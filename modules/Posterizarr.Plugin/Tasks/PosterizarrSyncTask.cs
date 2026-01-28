using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Library;
using MediaBrowser.Model.Tasks;
using MediaBrowser.Model.Entities;
using Microsoft.Extensions.Logging;
using Posterizarr.Plugin.Providers;
using System.Security.Cryptography;

namespace Posterizarr.Plugin.Tasks;

public class PosterizarrSyncTask : IScheduledTask
{
    private readonly ILibraryManager _libraryManager;
    private readonly ILogger<PosterizarrSyncTask> _logger;

    public PosterizarrSyncTask(ILibraryManager libraryManager, ILogger<PosterizarrSyncTask> logger)
    {
        _libraryManager = libraryManager;
        _logger = logger;
    }

    public string Name => "Sync Posterizarr Assets";
    public string Key => "PosterizarrSyncTask";
    public string Description => "Checks local assets and updates Jellyfin images if the file hash has changed.";
    public string Category => "Posterizarr";

    public IEnumerable<TaskTriggerInfo> GetDefaultTriggers()
    {
        // Default to running once a day at 2 AM
        return new[] { new TaskTriggerInfo { Type = TaskTriggerInfo.TriggerDaily, TimeOfDayTicks = TimeSpan.FromHours(2).Ticks } };
    }

    public async Task Execute(CancellationToken cancellationToken, IProgress<double> progress)
    {
        var config = Plugin.Instance?.Configuration;
        if (config == null || string.IsNullOrEmpty(config.AssetFolderPath))
        {
            _logger.LogWarning("[Posterizarr] Task aborted: AssetFolderPath not configured.");
            return;
        }

        // create a temporary instance of the provider to use its FindFile logic
        var provider = new PosterizarrImageProvider(_libraryManager, new LoggerFactory().CreateLogger<PosterizarrImageProvider>());

        var items = _libraryManager.GetItemList(new InternalItemsQuery
        {
            IncludeItemTypes = new[] { "Movie", "Series", "Season", "Episode" },
            Recursive = true,
            IsVirtualItem = false
        });

        for (var i = 0; i < items.Count; i++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var item = items[i];

            foreach (var type in new[] { ImageType.Primary, ImageType.Backdrop })
            {
                var localPath = provider.FindFile(item, config, type);
                if (string.IsNullOrEmpty(localPath)) continue;

                var existingImage = item.GetImageInfo(type, 0);

                // Check if we need to update
                bool shouldUpdate = existingImage == null || !IsHashMatch(localPath, existingImage.Path);

                if (shouldUpdate)
                {
                    _logger.LogInformation("[Posterizarr] Updating {0} image for: {1}", type, item.Name);
                    await _libraryManager.ConvertImageToLocal(item, localPath, type, 0, cancellationToken);
                }
            }

            progress.Report((double)i / items.Count * 100);
        }
        progress.Report(100);

        if (Plugin.Instance != null)
        {
            Plugin.Instance.Configuration.LastSyncTime = DateTime.Now;
            Plugin.Instance.SaveConfiguration();
            _logger.LogInformation("[Posterizarr] Sync task finished and timestamp updated.");
        }
    }

    private bool IsHashMatch(string sourcePath, string jellyfinPath)
    {
        if (!File.Exists(sourcePath) || !File.Exists(jellyfinPath)) return false;

        try
        {
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