using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Entities.Movies;
using MediaBrowser.Controller.Entities.TV;
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
            // Batch throttling: report progress and check cancellation
            if (i % 100 == 0)
            {
                cancellationToken.ThrowIfCancellationRequested();
                progress.Report((double)i / totalItems * 100);
            }

            var item = items[i];
            bool itemUpdated = false;

            // Define which images to check based on item type
            var typesToCheck = new List<ImageType> { ImageType.Primary };

            // Checking type via pattern matching (Safe and fast)
            if (item is Movie || item is Series)
            {
                typesToCheck.Add(ImageType.Backdrop);
            }

            foreach (var type in typesToCheck)
            {
                var localPath = provider.FindFile(item, config, type);
                if (string.IsNullOrEmpty(localPath)) continue;

                var existingImage = item.GetImageInfo(type, 0);

                // Memory-safe Hash Match
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
                // Persistence: Only updates the image rows in the database
                await _libraryManager.UpdateItemAsync(item, item, ItemUpdateType.ImageUpdate, cancellationToken).ConfigureAwait(false);
            }
        }

        progress.Report(100);
        _logger.LogInformation("[Posterizarr] Sync finished. Memory usage stabilized.");
    }

    private bool IsHashMatch(string sourcePath, string jellyfinPath)
    {
        if (string.IsNullOrEmpty(jellyfinPath) || !File.Exists(sourcePath) || !File.Exists(jellyfinPath)) return false;

        try
        {
            var sourceInfo = new FileInfo(sourcePath);
            var jellyfinInfo = new FileInfo(jellyfinPath);

            if (sourceInfo.Length != jellyfinInfo.Length) return false;

            // SequentialScan prevents Windows/Linux from caching these 37k files in the RAM Page Cache
            using var fs1 = new FileStream(sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.SequentialScan);
            using var fs2 = new FileStream(jellyfinPath, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.SequentialScan);

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