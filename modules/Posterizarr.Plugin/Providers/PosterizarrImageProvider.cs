using MediaBrowser.Model.Services;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Entities.Movies;
using MediaBrowser.Controller.Entities.TV;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.Entities;
using MediaBrowser.Model.Providers;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
#if TARGET_JELLYFIN
using System.Net.Http;
using System.Net.Http.Headers;
#endif
using System.Threading;
using System.Threading.Tasks;

namespace Posterizarr.Plugin.Providers;

public class PosterizarrImageProvider : IRemoteImageProvider, IHasOrder
{
    private readonly ILibraryManager _libraryManager;
    private readonly ILogger<PosterizarrImageProvider> _logger;

    public PosterizarrImageProvider(ILibraryManager libraryManager, ILogger<PosterizarrImageProvider> logger)
    {
        _libraryManager = libraryManager;
        _logger = logger;
    }

    public string Name => "Posterizarr Local Middleware";
    public int Order => -10;

    private void LogDebug(string message, params object[] args)
    {
        if (Plugin.Instance?.Configuration?.EnableDebugMode == true)
        {
            _logger.LogInformation("[Posterizarr DEBUG] " + message, args);
        }
    }

    public bool Supports(BaseItem item) => item is Movie || item is Series || item is Season || item is Episode;
    public IEnumerable<ImageType> GetSupportedImages(BaseItem item) => new[] { ImageType.Primary, ImageType.Backdrop };

#if TARGET_JELLYFIN
    public async Task<IEnumerable<RemoteImageInfo>> GetImages(BaseItem item, CancellationToken cancellationToken)
#else
    public async Task<IEnumerable<RemoteImageInfo>> GetImages(BaseItem item, MediaBrowser.Model.Configuration.LibraryOptions libraryOptions, CancellationToken cancellationToken)
#endif
    {
        var config = Plugin.Instance?.Configuration;
        LogDebug(">>> STARTING image search for Item: '{0}' (Type: {1})", item.Name, item.GetType().Name);

        if (config == null || string.IsNullOrEmpty(config.AssetFolderPath))
        {
            _logger.LogWarning("[Posterizarr] Configuration missing or AssetFolderPath is not configured.");
            return Enumerable.Empty<RemoteImageInfo>();
        }

        var results = new List<RemoteImageInfo>();
        foreach (var type in new[] { ImageType.Primary, ImageType.Backdrop })
        {
            LogDebug("Checking for image type: {0}", type);
            var path = FindFile(item, config, type);
            if (!string.IsNullOrEmpty(path))
            {
                LogDebug("SUCCESS: Found {0} at '{1}'", type, path);
                results.Add(new RemoteImageInfo { ProviderName = Name, Url = path, Type = type });
            }
            else
            {
                LogDebug("RESULT: No matching file found for {0}", type);
            }
        }
        return results;
    }

#if TARGET_JELLYFIN
    private string? FindFile(BaseItem item, Configuration.PluginConfiguration config, ImageType type)
    {
        var displayLibraryName = item.GetAncestorIds()
            .Select(id => _libraryManager.GetItemById(id))
            .OfType<CollectionFolder>()
            .FirstOrDefault()?.Name ?? "Unknown";

        var internalLibraryName = item.GetAncestorIds()
            .Select(id => _libraryManager.GetItemById(id))
            .FirstOrDefault(p => p != null && p.ParentId != Guid.Empty && _libraryManager.GetItemById(p.ParentId)?.ParentId == Guid.Empty)?
            .Name ?? "Unknown";

        LogDebug("Library Resolution -> Display Name: '{0}', Internal Name: '{1}'", displayLibraryName, internalLibraryName);

        if (!Directory.Exists(config.AssetFolderPath))
        {
            _logger.LogError("[Posterizarr] Asset Folder Path does not exist: {0}", config.AssetFolderPath);
            return null;
        }

        var directories = Directory.GetDirectories(config.AssetFolderPath);
        string? libraryDir = null;

        libraryDir = directories.FirstOrDefault(d => string.Equals(Path.GetFileName(d), displayLibraryName, StringComparison.OrdinalIgnoreCase));
        if (libraryDir != null) LogDebug("Strategy A (Exact Display) MATCHED: {0}", Path.GetFileName(libraryDir));

        if (libraryDir == null)
        {
            libraryDir = directories.FirstOrDefault(d => string.Equals(Path.GetFileName(d), internalLibraryName, StringComparison.OrdinalIgnoreCase));
            if (libraryDir != null) LogDebug("Strategy B (Exact Internal) MATCHED: {0}", Path.GetFileName(libraryDir));
        }

        if (libraryDir == null)
        {
            LogDebug("Strategies A & B failed. Attempting Strategy C (Fuzzy Match)...");
            var searchTerms = new[] { displayLibraryName, internalLibraryName }
                .Where(s => s != "Unknown" && s != "root")
                .Select(s => s.Replace(" ", "").ToLowerInvariant())
                .Distinct();

            libraryDir = directories.FirstOrDefault(d => {
                var folderStripped = Path.GetFileName(d).Replace(" ", "").ToLowerInvariant();
                return searchTerms.Any(term => folderStripped.Contains(term) || term.Contains(folderStripped));
            });
            if (libraryDir != null) LogDebug("Strategy C (Fuzzy) MATCHED: {0}", Path.GetFileName(libraryDir));
        }

        if (libraryDir == null)
        {
            LogDebug("FAIL: Could not find a folder in AssetPath matching '{0}' or '{1}'", displayLibraryName, internalLibraryName);
            return null;
        }

        var directoryPath = (item is Movie || item is Series) ? (item is Movie ? Path.GetDirectoryName(item.Path) : item.Path) :
                            (item is Season s ? s.Series.Path : (item is Episode e ? e.Series.Path : ""));

        var subFolder = Path.GetFileName(directoryPath) ?? "";
        LogDebug("Media Subfolder resolved to: '{0}'", subFolder);

        string fileNameBase = type switch {
            ImageType.Primary when item is Season sn => $"season{sn.IndexNumber ?? 0:D2}",
            ImageType.Primary when item is Episode ep => $"S{ep.ParentIndexNumber ?? 0:D2}E{ep.IndexNumber ?? 0:D2}",
            ImageType.Primary => "poster",
            _ => "background"
        };

        var actualFolder = Path.Combine(libraryDir, subFolder);
        LogDebug("Full target path to check: {0}", actualFolder);

        if (!Directory.Exists(actualFolder))
        {
            LogDebug("FAIL: Folder '{0}' does not exist on disk.", actualFolder);
            return null;
        }

        var filesInFolder = Directory.GetFiles(actualFolder);
        LogDebug("Searching for base name '{0}' with supported extensions...", fileNameBase);

        foreach (var ext in config.SupportedExtensions)
        {
            var targetFile = fileNameBase + ext;
            var match = filesInFolder.FirstOrDefault(f => Path.GetFileName(f).Equals(targetFile, StringComparison.OrdinalIgnoreCase));
            if (match != null) return match;

            if (type == ImageType.Backdrop)
            {
                var fanartTarget = "fanart" + ext;
                var fanartMatch = filesInFolder.FirstOrDefault(f => Path.GetFileName(f).Equals(fanartTarget, StringComparison.OrdinalIgnoreCase));
                if (fanartMatch != null)
                {
                    LogDebug("Found fallback: {0}", fanartTarget);
                    return fanartMatch;
                }
            }
        }

        LogDebug("No file matched '{0}' with extensions: {1}", fileNameBase, string.Join(", ", config.SupportedExtensions));
        return null;
    }
#else
    private string? FindFile(BaseItem item, Configuration.PluginConfiguration config, ImageType type)
    {
        BaseItem? current = item;
        string displayLibraryName = "Unknown";
        string internalLibraryName = "Unknown";

        while (current != null)
        {
            if (current is CollectionFolder) displayLibraryName = current.Name;
            if (current.ParentId == Guid.Empty) break;
            var parent = _libraryManager.GetItemById(current.ParentId);
            if (parent != null && parent.ParentId == Guid.Empty) internalLibraryName = current.Name;
            current = parent;
        }

        LogDebug("EMBY Library Resolution -> Display: '{0}', Internal: '{1}'", displayLibraryName, internalLibraryName);

        if (!Directory.Exists(config.AssetFolderPath)) return null;

        var directories = Directory.GetDirectories(config.AssetFolderPath);
        string? libraryDir = directories.FirstOrDefault(d => string.Equals(Path.GetFileName(d), displayLibraryName, StringComparison.OrdinalIgnoreCase))
                           ?? directories.FirstOrDefault(d => string.Equals(Path.GetFileName(d), internalLibraryName, StringComparison.OrdinalIgnoreCase));

        if (libraryDir == null) return null;

        var directoryPath = (item is Movie || item is Series) ? (item is Movie ? Path.GetDirectoryName(item.Path) : item.Path) :
                            (item is Season s ? s.Series.Path : (item is Episode e ? e.Series.Path : ""));

        var subFolder = Path.GetFileName(directoryPath) ?? "";
        string fileNameBase = type switch {
            ImageType.Primary when item is Season sn => $"season{sn.IndexNumber ?? 0:D2}",
            ImageType.Primary when item is Episode ep => $"S{ep.ParentIndexNumber ?? 0:D2}E{ep.IndexNumber ?? 0:D2}",
            ImageType.Primary => "poster",
            _ => "background"
        };

        var actualFolder = Path.Combine(libraryDir, subFolder);
        if (!Directory.Exists(actualFolder)) return null;

        var filesInFolder = Directory.GetFiles(actualFolder);
        foreach (var ext in config.SupportedExtensions)
        {
            var targetFile = fileNameBase + ext;
            var match = filesInFolder.FirstOrDefault(f => Path.GetFileName(f).Equals(targetFile, StringComparison.OrdinalIgnoreCase));
            if (match != null) return match;

            if (type == ImageType.Backdrop)
            {
                var fanartMatch = filesInFolder.FirstOrDefault(f => Path.GetFileName(f).Equals("fanart" + ext, StringComparison.OrdinalIgnoreCase));
                if (fanartMatch != null) return fanartMatch;
            }
        }
        return null;
    }
#endif

#if TARGET_JELLYFIN
    public Task<HttpResponseMessage> GetImageResponse(string url, CancellationToken cancellationToken)
    {
        LogDebug("Serving image response for: {0}", url);
        if (File.Exists(url))
        {
            var response = new HttpResponseMessage(HttpStatusCode.OK) { Content = new StreamContent(File.OpenRead(url)) };
            var ext = Path.GetExtension(url).ToLowerInvariant();
            string mimeType = ext switch { ".png" => "image/png", ".webp" => "image/webp", ".bmp" => "image/bmp", _ => "image/jpeg" };
            response.Content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(mimeType);
            return Task.FromResult(response);
        }
        _logger.LogError("[Posterizarr] File not found when serving response: {0}", url);
        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
    }
#else
    public Task<HttpResponseInfo> GetImageResponse(string url, CancellationToken cancellationToken)
    {
        LogDebug("EMBY: Serving image response for: {0}", url);
        if (File.Exists(url))
        {
            var ext = Path.GetExtension(url).ToLowerInvariant();
            return Task.FromResult(new HttpResponseInfo
            {
                Content = File.OpenRead(url),
                ContentType = ext switch { ".png" => "image/png", ".webp" => "image/webp", _ => "image/jpeg" },
                StatusCode = HttpStatusCode.OK
            });
        }
        return Task.FromResult(new HttpResponseInfo { StatusCode = HttpStatusCode.NotFound });
    }
#endif
}