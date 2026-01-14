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
using System.Net.Http;
using System.Net.Http.Headers;
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

    public async Task<IEnumerable<RemoteImageInfo>> GetImages(BaseItem item, CancellationToken cancellationToken)
    {
        var config = Plugin.Instance?.Configuration;
        LogDebug(">>> Starting Search for: '{0}' (ID: {1})", item.Name, item.Id);

        if (config == null || string.IsNullOrEmpty(config.AssetFolderPath))
        {
            _logger.LogWarning("[Posterizarr] Configuration missing or AssetFolderPath empty.");
            return Enumerable.Empty<RemoteImageInfo>();
        }

        var results = new List<RemoteImageInfo>();
        foreach (var type in new[] { ImageType.Primary, ImageType.Backdrop })
        {
            LogDebug("Searching for image type: {0}", type);
            var path = FindFile(item, config, type);
            if (!string.IsNullOrEmpty(path))
            {
                LogDebug("SUCCESS: Found {0} at {1}", type, path);

                // Return the full local path. Jellyfin will pass this back to
                // GetImageResponse when the browser requests the image.
                results.Add(new RemoteImageInfo
                {
                    ProviderName = Name,
                    Url = path,
                    Type = type
                });
            }
            else
            {
                LogDebug("NOTICE: No local {0} found for {1}", type, item.Name);
            }
        }
        return results;
    }

    private string? FindFile(BaseItem item, Configuration.PluginConfiguration config, ImageType type)
    {
        // 1. Resolve Library Names (Display Name vs Internal Name)
        var displayLibraryName = item.GetAncestorIds()
            .Select(id => _libraryManager.GetItemById(id))
            .OfType<CollectionFolder>()
            .FirstOrDefault()?.Name ?? "Unknown";

        var internalLibraryName = item.GetAncestorIds()
            .Select(id => _libraryManager.GetItemById(id))
            .FirstOrDefault(p => p != null && p.ParentId != Guid.Empty && _libraryManager.GetItemById(p.ParentId)?.ParentId == Guid.Empty)?
            .Name ?? "Unknown";

        LogDebug("Library Resolution -> Display: '{0}', Internal: '{1}'", displayLibraryName, internalLibraryName);

        // 2. Multi-Strategy Library Lookup
        if (!Directory.Exists(config.AssetFolderPath))
        {
            _logger.LogError("[Posterizarr] Asset root path not found: {0}", config.AssetFolderPath);
            return null;
        }

        var directories = Directory.GetDirectories(config.AssetFolderPath);
        string? libraryDir = null;

        // Strategy A: Exact Match on Display Name
        libraryDir = directories.FirstOrDefault(d => string.Equals(Path.GetFileName(d), displayLibraryName, StringComparison.OrdinalIgnoreCase));

        // Strategy B: Exact Match on Internal Name
        if (libraryDir == null)
            libraryDir = directories.FirstOrDefault(d => string.Equals(Path.GetFileName(d), internalLibraryName, StringComparison.OrdinalIgnoreCase));

        // Strategy C: Fuzzy Match
        if (libraryDir == null)
        {
            var searchTerms = new[] { displayLibraryName, internalLibraryName }
                .Where(s => s != "Unknown" && s != "root")
                .Select(s => s.Replace(" ", "").ToLowerInvariant())
                .Distinct();

            libraryDir = directories.FirstOrDefault(d => {
                var folderStripped = Path.GetFileName(d).Replace(" ", "").ToLowerInvariant();
                return searchTerms.Any(term => folderStripped.Contains(term) || term.Contains(folderStripped));
            });
        }

        if (libraryDir == null)
        {
            LogDebug("FAIL: Library folder match not found in {0}", config.AssetFolderPath);
            return null;
        }

        LogDebug("Matched Library Folder: {0}", libraryDir);

        // 3. Resolve Media Folder Name from Disk
        var directoryPath = (item is Movie || item is Series) ? (item is Movie ? Path.GetDirectoryName(item.Path) : item.Path) :
                            (item is Season s ? s.Series.Path : (item is Episode e ? e.Series.Path : ""));

        var subFolder = Path.GetFileName(directoryPath) ?? "";
        LogDebug("Item Folder Name on disk: '{0}'", subFolder);

        string fileNameBase = type switch {
            ImageType.Primary when item is Season sn => $"season{sn.IndexNumber ?? 0:D2}",
            ImageType.Primary when item is Episode ep => $"S{ep.ParentIndexNumber ?? 0:D2}E{ep.IndexNumber ?? 0:D2}",
            ImageType.Primary => "poster",
            _ => "background"
        };

        var actualFolder = Path.Combine(libraryDir, subFolder);
        if (!Directory.Exists(actualFolder))
        {
            LogDebug("FAIL: Media folder does not exist at {0}", actualFolder);
            return null;
        }

        // 4. File Lookup
        var filesInFolder = Directory.GetFiles(actualFolder);
        LogDebug("Scanning {0} files in folder: {1}", filesInFolder.Length, actualFolder);

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

    /// <summary>
    /// This method intercepts the request for the image URL provided in GetImages.
    /// It reads the local file and streams it back to the client via HTTP.
    /// </summary>
    public Task<HttpResponseMessage> GetImageResponse(string url, CancellationToken cancellationToken)
    {
        LogDebug("Proxying image request for: {0}", url);

        if (File.Exists(url))
        {
            try
            {
                // Open the local file for reading. Jellyfin will manage the stream disposal.
                var stream = File.OpenRead(url);
                var response = new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                {
                    Content = new StreamContent(stream)
                };

                var ext = Path.GetExtension(url).ToLowerInvariant();
                string mimeType = ext switch {
                    ".png" => "image/png",
                    ".webp" => "image/webp",
                    ".bmp" => "image/bmp",
                    _ => "image/jpeg"
                };

                response.Content.Headers.ContentType = new MediaTypeHeaderValue(mimeType);

                LogDebug("Proxy SUCCESS: Streaming {0} as {1}", url, mimeType);
                return Task.FromResult(response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[Posterizarr] Failed to proxy image at {0}. Check file permissions.", url);
                return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.InternalServerError));
            }
        }

        LogDebug("Proxy FAIL: File no longer exists at {0}", url);
        return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.NotFound));
    }
}