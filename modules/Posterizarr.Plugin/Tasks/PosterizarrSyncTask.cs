using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Library;
using MediaBrowser.Model.Tasks;
using MediaBrowser.Model.Entities;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.Querying;
using Microsoft.Extensions.Logging;
using Posterizarr.Plugin.Providers;
using System.Security.Cryptography;
using Jellyfin.Data.Enums;
using System.Linq;

namespace Posterizarr.Plugin.Tasks;

public class PosterizarrSyncTask : IScheduledTask
{
    private readonly ILibraryManager _libraryManager;
    private readonly IProviderManager _providerManager;
    private readonly ILogger<PosterizarrSyncTask> _logger;

    public PosterizarrSyncTask(
        ILibraryManager libraryManager,
        IProviderManager providerManager,
        ILogger<PosterizarrSyncTask> logger)
    {
        _libraryManager = libraryManager;
        _providerManager = providerManager;
        _logger = logger;
    }

    public string Name => "Sync Posterizarr Assets";
    public string Key => "PosterizarrSyncTask";
    public string Description => "Checks local assets and updates Jellyfin images if the file hash has changed.";
    public string Category => "Posterizarr";

    public IEnumerable<TaskTriggerInfo> GetDefaultTriggers()
    {
        return new[] { new TaskTriggerInfo { Type = TaskTriggerInfo.TriggerDaily, TimeOfDayTicks = TimeSpan.FromHours(2).Ticks } };
    }

    public async Task ExecuteAsync(IProgress<double> progress, CancellationToken cancellationToken)
    {
        var config = Plugin.Instance?.Configuration;
        if (config == null || string.IsNullOrEmpty(config.AssetFolderPath))
        {
            _logger.LogWarning("[Posterizarr] Task aborted: AssetFolderPath not configured.");
            return;
        }

        var provider = new PosterizarrImageProvider(_libraryManager, new LoggerFactory().CreateLogger<PosterizarrImageProvider>());

        var query = new InternalItemsQuery
        {
            IncludeItemTypes = new[] { BaseItemKind.Movie, BaseItemKind.Series, BaseItemKind.Season, BaseItemKind.Episode },
            Recursive = true,
            IsVirtualItem = false
        };

        var items = _libraryManager.GetItems(query).ToArray();

        _logger.LogInformation("[Posterizarr] Starting sync for {0} items.", items.Length);

        for (var i = 0; i < items.Length; i++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var item = items[i];

            foreach (var type in new[] { ImageType.Primary, ImageType.Backdrop })
            {
                var localPath = provider.FindFile(item, config, type);
                if (string.IsNullOrEmpty(localPath)) continue;

                var existingImage = item.GetImageInfo(type, 0);

                if (existingImage == null || !IsHashMatch(localPath, existingImage.Path))
                {
                    _logger.LogInformation("[Posterizarr] Updating {0} image for: {1}", type, item.Name);

                    await _providerManager.SaveImage(item, localPath, type, null, cancellationToken);
                }
            }

            progress.Report((double)i / items.Length * 100);
        }

        progress.Report(100);

        if (Plugin.Instance != null)
        {
            Plugin.Instance.Configuration.LastSyncTime = DateTime.Now;
            Plugin.Instance.SaveConfiguration();
        }
    }

    private bool IsHashMatch(string sourcePath, string jellyfinPath)
    {
        if (string.IsNullOrEmpty(jellyfinPath) || !File.Exists(sourcePath) || !File.Exists(jellyfinPath)) return false;

        try
        {
            // Quick check: If file sizes differ, hashes definitely differ
            if (new FileInfo(sourcePath).Length != new FileInfo(jellyfinPath).Length) return false;

            using var md5 = MD5.Create();
            using var s1 = File.OpenRead(sourcePath);
            using var s2 = File.OpenRead(jellyfinPath);
            return md5.ComputeHash(s1).SequenceEqual(md5.ComputeHash(s2));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Posterizarr] Error comparing hash for {0}", sourcePath);
            return false;
        }
    }
}