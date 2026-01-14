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
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;

namespace Posterizarr.Plugin.Providers;

public class PosterizarrImageProvider : IRemoteImageProvider, IHasOrder
{
    private readonly ILibraryManager _libraryManager;
    private readonly ILogger<PosterizarrImageProvider> _logger;
    private const string ProxyPrefix = "http://posterizarr.local";

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

                // Construct a URL that Jellyfin's server can proxy.
                // We use a relative path so the browser hits the Jellyfin server,
                // and a fake domain so the server hands the request to our plugin.
                var internalUrl = ProxyPrefix + path;
                var publicProxyUrl = "/Images/Remote?url=" + WebUtility.UrlEncode(internalUrl);

                results.Add(new RemoteImageInfo
                {
                    ProviderName = Name,
                    Url = publicProxyUrl,
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
        var displayLibraryName = item.GetAncestorIds()
            .Select(id => _libraryManager.GetItemById(id))
            .OfType<CollectionFolder>()
            .FirstOrDefault()?.Name ?? "Unknown";

        var internalLibraryName = item.GetAncestorIds()
            .Select(id => _libraryManager.GetItemById(id))
            .FirstOrDefault(p => p != null && p.ParentId != Guid.Empty && _libraryManager.GetItemById(p.ParentId)?.ParentId == Guid.Empty)?
            .Name ?? "Unknown";

        LogDebug("Library Resolution -> Display: '{0}', Internal: '{1}'", displayLibraryName, internalLibraryName);

        if (!Directory.Exists(config.AssetFolderPath))
        {
             _logger.LogError("[Posterizarr] Root Asset Path does not exist: {0}", config.AssetFolderPath);
             return null;
        }

        var directories = Directory.GetDirectories(config.AssetFolderPath);
        string? libraryDir = null;

        // Strategy A: Exact Match
        libraryDir = directories.FirstOrDefault(d => string.Equals(Path.GetFileName(d), displayLibraryName, StringComparison.OrdinalIgnoreCase));

        // Strategy B: Exact Match Internal
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
            LogDebug("FAIL: Library match not found for '{0}'", item.Name);
            return null;
        }

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

    public Task<HttpResponseMessage> GetImageResponse(string url, CancellationToken cancellationToken)
    {
        LogDebug("Incoming proxy request: {0}", url);

        // Strip the fake domain to get the local path
        string localPath = url;
        if (url.StartsWith(ProxyPrefix, StringComparison.OrdinalIgnoreCase))
        {
            localPath = url.Substring(ProxyPrefix.Length);
        }

        LogDebug("Resolved path for streaming: {0}", localPath);

        if (File.Exists(localPath))
        {
            try
            {
                var response = new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StreamContent(File.OpenRead(localPath))
                };

                var ext = Path.GetExtension(localPath).ToLowerInvariant();
                string mimeType = ext switch { ".png" => "image/png", ".webp" => "image/webp", ".bmp" => "image/bmp", _ => "image/jpeg" };
                response.Content.Headers.ContentType = new MediaTypeHeaderValue(mimeType);

                LogDebug("Proxy SUCCESS: Streaming {0}", localPath);
                return Task.FromResult(response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[Posterizarr] Error reading file at {0}", localPath);
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.InternalServerError));
            }
        }

        LogDebug("Proxy FAIL: File not found at {0}", localPath);
        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
    }
}