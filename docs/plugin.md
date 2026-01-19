# Posterizarr Plugin for Jellyfin & Emby

**Middleware for asset lookup. Maps local assets to library items as posters, backgrounds, or titlecards.**

## Overview

The Posterizarr Plugin acts as a local asset proxy for Jellyfin and Emby. It is designed to work alongside the [Posterizarr](https://github.com/fscorrupt/posterizarr) automation script, allowing your media server to utilize locally generated or managed assets (posters, backgrounds, title cards) as metadata.

!!! important
    This middleware does not allow you to browse, search, or download assets.
    Its sole purpose is to replace the default artwork by mapping library items to your local file system.

## Features

* **Local Asset Mapping:** Maps local files to library items without replacing original metadata permanently in some configurations.
* **Metadata Provider:** Registers as a metadata provider for images.
* **Support for Multiple Asset Types:** Handles Posters, Backgrounds (Fanart), and Title Cards.
* **Cross-Platform Support:** Specifically tailored builds for both Jellyfin (10.9+) and Emby (4.8+).

## Installation

!!! warning
    Only use this if you are not syncing from Plex, as it will overwrite your synced items with locally created assets from Posterizarr.

## Installation

### For Jellyfin (via Repository)
1.  Open your Jellyfin **Dashboard**.
2.  Navigate to **Plugins** -> **Repositories**.
3.  Click **Add** and enter the following information:
    * **Repository Name:** Posterizarr
    * **Repository URL:** `https://raw.githubusercontent.com/fscorrupt/posterizarr/main/manifest.json`
4.  Navigate to the **Catalog** tab.
5.  Find **Posterizarr** under the **Metadata** category.
6.  Click **Install** and choose the latest version.
7.  **Restart** your server.

### For Emby (Manual Installation)
Because Emby requires platform-specific assemblies, you must install the dedicated Emby build manually:
1.  Go to the **[Releases](https://github.com/fscorrupt/posterizarr/releases)** page of this repository.
2.  Download the latest `Posterizarr.Plugin_Emby_vX.X.X.zip`.
3.  Extract the `Posterizarr.Plugin.dll` from the ZIP file.
4.  Place the `.dll` into your Emby **plugins** folder (e.g., `/app/emby/programdata/plugins` or `/config/plugins`).
5.  **Restart** your Emby server.

## Configuration

1. After restarting, go to **Plugins** → **Installed Plugins** and click **Posterizarr**.
2. Click on **"Settings"**.
3. Configure your **Root Asset Folder Path** (the directory where your curated images are stored).
4. **Save** the settings.
5. Go to your **Dashboard** -> **Libraries**.
6. Manage a library (e.g., Movies).
7. Enable **Posterizarr** under the **Image Fetchers** settings.
8. Ensure it is prioritized according to your preferences.
9. Refresh metadata (Search for missing metadata → **Replace existing images**) for your library to pick up local assets.

## Developer Notes
This plugin uses conditional compilation to support both Jellyfin and Emby APIs from a single codebase:
* **Jellyfin Build:** Uses NuGet packages and standard .NET `HttpResponseMessage`.
* **Emby Build:** Uses local DLL references and Emby's `HttpResponseInfo`.