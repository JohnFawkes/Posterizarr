# Posterizarr PowerShell Scripts Architecture & Documentation

This document provides a comprehensive technical overview of all `.ps1` (PowerShell) scripts within the Posterizarr project. It is intended for developers and contributors looking to understand the codebase architecture, the purpose of each module, and where to add or modify features when submitting Pull Requests.

> **Note**: Scripts located in `node_modules` (under the `webui` folder) are excluded from this documentation as they belong to third-party Node.js dependencies.

---

## Architecture Overview
Posterizarr relies on a modular PowerShell architecture:

1. **Entry Points (`Root` & `modes`)**: Scripts that initialize the environment and dictate the operational flow (e.g., processing an entire library vs. a single item from an Arr webhook).
2. **Core Settings (`core`)**: Setup prerequisites and define global configuration state (`$global:` variables).
3. **Business Logic (`functions`)**: Reusable modules split by domain (API integrations, Image Processing, System Utilities, Notifications).

---

## 1. Root Execution Scripts

### Posterizarr.ps1

**Purpose**: The primary entry point for manual execution or scheduled tasks. It bootstraps the application, dot-sources the required modules, and launches the appropriate mode script based on user arguments or configuration.

### Start.ps1

**Purpose**: An initialization and maintenance wrapper, commonly used in Docker or scheduled environments.
**Key Functions:**

- `ScriptSchedule`: Keeps the script running in a loop based on the user's configured schedule interval.
- `GetLatestScriptVersion` / `CompareScriptVersion`: Checks the GitHub API for new releases and compares it against the local version.
- `CopyAssetFiles`: Ensures that default assets (like borders or overlay images) are copied to the active directory.
- `CheckJson` / `Ensure-WebUIConfig`: Validates and repairs the `config.json` schema and Web UI configurations before the main process starts.

---

## 2. Core Modules (`modules\core\`)

### PrerequisitesCheck.ps1

**Purpose**: A linear script that validates the host environment before execution. It ensures that necessary commands (like `magick`), environment variables, and folder structures exist.
*Contribution Tip*: If you introduce a new binary dependency or require a specific OS permission, add the check here.

### Variables.ps1

**Purpose**: Initializes and defines the `$global:` scope variables and configuration paths. It reads the user's `config.json` and maps it to variables used throughout the script.
*Contribution Tip*: If you add a new configuration parameter to `config.json`, map it to a global variable in this script so other modules can consume it safely.

---

## 3. Domain Functions (`modules\functions\`)

### ApiHandlers.ps1

**Purpose**: The integration layer for external metadata providers. Handles HTTP requests to TMDB, TVDB, Fanart, and IMDB to fetch raw images and logos.
**Key Functions:**

- `GetTMDBLogo`, `GetTVDBLogo`, `GetFanartLogo`: Queries the respective APIs for clearlogos. They handle language priorities and vote sorting based on global configs (uses the `Celerium.FanartTV` module for Fanart integrations).
- `GetTMDBMoviePoster`, `GetTMDBShowBackground`, etc.: Functions specifically tailored to endpoint structures for fetching raw posters and backgrounds.
- `GetPlexArtwork`: Fetches metadata and current artwork URLs from Plex.

### BackupRestore.ps1

**Purpose**: Contains massive library iteration operations for backup, restore, and reset features.
**Key Functions:**

- `MassDownloadPlexArtwork`, `MassDownloadJellyEmbyArtwork`: Loops over media libraries to pull down existing artwork for local processing.
- `MassRestorePlexArtwork`, `MassRestoreJellyEmbyArtwork`: Pushes artwork from the local backup directory directly to the media server.

### JellyEmby.ps1

**Purpose**: Core logic and API integration for Jellyfin and Emby media servers.
**Key Functions:**

- `CheckJellyfinAccess`, `CheckEmbyAccess`: Validates connection and API keys for the respective servers.

### Plex.ps1

**Purpose**: Core logic and API integration for the Plex media server.
**Key Functions:**

- `CheckPlexAccess`: Validates API keys and connection to the Plex server.
- `GetPlexArtworkUrl`: Fast-scans Plex URLs for existing EXIF data.

### AssetReset.ps1

**Purpose**: Handles library-wide asset resets, deleting custom metadata to restore defaults.
**Key Functions:**

- `Reset-PlexLibraryPictures`, `Reset-PlexLibraryLogos`: Triggers library-wide resets to default metadata.

### AssetUpload.ps1

**Purpose**: Consolidates the asset pushing logic across different media servers.
**Key Functions:**

- `Push-PlexAsset`, `Push-EmbyAsset`: Direct asset pushing to individual items on Plex/Emby.
- `UploadOtherMediaServerArtwork`: Handles pushing generated image assets to Jellyfin or Emby.

### Sync.ps1

**Purpose**: Cross-server syncing logic to keep multiple media servers consistent.
**Key Functions:**

- `SyncPlexArtwork`: Compares artwork between Plex and Jellyfin/Emby and pushes missing/updated assets across servers.

### AssetCache.ps1

**Purpose**: Responsible for rapidly indexing the asset directory.
**Key Functions:**

- `Get-AssetHashtable`: Centralized, highly optimized function that uses native `.NET` `EnumerateFiles` to recursively build a hashtable of all available local posters and artworks. It calculates total sizes and determines whether artwork exists without triggering slow file-system scans.

### CoreGeneration.ps1

**Purpose**: The orchestration engine for image creation. It glues together `ApiHandlers` and `ImageMagick`.
**Key Functions:**

- `Invoke-MoviePosterCreation`: Orchestrates the movie poster workflow: Fetches the raw background -> Determines text/logo overlay -> Calls `ImageMagick` to apply borders/text -> Returns the path to the completed poster.
- `Invoke-ShowPosterCreation`: Similar orchestration for TV Shows and Season posters.
- `Invoke-TitleCardCreation`: Orchestrates episode-level Title Card generation. Searches for TMDB/TVDB/Plex artwork with provider fallbacks, processes the image (resizing, text rendering, borders), and pushes the result to the media server.

### ImageMagick.ps1

**Purpose**: A wrapper around the `magick` CLI. It abstracts the complex ImageMagick arguments into reusable PowerShell functions.
**Key Functions:**

- `InvokeMagickCommand`: The central wrapper that actually executes `magick.exe`. Captures stdout/stderr for logging.
- `Get-OptimalPointSize`: Dynamically calculates the maximum font size that will fit a given text string within a constrained pixel bounding box. Very useful for title generation.
- `New-TextSizeCacheKey`, `Set-TextSizeCacheEntry`: Caches calculated font sizes to speed up future runs for the same titles.
- `CheckOverlayDimensions`, `Test-Dimension`: Ensures that user-provided border or overlay images match the aspect ratio and resolution of the base poster before combining them.

### Notifications.ps1

**Purpose**: Manages all outbound communications and telemetry.
**Key Functions:**

- `SendMessage`: A router function that determines which notification channels (Discord, Webhooks) are enabled.
- `Build-DiscordPayload`, `Push-ObjectToDiscord`: Constructs the rich embed JSON for Discord webhooks and sends it.
- `Send-UptimeKumaWebhook`: Pings a health check endpoint.
- `Send-PosterizarrTelemetry`: Sends anonymized usage statistics (if opted-in).

### System.ps1

**Purpose**: General utility and helper functions.
**Key Functions:**

- `Test-PathPermissions`: Validates read/write access to media folders before attempting generation.
- `CheckJson`, `CheckJsonPaths`: Schema validation and path sanitization for config files.
- `RotateLogs`, `Write-Entry`: Centralized logging engine with color-coded console output and file rotation.
- `RedactUrl`, `RedactKey`: Strips API keys and tokens from strings before writing them to log files to ensure security.

---

## 4. Operation Modes (`modules\modes\`)

These scripts represent the different "Modes" the application can run in. They do not define functions but instead represent linear logic flows that dot-source and call the functions described above.

- **`NormalMode.ps1`**: The default mode. Iterates through all configured media server libraries and processes every item sequentially.
- **`ArrMode.ps1`**: Designed to be triggered by Radarr/Sonarr custom scripts (`ArrTrigger.sh`) or webhooks (`/api/webhook/arr`). Parses TMDB/TVDB IDs and media paths to process *only* the newly imported item. Also dispatches callbacks to **Agregarr** if configured.
- **`TautulliMode.ps1`**: Triggered by Tautulli webhooks or `trigger.py` on 'Recently Added' events to process new items without a full library scan.
- **`ManualMode.ps1`**: Processes a specific media item using interactive prompts or CLI switches:
  - Switches: `-MoviePosterCard`, `-ShowPosterCard`, `-SeasonPoster`, `-CollectionCard`, `-BackgroundCard`, `-TitleCard`.
  - Arguments: `-PicturePath`, `-Titletext`, `-FolderName`, `-LibraryName`, `-SeasonPosterName`, `-EPTitleName`, `-EpisodeNumber`.
- **`SyncMode.ps1`**: Cross-server synchronization mode (`-SyncJelly`, `-SyncEmby`). Compares image hashes between Plex and Jellyfin/Emby and mirrors artwork.
- **`EmbyJellyMode.ps1`**: Optimized execution loop for setups running Jellyfin or Emby without Plex (`UseOtherMediaServer = "true"`).
- **`BackupMode.ps1`**: Downloads existing artwork and EXIF metadata from media servers to the local backup path (`/assetsbackup` or `BackupPath`).
- **`RestoreMode.ps1`**: Pushes artwork from the local backup directory back to the media server, skipping regeneration. Supports granular targeting:
  - `-RestoreLibrary "Movies"`: Restricts restore to a single library.
  - `-RestoreItem "Alien (1979)"`: Restores assets for a specific item (by title, original title, or folder name).
  - `-RestoreType "poster"`: Restores only specific asset categories (`poster`, `background`, `season`, `episode`, `titlecard`).
- **`LogoUpdaterMode.ps1`**: Dedicated clearlogo management engine:
  - `-LogoUpdater`: Scans libraries for missing clearlogos and pushes found assets to Plex.
  - `-LogoRevert`: Uses embedded fingerprints to detect and delete only Posterizarr-uploaded logos, leaving user-uploaded logos intact.
  - `-ForceReplace`: Overwrites existing logos on the server.
  - `-LibraryName`: Targets a specific library or `"all"`.
- **`PosterresetMode.ps1`**: Resets posters in a specified library back to the media server's default scraped art:
  - `-LibraryToReset "Movies"`: Specifies the target library.
- **`TestingMode.ps1`**: Generates pink dummy posters, backgrounds, and title cards under `./test` with varying text lengths and styles, allowing safe verification of overlay alignment and typography.

---

## 5. Media Server Plugins & Automation Triggers (`modules/`)

### C# Media Server Plugins
- **`Posterizarr.Plugin/`**: In-tree C# plugin for **Jellyfin**. Hooks into Jellyfin's item added and metadata refresh events to trigger Posterizarr processing automatically.
- **`Posterizarr.Plugin.Emby/`**: In-tree C# plugin for **Emby**, providing native event hooks and seamless communication with the Posterizarr backend.

### External Automation Scripts
- **`ArrTrigger.sh`**: Lightweight shell script configured as a Custom Script in Radarr and Sonarr (`On File Import`). Writes `.posterizarr` trigger descriptor files into `/posterizarr/watcher` for file-based containerized triggers.
- **`trigger.py`**: Python notification agent script configured in Tautulli to format and dispatch recently added Plex items to Posterizarr.

---

## Contribution Guidelines
When making a Pull Request:

1. **New API sources** (like adding Trakt or OMDB) should be placed in `modules\functions\ApiHandlers.ps1`.
2. **New Image manipulation logic** (like adding a drop-shadow effect) should be added to `modules\functions\ImageMagick.ps1`.
3. **If you add a new CLI parameter or Config item**, ensure it is parsed in `modules\core\Variables.ps1` and validated in `modules\functions\System.ps1`.
4. Use `Write-Entry` for all logging; avoid using `Write-Host` or `Write-Output` directly to ensure logs are captured to the log files safely.

---

## Reading Logs (Parallel Processing)
When reading the `Scriptlog.log` file, especially during parallel execution, you will see entries like:
```text
[2026-07-20 08:33:01] [INFO]     [T32]  |ApiHandlers.ps1:L.439       |      Searching on TMDB for a movie poster - TMDBID: 599960
```
- **`[INFO]`**: The log severity level.
- **`[T32]`**: The **Worker ID** (Runspace ID). Because multiple media items are processed in parallel, logs from different items will be mixed together. To track the execution flow of a single item, look for lines that share the exact same Worker ID (e.g., all lines with `[T32]`).
- **`|ApiHandlers.ps1:L.439 |`**: The source script and line number where the log entry was generated.
