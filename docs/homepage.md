# Homepage Custom API Integration

You can integrate Posterizarr statistics into your [Homepage](https://gethomepage.dev/) dashboard using the `customapi` widget type. This allows you to display global stats or specific library stats directly on your dashboard.

## Identifying Library Indices

To map specific libraries or collections in the examples below, you need to know their index in the `folders` array returned by the API.

1. Open your browser and navigate to: `http://your-ip:8003/api/assets/stats?api_key=your_api_key`
2. You will see a JSON response like this:

```json
{
  "success": true,
  "stats": {
    "folders": [
      { "name": "Anime Shows", ... }, // Index [0]
      { "name": "TV Shows", ... },    // Index [1]
      { "name": "Kids Shows", ... },  // Index [2]
      ...
    ]
  }
}
```

3. Count the folders starting from **0**. For example:
    - The first folder is `stats.folders[0]`
    - The second folder is `stats.folders[1]`
    - ... and so on.

## Overall Assets & Stats

This example shows how to combine both the `overview` (for missing assets) and `stats` (for counts) endpoints in a single service block using YAML anchors for a cleaner configuration.

!!! important
    This example uses `stats.folders[8]` for Collections. Please look at [Identifying Library Indices](#identifying-library-indices) to find the correct index for your system.

![Overall Assets & Stats](images/Homepage_OverallStats.png)

```yaml
- Posterizarr:
    - Assets:
        icon: https://github.com/fscorrupt/posterizarr/blob/main/docs/images/Logo_Posterizarr.png?raw=true
        widgets:
          - type: customapi
            url: http://your-ip:8003/api/assets/overview?api_key=your_api_key
            display: block
            mappings:
              - field: categories.missing_assets.count
                label: Missing

          - &stats_api
            type: customapi
            url: http://your-ip:8003/api/assets/stats?api_key=your_api_key
            display: block
            mappings:
              - field: stats.posters
                label: Posters
              - field: stats.folders[8].poster_count
                label: Collections
              - field: stats.seasons
                label: Seasons

          - <<: *stats_api
            display: block
            mappings:
              - field: stats.backgrounds
                label: Backgrounds
              - field: stats.titlecards
                label: Titlecards
              - field: stats.total_size
                label: Size
                format: bytes
```

## Global Statistics

To display overall statistics (Total Posters, Seasons, etc.), use the following configuration in your `services.yaml`:

![Global Statistics](images/Homepage_GlobalListStats.png)

```yaml
- Posterizarr Assets:
    icon: https://github.com/fscorrupt/posterizarr/blob/main/docs/images/Logo_Posterizarr.png?raw=true
    widget:
      type: customapi
      url: http://your-ip:8003/api/assets/stats?api_key=your_api_key
      display: list
      mappings:
        - field: stats.posters
          label: Total Posters
        - field: stats.backgrounds
          label: Total Backgrounds
        - field: stats.seasons
          label: Total Seasons
        - field: stats.titlecards
          label: Total Titlecards
        - field: stats.folders[8].poster_count
          label: Total Collections
        - field: stats.total_size
          label: Total Size
          format: bytes
```

## Library-Specific Statistics

You can also create separate widgets for each of your libraries (Anime, TV Shows, Movies, etc.).

### Example: Library Widgets

Here is an example configuration for multiple libraries using YAML anchors for efficiency:

![Library Widgets](images/HomepageMultiLibrary.png)

```yaml
- Posterizarr:
    - Anime Shows:
        widget: &lib_base  # <--- This defines the "lib_base" anchor
          type: customapi
          url: http://your-ip:8003/api/assets/stats?api_key=your_api_key
          mappings:
            - field: stats.folders[0].poster_count
              label: Posters
            - field: stats.folders[0].season_count
              label: Seasons
            - field: stats.folders[0].titlecard_count
              label: Titlecards
            - field: stats.folders[0].size
              label: Size
              format: bytes

    - TV Shows:
        widget:
          <<: *lib_base
          mappings:
            - field: stats.folders[1].poster_count # Only override the field index
              label: Posters
            - field: stats.folders[1].season_count
              label: Seasons
            - field: stats.folders[1].titlecard_count
              label: Titlecards
            - field: stats.folders[1].size
              label: Size
              format: bytes

    - Movies:
        widget:
          <<: *lib_base
          mappings:
            - field: stats.folders[3].poster_count
              label: Posters
            - field: stats.folders[3].size
              label: Size
              format: bytes

    - 4K TV Shows:
        widget:
          <<: *lib_base
          mappings:
            - field: stats.folders[5].poster_count
              label: Posters
            - field: stats.folders[5].season_count
              label: Seasons
            - field: stats.folders[5].titlecard_count
              label: Titlecards
            - field: stats.folders[5].size
              label: Size
              format: bytes
```

### Example: Collections Widget

Since the index for Collections varies between systems, you must first identify it using the guide above. If your Collections are at index `[8]`, your configuration would look like this:

```yaml
- Posterizarr:
    - Collections:
        widget:
          type: customapi
          url: http://your-ip:8003/api/assets/stats?api_key=your_api_key
          mappings:
            - field: stats.folders[8].poster_count
              label: Collection Posters
            - field: stats.folders[8].size
              label: Size
              format: bytes
```

## Available Fields

The following fields are typically available for each folder:

| Field | Description |
| :--- | :--- |
| `poster_count` | Number of posters in the folder |
| `background_count` | Number of backgrounds in the folder |
| `season_count` | Number of seasons (for TV shows) |
| `titlecard_count` | Number of titlecards |
| `size` | Total size of assets in bytes |
| `total_count` | Total file count |

!!! tip
    Use `format: bytes` in Homepage mappings for any field representing file size to ensure it displays in a human-readable format (e.g., GB instead of bytes).
