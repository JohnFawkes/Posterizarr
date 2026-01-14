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

                try
                {
                    // To solve the 405 Method Not Allowed error, we convert the local image to a Base64
                    // data URI. This allows the browser to display the image directly without
                    // relying on the server's POST-only download endpoints.
                    var bytes = File.ReadAllBytes(path);
                    var ext = Path.GetExtension(path).ToLowerInvariant();
                    string mimeType = ext switch {
                        ".png" => "image/png",
                        ".webp" => "image/webp",
                        ".bmp" => "image/bmp",
                        _ => "image/jpeg"
                    };

                    results.Add(new RemoteImageInfo
                    {
                        ProviderName = Name,
                        Url = $"data:{mimeType};base64,{Convert.ToBase64String(bytes)}",
                        Type = type
                    });

                    LogDebug("Converted {0} to Base64 data URI for UI display.", type);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "[Posterizarr] Failed to process image for UI at {0}", path);
                }
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
             _logger.LogError("[Posterizarr] Root Asset Path does not exist: {0}", config.AssetFolderPath);
             return null;
        }

        var directories = Directory.GetDirectories(config.AssetFolderPath);
        string? libraryDir = null;

        libraryDir = directories.FirstOrDefault(d => string.Equals(Path.GetFileName(d), displayLibraryName, StringComparison.OrdinalIgnoreCase));
        if (libraryDir != null) LogDebug("Matched Library via Strategy A: {0}", libraryDir);

        if (libraryDir == null)
        {
            libraryDir = directories.FirstOrDefault(d => string.Equals(Path.GetFileName(d), internalLibraryName, StringComparison.OrdinalIgnoreCase));
            if (libraryDir != null) LogDebug("Matched Library via Strategy B: {0}", libraryDir);
        }

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
            if (libraryDir != null) LogDebug("Matched Library via Strategy C: {0}", libraryDir);
        }

        if (libraryDir == null)
        {
            LogDebug("FAIL: Library not found. Tried matching Display: '{0}' and Internal: '{1}'", displayLibraryName, internalLibraryName);
            return null;
        }

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
            LogDebug("FAIL: Media subfolder not found: {0}", actualFolder);
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

    public Task<HttpResponseMessage> GetImageResponse(string url, CancellationToken cancellationToken)
    {
        LogDebug("Incoming proxy request (fallback): {0}", url);

        // This fallback handles cases where Jellyfin server tries to resolve the local
        // path during the metadata application phase.
        string localPath = url;
        if (url.Contains("ImageUrl="))
        {
            var parts = url.Split(new[] { "ImageUrl=" }, StringSplitOptions.None);
            if (parts.Length > 1)
            {
                localPath = Uri.UnescapeDataString(parts[1].Split('&')[0]);
            }
        }

        LogDebug("Resolved path for streaming: {0}", localPath);

        if (File.Exists(localPath))
        {
            try
            {
                var response = new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                {
                    Content = new StreamContent(File.OpenRead(localPath))
                };

                var ext = Path.GetExtension(localPath).ToLowerInvariant();
                string mimeType = ext switch {
                    ".png" => "image/png",
                    ".webp" => "image/webp",
                    ".bmp" => "image/bmp",
                    _ => "image/jpeg"
                };

                response.Content.Headers.ContentType = new MediaTypeHeaderValue(mimeType);

                LogDebug("Proxy SUCCESS: Streaming {0}", localPath);
                return Task.FromResult(response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[Posterizarr] Error reading local file at {0}", localPath);
                return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.InternalServerError));
            }
        }

        LogDebug("Proxy FAIL: File not found at {0}", localPath);
        return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.NotFound));
    }
}