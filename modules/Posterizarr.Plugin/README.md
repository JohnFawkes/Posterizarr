# Posterizarr Plugin for Jellyfin

**Middleware for asset lookup. Maps local assets to library items as posters, backgrounds, or titlecards.**

## Overview

The Posterizarr Plugin acts as a local asset proxy for Jellyfin. It is designed to work alongside the [Posterizarr](https://github.com/fscorrupt/posterizarr) automation script, allowing your media server to utilize locally generated or managed assets (posters, backgrounds, title cards) as metadata.

> [!IMPORTANT]
> This middleware does not allow you to browse, search, or download assets.
> Its sole purpose is to replace the default artwork by mapping library items to your local file system.

## Features

*   **Local Asset Mapping:** Maps local files to library items without replacing original metadata permanently in some configurations.
*   **Metadata Provider:** Registers as a metadata provider for images.
*   **Support for Multiple Asset Types:** Handles Posters, Backgrounds (Fanart), and Title Cards.

> [!WARNING]
> Only use this if you are not syncing from Plex, as it will overwrite your synced items with locally created assets from Posterizarr.

## Installation

### Via Repository (Recommended)

1.  Open your Jellyfin **Dashboard**.
2.  Navigate to **Plugins** -> **Repositories**.
3.  Click **Add** and enter the following information:
    *   **Repository Name:** Posterizarr
    *   **Repository URL:** `https://raw.githubusercontent.com/fscorrupt/posterizarr/main/manifest.json`
4.  Navigate to the **Catalog** tab.
5.  Find **Posterizarr** under the **Metadata** category.
6.  Click **Install** and choose the latest version.
7.  **Restart** your server.

## Configuration

1. After restarting, go to **Plugins** → **Installed Plugins** and click **Posterizarr**.
1. Click on **"Settings"**
1. Configure your Asset Root Path (the directory where your curated images are stored).
1. Safe it
1. Go to your **Dashboard** -> **Libraries**.
1. Manage a library (e.g., Movies).
1. Enable **Posterizarr** under the **Image Fetchers** settings.
1. Ensure it is prioritized according to your preferences.
1. Refresh metadata (Search for missing metadata → **Replace existing images**) for your library to pick up local assets.

## Scheduled Tasks & Automation

The plugin registers a scheduled background task (default: daily at 02:00 AM) that automatically syncs and refreshes your libraries against local assets.

### Configuring the Sync Schedule

1. Open your Jellyfin **Dashboard**.
2. In the left sidebar under the **Server** section, navigate to **Scheduled Tasks**.
3. Locate the **Posterizarr Sync Task** in the list.
4. Click on the task to customize its triggers:
    * You can configure the task to run on an interval, at a specific time of day (e.g., daily at 3:00 AM), on system startup, or on a weekly schedule.
5. You can also trigger the task manually at any time by clicking the **Play (Run)** button next to it.

## Building from Source

```bash
dotnet publish -c Release -o publish
```

The compiled `Posterizarr.Plugin.dll` will be in the `publish/` directory.