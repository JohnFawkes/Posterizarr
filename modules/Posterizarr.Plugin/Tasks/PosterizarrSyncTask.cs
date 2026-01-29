using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Library;
using MediaBrowser.Model.Tasks;
using MediaBrowser.Model.Entities;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.Querying;
using MediaBrowser.Model.IO;
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
    private readonly IFileSystem _fileSystem;
    private readonly ILogger<PosterizarrSyncTask> _logger;

    public PosterizarrSyncTask(
        ILibraryManager libraryManager,
        IProviderManager providerManager,
        IFileSystem fileSystem,
        ILogger<PosterizarrSyncTask> logger)
    {
        _libraryManager = libraryManager;
        _providerManager = providerManager;
        _fileSystem = fileSystem;
        _logger = logger;
    }

    public string Name => "Sync Posterizarr Assets";
    public string Key => "PosterizarrSyncTask";
    public string Description => "High-performance sync optimized for 30k+ items.";
    public string Category => "Posterizarr";

    public IEnumerable<TaskTriggerInfo> GetDefaultTriggers()
    {
        return new[] { new TaskTriggerInfo { Type = TaskTriggerInfoType.DailyTrigger, TimeOfDayTicks = TimeSpan.FromHours(2).Ticks } };
    }

    public async Task ExecuteAsync(IProgress<double> progress, CancellationToken cancellationToken)
    {
        var config = Plugin.Instance?.Configuration;
        if (config == null || string.IsNullOrEmpty(config.AssetFolderPath)) return;

        var provider = new PosterizarrImageProvider(_libraryManager, new LoggerFactory().CreateLogger<PosterizarrImageProvider>());

        var query = new InternalItemsQuery
        {
            IncludeItemTypes = new[] { BaseItemKind.Movie, BaseItemKind.Series, BaseItemKind.Season, BaseItemKind.Episode },
            Recursive = true,
            IsVirtualItem = false
        };

        var items = _libraryManager.GetItemList(query);
        int totalItems = items.Count;

        _logger.LogInformation("[Posterizarr] Starting memory-optimized sync for {0} items.", totalItems);

        for (var i = 0; i < totalItems; i++)
        {
            // Throttling: Check cancellation and update UI every 100 items
            if (i % 100 == 0)
            {
                cancellationToken.ThrowIfCancellationRequested();
                progress.Report((double)i / totalItems * 100);
            }

            var item = items[i];
            bool itemUpdated = false;

            // Logical filtering: Only check backdrops for top-level media
            var typesToCheck = new List<ImageType> { ImageType.Primary };
            if (item.Kind == BaseItemKind.Movie || item.Kind == BaseItemKind.Series)
            {
                typesToCheck.Add(ImageType.Backdrop);
            }

            foreach (var type in typesToCheck)
            {
                var localPath = provider.FindFile(item, config, type);
                if (string.IsNullOrEmpty(localPath)) continue;

                var existingImage = item.GetImageInfo(type, 0);

                // High-performance hash match
                if (existingImage == null || !IsHashMatch(localPath, existingImage.Path))
                {
                    item.SetImage(new ItemImageInfo
                    {
                        Path = localPath,
                        Type = type,
                        DateModified = File.GetLastWriteTimeUtc(localPath)
                    }, 0);

                    itemUpdated = true;
                }
            }

            if (itemUpdated)
            {
                // ImageUpdate tells the DB to only touch the image rows (very fast)
                await _libraryManager.UpdateItemAsync(item, item, ItemUpdateType.ImageUpdate, cancellationToken).ConfigureAwait(false);
            }
        }

        progress.Report(100);
        _logger.LogInformation("[Posterizarr] Sync finished. RAM should remain stable.");
    }

    private bool IsHashMatch(string sourcePath, string jellyfinPath)
    {
        if (string.IsNullOrEmpty(jellyfinPath) || !File.Exists(sourcePath) || !File.Exists(jellyfinPath)) return false;

        try
        {
            var sourceInfo = new FileInfo(sourcePath);
            var jellyfinInfo = new FileInfo(jellyfinPath);

            // Instant size check
            if (sourceInfo.Length != jellyfinInfo.Length) return false;

            // Memory-Safe Stream Handling:
            // FileOptions.SequentialScan prevents the OS from caching these 37k files in RAM.
            using var fs1 = new FileStream(sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.SequentialScan);
            using var fs2 = new FileStream(jellyfinPath, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.SequentialScan);

            // HashData is a .NET modern method that is faster and more allocation-friendly
            byte[] hash1 = MD5.HashData(fs1);
            byte[] hash2 = MD5.HashData(fs2);

            return hash1.SequenceEqual(hash2);
        }
        catch
        {
            return false;
        }
    }
}