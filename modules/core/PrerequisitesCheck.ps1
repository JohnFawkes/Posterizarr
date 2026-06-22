#region Prerequisites Check
$fileExtensions = @(".otf", ".ttf", ".otc", ".ttc", ".png")

# Initialize Other Variables
$SeasonsTemp = $null
$SeasonNames = $null
$SeasonNumbers = $null
$SeasonRatingkeys = $null
$ApplyTextInsteadOfLogo = $null

# Define cross-platform paths
$LogsPath = Join-Path $global:ScriptRoot 'Logs'
$TempPath = Join-Path $global:ScriptRoot 'temp'
$TestPath = Join-Path $global:ScriptRoot 'test'
$global:OverlayPath = Join-Path $global:ScriptRoot 'Overlayfiles'

# Invoke ImageMagick Checks
InvokeIMChecks

# Create directories if they don't exist

if (!(Test-Path $AssetPath)) {
    if ($global:OSType -ne "Win32NT" -and $AssetPath -eq 'P:\assets') {
        Write-Entry -Message 'Please change default asset Path...' -Path $global:configLogging -Color Red -log Error
        # Clear Running File
        HandleScriptExit -Message "Default asset path"
    }
    New-Item -ItemType Directory -Path $AssetPath -Force | Out-Null
}

# Check directory perms
Test-PathPermissions -PathToTest $AssetPath
Test-PathPermissions -PathToTest $BackupPath
Test-PathPermissions -PathToTest $ManualAssetPath

if ($ForceRunningDeletion -eq 'true') {
    if (Test-Path $CurrentlyRunning) {
        try {
            Remove-Item -LiteralPath $CurrentlyRunning -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Entry -Message "Failed to delete '$CurrentlyRunning'." -Path $global:configLogging -Color Red -log Error
            Write-Entry -Subtext "Reason: $($_.Exception.Message)" -Path $global:configLogging -Color Yellow -log Error
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
        }
    }
}

if (Test-Path $CurrentlyRunning) {
    Write-Entry -Message "Another Posterizarr instance already running, exiting now..." -Path $global:configLogging -Color Yellow -log Warning
    Write-Entry -Subtext "If its a false positive message you can manually delete the 'Posterizarr.Running' file in temp dir..." -Path $global:configLogging -Color Cyan -log Warning
    if ($global:UptimeKumaUrl) {
        Send-UptimeKumaWebhook -status "down" -msg "Another instance running"
    }
    Exit
}
Else {
    $RunMode = "Normal"

    if ($Tautulli) {
        $RunMode = "Tautulli"
        Write-Entry -Message "Tautulli Recently Added running file created..." -Path $global:configLogging -Color White -log Info
    }
    Elseif ($ArrTrigger) {
        $RunMode = "arr"
        Write-Entry -Message "Arr Recently Added running file created..." -Path $global:configLogging -Color White -log Info
    }
    Elseif ($Testing) {
        $RunMode = "Testing"
        Write-Entry -Message "Testing running file created..." -Path $global:configLogging -Color White -log Info
    }
    Elseif ($Manual) {
        $RunMode = "Manual"
        Write-Entry -Message "Manual running file created..." -Path $global:configLogging -Color White -log Info
    }
    Elseif ($SyncJelly) {
        $RunMode = "SyncJelly"
        Write-Entry -Message "SyncJelly running file created..." -Path $global:configLogging -Color White -log Info
    }
    Elseif ($SyncEmby) {
        $RunMode = "SyncEmby"
        Write-Entry -Message "SyncEmby running file created..." -Path $global:configLogging -Color White -log Info
    }
    Elseif ($Backup) {
        $RunMode = "Backup"
        Write-Entry -Message "Backup running file created..." -Path $global:configLogging -Color White -log Info
    }
    Elseif ($PosterReset) {
        $RunMode = "Reset"
        Write-Entry -Message "Reset running file created..." -Path $global:configLogging -Color White -log Info
    }
    Else {
        Write-Entry -Message "Posterizarr running file created..." -Path $global:configLogging -Color White -log Info
    }

    New-Item -Path $CurrentlyRunning -Force -Value $RunMode | Out-Null
}
# Delete all files and subfolders within the temp directory
if (Test-Path $TempPath) {
    Get-ChildItem -Path (Join-Path $TempPath '*') -Recurse -Exclude 'Posterizarr.Running', 'font_preview*' | Remove-Item -Force
    Write-Entry -Message "Deleting temp folder: $TempPath" -Path $global:configLogging -Color White -log Info
}
if ($Testing) {
    if ((Test-Path $TestPath)) {
        Remove-Item -Path (Join-Path $TestPath '*') -Recurse -Force
        Write-Entry -Message "Deleting test folder: $TestPath" -Path $global:configLogging -Color White -log Info
    }
}

# Test and download files if they don't exist
if ($config.PrerequisitePart.overlayfile -eq 'overlay.png' -or $config.PrerequisitePart.seasonoverlayfile -eq 'overlay.png') {
    Test-And-Download -url "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/Overlayfiles/overlay.png" -destination (Join-Path $global:OverlayPath 'overlay.png')
}
if ($config.PrerequisitePart.overlayfile -eq 'overlay-innerglow.png' -or $config.PrerequisitePart.seasonoverlayfile -eq 'overlay-innerglow.png') {
    Test-And-Download -url "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/Overlayfiles/overlay-innerglow.png" -destination (Join-Path $global:OverlayPath 'overlay-innerglow.png')
}
if ($config.PrerequisitePart.backgroundoverlayfile -eq 'backgroundoverlay.png' -or $config.PrerequisitePart.titlecardoverlayfile -eq 'backgroundoverlay.png') {
    Test-And-Download -url "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/Overlayfiles/backgroundoverlay.png" -destination (Join-Path $global:OverlayPath 'backgroundoverlay.png')
}
if ($config.PrerequisitePart.backgroundoverlayfile -eq 'backgroundoverlay-innerglow.png' -or $config.PrerequisitePart.titlecardoverlayfile -eq 'backgroundoverlay-innerglow.png') {
    Test-And-Download -url "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/Overlayfiles/backgroundoverlay-innerglow.png" -destination (Join-Path $global:OverlayPath 'backgroundoverlay-innerglow.png')
}
if ($config.PrerequisitePart.font -eq 'Rocky.ttf' -or $config.PrerequisitePart.backgroundfont -eq 'Rocky.ttf' -or $config.PrerequisitePart.titlecardfont -eq 'Rocky.ttf' -or $config.PrerequisitePart.RTLFont -eq 'Rocky.ttf') {
    Test-And-Download -url "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/Overlayfiles/Rocky.ttf" -destination (Join-Path $global:OverlayPath 'Rocky.ttf')
}
if ($config.PrerequisitePart.font -eq 'Colus-Regular.ttf' -or $config.PrerequisitePart.backgroundfont -eq 'Colus-Regular.ttf' -or $config.PrerequisitePart.titlecardfont -eq 'Colus-Regular.ttf' -or $config.PrerequisitePart.RTLFont -eq 'Colus-Regular.ttf') {
    Test-And-Download -url "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/Overlayfiles/Colus-Regular.ttf" -destination (Join-Path $global:OverlayPath 'Colus-Regular.ttf')
}

# Write log message
Write-Entry -Message "Old log files cleared..." -Path $global:configLogging -Color White -log Info
# Display Current Config settings:
Write-Entry -Message "Current Config settings:" -Path $global:configLogging -Color DarkMagenta -log Info
Output-ConfigJson -obj $config
# Starting main Script now...
Write-Entry -Message "Starting main Script now..." -Path $global:configLogging -Color Green -log Info

# Fix asset path based on OS (do it here so that we see what is in config.json versus what script should use)
if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
    $AssetPath = $AssetPath.Replace('\', '/')
}
else {
    $AssetPath = $AssetPath.Replace('/', '\')
}

# Fix backup path based on OS (do it here so that we see what is in config.json versus what script should use)
if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
    $BackupPath = $BackupPath.Replace('\', '/')
}
else {
    $BackupPath = $BackupPath.Replace('/', '\')
}

# Migration block: Only run this when migration is needed
$DoMigration = Get-ChildItem -Path $global:ScriptRoot -File | Where-Object { $_.Extension -in $fileExtensions } -ErrorAction SilentlyContinue
if ($DoMigration.Count -gt 0) {
    Write-Entry -Message "Migration needed: Found $($DoMigration.Count) files to migrate." -Path $global:configLogging -Color Yellow -log Info

    foreach ($file in $DoMigration) {
        try {
            Write-Entry -Subtext "Trying to migrate '$($file.Name)' from ScriptRoot to OverlayPath..." -Path $global:configLogging -Color Cyan -log Debug
            $destinationPath = Join-Path -Path $global:OverlayPath -ChildPath $file.Name

            Move-Item -LiteralPath $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
            Write-Entry -Subtext "Migrated File: '$($file.Name)' from ScriptRoot to OverlayPath..." -Path $global:configLogging -Color Cyan -log Info
        }
        catch {
            Write-Entry -Subtext "Error migrating file '$($file.Name)': $_" -Path $global:configLogging -Color Red -log Error
        }
    }
}

# Always copy files from OverlayPath to temp folder
$files = Get-ChildItem -Path $global:OverlayPath -File | Where-Object { $_.Extension -in $fileExtensions } -ErrorAction SilentlyContinue
foreach ($file in $files) {
    try {
        Write-Entry -Subtext "Trying to copy '$($file.Name)' into temp dir..." -Path $global:configLogging -Color Cyan -log Debug
        $destinationPath = Join-Path -Path (Join-Path -Path $global:ScriptRoot -ChildPath 'temp') -ChildPath $file.Name

        if (!(Test-Path -LiteralPath $destinationPath)) {
            Copy-Item -Path $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
            Write-Entry -Subtext "Found File: '$($file.Name)' in OverlayPath - copying it into temp folder..." -Path $global:configLogging -Color Cyan -log Info
        }

        # Font handling...
        if ($file.Extension -match "\.(ttf|otf)$" -and $env:POSTERIZARR_NON_ROOT -eq 'TRUE') {
            $fontDestination = Join-Path -Path $Font_Cache -ChildPath $file.Name
            Write-Entry -Subtext "Copying font '$($file.Name)' to ImageMagick cache..." -Path $global:configLogging -Color Cyan -log Info
            Copy-Item -Path $file.FullName -Destination $fontDestination -Force -ErrorAction Stop
            if (!(Test-Path -Path $IM_Font_Cache)) {
                New-Item -ItemType Directory -Path $IM_Font_Cache -Force | Out-Null
            }
        }
    }
    catch {
        Write-Entry -Subtext "Error copying file '$($file.Name)': $_" -Path $global:configLogging -Color Red -log Error
    }
}


# Refresh font cache if any fonts were copied
if ($files.Extension -match "\.(ttf|otf)$" -and $env:POSTERIZARR_NON_ROOT -eq 'TRUE') {
    Write-Entry -Subtext "Updating ImageMagick font cache..." -Path $global:configLogging -Color Green -log Info
    & fc-cache -fv 1> $null 2> $null
}

CheckJsonPaths -font "$font" -RTLfont "$RTLfont" -backgroundfont "$backgroundfont" -titlecardfont "$titlecardfont" -Posteroverlay "$DefaultPosteroverlay" -ShowPosteroverlay "$DefaultShowPosteroverlay" -Backgroundoverlay "$DefaultBackgroundoverlay" -ShowBackgroundoverlay "$DefaultShowBackgroundoverlay" -titlecardoverlay "$Defaulttitlecardoverlay" -Collectionoverlay "$collectionoverlay" -Seasonoverlay "$Seasonoverlay" -Posteroverlay4k "$4kposter" -Posteroverlay1080p "$1080pPoster" -Backgroundoverlay4k "$4kBackground" -Backgroundoverlay1080p "$1080pBackground" -TCoverlay4k "$4kTC" -TCoverlay1080p "$1080pTC" -Posteroverlay4KDoVi "$4KDoVi" -Posteroverlay4KHDR10 "$4KHDR10" -Posteroverlay4KDoViHDR10 "$4KDoViHDR10" -Backgroundoverlay4KDoVi "$4KDoViBackground" -Backgroundoverlay4KHDR10 "$4KHDR10Background" -Backgroundoverlay4KDoViHDR10 "$4KDoViHDR10Background" -TCoverlay4KDoVi "$4KDoViTC" -TCoverlay4KHDR10 "$4KHDR10TC" -TCoverlay4KDoViHDR10 "$4KDoViHDR10TC"
# Check Plex now:
if (!$SyncJelly -and !$SyncEmby) {
    if ($UsePlex -eq 'true') {
        [xml]$Libs = CheckPlexAccess -PlexUrl $PlexUrl -PlexToken $PlexToken
    }

    if ($UseJellyfin -eq 'true') {
        # Check Jellyfin now:
        CheckJellyfinAccess -JellyfinUrl $JellyfinUrl -JellyfinApi $JellyfinAPIKey
    }
    if ($UseEmby -eq 'true') {
        # Check Emby now:
        CheckEmbyAccess -EmbyUrl $EmbyUrl -EmbyAPI $EmbyAPIKey
    }
}
# Check overlay artwork for poster, background, and titlecard dimensions
Write-Entry -Message "Checking size of overlay files..." -Path $global:configLogging -Color White -log Info
CheckOverlayDimensions -Posteroverlay "$DefaultPosteroverlay" -ShowPosteroverlay "$DefaultShowPosteroverlay" -Backgroundoverlay "$DefaultBackgroundoverlay" -ShowBackgroundoverlay "$DefaultShowBackgroundoverlay" -titlecardoverlay "$Defaulttitlecardoverlay" -PosterSize "$PosterSize" -BackgroundSize "$BackgroundSize" -Collectionoverlay "$collectionoverlay" -Seasonoverlay "$Seasonoverlay" -Posteroverlay4k "$4kposter" -Posteroverlay1080p "$1080pPoster" -Backgroundoverlay4k "$4kBackground" -Backgroundoverlay1080p "$1080pBackground" -TCoverlay4k "$4kTC" -TCoverlay1080p "$1080pTC" -Posteroverlay4KDoVi "$4KDoVi" -Posteroverlay4KHDR10 "$4KHDR10" -Posteroverlay4KDoViHDR10 "$4KDoViHDR10" -Backgroundoverlay4KDoVi "$4KDoViBackground" -Backgroundoverlay4KHDR10 "$4KHDR10Background" -Backgroundoverlay4KDoViHDR10 "$4KDoViHDR10Background" -TCoverlay4KDoVi "$4KDoViTC" -TCoverlay4KHDR10 "$4KHDR10TC" -TCoverlay4KDoViHDR10 "$4KDoViHDR10TC"

# Check if the FanartTvAPI module is installed
$module = Get-Module -ListAvailable -Name FanartTvAPI

if (-not $module) {
    # Try to install the module
    try {
        Install-Module -Name $moduleName -Force -SkipPublisherCheck -AllowPrerelease -Scope AllUsers
        Write-Entry -Message "FanartTvAPI Module missing, installing it for you..." -Path $global:configLogging -Color Red -log Error
        $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

        Write-Entry -Subtext "FanartTvAPI Module installed, importing it now..." -Path $global:configLogging -Color Green -log Info
        Import-Module -Name FanartTvAPI
    }
    catch {
        Write-Host "Failed to install $moduleName module. Error: $_"
    }
}

# Only connect if DisableOnlineAssetFetch is not set to false
if ($global:DisableOnlineAssetFetch -eq 'false') {
    # Add Fanart API
    Add-FanartTvAPIKey -Api_Key $FanartTvAPIKey

    # Check TMDB Token before building the Header.
    if ($global:tmdbtoken.Length -le '35') {
        Write-Entry -Message "TMDB Token is too short, you may have used the API key in your config file. Please use the 'API Read Access Token'." -Path $global:configLogging -Color Red -log Error
        # Clear Running File
        HandleScriptExit -Message "Wrong TMDB token"
    }

    $maxRetries = 6
    $retryCount = 0
    $success = $false
    Write-Entry -Message "Trying to receive a TVDB Token..." -Path $global:configLogging -Color White -log Info

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            # tvdb token Header
            $global:apiUrl = "https://api4.thetvdb.com/v4/login"
            if ($global:tvdbpin) {
                $global:requestBody = @{
                    apikey = $global:tvdbapi
                    pin    = $global:tvdbpin
                } | ConvertTo-Json
            }
            Else {
                $global:requestBody = @{
                    apikey = $global:tvdbapi
                } | ConvertTo-Json
            }
            # tvdb Header
            $global:tvdbtokenheader = @{
                'accept'       = 'application/json'
                'Content-Type' = 'application/json'
            }

            # Make tvdb the POST request
            $global:tvdbtoken = (Invoke-RestMethod -Uri $global:apiUrl -Headers $global:tvdbtokenheader -Method Post -Body $global:requestBody).data.token
            $global:tvdbheader = @{}
            $global:tvdbheader.Add("accept", "application/json")
            $global:tvdbheader.Add("Authorization", "Bearer $global:tvdbtoken")

            if ($global:tvdbtoken) {
                $success = $true
                Write-Entry -Subtext "Successfully received a TVDB Token" -Path $global:configLogging -Color Green -log Info
            }

        }
        catch {
            $retryCount++

            if ($retryCount -lt $maxRetries) {
                Start-Sleep -Seconds 10  # Wait for 10 seconds before the next retry
            }
            else {
                if ($global:FavProvider -eq 'TVDB') {
                    Write-Entry -Subtext "Could not receive a TVDB Token - $($retryCount)/$($maxRetries) - you may have used an legacy API key in your config file. Please use an 'Project Api Key'" -Path $global:configLogging -Color Red -log Error
                    $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                    # Clear Running File
                    HandleScriptExit -Message "Could not receive a TVDB Token"
                }
                Else {
                    Write-Entry -Subtext "Could not receive a TVDB Token - $($retryCount)/$($maxRetries) - you may have used an legacy API key in your config file. Please use an 'Project Api Key'" -Path $global:configLogging -Color Red -log Error
                    $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                    break
                }
            }
        }
    }

    # tmdb Header
    $global:headers = @{}
    $global:headers.Add("accept", "application/json")
    $global:headers.Add("Authorization", "Bearer $global:tmdbtoken")
}
# Plex Headers
$extraPlexHeaders = @{
    'X-Plex-Container-Size' = '1000'
}

#### MAIN SCRIPT START ####
