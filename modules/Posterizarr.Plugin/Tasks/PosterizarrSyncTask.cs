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
        return new[]
        {
            new TaskTriggerInfo
            {
                Type = TaskTriggerInfoType.DailyTrigger,
                TimeOfDayTicks = TimeSpan.FromHours(2).Ticks
            }
        };
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

        // In 10.11.x, GetItemList returns the collection directly.
        var items = _libraryManager.GetItemList(query).ToArray();

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
                    _logger.LogInformation("[Posterizarr] Syncing {0} for {1}...", type, item.Name);

                    // 1. Manually set the image info to avoid overload and URI issues
                    item.SetImage(new ItemImageInfo
                    {
                        Path = localPath,
                        Type = type,
                        LastModified = File.GetLastWriteTimeUtc(localPath)
                    }, 0);

                    // 2. Persist the change to the database
                    // Note: UpdateItem is the stable 10.11 method for internal persistence
                    _libraryManager.UpdateItem(item, item, ItemUpdateType.MetadataEdit, cancellationToken);
                }
            }

            progress.Report((double)i / items.Length * 100);
        }

        progress.Report(100);

        if (Plugin.Instance != null)
        {
            Plugin.Instance.Configuration.LastSyncTime = DateTime.Now;
            Plugin.Instance.SaveConfiguration();
            _logger.LogInformation("[Posterizarr] Sync task finished.");
        }
    }

    private bool IsHashMatch(string sourcePath, string jellyfinPath)
    {
        if (string.IsNullOrEmpty(jellyfinPath) || !File.Exists(sourcePath) || !File.Exists(jellyfinPath)) return false;

        try
        {
            var sourceInfo = new FileInfo(sourcePath);
            var jellyfinInfo = new FileInfo(jellyfinPath);

            // Optimization: If sizes differ, skip MD5
            if (sourceInfo.Length != jellyfinInfo.Length) return false;

            using var md5 = MD5.Create();
            using var s1 = File.OpenRead(sourcePath);
            using var s2 = File.OpenRead(jellyfinPath);
            return md5.ComputeHash(s1).SequenceEqual(md5.ComputeHash(s2));
        }
        catch
        {
            return false;
        }
    }
}