using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Model.Entities;
using Microsoft.Extensions.Logging;

namespace Posterizarr.Plugin.Tasks;

public class AssetSyncRecord
{
    public string SourcePath { get; set; } = string.Empty;
    public long SourceLastWriteTimeUtcTicks { get; set; }
    public long SourceLength { get; set; }
    public string JellyfinImagePath { get; set; } = string.Empty;
    public long JellyfinDateModifiedUtcTicks { get; set; }
}

/// <summary>
/// Persistent state cache manager to avoid re-reading, hashing, and re-downloading
/// assets that are already in sync between NAS and Jellyfin.
/// </summary>
public class SyncCacheManager
{
    private readonly string _cacheFilePath;
    private readonly ILogger _logger;
    private readonly ConcurrentDictionary<string, AssetSyncRecord> _records = new(StringComparer.OrdinalIgnoreCase);
    private bool _isDirty;
    private static readonly TimeSpan TimestampTolerance = TimeSpan.FromSeconds(2);

    public SyncCacheManager(string dataFolderPath, ILogger logger)
    {
        _logger = logger;
        Directory.CreateDirectory(dataFolderPath);
        _cacheFilePath = Path.Combine(dataFolderPath, "posterizarr_sync_cache.json");
    }

    public int Count => _records.Count;

    public void Load()
    {
        if (!File.Exists(_cacheFilePath))
        {
            _logger.LogInformation("[Posterizarr] No existing sync cache found at {0}. Starting fresh.", _cacheFilePath);
            return;
        }

        try
        {
            using var stream = File.OpenRead(_cacheFilePath);
            var loaded = JsonSerializer.Deserialize<Dictionary<string, AssetSyncRecord>>(stream);
            if (loaded != null)
            {
                _records.Clear();
                foreach (var (key, record) in loaded)
                {
                    _records[key] = record;
                }
                _logger.LogInformation("[Posterizarr] Loaded {0} cached sync records from disk.", _records.Count);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "[Posterizarr] Could not read sync cache from {0}. Will regenerate.", _cacheFilePath);
        }
    }

    public void Save()
    {
        if (!_isDirty) return;

        try
        {
            var tempFile = _cacheFilePath + ".tmp";
            using (var stream = new FileStream(tempFile, FileMode.Create, FileAccess.Write, FileShare.None, 65536, FileOptions.SequentialScan))
            {
                JsonSerializer.Serialize(stream, _records, new JsonSerializerOptions
                {
                    WriteIndented = false,
                    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
                });
            }

            File.Move(tempFile, _cacheFilePath, overwrite: true);
            _isDirty = false;
            _logger.LogInformation("[Posterizarr] Saved {0} sync records to cache.", _records.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Posterizarr] Failed to write sync cache to disk.");
        }
    }

    public bool IsMatch(Guid itemId, ImageType type, FileInfo sourceFile, ItemImageInfo existingImage)
    {
        var key = BuildKey(itemId, type);
        if (!_records.TryGetValue(key, out var record))
        {
            return false;
        }

        // 1. Check Source File on NAS (Path, Size, Timestamp)
        if (!string.Equals(record.SourcePath, sourceFile.FullName, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        if (record.SourceLength != sourceFile.Length)
        {
            return false;
        }

        var sourceDiff = Math.Abs((sourceFile.LastWriteTimeUtc - new DateTime(record.SourceLastWriteTimeUtcTicks, DateTimeKind.Utc)).TotalSeconds);
        if (sourceDiff > TimestampTolerance.TotalSeconds)
        {
            return false;
        }

        // 2. Check Jellyfin Internal Image (Path, Timestamp)
        if (!string.Equals(record.JellyfinImagePath, existingImage.Path, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var jfDiff = Math.Abs((existingImage.DateModified.ToUniversalTime() - new DateTime(record.JellyfinDateModifiedUtcTicks, DateTimeKind.Utc)).TotalSeconds);
        if (jfDiff > TimestampTolerance.TotalSeconds)
        {
            return false;
        }

        return true;
    }

    public void Update(Guid itemId, ImageType type, FileInfo sourceFile, ItemImageInfo existingImage)
    {
        var key = BuildKey(itemId, type);
        _records[key] = new AssetSyncRecord
        {
            SourcePath = sourceFile.FullName,
            SourceLastWriteTimeUtcTicks = sourceFile.LastWriteTimeUtc.Ticks,
            SourceLength = sourceFile.Length,
            JellyfinImagePath = existingImage.Path ?? string.Empty,
            JellyfinDateModifiedUtcTicks = existingImage.DateModified.ToUniversalTime().Ticks
        };
        _isDirty = true;
    }

    private static string BuildKey(Guid itemId, ImageType type) => $"{itemId:N}_{type}";
}
