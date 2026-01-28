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

        // Based on your interface, GetItemList returns IReadOnlyList<BaseItem>
        var items = _libraryManager.GetItemList(query);

        _logger.LogInformation("[Posterizarr] Starting sync for {0} items.", items.Count);

        for (var i = 0; i < items.Count; i++)
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

                    // Based on your provided classes:
                    // 1. Create the required ItemImageInfo object
                    var newImageInfo = new ItemImageInfo
                    {
                        Path = localPath,
                        Type = type,
                        DateModified = File.GetLastWriteTimeUtc(localPath)
                    };

                    // 2. Call ConvertImageToLocal using the 4-parameter overload from your interface:
                    // Task<ItemImageInfo> ConvertImageToLocal(BaseItem item, ItemImageInfo image, int imageIndex, bool removeOnFailure = true);
                    await _libraryManager.ConvertImageToLocal(item, newImageInfo, 0, true);
                }
            }

            progress.Report((double)i / items.Count * 100);
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