#region Functions
function Test-IsPosterizarrAsset {
    param ([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $buffer = New-Object byte[] 65536
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)

            # Convert to string (Try UTF8 first, then check for typical ASCII)
            $content = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)

            # Returns True if any keywords match
            return $content -match 'posterizarr|overlay|titlecard|created with posterizarr|created with ppm'
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        return $false
    }
}

function HandleScriptExit {
    param (
        [string]$Message,
        [string]$Status = "down"
    )

    Write-Entry -Message $Message -Path $global:configLogging -Color Red -log Error

    # Global Cleanup
    if (Test-Path $CurrentlyRunning) {
        try {
            Remove-Item -LiteralPath $CurrentlyRunning -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Entry -Message "Failed to delete '$CurrentlyRunning'." -Path $global:configLogging -Color Red -log Error
            Write-Entry -Subtext "Reason: $($_.Exception.Message)" -Path $global:configLogging -Color Yellow -log Error
            $global:errorCount++
        }
    }

    # Uptime Kuma Notification
    if ($global:UptimeKumaUrl) {
        Send-UptimeKumaWebhook -status $Status -msg $Message
    }

    # Exit the script entirely
    exit
}
function GetTMDBLogo {
    param(
        [string]$Type
    )
    if ($global:tmdbid) {
        Write-Entry -Subtext "Searching on TMDB for a Logo - TMDBID: $global:tmdbid" -Path $global:configLogging -Color Cyan -log Info
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/$Type/$($global:tmdbid)?append_to_response=images&language=$($global:LogoLanguageOrder[0])&include_image_language=$($global:LogoLanguageOrder -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
        }
        if ($response) {
            if ($response.images.logos) {
                foreach ($lang in $global:LogoLanguageOrder) {
                    if ($lang -ne 'null' -and $lang -ne 'xx') {
                        if ($global:UseClearlogo -eq 'true') {
                            $FavPoster = ($response.images.logos | Where-Object iso_639_1 -eq $lang)
                        }
                    }

                    if ($FavPoster) {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = $FavPoster[0].file_path
                        }
                        Else {
                            $posterpath = (($FavPoster | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                        $global:LogoUrl = "https://image.tmdb.org/t/p/original$posterpath"
                        if ($lang -ne 'null' -and $lang -ne 'xx') {
                            Write-Entry -Subtext "Found Logo with Language '$lang' on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        $global:LogoLanguage = $lang
                        return $global:LogoUrl
                        continue
                    }
                }
            }
            Else {
                Write-Entry -Subtext "No Logo found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
            }
        }
        Else {
            Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error

        }
    }
    Else {
        Write-Entry -Subtext "Cannot search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
}
function GetTVDBLogo {
    param(
        [string]$Type
    )
    if ($global:tvdbid) {
        Write-Entry -Subtext "Searching on TVDB for a Logo - TVDBID: $global:tvdbid" -Path $global:configLogging -Color Cyan -log Info
        try {
            if ($type -eq 'series') {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/$Type/$($global:tvdbid)/artworks" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
            Else {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/$Type/$($global:tvdbid)/extended" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
        }
        catch {
            Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
        }
        if ($response) {
            if ($response.data) {
                foreach ($lang in $global:LogoLanguageOrder) {
                    if ($lang -ne 'null') {
                        if ($global:UseClearart -eq 'true') {
                            if ($Type -eq 'series') {
                                $global:tvdblogo = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '22' } | Sort-Object Score -Descending)
                            }
                            Else {
                                $global:tvdblogo = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '24' } | Sort-Object Score -Descending)
                            }
                        }
                        elseif ($global:UseClearlogo -eq 'true') {
                            if ($Type -eq 'series') {
                                $global:tvdblogo = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '23' } | Sort-Object Score -Descending)
                            }
                            Else {
                                $global:tvdblogo = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '25' } | Sort-Object Score -Descending)
                            }
                        }
                    }

                    if ($global:tvdblogo) {
                        $global:LogoUrl = $global:tvdblogo[0].image
                        Write-Entry -Subtext "Found Logo with Language '$lang' on TVDB" -Path $global:configLogging -Color Blue -log Info
                        $global:LogoLanguage = $lang
                        return $global:LogoUrl
                        continue
                    }
                }
            }
            Else {
                Write-Entry -Subtext "No Logo found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
            }
        }
        Else {
            Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
        }
    }
    Else {
        Write-Entry -Subtext "Cannot search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
}
function GetFanartLogo {
    param(
        [string]$Type
    )
    $global:Fallback = $null
    Write-Entry -Subtext "Searching on Fanart.tv for a Logo" -Path $global:configLogging -Color Cyan -log Info
    $ids = @($global:tmdbid, $global:imdbid)
    $entrytemp = $null

    foreach ($id in $ids) {
        if (-not $id) { continue }

        $entrytemp = Get-FanartTv -Type $Type -id $id -ErrorAction SilentlyContinue
        if (-not $entrytemp) { continue }

        $field = if ($global:UseClearart -eq 'true') {
            if ($Type -eq 'tv') { "hdclearart" } else { "hdmovieclearart" }
        }
        elseif ($global:UseClearlogo -eq 'true') {
            if ($Type -eq 'tv') { "hdtvlogo" } else { "hdmovielogo" }
        }

        if ($field -and $entrytemp.$field) {
            foreach ($lang in $global:LogoLanguageOrder) {
                $matchedLogos = $entrytemp.$field | Where-Object { $_.lang -eq $lang }

                if ($matchedLogos) {
                    $global:LogoUrl = $matchedLogos[0].url
                    $global:LogoLanguage = $lang
                    Write-Entry -Subtext "Found $field with Language '$lang' on FANART" -Path $global:configLogging -Color Blue -log Info
                    return $global:LogoUrl
                }
            }
        }
    }
    if ($null -eq $ids[0] -and $null -eq $ids[1]) {
        Write-Entry -Subtext "Cannot search on FANART, missing IDs..." -Path $global:configLogging -Color Yellow -log Warning
    }
    if (!$global:LogoUrl) {
        Write-Entry -Subtext "No match/logo found on Fanart.tv" -Path $global:configLogging -Color Yellow -log Warning
    }
    Else {
        return $global:LogoUrl
    }
}
function New-PosterizarrSupportZip {
    param(
        [string]$BasePath
    )

    # 0. Timestamp + paths (match Python zip name)
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $stagingDir = Join-Path $BasePath "SupportZip_$timestamp"
    $zipPath = Join-Path $BasePath "posterizarr_support_$timestamp.zip"

    # Base dirs (equivalent to globals in main.py)
    $databaseDir = Join-Path $BasePath "database"
    $logsDir = Join-Path $BasePath "Logs"
    $rotatedDir = Join-Path $BasePath "RotatedLogs"
    $uiLogsDir = Join-Path $BasePath "UILogs"

    # 1. Staging + database subdir
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
    $dbStagingDir = Join-Path $stagingDir "database"
    New-Item -ItemType Directory -Path $dbStagingDir -Force | Out-Null

    # ---------------------------------------------------------------------
    # 2. Copy Log Folders (with ignore rules like Python)
    #    - Logs / RotatedLogs: ignore *.json
    #    - UILogs: keep .json (only ignore pyc/__pycache__/.DS_Store)
    # ---------------------------------------------------------------------

    function Copy-Tree {
        param(
            [string]$Source,
            [string]$Dest,
            [string[]]$ExcludeExtensions = @(),
            [string[]]$ExcludeNames = @()
        )

        if (-not (Test-Path $Source)) { return }

        New-Item -ItemType Directory -Path $Dest -Force | Out-Null

        Get-ChildItem -Path $Source -Recurse | ForEach-Object {
            # Skip excluded names (e.g. __pycache__, .DS_Store)
            if ($ExcludeNames -contains $_.Name) { return }

            # Skip excluded extensions (e.g. .json)
            if ($_.PSIsContainer -eq $false -and $ExcludeExtensions -contains $_.Extension.ToLower()) {
                return
            }

            $relative = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
            $target = Join-Path $Dest $relative

            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Path $target -Force | Out-Null
            }
            else {
                New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
                Copy-Item $_.FullName -Destination $target -Force
            }
        }
    }

    # Logs: ignore *.json (ignore_patterns_logs)
    if (Test-Path $logsDir) {
        Copy-Tree -Source $logsDir -Dest (Join-Path $stagingDir "Logs") `
            -ExcludeExtensions @(".json") `
            -ExcludeNames @("__pycache__", ".DS_Store")
    }

    # RotatedLogs: same rule as Logs
    if (Test-Path $rotatedDir) {
        Copy-Tree -Source $rotatedDir -Dest (Join-Path $stagingDir "RotatedLogs") `
            -ExcludeExtensions @(".json") `
            -ExcludeNames @("__pycache__", ".DS_Store")
    }

    # UILogs: default ignore (no .json exclusion)
    if (Test-Path $uiLogsDir) {
        Copy-Tree -Source $uiLogsDir -Dest (Join-Path $stagingDir "UILogs") `
            -ExcludeExtensions @() `
            -ExcludeNames @("__pycache__", ".DS_Store")
    }

    # ---------------------------------------------------------------------
    # 3. Copy & sanitize databases (mirror Python as closely as possible)
    # ---------------------------------------------------------------------

    # 3a. Copy non-sensitive DBs
    $nonSensitiveDbs = @(
        "media_export.db",
        "runtime_stats.db",
        "server_libraries.db"
    )

    foreach ($dbName in $nonSensitiveDbs) {
        $srcDb = Join-Path $databaseDir $dbName
        if (Test-Path $srcDb) {
            Copy-Item $srcDb -Destination (Join-Path $dbStagingDir $dbName) -Force
        }
    }

    # Copy + sanitize imagechoices.db (via Python sqlite3, like your function)
    $srcImageChoicesDb = Join-Path $databaseDir "imagechoices.db"
    $copiedImageChoicesDb = Join-Path $dbStagingDir "imagechoices.db"

    if (Test-Path $srcImageChoicesDb) {
        Copy-Item $srcImageChoicesDb -Destination $copiedImageChoicesDb -Force

        # The Python snippet below is a near-direct port of your sanitization logic.
        $pyScript = @'
import sqlite3, re, sys

db_path = sys.argv[1]

ALLOWED_PREFIXES = [
    "https://image.tmdb.org",
    "https://artworks.thetvdb.com",
    "https://assets.fanart.tv",
    "https://m.media-amazon.com",
    "https://www.themoviedb.org",
    "https://fanart.tv",
    "https://www.thetvdb.com",
]

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

cursor.execute(
    "SELECT id, DownloadSource FROM imagechoices WHERE DownloadSource LIKE 'http%%'"
)
rows = cursor.fetchall()

updates = []

for row_id, source in rows:
    if not source:
        continue

    sanitized_source = source
    is_allowed = False

    for prefix in ALLOWED_PREFIXES:
        if source.startswith(prefix):
            is_allowed = True
            break

    if not is_allowed:
        sanitized_source = re.sub(r"(https?://)[^/]+", r"\\1[MASKED_HOST]", sanitized_source, count=1)

    sanitized_source = re.sub(r"([?&][^=]*Token=)[^&]+", r"\\1[MASKED_TOKEN]", sanitized_source, flags=re.IGNORECASE)
    sanitized_source = re.sub(r"([?&][^=]*api_key=)[^&]+", r"\\1[MASKED_KEY]", sanitized_source, flags=re.IGNORECASE)
    sanitized_source = re.sub(r"([?&][^=]*pin=)[^&]+", r"\\1[MASKED_PIN]", sanitized_source, flags=re.IGNORECASE)

    if sanitized_source != source:
        updates.append((sanitized_source, row_id))

if updates:
    cursor.executemany(
        "UPDATE imagechoices SET DownloadSource = ? WHERE id = ?", updates
    )
    conn.commit()

conn.close()
'@

        # Write Python snippet to a temp file and execute it against the copied DB
        $tmpPy = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".py")
        Set-Content -Path $tmpPy -Value $pyScript -Encoding UTF8

        $pythonExe = "python"
        & $pythonExe $tmpPy $copiedImageChoicesDb 2>$null

        Remove-Item $tmpPy -Force -ErrorAction SilentlyContinue
    }

    # Sanitize ImageChoices.csv (searches all subdirs)
    $allowedPrefixes = @(
        "https://image.tmdb.org",
        "https://artworks.thetvdb.com",
        "https://assets.fanart.tv",
        "https://m.media-amazon.com",
        "https://www.themoviedb.org",
        "https://fanart.tv",
        "https://www.thetvdb.com"
    )

    $csvFiles = Get-ChildItem -Path $stagingDir -Recurse -Filter "ImageChoices.csv" -File
    $totalSanitizedRows = 0

    foreach ($csv in $csvFiles) {
        $path = $csv.FullName
        try {
            $rows = Import-Csv -Path $path -Delimiter ';'
            if (-not $rows) { continue }

            # Ensure required columns exist
            $props = $rows[0].PSObject.Properties.Name
            if (-not ($props -contains 'Download Source' -and $props -contains 'Fav Provider Link')) {
                continue
            }

            $sanitizedInFile = 0

            foreach ($row in $rows) {
                $origDownload = $row.'Download Source'
                $origFav = $row.'Fav Provider Link'

                $newDownload = $origDownload
                $newFav = $origFav

                if ($newDownload -and $newDownload -like 'http*') {
                    $isAllowed = $false
                    foreach ($prefix in $allowedPrefixes) {
                        if ($newDownload.StartsWith($prefix)) { $isAllowed = $true; break }
                    }

                    if (-not $isAllowed) {
                        $newDownload = $newDownload -replace '(https?://)[^/]+', '$1[MASKED_HOST]'
                    }

                    $newDownload = $newDownload -replace '([?&][^=]*Token=)[^&]+', '$1[MASKED_TOKEN]'
                    $newDownload = $newDownload -replace '([?&][^=]*api_key=)[^&]+', '$1[MASKED_KEY]'
                    $newDownload = $newDownload -replace '([?&][^=]*pin=)[^&]+', '$1[MASKED_PIN]'
                }

                if ($newFav -and $newFav -like 'http*') {
                    $isAllowedFav = $false
                    foreach ($prefix in $allowedPrefixes) {
                        if ($newFav.StartsWith($prefix)) { $isAllowedFav = $true; break }
                    }

                    if (-not $isAllowedFav) {
                        $newFav = $newFav -replace '(https?://)[^/]+', '$1[MASKED_HOST]'
                    }

                    $newFav = $newFav -replace '([?&][^=]*Token=)[^&]+', '$1[MASKED_TOKEN]'
                    $newFav = $newFav -replace '([?&][^=]*api_key=)[^&]+', '$1[MASKED_KEY]'
                    $newFav = $newFav -replace '([?&][^=]*pin=)[^&]+', '$1[MASKED_PIN]'
                }

                if ($newDownload -ne $origDownload -or $newFav -ne $origFav) {
                    $sanitizedInFile++
                    $row.'Download Source' = $newDownload
                    $row.'Fav Provider Link' = $newFav
                }
            }

            if ($sanitizedInFile -gt 0) {
                $totalSanitizedRows += $sanitizedInFile
            }

            # Overwrite CSV with sanitized rows (Manual write to force QUOTE_ALL)
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            $sw = [System.IO.StreamWriter]::new($path, $false, $utf8NoBom)

            # Get headers from the first row object
            $headers = $rows[0].PSObject.Properties.Name

            # Write headers (all quoted)
            $headerLine = ($headers | ForEach-Object { '"{0}"' -f $_.Replace('"', '""') }) -join ';'
            $sw.WriteLine($headerLine)

            # Write data rows (all quoted)
            foreach ($r in $rows) {
                $line = ($headers | ForEach-Object {
                        $val = $r.$_
                        '"{0}"' -f "$val".Replace('"', '""')
                    }) -join ';'
                $sw.WriteLine($line)
            }
            $sw.Dispose()
        }
        catch {
            # Log-like behavior; in PS script we can just Write-Host or ignore
            Write-Host "[SupportZip] Failed to sanitize $($csv.Name): $($_.Exception.Message)"
        }
    }

    # ---------------------------------------------------------------------
    # 4. Create ZIP file
    # ---------------------------------------------------------------------
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    # Calculate the ABSOLUTE path for the zip file, because we are about to change directories
    $absZipPath = $zipPath
    if (-not [System.IO.Path]::IsPathRooted($zipPath)) {
        $absZipPath = Join-Path (Get-Location).Path $zipPath
    }

    # Enter the staging directory to force Compress-Archive
    # to treat the *contents* as the root of the zip.
    Push-Location $stagingDir
    try {
        Compress-Archive -Path * -DestinationPath $absZipPath -Force
    }
    finally {
        # Return to the original directory
        Pop-Location
    }

    # Cleanup staging
    Remove-Item $stagingDir -Recurse -Force

    return $zipPath
}
function New-TextSizeCacheKey {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][hashtable]$Params)
    $list = [System.Collections.Generic.List[string]]::new()
    $list.Add("text=`"$Text`"")
    foreach ($k in ((($Params.Keys | ForEach-Object { $_.ToString().ToLowerInvariant() }) | Sort-Object))) {
        $v = $Params[$k]; if ($null -eq $v) { $v = '' }
        $list.Add(("{0}={1}" -f ($k.ToString().ToLowerInvariant()), ($v.ToString())))
    }
    $payload = [string]::Join('|', $list)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    return $hash
}
function Get-TextSizeFromCache {
    param([Parameter(Mandatory)][string]$Key, [string]$Path = $Global:TextSizeCachePath)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
        if (-not $raw) { return $null }

        $db = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($db.PSObject.Properties.Name -contains $Key) { return $db.$Key }
    }
    catch {
        # If any file read or json parse error occurs, return null (miss)
        return $null
    }
    return $null
}
function Set-TextSizeCacheEntry {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)]$Result, [string]$Path = $Global:TextSizeCachePath)

    # Ensure directory exists
    if (-not (Test-Path -LiteralPath $Path)) {
        try { '{}' | Set-Content -LiteralPath $Path -Encoding UTF8 } catch {}
    }

    $lockPath = "$Path.lock"
    $sw = [Diagnostics.Stopwatch]::StartNew()

    # Wait for lock
    while (Test-Path -LiteralPath $lockPath) {
        Start-Sleep -Milliseconds 50
        if ($sw.ElapsedMilliseconds -gt 5000) { break }
    }

    # Create lock
    New-Item -ItemType File -Path $lockPath -Force | Out-Null

    try {
        $raw = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 } else { '{}' }
        if (-not $raw) { $raw = '{}' }

        try {
            $db = $raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            # If JSON is corrupt, log it and reset DB so we don't crash next time
            Write-Entry -Message "TextSizeCache JSON is corrupt. Resetting cache." -Path $global:configLogging -Color Yellow -log Warning
            $db = @{}
        }

        if ($null -eq $db) { $db = @{ } }

        $db | Add-Member -NotePropertyName $Key -NotePropertyValue $Result -Force
        ($db | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    catch {
        Write-Entry -Message "Failed to write to TextSizeCache: $_" -Path $global:configLogging -Color Red -log Error
    }
    finally {
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    }
}
function InvokeIMChecks {
    # Check for latest Imagemagick Version
    if ($global:OSarch -eq "Arm64") {
        try {
            $global:CurrentImagemagickversion = & $magick -version
        }
        catch {
            Write-Entry -Message "Could not query installed Imagemagick" -Path $global:configLogging -Color Red -log Error
            # Clear Running File
            HandleScriptExit -Message "Imagemagick missing"
        }
        $global:CurrentImagemagickversion = [regex]::Match($global:CurrentImagemagickversion, 'Version: ImageMagick (\d+(\.\d+){1,2}-\d+)')
        $global:CurrentImagemagickversion = $global:CurrentImagemagickversion.Groups[1].Value.replace('-', '.')
        Write-Entry -Message "Current Imagemagick Version: $global:CurrentImagemagickversion" -Path $global:configLogging -Color White -log Info
    }
    Else {
        # Check ImageMagick now:
        CheckImageMagick -magick $magick -magickinstalllocation $magickinstalllocation

        $global:CurrentImagemagickversion = & $magick -version
        $global:CurrentImagemagickversion = [regex]::Match($global:CurrentImagemagickversion, 'Version: ImageMagick (\d+(\.\d+){1,2}-\d+)')
        $global:CurrentImagemagickversion = $global:CurrentImagemagickversion.Groups[1].Value.replace('-', '.')
        Write-Entry -Message "Current Imagemagick Version: $global:CurrentImagemagickversion" -Path $global:configLogging -Color White -log Info
    }

    if ($global:OSType -eq "Docker") {
        #$OSVersionTag = (Get-Content /etc/os-release | Select-String -Pattern "^PRETTY_NAME=").ToString().Split('=')[1].Trim('"').replace('Alpine Linux ', '')
        $Url = "https://pkgs.alpinelinux.org/package/edge/community/x86_64/imagemagick"
        $response = Invoke-WebRequest -Uri $url
        $htmlContent = $response.Content
        $regexPattern = '<th class="header">Version<\/th>\s*<td>\s*<strong[^>]*>([\d\.]+-r\d+)<\/strong>'
        $Versionmatching = [regex]::Matches($htmlContent, $regexPattern)

        if ($Versionmatching.Count -gt 0) {
            $global:LatestImagemagickversion = $Versionmatching[0].Groups[1].Value.split('-')[0]
        }
        <#
        $Url = "https://raw.githubusercontent.com/SoftCreatR/imei/main/versions/imagemagick.version"
        $response = Invoke-WebRequest -Uri $url
        $htmlContent = $response.Content
        $regexPattern = '(\d+\.\d+\.\d+-\d+)'
        $Versionmatching = [regex]::Matches($htmlContent, $regexPattern)

        if ($Versionmatching.Count -gt 0) {
            $global:LatestImagemagickversion = $Versionmatching[0].Value
        }
    #>
    }
    Elseif ($global:OSType -eq "Win32NT") {
        try {
            $Url = "https://imagemagick.org/archive/binaries/?C=M;O=D"
            $result = Invoke-WebRequest -Uri $Url -ErrorAction Stop

            $global:LatestImagemagickversion = ($result.links.href |
                Where-Object { $_ -like '*portable-Q16-HDRI-x64.zip' } |
                Sort-Object -Descending)[0] -replace '-portable-Q16-HDRI-x64.zip', '' -replace 'ImageMagick-', ''
        }
        catch {
            # Fallback to GitHub API if direct access is forbidden or fails
            Write-Entry -Subtext "Primary method failed. Falling back to GitHub API..." -Path $global:configLogging -Color Yellow -log Debug
            $global:LatestImagemagickversion = (Invoke-RestMethod -Uri "https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest" -Method Get).tag_name
        }
    }
    Else {
        $global:LatestImagemagickversion = (Invoke-RestMethod -Uri "https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest" -Method Get).tag_name
    }
    if ($global:LatestImagemagickversion) {
        $global:LatestImagemagickversiontemp = $global:LatestImagemagickversion
        $global:LatestImagemagickversion = $global:LatestImagemagickversion.replace('-', '.')
        Write-Entry -Subtext "Latest Imagemagick Version: $global:LatestImagemagickversion" -Path $global:configLogging -Color Yellow -log Info
    }

    # Auto Update Magick
    if ($AutoUpdateIM -eq 'true' -and $global:OSType -ne "Docker" -and $global:OSType -eq "Win32NT" -and $global:LatestImagemagickversion -gt $global:CurrentImagemagickversion -and $global:OSarch -ne "Arm64") {
        Remove-Item -LiteralPath "$global:ScriptRoot/magick" -Force

        if ($global:OSType -ne "Win32NT") {
            if ($global:OSType -ne "Docker") {
                Write-Entry -Subtext "Downloading the latest Imagemagick portable version for you..." -Path $global:configLogging -Color Cyan -log Info
                $magickUrl = "https://imagemagick.org/archive/binaries/magick"
                Invoke-WebRequest -Uri $magickUrl -OutFile "$global:ScriptRoot/magick"
                chmod +x "$global:ScriptRoot/magick"
                Write-Entry -Subtext "Made the portable Magick executable..." -Path $global:configLogging -Color Green -log Info
            }
        }
    }
}
function Output-ConfigJson {
    param (
        $obj,
        [int]$indentLevel = 0
    )
    function RedactUrl($value) {
        if ($null -eq $value) { return $null }
        if ($value.Length -le 10) { return $value }
        return ($value[0..9] -join '') + '****'
    }
    function RedactKey($value) {
        if ($null -eq $value) { return $null }
        # If the string is 1 character or less, return it as-is.
        if ($value.Length -le 1) {
            return $value
        }
        # For any string longer than 1 char, show the first char and then redact.
        return $value.Substring(0, 1) + '****'
    }
    $redactKeys = @("tvdbapi", "tmdbtoken", "fanarttvapikey", "plextoken", "jellyfinapikey", "embyapikey", "embyurl", "jellyfinurl", "discord", "plexurl", "UptimeKumaUrl", "AppriseUrl", "basicAuthPassword", "basicAuthUsername")
    $indent = '  ' * $indentLevel

    if ($indentLevel -eq 0) {
        foreach ($section in $obj.PSObject.Properties) {
            Write-Entry "===== $($section.Name) =====" -Path $global:configLogging -Color Yellow -log Info
            Output-ConfigJson -obj $section.Value -indentLevel 1
        }
        return
    }

    if ($obj -is [System.Management.Automation.PSCustomObject] -or $obj -is [Hashtable]) {
        foreach ($prop in $obj.PSObject.Properties) {
            $keyLower = $prop.Name.ToLower()
            $val = $prop.Value

            if ($redactKeys -contains $keyLower) {
                if ($keyLower.EndsWith("url")) {
                    $redacted = RedactUrl $val
                }
                else {
                    $redacted = RedactKey $val
                }
                Write-Entry -Subtext "$indent$($prop.Name): $redacted" -Path $global:configLogging -Color Cyan -log Info
            }
            elseif ($val -is [System.Management.Automation.PSCustomObject] -or $val -is [Hashtable]) {
                # For nested objects, print key with colon and then recurse with increased indent
                Write-Entry -Subtext "$indent$($prop.Name):" -Path $global:configLogging -Color Cyan -log Info
                Output-ConfigJson -obj $val -indentLevel ($indentLevel + 1)
            }
            elseif ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                # For arrays/lists, join with comma and print on the same line
                $joined = ($val | ForEach-Object { $_ }) -join ", "
                Write-Entry -Subtext "$indent$($prop.Name): $joined" -Path $global:configLogging -Color Cyan -log Info
            }
            else {
                Write-Entry -Subtext "$indent$($prop.Name): $val" -Path $global:configLogging -Color Cyan -log Info
            }
        }
    }
    else {
        Write-Entry -Subtext ("{0}{1}" -f ('  ' * $indentLevel), $obj) -Path $global:configLogging -Color Cyan -log Info
    }
}
function Initialize-LanguageSettings {
    param (
        [string]$SettingName, # e.g. "PreferredLanguageOrder"
        [string]$Label,       # e.g. "Poster"
        [string[]]$Default = @("xx", "en", "de")
    )

    # Get the starting value (global if exists, else default)
    if (Get-Variable -Name $SettingName -Scope Global -ErrorAction SilentlyContinue) {
        $valueToValidate = (Get-Variable -Name $SettingName -Scope Global).Value
    }
    else {
        $valueToValidate = $Default
        Write-Entry -Message "$Label search Order not set in Config, setting it to '$($Default -join ",")'" -Path "$global:configLogging" -Color Yellow -log Warning
    }

    # Log and remove invalid entries (> 2 chars and not "xx")
    $invalids = $valueToValidate | Where-Object { $_ -ne 'xx' -and $_.Length -ne 2 }
    foreach ($inv in $invalids) {
        Write-Entry -Message "$Label search Order contains invalid language code '$inv' (must be exactly 2 chars), removing it." -Path "$global:configLogging" -Color Red -log Error
    }

    $validLangs = $valueToValidate | Where-Object { $_ -eq 'xx' -or ($_ -match '^[a-z]{2}$') }

    # Fallback to default if empty after filtering
    if (-not $validLangs -or $validLangs.Count -eq 0) {
        $validLangs = $Default
        Write-Entry -Message "$Label order invalid after filtering, using default '$($Default -join ",")'" -Path "$global:configLogging" -Color Red -log Error
    }

    # Always overwrite the global variable
    Set-Variable -Name $SettingName -Scope Global -Value $validLangs -Force

    # Derived variants
    Set-Variable -Name "${SettingName}TMDB"   -Scope Global -Value $validLangs
    Set-Variable -Name "${SettingName}Fanart" -Scope Global -Value ($validLangs -replace '^xx$', '00')
    Set-Variable -Name "${SettingName}TVDB"   -Scope Global -Value ($validLangs -replace '^xx$', 'null')

    # Flags
    if ($validLangs -contains 'xx' -and $validLangs.Count -eq 1) {
        Set-Variable -Name "${Label}PreferTextless" -Scope Global -Value $true
        Set-Variable -Name "${Label}OnlyTextless"   -Scope Global -Value $true
    }
    elseif ($validLangs[0] -eq 'xx') {
        Set-Variable -Name "${Label}PreferTextless" -Scope Global -Value $true
        Set-Variable -Name "${Label}OnlyTextless"   -Scope Global -Value $false
    }
    else {
        Set-Variable -Name "${Label}PreferTextless" -Scope Global -Value $false
        Set-Variable -Name "${Label}OnlyTextless"   -Scope Global -Value $false
    }

    # Debug logs

    $preferTextless = (Get-Variable -Name "${Label}PreferTextless" -Scope Global).Value
    $onlyTextless = (Get-Variable -Name "${Label}OnlyTextless" -Scope Global).Value

    Write-Entry -Subtext "$Label PreferTextless Value: $preferTextless" -Path "$global:configLogging" -Color Cyan -log Debug
    Write-Entry -Subtext "$Label OnlyTextless Value: $onlyTextless" -Path "$global:configLogging" -Color Cyan -log Debug

}
function Test-PathPermissions {
    param (
        [string]$PathToTest
    )

    # Extract drive (if any) from the path (Windows paths like P:\assetsbackup)
    $driveLetter = ($PathToTest -split ':')[0]

    # If path starts with a drive letter but that drive doesn't exist, log and skip
    if ($PathToTest -match '^[A-Za-z]:\\' -and -not (Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue)) {
        Write-Entry -Message "Drive '$($driveLetter):' not found. The path '$PathToTest' appears to use a Windows-style default." -Path "$global:configLogging" -Color Yellow -log Warning
        Write-Entry -Subtext "Please update this path to a valid mount (e.g., /assetsbackup)." -Path "$global:configLogging" -Color Cyan -log Info
        Write-Entry -Message "Refer to the official docker-compose.yml template for correct volume mappings:" -Path "$global:configLogging" -Color Cyan -log Info
        Write-Entry -Subtext "https://raw.githubusercontent.com/fscorrupt/posterizarr/refs/heads/main/docker-compose.yml" -Path "$global:configLogging" -Color Cyan -log Info
        return
    }

    # Check if directory exists
    $canRead = Test-Path $PathToTest -PathType Container -ErrorAction SilentlyContinue

    # Check write access
    $testFile = Join-Path $PathToTest ".perm_check"

    try {
        New-Item -ItemType File -Path $testFile -Force -ErrorAction Stop | Out-Null
        Remove-Item $testFile -Force
        $canWrite = $true
    }
    catch {
        $canWrite = $false
    }

    if ($canRead -and $canWrite) {
        Write-Entry -Message "You have read and write permissions to $PathToTest" -Path "$global:configLogging" -Color Green -log Info
    }
    else {
        Write-Entry -Message "You do NOT have read and/or write permissions to $PathToTest" -Path "$global:configLogging" -Color Red -log Error
        if ($PathToTest -eq $AssetPath) {
            # Clear Running File
            HandleScriptExit -Message "Perm issues on /assets"
        }
    }
}
function Reset-PlexLibraryPictures {
    param (
        [string]$LibraryName
    )

    # Fetch the sections of the Plex library
    try {
        if ($PlexToken) {
            $sections = Invoke-RestMethod -Uri "$PlexUrl/library/sections?X-Plex-Token=$PlexToken"
        }
        Else {
            $sections = Invoke-RestMethod -Uri "$PlexUrl/library/sections"
        }
    }
    catch {
        Write-Entry -Subtext "Error fetching sections: $_" -Path "$global:configLogging" -Color Red -log Error
        return
    }

    $section = $sections.MediaContainer.Directory | Where-Object { $_.title -eq $LibraryName }

    if (-not $section) {
        Write-Entry -Subtext "Library not found: $LibraryName" -Path "$global:configLogging" -Color Red -log Error
        return
    }

    # Determine if the library is a show or not
    $IsShow = $null
    if ($section.type -eq "show") {
        $ContainerUrl = "directory"
        $IsShow = 'True'
    }
    Else {
        $ContainerUrl = "video"
        $IsShow = 'False'
    }

    $PlexHeaders = @{}
    # Default headers for Plex API requests
    $PlexHeaders['X-Plex-Container-Size'] = '1000'

    if ($PlexToken) {
        $PlexHeaders['X-Plex-Token'] = $PlexToken
    }

    # Fetch all items in the library
    try {
        $url = "$PlexUrl/library/sections/$($section.key)/all"
        $items = Invoke-RestMethod -Uri $url -Headers $PlexHeaders
    }
    catch {
        Write-Entry -Subtext "Error fetching library items: $_" -Path "$global:configLogging" -Color Red -log Error
        return
    }

    foreach ($item in $items.MediaContainer.$ContainerUrl) {
        $title = $item.title
        $ratingKey = $item.ratingKey
        Write-Entry -Message "Current Show/Movie: $title [$ratingKey]" -Path "$global:configLogging" -Color Cyan -log Debug

        # If the item is a show, handle seasons and episodes
        if ($IsShow -eq 'True') {
            try {
                $SeasondataUrl = "$PlexUrl/library/metadata/$ratingKey/children?"
                $Seasondata = Invoke-RestMethod -Uri $SeasondataUrl -Headers $PlexHeaders
            }
            catch {
                Write-Entry -Subtext "Error fetching season data for show [$title]: $_" -Path "$global:configLogging" -Color Red -log Error
                continue
            }

            foreach ($season in $Seasondata.MediaContainer.Directory) {
                $SeasonratingKey = $season.ratingKey
                Write-Entry -Subtext "Season $($season.index): $($season.title) [$SeasonratingKey]" -Path "$global:configLogging" -Color Cyan -log Debug

                # Get posters for the season
                try {
                    $seasonposterUrls = "$PlexUrl/library/metadata/$SeasonratingKey/posters?"
                    $seasonposters = Invoke-RestMethod -Uri $seasonposterUrls -Headers $PlexHeaders
                }
                catch {
                    Write-Entry -Subtext "Error fetching season posters for [$title]: $_" -Path "$global:configLogging" -Color Red -log Error
                    continue
                }

                if ($seasonposters.MediaContainer.Photo.Count -gt 0) {
                    $firstPosterKey = $seasonposters.MediaContainer.Photo[0].ratingKey -replace "^metadata://posters/", ""
                    $setPosterUrl = "$PlexUrl/library/metadata/$SeasonratingKey/poster?url=$firstPosterKey"

                    try {
                        $response = Invoke-RestMethod -Uri $setPosterUrl -Method PUT -Headers $PlexHeaders
                        Write-Entry -Subtext "Poster was reset for: $title (Season $($season.index))" -Path "$global:configLogging" -Color Green -log Info
                    }
                    catch {
                        Write-Entry -Subtext "Error setting Season poster for [$title]: $_" -Path "$global:configLogging" -Color Red -log Error
                    }
                }
                else {
                    Write-Entry -Subtext "No Season posters found for: $title" -Path "$global:configLogging" -Color Yellow -log Warning
                }

                # Fetch episodes for the season
                try {
                    $EpisodedataUrl = "$PlexUrl/library/metadata/$SeasonratingKey/children?"
                    $Episodedata = Invoke-RestMethod -Uri $EpisodedataUrl -Headers $PlexHeaders
                }
                catch {
                    Write-Entry -Subtext "Error fetching episode data for season [$SeasonratingKey]: $_" -Path "$global:configLogging" -Color Red -log Error
                    continue
                }

                foreach ($episode in $Episodedata.MediaContainer.Video) {
                    $EpisodeRatingKey = $episode.ratingKey
                    Write-Entry -Subtext "Season $($season.index) - Episode $($episode.index): $($episode.title) [$EpisodeRatingKey]" -Path "$global:configLogging" -Color Cyan -log Debug

                    # Get posters for the episode
                    try {
                        $EpisodeposterUrls = "$PlexUrl/library/metadata/$EpisodeRatingKey/posters?"
                        $EpisodePosters = Invoke-RestMethod -Uri $EpisodeposterUrls -Headers $PlexHeaders
                    }
                    catch {
                        Write-Entry -Subtext "Error fetching episode posters for [$episode.title]: $_" -Path "$global:configLogging" -Color Red -log Error
                        continue
                    }

                    if ($EpisodePosters.MediaContainer.Photo.Count -gt 0) {
                        $firstPosterKey = $EpisodePosters.MediaContainer.Photo[0].ratingKey -replace "^metadata://posters/", ""
                        $setPosterUrl = "$PlexUrl/library/metadata/$EpisodeRatingKey/poster?url=$firstPosterKey"

                        try {
                            $response = Invoke-RestMethod -Uri $setPosterUrl -Method PUT -Headers $PlexHeaders
                            Write-Entry -Subtext "Poster was reset for: $title (Season $($season.index) - Episode $($episode.index))" -Path "$global:configLogging" -Color Green -log Info
                        }
                        catch {
                            Write-Entry -Subtext "Error setting Episode poster for [$title]: $_" -Path "$global:configLogging" -Color Red -log Error
                        }
                    }
                    else {
                        Write-Entry -Subtext "No Episode posters found for: $title" -Path "$global:configLogging" -Color Yellow -log Warning
                    }
                }
            }
        }

        # Get posters for the main show
        try {
            $postersUrl = "$PlexUrl/library/metadata/$ratingKey/posters?"
            $posters = Invoke-RestMethod -Uri $postersUrl -Headers $PlexHeaders
        }
        catch {
            Write-Entry -Subtext "Error fetching posters for main show [$title]: $_" -Path "$global:configLogging" -Color Red -log Error
            continue
        }

        if ($posters.MediaContainer.Photo.Count -gt 0) {
            $firstPosterKey = $posters.MediaContainer.Photo[0].ratingKey -replace "^metadata://posters/", ""
            $setPosterUrl = "$PlexUrl/library/metadata/$ratingKey/poster?url=$firstPosterKey"

            try {
                $response = Invoke-RestMethod -Uri $setPosterUrl -Method PUT -Headers $PlexHeaders
                Write-Entry -Subtext "Poster was reset for: $title" -Path "$global:configLogging" -Color Green -log Info
            }
            catch {
                Write-Entry -Subtext "Error setting poster for [$title]: $_" -Path "$global:configLogging" -Color Red -log Error
            }
        }
        else {
            Write-Entry -Subtext "No posters found for: $title" -Path "$global:configLogging" -Color Yellow -log Warning
        }

        Start-Sleep -Seconds 1  # Avoid hammering server
    }
}
function Reset-PlexLibraryLogos {
    param (
        [string]$LibraryName
    )

    # Fetch the sections of the Plex library
    try {
        if ($PlexToken) {
            $sections = Invoke-RestMethod -Uri "$PlexUrl/library/sections?X-Plex-Token=$PlexToken"
        }
        Else {
            $sections = Invoke-RestMethod -Uri "$PlexUrl/library/sections"
        }
    }
    catch {
        Write-Entry -Subtext "Error fetching sections: $_" -Path "$global:configLogging" -Color Red -log Error
        return
    }

    $section = $sections.MediaContainer.Directory | Where-Object { $_.title -eq $LibraryName }

    if (-not $section) {
        Write-Entry -Subtext "Library not found: $LibraryName" -Path "$global:configLogging" -Color Red -log Error
        return
    }

    # Determine Container URL
    if ($section.type -eq "show") {
        $ContainerUrl = "directory"
    }
    Else {
        $ContainerUrl = "video"
    }

    $PlexHeaders = @{}
    $PlexHeaders['X-Plex-Container-Size'] = '1000'
    if ($PlexToken) { $PlexHeaders['X-Plex-Token'] = $PlexToken }

    # Fetch all items in the library
    try {
        $url = "$PlexUrl/library/sections/$($section.key)/all"
        $items = Invoke-RestMethod -Uri $url -Headers $PlexHeaders
    }
    catch {
        Write-Entry -Subtext "Error fetching library items: $_" -Path "$global:configLogging" -Color Red -log Error
        return
    }

    foreach ($item in $items.MediaContainer.$ContainerUrl) {
        $title = $item.title
        $ratingKey = $item.ratingKey
        Write-Entry -Message "Current Show/Movie: $title [$ratingKey]" -Path "$global:configLogging" -Color Cyan -log Debug
        # Get logos for the main show/movie
        try {
            $logosUrl = "$PlexUrl/library/metadata/$ratingKey/clearLogos?"
            $logos = Invoke-RestMethod -Uri $logosUrl -Headers $PlexHeaders
        }
        catch {
            Write-Entry -Subtext "Error fetching logos for [$title]: $_" -Path "$global:configLogging" -Color Red -log Error
            continue
        }

        if ($logos.MediaContainer.Photo.Count -gt 0) {

            $defaultLogoKey = $null

            # Find the first official metadata/http logo (avoids re-selecting an upload:// logo)
            foreach ($logo in $logos.MediaContainer.Photo) {
                if ($logo.ratingKey -match "^metadata://" -or $logo.ratingKey -match "^https?://") {
                    # Strip the prefix just like the poster script does
                    $defaultLogoKey = $logo.ratingKey -replace "^metadata://clearLogos/", ""
                    break
                }
            }

            if ($defaultLogoKey) {
                # Note: The PUT endpoint uses the singular "clearLogo", not "clearLogos"
                $setLogoUrl = "$PlexUrl/library/metadata/$ratingKey/clearLogo?url=$defaultLogoKey"

                try {
                    $response = Invoke-RestMethod -Uri $setLogoUrl -Method PUT -Headers $PlexHeaders
                    Write-Entry -Subtext "Logo was reset for: $title" -Path "$global:configLogging" -Color Green -log Info
                }
                catch {
                    Write-Entry -Subtext "Error setting logo for [$title]: $_" -Path "$global:configLogging" -Color Red -log Error
                }
            }
            else {
                Write-Entry -Subtext "No default fallback logo found for: $title" -Path "$global:configLogging" -Color Yellow -log Warning
            }
        }
        else {
            Write-Entry -Subtext "No logos exist at all for: $title" -Path "$global:configLogging" -Color Yellow -log Warning
        }

        Start-Sleep -Seconds 1  # Avoid hammering server
    }
}
function Get-Resolution {
    param ($Width)
    switch ($true) {
        ($Width -ge 7680) { return "8K" }
        ($Width -ge 5120) { return "5K" }
        ($Width -ge 3840) { return "4K" }
        ($Width -ge 2560) { return "1440p" }
        ($Width -ge 1920) { return "1080p" }
        ($Width -ge 1280) { return "720p" }
        ($Width -ge 854) { return "480p" }
        ($Width -ge 640) { return "360p" }
        ($Width -ge 426) { return "240p" }
        default { return "unknown" }
    }
}
function Get-CPUModel {
    if ($Platform -eq 'Docker') {
        $cpuInfo = cat /proc/cpuinfo | Out-String
        $cpuModelLine = $cpuInfo -split "`n" | Where-Object { $_ -like "model name*" }
        $cpuModel = $cpuModelLine -replace "model name\s*:\s*", ""
        $cpuModel = $cpuModel[0]
    }
    Elseif ($Platform -eq 'Windows') {
        $cpuModel = (Get-CimInstance win32_processor).name
    }
    Elseif ($Platform -eq 'Linux') {
        $cpuInfo = lscpu | Out-String
        $cpuInfoLines = $cpuInfo -split "`n"
        $cpuModel = ($cpuInfoLines | Where-Object { $_ -like "Model name*" }) -replace "Model name\s*:\s*", ""
    }
    Elseif ($Platform -eq 'macOS') {
        $cpuModel = system_profiler SPHardwareDataType | grep "Processor Name" | awk -F': ' '{print $2}' | xargs
    }
    Else {
        $cpuModel = 'Unknown'
    }
    return $cpuModel
}
function GetHash {
    param ([byte[]]$imageBytes)

    # Create a hash algorithm instance (SHA256)
    $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()

    # Compute the hash from the byte array
    $hashBytes = $hashAlgorithm.ComputeHash($imageBytes)

    # Convert the hash bytes to a readable hex string
    $hashString = [BitConverter]::ToString($hashBytes) -replace "-", ""
    return $hashString
}
function Set-OSTypeAndScriptRoot {
    if ($env:POWERSHELL_DISTRIBUTION_CHANNEL -like 'PSDocker*') {
        $global:OSType = "Docker"
        $currentuser = whoami
        if ($currentuser -eq 'posterizarr' -or $currentuser -eq 'abc' -or $env:VIRTUAL_ENV -eq '/lsiopy' -or $env:POSTERIZARR_NON_ROOT -eq 'TRUE') {
            $global:ScriptRoot = "/config"
        }
        Else {
            $global:ScriptRoot = "./config"
        }
    }
    elseif ($env:APP_DATA) {
        $global:ScriptRoot = $env:APP_DATA
    }
    Else {
        $global:ScriptRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        $global:OSType = [System.Environment]::OSVersion.Platform
    }
}
function Write-Entry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Warning', 'Error', 'Optional', 'Debug', 'Trace', 'Success')]
        [string]$log,

        [Parameter(Mandatory = $true)]
        [ValidateSet('White', 'Yellow', 'Red', 'Blue', 'DarkMagenta', 'Cyan', 'Green')]
        [string]$Color,

        [string]$Subtext = $null
    )
    switch ($log) {
        'Info' { $theLog = 2 }
        'Warning' { $theLog = 1 }
        'Error' { $theLog = 1 }
        'Debug' { $theLog = 3 }
        'Optional' { $theLog = 3 }
    }
    if (!(Test-Path -path $path)) {
        New-Item -Path $Path -Force | out-null
    }
    # ASCII art header
    if (-not $global:HeaderWritten) {
        # Retrieve CPU model
        $cpuModel = Get-CPUModel
        # Retrieve RAM Info
        if ($Platform -eq 'Docker' -or $Platform -eq 'Linux') {
            # Check Memory Usage (Total and Free)
            $memoryUsage = free -m | Out-String
            $memoryUsageLines = $memoryUsage -split "`n"
            $memValues = $memoryUsageLines[1] -split "\s+"

            $totalMemory = [int]$memValues[1]
            $usedMemory = [int]$memValues[2]
            $freeMemory = [int]$memValues[3]
            $sharedMemory = [int]$memValues[4]
            $buffersCache = [int]$memValues[5]
            $availableMemory = [int]$memValues[6]
            if (Test-Path /etc/os-release) {
                $OSVersion = (Get-Content /etc/os-release | Select-String -Pattern "^PRETTY_NAME=").ToString().Split('=')[1].Trim('"')
            }
            $Header = @"
======================================================
  _____          _            _
 |  __ \        | |          (_)
 | |__) |__  ___| |_ ___ _ __ _ ______ _ _ __ _ __
 |  ___/ _ \/ __| __/ _ \ '__| |_  / _``` | '__| '__|
 | |  | (_) \__ \ ||  __/ |  | |/ / (_| | |  | |
 |_|   \___/|___/\__\___|_|  |_/___\__,_|_|  |_|

 Current Version: $CurrentScriptVersion
 Latest Version: $LatestScriptVersion
 Platform: $Platform
 OS Version: $OSVersion
 Branch: $Branch

 CPU Model: $cpuModel

 Total Memory: $totalMemory MB
 Used Memory: $usedMemory MB
 Free Memory: $freeMemory MB
 Shared Memory: $sharedMemory MB
 Buffers/Cache: $buffersCache MB
 Available: $availableMemory MB
 ======================================================
"@
        }
        Elseif ($Platform -eq 'Windows') {
            # Retrieve memory information in GB or MB
            $memoryInfo = Get-CimInstance Win32_OperatingSystem | Select-Object @{Name = "FreePhysicalMemory"; Expression = {
                    if ($_.FreePhysicalMemory -ge 1GB) {
                        "$([math]::Round($_.FreePhysicalMemory / 1GB, 2)) MB"
                    }
                    elseif ($_.FreePhysicalMemory -ge 1MB) {
                        "$([math]::Round($_.FreePhysicalMemory / 1MB, 2)) GB"
                    }
                    else {
                        "$($_.FreePhysicalMemory)"
                    } }
            },
            @{Name = "TotalVisibleMemorySize"; Expression = {
                    if ($_.TotalVisibleMemorySize -ge 1GB) {
                        "$([math]::Round($_.TotalVisibleMemorySize / 1GB, 2)) MB"
                    }
                    elseif ($_.TotalVisibleMemorySize -ge 1MB) {
                        "$([math]::Round($_.TotalVisibleMemorySize / 1MB, 2)) GB"
                    }
                    else {
                        "$($_.TotalVisibleMemorySize)"
                    }
                }
            },
            @{Name = "UsedMemory"; Expression = {
                    $totalMemory = $_.TotalVisibleMemorySize
                    $freeMemory = $_.FreePhysicalMemory
                    $usedMemory = $totalMemory - $freeMemory

                    if ($usedMemory -ge 1GB) {
                        "$([math]::Round($usedMemory / 1GB, 2)) MB"
                    }
                    elseif ($usedMemory -ge 1MB) {
                        "$([math]::Round($usedMemory / 1MB, 2)) GB"
                    }
                    else {
                        $usedMemory
                    }
                }
            }
            $totalMemory = $memoryInfo.TotalVisibleMemorySize
            $usedMemory = $memoryInfo.UsedMemory
            $freeMemory = $memoryInfo.FreePhysicalMemory
            $OSVersion = (Get-CimInstance -class Win32_OperatingSystem).Caption
            $Header = @"
======================================================
  _____          _            _
 |  __ \        | |          (_)
 | |__) |__  ___| |_ ___ _ __ _ ______ _ _ __ _ __
 |  ___/ _ \/ __| __/ _ \ '__| |_  / _``` | '__| '__|
 | |  | (_) \__ \ ||  __/ |  | |/ / (_| | |  | |
 |_|   \___/|___/\__\___|_|  |_/___\__,_|_|  |_|

 Current Version: $CurrentScriptVersion
 Latest Version: $LatestScriptVersion
 Platform: $Platform
 OS Version: $OSVersion
 Branch: $Branch

 CPU Model: $cpuModel

 Total Memory: $totalMemory
 Used Memory: $usedMemory
 Free Memory: $freeMemory
 ======================================================
"@
        }
        Else {
            $Header = @"
======================================================
  _____          _            _
 |  __ \        | |          (_)
 | |__) |__  ___| |_ ___ _ __ _ ______ _ _ __ _ __
 |  ___/ _ \/ __| __/ _ \ '__| |_  / _``` | '__| '__|
 | |  | (_) \__ \ ||  __/ |  | |/ / (_| | |  | |
 |_|   \___/|___/\__\___|_|  |_/___\__,_|_|  |_|

 Current Version: $CurrentScriptVersion
 Latest Version: $LatestScriptVersion
 Platform: $Platform
 Branch: $Branch
 CPU Model: $cpuModel
 ======================================================
"@
        }
        Write-Host $Header
        $Header | Out-File $Path -Append
        $global:HeaderWritten = $true
    }
    if ($theLog -le $global:logLevel) {
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $PaddedType = "[" + $log + "]"
        $PaddedType = $PaddedType.PadRight(10)
        $Linenumber = "L" + "." + "$($MyInvocation.ScriptLineNumber)"
        if ($Linenumber.Length -eq '4') {
            $Linenumber = $Linenumber + "   "
        }
        if ($Linenumber.Length -eq '5') {
            $Linenumber = $Linenumber + "  "
        }
        if ($Linenumber.Length -eq '6') {
            $Linenumber = $Linenumber + " "
        }
        $TypeFormatted = "[{0}] {1}|{2}" -f $Timestamp, $PaddedType.ToUpper(), $Linenumber

        if ($Message) {
            $FormattedLine1 = "{0}| {1}" -f ($TypeFormatted, $Message)
            $FormattedLineWritehost = "{0}| " -f ($TypeFormatted)
        }

        if ($Subtext) {
            $FormattedLine = "{0}|      {1}" -f ($TypeFormatted, $Subtext)
            $FormattedLineWritehost = "{0}|      " -f ($TypeFormatted)
            Write-Host $FormattedLineWritehost -NoNewline
            Write-Host $Subtext -ForegroundColor $Color
            $FormattedLine | Out-File $Path -Append
        }
        else {

            Write-Host $FormattedLineWritehost -NoNewline
            Write-Host $Message -ForegroundColor $Color
            $FormattedLine1 | Out-File $Path -Append
        }
    }
}
function SendMessage {
    param(
        [string]$type,
        [string]$title,
        [string]$Lib,
        [string]$DLSource,
        [string]$lang,
        [string]$favurl,
        [string]$fallback,
        [string]$truncated
    )
    function Build-DiscordPayload {

        # Create a list for the fields
        $fieldList = [System.Collections.Generic.List[object]]::new()

        # Add all common fields
        $fieldList.Add([PSCustomObject]@{ name = ""; value = ":bar_chart:"; inline = $false })
        $fieldList.Add([PSCustomObject]@{ name = "Type"; value = $type; inline = $false })
        $fieldList.Add([PSCustomObject]@{ name = "Fallback"; value = $fallback; inline = $true })
        $fieldList.Add([PSCustomObject]@{ name = "Language"; value = $lang; inline = $true })
        $fieldList.Add([PSCustomObject]@{ name = "Truncated"; value = $truncated; inline = $true })

        # Add conditional fields
        if ($SkipTBA -eq 'true' -or $SkipJapTitle -eq 'true') {
            $fieldList.Add([PSCustomObject]@{ name = "TBA Skipped"; value = "$SkipTBACount"; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "Jap/Chinese Skipped"; value = "$SkipJapTitleCount"; inline = $true })
        }

        # Add remaining fields
        $fieldList.Add([PSCustomObject]@{ name = ""; value = ":frame_photo:"; inline = $false })

        # Add the title. ConvertTo-Json will handle any special characters in $title
        $fieldList.Add([PSCustomObject]@{ name = "Title"; value = $title; inline = $false })

        $fieldList.Add([PSCustomObject]@{ name = "Library"; value = $Lib; inline = $true })

        # Add the URL. ConvertTo-Json will handle any special characters in $favurl
        $fieldList.Add([PSCustomObject]@{ name = "Fav Url"; value = $favurl; inline = $true })

        # Build the final payload object
        $payloadObject = [PSCustomObject]@{
            username   = $global:DiscordUserName
            avatar_url = "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/docs/images/webhook.png"
            # content    = ""
            embeds     = @(
                [PSCustomObject]@{
                    author      = @{
                        name = "Posterizarr @Github"
                        url  = "https://github.com/fscorrupt/posterizarr"
                    }
                    description = "Recently Added`n`n"
                    timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    color       = $(if ($errorCount -ge '1') { 16711680 } Elseif ($global:IsFallback -eq 'true' -or $global:IsTruncated -eq 'true') { 15120384 } Else { 5763719 })
                    fields      = $fieldList
                    thumbnail   = @{
                        url = $DLSource
                    }
                    footer      = @{
                        text = "$Platform  | vCurr: $CurrentScriptVersion | vNext: $LatestScriptVersion | IM vCurr: $global:CurrentImagemagickversion | IM vNext: $global:LatestImagemagickversion"
                    }
                }
            )
        }

        # Convert the entire object to a JSON string safely
        # -Depth 6 is needed to make sure it nests everything (payload->embeds->fields)
        return $payloadObject | ConvertTo-Json -Depth 6
    }

    if ($global:NotifyUrl -and $global:SendNotification -eq 'true') {

        # Handle Discord notifications
        if ($global:NotifyUrl -like '*discord*') {
            $jsonPayload = Build-DiscordPayload
            $webhookUrl = $global:NotifyUrl -replace '(?i)^discord://(?:[^@/]+@)?(.*)$', 'https://discord.com/api/webhooks/$1'
            Push-ObjectToDiscord -strDiscordWebhook $webhookUrl -objPayload $jsonPayload
        }

        # Handle Apprise notifications
        Elseif ($env:POWERSHELL_DISTRIBUTION_CHANNEL -like 'PSDocker*') {
            if ($errorCount -ge '1') {
                apprise --notification-type="failure" --title="Posterizarr" --body="Run took: $FormattedTimespawn`nIt Created '$posterCount' Images`n`nDuring execution '$errorCount' Errors occurred, please check log for detailed description." "$global:NotifyUrl"
            }
            Else {
                apprise --notification-type="success" --title="Posterizarr" --body="Run took: $FormattedTimespawn`nIt Created '$posterCount' Images" "$global:NotifyUrl"
            }
        }
    }
}
function AddTrailingSlash($path) {
    $path = $path.TrimEnd()
    if (-not ($path -match '[\\/]$')) {
        $path += if ($path -match '\\') { '\' } else { '/' }
    }
    return $path
}
function RemoveTrailingSlash($path) {
    if ($path -match '[\\/]$') {
        $path = $path.TrimEnd('\', '/')
    }
    return $path
}
function Get-OptimalPointSize {
    param(
        [string]$text,
        [string]$fontImagemagick,
        [int]$box_width,
        [int]$box_height,
        [int]$min_pointsize,
        [int]$max_pointsize,
        [int]$lineSpacing # parameter for line height
    )

    try {
        if (-not $script:IMVersion) { $script:IMVersion = (& $magick -version | Select-Object -First 1) }

        $__tsc_Params = @{
            font = $fontImagemagick; w = $box_width; h = $box_height;
            min = $min_pointsize; max = $max_pointsize; line = $lineSpacing;
            imv = $script:IMVersion; algo = 'Get-OptimalPointSize-v1'
        }

        $__tsc_Key = New-TextSizeCacheKey -Text $text -Params $__tsc_Params
        $__tsc_Path = if ($Global:TextSizeCachePath) { $Global:TextSizeCachePath } else { Join-Path $global:ScriptRoot 'Cache\text_size_cache.json' }

        # Wrapped in try/catch to ensure corruption doesn't stop flow
        try {
            $__tsc_Hit = Get-TextSizeFromCache -Key $__tsc_Key -Path $__tsc_Path
        }
        catch {
            $__tsc_Hit = $null
        }

        if ($__tsc_Hit) {
            if ($__tsc_Hit.PSObject.Properties.Name -contains 'isTruncated') { $global:IsTruncated = [bool]$__tsc_Hit.isTruncated } else { $global:IsTruncated = $null }
            $script:CurrentTextSizeSource = 'cache'
            $script:tsHits++   # [stats] count cache hits
            return [int]$__tsc_Hit.pointSize
        }
    }
    catch {
        # If cache logic fails entirely, ignore and proceed to calculate
        Write-Entry -Message "Cache lookup failed, proceeding with calculation. Error: $_" -Path $global:configLogging -Color Yellow -log Debug
    }

    $global:IsTruncated = $null

    # Construct the command with interline spacing and font option
    $cmd = "& `"$magick`" -size ${box_width}x${box_height} -font `"$fontImagemagick`" -gravity center -fill black -interline-spacing ${lineSpacing} caption:`"$text`" -format `"%[caption:pointsize]`" info:"

    # Log the command for debugging purposes
    $cmd | Out-File $magickLog -Append

    # [stats] start timing the ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œmissÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â compute path
    $tsc_sw = [Diagnostics.Stopwatch]::StartNew()

    # Execute the command and get the current point size
    $current_pointsize = [int](Invoke-Expression $cmd | Out-String).Trim()

    # Apply point size limits
    if ($current_pointsize -gt $max_pointsize) {
        $current_pointsize = $max_pointsize
    }
    elseif ($current_pointsize -lt $min_pointsize) {
        Write-Entry -Subtext "Text truncated! optimalFontSize: $current_pointsize below min_pointsize: $min_pointsize" -Path $global:configLogging -Color Yellow -log Warning
        $global:IsTruncated = $true
        $current_pointsize = $min_pointsize
    }

    # [stats] stop timer and record miss metrics
    $tsc_sw.Stop()
    $script:tsMiss++
    $script:tsRuns++
    $script:tsMs += $tsc_sw.ElapsedMilliseconds

    # Wrapped in try/catch to ensure saving errors don't crash script
    try {
        $__tsc_Save = [PSCustomObject]@{ pointSize = [int]$current_pointsize; isTruncated = [bool]$global:IsTruncated }
        Set-TextSizeCacheEntry -Key $__tsc_Key -Result $__tsc_Save -Path $__tsc_Path
    }
    catch {
        Write-Entry -Message "Failed to save to text size cache: $_" -Path $global:configLogging -Color Yellow -log Debug
    }

    $script:CurrentTextSizeSource = 'calculated'
    return $current_pointsize
}
function GetTMDBMoviePoster {
    Write-Entry -Subtext "Searching on TMDB for a movie poster - TMDBID: $global:tmdbid" -Path $global:configLogging -Color Cyan -log Info
    if (!$global:tmdbid) {
        Write-Entry -Subtext "Cannot search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
    if ($global:PosterPreferTextless -eq $true) {
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/movie/$($global:tmdbid)?append_to_response=images&language=xx&include_image_language=$($global:PreferredLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/posters"

        }
        if ($response) {
            if ($response.images.posters) {
                if ($global:WidthHeightFilter -eq 'true') {
                    $NoLangPoster = ($response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                    $NoLangPoster = ($response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                }
                Else {
                    $NoLangPoster = ($response.images.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                }
                if (!$NoLangPoster) {
                    Write-Entry -Subtext "PreferTextless Value: $global:PosterPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Subtext "OnlyTextless Value: $global:PosterOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                    if ($global:PosterOnlyTextless -eq $false) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $filteredPosters = $response.images.posters | Where-Object { $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = $filteredPosters[0].file_path
                                    Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                            Else {
                                $filteredPosters = $response.images.posters

                                if ($filteredPosters) {
                                    $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                    Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                        }
                        Else {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $filteredPosters = $response.images.posters

                                if ($filteredPosters) {
                                    $posterpath = $filteredPosters[0].file_path
                                }
                            }
                            Else {
                                $filteredPosters = $response.images.posters

                                if ($filteredPosters) {
                                    $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                }
                            }
                        }
                        if ($posterpath) {
                            $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                            if ($global:FavProvider -eq 'TMDB') {
                                $global:Fallback = "fanart"
                                $global:tmdbfallbackposterurl = $global:posterurl
                            }
                            Write-Entry -Subtext "Found Poster with text on TMDB" -Path $global:configLogging -Color Blue -log Info
                            $global:PosterWithText = $true
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $global:TMDBAssetTextLang = $response.images.posters[0].iso_639_1
                            }
                            Else {
                                $global:TMDBAssetTextLang = (($response.images.posters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                            }
                        }
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/posters"
                        return $global:posterurl
                    }
                    Else {
                        Write-Entry -Subtext "Found Poster with text on TMDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/posters"
                    }
                }
                Else {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $filteredPosters = $response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                            if ($filteredPosters) {
                                $posterpath = $filteredPosters[0].file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                        Else {
                            $filteredPosters = $response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                            if ($filteredPosters) {
                                $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                    }
                    Else {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $filteredPosters = $response.images.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null }
                            if ($filteredPosters) {
                                $posterpath = $filteredPosters[0].file_path
                            }

                        }
                        Else {
                            $filteredPosters = $response.images.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null }

                            if ($filteredPosters) {
                                $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                            }
                        }
                    }
                    if ($posterpath) {
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        Write-Entry -Subtext "Found Textless Poster on TMDB" -Path $global:configLogging -Color Green -log Info
                        $global:TextlessPoster = $true
                        $global:PosterWithText = $null
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/posters"
                        return $global:posterurl
                    }
                }
            }
        }
        Else {
            Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/posters"
        }
    }
    Else {
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/movie/$($global:tmdbid)?append_to_response=images&language=$($PreferredLanguageOrder[0])&include_image_language=$($global:PreferredLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/posters"

        }
        if ($response) {
            if ($response.images.posters) {
                foreach ($lang in $global:PreferredLanguageOrderTMDB) {
                    if ($lang -eq 'null' -or $lang -eq 'xx') {
                        if ($global:WidthHeightFilter -eq 'true') {
                            $FavPoster = ($response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                            $FavPoster = ($response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                        }
                        Else {
                            $FavPoster = ($response.images.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                        }
                    }
                    Else {
                        if ($global:WidthHeightFilter -eq 'true') {
                            $FavPoster = ($response.images.posters | Where-Object { $_.iso_639_1 -eq $lang -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                        }
                        Else {
                            $FavPoster = ($response.images.posters | Where-Object iso_639_1 -eq $lang)
                        }
                    }
                    if ($FavPoster) {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = $FavPoster[0].file_path
                        }
                        Else {
                            $posterpath = (($FavPoster | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            Write-Entry -Subtext "Found Poster without Language on TMDB" -Path $global:configLogging -Color Blue -log Info
                            $global:TextlessPoster = $true
                            $global:PosterWithText = $null
                        }
                        Else {
                            Write-Entry -Subtext "Found Poster with Language '$lang' on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        if ($lang -ne 'null' -or $lang -eq 'xx') {
                            $global:PosterWithText = $true
                            $global:TMDBAssetTextLang = $lang
                            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/posters"
                        }
                        return $global:posterurl
                        continue
                    }
                }
            }
        }
        Else {
            Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/posters"
        }
    }
}
function GetTMDBMovieBackground {
    Write-Entry -Subtext "Searching on TMDB for a movie background - TMDBID: $global:tmdbid" -Path $global:configLogging -Color Cyan -log Info
    if (!$global:tmdbid) {
        Write-Entry -Subtext "Cannot search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
    if ($global:BackgroundPreferTextless -eq $true) {
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/movie/$($global:tmdbid)?append_to_response=images&language=xx&include_image_language=$($global:PreferredBackgroundLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"

        }
        if ($response) {
            if ($response.images.backdrops) {
                if ($global:WidthHeightFilter -eq 'true') {
                    $NoLangPoster = ($response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight })
                    $NoLangPoster = ($response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight })
                }
                Else {
                    $NoLangPoster = ($response.images.backdrops | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                }
                if (!$NoLangPoster) {
                    Write-Entry -Subtext "PreferTextless Value: $global:BackgroundPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Subtext "OnlyTextless Value: $global:BackgroundOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                    if ($global:BackgroundOnlyTextless -eq $false) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $filteredPosters = $response.images.backdrops | Where-Object { $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = $filteredPosters[0].file_path
                                    Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No Background posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                            Else {
                                $filteredPosters = $response.images.backdrops | Where-Object { $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                    Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No Background posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                        }
                        Else {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $posterpath = $response.images.backdrops[0].file_path
                            }
                            Else {
                                $posterpath = (($response.images.backdrops | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                            }
                        }
                        if ($posterpath) {
                            $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                            if ($global:FavProvider -eq 'TMDB') {
                                $global:Fallback = "fanart"
                                $global:tmdbfallbackposterurl = $global:posterurl
                            }
                            Write-Entry -Subtext "Found background with text on TMDB" -Path $global:configLogging -Color Blue -log Info
                            $global:PosterWithText = $true
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $global:TMDBAssetTextLang = $response.images.backdrops[0].iso_639_1
                            }
                            Else {
                                $global:TMDBAssetTextLang = (($response.images.backdrops | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                            }
                            return $global:posterurl
                        }
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"
                    }
                    Else {
                        Write-Entry -Subtext "Found Poster with text on TMDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"
                    }
                }
                Else {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $filteredPosters = $response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }

                            if ($filteredPosters) {
                                $posterpath = $filteredPosters[0].file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No Background posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                        Else {
                            $filteredPosters = $response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }

                            if ($filteredPosters) {
                                $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No Background posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                    }
                    Else {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = (($response.images.backdrops | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })[0]).file_path
                        }
                        Else {
                            $posterpath = (($response.images.backdrops | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null } | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                    }
                    if ($posterpath) {
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        Write-Entry -Subtext "Found Textless background on TMDB" -Path $global:configLogging -Color Green -log Info
                        $global:TextlessPoster = $true
                        $global:PosterWithText = $null
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"
                        return $global:posterurl
                    }
                }
            }
            Else {
                Write-Entry -Subtext "No Background found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"
                if ($global:FavProvider -eq 'TMDB') {
                    $global:Fallback = "fanart"
                }
            }
        }
        Else {
            Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"
        }
    }
    Else {
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/movie/$($global:tmdbid)?append_to_response=images&language=$($PreferredBackgroundLanguageOrder[0])&include_image_language=$($global:PreferredBackgroundLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"

        }
        if ($response) {
            if ($response.images.backdrops) {
                foreach ($lang in $global:PreferredBackgroundLanguageOrderTMDB) {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight })
                            $FavPoster = ($response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight })
                        }
                        Else {
                            $FavPoster = ($response.images.backdrops | Where-Object { $_.iso_639_1 -eq $lang -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight })
                        }
                    }
                    Else {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($response.images.backdrops | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                        }
                        Else {
                            $FavPoster = ($response.images.backdrops | Where-Object iso_639_1 -eq $lang)
                        }
                    }
                    if ($FavPoster) {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = $FavPoster[0].file_path
                        }
                        Else {
                            $posterpath = (($FavPoster | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            Write-Entry -Subtext "Found background without Language on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        Else {
                            Write-Entry -Subtext "Found background with Language '$lang' on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        if ($lang -ne 'null' -or $lang -eq 'xx') {
                            $global:PosterWithText = $true
                            $global:TMDBAssetTextLang = $lang
                            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"
                        }
                        return $global:posterurl
                        continue
                    }
                }
                if (!$global:posterurl -and $global:WidthHeightFilter -eq 'false') {
                    Write-Entry -Subtext "No Background found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                    if ($global:FavProvider -ne 'fanart') {
                        $global:Fallback = "fanart"
                    }
                }
                if (!$global:posterurl -and $global:WidthHeightFilter -eq 'true') {
                    Write-Entry -Subtext "No Background found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                    if ($global:FavProvider -ne 'fanart') {
                        $global:Fallback = "fanart"
                    }
                }
            }
            Else {
                Write-Entry -Subtext "No Background found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"
                if ($global:FavProvider -ne 'fanart') {
                    $global:Fallback = "fanart"
                }
            }
        }
        Else {
            Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/movie/$($global:tmdbid)/images/backdrops"
        }
    }
}
function GetTMDBShowPoster {
    Write-Entry -Subtext "Searching on TMDB for a show poster - TMDBID: $global:tmdbid" -Path $global:configLogging -Color Cyan -log Info
    if (!$global:tmdbid) {
        Write-Entry -Subtext "Cannot search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
        $global:tmdbsearched = $true
    }
    Else {
        if ($global:PosterPreferTextless -eq $true) {
            try {
                $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/tv/$($global:tmdbid)?append_to_response=images&language=xx&include_image_language=$($global:PreferredLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
            }
            catch {
                Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/posters"

            }
            if ($response) {
                if ($response.images.posters) {
                    if ($global:WidthHeightFilter -eq 'true') {
                        $NoLangPoster = ($response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                        $NoLangPoster = ($response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                    }
                    Else {
                        $NoLangPoster = ($response.images.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                    }
                    if (!$NoLangPoster) {
                        Write-Entry -Subtext "PreferTextless Value: $global:PosterPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "OnlyTextless Value: $global:PosterOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                        if ($global:PosterOnlyTextless -eq $false) {
                            if ($global:WidthHeightFilter -eq 'true') {
                                if ($global:TMDBVoteSorting -eq 'primary') {
                                    $filteredPosters = $response.images.posters | Where-Object { $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                                    if ($filteredPosters) {
                                        $posterpath = $filteredPosters[0].file_path
                                        $global:TMDBAssetTextLang = $filteredPosters[0].iso_639_1
                                        Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                                    }
                                    else {
                                        Write-Entry -Subtext "No posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                    }
                                }
                                Else {
                                    $filteredPosters = $response.images.posters | Where-Object { $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                                    if ($filteredPosters) {
                                        $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                        $global:TMDBAssetTextLang = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                                        Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                                    }
                                    else {
                                        Write-Entry -Subtext "No posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                    }
                                }
                            }
                            Else {
                                if ($global:TMDBVoteSorting -eq 'primary') {
                                    $posterpath = $response.images.posters[0].file_path
                                    $global:TMDBAssetTextLang = $response.images.posters[0].iso_639_1
                                }
                                Else {
                                    $posterpath = (($response.images.posters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                    $global:TMDBAssetTextLang = (($response.images.posters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                                }
                            }
                            if ($posterpath) {
                                $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                                if ($global:FavProvider -ne 'fanart') {
                                    $global:Fallback = "fanart"
                                    $global:tmdbfallbackposterurl = $global:posterurl
                                }
                                Write-Entry -Subtext "Found Poster with text on TMDB" -Path $global:configLogging -Color Blue -log Info
                                $global:PosterWithText = $true

                                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/posters"
                                return $global:posterurl
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Found Poster with text on TMDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/posters"
                        }
                    }
                    Else {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $filteredPosters = $response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = $filteredPosters[0].file_path
                                    Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                            Else {
                                $filteredPosters = $response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                    Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                        }
                        Else {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $posterpath = ($response.images.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                                if ($posterpath) {
                                    $posterpath = $posterpath[0].file_path
                                }
                            }
                            Else {
                                $posterpath = ($response.images.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null } | Sort-Object $global:TMDBVoteSorting -Descending)
                                if ($posterpath) {
                                    $posterpath = $posterpath[0].file_path
                                }
                            }
                        }
                        if ($posterpath) {
                            $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                            Write-Entry -Subtext "Found Textless Poster on TMDB" -Path $global:configLogging -Color Green -log Info
                            $global:TextlessPoster = $true
                            $global:PosterWithText = $null
                            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/posters"
                            return $global:posterurl
                        }
                    }
                    $global:tmdbsearched = $true
                }
            }
            Else {
                Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/posters"
                $global:tmdbsearched = $true
            }
        }
        Else {
            try {
                $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/tv/$($global:tmdbid)?append_to_response=images&language=$($PreferredLanguageOrder[0])&include_image_language=$($global:PreferredLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
            }
            catch {
                Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/posters"

            }
            if ($response) {
                if ($response.images.posters) {
                    foreach ($lang in $global:PreferredLanguageOrderTMDB) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($lang -eq 'null' -or $lang -eq 'xx') {
                                $FavPoster = ($response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                                $FavPoster = ($response.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                            }
                            Else {
                                $FavPoster = ($response.images.posters | Where-Object { $_.iso_639_1 -eq $lang -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                            }
                        }
                        Else {
                            if ($lang -eq 'null' -or $lang -eq 'xx') {
                                $FavPoster = ($response.images.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                            }
                            Else {
                                $FavPoster = ($response.images.posters | Where-Object iso_639_1 -eq $lang)
                            }
                        }
                        if ($FavPoster) {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $posterpath = $FavPoster[0].file_path
                            }
                            Else {
                                $posterpath = (($FavPoster | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                            }
                            $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                            if ($lang -eq 'null' -or $lang -eq 'xx') {
                                Write-Entry -Subtext "Found Poster without Language on TMDB" -Path $global:configLogging -Color Blue -log Info
                                $global:TextlessPoster = $true
                                $global:PosterWithText = $null
                            }
                            Else {
                                Write-Entry -Subtext "Found Poster with Language '$lang' on TMDB" -Path $global:configLogging -Color Blue -log Info
                            }
                            if ($lang -ne 'null' -or $lang -eq 'xx') {
                                $global:PosterWithText = $true
                                $global:TMDBAssetTextLang = $lang
                                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/posters"
                            }
                            return $global:posterurl
                            continue
                        }
                        $global:tmdbsearched = $true
                    }
                }
            }
            Else {
                Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/posters"
                $global:tmdbsearched = $true
            }
        }
    }
}
function GetTMDBSeasonPoster {
    Write-Entry -Subtext "Searching on TMDB for Season '$global:SeasonNumber' poster - TMDBID: $global:tmdbid" -Path $global:configLogging -Color Cyan -log Info
    if (!$global:tmdbid) {
        Write-Entry -Subtext "Cannot search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
    if ($global:SeasonPreferTextless -eq $true) {
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/tv/$($global:tmdbid)/season/$global:SeasonNumber/images?append_to_response=images&language=xx&include_image_language=$($global:PreferredSeasonLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"

        }
        if ($response) {
            if ($response.posters) {
                if ($global:WidthHeightFilter -eq 'true') {
                    $NoLangPoster = ($response.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                }
                Else {
                    $NoLangPoster = ($response.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) })
                }
                Write-Entry -Subtext "NoLangPoster: $NoLangPoster" -Path $global:configLogging -Color Cyan -log Debug
                if (!$NoLangPoster) {
                    if (!$global:SeasonOnlyTextless) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $filteredPosters = $response.poster | Where-Object { $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = $filteredPosters[0].file_path
                                    $global:TMDBAssetTextLang = $filteredPosters[0].iso_639_1
                                    Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No Season posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                            Else {
                                $filteredPosters = $response.posters | Where-Object { $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                    $global:TMDBAssetTextLang = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                                    Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No Season posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                        }
                        Else {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $posterpath = $response.posters[0].file_path
                                $global:TMDBAssetTextLang = $response.posters[0].iso_639_1
                            }
                            Else {
                                $posterpath = (($response.posters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                $global:TMDBAssetTextLang = (($response.posters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                            }
                        }
                        if ($posterpath) {
                            $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                            Write-Entry -Subtext "Found Season Poster with text on TMDB" -Path $global:configLogging -Color Blue -log Info
                            $global:PosterWithText = $true
                            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"
                            $global:TMDBSeasonFallback = $global:posterurl
                            Write-Entry -Subtext "Posterpath: $posterpath" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "PosterUrl: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "PosterWithText: $global:PosterWithText" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "TMDBAssetTextLang: $global:TMDBAssetTextLang" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "TMDBAssetChangeUrl: $global:TMDBAssetChangeUrl" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "TMDBSeasonFallback: $global:TMDBSeasonFallback" -Path $global:configLogging -Color Cyan -log Debug
                            return $global:posterurl
                        }
                    }
                    Else {
                        Write-Entry -Subtext "Found Season Poster with text on TMDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"
                    }
                }
                Else {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $filteredPosters = $response.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                            if ($filteredPosters) {
                                $posterpath = $filteredPosters[0].file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No Season posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                        Else {
                            $filteredPosters = $response.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                            if ($filteredPosters) {
                                $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No Season posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                    }
                    Else {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = (($response.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })[0]).file_path
                        }
                        Else {
                            $posterpath = (($response.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null } | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                    }
                    if ($posterpath) {
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        Write-Entry -Subtext "Found Textless Season Poster on TMDB" -Path $global:configLogging -Color Green -log Info
                        $global:TextlessPoster = $true
                        $global:PosterWithText = $null
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"
                        Write-Entry -Subtext "Posterpath: $posterpath" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "PosterUrl: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "TextlessPoster: $global:TextlessPoster" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "TMDBAssetChangeUrl: $global:TMDBAssetChangeUrl" -Path $global:configLogging -Color Cyan -log Debug
                        return $global:posterurl
                    }
                }
            }
            Else {
                Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"
            }
        }
        Else {
            Write-Entry -Subtext "No Season Poster on TMDB" -Path $global:configLogging -Color Yellow -log Warning
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"
        }
    }
    Else {
        try {
            if ($global:SeasonNumber -match '\b\d{1,2}\b') {
                $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/tv/$($global:tmdbid)/season/$global:SeasonNumber/images?append_to_response=images&language=$($global:PreferredSeasonLanguageOrder[0])&include_image_language=$($global:PreferredSeasonLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
            }
            Else {
                $responseBackup = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/tv/$($global:tmdbid)?append_to_response=images&language=$($global:PreferredSeasonLanguageOrder[0])&include_image_language=$($global:PreferredSeasonLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"

        }
        if ($responseBackup) {
            if ($responseBackup.images.posters) {
                Write-Entry -Subtext "Could not get a result with '$global:SeasonNumber' on TMDB, likely season number not in correct format, fallback to Show poster." -Path $global:configLogging -Color Blue -log Info
                foreach ($lang in $global:PreferredSeasonLanguageOrderTMDB) {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($responseBackup.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                            $FavPoster = ($responseBackup.images.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                        }
                        Else {
                            $FavPoster = ($responseBackup.images.posters | Where-Object { $_.iso_639_1 -eq $lang -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                        }
                    }
                    Else {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($responseBackup.images.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                        }
                        Else {
                            $FavPoster = ($responseBackup.images.posters | Where-Object iso_639_1 -eq $lang)
                        }
                    }
                    if ($FavPoster) {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = $FavPoster[0].file_path
                        }
                        Else {
                            $posterpath = (($FavPoster | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            Write-Entry -Subtext "Found Poster without Language on TMDB" -Path $global:configLogging -Color Blue -log Info
                            $global:TextlessPoster = $true
                            $global:PosterWithText = $null
                        }
                        Else {
                            Write-Entry -Subtext "Found Poster with Language '$lang' on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        if ($lang -ne 'null' -or $lang -eq 'xx') {
                            $global:PosterWithText = $true
                            $global:TMDBAssetTextLang = $lang
                            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"
                        }
                        Write-Entry -Subtext "Posterpath: $posterpath" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "PosterUrl: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "PosterWithText: $global:PosterWithText" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "TMDBAssetTextLang: $global:TMDBAssetTextLang" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "TMDBAssetChangeUrl: $global:TMDBAssetChangeUrl" -Path $global:configLogging -Color Cyan -log Debug
                        return $global:posterurl
                        continue
                    }
                }
            }
        }
        if ($response) {
            if ($response.posters) {
                foreach ($lang in $global:PreferredSeasonLanguageOrderTMDB) {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($response.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                            $FavPoster = ($response.posters | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                        }
                        Else {
                            $FavPoster = ($response.posters | Where-Object { $_.iso_639_1 -eq $lang -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                        }
                    }
                    Else {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($response.posters | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                        }
                        Else {
                            $FavPoster = ($response.posters | Where-Object iso_639_1 -eq $lang)
                        }
                    }
                    if ($FavPoster) {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = $FavPoster[0].file_path
                        }
                        Else {
                            $posterpath = (($FavPoster | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            Write-Entry -Subtext "Found Poster without Language on TMDB" -Path $global:configLogging -Color Blue -log Info
                            $global:TextlessPoster = $true
                            $global:PosterWithText = $null
                        }
                        Else {
                            Write-Entry -Subtext "Found Poster with Language '$lang' on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        if ($lang -ne 'null' -or $lang -eq 'xx') {
                            $global:PosterWithText = $true
                            $global:TMDBAssetTextLang = $lang
                            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"
                        }
                        return $global:posterurl
                        continue
                    }
                }
            }
            Else {
                Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"
            }
        }
        Else {
            Write-Entry -Subtext "No Season Poster on TMDB" -Path $global:configLogging -Color Yellow -log Warning
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:SeasonNumber/images/posters"
        }

    }
}
function GetTMDBShowBackground {
    Write-Entry -Subtext "Searching on TMDB for a show background - TMDBID: $global:tmdbid" -Path $global:configLogging -Color Cyan -log Info
    if (!$global:tmdbid) {
        Write-Entry -Subtext "Cannot search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
    if ($global:BackgroundPreferTextless -eq $true) {
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/tv/$($global:tmdbid)?append_to_response=images&language=xx&include_image_language=$($global:PreferredBackgroundLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"

        }
        if ($response) {
            if ($response.images.backdrops) {
                if ($global:WidthHeightFilter -eq 'true') {
                    $NoLangPoster = ($response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                    $NoLangPoster = ($response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                }
                Else {
                    $NoLangPoster = ($response.images.backdrops | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                }
                if (!$NoLangPoster) {
                    Write-Entry -Subtext "PreferTextless Value: $global:BackgroundPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Subtext "OnlyTextless Value: $global:BackgroundOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                    if ($global:BackgroundOnlyTextless -eq $false) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $filteredPosters = $response.images.backdrops | Where-Object { $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = $filteredPosters[0].file_path
                                    $global:TMDBAssetTextLang = $filteredPosters[0].iso_639_1
                                    Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No Background posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                            Else {
                                $filteredPosters = $response.images.backdrops | Where-Object { $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                    $global:TMDBAssetTextLang = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                                    Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No Background posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                        }
                        Else {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $posterpath = $response.images.backdrops[0].file_path
                                $global:TMDBAssetTextLang = $response.images.backdrops[0].iso_639_1
                            }
                            Else {
                                $posterpath = (($response.images.backdrops | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                $global:TMDBAssetTextLang = (($response.images.backdrops | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                            }
                        }
                        if ($posterpath) {
                            $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                            if ($global:FavProvider -ne 'fanart') {

                                $global:Fallback = "fanart"
                                $global:tmdbfallbackposterurl = $global:posterurl
                            }
                            Write-Entry -Subtext "Found background with text on TMDB" -Path $global:configLogging -Color Blue -log Info
                            $global:PosterWithText = $true
                        }
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"
                    }
                    Else {
                        Write-Entry -Subtext "Found Poster with text on TMDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"
                    }
                }
                Else {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $filteredPosters = $response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                            if ($filteredPosters) {
                                $posterpath = $filteredPosters[0].file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No Background posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                        Else {
                            $filteredPosters = $response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }

                            if ($filteredPosters) {
                                $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No Background posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                    }
                    Else {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = (($response.images.backdrops | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })[0]).file_path
                        }
                        Else {
                            $posterpath = (($response.images.backdrops | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null } | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                    }
                    if ($posterpath) {
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        Write-Entry -Subtext "Found Textless background on TMDB" -Path $global:configLogging -Color Green -log Info
                        $global:TextlessPoster = $true
                        $global:PosterWithText = $null
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"
                        return $global:posterurl
                    }
                }
                if (!$global:posterurl) {
                    Write-Entry -Subtext "No Background found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                    if ($global:FavProvider -ne 'fanart') {
                        $global:Fallback = "fanart"
                    }
                }
            }
            Else {
                Write-Entry -Subtext "No Background found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"
                if ($global:FavProvider -ne 'fanart') {
                    $global:Fallback = "fanart"
                }
            }
        }
        Else {
            Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"
        }
    }
    Else {
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/tv/$($global:tmdbid)?append_to_response=images&language=$($PreferredBackgroundLanguageOrder[0])&include_image_language=$($global:PreferredBackgroundLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"

        }
        if ($response) {
            if ($response.images.backdrops) {
                foreach ($lang in $global:PreferredBackgroundLanguageOrderTMDB) {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                            $FavPoster = ($response.images.backdrops | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                        }
                        Else {
                            $FavPoster = ($response.images.backdrops | Where-Object { $_.iso_639_1 -eq $lang -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight })
                        }
                    }
                    Else {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($response.images.backdrops | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                        }
                        Else {
                            $FavPoster = ($response.images.backdrops | Where-Object iso_639_1 -eq $lang)
                        }
                    }
                    if ($FavPoster) {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = $FavPoster[0].file_path
                        }
                        Else {
                            $posterpath = (($FavPoster | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            Write-Entry -Subtext "Found background without Language on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        Else {
                            Write-Entry -Subtext "Found background with Language '$lang' on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        if ($lang -ne 'null' -or $lang -eq 'xx') {
                            $global:PosterWithText = $true
                            $global:TMDBAssetTextLang = $lang
                            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"
                        }
                        return $global:posterurl
                        continue
                    }
                }
                if (!$global:posterurl) {
                    Write-Entry -Subtext "No Background found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"
                    if ($global:FavProvider -ne 'fanart') {
                        $global:Fallback = "fanart"
                    }
                }
            }
            Else {
                Write-Entry -Subtext "No Background found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"
                if ($global:FavProvider -ne 'fanart') {
                    $global:Fallback = "fanart"
                }
            }
        }
        Else {
            Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/images/backdrops"
        }
    }
}
function GetTMDBTitleCard {
    Write-Entry -Subtext "Searching on TMDB for: $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card - TMDBID: $global:tmdbid" -Path $global:configLogging -Color Cyan -log Info
    if (!$global:tmdbid) {
        Write-Entry -Subtext "Cannot search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
    if ($global:TCPreferTextless -eq $true) {
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/tv/$($global:tmdbid)/season/$($global:season_number)/episode/$($global:episodenumber)/images?append_to_response=images&language=xx&include_image_language=$($global:PreferredTCLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
        }
        if ($response) {
            if ($response.stills) {
                if ($global:WidthHeightFilter -eq 'true') {
                    $NoLangPoster = ($response.stills | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight })
                }
                Else {
                    $NoLangPoster = ($response.stills | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                }
                if (!$NoLangPoster) {
                    Write-Entry -Subtext "PreferTextless Value: $global:TCPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Subtext "OnlyTextless Value: $global:TCOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                    if ($global:TCOnlyTextless -eq $false) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $filteredPosters = $response.stills | Where-Object { $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = $filteredPosters[0].file_path
                                    $global:TMDBAssetTextLang = $filteredPosters[0].iso_639_1
                                    Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No TC posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                            Else {
                                $filteredPosters = $response.stills | Where-Object { $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }

                                if ($filteredPosters) {
                                    $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                    $global:TMDBAssetTextLang = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                                    Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                                }
                                else {
                                    Write-Entry -Subtext "No TC posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                                }
                            }
                        }
                        Else {
                            if ($global:TMDBVoteSorting -eq 'primary') {
                                $posterpath = $response.stills[0].file_path
                                $global:TMDBAssetTextLang = $response.stills[0].iso_639_1
                            }
                            Else {
                                $posterpath = (($response.stills | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                $global:TMDBAssetTextLang = (($response.stills | Sort-Object $global:TMDBVoteSorting -Descending)[0]).iso_639_1
                            }
                        }
                        if ($posterpath) {
                            $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                            Write-Entry -Subtext "Found TC with text on TMDB" -Path $global:configLogging -Color Blue -log Info
                            $global:PosterWithText = $true
                        }
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
                    }
                    Else {
                        Write-Entry -Subtext "Found Poster with text on TMDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
                    }
                }
                Else {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $filteredPosters = $response.stills | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }

                            if ($filteredPosters) {
                                $posterpath = $filteredPosters[0].file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $($filteredPosters[0].width) | height: $($filteredPosters[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No TC posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                        Else {
                            $filteredPosters = $response.stills | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }

                            if ($filteredPosters) {
                                $posterpath = (($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                                Write-Entry -Subtext "Found a poster sized at - width: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).width) | height: $((($filteredPosters | Sort-Object $global:TMDBVoteSorting -Descending)[0]).height)" -Path $global:configLogging -Color White -log Info
                            }
                            else {
                                Write-Entry -Subtext "No TC posters found on TMDB with the specified dimensions." -Path $global:configLogging -Color Yellow -log Warning
                            }
                        }
                    }
                    Else {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = (($response.stills | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })[0]).file_path
                        }
                        Else {
                            $posterpath = (($response.stills | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null } | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                    }
                    if ($posterpath) {
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        Write-Entry -Subtext "Found Textless TC on TMDB" -Path $global:configLogging -Color Green -log Info
                        $global:TextlessPoster = $true
                        $global:PosterWithText = $null
                        $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
                        return $global:posterurl
                    }
                }
                if (!$global:posterurl) {
                    Write-Entry -Subtext "No TC found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                }
            }
            Else {
                Write-Entry -Subtext "No TC found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
            }
        }
        Else {
            Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
        }
    }
    Else {
        try {
            $response = (Invoke-WebRequest -Uri "https://api.themoviedb.org/3/tv/$($global:tmdbid)/season/$($global:season_number)/episode/$($global:episodenumber)/images?append_to_response=images&language=$($global:PreferredTCLanguageOrderTMDB[0])&include_image_language=$($global:PreferredTCLanguageOrderTMDB -join ',')" -Method GET -Headers $global:headers -ErrorAction SilentlyContinue).content | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch {
            Write-Entry -Subtext "Could not query TMDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"

        }
        if ($response) {
            if ($response.stills) {
                foreach ($lang in $global:PreferredTCLanguageOrderTMDB) {
                    if ($global:WidthHeightFilter -eq 'true') {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($response.stills | Where-Object { ($_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null) -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight })
                        }
                        Else {
                            $FavPoster = ($response.stills | Where-Object { $_.iso_639_1 -eq $lang -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight })
                        }
                    }
                    Else {
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            $FavPoster = ($response.stills | Where-Object { $_.iso_639_1 -eq 'xx' -or $_.iso_3166_1 -eq 'XX' -or $_.iso_3166_1 -eq $null -or $_.iso_639_1 -eq $null })
                        }
                        Else {
                            $FavPoster = ($response.stills | Where-Object iso_639_1 -eq $lang)
                        }
                    }
                    if ($FavPoster) {
                        if ($global:TMDBVoteSorting -eq 'primary') {
                            $posterpath = $FavPoster[0].file_path
                        }
                        Else {
                            $posterpath = (($FavPoster | Sort-Object $global:TMDBVoteSorting -Descending)[0]).file_path
                        }
                        $global:posterurl = "https://image.tmdb.org/t/p/original$posterpath"
                        if ($lang -eq 'null' -or $lang -eq 'xx') {
                            Write-Entry -Subtext "Found TC without Language on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        Else {
                            Write-Entry -Subtext "Found TC with Language '$lang' on TMDB" -Path $global:configLogging -Color Blue -log Info
                        }
                        if ($lang -ne 'null' -or $lang -eq 'xx') {
                            $global:PosterWithText = $true
                            $global:TMDBAssetTextLang = $lang
                            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
                        }
                        return $global:posterurl
                        continue
                    }
                }
                if (!$global:posterurl) {
                    Write-Entry -Subtext "No TC found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
                }
            }
            Else {
                Write-Entry -Subtext "No TC found on TMDB" -Path $global:configLogging -Color Yellow -log Warning
                $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
            }
        }
        Else {
            Write-Entry -Subtext "TMDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:TMDBAssetChangeUrl = "https://www.themoviedb.org/tv/$($global:tmdbid)/season/$global:season_number/episode/$global:episodenumber/images/backdrops"
        }
    }
}
function GetFanartMoviePoster {
    $global:Fallback = $null
    Write-Entry -Subtext "Searching on Fanart.tv for a movie poster" -Path $global:configLogging -Color Cyan -log Info
    if ($global:PosterPreferTextless -eq $true) {
        $ids = @($global:tmdbid, $global:imdbid)
        $entrytemp = $null

        foreach ($id in $ids) {
            if ($id) {
                $entrytemp = Get-FanartTv -Type movies -id $id -ErrorAction SilentlyContinue
                if ($entrytemp -and $entrytemp.movieposter) {
                    if (!($entrytemp.movieposter | Where-Object lang -eq '00')) {
                        Write-Entry -Subtext "PreferTextless Value: $global:PosterPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "OnlyTextless Value: $global:PosterOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                        if ($global:PosterOnlyTextless -eq $false) {
                            $global:posterurl = ($entrytemp.movieposter)[0].url
                            Write-Entry -Subtext "Found Poster with text on Fanart.tv"  -Path $global:configLogging -Color Blue -log Info
                            $global:PosterWithText = $true
                            $global:FANARTAssetTextLang = ($entrytemp.movieposter)[0].lang
                            $global:FANARTAssetChangeUrl = "https://fanart.tv/movie/$id"

                            if ($global:FavProvider -eq 'FANART') {
                                $global:Fallback = "TMDB"
                                $global:fanartfallbackposterurl = ($entrytemp.movieposter)[0].url
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Found Poster with text on FANART, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                            $global:FANARTAssetChangeUrl = "https://fanart.tv/movie/$id"
                        }
                        return $global:posterurl
                        continue
                    }
                    Else {
                        $global:posterurl = ($entrytemp.movieposter | Where-Object lang -eq '00')[0].url
                        Write-Entry -Subtext "Found Textless Poster on Fanart.tv" -Path $global:configLogging -Color Green -log Info
                        $global:TextlessPoster = $true
                        $global:PosterWithText = $null
                        $global:FANARTAssetChangeUrl = "https://fanart.tv/movie/$id"
                        return $global:posterurl
                        break
                    }
                }
            }
        }
        if ($null -eq $ids[0] -and $null -eq $ids[1]) {
            Write-Entry -Subtext "Cannot search on FANART, missing IDs..." -Path $global:configLogging -Color Yellow -log Warning
        }
        if (!$global:posterurl) {
            Write-Entry -Subtext "No movie match or poster found on Fanart.tv" -Path $global:configLogging -Color Yellow -log Warning
        }
        Else {
            return $global:posterurl
        }
    }
    Else {
        $ids = @($global:tmdbid, $global:imdbid)
        $entrytemp = $null

        foreach ($id in $ids) {
            if ($id) {
                $entrytemp = Get-FanartTv -Type movies -id $id -ErrorAction SilentlyContinue
                if ($entrytemp -and $entrytemp.movieposter) {
                    foreach ($lang in $global:PreferredLanguageOrderFanart) {
                        if (($entrytemp.movieposter | Where-Object lang -eq "$lang")) {
                            $global:posterurl = ($entrytemp.movieposter)[0].url
                            if ($lang -eq '00') {
                                Write-Entry -Subtext "Found Poster without Language on FANART" -Path $global:configLogging -Color Blue -log Info
                                $global:TextlessPoster = $true
                                $global:PosterWithText = $null
                            }
                            Else {
                                Write-Entry -Subtext "Found Poster with Language '$lang' on FANART" -Path $global:configLogging -Color Blue -log Info
                            }
                            if ($lang -ne '00') {
                                $global:PosterWithText = $true
                                $global:FANARTAssetTextLang = $lang
                            }
                            return $global:posterurl
                            continue
                        }
                    }
                }
            }
        }
        if ($null -eq $ids[0] -and $null -eq $ids[1]) {
            Write-Entry -Subtext "Cannot search on FANART, missing IDs..." -Path $global:configLogging -Color Yellow -log Warning
        }
        if (!$global:posterurl) {
            Write-Entry -Subtext "No movie match or poster found on Fanart.tv" -Path $global:configLogging -Color Yellow -log Warning
        }
        Else {
            return $global:posterurl
        }
    }
}
function GetFanartMovieBackground {
    $global:Fallback = $null
    Write-Entry -Subtext "Searching on Fanart.tv for a Background poster" -Path $global:configLogging -Color Cyan -log Info
    $ids = @($global:tmdbid, $global:imdbid)
    $entrytemp = $null

    foreach ($id in $ids) {
        if ($id) {
            $entrytemp = Get-FanartTv -Type movies -id $id -ErrorAction SilentlyContinue
            if ($entrytemp -and $entrytemp.moviebackground) {
                if (!($entrytemp.moviebackground | Where-Object lang -eq '')) {
                    Write-Entry -Subtext "PreferTextless Value: $global:BackgroundPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Subtext "OnlyTextless Value: $global:BackgroundOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                    if ($global:BackgroundOnlyTextless -eq $false) {
                        $global:posterurl = ($entrytemp.moviebackground)[0].url
                        Write-Entry -Subtext "Found Background with text on Fanart.tv"  -Path $global:configLogging -Color Blue -log Info
                        $global:PosterWithText = $true
                        $global:FANARTAssetTextLang = ($entrytemp.moviebackground)[0].lang
                        $global:FANARTAssetChangeUrl = "https://fanart.tv/movie/$id"

                        if ($global:FavProvider -eq 'FANART') {
                            $global:Fallback = "TMDB"
                            $global:fanartfallbackposterurl = ($entrytemp.moviebackground)[0].url
                        }
                    }
                    Else {
                        Write-Entry -Subtext "Found Background with text on FANART, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                        $global:FANARTAssetChangeUrl = "https://fanart.tv/movie/$id"
                    }
                    return $global:posterurl
                    continue
                }
                Else {
                    $global:posterurl = ($entrytemp.moviebackground | Where-Object lang -eq '')[0].url
                    Write-Entry -Subtext "Found Textless background on Fanart.tv" -Path $global:configLogging -Color Green -log Info
                    $global:TextlessPoster = $true
                    $global:PosterWithText = $null
                    $global:FANARTAssetChangeUrl = "https://fanart.tv/movie/$id"
                    return $global:posterurl
                    continue
                }
            }
        }
    }
    if ($null -eq $ids[0] -and $null -eq $ids[1]) {
        Write-Entry -Subtext "Cannot search on FANART, missing IDs..." -Path $global:configLogging -Color Yellow -log Warning
    }
    if (!$global:posterurl) {
        Write-Entry -Subtext "No movie match or background found on Fanart.tv" -Path $global:configLogging -Color Yellow -log Warning
    }
    Else {
        return $global:posterurl
    }

}
function GetFanartShowPoster {
    $global:Fallback = $null
    Write-Entry -Subtext "Searching on Fanart.tv for a show poster" -Path $global:configLogging -Color Cyan -log Info
    if ($global:PosterPreferTextless -eq $true) {
        $id = $global:tvdbid
        $entrytemp = $null
        if ($id) {
            $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue
            if ($entrytemp -and $entrytemp.tvposter) {
                if (!($entrytemp.tvposter | Where-Object lang -eq '00')) {
                    Write-Entry -Subtext "PreferTextless Value: $global:PosterPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Subtext "OnlyTextless Value: $global:PosterOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                    if ($global:PosterOnlyTextless -eq $false) {
                        $global:posterurl = ($entrytemp.tvposter)[0].url

                        Write-Entry -Subtext "Found Poster with text on Fanart.tv" -Path $global:configLogging -Color Blue -log Info
                        $global:PosterWithText = $true
                        $global:FANARTAssetTextLang = ($entrytemp.tvposter)[0].lang
                        $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"

                        if ($global:FavProvider -eq 'FANART') {
                            $global:Fallback = "TMDB"
                            $global:fanartfallbackposterurl = ($entrytemp.tvposter)[0].url
                        }
                    }
                    Else {
                        Write-Entry -Subtext "Found Poster with text on FANART, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                        if ($global:FavProvider -eq 'FANART') {
                            $global:Fallback = "TMDB"
                        }
                        $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                    }
                    return $global:posterurl
                    continue
                }
                Else {
                    $global:posterurl = ($entrytemp.tvposter | Where-Object lang -eq '00')[0].url
                    Write-Entry -Subtext "Found Textless Poster on Fanart.tv" -Path $global:configLogging -Color Green -log Info
                    $global:TextlessPoster = $true
                    $global:PosterWithText = $null
                    $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                    return $global:posterurl
                    break
                }
            }
        }
        Else {
            Write-Entry -Subtext "Cannot search on FANART, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
            if ($global:FavProvider -eq 'FANART') {
                $global:Fallback = "TMDB"
            }
        }
        if (!$global:posterurl) {
            Write-Entry -Subtext "No show match or poster found on Fanart.tv" -Path $global:configLogging -Color Yellow -log Warning
            if ($global:FavProvider -eq 'FANART') {
                $global:Fallback = "TMDB"
            }
        }
        Else {
            return $global:posterurl
        }
    }
    Else {
        $id = $global:tvdbid
        $entrytemp = $null

        if ($id) {
            $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue
            if ($entrytemp -and $entrytemp.tvposter) {
                foreach ($lang in $global:PreferredSeasonLanguageOrderFanart) {
                    if (($entrytemp.tvposter | Where-Object lang -eq "$lang")) {
                        $global:posterurl = ($entrytemp.tvposter)[0].url
                        if ($lang -eq '00') {
                            Write-Entry -Subtext "Found Poster without Language on FANART" -Path $global:configLogging -Color Blue -log Info
                            $global:TextlessPoster = $true
                            $global:PosterWithText = $null
                        }
                        Else {
                            Write-Entry -Subtext "Found Poster with Language '$lang' on FANART" -Path $global:configLogging -Color Blue -log Info
                        }
                        if ($lang -ne '00') {
                            $global:PosterWithText = $true
                            $global:FANARTAssetTextLang = $lang
                        }
                        return $global:posterurl
                        continue
                    }
                }
            }
        }
        Else {
            Write-Entry -Subtext "Cannot search on FANART, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
        }
        if (!$global:posterurl) {
            Write-Entry -Subtext "No show match or poster found on Fanart.tv" -Path $global:configLogging -Color Yellow -log Warning
            if ($global:FavProvider -eq 'FANART') {
                $global:Fallback = "TMDB"
            }
        }
        Else {
            return $global:posterurl
        }
    }
}
function GetFanartShowBackground {
    $global:Fallback = $null
    Write-Entry -Subtext "Searching on Fanart.tv for a Background poster" -Path $global:configLogging -Color Cyan -log Info
    $id = $global:tvdbid
    $entrytemp = $null

    if ($id) {
        $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue
        if ($entrytemp -and $entrytemp.showbackground) {
            if (!($entrytemp.showbackground | Where-Object lang -eq '')) {
                Write-Entry -Subtext "PreferTextless Value: $global:BackgroundPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Subtext "OnlyTextless Value: $global:BackgroundOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                if ($global:BackgroundOnlyTextless -eq $false) {
                    $global:posterurl = ($entrytemp.showbackground)[0].url
                    Write-Entry -Subtext "Found Background with text on Fanart.tv"  -Path $global:configLogging -Color Blue -log Info
                    $global:PosterWithText = $true
                    $global:FANARTAssetTextLang = ($entrytemp.showbackground)[0].lang
                    $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"

                    if ($global:FavProvider -eq 'FANART') {
                        $global:Fallback = "TMDB"
                        $global:fanartfallbackposterurl = ($entrytemp.showbackground)[0].url
                    }
                }
                Else {
                    Write-Entry -Subtext "Found Background with text on FANART, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                    $global:FANARTAssetChangeUrl = "https://fanart.tv/movie/$id"
                }
                return $global:posterurl
                continue
            }
            Else {
                $global:posterurl = ($entrytemp.showbackground | Where-Object lang -eq '')[0].url
                Write-Entry -Subtext "Found Textless background on Fanart.tv" -Path $global:configLogging -Color Green -log Info
                $global:TextlessPoster = $true
                $global:PosterWithText = $null
                $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                return $global:posterurl
                continue
            }
        }
    }
    Else {
        Write-Entry -Subtext "Cannot search on FANART, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
    if (!$global:posterurl) {
        Write-Entry -Subtext "No show match or background found on Fanart.tv" -Path $global:configLogging -Color Yellow -log Warning
    }
    Else {
        return $global:posterurl
    }

}
function GetFanartSeasonPoster {
    Write-Entry -Subtext "Searching on Fanart.tv for Season '$global:SeasonNumber' poster" -Path $global:configLogging -Color Cyan -log Info
    $id = $global:tvdbid
    $entrytemp = $null
    if ($global:SeasonPreferTextless -eq $true) {
        if ($id) {
            $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue
            if ($entrytemp.seasonposter) {
                if ($global:SeasonNumber -match '\b\d{1,2}\b') {
                    $NoLangPoster = ($entrytemp.seasonposter | Where-Object { $_.lang -eq '00' -and $_.Season -eq $global:SeasonNumber } | Sort-Object likes)
                    if ($NoLangPoster) {
                        $global:posterurl = ($NoLangPoster | Sort-Object likes)[0].url
                        Write-Entry -Subtext "Found Season Poster without Language on FANART" -Path $global:configLogging -Color Blue -log Info
                        $global:TextlessPoster = $true
                        $global:PosterWithText = $null
                        $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                        Write-Entry -Subtext "NoLangPoster: $NoLangPoster" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "PosterUrl: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "TextlessPoster: $global:TextlessPoster" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "FANARTAssetChangeUrl: $global:FANARTAssetChangeUrl" -Path $global:configLogging -Color Cyan -log Debug
                    }
                    Else {
                        if (!$global:SeasonOnlyTextless) {
                            Write-Entry -Subtext "No Textless Season Poster on FANART" -Path $global:configLogging -Color Blue -log Info
                            foreach ($lang in $global:PreferredSeasonLanguageOrderFanart) {
                                $FoundPoster = ($entrytemp.seasonposter | Where-Object { $_.lang -eq "$lang" -and $_.Season -eq $global:SeasonNumber } | Sort-Object likes)
                                if ($FoundPoster) {
                                    $global:posterurl = $FoundPoster[0].url
                                    Write-Entry -Subtext "Found season Poster with Language '$lang' on FANART" -Path $global:configLogging -Color Blue -log Info
                                    $global:PosterWithText = $true
                                    $global:FANARTAssetTextLang = $lang
                                    $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                                    $global:FANARTSeasonFallback = $global:posterurl
                                    Write-Entry -Subtext "FoundPoster: $FoundPoster" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Subtext "PosterUrl: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Subtext "PosterWithText: $global:PosterWithText" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Subtext "FANARTAssetTextLang: $global:FANARTAssetTextLang" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Subtext "FANARTAssetChangeUrl: $global:FANARTAssetChangeUrl" -Path $global:configLogging -Color Cyan -log Debug
                                    return $global:posterurl
                                }
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Found Poster with text on FANART, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                            $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                        }
                    }
                }
                Else {
                    Write-Entry -Subtext "Could not get a result with '$global:SeasonNumber' on Fanart, likely season number not in correct format, fallback to Show poster." -Path $global:configLogging -Color Blue -log Info
                    if ($entrytemp -and $entrytemp.tvposter) {
                        foreach ($lang in $global:PreferredSeasonLanguageOrderFanart) {
                            if (($entrytemp.tvposter | Where-Object lang -eq "$lang")) {
                                $global:posterurl = ($entrytemp.tvposter)[0].url
                                if ($lang -eq '00') {
                                    Write-Entry -Subtext "Found Poster without Language on FANART" -Path $global:configLogging -Color Blue -log Info
                                    $global:TextlessPoster = $true
                                    $global:PosterWithText = $null
                                    $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                                }
                                Else {
                                    if (!$global:SeasonOnlyTextless) {
                                        Write-Entry -Subtext "Found Poster with Language '$lang' on FANART" -Path $global:configLogging -Color Blue -log Info
                                    }
                                }
                                if (!$global:SeasonOnlyTextless -and !$global:TextlessPoster) {
                                    if ($lang -ne '00') {
                                        $global:PosterWithText = $true
                                        $global:FANARTAssetTextLang = $lang
                                        $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                                        $global:FANARTSeasonFallback = $global:posterurl
                                    }
                                }
                                Else {
                                    Write-Entry -Subtext "Found Poster with text on FANART, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                                    $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                                    $global:posterurl = $null
                                }
                                return $global:posterurl
                            }
                        }
                    }
                }
            }
            Else {
                $global:posterurl = $null
            }
        }
        Else {
            Write-Entry -Subtext "Cannot search on FANART, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
        }
        if ($global:posterurl) {
            Write-Entry -Subtext "Found season poster on Fanart" -Path $global:configLogging -Color Cyan -log Info
            return $global:posterurl
        }
        Else {
            if ($global:PosterOnlyTextless -eq $true) {
                Write-Entry -Subtext "No Textless Season Poster on Fanart" -Path $global:configLogging -Color Yellow -log Warning
            }
            Else {
                Write-Entry -Subtext "No Season Poster on Fanart" -Path $global:configLogging -Color Yellow -log Warning
            }
        }
    }
    Else {
        if ($id) {
            $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue
            if ($entrytemp.seasonposter) {
                foreach ($lang in $global:PreferredSeasonLanguageOrderFanart) {
                    $FoundPoster = ($entrytemp.seasonposter | Where-Object { $_.lang -eq "$lang" -and $_.Season -eq $global:SeasonNumber } | Sort-Object likes)
                    if ($FoundPoster) {
                        $global:posterurl = $FoundPoster[0].url
                    }
                    if ($global:posterurl) {
                        if ($lang -eq '00') {
                            Write-Entry -Subtext "Found season Poster without Language on FANART" -Path $global:configLogging -Color Blue -log Info
                            $global:TextlessPoster = $true
                            $global:PosterWithText = $null
                            $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                        }
                        Else {
                            Write-Entry -Subtext "Found season Poster with Language '$lang' on FANART" -Path $global:configLogging -Color Blue -log Info
                            $global:PosterWithText = $true
                            $global:FANARTAssetTextLang = $lang
                            $global:FANARTAssetChangeUrl = "https://fanart.tv/series/$id"
                            return $global:posterurl
                        }
                    }
                }
            }
            Else {
                $global:posterurl = $null
                return $global:posterurl
            }
        }
        Else {
            Write-Entry -Subtext "Cannot search on FANART, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
        }
        if ($global:posterurl) {
            return $global:posterurl
        }
        Else {
            if ($global:PosterOnlyTextless -eq $true) {
                Write-Entry -Subtext "No Textless Season Poster on Fanart" -Path $global:configLogging -Color Yellow -log Warning
            }
            Else {
                Write-Entry -Subtext "No Season Poster on Fanart" -Path $global:configLogging -Color Yellow -log Warning
            }
        }
    }
}
function GetTVDBMoviePoster {
    if ($global:tvdbid) {
        if ($global:PosterPreferTextless -eq $true) {
            Write-Entry -Subtext "Searching on TVDB for a movie poster - TVDBID: $global:tvdbid" -Path $global:configLogging -Color Cyan -log Info
            try {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/movies/$($global:tvdbid)/extended" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
            catch {
                Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
            if ($response) {
                if ($response.data.artworks) {
                    if ($global:WidthHeightFilter -eq 'true') {
                        $global:posterurltmp = ($response.data.artworks | Where-Object { $null -eq $_.language -and $_.type -eq '14' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight } | Sort-Object Score -Descending)
                    }
                    Else {
                        $global:posterurltmp = ($response.data.artworks | Where-Object { $null -eq $_.language -and $_.type -eq '14' } | Sort-Object Score -Descending)
                    }
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                    if ($global:posterurltmp) {
                        $global:posterurl = $global:posterurltmp[0].image
                        if ($global:WidthHeightFilter -eq 'true') {
                            Write-Entry -Subtext "Found a poster sized at - width: $($global:posterurltmp[0].width) | height: $($global:posterurltmp[0].height)" -Path $global:configLogging -Color White -log Info
                        }
                        Write-Entry -Subtext "Found Textless Poster on TVDB" -Path $global:configLogging -Color Blue -log Info
                        return $global:posterurl
                    }
                    Else {
                        Write-Entry -Subtext "PreferTextless Value: $global:PosterPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "OnlyTextless Value: $global:PosterOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                        if ($global:PosterOnlyTextless -eq $false) {
                            foreach ($lang in $global:PreferredLanguageOrderTVDB) {
                                if ($global:WidthHeightFilter -eq 'true') {
                                    if ($lang -eq 'null') {
                                        $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '14' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight } | Sort-Object Score -Descending)
                                    }
                                    Else {
                                        $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '14' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight } | Sort-Object Score -Descending)
                                    }
                                }
                                Else {
                                    if ($lang -eq 'null') {
                                        $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '14' } | Sort-Object Score -Descending)
                                    }
                                    Else {
                                        $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '14' } | Sort-Object Score -Descending)
                                    }
                                }
                                if ($LangArtwork) {
                                    $global:posterurl = $LangArtwork[0].image
                                    if ($global:WidthHeightFilter -eq 'true') {
                                        Write-Entry -Subtext "Found a poster sized at - width: $($LangArtwork[0].width) | height: $($LangArtwork[0].height)" -Path $global:configLogging -Color White -log Info
                                    }
                                    if ($lang -eq 'null') {
                                        Write-Entry -Subtext "Found Poster without Language on TVDB" -Path $global:configLogging -Color Blue -log Info
                                        $global:TextlessPoster = $true
                                        $global:PosterWithText = $null
                                    }
                                    Else {
                                        Write-Entry -Subtext "Found Poster with Language '$lang' on TVDB" -Path $global:configLogging -Color Blue -log Info
                                    }
                                    if ($lang -ne 'null') {
                                        $global:PosterWithText = $true
                                        $global:TVDBAssetTextLang = $lang
                                        if ($global:FavProvider -eq 'TVDB') {
                                            $global:Fallback = "TMDB"
                                            $global:TVDBfallbackposterurl = $LangArtwork[0].image
                                        }
                                    }
                                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                                    return $global:posterurl
                                    continue
                                }
                            }
                        }
                        Else {
                            Write-Entry -Subtext "No Textless Poster on TVDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                        }
                    }
                }
                Else {
                    Write-Entry -Subtext "No Poster found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                }
            }
            Else {
                Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
            }
        }
        Else {
            Write-Entry -Subtext "Searching on TVDB for a movie poster" -Path $global:configLogging -Color Cyan -log Info
            try {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/movies/$($global:tvdbid)/extended" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
            catch {
                Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
            if ($response) {
                if ($response.data.artworks) {
                    foreach ($lang in $global:PreferredLanguageOrderTVDB) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '14' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '14' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight } | Sort-Object Score -Descending)
                            }
                        }
                        Else {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '14' } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '14' } | Sort-Object Score -Descending)
                            }
                        }
                        if ($LangArtwork) {
                            $global:posterurl = $LangArtwork[0].image
                            if ($global:WidthHeightFilter -eq 'true') {
                                Write-Entry -Subtext "Found a poster sized at - width: $($LangArtwork[0].width) | height: $($LangArtwork[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            if ($lang -eq 'null') {
                                Write-Entry -Subtext "Found Poster without Language on TVDB" -Path $global:configLogging -Color Blue -log Info
                                $global:TextlessPoster = $true
                                $global:PosterWithText = $null
                            }
                            Else {
                                Write-Entry -Subtext "Found Poster with Language '$lang' on TVDB" -Path $global:configLogging -Color Blue -log Info
                            }
                            if ($lang -ne 'null') {
                                $global:PosterWithText = $true
                                $global:TVDBAssetTextLang = $lang
                            }
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                            return $global:posterurl
                            continue
                        }
                    }
                }
                Else {
                    Write-Entry -Subtext "No Poster found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                }
            }
            Else {
                Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
            }
        }
    }
    Else {
        Write-Entry -Subtext "Cannot search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
}
function GetTVDBMovieBackground {
    if ($global:tvdbid) {
        if ($global:BackgroundPreferTextless -eq $true) {
            Write-Entry -Subtext "Searching on TVDB for a movie Background - TVDBID: $global:tvdbid" -Path $global:configLogging -Color Cyan -log Info
            try {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/movies/$($global:tvdbid)/extended" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
            catch {
                Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
            if ($response) {
                if ($response.data.artworks) {
                    if ($global:WidthHeightFilter -eq 'true') {
                        $NoLangArtwork = $response.data.artworks | Where-Object { $null -eq $_.language -and $_.type -eq '15' -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }
                    }
                    Else {
                        $NoLangArtwork = $response.data.artworks | Where-Object { $null -eq $_.language -and $_.type -eq '15' }
                    }
                    if ($NoLangArtwork) {
                        $global:posterurl = ($NoLangArtwork | Sort-Object Score -Descending)[0].image
                        if ($global:WidthHeightFilter -eq 'true') {
                            Write-Entry -Subtext "Found a poster sized at - width: $(($NoLangArtwork | Sort-Object Score -Descending)[0].width) | height: $(($NoLangArtwork | Sort-Object Score -Descending)[0].height)" -Path $global:configLogging -Color White -log Info
                        }
                        Write-Entry -Subtext "Found Textless Background on TVDB" -Path $global:configLogging -Color Blue -log Info
                        $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                        return $global:posterurl
                    }
                    Else {
                        Write-Entry -Subtext "PreferTextless Value: $global:BackgroundPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "OnlyTextless Value: $global:BackgroundOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                        if ($global:BackgroundOnlyTextless -eq $false) {
                            # Trying other languages
                            foreach ($lang in $global:PreferredBackgroundLanguageOrderTVDB) {
                                if ($global:WidthHeightFilter -eq 'true') {
                                    if ($lang -eq 'null') {
                                        $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '15' -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight } | Sort-Object Score -Descending)
                                    }
                                    Else {
                                        $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '15' -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight } | Sort-Object Score -Descending)
                                    }
                                }
                                Else {
                                    if ($lang -eq 'null') {
                                        $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '15' } | Sort-Object Score -Descending)
                                    }
                                    Else {
                                        $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '15' } | Sort-Object Score -Descending)
                                    }
                                }
                                if ($LangArtwork) {
                                    $global:posterurl = $LangArtwork[0].image
                                    if ($global:WidthHeightFilter -eq 'true') {
                                        Write-Entry -Subtext "Found a poster sized at - width: $($LangArtwork[0].width) | height: $($LangArtwork[0].height)" -Path $global:configLogging -Color White -log Info
                                    }
                                    if ($lang -eq 'null') {
                                        Write-Entry -Subtext "Found Background without Language on TVDB" -Path $global:configLogging -Color Blue -log Info
                                    }
                                    Else {
                                        Write-Entry -Subtext "Found Background with Language '$lang' on TVDB" -Path $global:configLogging -Color Blue -log Info
                                    }
                                    if ($lang -ne 'null') {
                                        $global:PosterWithText = $true
                                        $global:TVDBAssetTextLang = $lang
                                        if ($global:FavProvider -eq 'TVDB') {
                                            $global:Fallback = "TMDB"
                                            $global:TVDBfallbackposterurl = $LangArtwork[0].image
                                        }
                                    }
                                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                                    return $global:posterurl
                                    continue
                                }
                            }
                            if (!$global:posterurl) {
                                Write-Entry -Subtext "No background found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                                $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Found background with text on TVDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
                        }
                    }
                }
                Else {
                    Write-Entry -Subtext "No Background found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                }
            }
            Else {
                Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
            }
        }
        Else {
            Write-Entry -Subtext "Searching on TVDB for a movie Background" -Path $global:configLogging -Color Cyan -log Info
            try {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/movies/$($global:tvdbid)/extended" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
            catch {
                Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
            if ($response) {
                if ($response.data.artworks) {
                    foreach ($lang in $global:PreferredBackgroundLanguageOrderTVDB) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '15' -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '15' -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight } | Sort-Object Score -Descending)
                            }
                        }
                        Else {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '15' } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '15' } | Sort-Object Score -Descending)
                            }
                        }
                        if ($LangArtwork) {
                            $global:posterurl = $LangArtwork[0].image
                            if ($global:WidthHeightFilter -eq 'true') {
                                Write-Entry -Subtext "Found a poster sized at - width: $($LangArtwork[0].width) | height: $($LangArtwork[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            if ($lang -eq 'null') {
                                Write-Entry -Subtext "Found Background without Language on TVDB" -Path $global:configLogging -Color Blue -log Info
                            }
                            Else {
                                Write-Entry -Subtext "Found Background with Language '$lang' on TVDB" -Path $global:configLogging -Color Blue -log Info
                            }
                            if ($lang -ne 'null') {
                                $global:PosterWithText = $true
                                $global:TVDBAssetTextLang = $lang
                            }
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                            return $global:posterurl
                            continue
                        }
                    }
                    if (!$global:posterurl) {
                        Write-Entry -Subtext "No background found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                        $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                    }
                }
                Else {
                    Write-Entry -Subtext "No Background found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
                }
            }
            Else {
                Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/movies/$($response.data.slug)#artwork"
            }
        }
    }
    Else {
        Write-Entry -Subtext "Cannot search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
}
function GetTVDBShowPoster {
    if ($global:tvdbid) {
        Write-Entry -Subtext "Searching on TVDB for a poster - TVDBID: $global:tvdbid" -Path $global:configLogging -Color Cyan -log Info
        if ($global:PosterPreferTextless -eq $true) {
            try {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/series/$($global:tvdbid)/artworks" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
            catch {
                Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
            if ($response) {
                if ($response.data) {
                    $defaultImageurl = $response.data.image
                    if ($global:WidthHeightFilter -eq 'true') {
                        $NoLangImageUrl = $response.data.artworks | Where-Object { $null -eq $_.language -and $_.type -eq '2' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight }
                    }
                    Else {
                        $NoLangImageUrl = $response.data.artworks | Where-Object { $null -eq $_.language -and $_.type -eq '2' }
                    }
                    if ($NoLangImageUrl) {
                        $global:posterurl = $NoLangImageUrl[0].image
                        if ($global:WidthHeightFilter -eq 'true') {
                            Write-Entry -Subtext "Found a poster sized at - width: $($NoLangImageUrl[0].width) | height: $($NoLangImageUrl[0].height)" -Path $global:configLogging -Color White -log Info
                        }
                        Write-Entry -Subtext "Found Textless Poster on TVDB" -Path $global:configLogging -Color Blue -log Info
                        $global:TextlessPoster = $true
                        $global:PosterWithText = $null
                        $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)#artwork"
                    }
                    Else {
                        Write-Entry -Subtext "PreferTextless Value: $global:PosterPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Subtext "OnlyTextless Value: $global:PosterOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                        if ($global:PosterOnlyTextless -eq $false) {
                            $global:posterurl = $defaultImageurl
                            Write-Entry -Subtext "Found Poster with text on TVDB" -Path $global:configLogging -Color Blue -log Info
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)#artwork"
                            if ($global:FavProvider -ne 'TVDB') {
                                if (!$global:tmdbsearched) {
                                    $global:Fallback = "TMDB"
                                }
                                $global:TVDBfallbackposterurl = $global:posterurl
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Found Poster with text on TVDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)#artwork"
                        }
                    }
                    return $global:posterurl
                }
                Else {
                    Write-Entry -Subtext "No Poster found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)#artwork"
                }
            }
            Else {
                Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)#artwork"
            }
        }
        Else {
            try {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/series/$($global:tvdbid)/artworks" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
            catch {
                Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
            if ($response) {
                if ($response.data) {
                    foreach ($lang in $global:PreferredLanguageOrderTVDB) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '2' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '2' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight } | Sort-Object Score -Descending)
                            }
                        }
                        Else {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '2' } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '2' } | Sort-Object Score -Descending)
                            }
                        }
                        if ($LangArtwork) {
                            $global:posterurl = $LangArtwork[0].image
                            if ($global:WidthHeightFilter -eq 'true') {
                                Write-Entry -Subtext "Found a poster sized at - width: $($LangArtwork[0].width) | height: $($LangArtwork[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            if ($lang -eq 'null') {
                                Write-Entry -Subtext "Found Poster without Language on TVDB" -Path $global:configLogging -Color Blue -log Info
                                $global:TextlessPoster = $true
                                $global:PosterWithText = $null
                            }
                            Else {
                                Write-Entry -Subtext "Found Poster with Language '$lang' on TVDB" -Path $global:configLogging -Color Blue -log Info
                            }
                            if ($lang -ne 'null') {
                                $global:PosterWithText = $true
                                $global:TVDBAssetTextLang = $lang
                            }
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)#artwork"
                            return $global:posterurl
                            continue
                        }
                    }
                }
                Else {
                    Write-Entry -Subtext "No Poster found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)#artwork"
                }
            }
            Else {
                Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)#artwork"
            }
        }
    }
    Else {
        Write-Entry -Subtext "Cannot search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
}
function GetTVDBSeasonPoster {
    if ($global:tvdbid) {
        Write-Entry -Subtext "Searching on TVDB for a Season poster - TVDBID: $global:tvdbid" -Path $global:configLogging -Color Cyan -log Info
        try {
            $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/series/$($global:tvdbid)/extended" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
        }
        catch {
            Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

        }
        if ($response) {
            if ($response.data.seasons) {
                # Select season id from current Season number
                $SeasonID = $response.data.seasons | Where-Object { $_.number -eq $global:SeasonNumber -and $_.type.type -eq 'official' }
                if (!$SeasonID) {
                    $SeasonID = $response.data.seasons | Where-Object { $_.number -eq $global:SeasonNumber -and $_.type.type -eq 'alternate' }
                }
                try {
                    $Seasonresponse = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/seasons/$($SeasonID.id)/extended" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
                }
                catch {
                    Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                }
                if ($Seasonresponse) {
                    foreach ($lang in $global:PreferredSeasonLanguageOrderTVDB) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($Seasonresponse.data.artwork | Where-Object { $_.language -like "" -and $_.type -eq '7' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($Seasonresponse.data.artwork  | Where-Object { $_.language -like "$lang*" -and $_.type -eq '7' -and $_.width -ge $global:PosterMinWidth -and $_.height -ge $global:PosterMinHeight } | Sort-Object Score -Descending)
                            }
                        }
                        Else {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($Seasonresponse.data.artwork | Where-Object { $_.language -like "" -and $_.type -eq '7' } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($Seasonresponse.data.artwork  | Where-Object { $_.language -like "$lang*" -and $_.type -eq '7' } | Sort-Object Score -Descending)
                            }
                        }
                        if ($LangArtwork) {
                            $global:posterurl = $LangArtwork[0].image
                            if ($global:WidthHeightFilter -eq 'true') {
                                Write-Entry -Subtext "Found a poster sized at - width: $($LangArtwork[0].width) | height: $($LangArtwork[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            if ($lang -eq 'null') {
                                Write-Entry -Subtext "Found Season Poster without Language on TVDB" -Path $global:configLogging -Color Blue -log Info
                                $global:TextlessPoster = $true
                                $global:PosterWithText = $null
                            }
                            Else {
                                Write-Entry -Subtext "Found Season Poster with Language '$lang' on TVDB" -Path $global:configLogging -Color Blue -log Info
                            }
                            if ($lang -ne 'null') {
                                $global:PosterWithText = $true
                                $global:TVDBAssetTextLang = $lang
                            }
                            if (!$global:SeasonOnlyTextless -and !$global:TextlessPoster) {
                                $global:TVDBSeasonFallback = $global:posterurl
                            }
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/seasons/$($Seasonresponse.data.type.type)/$global:SeasonNumber#artwork"
                            Write-Entry -Subtext "LangArtwork: $LangArtwork" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "PosterUrl: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "TextlessPoster: $global:TextlessPoster" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "PosterWithText: $global:PosterWithText" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "TVDBAssetTextLang: $global:TVDBAssetTextLang" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "TVDBAssetChangeUrl: $global:TVDBAssetChangeUrl" -Path $global:configLogging -Color Cyan -log Debug
                            if ($global:SeasonOnlyTextless -and $global:PosterWithText) {
                                continue
                            }
                            Else {
                                return $global:posterurl
                            }
                            continue
                        }
                    }
                    if (!$global:posterurl -and $global:PosterOnlyTextless -eq $true) {
                        Write-Entry -Subtext "No Textless Poster found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    }
                    Else {
                        Write-Entry -Subtext "No Poster found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    }
                }
                return $global:posterurl
            }
            Else {
                Write-Entry -Subtext "No Poster found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/seasons/$($Seasonresponse.data.type.type)/$global:SeasonNumber#artwork"
            }
        }
        Else {
            Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/seasons/$($Seasonresponse.data.type.type)/$global:SeasonNumber#artwork"
        }
    }
    Else {
        Write-Entry -Subtext "Cannot search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
}
function GetTVDBShowBackground {
    if ($global:tvdbid) {
        Write-Entry -Subtext "Searching on TVDB for a background - TVDBID: $global:tvdbid" -Path $global:configLogging -Color Cyan -log Info
        if ($global:BackgroundPreferTextless -eq $true) {
            try {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/series/$($global:tvdbid)/artworks" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
            catch {
                Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
            if ($response) {
                if ($response.data -and $response.data.artworks) {
                    $artworksOfType3 = $response.data.artworks | Where-Object { $_.type -eq '3' }
                    if ($artworksOfType3) {
                        $defaultImageurltemp = $artworksOfType3
                        if ($defaultImageurltemp) {
                            $defaultImageurl = $defaultImageurltemp[0].image
                        }
                        if ($global:WidthHeightFilter -eq 'true') {
                            $NoLangImageUrl = $response.data.artworks | Where-Object { $_.language -eq $null -and $_.type -eq '3' -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight }
                        }
                        Else {
                            $NoLangImageUrl = $response.data.artworks | Where-Object { $_.language -eq $null -and $_.type -eq '3' }
                        }
                        if ($NoLangImageUrl) {
                            $global:posterurl = $NoLangImageUrl[0].image
                            if ($global:WidthHeightFilter -eq 'true') {
                                Write-Entry -Subtext "Found a poster sized at - width: $($NoLangImageUrl[0].width) | height: $($NoLangImageUrl[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            Write-Entry -Subtext "Found Textless background on TVDB" -Path $global:configLogging -Color Blue -log Info
                            $global:TextlessPoster = $true
                            $global:PosterWithText = $null
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
                        }
                        Else {
                            Write-Entry -Subtext "PreferTextless Value: $global:BackgroundPreferTextless" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "OnlyTextless Value: $global:BackgroundOnlyTextless" -Path $global:configLogging -Color Cyan -log Debug
                            if ($global:BackgroundOnlyTextless -eq $false) {
                                $global:posterurl = $defaultImageurl
                                Write-Entry -Subtext "Found background with text on TVDB" -Path $global:configLogging -Color Blue -log Info
                                $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
                            }
                            Else {
                                Write-Entry -Subtext "Found Poster with text on TVDB, skipping because you only want textless..." -Path $global:configLogging -Color Yellow -log Info
                                $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
                            }
                        }
                        return $global:posterurl
                    }
                    Else {
                        Write-Entry -Subtext "No background found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                        $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
                    }
                }
                Else {
                    Write-Entry -Subtext "No data returned from API at all" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
                }
            }
            Else {
                Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
            }
        }
        Else {
            try {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/series/$($global:tvdbid)/artworks" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
            }
            catch {
                Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
            if ($response) {
                if ($response.data) {
                    foreach ($lang in $global:PreferredBackgroundLanguageOrderTVDB) {
                        if ($global:WidthHeightFilter -eq 'true') {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '3' -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '3' -and $_.width -ge $global:BgTcMinWidth -and $_.height -ge $global:BgTcMinHeight } | Sort-Object Score -Descending)
                            }
                        }
                        Else {
                            if ($lang -eq 'null') {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "" -and $_.type -eq '3' } | Sort-Object Score -Descending)
                            }
                            Else {
                                $LangArtwork = ($response.data.artworks | Where-Object { $_.language -like "$lang*" -and $_.type -eq '3' } | Sort-Object Score -Descending)
                            }
                        }
                        if ($LangArtwork) {
                            $global:posterurl = $LangArtwork[0].image
                            if ($global:WidthHeightFilter -eq 'true') {
                                Write-Entry -Subtext "Found a poster sized at - width: $($LangArtwork[0].width) | height: $($LangArtwork[0].height)" -Path $global:configLogging -Color White -log Info
                            }
                            if ($lang -eq 'null') {
                                Write-Entry -Subtext "Found background without Language on TVDB" -Path $global:configLogging -Color Blue -log Info
                            }
                            Else {
                                Write-Entry -Subtext "Found background with Language '$lang' on TVDB" -Path $global:configLogging -Color Blue -log Info
                            }
                            if ($lang -ne 'null') {
                                $global:PosterWithText = $true
                                $global:TVDBAssetTextLang = $lang
                            }
                            $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"

                            return $global:posterurl
                            continue
                        }
                    }
                    if (!$global:posterurl) {
                        Write-Entry -Subtext "No background found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                        $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
                    }
                }
                Else {
                    Write-Entry -Subtext "No background found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
                }
            }
            Else {
                Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"
            }
        }
    }
    Else {
        Write-Entry -Subtext "Cannot search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
}
function GetTVDBTitleCard {
    if ($global:tvdbid) {
        Write-Entry -Subtext "Searching on TVDB for: $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card - TVDBID: $global:tvdbid" -Path $global:configLogging -Color Cyan -log Info
        $allEpisodes = [System.Collections.Generic.List[object]]::new()
        $page = 0

        do {
            try {
                $response = (Invoke-WebRequest -Uri "https://api4.thetvdb.com/v4/series/$($global:tvdbid)/episodes/default?page=$page" -Method GET -Headers $global:tvdbheader).content | ConvertFrom-Json
                $episodes = $response.data.episodes
                $seriesData = $response.data

                if ($episodes) {
                    $allEpisodes.Add($seriesData)
                    $page++
                }
            }
            catch {
                Write-Entry -Subtext "Could not query TVDB url, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                break
            }
        } while ($episodes -and $episodes.Count -gt 0)

        # Now $allEpisodes contains all the episodes retrieved from the API

        if ($response) {
            if ($allEpisodes.episodes) {
                $global:NoLangImageUrl = $allEpisodes.episodes | Where-Object { $_.seasonNumber -eq $global:season_number -and $_.number -eq $global:episodenumber }
                if ($global:NoLangImageUrl.image) {
                    $global:posterurl = $global:NoLangImageUrl.image
                    Write-Entry -Subtext "Found Title Card on TVDB" -Path $global:configLogging -Color Blue -log Info
                    $global:TextlessPoster = $true
                    $global:PosterWithText = $null
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($allEpisodes.series.slug)/episodes/$($global:NoLangImageUrl.id)"

                    return $global:NoLangImageUrl.image
                }
                Else {
                    Write-Entry -Subtext "No Title Card found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($allEpisodes.slug)/#artwork"

                }
            }
            Else {
                Write-Entry -Subtext "No Title Card found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($allEpisodes.slug)/#artwork"

            }
        }
        Else {
            Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($response.data.slug)/#artwork"

        }
    }
    Else {
        Write-Entry -Subtext "Cannot search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
    }
}
function GetIMDBPoster {
    $response = Invoke-WebRequest -Uri "https://www.imdb.com/title/$($global:imdbid)/mediaviewer" -Method GET
    $global:posterurl = $response.images.src[1]
    if (!$global:posterurl) {
        Write-Entry -Subtext "No show match or poster found on IMDB" -Path $global:configLogging -Color Yellow -log Warning
    }
    Else {
        Write-Entry -Subtext "Found Poster with text on IMDB" -Path $global:configLogging -Color Blue -log Info
        return $global:posterurl
    }
}
function GetPlexArtwork {
    param(
        [string]$Type,
        [string]$ArtUrl,
        [string]$TempImage
    )

    Write-Entry -Subtext "Checking Plex metadata for $Type..." -Path $global:configLogging -Color Cyan -log Info

    $ExifFound = $false

    try {
        $client = New-Object System.Net.Http.HttpClient
        # Request only the first 64KB for EXIF/Metadata
        $client.DefaultRequestHeaders.Range = New-Object System.Net.Http.Headers.RangeHeaderValue(0, 65536)

        # Add Plex Headers
        foreach ($key in $extraPlexHeaders.Keys) {
            $client.DefaultRequestHeaders.TryAddWithoutValidation($key, $extraPlexHeaders[$key])
        }

        $task = $client.GetByteArrayAsync($ArtUrl)
        $buffer = $task.GetAwaiter().GetResult()
        $client.Dispose()

        # Check for markers
        $content = [System.Text.Encoding]::UTF8.GetString($buffer)
        if ($content -match 'overlay|titlecard|created with ppm|created with posterizarr') {
            $ExifFound = $true
        }
    }
    catch {
        Write-Entry -Subtext "Fast-Scan failed for $Type. Error: $($_.Exception.Message)" -Path $global:configLogging -Color Yellow -log Warning
        try {
            Invoke-WebRequest -Uri $ArtUrl -OutFile $TempImage -Headers $extraPlexHeaders
            $magickcommand = "& `"$magick`" identify -verbose `"$TempImage`""
            if (Invoke-Expression $magickcommand | Select-String -Pattern 'overlay|titlecard|created with ppm|created with posterizarr') {
                $ExifFound = $true
            }
        }
        catch {
            Write-Entry -Subtext "Could not download Artwork from plex: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; return
        }
    }

    if ($ExifFound -and $DisableHashValidation -eq 'false') {
        if ($global:UploadExistingAssets -eq 'true') {
            Write-Entry -Subtext "Plex artwork already has EXIF (posterizarr/kometa/tcm), skipping..." -Path $global:configLogging -Color Yellow -log Warning
        }
        else {
            Write-Entry -Subtext "Plex artwork already processed, cannot use as source..." -Path $global:configLogging -Color Yellow -log Warning
        }
        if (Test-Path -LiteralPath $TempImage) {
            Remove-Item -LiteralPath $TempImage -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    else {
        # Only download the FULL image if needed
        Write-Entry -Subtext "No EXIF found or validation disabled, downloading full $Type..." -Path $global:configLogging -Color Green -log Info
        try {
            Invoke-WebRequest -Uri $ArtUrl -OutFile $TempImage -Headers $extraPlexHeaders
            $global:PlexartworkDownloaded = $true
            $global:posterurl = $ArtUrl
        }
        catch {
            Write-Entry -Subtext "Full download failed: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
        }
    }
}
function Push-ObjectToDiscord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$strDiscordWebhook,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$objPayload
    )

    try {
        $response = Invoke-RestMethod -Method Post -Uri $strDiscordWebhook -Body $objPayload -ContentType 'Application/Json' -ResponseHeadersVariable "resHeaders"

        Write-Entry -Subtext "Discord webhook sent successfully." -Path $global:configLogging -Color Green -log Info

        # Smart Rate Limiting: Discord returns 'x-ratelimit-reset-after' in seconds
        if ($resHeaders.'x-ratelimit-remaining' -eq 0) {
            $waitTime = $resHeaders.'x-ratelimit-reset-after'
            Write-Verbose "Rate limit reached. Sleeping for $waitTime seconds."
            Start-Sleep -Seconds [math]::Ceiling($waitTime)
        }
        else {
            # Default safety gap
            Start-Sleep -Milliseconds 500
        }
    }
    catch {
        $errorMessage = "Unable to send to Discord."
        $discordErrorBody = "N/A"
        $statusCode = "N/A"

        # Check if we have a response object
        if ($_.Exception.Response) {
            $response = $_.Exception.Response
            $statusCode = $response.StatusCode

            if ($statusCode -eq 'NotFound') {
                $errorMessage = "Unable to send to Discord. Status: $statusCode. Reason: Wrong Webhook Url"
            }
            else {
                # Handle PowerShell 7+ (HttpResponseMessage)
                if ($_.ErrorDetails) {
                    $discordErrorBody = $_.ErrorDetails.Message
                }
                elseif ($response.GetType().Name -eq 'HttpResponseMessage') {
                    try {
                        $task = $response.Content.ReadAsStringAsync()
                        $discordErrorBody = $task.Result
                    } catch {
                        $discordErrorBody = "Could not read disposed response"
                    }
                }
                # Handle Windows PowerShell 5.1 (HttpWebResponse)
                elseif ($response.GetResponseStream) {
                    $stream = $response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $discordErrorBody = $reader.ReadToEnd()
                    $reader.Close()
                }
                $errorMessage = "Unable to send to Discord. Status: $statusCode. Reason: $discordErrorBody"
            }
        }
        else {
            $errorMessage = "Network/DNS Error: $($_.Exception.Message)"
        }

        # Logging to Posterizarr globals
        Write-Entry -Message $errorMessage -Path $global:configLogging -Color Red -log Error
        Write-Entry -Message "Failing Payload: $objPayload" -Path $global:configLogging -Color Red -log Error
    }
}
function CheckJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$jsonExampleUrl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object]$jsonFilePath
    )
    try {
        $AttributeChanged = $null
        # Download the default configuration JSON file from the URL
        $defaultConfig = Invoke-RestMethod -Uri $jsonExampleUrl -Method Get -ErrorAction Stop

        # Read the existing configuration file if it exists
        if (Test-Path $jsonFilePath) {
            try {
                $config = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json
            }
            catch {
                Write-Entry -Message "Failed to read the existing configuration file: $jsonFilePath. Please ensure it is valid JSON. Aborting..." -Path $global:configLogging -Color Red -log Error
                # Clear Running File
                HandleScriptExit -Message "Failed to read the existing configuration file."
            }
        }
        else {
            $config = @{}
        }

        # Remove keys from config that are no longer in the default config
        foreach ($existingKey in $config.PSObject.Properties.Name) {
            if (-not $defaultConfig.PSObject.Properties.Name.Contains($existingKey)) {
                Write-Entry -Message "Removing obsolete Main Attribute from your Config file: $existingKey." -Path $global:configLogging -Color Yellow -log Warning
                $config.PSObject.Properties.Remove($existingKey)
                $AttributeChanged = $True
            }
        }

        # Remove sub-attributes no longer in the default config
        foreach ($partKey in $config.PSObject.Properties.Name) {
            if ($defaultConfig.PSObject.Properties.Name.Contains($partKey)) {
                # Check each sub-attribute in the part
                foreach ($existingSubKey in $config.$partKey.PSObject.Properties.Name) {
                    if (-not $defaultConfig.$partKey.PSObject.Properties.Name.Contains($existingSubKey)) {
                        Write-Entry -Message "Removing obsolete Sub-Attribute from your Config file: $partKey.$existingSubKey." -Path $global:configLogging -Color Yellow -log Warning
                        $config.$partKey.PSObject.Properties.Remove($existingSubKey)
                        $AttributeChanged = $True
                    }
                }
            }
        }

        # Check and add missing keys from the default configuration
        foreach ($partKey in $defaultConfig.PSObject.Properties.Name) {
            # Check if the part exists in the current configuration
            if (-not $config.PSObject.Properties.Name.Contains($partKey)) {
                if (-not $config.PSObject.Properties.Name.tolower().Contains($partKey.tolower())) {
                    # Add "SeasonPosterOverlayPart" if it's missing in $config
                    if (-not $config.PSObject.Properties.Name.tolower().Contains("seasonposteroverlaypart")) {
                        $config | Add-Member -MemberType NoteProperty -Name "SeasonPosterOverlayPart" -Value $defaultConfig.PosterOverlayPart
                        Write-Entry -Message "Missing Main Attribute in your Config file: $partKey." -Path $global:configLogging -Color Yellow -log Warning
                        Write-Entry -Subtext "I will copy all settings from 'PosterOverlayPart'..." -Path $global:configLogging -Color White -log Info
                        Write-Entry -Subtext "Adding it for you... In GH Readme, look for $partKey - if you want to see what changed..." -Path $global:configLogging -Color White -log Info
                        Write-Entry -Subtext "GH Readme -> https://fscorrupt.github.io/posterizarr/configuration" -Path $global:configLogging -Color White -log Info
                        # Convert the updated configuration object back to JSON and save it, then reload it
                        $configJson = $config | ConvertTo-Json -Depth 10
                        $configJson | Set-Content -Path $jsonFilePath -Force
                        $config = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json
                    }
                    Else {
                        Write-Entry -Message "Missing Main Attribute in your Config file: $partKey." -Path $global:configLogging -Color Yellow -log Warning
                        Write-Entry -Subtext "Adding it for you... In GH Readme, look for $partKey - if you want to see what changed..." -Path $global:configLogging -Color White -log Info
                        Write-Entry -Subtext "GH Readme -> https://fscorrupt.github.io/posterizarr/configuration" -Path $global:configLogging -Color White -log Info
                        $config | Add-Member -MemberType NoteProperty -Name $partKey -Value $defaultConfig.$partKey
                        $AttributeChanged = $True
                    }
                }
                else {
                    # Inform user about the case issue
                    Write-Entry -Message "The Main Attribute '$partKey' in your configuration file has a different casing than the expected property." -Path $global:configLogging -Color Red -log Error
                    Write-Entry -Subtext "Please correct the casing of the property in your configuration file to '$partKey'." -Path $global:configLogging -Color Yellow -log Info
                    # Clear Running File
                    HandleScriptExit -Message "Wrong Main Attribute casing in config file"
                }
            }
            else {
                # Check each key in the part
                foreach ($propertyKey in $defaultConfig.$partKey.PSObject.Properties.Name) {
                    # Show user that a sub-attribute is missing
                    if (-not $config.$partKey.PSObject.Properties.Name.Contains($propertyKey)) {
                        if (-not $config.$partKey.PSObject.Properties.Name.tolower().Contains($propertyKey.tolower())) {
                            Write-Entry -Message "Missing Sub-Attribute in your Config file: $partKey.$propertyKey" -Path $global:configLogging -Color Yellow -log Warning
                            Write-Entry -Subtext "Adding it for you... In GH Readme, look for $partKey.$propertyKey - if you want to see what changed..." -Path $global:configLogging -Color White -log Info
                            Write-Entry -Subtext "GH Readme -> https://fscorrupt.github.io/posterizarr/configuration" -Path $global:configLogging -Color White -log Info
                            # Add the property using the expected casing
                            $config.$partKey | Add-Member -MemberType NoteProperty -Name $propertyKey -Value $defaultConfig.$partKey.$propertyKey -Force
                            $AttributeChanged = $True
                        }
                        else {
                            # Inform user about the case issue
                            Write-Entry -Message "The Sub-Attribute '$partKey.$propertyKey' in your configuration file has a different casing than the expected property." -Path $global:configLogging -Color Red -log Error
                            Write-Entry -Subtext "Please correct the casing of the Sub-Attribute in your configuration file to '$partKey.$propertyKey'." -Path $global:configLogging -Color Yellow -log Info
                            # Clear Running File
                            HandleScriptExit -Message "Wrong Sub Attribute casing in config file"
                        }
                    }
                }
            }
        }

        if ($AttributeChanged -eq 'true') {
            # Convert the updated configuration object back to JSON and save it
            $configJson = $config | ConvertTo-Json -Depth 10
            $configJson | Set-Content -Path $jsonFilePath -Force

            Write-Entry -Subtext "Configuration file updated successfully." -Path $global:configLogging -Color Green -log Info
        }
    }
    catch [System.Net.WebException] {
        Write-Entry -Message "Failed to download the default configuration JSON file from the URL." -Path $global:configLogging -Color Red -log Error
        HandleScriptExit -Message "Config.json download failed."
    }
    catch {
        Write-Entry -Message "An unexpected error occurred: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
        # Clear Running File
        HandleScriptExit -Message "$($_.Exception.Message)"
    }
}
function CheckJsonPaths {
    param (
        [string]$font,
        [string]$RTLfont,
        [string]$backgroundfont,
        [string]$titlecardfont,
        [string]$Posteroverlay,
        [string]$ShowPosteroverlay,
        [string]$Collectionoverlay,
        [string]$titlecardoverlay,
        [string]$Seasonoverlay,
        [string]$Backgroundoverlay,
        [string]$ShowBackgroundoverlay,
        [string]$Posteroverlay4k,
        [string]$Posteroverlay1080p,
        [string]$Backgroundoverlay4k,
        [string]$Backgroundoverlay1080p,
        [string]$TCoverlay4k,
        [string]$TCoverlay1080p,
        [string]$Posteroverlay4KDoVi,
        [string]$Posteroverlay4KHDR10,
        [string]$Posteroverlay4KDoViHDR10,
        [string]$Backgroundoverlay4KDoVi,
        [string]$Backgroundoverlay4KHDR10,
        [string]$Backgroundoverlay4KDoViHDR10,
        [string]$TCoverlay4KDoVi,
        [string]$TCoverlay4KHDR10,
        [string]$TCoverlay4KDoViHDR10
    )

    $paths = @(
        $font, $RTLfont, $backgroundfont, $titlecardfont, $Posteroverlay, $ShowPosteroverlay,
        $Collectionoverlay, $Backgroundoverlay, $ShowBackgroundoverlay, $titlecardoverlay, $Seasonoverlay,
        $Posteroverlay4k, $Posteroverlay1080p, $Backgroundoverlay4k,
        $Backgroundoverlay1080p, $TCoverlay4k, $TCoverlay1080p, $Posteroverlay4KDoVi, $Posteroverlay4KHDR10, $Posteroverlay4KDoViHDR10,
        $Backgroundoverlay4KDoVi, $Backgroundoverlay4KHDR10, $Backgroundoverlay4KDoViHDR10,
        $TCoverlay4KDoVi, $TCoverlay4KHDR10, $TCoverlay4KDoViHDR10
    )

    foreach ($path in $paths) {
        # Only check the path if it's not null or empty.
        # This allows optional overlays (set to null in config) to pass.
        if ((-not [string]::IsNullOrEmpty($path)) -and (-not (Test-Path -LiteralPath $path.TrimEnd()))) {
            Write-Entry -Message "Could not find file in: $path" -Path $global:configLogging -Color Red -log Error
            Write-Entry -Subtext "Check config for typos and make sure that the file is present in scriptroot." -Path $global:configLogging -Color Yellow -log Warning
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
        }
    }

    if ($errorCount -ge 1) {
        # Clear Running File
        HandleScriptExit -Message "File missing"
    }
}
function Get-Platform {
    if ($global:OSType -eq 'Docker') {
        return 'Docker'
    }
    elseif ($global:OSType -eq 'Unix' -and $env:POWERSHELL_DISTRIBUTION_CHANNEL -notlike 'PSDocker*') {
        # Check if it is a Mac
        $unameOutput = & uname
        if ($unameOutput -like "*Darwin*") {
            return 'macOS'
        }
        Else {
            return 'Linux'
        }
    }
    elseif ($global:OSType -eq 'Win32NT') {
        return 'Windows'
    }
    else {
        return 'Unknown'
    }
}
function Get-LatestScriptVersion {
    try {
        return Invoke-RestMethod -Uri "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/Release.txt" -Method Get -ErrorAction Stop
    }
    catch {
        Write-Entry -Subtext "Could not query latest script version, Error: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
        return $null
    }
}
function RotateLogs {
    param (
        [string]$ScriptRoot
    )

    $logFolder = Join-Path $ScriptRoot "Logs"
    $global:RotationFolderName = "RotatedLogs"
    $rotationFolder = Join-Path $ScriptRoot $global:RotationFolderName

    if (Test-Path -Path $logFolder -PathType Container) {
        $filesToMove = Get-ChildItem -Path $logFolder

        if ($filesToMove.Count -gt 0) {
            if (!(Test-Path -Path $rotationFolder)) {
                New-Item -ItemType Directory -Path $rotationFolder -Force | Out-Null
            }

            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $destinationPath = Join-Path $rotationFolder "Logs_$timestamp"
            New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

            try {
                $filesToMove | Move-Item -Destination $destinationPath -ErrorAction Stop
            }
            catch {
                Write-Host "Log Rotation partial or failed: $($_.Exception.Message)"
            }
        }
    }
}
function Send-PosterizarrTelemetry {
    # Immediately return/exit if the config's telemetry toggle is set to false.
    if ($config.PrerequisitePart.telemetry -eq $false -or $config.PrerequisitePart.telemetry -eq 'false') {
        return
    }

    $cacheFile = Join-Path $global:ScriptRoot 'Cache\telemetry.cache.json'
    try {
        $cacheDir = Split-Path -Parent $cacheFile
        if ($cacheDir -and -not (Test-Path -LiteralPath $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    }
    catch {}
    $cache = $null
    if (Test-Path $cacheFile) {
        try {
            $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
        }
        catch {}
    }

    $instanceId = $null
    if ($cache -and $cache.InstanceId) {
        $instanceId = $cache.InstanceId
    }
    else {
        $instanceId = [guid]::NewGuid().ToString()
    }

    $cachedVersion = $null
    if ($cache -and $cache.AppVersion) {
        $cachedVersion = $cache.AppVersion
    }

    if ($cachedVersion -eq $CurrentScriptVersion) {
        return
    }

    $osName = $Platform

    if ($config.PlexPart.UsePlex -eq 'true' -or $config.PlexPart.UsePlex -eq $true) {
        $target = "Plex"
    } elseif ($config.JellyfinPart.UseJellyfin -eq 'true' -or $config.JellyfinPart.UseJellyfin -eq $true) {
        $target = "Jellyfin"
    } elseif ($config.EmbyPart.UseEmby -eq 'true' -or $config.EmbyPart.UseEmby -eq $true) {
        $target = "Emby"
    }

    $payload = @{
        InstanceId = $instanceId
        os         = $osName
        target     = $target
        appVersion = $CurrentScriptVersion
    }

    try {
        Invoke-RestMethod -Uri "https://telemetry.posterizarr-stats.workers.dev/" -Method Post -Body ($payload | ConvertTo-Json -Compress) -ContentType "application/json" -ErrorAction Stop | Out-Null

        $newCache = @{
            InstanceId = $instanceId
            AppVersion = $CurrentScriptVersion
        }
        $newCache | ConvertTo-Json -Compress | Set-Content $cacheFile -Force
    }
    catch {
        Write-Verbose "Telemetry failed silently: $($_.Exception.Message)"
    }
}
function CheckConfigFile {
    param (
        [string]$ScriptRoot
    )

    if (!(Test-Path (Join-Path $ScriptRoot 'config.json'))) {
        Write-Entry -Message "Config File missing, downloading it for you..." -Path $global:configLogging -Color White -log Info
        Invoke-WebRequest -Uri "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/config.example.json" -OutFile "$ScriptRoot\config.json"
        Write-Entry -Subtext "Config File downloaded here: '$ScriptRoot\config.json'" -Path $global:configLogging -Color White -log Info
        Write-Entry -Subtext "Please configure the config file according to GitHub, Exit script now..." -Path $global:configLogging -Color Yellow -log Warning
        # Clear Running File
        HandleScriptExit -Message "Configure config file"
    }
}
function Test-And-Download {
    param(
        [string]$url,
        [string]$destination
    )

    if (!(Test-Path $destination)) {
        Invoke-WebRequest -Uri $url -OutFile $destination
    }
}
function RedactMediaServerUrl {
    param(
        [string]$url
    )

    # Match Plex URLs containing X-Plex-Token
    $plexMatch = $url -match "(https?://)([^:/]+)(:\d+)?(/[^?]+)(\?X-Plex-Token=)([^&]+)(.*)"

    # Match Jellyfin/Emby URLs containing api_key
    $otherMatch = $url -match "(https?://)([^:/]+)(:\d+)?(/[^?]+)(\?api_key=)([^&]+)(.*)"

    if ($plexMatch -or $otherMatch) {
        $protocol = $Matches[1]
        $hostname = $Matches[2]
        $port = $Matches[3]
        $path = $Matches[4]
        $prefix = $Matches[5]   # Either "?X-Plex-Token=" or "?api_key="
        $token = $Matches[6]
        $suffix = $Matches[7]

        # Redact IP address or hostname
        $redactedHostname = $hostname -replace "(?<=.{3}).", "*"

        # Redact API Token
        $redactedToken = $($token[0..7] -join '') + "*******"

        # Construct the redacted URL
        $redactedUrl = $protocol + $redactedHostname + $port + $path + $prefix + $redactedToken + $suffix

        return $redactedUrl
    }
    else {
        return $url  # Return original if no match found
    }
}
function CheckPlexAccess {
    param (
        [string]$PlexUrl,
        [string]$PlexToken
    )

    if ($PlexToken) {
        Write-Entry -Message "Plex token found, checking access now..." -Path $global:configLogging -Color White -log Info
        try {
            $response = Invoke-WebRequest -Uri "$PlexUrl/library/sections/?X-Plex-Token=$PlexToken" -ErrorAction Stop -Headers $extraPlexHeaders
            if ($response.StatusCode -eq 200) {
                Write-Entry -Subtext "Plex access is working..." -Path $global:configLogging -Color Green -log Info
                # Check if libs are available
                [XML]$Libs = $response.Content
                # Plex Debug info
                $plexdebuginfo = Invoke-WebRequest -Uri "$PlexUrl/?X-Plex-Token=$PlexToken" -ErrorAction Stop -Headers $extraPlexHeaders
                [XML]$plexdebuginfo = $plexdebuginfo.Content
                Write-Entry -Subtext "Plex Server Version: $($plexdebuginfo.MediaContainer.version)" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Subtext "My Plex Server: $($plexdebuginfo.MediaContainer.myPlex)"-Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Subtext "Plex Server Signin State: $($plexdebuginfo.MediaContainer.myPlexSigninState)" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Subtext "Plex Server allow Deletion: $($plexdebuginfo.MediaContainer.allowMediaDeletion)" -Path $global:configLogging -Color Cyan -log Debug
                if ($Libs.MediaContainer.size -ge 1) {
                    return $Libs
                }
                else {
                    Write-Entry -Subtext "No libs on Plex, abort script now..." -Path $global:configLogging -Color Red -log Error
                    # Clear Running File
                    HandleScriptExit -Message "No Plex Libs found"
                }
            }
            else {
                Write-Entry -Message "Could not access Plex with this URL: $(RedactMediaServerUrl -url "$PlexUrl/library/sections/?X-Plex-Token=$PlexToken")" -Path $global:configLogging -Color Red -Log Error
                Write-Entry -Subtext "Please check token and access..." -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                # Clear Running File
                HandleScriptExit -Message "Could not access plex"
            }
        }
        catch {
            Write-Entry -Subtext "Could not access Plex with this URL: $(RedactMediaServerUrl -url "$PlexUrl/library/sections/?X-Plex-Token=$PlexToken")" -Path $global:configLogging -Color Red -Log Error
            Write-Entry -Subtext "Error occurred while accessing Plex server: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            # Clear Running File
            HandleScriptExit -Message "Could not access plex"
        }
    }
    else {
        Write-Entry -Message "Checking Plex access now..." -Path $global:configLogging -Color White -log Info
        try {
            $result = Invoke-WebRequest -Uri "$PlexUrl/library/sections" -ErrorAction SilentlyContinue -Headers $extraPlexHeaders
            if ($result.StatusCode -eq 200) {
                Write-Entry -Subtext "Plex access is working..." -Path $global:configLogging -Color Green -log Info
                # Check if libs are available
                [XML]$Libs = $result.Content
                # Plex Debug info
                $plexdebuginfo = Invoke-WebRequest -Uri "$PlexUrl" -ErrorAction Stop -Headers $extraPlexHeaders
                [XML]$plexdebuginfo = $plexdebuginfo.Content
                Write-Entry -Subtext "Plex Server Version: $($plexdebuginfo.MediaContainer.version)" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Subtext "My Plex Server: $($plexdebuginfo.MediaContainer.myPlex)"-Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Subtext "Plex Server Signin State: $($plexdebuginfo.MediaContainer.myPlexSigninState)" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Subtext "Plex Server allow Deletion: $($plexdebuginfo.MediaContainer.allowMediaDeletion)" -Path $global:configLogging -Color Cyan -log Debug
                if ($Libs.MediaContainer.size -ge 1) {
                    Write-Entry -Subtext "Found libs on Plex..." -Path $global:configLogging -Color White -log Info
                    return $Libs
                }
                else {
                    Write-Entry -Subtext "No libs on Plex, abort script now..." -Path $global:configLogging -Color Red -log Error
                    HandleScriptExit -Message "No libs on plex"
                }
            }
        }
        catch {
            Write-Entry -Subtext "Error occurred while accessing Plex server: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            Write-Entry -Subtext "Please check access and settings in Plex..." -Path $global:configLogging -Color Yellow -log Warning
            Write-Entry -Message "To be able to connect to Plex without authentication" -Path $global:configLogging -Color White -log Info
            Write-Entry -Message "You have to enter your IP range in 'Settings -> Network -> List of IP addresses and networks that are allowed without auth: '192.168.1.0/255.255.255.0''" -Path $global:configLogging -Color White -log Info
            # Clear Running File
            HandleScriptExit -Message "Could not access plex"
        }
    }
}
function CheckImageMagick {
    param (
        [string]$magick,
        [string]$magickinstalllocation
    )

    if (!(Test-Path $magick)) {
        if ($global:OSType -ne "Win32NT") {
            if ($global:OSType -ne "Docker") {
                Write-Entry -Message "ImageMagick missing, downloading the portable version for you..." -Path $global:configLogging -Color Yellow -log Warning
                $magickUrl = "https://imagemagick.org/archive/binaries/magick"
                Invoke-WebRequest -Uri $magickUrl -OutFile "$global:ScriptRoot/magick"
                chmod +x "$global:ScriptRoot/magick"
                Write-Entry -Subtext "Made the portable Magick executable..." -Path $global:configLogging -Color Green -log Info
            }
        }
        else {

            $result = Invoke-WebRequest "https://imagemagick.org/archive/binaries/?C=M;O=D"
            $LatestRelease = [regex]::Matches($result.Content, 'href="(ImageMagick-7[^"]+-portable-Q16-HDRI-x64\.7z)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 1

            Write-Entry -Message "ImageMagick missing, please manually install/copy portable Imagemagick from here: https://imagemagick.org/archive/binaries/$LatestRelease" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            Exit
        }
    }
}
function CheckOverlayDimensions {
    param (
        [string]$Posteroverlay,
        [string]$ShowPosteroverlay,
        [string]$Seasonoverlay,
        [string]$Backgroundoverlay,
        [string]$ShowBackgroundoverlay,
        [string]$Collectionoverlay,
        [string]$Titlecardoverlay,
        [string]$Posteroverlay4k,
        [string]$Posteroverlay1080p,
        [string]$Backgroundoverlay4k,
        [string]$Backgroundoverlay1080p,
        [string]$TCoverlay4k,
        [string]$TCoverlay1080p,
        [string]$PosterSize,
        [string]$BackgroundSize,
        [string]$Posteroverlay4KDoVi,
        [string]$Posteroverlay4KHDR10,
        [string]$Posteroverlay4KDoViHDR10,
        [string]$Backgroundoverlay4KDoVi,
        [string]$Backgroundoverlay4KHDR10,
        [string]$Backgroundoverlay4KDoViHDR10,
        [string]$TCoverlay4KDoVi,
        [string]$TCoverlay4KHDR10,
        [string]$TCoverlay4KDoViHDR10
    )
    # This function checks a single overlay's dimensions
    function Test-Dimension {
        param (
            [string]$OverlayPath,
            [string]$ExpectedSize,
            [string]$OverlayName
        )

        # If the path is $null or empty (i.e., optional overlay not configured),
        if ([string]::IsNullOrEmpty($OverlayPath)) {
            return
        }

        try {
            $actualDimensions = & $magick $OverlayPath -format "%wx%h" info:

            if ($actualDimensions -eq $ExpectedSize) {
                Write-Entry -Subtext "$OverlayName is correctly sized at: $ExpectedSize" -Path $global:configLogging -Color Cyan -log Info
            }
            else {
                Write-Entry -Subtext "$OverlayName is NOT correctly sized at: $ExpectedSize. Actual dimensions: $actualDimensions" -Path $global:configLogging -Color Yellow -log Warning
            }
        }
        catch {
            Write-Entry -Subtext "Failed to check dimensions for $OverlayName at path $OverlayPath. Error: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
        }
    }

    # Standard Poster Types (expect PosterSize)
    Test-Dimension -OverlayPath $Posteroverlay -ExpectedSize $PosterSize -OverlayName "Poster overlay"
    Test-Dimension -OverlayPath $ShowPosteroverlay -ExpectedSize $PosterSize -OverlayName "Show Poster overlay"
    Test-Dimension -OverlayPath $Seasonoverlay -ExpectedSize $PosterSize -OverlayName "Season overlay"
    Test-Dimension -OverlayPath $Collectionoverlay -ExpectedSize $PosterSize -OverlayName "Collection overlay"
    Test-Dimension -OverlayPath $Posteroverlay4k -ExpectedSize $PosterSize -OverlayName "4K Poster overlay"
    Test-Dimension -OverlayPath $Posteroverlay1080p -ExpectedSize $PosterSize -OverlayName "1080p Poster overlay"

    # Standard Background/TC Types (expect BackgroundSize)
    Test-Dimension -OverlayPath $Backgroundoverlay -ExpectedSize $BackgroundSize -OverlayName "Background overlay"
    Test-Dimension -OverlayPath $ShowBackgroundoverlay -ExpectedSize $BackgroundSize -OverlayName "Show Background overlay"
    Test-Dimension -OverlayPath $Titlecardoverlay -ExpectedSize $BackgroundSize -OverlayName "TitleCard overlay"
    Test-Dimension -OverlayPath $Backgroundoverlay4k -ExpectedSize $BackgroundSize -OverlayName "4K Background overlay"
    Test-Dimension -OverlayPath $Backgroundoverlay1080p -ExpectedSize $BackgroundSize -OverlayName "1080p Background overlay"
    Test-Dimension -OverlayPath $TCoverlay4k -ExpectedSize $BackgroundSize -OverlayName "4K TitleCard overlay"
    Test-Dimension -OverlayPath $TCoverlay1080p -ExpectedSize $BackgroundSize -OverlayName "1080p TitleCard overlay"

    # 4K Poster Types (expect PosterSize)
    Test-Dimension -OverlayPath $Posteroverlay4KDoVi -ExpectedSize $PosterSize -OverlayName "4K DoVi Poster overlay"
    Test-Dimension -OverlayPath $Posteroverlay4KHDR10 -ExpectedSize $PosterSize -OverlayName "4K HDR10 Poster overlay"
    Test-Dimension -OverlayPath $Posteroverlay4KDoViHDR10 -ExpectedSize $PosterSize -OverlayName "4K DoVi/HDR10 Poster overlay"

    # 4K Background Types (expect BackgroundSize)
    Test-Dimension -OverlayPath $Backgroundoverlay4KDoVi -ExpectedSize $BackgroundSize -OverlayName "4K DoVi Background overlay"
    Test-Dimension -OverlayPath $Backgroundoverlay4KHDR10 -ExpectedSize $BackgroundSize -OverlayName "4K HDR10 Background overlay"
    Test-Dimension -OverlayPath $Backgroundoverlay4KDoViHDR10 -ExpectedSize $BackgroundSize -OverlayName "4K DoVi/HDR10 Background overlay"

    # 4K TC Types (expect BackgroundSize)
    Test-Dimension -OverlayPath $TCoverlay4KDoVi -ExpectedSize $BackgroundSize -OverlayName "4K DoVi TitleCard overlay"
    Test-Dimension -OverlayPath $TCoverlay4KHDR10 -ExpectedSize $BackgroundSize -OverlayName "4K HDR10 TitleCard overlay"
    Test-Dimension -OverlayPath $TCoverlay4KDoViHDR10 -ExpectedSize $BackgroundSize -OverlayName "4K DoVi/HDR10 TitleCard overlay"
}
function InvokeMagickCommand {
    param (
        [string]$Command,
        [string]$Arguments
    )

    $global:ImageMagickError = $null
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Write-Entry -Subtext "Skipping: No arguments provided for magick command." -Path $global:configLogging -Color Cyan -log Debug
        return
    }
    function GetMagickErrorMessage {
        param (
            [string]$ErrorMessage
        )

        $global:ImageMagickError = $true
        $lines = $ErrorMessage -split "convert: |magick.exe: |magick: |@"

        if ($lines.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($lines[1])) {
            return $lines[1].Trim()
        }
        Else {
            # Fallback to returning the whole error
            return $ErrorMessage.Trim()
        }
    }

    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $Command
        $processInfo.Arguments = $Arguments
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo

        try {
            $process.Start() | Out-Null

            # Capture error
            $errorOutput = $process.StandardError.ReadToEnd()

            # Wait for the process to exit
            $process.WaitForExit()

            # Check if there was any error output
            if (-not [string]::IsNullOrWhiteSpace($errorOutput)) {
                Write-Entry -Subtext "An error occurred while executing the magick command:" -Path $global:configLogging -Color Red -log Error
                Write-Entry -Subtext (GetMagickErrorMessage $errorOutput) -Path $global:configLogging -Color Red -log Error
                Write-Entry -Subtext "$errorOutput" -Path $global:configLogging -Color Cyan -log Debug
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
        }
        catch {
            Write-Entry -Subtext "Failed to start the process or read the error output:" -Path $global:configLogging -Color Red -log Error
            Write-Entry -Subtext $_.Exception.Message -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

        }
        finally {
            if ($process) {
                $process.Dispose()
            }
        }
    }
    catch {
        Write-Entry -Subtext "An unexpected error occurred while setting up the process:" -Path $global:configLogging -Color Red -log Error
        Write-Entry -Subtext $_.Exception.Message -Path $global:configLogging -Color Red -log Error
        $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

    }
}
function CheckCharLimit {
    # Attempt to get the registry key
    try {
        $regKey = Get-Item -ErrorAction Stop -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

        # Get the value of LongPathsEnabled
        $longPathsEnabled = $regKey.GetValue("LongPathsEnabled")

        if ($longPathsEnabled -eq 1) {
            return $true
        }
        Else {
            return $false
        }
    }
    catch {
        # Handle any errors accessing the registry key
        Write-Entry -Subtext "$($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
        return $false
    }
}
function CheckJellyfinAccess {
    param (
        [string]$JellyfinUrl,
        [string]$JellyfinAPI
    )

    if ($JellyfinAPI) {
        Write-Entry -Message "Checking Jellyfin access now..." -Path $global:configLogging -Color White -log Info
        try {
            $response = Invoke-RestMethod -Method Get -Uri "$JellyfinUrl/System/Info?api_key=$JellyfinAPI" -ErrorAction Stop
            if ($response.version) {
                Write-Entry -Subtext "Jellyfin access is working..." -Path $global:configLogging -Color Green -log Info
            }
            else {
                Write-Entry -Message "Could not access Jellyfin" -Path $global:configLogging -Color Red -Log Error
                Write-Entry -Subtext "Please check token and url..." -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                # Clear Running File
                HandleScriptExit -Message "Cloud not access jellyfin"
            }
        }
        catch {
            Write-Entry -Subtext "Could not access Jellyfin" -Path $global:configLogging -Color Red -Log Error
            Write-Entry -Subtext "Error occurred while accessing Jellyfin server: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            # Clear Running File
            HandleScriptExit -Message "Cloud not access jellyfin"
        }
    }
}
function CheckEmbyAccess {
    param (
        [string]$EmbyUrl,
        [string]$EmbyAPI
    )

    if ($EmbyAPI) {
        Write-Entry -Message "Checking Emby access now..." -Path $global:configLogging -Color White -log Info
        try {
            $response = Invoke-RestMethod -Method Get -Uri "$EmbyUrl/System/Info?api_key=$EmbyAPI" -ErrorAction Stop
            if ($response.version) {
                Write-Entry -Subtext "Emby access is working..." -Path $global:configLogging -Color Green -log Info
            }
            else {
                Write-Entry -Message "Could not access Emby" -Path $global:configLogging -Color Red -Log Error
                Write-Entry -Subtext "Please check token and url..." -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                # Clear Running File
                HandleScriptExit -Message "Cloud not access emby"
            }
        }
        catch {
            Write-Entry -Subtext "Could not access Emby" -Path $global:configLogging -Color Red -Log Error
            Write-Entry -Subtext "Error occurred while accessing Emby server: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            # Clear Running File
            HandleScriptExit -Message "Cloud not access emby"
        }
    }
}
function UploadOtherMediaServerArtwork {
    param (
        [string]$itemId,
        [string]$imageType,
        [string]$imagePath,
        [switch]$SkipExifCheck # Added optional parameter
    )

    # Check if current image already has exif data
    $Imageinfo = Invoke-RestMethod -Method Get -Uri "$OtherMediaServerUrl/items/$itemId/images/?api_key=$OtherMediaServerApiKey"
    $Imageinfotemp = $Imageinfo | Where-Object imagetype -eq $imageType | Select-Object Height, Width, Path
    if ($Imageinfotemp) {
        $Imageinfotemp = $imageinfotemp[0]
    }
    # Clear value to ensure no old data causes a false skip
    $value = $null

    # Only run the EXIF check if the switch was NOT provided
    if (-not $SkipExifCheck) {
        # Set the API endpoint URL for magick exif check
        if (($imageinfotemp.Height) -and ($imageinfotemp.width)) {
            try {
                $ImageUrl = "$OtherMediaServerUrl/items/$itemId/images/$imageType/?api_key=$OtherMediaServerApiKey&width=$($imageinfotemp.width)&height=$($imageinfotemp.Height)"
                $tempFile = Join-Path -Path $global:ScriptRoot -ChildPath "temp\hashcompare.jpg"

                # Try to download the image
                $response = Invoke-WebRequest -Uri $ImageUrl -OutFile $tempFile -ErrorAction Stop

                $magickcommand = "& `"$magick`" identify -verbose `"$tempFile`""
                $magickcommand | Out-File $magickLog -Append
                $value = Invoke-Expression $magickcommand | Select-String -Pattern 'overlay|titlecard|created with ppm|created with posterizarr'

                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue | out-null
            }
            catch {
                # Log as a warning (not error) so we know why the check failed, but don't stop the script
                Write-Entry -Subtext "Exif check skipped (Image 404 or missing). Proceeding to upload. Error: $($_.Exception.Message)" -Path $global:configLogging -Color Yellow -log Warning

                # Ensure temp file cleanup happens if the download partially succeeded or failed
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue | out-null
                }
            }
        }
    }

    if ($value -and $DisableHashValidation -eq 'false') {
        $ExifFound = $True
        Write-Entry -Subtext "Artwork has exif data from posterizarr/kometa/tcm, skip upload..." -Path $global:configLogging -Color Yellow -log Warning
    }
    Else {
        if ($DisableHashValidation -eq 'false') {
            Write-Entry -Subtext "No posterizarr/kometa/tcm exif data found, starting upload..." -Path $global:configLogging -Color Green -log Info
        }
        # Read the image file as binary
        $imageData = [System.IO.File]::ReadAllBytes($imagePath)

        # Convert the image to a base64 string
        $imageBase64 = [Convert]::ToBase64String($imageData)

        # Determine the content type based on the file extension
        switch ([System.IO.Path]::GetExtension($imagePath).ToLower()) {
            ".jpg" { $contentType = "image/jpeg" }
            ".jpeg" { $contentType = "image/jpeg" }
            ".png" { $contentType = "image/png" }
            ".gif" { $contentType = "image/gif" }
            ".bmp" { $contentType = "image/bmp" }
            ".tiff" { $contentType = "image/tiff" }
            default {
                Write-Entry -Subtext "Unsupported image format." -Path $global:configLogging -Color Red -log Error
                # Clear Running File
                HandleScriptExit -Message "Unsupported image format"
            }
        }

        # Set the API endpoint URL
        $apiUrl = "$OtherMediaServerUrl/items/$itemId/images/$imageType/?api_key=$OtherMediaServerApiKey"

        if ($imageType -eq "Backdrop") {
            $deleteUrl = "$OtherMediaServerUrl/items/$itemId/images/$imageType/0?api_key=$OtherMediaServerApiKey"
            # Make the API request to delete the backdrop image
            try {
                # Delete the existing image first
                $response = Invoke-RestMethod -Uri $deleteUrl -Method Delete -ErrorAction Stop
                Write-Entry -Subtext "Image successfully deleted..." -Path $global:configLogging -Color Green -log Info
                $UploadCount++
            }
            catch {
                if ($_.Exception.Response -is [System.Net.Http.HttpResponseMessage] -and $_.Exception.Response.Content) {
                    try {
                        $response = $_.Exception.Response.Content.ReadAsStringAsync().Result
                    }
                    catch {
                        $response = "Unable to read server response (content may be disposed)."
                    }
                    Write-Entry -Subtext "Failed to delete image. Server response: $response" -Path $global:configLogging -Color Red -log Error
                }
                else {
                    Write-Entry -Subtext "Failed to delete image. Error: $_" -Path $global:configLogging -Color Red -log Error
                }
            }
            if ($global:ReplaceThumbwithBackdrop -eq 'true') {
                # Make the API request to upload the Thumb image
                $thumbapiUrl = "$OtherMediaServerUrl/items/$itemId/images/Thumb/?api_key=$OtherMediaServerApiKey"
                try {
                    $response = Invoke-RestMethod -Uri $thumbapiUrl -Method Post -Body $imageBase64 -ContentType $contentType -ErrorAction Stop

                    Write-Entry -Subtext "Thumb Image successfully uploaded..." -Path $global:configLogging -Color Green -log Info
                    $UploadCount++
                }
                catch {
                    if ($_.Exception.Response -is [System.Net.Http.HttpResponseMessage] -and $_.Exception.Response.Content) {
                        try {
                            $response = $_.Exception.Response.Content.ReadAsStringAsync().Result
                        }
                        catch {
                            $response = "Unable to read server response (content may be disposed)."
                        }
                        Write-Entry -Subtext "Failed to upload Thumb image. Server response: $response" -Path $global:configLogging -Color Red -log Error
                    }
                    else {
                        Write-Entry -Subtext "Failed to upload Thumb image. Error: $_" -Path $global:configLogging -Color Red -log Error
                    }
                }
            }
        }
        # Make the API request to upload the image
        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $imageBase64 -ContentType $contentType -ErrorAction Stop

            Write-Entry -Subtext "Image successfully uploaded..." -Path $global:configLogging -Color Green -log Info
            $UploadCount++
        }
        catch {
            if ($_.Exception.Response -is [System.Net.Http.HttpResponseMessage] -and $_.Exception.Response.Content) {
                try {
                    $response = $_.Exception.Response.Content.ReadAsStringAsync().Result
                }
                catch {
                    $response = "Unable to read server response (content may be disposed)."
                }
                Write-Entry -Subtext "Failed to upload image. Server response: $response" -Path $global:configLogging -Color Red -log Error
            }
            else {
                Write-Entry -Subtext "Failed to upload image. Error: $_" -Path $global:configLogging -Color Red -log Error
            }
        }
    }
}
function MassDownloadPlexArtwork {
    function GetPlexArtworkUrl {
        param(
            [string]$ArtUrl,
            [string]$TempImage
        )

        Write-Entry -Subtext "Fast-scanning Plex URL for EXIF data..." -Path $global:configLogging -Color Cyan -log Info

        $ExifFound = $false

        try {
            # Perform a partial download (64KB) to check for EXIF markers in memory
            $client = New-Object System.Net.Http.HttpClient
            $client.DefaultRequestHeaders.Range = New-Object System.Net.Http.Headers.RangeHeaderValue(0, 65536)

            # Add Plex Headers
            foreach ($key in $extraPlexHeaders.Keys) {
                $client.DefaultRequestHeaders.TryAddWithoutValidation($key, $extraPlexHeaders[$key])
            }

            $task = $client.GetByteArrayAsync($ArtUrl)
            $buffer = $task.GetAwaiter().GetResult()
            $client.Dispose()

            $content = [System.Text.Encoding]::UTF8.GetString($buffer)

            if ($content -match 'overlay|titlecard|created with ppm|created with posterizarr') {
                $ExifFound = $true
            }
        }
        catch {
            Write-Entry -Subtext "Fast-scan failed, falling back to full download. Error: $($_.Exception.Message)" -Path $global:configLogging -Color Yellow -log Warning

            try {
                Invoke-WebRequest -Uri $ArtUrl -OutFile $TempImage -Headers $extraPlexHeaders
                $magickcommand = "& `"$magick`" identify -verbose `"$TempImage`""
                if (Invoke-Expression $magickcommand | Select-String -Pattern 'overlay|titlecard|created with ppm|created with posterizarr') {
                    $ExifFound = $true
                }
            }
            catch {
                Write-Entry -Subtext "Could not download Artwork from plex: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; return
            }
        }

        if ($ExifFound) {
            Write-Entry -Subtext "Artwork has exif data from posterizarr/kometa/tcm, using URL..." -Path $global:configLogging -Color Green -log Info
            $global:posterurl = $ArtUrl
        }
        else {
            Write-Entry -Subtext "No posterizarr/kometa/tcm exif data found, using URL..." -Path $global:configLogging -Color Yellow -log Warning
            $global:posterurl = $ArtUrl
        }
    }
    $Mode = "backup"
    Write-Entry -Message "Backup Mode Started..." -Path $global:configLogging -Color White -log Info
    Write-Entry -Message "Query plex libs..." -Path $global:configLogging -Color White -log Info
    $Libsoverview = [System.Collections.Generic.List[object]]::new()
    foreach ($lib in $Libs.MediaContainer.Directory) {
        if ($lib.title -notin $LibstoExclude) {
            $libtemp = New-Object psobject
            $libtemp | Add-Member -MemberType NoteProperty -Name "ID" -Value $lib.key
            $libtemp | Add-Member -MemberType NoteProperty -Name "Name" -Value $lib.title
            $libtemp | Add-Member -MemberType NoteProperty -Name "Language" -Value $lib.language

            # Check if $lib.location.path is an array
            if ($lib.location.path -is [array]) {
                $paths = $lib.location.path -join ',' # Convert array to string
                $libtemp | Add-Member -MemberType NoteProperty -Name "Path" -Value $paths
            }
            else {
                $libtemp | Add-Member -MemberType NoteProperty -Name "Path" -Value $lib.location.path
            }
            # Check if Libname has chars we cant use for Folders
            if ($lib.title -notmatch "^[^\/:*?`"<>\|\\}]+$") {
                Write-Entry -Message  "Lib: '$($lib.title)' contains invalid characters." -Path $global:configLogging -Color Red -log Error
                Write-Entry -Subtext "Please rename your lib and remove all chars that are listed here: '/, :, *, ?, `", <, >, |, \, or }'" -Path $global:configLogging -Color Yellow -log Warning
                HandleScriptExit -Message "Invalid lib chars"
            }
            $Libsoverview.Add($libtemp)
        }
    }
    if ($($Libsoverview.count) -lt 1) {
        Write-Entry -Subtext "0 libraries were found. Are you on the correct Plex server?" -Path $global:configLogging -Color Red -log Error
        HandleScriptExit -Message "No libs found"
    }
    Write-Entry -Subtext "Found '$($Libsoverview.count)' libs and '$($LibstoExclude.count)' are excluded..." -Path $global:configLogging -Color Cyan -log Info
    $IncludedLibraryNames = $Libsoverview.Name -join ', '
    Write-Entry -Subtext "Included Libraries: $IncludedLibraryNames" -Path $global:configLogging -Color Cyan -log Info
    Write-Entry -Message "Query all items from all Libs, this can take a while..." -Path $global:configLogging -Color White -log Info
    $Libraries = [System.Collections.Generic.List[object]]::new()
    Foreach ($Library in $Libsoverview) {
        if ($Library.Name -notin $LibstoExclude) {
            $PlexHeaders = @{}
            if ($PlexToken) {
                $PlexHeaders['X-Plex-Token'] = $PlexToken
            }

            # Create a parent XML document
            $Libcontent = New-Object -TypeName System.Xml.XmlDocument
            $mediaContainerNode = $Libcontent.CreateElement('MediaContainer')
            $Libcontent.AppendChild($mediaContainerNode) | Out-Null

            # Initialize variables for pagination
            $searchsize = 0
            $totalContentSize = 1

            # Loop until all content is retrieved
            do {
                # Set headers for the current request
                $PlexHeaders['X-Plex-Container-Start'] = $searchsize
                $PlexHeaders['X-Plex-Container-Size'] = '1000'

                # Fetch content from Plex server
                $response = Invoke-WebRequest -Uri "$PlexUrl/library/sections/$($Library.ID)/all" -Headers $PlexHeaders

                # Convert response content to XML
                [xml]$additionalContent = $response.Content

                # Get total content size if not retrieved yet
                if ($totalContentSize -eq 1) {
                    $totalContentSize = $additionalContent.MediaContainer.totalSize
                }

                # Import and append video nodes to the parent XML document
                $contentquery = if ($additionalContent.MediaContainer.video) {
                    'video'
                }
                else {
                    'Directory'
                }
                foreach ($videoNode in $additionalContent.MediaContainer.$contentquery) {
                    $importedNode = $Libcontent.ImportNode($videoNode, $true)
                    [void]$mediaContainerNode.AppendChild($importedNode)
                }

                # Update search size for next request
                $searchsize += [int]$additionalContent.MediaContainer.Size
            } until ($searchsize -ge $totalContentSize)
            if ($Libcontent.MediaContainer.video) {
                $contentquery = 'video'
            }
            Else {
                $contentquery = 'Directory'
            }
            foreach ($item in $Libcontent.MediaContainer.$contentquery) {
                $extractedFolder = $null
                $Seasondata = $null
                if ($PlexToken) {
                    if ($contentquery -eq 'Directory') {
                        try {
                            [xml]$Metadata = (Invoke-WebRequest $PlexUrl/library/metadata/$($item.ratingKey)?X-Plex-Token=$PlexToken -Headers $extraPlexHeaders).content
                            [xml]$Seasondata = (Invoke-WebRequest $PlexUrl/library/metadata/$($item.ratingKey)/children?X-Plex-Token=$PlexToken -Headers $extraPlexHeaders).content
                        }
                        catch {
                            Write-Entry -Subtext "Current Seasondata Plex Query: $($PlexUrl[0..10] -join '')****/library/metadata/$($item.ratingKey)/children?X-Plex-Token=$($PlexToken[0..7] -join '')****" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "Current Metadata Plex Query: $($PlexUrl[0..10] -join '')****/library/metadata/$($item.ratingKey)?X-Plex-Token=$($PlexToken[0..7] -join '')****" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "An error occurred during Plex query: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                            $isConnRefused = $_.Exception.Message -match "(Connection refused|Name or service not known)"
                            if ($isConnRefused) {
                                $ConnRefusedCount++
                            }
                            if ($isConnRefused -and $ConnRefusedCount -ge 3) {
                                HandleScriptExit -Message "[FATAL] Connection refused 3 times. Terminating script."
                            }
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                        }
                    }
                    Else {
                        try {
                            [xml]$Metadata = (Invoke-WebRequest $PlexUrl/library/metadata/$($item.ratingKey)?X-Plex-Token=$PlexToken -Headers $extraPlexHeaders).content
                        }
                        catch {
                            Write-Entry -Subtext "Current Metadata Plex Query: $($PlexUrl[0..10] -join '')****/library/metadata/$($item.ratingKey)?X-Plex-Token=$($PlexToken[0..7] -join '')****" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "An error occurred during Plex query: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                            $isConnRefused = $_.Exception.Message -match "(Connection refused|Name or service not known)"
                            if ($isConnRefused) {
                                $ConnRefusedCount++
                            }
                            if ($isConnRefused -and $ConnRefusedCount -ge 3) {
                                HandleScriptExit -Message "[FATAL] Connection refused 3 times. Terminating script."
                            }
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                        }
                    }
                }
                Else {
                    if ($contentquery -eq 'Directory') {
                        try {
                            [xml]$Metadata = (Invoke-WebRequest $PlexUrl/library/metadata/$($item.ratingKey) -Headers $extraPlexHeaders).content
                            [xml]$Seasondata = (Invoke-WebRequest $PlexUrl/library/metadata/$($item.ratingKey)/children? -Headers $extraPlexHeaders).content
                        }
                        catch {
                            Write-Entry -Subtext "Current Seasondata Plex Query: $($PlexUrl[0..10] -join '')****/library/metadata/$($item.ratingKey)/children?" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "Current Metadata Plex Query: $($PlexUrl[0..10] -join '')****/library/metadata/$($item.ratingKey)" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "An error occurred during Plex query: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                            $isConnRefused = $_.Exception.Message -match "(Connection refused|Name or service not known)"
                            if ($isConnRefused) {
                                $ConnRefusedCount++
                            }
                            if ($isConnRefused -and $ConnRefusedCount -ge 3) {
                                HandleScriptExit -Message "[FATAL] Connection refused 3 times. Terminating script."
                            }
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                        }
                    }
                    Else {
                        try {
                            [xml]$Metadata = (Invoke-WebRequest $PlexUrl/library/metadata/$($item.ratingKey) -Headers $extraPlexHeaders).content
                        }
                        catch {
                            Write-Entry -Subtext "Current Metadata Plex Query: $($PlexUrl[0..10] -join '')****/library/metadata/$($item.ratingKey)" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "An error occurred during Plex query: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                            $isConnRefused = $_.Exception.Message -match "(Connection refused|Name or service not known)"
                            if ($isConnRefused) {
                                $ConnRefusedCount++
                            }
                            if ($isConnRefused -and $ConnRefusedCount -ge 3) {
                                HandleScriptExit -Message "[FATAL] Connection refused 3 times. Terminating script."
                            }
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                        }
                    }
                }
                $metadatatemp = $Metadata.MediaContainer.$contentquery.guid.id
                $tmdbpattern = 'tmdb://(\d+)'
                $imdbpattern = 'imdb://tt(\d+)'
                $tvdbpattern = 'tvdb://(\d+)'
                if ($Metadata.MediaContainer.$contentquery.Location) {
                    $location = $Metadata.MediaContainer.$contentquery.Location.path
                    if ($location) {
                        $location = $location.replace('\\?\', '')
                    }
                    if ($location.count -gt '1') {
                        $location = $location[0]
                        $MultipleVersions = $true
                    }
                    Else {
                        $MultipleVersions = $false
                    }
                    $libpaths = $($Library.path).split(',')
                    Write-Entry -Subtext "Plex Lib Paths before split: $($Library.path)" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Subtext "Plex Lib Paths after split: $libpaths" -Path $global:configLogging -Color Cyan -log Debug
                    foreach ($libpath in $libpaths) {
                        if ($location -like "$libpath/*" -or $location -like "$libpath\*") {
                            Write-Entry -Subtext "Location: $location" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "Libpath: $libpath" -Path $global:configLogging -Color Cyan -log Debug
                            $Matchedpath = AddTrailingSlash $libpath
                            $libpath = $Matchedpath
                            $relativePath = $location.Substring($libpath.Length)
                            $pathSegments = $relativePath -split '[\\/]'

                            # Determine the extracted folder and the root folder path
                            if ($pathSegments.Count -gt 2) {
                                $extractedFolder = $pathSegments[-2]  # Second-to-last segment is the folder containing the file
                                $extraFolder = $pathSegments[0]  # All segments up to the extracted folder
                            }
                            else {
                                $extractedFolder = $pathSegments[0]  # Only one segment, it's the folder
                                $extraFolder = $null  # No parent structure
                            }
                            Write-Entry -Subtext "Matchedpath: $Matchedpath" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "ExtractedFolder: $extractedFolder" -Path $global:configLogging -Color Cyan -log Debug
                            continue
                        }
                    }
                }
                Else {
                    $location = $Metadata.MediaContainer.$contentquery.media.part.file
                    if ($location) {
                        $location = $location.replace('\\?\', '')
                    }
                    if ($location.count -gt '1') {
                        Write-Entry -Subtext "Multi File Locations: $location" -Path $global:configLogging -Color Cyan -log Debug
                        $location = $location[0]
                        $MultipleVersions = $true
                    }
                    Else {
                        $MultipleVersions = $false
                    }
                    Write-Entry -Subtext "File Location: $location" -Path $global:configLogging -Color Cyan -log Debug

                    if ($location.length -ge '256' -and $Platform -eq 'Windows') {
                        $CheckCharLimit = CheckCharLimit
                        if ($CheckCharLimit -eq $false) {
                            Write-Entry -Subtext "Skipping [$($item.title)] because path length is over '256'..." -Path $global:configLogging -Color Yellow -log Warning
                            Write-Entry -Subtext "You can adjust it by following this: https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=registry#enable-long-paths-in-windows-10-version-1607-and-later" -Path $global:configLogging -Color Yellow -log Warning
                            continue
                        }
                    }

                    $libpaths = $($Library.path).split(',')
                    Write-Entry -Subtext "Plex Lib Paths before split: $($Library.path)" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Subtext "Plex Lib Paths after split: $libpaths" -Path $global:configLogging -Color Cyan -log Debug
                    foreach ($libpath in $libpaths) {
                        if ($location -like "$libpath/*" -or $location -like "$libpath\*") {
                            Write-Entry -Subtext "Location: $location" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "Libpath: $libpath" -Path $global:configLogging -Color Cyan -log Debug
                            $Matchedpath = AddTrailingSlash $libpath
                            $libpath = $Matchedpath
                            $relativePath = $location.Substring($libpath.Length)
                            $pathSegments = $relativePath -split '[\\/]'

                            # Determine the extracted folder and the root folder path
                            if ($pathSegments.Count -gt 2) {
                                $extractedFolder = $pathSegments[-2]  # Second-to-last segment is the folder containing the file
                                $extraFolder = $pathSegments[0]  # All segments up to the extracted folder
                            }
                            else {
                                $extractedFolder = $pathSegments[0]  # Only one segment, it's the folder
                                $extraFolder = $null  # No parent structure
                            }
                            Write-Entry -Subtext "Matchedpath: $Matchedpath" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Subtext "ExtractedFolder: $extractedFolder" -Path $global:configLogging -Color Cyan -log Debug
                            continue
                        }
                    }
                }
                if ($Seasondata) {
                    $SeasonsTemp = $Seasondata.MediaContainer.Directory | Where-Object { $_.Title -ne 'All episodes' }
                    $SeasonNames = $SeasonsTemp.Title -join ';'
                    $SeasonNumbers = $SeasonsTemp.index -join ','
                    $SeasonRatingkeys = $SeasonsTemp.ratingKey -join ','
                    $SeasonPosterUrl = ($SeasonsTemp | Where-Object { $_.type -eq "season" }).thumb -join ','
                }
                $matchesimdb = [regex]::Matches($metadatatemp, $imdbpattern)
                $matchestmdb = [regex]::Matches($metadatatemp, $tmdbpattern)
                $matchestvdb = [regex]::Matches($metadatatemp, $tvdbpattern)
                if ($matchesimdb.value) { $imdbid = $matchesimdb.value.Replace('imdb://', '') }Else { $imdbid = $null }
                if ($matchestmdb.value) { $tmdbid = $matchestmdb.value.Replace('tmdb://', '') }Else { $tmdbid = $null }
                if ($matchestvdb.value) { $tvdbid = $matchestvdb.value.Replace('tvdb://', '') }Else { $tvdbid = $null }
                # check if there are more then 1 entry in ids
                if ($tvdbid.count -gt '1') { $tvdbid = $tvdbid[0] }
                if ($tmdbid.count -gt '1') { $tmdbid = $tmdbid[0] }
                if ($imdbid.count -gt '1') { $imdbid = $imdbid[0] }

                if ($Metadata.MediaContainer.$contentquery.Label.tag) {
                    $Labels = $($Metadata.MediaContainer.$contentquery.Label.tag -join ',')
                }
                Else {
                    $Labels = ""
                }
                $FileMetadata = $Metadata.MediaContainer.$contentquery.media.part.stream
                $Resolution = $null
                # Get Resolution
                if ($FileMetadata) {
                    $FileMetadata | ForEach-Object {
                        if ($_.streamType -eq '1') {
                            $Resolution = $_.displayTitle
                        }
                    }
                }
                $temp = New-Object psobject
                $temp | Add-Member -MemberType NoteProperty -Name "Library Name" -Value $Library.Name
                $temp | Add-Member -MemberType NoteProperty -Name "Library Type" -Value $Metadata.MediaContainer.$contentquery.type
                $temp | Add-Member -MemberType NoteProperty -Name "Library Language" -Value $($Library.language.split("-")[0])
                $temp | Add-Member -MemberType NoteProperty -Name "title" -Value $($item.title)
                if ($FileMetadata) {
                    $temp | Add-Member -MemberType NoteProperty -Name "Resolution" -Value $Resolution
                }
                $temp | Add-Member -MemberType NoteProperty -Name "originalTitle" -Value $($item.originalTitle)
                $temp | Add-Member -MemberType NoteProperty -Name "SeasonNames" -Value $SeasonNames
                $temp | Add-Member -MemberType NoteProperty -Name "SeasonNumbers" -Value $SeasonNumbers
                $temp | Add-Member -MemberType NoteProperty -Name "SeasonRatingKeys" -Value $SeasonRatingkeys
                $temp | Add-Member -MemberType NoteProperty -Name "year" -Value $item.year
                $temp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $tvdbid
                $temp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $imdbid
                $temp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $tmdbid
                $temp | Add-Member -MemberType NoteProperty -Name "ratingKey" -Value $item.ratingKey
                $temp | Add-Member -MemberType NoteProperty -Name "Path" -Value $Matchedpath
                $temp | Add-Member -MemberType NoteProperty -Name "RootFoldername" -Value $extractedFolder
                $temp | Add-Member -MemberType NoteProperty -Name "extraFolder" -Value $extraFolder
                $temp | Add-Member -MemberType NoteProperty -Name "MultipleVersions" -Value $MultipleVersions
                $temp | Add-Member -MemberType NoteProperty -Name "PlexPosterUrl" -Value $Metadata.MediaContainer.$contentquery.thumb
                $temp | Add-Member -MemberType NoteProperty -Name "PlexBackgroundUrl" -Value $Metadata.MediaContainer.$contentquery.art
                $temp | Add-Member -MemberType NoteProperty -Name "PlexSeasonUrls" -Value $SeasonPosterUrl
                $temp | Add-Member -MemberType NoteProperty -Name "Labels" -Value $Labels
                $Libraries.Add($temp)
                Write-Entry -Subtext "Found [$($temp.title)] of type $($temp.{Library Type}) in [$($temp.{Library Name})]" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging -Color Cyan -log Debug
            }
        }
    }
    Write-Entry -Subtext "Found '$($Libraries.count)' Items..." -Path $global:configLogging -Color Cyan -log Info
    $Libraries | Select-Object * | Export-Csv -Path "$global:ScriptRoot\Logs\PlexLibexport.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force
    Write-Entry -Message "Export everything to a csv: $global:ScriptRoot\Logs\PlexLibexport.csv" -Path $global:configLogging -Color White -log Info

    # Initialize counter variable
    $posterCount = 0
    $SeasonCount = 0
    $EpisodeCount = 0
    $BackgroundCount = 0
    $PosterUnknownCount = 0
    $SkipTBACount = 0
    $SkipJapTitleCount = 0
    $AllShows = $Libraries | Where-Object { $_.'Library Type' -eq 'show' }
    $AllMovies = $Libraries | Where-Object { $_.'Library Type' -eq 'movie' }

    # Getting information of all Episodes
    if ($global:TitleCards -eq 'true') {
        Write-Entry -Message "Query episodes data from all Libs, this can take a while..." -Path $global:configLogging -Color White -log Info
        # Query episode info
        $Episodedata = [System.Collections.Generic.List[object]]::new()
        foreach ($showentry in $AllShows) {
            # Getting child entries for each season
            $splittedkeys = $showentry.SeasonRatingKeys.split(',')
            foreach ($key in $splittedkeys) {
                if ($PlexToken) {
                    [xml]$Seasondata = (Invoke-WebRequest $PlexUrl/library/metadata/$key/children?X-Plex-Token=$PlexToken -Headers $extraPlexHeaders).content
                }
                Else {
                    [xml]$Seasondata = (Invoke-WebRequest $PlexUrl/library/metadata/$key/children? -Headers $extraPlexHeaders).content
                }
                $FileMetadata = $Seasondata.MediaContainer.video.media
                $Resolution = $null
                # Get Resolution
                if ($FileMetadata) {
                    $ResolutionList = [System.Collections.Generic.List[object]]::new()
                    $FileMetadata | ForEach-Object {
                        $Resolution = $_.videoResolution
                        $ResolutionList.Add($Resolution)
                    }
                    $Resolution = $ResolutionList -join ","
                }
                $tempseasondata = New-Object psobject
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "Show Name" -Value $Seasondata.MediaContainer.grandparentTitle
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "Type" -Value $Seasondata.MediaContainer.viewGroup
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $showentry.tvdbid
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $showentry.tmdbid
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "Library Name" -Value $showentry.'Library Name'
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "Season Number" -Value $Seasondata.MediaContainer.parentIndex
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "Episodes" -Value $($Seasondata.MediaContainer.video.index -join ',')
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "Title" -Value $($Seasondata.MediaContainer.video.title -join ';')
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "RatingKeys" -Value $($Seasondata.MediaContainer.video.ratingKey -join ',')
                $tempseasondata | Add-Member -MemberType NoteProperty -Name "PlexTitleCardUrls" -Value $($Seasondata.MediaContainer.video.thumb -join ',')
                if ($FileMetadata) {
                    $tempseasondata | Add-Member -MemberType NoteProperty -Name "Resolutions" -Value $Resolution
                }
                $Episodedata.Add($tempseasondata)
                Write-Entry -Subtext "Found [$($tempseasondata.'Show Name')] of type $($tempseasondata.Type) for season $($tempseasondata.'Season Number')" -Path $global:configLogging -Color Cyan -log Debug
            }
        }
        $Episodedata | Select-Object * | Export-Csv -Path "$global:ScriptRoot\Logs\PlexEpisodeExport.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force
        if ($Episodedata) {
            Write-Entry -Subtext "Found '$($Episodedata.Episodes.split(',').count)' Episodes..." -Path $global:configLogging -Color Cyan -log Info
        }
    }

    # Test if csvÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´s are missing and create dummy file.
    if (!(Get-ChildItem -LiteralPath "$global:ScriptRoot\Logs\PlexEpisodeExport.csv" -ErrorAction SilentlyContinue)) {
        $EpisodeDummycsv = New-Object psobject

        # Add members to the object with empty values
        $EpisodeDummycsv | Add-Member -MemberType NoteProperty -Name "Show Name" -Value $null
        $EpisodeDummycsv | Add-Member -MemberType NoteProperty -Name "Type" -Value $null
        $EpisodeDummycsv | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $null
        $EpisodeDummycsv | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $null
        $EpisodeDummycsv | Add-Member -MemberType NoteProperty -Name "Library Name" -Value $null
        $EpisodeDummycsv | Add-Member -MemberType NoteProperty -Name "Season Number" -Value $null
        $EpisodeDummycsv | Add-Member -MemberType NoteProperty -Name "Episodes" -Value $null
        $EpisodeDummycsv | Add-Member -MemberType NoteProperty -Name "Title" -Value $null
        $EpisodeDummycsv | Add-Member -MemberType NoteProperty -Name "PlexTitleCardUrls" -Value $null

        $EpisodeDummycsv | Select-Object * | Export-Csv -Path "$global:ScriptRoot\Logs\PlexEpisodeExport.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force
        Write-Entry -Message "No PlexEpisodeExport.csv found, creating dummy file for you..." -Path $global:configLogging -Color White -log Info
    }
    if (!(Get-ChildItem -LiteralPath "$global:ScriptRoot\Logs\PlexLibexport.csv" -ErrorAction SilentlyContinue)) {
        # Add members to the object with empty values
        $PlexLibDummycsv = New-Object psobject
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "Library Name" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "Library Type" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "Library Language" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "title" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "originalTitle" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "SeasonNames" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "SeasonNumbers" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "SeasonRatingKeys" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "year" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "ratingKey" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "Path" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "RootFoldername" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "MultipleVersions" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "PlexPosterUrl" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "PlexBackgroundUrl" -Value $null
        $PlexLibDummycsv | Add-Member -MemberType NoteProperty -Name "PlexSeasonUrls" -Value $null

        $PlexLibDummycsv | Select-Object * | Export-Csv -Path "$global:ScriptRoot\Logs\PlexLibexport.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force
        Write-Entry -Message "No PlexLibexport.csv found, creating dummy file for you..." -Path $global:configLogging -Color White -log Info
    }
    # Store all Files from asset dir in a hashtable
    Write-Entry -Message "Creating Hashtable of all posters in asset dir..." -Path $global:configLogging -Color White -log Info
    try {
        $directoryHashtable = @{}
        $allowedExtensions = @(".jpg", ".jpeg", ".png", ".bmp")
        $totalSize = 0
        $excludePath = Join-Path -Path $BackupPath -ChildPath 'Collections'

        if ($FollowSymlink) {
            Get-ChildItem -Path $BackupPath -Recurse -FollowSymlink | Where-Object {
                $_.FullName -ne $excludePath -and $_.FullName -notlike "$excludePath/*"
            } | ForEach-Object {
                if ($allowedExtensions -contains $_.Extension.ToLower()) {
                    $directory = $_.Directory
                    $basename = $_.BaseName
                    if ($Platform -eq "Docker" -or $Platform -eq "Linux" -or $Platform -eq 'macOS') {
                        $directoryHashtable["$directory/$basename"] = $true
                    }
                    Else {
                        $directoryHashtable["$directory\$basename"] = $true
                    }
                }
                $totalSize += $_.Length
            }
        }
        Else {
            Get-ChildItem -Path $BackupPath -Recurse | Where-Object {
                $_.FullName -ne $excludePath -and $_.FullName -notlike "$excludePath/*"
            } | ForEach-Object {
                if ($allowedExtensions -contains $_.Extension.ToLower()) {
                    $directory = $_.Directory
                    $basename = $_.BaseName
                    if ($Platform -eq "Docker" -or $Platform -eq "Linux" -or $Platform -eq 'macOS') {
                        $directoryHashtable["$directory/$basename"] = $true
                    }
                    Else {
                        $directoryHashtable["$directory\$basename"] = $true
                    }
                }
                $totalSize += $_.Length
            }
        }

        # Convert bytes to kilobytes, megabytes, or gigabytes as needed
        if ($totalSize -gt 1GB) {
            $totalSizeString = "{0:N2} GB" -f ($totalSize / 1GB)
        }
        elseif ($totalSize -gt 1MB) {
            $totalSizeString = "{0:N2} MB" -f ($totalSize / 1MB)
        }
        elseif ($totalSize -gt 1KB) {
            $totalSizeString = "{0:N2} KB" -f ($totalSize / 1KB)
        }
        else {
            $totalSizeString = "$totalSize bytes"
        }

        Write-Entry -Subtext "Hashtable created..." -Path $global:configLogging -Color Green -log Info
        Write-Entry -Subtext "Found: '$($directoryHashtable.count)' images in asset directory." -Path $global:configLogging -Color Cyan -log Info
        Write-Entry -Subtext "Total size of asset directory: $totalSizeString" -Path $global:configLogging -Color Cyan -log Info
    }
    catch {
        Write-Entry -Subtext "Error during Hashtable creation, please check Asset dir is available..." -Path $global:configLogging -Color Red -log Error
        HandleScriptExit -Message "Hashtable creation failed"
    }
    if ($global:logLevel -eq '3') {
        Write-Entry -Message "Output hashtable..." -Path $global:configLogging -Color White -log Info
        $directoryHashtable.keys | Out-File "$global:ScriptRoot\Logs\hashtable.log" -Force
    }

    # Download poster foreach movie
    Write-Entry -Message "Starting asset download now, this can take a while..." -Path $global:configLogging -Color White -log Info
    Write-Entry -Message "Starting Movie Poster/Background download part..." -Path $global:configLogging -Color Green -log Info

    $checkedItems = [System.Collections.Generic.List[object]]::new()
    # Movie Part
    foreach ($entry in $AllMovies) {
        try {
            if ($($entry.RootFoldername)) {
                $SkippingText = 'false'
                $global:posterurl = $null
                $global:ImageMagickError = $null
                $global:TMDBfallbackposterurl = $null
                $global:fanartfallbackposterurl = $null
                $global:IsFallback = $null
                $global:PlexartworkDownloaded = $null
                $global:langCode = $null
                $global:direction = $null

                # Determine the language direction
                $global:langCode = $entry.'Library Language'
                $global:direction = $global:languageDirections[$global:langCode]

                $cjkPattern = '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}\p{IsCyrillic}\p{IsDevanagari}\p{IsThai}\p{IsEthiopic}\p{IsGeorgian}\p{IsArmenian}\p{IsBengali}]'

                if ($UseOriginalTitle -eq 'true') {
                    if ($entry.originalTitle -match $cjkPattern) {
                        $Titletext = $entry.title
                    }
                    else {
                        $Titletext = $entry.originalTitle
                    }
                }
                Else {
                    if ($entry.title -match $cjkPattern) {
                        $Titletext = $entry.originalTitle
                    }
                    else {
                        $Titletext = $entry.title
                    }
                }

                if ($LibraryFolders -eq 'true') {
                    $LibraryName = $entry.'Library Name'
                    $EntryDir = "$BackupPath\$LibraryName\$($entry.RootFoldername)"
                    $PosterImageoriginal = "$EntryDir\poster.jpg"
                    $TestPath = $EntryDir
                    $Testfile = "poster"

                    if (!(Get-ChildItem -LiteralPath $EntryDir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -path $EntryDir -Force | out-null
                    }
                }
                Else {
                    $PosterImageoriginal = "$BackupPath\$($entry.RootFoldername).jpg"
                    $TestPath = $BackupPath
                    $Testfile = $($entry.RootFoldername)
                }

                if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                    $PosterImageoriginal = ($PosterImageoriginal).Replace('\', '/').Replace('./', '/')
                    $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                }
                else {
                    $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                    if ($fullTestPath) {
                        $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                    }
                    Else {
                        $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                    }
                }
                Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug
                $PosterImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername).jpg"
                $PosterImage = $PosterImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')
                # Now we can start the Poster Part
                if ($global:Posters -eq 'true') {
                    $checkedItems.Add($hashtestpath)

                    if (($null -ne $FileTestOnTrigger -and $FileTestOnTrigger -eq 'false') -or (-not $directoryHashtable.ContainsKey("$hashtestpath"))) {
                        # Define Global Variables
                        $SkippingText = 'false'
                        $global:tmdbid = $entry.tmdbid
                        $global:tvdbid = $entry.tvdbid
                        $global:imdbid = $entry.imdbid
                        $global:TextlessPoster = $null
                        $global:posterurl = $null
                        $global:PosterWithText = $null
                        $global:AssetTextLang = $null
                        $global:TMDBAssetTextLang = $null
                        $global:FANARTAssetTextLang = $null
                        $global:TVDBAssetTextLang = $null
                        $global:TMDBAssetChangeUrl = $null
                        $global:FANARTAssetChangeUrl = $null
                        $global:TVDBAssetChangeUrl = $null
                        $global:Fallback = $null
                        $global:IsFallback = $null
                        $global:ImageMagickError = $null
                        $Arturl = $null

                        if ($entry.PlexPosterUrl -like "/library/*") {
                            if ($PlexToken) {
                                $Arturl = $plexurl + $entry.PlexPosterUrl + "?X-Plex-Token=$PlexToken"
                            }
                            Else {
                                $Arturl = $plexurl + $entry.PlexPosterUrl
                            }
                        }
                        Write-Entry -Message "Searching on Plex for $Titletext - Poster" -Path $global:configLogging -Color White -log Info

                        if ($fontAllCaps -eq 'true') {
                            $joinedTitle = $Titletext.ToUpper()
                        }
                        Else {
                            $joinedTitle = $Titletext
                        }
                        GetPlexArtworkUrl -ArtUrl $Arturl -TempImage $PosterImage
                        if ($global:posterurl) {
                            try {
                                Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                Write-Entry -Subtext "Downloading Poster from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $PosterImage -ErrorAction Stop
                            }
                            catch {
                                if ($_.Exception.Response) {
                                    $statusCode = $_.Exception.Response.StatusCode.value__
                                }
                                else {
                                    $statusCode = $_.Exception.Message
                                }
                                Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error


                            }
                            # Move file back to original naming with Brackets.
                            if (Get-ChildItem -LiteralPath $PosterImage -ErrorAction SilentlyContinue) {
                                try {
                                    if ($LibraryFolders -eq 'true' -and !(Test-Path -LiteralPath $EntryDir)) {
                                        New-Item -ItemType Directory -Path $EntryDir -Force | Out-Null
                                    }
                                    # Attempt to move the item
                                    Move-Item -LiteralPath $PosterImage -Destination $PosterImageoriginal -Force -ErrorAction Stop

                                    # Log success if move was successful
                                    Write-Entry -Subtext "Added: $PosterImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                }
                                catch {
                                    # Log the error if the move operation fails
                                    Write-Entry -Subtext "Failed to move $PosterImage to $PosterImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                    Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                }
                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                $posterCount++
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                        }
                    }
                    else {
                        if ($show_skipped -eq 'true' ) {
                            Write-Entry -Subtext "Already exists: $PosterImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                        }
                    }
                }
                # Now we can start the Background Poster Part
                if ($global:BackgroundPosters -eq 'true') {
                    if ($LibraryFolders -eq 'true') {
                        $LibraryName = $entry.'Library Name'
                        $EntryDir = "$BackupPath\$LibraryName\$($entry.RootFoldername)"
                        $backgroundImageoriginal = "$EntryDir\background.jpg"
                        $TestPath = $EntryDir
                        $Testfile = "background"

                        if (!(Get-ChildItem -LiteralPath $EntryDir -ErrorAction SilentlyContinue)) {
                            New-Item -ItemType Directory -path $EntryDir -Force | out-null
                        }
                    }
                    Else {
                        $backgroundImageoriginal = "$BackupPath\$($entry.RootFoldername)_background.jpg"
                        $TestPath = $BackupPath
                        $Testfile = "$($entry.RootFoldername)_background"
                    }

                    if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                        $backgroundImageoriginal = ($backgroundImageoriginal).Replace('\', '/').Replace('./', '/')
                        $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                    }
                    else {
                        $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                        if ($fullTestPath) {
                            $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                        }
                        Else {
                            $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                        }
                    }

                    $backgroundImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername)_background.jpg"
                    $backgroundImage = $backgroundImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')
                    $checkedItems.Add($hashtestpath)

                    if (($null -ne $FileTestOnTrigger -and $FileTestOnTrigger -eq 'false') -or (-not $directoryHashtable.ContainsKey("$hashtestpath"))) {
                        # Define Global Variables
                        $SkippingText = 'false'
                        $global:tmdbid = $entry.tmdbid
                        $global:tvdbid = $entry.tvdbid
                        $global:imdbid = $entry.imdbid
                        $global:posterurl = $null
                        $global:PosterWithText = $null
                        $global:AssetTextLang = $null
                        $global:Fallback = $null
                        $global:IsFallback = $null
                        $global:TMDBAssetTextLang = $null
                        $global:FANARTAssetTextLang = $null
                        $global:TVDBAssetTextLang = $null
                        $global:TMDBAssetChangeUrl = $null
                        $global:FANARTAssetChangeUrl = $null
                        $global:TVDBAssetChangeUrl = $null
                        $global:ImageMagickError = $null
                        $global:TextlessPoster = $null
                        $Arturl = $null

                        if ($entry.PlexBackgroundUrl -like "/library/*") {
                            if ($PlexToken) {
                                $Arturl = $plexurl + $entry.PlexBackgroundUrl + "?X-Plex-Token=$PlexToken"
                            }
                            Else {
                                $Arturl = $plexurl + $entry.PlexBackgroundUrl
                            }
                        }
                        Write-Entry -Message "Searching on Plex for $Titletext - Background" -Path $global:configLogging -Color White -log Info

                        if ($BackgroundfontAllCaps -eq 'true') {
                            $joinedTitle = $Titletext.ToUpper()
                        }
                        Else {
                            $joinedTitle = $Titletext
                        }
                        GetPlexArtworkUrl -ArtUrl $Arturl -TempImage $BackgroundImage
                        if ($global:posterurl) {
                            try {
                                Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                Write-Entry -Subtext "Downloading Poster from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $BackgroundImage -ErrorAction Stop
                            }
                            catch {
                                if ($_.Exception.Response) {
                                    $statusCode = $_.Exception.Response.StatusCode.value__
                                }
                                else {
                                    $statusCode = $_.Exception.Message
                                }
                                Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                            }

                            # Move file back to original naming with Brackets.
                            if (Get-ChildItem -LiteralPath $backgroundImage -ErrorAction SilentlyContinue) {
                                try {
                                    # Attempt to move the item
                                    Move-Item -LiteralPath $backgroundImage -Destination $backgroundImageoriginal -Force -ErrorAction Stop

                                    # Log success if move was successful
                                    Write-Entry -Subtext "Added: $backgroundImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                }
                                catch {
                                    # Log the error if the move operation fails
                                    Write-Entry -Subtext "Failed to move $backgroundImage to $backgroundImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                    Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                }
                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                $posterCount++
                                $BackgroundCount++
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                        }
                    }
                    else {
                        if ($show_skipped -eq 'true' ) {
                            Write-Entry -Subtext "Already exists: $backgroundImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                        }
                    }
                }
            }
            Else {
                Write-Entry -Message "Rootfolder value: $($entry.RootFoldername)" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Path value: $($entry.Path)" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Missing RootFolder for: $($entry.title) - you have to manually create the poster for it..." -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
        }
        catch {
            Write-Entry -Subtext "Could not query entries from movies array, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            write-Entry -Subtext "At line $($_.InvocationInfo.ScriptLineNumber)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

        }
    }

    Write-Entry -Message "Starting Show/Season Poster/Background/TitleCard Download part..." -Path $global:configLogging -Color Green -log Info
    # Show Part
    foreach ($entry in $AllShows) {
        if ($($entry.RootFoldername)) {
            # Define Global Variables
            $SkippingText = 'false'
            $global:tmdbid = $entry.tmdbid
            $global:tvdbid = $entry.tvdbid
            $global:imdbid = $entry.imdbid
            $Seasonpostersearchtext = $null
            $global:ImageMagickError = $null
            $Episodepostersearchtext = $null
            $global:TMDBfallbackposterurl = $null
            $global:fanartfallbackposterurl = $null
            $FanartSearched = $null
            $global:plexalreadysearched = $null
            $global:posterurl = $null
            $global:PosterWithText = $null
            $global:AssetTextLang = $null
            $global:TMDBAssetTextLang = $null
            $global:FANARTAssetTextLang = $null
            $global:TVDBAssetTextLang = $null
            $global:TMDBAssetChangeUrl = $null
            $global:FANARTAssetChangeUrl = $null
            $global:TVDBAssetChangeUrl = $null
            $global:IsFallback = $null
            $global:FallbackText = $null
            $global:Fallback = $null
            $global:TextlessPoster = $null
            $global:tvdbalreadysearched = $null
            $global:PlexartworkDownloaded = $null
            $global:langCode = $null
            $global:direction = $null

            # Determine the language direction
            $global:langCode = $entry.'Library Language'
            $global:direction = $global:languageDirections[$global:langCode]

            $cjkPattern = '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}\p{IsCyrillic}\p{IsDevanagari}\p{IsThai}\p{IsEthiopic}\p{IsGeorgian}\p{IsArmenian}\p{IsBengali}]'

            if ($UseOriginalTitle -eq 'true') {
                if ($entry.originalTitle -match $cjkPattern) {
                    $Titletext = $entry.title
                }
                else {
                    $Titletext = $entry.originalTitle
                }
            }
            Else {
                if ($entry.title -match $cjkPattern) {
                    $Titletext = $entry.originalTitle
                }
                else {
                    $Titletext = $entry.title
                }
            }

            if ($LibraryFolders -eq 'true') {
                $LibraryName = $entry.'Library Name'
                $EntryDir = "$BackupPath\$LibraryName\$($entry.RootFoldername)"
                $PosterImageoriginal = "$EntryDir\poster.jpg"
                $TestPath = $EntryDir
                $Testfile = "poster"

                if (!(Get-ChildItem -LiteralPath $EntryDir -ErrorAction SilentlyContinue)) {
                    New-Item -ItemType Directory -path $EntryDir -Force | out-null
                }
            }
            Else {
                $PosterImageoriginal = "$BackupPath\$($entry.RootFoldername).jpg"
                $TestPath = $BackupPath
                $Testfile = $($entry.RootFoldername)
            }

            if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                $PosterImageoriginal = ($PosterImageoriginal).Replace('\', '/').Replace('./', '/')
                $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
            }
            else {
                $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                if ($fullTestPath) {
                    $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                }
                Else {
                    $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                }
            }

            Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
            Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
            Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
            Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug

            $PosterImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername).jpg"
            $PosterImage = $PosterImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')

            # Now we can start the Poster Part
            if ($global:Posters -eq 'true') {
                $checkedItems.Add($hashtestpath)

                if (($null -ne $FileTestOnTrigger -and $FileTestOnTrigger -eq 'false') -or (-not $directoryHashtable.ContainsKey("$hashtestpath"))) {
                    $Arturl = $null
                    if ($entry.PlexPosterUrl -like "/library/*") {
                        if ($PlexToken) {
                            $Arturl = $plexurl + $entry.PlexPosterUrl + "?X-Plex-Token=$PlexToken"
                        }
                        Else {
                            $Arturl = $plexurl + $entry.PlexPosterUrl
                        }
                    }
                    Write-Entry -Message "Searching on Plex for $Titletext - Poster" -Path $global:configLogging -Color White -log Info
                    GetPlexArtworkUrl -ArtUrl $Arturl -TempImage $PosterImage

                    if ($fontAllCaps -eq 'true') {
                        $joinedTitle = $Titletext.ToUpper()
                    }
                    Else {
                        $joinedTitle = $Titletext
                    }
                    if (!$global:TextlessPoster -eq 'true' -and $global:TMDBfallbackposterurl) {
                        $global:posterurl = $global:TMDBfallbackposterurl
                    }
                    if (!$global:TextlessPoster -eq 'true' -and $global:fanartfallbackposterurl) {
                        $global:posterurl = $global:fanartfallbackposterurl
                    }
                    if ($global:posterurl) {
                        try {
                            Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                            Write-Entry -Subtext "Downloading Poster from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                            $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $PosterImage -ErrorAction Stop
                        }
                        catch {
                            if ($_.Exception.Response) {
                                $statusCode = $_.Exception.Response.StatusCode.value__
                            }
                            else {
                                $statusCode = $_.Exception.Message
                            }
                            Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                        }
                        if (Get-ChildItem -LiteralPath $PosterImage -ErrorAction SilentlyContinue) {
                            # Move file back to original naming with Brackets.
                            try {
                                # Attempt to move the item
                                Move-Item -LiteralPath $PosterImage -Destination $PosterImageoriginal -Force -ErrorAction Stop

                                # Log success if move was successful
                                Write-Entry -Subtext "Added: $PosterImageoriginal" -Path $global:configLogging -Color Green -Log Info
                            }
                            catch {
                                # Log the error if the move operation fails
                                Write-Entry -Subtext "Failed to move $PosterImage to $PosterImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                            }
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $posterCount++
                        }

                    }
                    Else {
                        Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                        Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                        $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                    }
                }
                else {
                    if ($show_skipped -eq 'true' ) {
                        Write-Entry -Subtext "Already exists: $PosterImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                    }
                }
            }
            # Now we can start the Background Part
            if ($global:BackgroundPosters -eq 'true') {
                if ($LibraryFolders -eq 'true') {
                    $LibraryName = $entry.'Library Name'
                    $EntryDir = "$BackupPath\$LibraryName\$($entry.RootFoldername)"
                    $backgroundImageoriginal = "$EntryDir\background.jpg"
                    $TestPath = $EntryDir
                    $Testfile = "background"

                    if (!(Get-ChildItem -LiteralPath $EntryDir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -path $EntryDir -Force | out-null
                    }
                }
                Else {
                    $backgroundImageoriginal = "$BackupPath\$($entry.RootFoldername)_background.jpg"
                    $TestPath = $BackupPath
                    $Testfile = "$($entry.RootFoldername)_background"
                }

                if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                    $backgroundImageoriginal = ($backgroundImageoriginal).Replace('\', '/').Replace('./', '/')
                    $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                }
                else {
                    $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                    if ($fullTestPath) {
                        $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                    }
                    Else {
                        $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                    }
                }

                Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug

                $backgroundImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername)_background.jpg"
                $backgroundImage = $backgroundImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')
                $checkedItems.Add($hashtestpath)

                if (($null -ne $FileTestOnTrigger -and $FileTestOnTrigger -eq 'false') -or (-not $directoryHashtable.ContainsKey("$hashtestpath"))) {
                    # Define Global Variables
                    $SkippingText = 'false'
                    $global:tmdbid = $entry.tmdbid
                    $global:tvdbid = $entry.tvdbid
                    $global:imdbid = $entry.imdbid
                    $global:posterurl = $null
                    $global:PosterWithText = $null
                    $global:AssetTextLang = $null
                    $global:Fallback = $null
                    $global:IsFallback = $null
                    $global:FallbackText = $null
                    $global:TMDBAssetTextLang = $null
                    $global:FANARTAssetTextLang = $null
                    $global:TVDBAssetTextLang = $null
                    $global:TMDBAssetChangeUrl = $null
                    $global:FANARTAssetChangeUrl = $null
                    $global:TVDBAssetChangeUrl = $null
                    $global:TextlessPoster = $null
                    $global:ImageMagickError = $null
                    $Arturl = $null
                    if ($entry.PlexBackgroundUrl -like "/library/*") {
                        if ($PlexToken) {
                            $Arturl = $plexurl + $entry.PlexBackgroundUrl + "?X-Plex-Token=$PlexToken"
                        }
                        Else {
                            $Arturl = $plexurl + $entry.PlexBackgroundUrl
                        }
                    }
                    Write-Entry -Message "Searching on Plex for $Titletext - Background" -Path $global:configLogging -Color White -log Info
                    GetPlexArtworkUrl -ArtUrl $Arturl -TempImage $backgroundImage

                    if ($BackgroundfontAllCaps -eq 'true') {
                        $joinedTitle = $Titletext.ToUpper()
                    }
                    Else {
                        $joinedTitle = $Titletext
                    }
                    if ($global:posterurl) {
                        try {
                            Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                            Write-Entry -Subtext "Downloading Poster from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                            $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $BackgroundImage -ErrorAction Stop
                        }
                        catch {
                            if ($_.Exception.Response) {
                                $statusCode = $_.Exception.Response.StatusCode.value__
                            }
                            else {
                                $statusCode = $_.Exception.Message
                            }
                            Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                        }
                        # Move file back to original naming with Brackets.
                        if (Get-ChildItem -LiteralPath $backgroundImage -ErrorAction SilentlyContinue) {
                            try {
                                # Attempt to move the item
                                Move-Item -LiteralPath $backgroundImage -Destination $backgroundImageoriginal -Force -ErrorAction Stop

                                # Log success if move was successful
                                Write-Entry -Subtext "Added: $backgroundImageoriginal" -Path $global:configLogging -Color Green -Log Info
                            }
                            catch {
                                # Log the error if the move operation fails
                                Write-Entry -Subtext "Failed to move $backgroundImage to $backgroundImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                            }
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $BackgroundCount++
                            $posterCount++
                        }
                    }
                    Else {
                        Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                        Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                        $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                    }
                }
                else {
                    if ($show_skipped -eq 'true' ) {
                        Write-Entry -Subtext "Already exists: $backgroundImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                    }
                }
            }
            # Now we can start the Season Part
            if ($global:SeasonPosters -eq 'true') {
                $global:IsFallback = $null
                $global:FallbackText = $null
                $global:AssetTextLang = $null
                $global:Fallback = $null
                $global:TMDBAssetTextLang = $null
                $global:FANARTAssetTextLang = $null
                $global:TVDBAssetTextLang = $null
                $global:TMDBAssetChangeUrl = $null
                $global:FANARTAssetChangeUrl = $null
                $global:TVDBAssetChangeUrl = $null
                $global:PosterWithText = $null
                $global:ImageMagickError = $null
                $global:TextlessPoster = $null
                $global:seasonNames = $entry.SeasonNames -split ';'
                $global:SeasonRatingKeys = $entry.SeasonRatingKeys -split ','
                $global:seasonNumbers = $entry.seasonNumbers -split ','
                $global:PlexSeasonUrls = $entry.PlexSeasonUrls -split ','
                for ($i = 0; $i -lt $global:seasonNames.Count; $i++) {
                    $SkippingText = 'false'
                    $global:posterurl = $null
                    $global:seasontmp = $null
                    $global:IsFallback = $null
                    $global:FallbackText = $null
                    $global:AssetTextLang = $null
                    $global:Fallback = $null
                    $global:TMDBAssetTextLang = $null
                    $global:FANARTAssetTextLang = $null
                    $global:TVDBAssetTextLang = $null
                    $global:TMDBAssetChangeUrl = $null
                    $global:FANARTAssetChangeUrl = $null
                    $global:TVDBAssetChangeUrl = $null
                    $global:PosterWithText = $null
                    $global:ImageMagickError = $null
                    $global:TMDBSeasonFallback = $null
                    $global:TVDBSeasonFallback = $null
                    $global:FANARTSeasonFallback = $null
                    if ($SeasonfontAllCaps -eq 'true') {
                        $global:seasonTitle = $global:seasonNames[$i].ToUpper()
                    }
                    Else {
                        $global:seasonTitle = $global:seasonNames[$i]
                    }
                    $global:SeasonNumber = $global:seasonNumbers[$i]
                    $global:SeasonRatingKey = $global:SeasonRatingKeys[$i]
                    $global:PlexSeasonUrl = $global:PlexSeasonUrls[$i]
                    if ($null -ne $global:SeasonNumber) {
                        $global:seasontmp = "Season" + $global:SeasonNumber.PadLeft(2, '0')
                    }
                    if ($LibraryFolders -eq 'true') {
                        $SeasonImageoriginal = "$EntryDir\$global:seasontmp.jpg"
                        $TestPath = $EntryDir
                        $Testfile = "$global:seasontmp"
                    }
                    Else {
                        $SeasonImageoriginal = "$BackupPath\$($entry.RootFoldername)_$global:seasontmp.jpg"
                        $TestPath = $BackupPath
                        $Testfile = "$($entry.RootFoldername)_$global:seasontmp"
                    }

                    if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                        $SeasonImageoriginal = ($SeasonImageoriginal).Replace('\', '/').Replace('./', '/')
                        $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                    }
                    else {
                        $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                        if ($fullTestPath) {
                            $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                        }
                        Else {
                            $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                        }
                    }

                    Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug

                    $SeasonImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername)_$global:seasontmp.jpg"
                    $SeasonImage = $SeasonImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')
                    $checkedItems.Add($hashtestpath)

                    if (($null -ne $FileTestOnTrigger -and $FileTestOnTrigger -eq 'false') -or (-not $directoryHashtable.ContainsKey("$hashtestpath"))) {
                        $Arturl = $null
                        if ($global:PlexSeasonUrl -like "/library/*") {
                            if ($PlexToken) {
                                $Arturl = $plexurl + $global:PlexSeasonUrl + "?X-Plex-Token=$PlexToken"
                            }
                            Else {
                                $Arturl = $plexurl + $global:PlexSeasonUrl
                            }
                        }
                        if (!$Seasonpostersearchtext) {
                            Write-Entry -Message "Searching on Plex for $Titletext - Season" -Path $global:configLogging -Color White -log Info
                            $Seasonpostersearchtext = $true
                        }
                        GetPlexArtworkUrl -ArtUrl $Arturl -TempImage $SeasonImage
                        if ($global:posterurl) {
                            try {
                                Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                Write-Entry -Subtext "Downloading Poster from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $SeasonImage -ErrorAction Stop
                            }
                            catch {
                                if ($_.Exception.Response) {
                                    $statusCode = $_.Exception.Response.StatusCode.value__
                                }
                                else {
                                    $statusCode = $_.Exception.Message
                                }
                                Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                            }
                            if (Get-ChildItem -LiteralPath $SeasonImage -ErrorAction SilentlyContinue) {
                                # Move file back to original naming with Brackets.
                                try {
                                    # Attempt to move the item
                                    Move-Item -LiteralPath $SeasonImage -Destination $SeasonImageoriginal -Force -ErrorAction Stop

                                    # Log success if move was successful
                                    Write-Entry -Subtext "Added: $SeasonImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                }
                                catch {
                                    # Log the error if the move operation fails
                                    Write-Entry -Subtext "Failed to move $SeasonImage to $SeasonImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                    Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                }
                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                $SeasonCount++
                                $posterCount++
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                        }
                    }
                    else {
                        if ($show_skipped -eq 'true' ) {
                            Write-Entry -Subtext "Already exists: $SeasonImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                        }
                    }
                }
            }
            # Now we can start the Episode Part
            if ($global:TitleCards -eq 'true') {
                # Loop through each episode
                foreach ($episode in $Episodedata) {
                    $SkippingText = 'false'
                    $global:AssetTextLang = $null
                    $global:TMDBAssetTextLang = $null
                    $global:FANARTAssetTextLang = $null
                    $global:TVDBAssetTextLang = $null
                    $global:TMDBAssetChangeUrl = $null
                    $global:FANARTAssetChangeUrl = $null
                    $global:TVDBAssetChangeUrl = $null
                    $global:PosterWithText = $null
                    $global:ImageMagickError = $null
                    $global:season_number = $null
                    $Episodepostersearchtext = $null
                    $global:show_name = $null
                    $global:episodenumber = $null
                    $global:episode_numbers = $null
                    $global:titles = $null
                    $global:posterurl = $null
                    $global:FileNaming = $null
                    $EpisodeImageoriginal = $null
                    $EpisodeImage = $null
                    $global:Fallback = $null
                    $global:IsFallback = $null
                    $global:FallbackText = $null
                    $global:TextlessPoster = $null

                    if (($episode.tmdbid -eq $entry.tmdbid -or $episode.tvdbid -eq $entry.tvdbid) -and $episode.'Show Name' -eq $entry.title -and $episode.'Library Name' -eq $entry.'Library Name') {
                        $global:show_name = $episode."Show Name"
                        $global:season_number = $episode."Season Number"
                        $global:episode_numbers = $episode."Episodes".Split(",")
                        $global:episode_ratingkeys = $episode."ratingKeys".Split(",")
                        $global:titles = $episode."Title".Split(";")
                        $global:PlexTitleCardUrls = $episode."PlexTitleCardUrls".Split(",")
                        $global:ImageMagickError = $null
                        for ($i = 0; $i -lt $global:episode_numbers.Count; $i++) {
                            $SkippingText = 'false'
                            $global:AssetTextLang = $null
                            $global:TMDBAssetTextLang = $null
                            $global:FANARTAssetTextLang = $null
                            $global:TVDBAssetTextLang = $null
                            $global:TMDBAssetChangeUrl = $null
                            $global:FANARTAssetChangeUrl = $null
                            $global:TVDBAssetChangeUrl = $null
                            $global:PosterWithText = $null
                            $global:Fallback = $null
                            $global:IsFallback = $null
                            $global:posterurl = $null
                            $Episodepostersearchtext = $null
                            $ExifFound = $null
                            $global:PlexartworkDownloaded = $null
                            $value = $null
                            $magickcommand = $null
                            $Arturl = $null
                            $global:PlexTitleCardUrl = $($global:PlexTitleCardUrls[$i].Trim())
                            $global:episode_ratingkey = $($global:episode_ratingkeys[$i].Trim())
                            $global:EPTitle = $($global:titles[$i].Trim())
                            $global:episodenumber = $($global:episode_numbers[$i].Trim())
                            $global:FileNaming = "S" + $global:season_number.PadLeft(2, '0') + "E" + $global:episodenumber.PadLeft(2, '0')
                            $bullet = [char]0x2022
                            $global:SeasonEPNumber = "$SeasonTCText $global:season_number $bullet $EpisodeTCText $global:episodenumber"

                            if ($LibraryFolders -eq 'true') {
                                $EpisodeImageoriginal = "$EntryDir\$global:FileNaming.jpg"
                                $TestPath = $EntryDir
                                $Testfile = "$global:FileNaming"
                            }
                            Else {
                                $EpisodeImageoriginal = "$BackupPath\$($entry.RootFoldername)_$global:FileNaming.jpg"
                                $TestPath = $BackupPath
                                $Testfile = "$($entry.RootFoldername)_$global:FileNaming"
                            }

                            if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                                $EpisodeImageoriginal = ($EpisodeImageoriginal).Replace('\', '/').Replace('./', '/')
                                $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                            }
                            else {
                                $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                                if ($fullTestPath) {
                                    $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                                }
                                Else {
                                    $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                                }
                            }

                            Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
                            Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug

                            $EpisodeImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername)_$global:FileNaming.jpg"
                            $EpisodeImage = $EpisodeImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')

                            $cjkTitlePattern = '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}\p{IsThai}]'
                            $checkedItems.Add($hashtestpath)

                            if (($null -ne $FileTestOnTrigger -and $FileTestOnTrigger -eq 'false') -or (-not $directoryHashtable.ContainsKey("$hashtestpath"))) {
                                $Arturl = $null
                                if ($global:PlexTitleCardUrl -like "/library/*") {
                                    if ($PlexToken) {
                                        $Arturl = $plexurl + $global:PlexTitleCardUrl + "?X-Plex-Token=$PlexToken"
                                    }
                                    Else {
                                        $Arturl = $plexurl + $global:PlexTitleCardUrl
                                    }
                                }
                                Write-Entry -Message "Searching on Plex for $global:show_name | $global:SeasonEPNumber - Titlecard" -Path $global:configLogging -Color White -log Info
                                GetPlexArtworkUrl -ArtUrl $ArtUrl -TempImage $EpisodeImage
                                if ($global:posterurl) {
                                    try {
                                        Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                        Write-Entry -Subtext "Downloading Titlecard from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $EpisodeImage -ErrorAction Stop
                                    }
                                    catch {
                                        if ($_.Exception.Response) {
                                            $statusCode = $_.Exception.Response.StatusCode.value__
                                        }
                                        else {
                                            $statusCode = $_.Exception.Message
                                        }
                                        Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                        $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                    }
                                    if (Get-ChildItem -LiteralPath $EpisodeImage -ErrorAction SilentlyContinue) {
                                        # Move file back to original naming with Brackets.
                                        try {
                                            # Attempt to move the item
                                            Move-Item -LiteralPath $EpisodeImage -Destination $EpisodeImageoriginal -Force -ErrorAction Stop

                                            # Log success if move was successful
                                            Write-Entry -Subtext "Added: $EpisodeImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                        }
                                        catch {
                                            # Log the error if the move operation fails
                                            Write-Entry -Subtext "Failed to move $EpisodeImage to $EpisodeImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                            Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                        }
                                        Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                        $EpisodeCount++
                                        $posterCount++
                                    }
                                }
                                Else {
                                    Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                }

                            }
                            else {
                                if ($show_skipped -eq 'true' ) {
                                    Write-Entry -Subtext "Already exists: $EpisodeImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                                }
                            }
                        }
                    }
                }
            }
        }
        Else {
            Write-Entry -Message "Rootfolder value: $($entry.RootFoldername)" -Path $global:configLogging -Color Cyan -log Debug
            Write-Entry -Message "Path value: $($entry.Path)" -Path $global:configLogging -Color Cyan -log Debug
            Write-Entry -Message "Missing RootFolder for: $($entry.title) - you have to manually create the poster for it..." -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

        }
    }

    $endTime = Get-Date
    $executionTime = New-TimeSpan -Start $startTime -End $endTime
    # Format the execution time
    $hours = [math]::Floor($executionTime.TotalHours)
    $minutes = $executionTime.Minutes
    $seconds = $executionTime.Seconds
    $FormattedTimespawn = $hours.ToString() + "h " + $minutes.ToString() + "m " + $seconds.ToString() + "s "
    Write-Entry -Message "Finished, Total images downloaded: $posterCount" -Path $global:configLogging -Color Green -log Info
    if ($posterCount -ge '1') {
        Write-Entry -Message "Show/Movie Posters downloaded: $($posterCount-$SeasonCount-$BackgroundCount-$EpisodeCount)| Season images downloaded: $SeasonCount | Background images downloaded: $BackgroundCount | TitleCards downloaded: $EpisodeCount" -Path $global:configLogging -Color Green -log Info
    }
    if ((Test-Path $global:ScriptRoot\Logs\ImageChoices.csv)) {
        Write-Entry -Message "You can find a detailed Summary of image Choices here: $global:ScriptRoot\Logs\ImageChoices.csv" -Path $global:configLogging -Color White -log Info
        # Calculate Summary
        $SummaryCount = Import-Csv -LiteralPath "$global:ScriptRoot\Logs\ImageChoices.csv" -Delimiter ';'
        $FallbackCount = @($SummaryCount | Where-Object Fallback -eq 'true')
        $TextlessCount = @($SummaryCount | Where-Object Language -eq 'Textless')
        $TextTruncatedCount = @($SummaryCount | Where-Object TextTruncated -eq 'true')
        $TextCount = @($SummaryCount | Where-Object Textless -eq 'false')
        if ($TextlessCount -or $FallbackCount -or $TextCount -or $PosterUnknownCount -or $TextTruncatedCount) {
            Write-Entry -Message "This is a subset summary of all image choices from the ImageChoices.csv" -Path $global:configLogging -Color Yellow -log Info
        }
        if ($TextlessCount) {
            Write-Entry -Subtext "'$($TextlessCount.count)' times the script took a Textless image" -Path $global:configLogging -Color Yellow -log Info
        }
        if ($FallbackCount) {
            Write-Entry -Subtext "'$($FallbackCount.count)' times the script took a fallback image" -Path $global:configLogging -Color Yellow -log Info
            Write-Entry -Subtext "'$($posterCount-$($FallbackCount.count))' times the script took the image from fav provider: $global:FavProvider" -Path $global:configLogging -Color Yellow -log Info
        }
        if ($TextCount) {
            Write-Entry -Subtext "'$($TextCount.count)' times the script took an image with Text" -Path $global:configLogging -Color Yellow -log Info
        }
        if ($PosterUnknownCount -ge '1') {
            Write-Entry -Subtext "'$PosterUnknownCount' times the script took a season poster where we cannot tell if it has text or not" -Path $global:configLogging -Color Yellow -log Info
        }
        if ($TextTruncatedCount) {
            Write-Entry -Subtext "'$($TextTruncatedCount.count)' times the script truncated the text in images" -Path $global:configLogging -Color Yellow -log Info
        }
    }
    if ($errorCount -ge '1') {
        Write-Entry -Message "During execution '$errorCount' Errors occurred, please check the log for a detailed description where you see [ERROR-HERE]." -Path $global:configLogging -Color White -log Info
    }
    Write-TextSizeCacheSummary
    Write-Entry -Message "Script execution time: $FormattedTimespawn" -Path $global:configLogging -Color White -log Info

    # Send Notification
    Send-SummaryNotification -ScriptMode $Mode -FormattedTimespawn $FormattedTimespawn -ErrorCount $errorCount -FallbackCount $FallbackCount.count -TextlessCount $TextlessCount.count -TruncatedCount $TextTruncatedCount.count -PosterUnknownCount $PosterUnknownCount -PosterCount $posterCount -BackgroundCount $BackgroundCount -SeasonCount $SeasonCount -EpisodeCount $EpisodeCount

    # Export json
    $jsonObject = [PSCustomObject]@{
        Posters              = if ($posterCount) { $posterCount } Else { 0 }
        Backgrounds          = if ($BackgroundCount) { $BackgroundCount } Else { 0 }
        Titlecards           = if ($EpisodeCount) { $EpisodeCount } Else { 0 }
        Seasons              = if ($SeasonCount) { $SeasonCount } Else { 0 }
        Collections          = if ($collectionCount) { $collectionCount } Else { 0 }
        Mode                 = $Mode
        Runtime              = $($hours.ToString() + ":" + $minutes.ToString() + ":" + $seconds.ToString())
        Errors               = if ($errorCount) { $errorCount } Else { 0 }
        Fallbacks            = if ($FallbackCount) { $FallbackCount } Else { 0 }
        Textless             = if ($TextlessCount) { $TextlessCount } Else { 0 }
        Truncated            = if ($TextTruncatedCount) { $TextTruncatedCount } Else { 0 }
        Text                 = if ($TextCount) { $TextCount } Else { 0 }
        "TBA Skipped"        = if ($SkipTBACount) { $SkipTBACount } Else { 0 }
        "Jap/Chines Skipped" = if ($SkipJapTitleCount) { $SkipJapTitleCount } Else { 0 }
        "Notification Sent"  = if ($global:SendNotification -eq 'true') { $global:SendNotification } Else { "false" }
        "Uptime Kuma"        = if ($global:UptimeKumaUrl) { "true" } Else { "false" }
        "Images cleared"     = if ($ImagesCleared) { $ImagesCleared } Else { 0 }
        "Folders Cleared"    = if ($PathsCleared) { $PathsCleared } Else { 0 }
        "Space saved"        = if ($savedsizestring) { $savedsizestring } Else { 0 }
        "Script Version"     = $CurrentScriptVersion
        "IM Version"         = $global:CurrentImagemagickversion
        "Start time"         = $startTime.ToString('dd.MM.yyyy HH:mm:ss')
        "End Time"           = $endTime.ToString('dd.MM.yyyy HH:mm:ss')
    }

    $jsonOutput = $jsonObject | ConvertTo-Json
    $jsonOutput | Out-File -FilePath "$global:ScriptRoot\Logs\$Mode.json" -Encoding utf8

    # Clear Running File
    if (Test-Path $CurrentlyRunning) {
        try {
            Remove-Item -LiteralPath $CurrentlyRunning -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Entry -Message "Failed to delete '$CurrentlyRunning'." -Path $global:configLogging -Color Red -log Error
            Write-Entry -Subtext "Reason: $($_.Exception.Message)" -Path $global:configLogging -Color Yellow -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
        }
    }
    if ($global:UptimeKumaUrl) {
        Send-UptimeKumaWebhook -status "up" -ping $executionTime.TotalMilliseconds
    }
}
function MassDownloadJellyEmbyArtwork {
    if ($UseJellyfin -eq 'true') {
        CheckJellyfinAccess -JellyfinUrl $JellyfinUrl -JellyfinApi $JellyfinAPIKey
        $OtherMediaServerUrl = $JellyfinUrl
        $OtherMediaServerApiKey = $JellyfinAPIKey
    }
    if ($UseEmby -eq 'true') {
        CheckEmbyAccess -EmbyUrl $EmbyUrl -EmbyAPI $EmbyAPIKey
        $OtherMediaServerUrl = $EmbyUrl
        $OtherMediaServerApiKey = $EmbyAPIKey
    }

    $Mode = "backup"
    Write-Entry -Message "Backup Mode Started..." -Path $global:configLogging -Color White -log Info
    Write-Entry -Message "Querying Jelly/Emby libraries..." -Path $global:configLogging -Color White -log Info

    $libsResponse = Invoke-RestMethod -Uri "$OtherMediaServerUrl/Library/VirtualFolders?api_key=$OtherMediaServerApiKey"

    $posterCount = 0
    $BackgroundCount = 0
    $SeasonCount = 0
    $EpisodeCount = 0

    foreach ($lib in $libsResponse) {
        if ($lib.Name -in $LibsToExclude) { continue }

        $collectionType = $lib.CollectionType.ToLower()
        if ($collectionType -notin @("movies", "tvshows")) { continue }

        Write-Entry -Message "--- Processing Library: $($lib.Name) ---" -Path $global:configLogging -Color Cyan -log Info

        $itemsUrl = "$OtherMediaServerUrl/Items?ParentId=$($lib.ItemId)&Recursive=true&IncludeItemTypes=Movie,Series&fields=Path,Id,Name,Type,ProductionYear,OriginalTitle&api_key=$OtherMediaServerApiKey"
        $items = (Invoke-RestMethod -Uri $itemsUrl).Items

        foreach ($item in $items) {
            # Extract Folder/File names
            $rootFolderName = Split-Path $item.Path -Leaf
            if ($item.Type -eq "Movie") {
                $rootFolderName = [System.IO.Path]::GetFileNameWithoutExtension($item.Path)
            }

            if ($LibraryFolders) {
                $entryDir = Join-Path $BackupPath "$($lib.Name)\$rootFolderName"
                $posterDest = Join-Path $entryDir "poster.jpg"
                $backdropDest = Join-Path $entryDir "background.jpg"
            }
            else {
                $entryDir = $BackupPath
                $posterDest = Join-Path $entryDir "$($rootFolderName).jpg"
                $backdropDest = Join-Path $entryDir "$($rootFolderName)_background.jpg"
            }

            if (!(Test-Path -LiteralPath $entryDir)) {
                New-Item -ItemType Directory -Path $entryDir -Force | Out-Null
            }

            # 1. Download Primary Poster
            $posterUrl = "$OtherMediaServerUrl/Items/$($item.Id)/Images/Primary?api_key=$OtherMediaServerApiKey"
            if (!(Test-Path -LiteralPath $posterDest)) {
                try {
                    Invoke-WebRequest -Uri $posterUrl -OutFile $posterDest -ErrorAction SilentlyContinue
                    $posterCount++
                    Write-Entry -Subtext "Added: $posterDest" -Path $global:configLogging -Color Green -Log Info
                }
                catch {
                    Write-Entry -Subtext "[ERROR-HERE] Failed to download poster for $($item.Name)" -Path $global:configLogging -Color Red -Log Error
                    $global:errorCount++
                }
            }

            # 2. Download Backdrop
            if (!(Test-Path -LiteralPath $backdropDest)) {
                try {
                    Invoke-WebRequest -Uri "$OtherMediaServerUrl/Items/$($item.Id)/Images/Backdrop?api_key=$OtherMediaServerApiKey" -OutFile $backdropDest -ErrorAction SilentlyContinue
                    $BackgroundCount++
                    $posterCount++
                    Write-Entry -Subtext "Added: $backdropDest" -Path $global:configLogging -Color Green -Log Info
                }
                catch {
                    Write-Entry -Subtext "No backdrop found for $($item.Name)" -Path $global:configLogging -Color Yellow -Log Debug
                    $global:errorCount++
                }
            }

            if ($item.Type -eq "Series") {
                $seasons = (Invoke-RestMethod -Uri "$OtherMediaServerUrl/Shows/$($item.Id)/Seasons?api_key=$OtherMediaServerApiKey").Items
                foreach ($season in $seasons) {
                    $sNum = if ($null -ne $season.IndexNumber) { $season.IndexNumber.ToString("D2") } else { "00" }
                    $sDest = if ($LibraryFolders) { Join-Path $entryDir "Season$sNum.jpg" } else { Join-Path $entryDir "$($rootFolderName)_season$sNum.jpg" }

                    if (!(Test-Path -LiteralPath $sDest)) {
                        try {
                            Invoke-WebRequest -Uri "$OtherMediaServerUrl/Items/$($season.Id)/Images/Primary?api_key=$OtherMediaServerApiKey" -OutFile $sDest -ErrorAction SilentlyContinue
                            Write-Entry -Subtext "Added: $sDest" -Path $global:configLogging -Color Green -Log Info
                        }
                        catch {
                            Write-Entry -Subtext "No season found for $($item.Name) | Season$sNum" -Path $global:configLogging -Color Yellow -Log Info
                            $global:errorCount++
                        }
                    }
                }

                $episodes = (Invoke-RestMethod -Uri "$OtherMediaServerUrl/Shows/$($item.Id)/Episodes?Fields=ParentIndexNumber,IndexNumber&api_key=$OtherMediaServerApiKey").Items
                foreach ($ep in $episodes) {
                    $sNum = if ($null -ne $ep.ParentIndexNumber) { $ep.ParentIndexNumber.ToString("D2") } else { "00" }
                    $eNum = if ($null -ne $ep.IndexNumber) { $ep.IndexNumber.ToString("D2") } else { "00" }
                    $naming = "S$($sNum)E$($eNum)"
                    $epDest = if ($LibraryFolders) { Join-Path $entryDir "$naming.jpg" } else { Join-Path $entryDir "$($rootFolderName)_$naming.jpg" }

                    if (!(Test-Path -LiteralPath $epDest)) {
                        try {
                            Invoke-WebRequest -Uri "$OtherMediaServerUrl/Items/$($ep.Id)/Images/Primary?api_key=$OtherMediaServerApiKey" -OutFile $epDest -ErrorAction SilentlyContinue
                            $EpisodeCount++
                            $posterCount++
                            Write-Entry -Subtext "Added: $epDest" -Path $global:configLogging -Color Green -Log Info
                        }
                        catch {
                            Write-Entry -Subtext "No episode found for $($item.Name) | $naming" -Path $global:configLogging -Color Yellow -Log Error
                            $global:errorCount++
                        }
                    }
                }
            }
        }
    }

    $endTime = Get-Date
    $executionTime = New-TimeSpan -Start $startTime -End $endTime
    # Format the execution time
    $hours = [math]::Floor($executionTime.TotalHours)
    $minutes = $executionTime.Minutes
    $seconds = $executionTime.Seconds
    $FormattedTimespawn = $hours.ToString() + "h " + $minutes.ToString() + "m " + $seconds.ToString() + "s "
    Write-Entry -Message "Finished, Total images downloaded: $posterCount" -Path $global:configLogging -Color Green -log Info
    if ($posterCount -ge '1') {
        Write-Entry -Message "Show/Movie Posters downloaded: $($posterCount-$SeasonCount-$BackgroundCount-$EpisodeCount)| Season images downloaded: $SeasonCount | Background images downloaded: $BackgroundCount | TitleCards downloaded: $EpisodeCount" -Path $global:configLogging -Color Green -log Info
    }
    if ($errorCount -ge '1') {
        Write-Entry -Message "During execution '$errorCount' Errors occurred, please check the log for a detailed description where you see [ERROR-HERE]." -Path $global:configLogging -Color White -log Info
    }
    Write-TextSizeCacheSummary
    Write-Entry -Message "Script execution time: $FormattedTimespawn" -Path $global:configLogging -Color White -log Info

    # Send Notification
    Send-SummaryNotification -ScriptMode $Mode -FormattedTimespawn $FormattedTimespawn -ErrorCount $errorCount -FallbackCount $FallbackCount.count -TextlessCount $TextlessCount.count -TruncatedCount $TextTruncatedCount.count -PosterUnknownCount $PosterUnknownCount -PosterCount $posterCount -BackgroundCount $BackgroundCount -SeasonCount $SeasonCount -EpisodeCount $EpisodeCount

    # Export json
    $jsonObject = [PSCustomObject]@{
        Posters              = if ($posterCount) { $posterCount } Else { 0 }
        Backgrounds          = if ($BackgroundCount) { $BackgroundCount } Else { 0 }
        Titlecards           = if ($EpisodeCount) { $EpisodeCount } Else { 0 }
        Seasons              = if ($SeasonCount) { $SeasonCount } Else { 0 }
        Collections          = if ($collectionCount) { $collectionCount } Else { 0 }
        Mode                 = $Mode
        Runtime              = $($hours.ToString() + ":" + $minutes.ToString() + ":" + $seconds.ToString())
        Errors               = if ($errorCount) { $errorCount } Else { 0 }
        Fallbacks            = if ($FallbackCount) { $FallbackCount } Else { 0 }
        Textless             = if ($TextlessCount) { $TextlessCount } Else { 0 }
        Truncated            = if ($TextTruncatedCount) { $TextTruncatedCount } Else { 0 }
        Text                 = if ($TextCount) { $TextCount } Else { 0 }
        "TBA Skipped"        = if ($SkipTBACount) { $SkipTBACount } Else { 0 }
        "Jap/Chines Skipped" = if ($SkipJapTitleCount) { $SkipJapTitleCount } Else { 0 }
        "Notification Sent"  = if ($global:SendNotification -eq 'true') { $global:SendNotification } Else { "false" }
        "Uptime Kuma"        = if ($global:UptimeKumaUrl) { "true" } Else { "false" }
        "Images cleared"     = if ($ImagesCleared) { $ImagesCleared } Else { 0 }
        "Folders Cleared"    = if ($PathsCleared) { $PathsCleared } Else { 0 }
        "Space saved"        = if ($savedsizestring) { $savedsizestring } Else { 0 }
        "Script Version"     = $CurrentScriptVersion
        "IM Version"         = $global:CurrentImagemagickversion
        "Start time"         = $startTime.ToString('dd.MM.yyyy HH:mm:ss')
        "End Time"           = $endTime.ToString('dd.MM.yyyy HH:mm:ss')
    }

    $jsonOutput = $jsonObject | ConvertTo-Json
    $jsonOutput | Out-File -FilePath "$global:ScriptRoot\Logs\$Mode.json" -Encoding utf8

    # Clear Running File
    if (Test-Path $CurrentlyRunning) {
        try {
            Remove-Item -LiteralPath $CurrentlyRunning -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Entry -Message "Failed to delete '$CurrentlyRunning'." -Path $global:configLogging -Color Red -log Error
            Write-Entry -Subtext "Reason: $($_.Exception.Message)" -Path $global:configLogging -Color Yellow -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
        }
    }
    if ($global:UptimeKumaUrl) {
        Send-UptimeKumaWebhook -status "up" -ping $executionTime.TotalMilliseconds
    }
}
function SyncPlexArtwork {
    param(
        [string]$ArtUrl,
        [string]$DestUrl,
        [string]$imageType,
        [string]$title,
        [string]$artworktype
    )
    $startmessage = $null

    if ($show_skipped -eq 'true') {
        Write-Entry -Message "Starting SyncPlexArtwork for: $title" -Path $global:configLogging -Color White -log Info
        $startmessage = $true
    }
    Else {
        Write-Entry -Message "Starting SyncPlexArtwork for: $title" -Path $global:configLogging -Color White -log Debug
        if ($global:logLevel -eq '3') {
            $startmessage = $true
        }
    }

    try {
        Write-Entry -Subtext "Fetching image from source: $(RedactMediaServerUrl -url $ArtUrl)" -Path $global:configLogging -Color Cyan -log Debug
        $imageResponse = Invoke-WebRequest -Uri $ArtUrl -Headers $extraPlexHeaders -UseBasicParsing -ErrorAction Stop
    }
    catch {
        # Attempt to parse JSON error response
        $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue

        if ($errorResponse) {
            $errorTitle = $errorResponse.title
            $errorStatus = $errorResponse.status
            if (-not $startmessage) {
                Write-Entry -Message "Starting SyncPlexArtwork for: $title" -Path $global:configLogging -Color White -log Info
            }
            Write-Entry -Subtext "Failed to retrieve source image: Status: $errorStatus, Title: $errorTitle" -Path $global:configLogging -Color Red -log Error
        }
        else {
            if (-not $startmessage) {
                Write-Entry -Message "Starting SyncPlexArtwork for: $title" -Path $global:configLogging -Color White -log Info
            }
            Write-Entry -Subtext "Failed to retrieve source image: Unknown error" -Path $global:configLogging -Color Red -log Error
        }

        return
    }


    if ($imageResponse.StatusCode -ne 200) {
        if (-not $startmessage) {
            Write-Entry -Message "Starting SyncPlexArtwork for: $title" -Path $global:configLogging -Color White -log Info
        }
        Write-Entry -Subtext "Unexpected response from source ($(RedactMediaServerUrl -url $ArtUrl)): $($imageResponse.StatusCode)" -Path $global:configLogging -Color Red -log Error
        return
    }

    $remoteImageBytes = $imageResponse.Content
    if (-not $remoteImageBytes) {
        if (-not $startmessage) {
            Write-Entry -Message "Starting SyncPlexArtwork for: $title" -Path $global:configLogging -Color White -log Info
        }
        Write-Entry -Subtext "Source image content is empty!" -Path $global:configLogging -Color Red -log Error
        return
    }

    $remoteImageContentType = $imageResponse.Headers.'Content-Type'
    if ($remoteImageContentType -is [System.Array]) {
        $remoteImageContentType = $remoteImageContentType[0]
    }

    Write-Entry -Subtext "Calculating hash for remote image..." -Path $global:configLogging -Color Cyan -log Debug
    $remoteImageHash = GetHash -imageBytes $remoteImageBytes

    try {
        Write-Entry -Subtext "Fetching existing image from destination: $(RedactMediaServerUrl -url $DestUrl)" -Path $global:configLogging -Color Cyan -log Debug
        $existingImageResponse = Invoke-WebRequest -Uri $DestUrl -UseBasicParsing -ErrorAction Stop
    }
    catch {
        # Attempt to parse JSON error response
        $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue

        if ($errorResponse) {
            $errorTitle = $errorResponse.title
            $errorStatus = $errorResponse.status
            if (-not $startmessage) {
                Write-Entry -Message "Starting SyncPlexArtwork for: $title" -Path $global:configLogging -Color White -log Info
            }
            Write-Entry -Subtext "Failed to retrieve destination image: Status: $errorStatus, Title: $errorTitle" -Path $global:configLogging -Color Red -log Error
        }
        else {
            if (-not $startmessage) {
                Write-Entry -Message "Starting SyncPlexArtwork for: $title" -Path $global:configLogging -Color White -log Info
            }
            Write-Entry -Subtext "Failed to retrieve destination image: Unknown error" -Path $global:configLogging -Color Red -log Error
        }

        return
    }


    if ($existingImageResponse.StatusCode -ne 200) {
        if (-not $startmessage) {
            Write-Entry -Message "Starting SyncPlexArtwork for: $title" -Path $global:configLogging -Color White -log Info
        }
        Write-Entry -Subtext "Unexpected response from destination ($(RedactMediaServerUrl -url $DestUrl)): $($existingImageResponse.StatusCode)" -Path $global:configLogging -Color Red -log Error
        return
    }

    $existingImageBytes = $existingImageResponse.Content
    if (-not $existingImageBytes) {
        Write-Entry -Subtext "Existing image content is empty!" -Path $global:configLogging -Color Yellow -log Warning
    }

    $existingImageHash = GetHash -imageBytes $existingImageBytes
    if ($remoteImageHash -eq $existingImageHash) {
        if ($show_skipped -eq 'true') {
            Write-Entry -Subtext "Image hashes match, skipping upload for $title" -Path $global:configLogging -Color White -log Info
        }
        Else {
            Write-Entry -Subtext "Image hashes match, skipping upload for $title" -Path $global:configLogging -Color White -log Debug
        }
        if ($DisableHashValidation -eq 'true') {
            Write-Entry -Subtext "Hash validation is disabled, proceeding with upload..." -Path $global:configLogging -Color Yellow -log Warning
        }
        else {
            return
        }
    }

    Write-Entry -Subtext "Uploading new artwork to Jelly/Emby for: $title" -Path $global:configLogging -Color White -log Info

    if ($imageType -eq 'Backdrop') {
        try {
            Write-Entry -Subtext "Deleting old artwork before upload..." -Path $global:configLogging -Color Yellow -log Info
            Invoke-RestMethod -Uri $DestUrl -Method Delete -ErrorAction Stop
            Write-Entry -Subtext "Successfully deleted old artwork." -Path $global:configLogging -Color Green -log Info
        }
        catch {
            # Attempt to parse JSON error response
            $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue

            if ($errorResponse) {
                $errorTitle = $errorResponse.title
                $errorStatus = $errorResponse.status

                Write-Entry -Subtext "Error deleting image: Status: $errorStatus, Title: $errorTitle" -Path $global:configLogging -Color Red -log Error
            }
            else {
                Write-Entry -Subtext "Error deleting image: Unknown error" -Path $global:configLogging -Color Red -log Error
            }
        }

    }

    try {
        $imageBase64 = [Convert]::ToBase64String($remoteImageBytes)
        $response = Invoke-RestMethod -Uri $DestUrl -Method Post -Body $imageBase64 -ContentType $remoteImageContentType -ErrorAction Stop
        Write-Entry -Subtext "Image uploaded successfully." -Path $global:configLogging -Color Green -log Info

        switch ($artworktype) {
            'poster' { $postercount++ }
            'tc' { $EpisodeCount++ }
            'background' { $BackgroundCount++ }
            'season' { $SeasonCount++ }
        }
        $UploadCount++
    }
    catch {
        # Attempt to parse JSON error response
        $message = $_.ErrorDetails.Message
        if ($message -match '^\s*\{.*\}\s*$') {
            $errorResponse = $message | ConvertFrom-Json -ErrorAction SilentlyContinue
        }

        if ($errorResponse) {
            $errorTitle = $errorResponse.title
            $errorStatus = $errorResponse.status

            Write-Entry -Subtext "Error uploading image: Status: $errorStatus, Title: $errorTitle" -Path $global:configLogging -Color Red -log Error
        }
        else {
            Write-Entry -Subtext "Error uploading image: $message" -Path $global:configLogging -Color Red -log Error
        }
    }

}
function Send-UptimeKumaWebhook {
    param (
        [string]$status,
        [string]$msg = "OK",
        [int]$ping = 0
    )

    $uri = $global:UptimeKumaUrl + "?status=$status&msg=$msg&ping=$ping"
    try {
        $null = Invoke-RestMethod -Uri $uri
        Write-Entry -Message "Uptime Kuma webhook sent: Status=$status, Msg=$msg, Ping=$ping" -Path $global:configLogging -Color White -log Info
    }
    catch {
        Write-Entry -Message "Failed to send Uptime Kuma webhook: $_" -Path $global:configLogging -Color Red -log Error
    }
}

function Write-TextSizeCacheSummary {
    param([string]$Label = "Text-size cache")
    $total = $script:tsHits + $script:tsMiss
    $rate = if ($total) { [math]::Round(100 * $script:tsHits / $total, 2) }else { 0 }
    $avg = if ($script:tsRuns) { [math]::Round($script:tsMs / $script:tsRuns, 2) }else { 0 }
    $saved = [TimeSpan]::FromMilliseconds([double]($script:tsHits * $avg))
    Write-Entry -Subtext ("{0}: hits='{1}', misses='{2}' ({3}%); magick_calls='{4}' in '{5} ms'; est_saved='{6}h {7}m {8}s'" -f `
            $Label, $script:tsHits, $script:tsMiss, $rate, $script:tsRuns, $script:tsMs, $saved.Hours, $saved.Minutes, $saved.Seconds) `
        -Path $global:configLogging -Color Green -log Info
}

function Send-SummaryNotification {
    param (
        [string]$ScriptMode,
        [string]$FormattedTimespawn,
        [int]$ErrorCount,
        [int]$FallbackCount,
        [int]$TextlessCount,
        [int]$TruncatedCount,
        [int]$PosterUnknownCount,
        [int]$SkipTBACount,
        [int]$SkipJapTitleCount,
        [int]$PosterCount,
        [int]$BackgroundCount,
        [int]$SeasonCount,
        [int]$EpisodeCount,
        [int]$ImagesCleared,
        [int]$PathsCleared,
        [string]$SavedSizeString,
        [int]$UploadCount,
        [int]$MatchedCount,
        [string]$LibName
    )

    if (-not ($global:NotifyUrl -and $global:SendNotification -eq 'true')) {
        return # Do nothing if notifications are off
    }

    # 1. Handle Apprise (Docker)
    if ($global:NotifyUrl -notlike '*discord*' -and $env:POWERSHELL_DISTRIBUTION_CHANNEL -like 'PSDocker*') {
        $body = "Run took: $FormattedTimespawn`nIt Created '$PosterCount' Images"

        if ($ScriptMode -eq 'backup') {
            $body = "Run took: $FormattedTimespawn`nIt Downloaded '$PosterCount' Images"
        }
        if ($ScriptMode -eq 'syncjelly' -or $ScriptMode -eq 'syncemby') {
            $body = "Run took: $FormattedTimespawn`nIt Synced '$UploadCount' Images"
        }
        if ($ScriptMode -eq 'logoupdater') {
            $body = "Run took: $FormattedTimespawn`nIt Matched '$MatchedCount' and Updated '$UploadCount' Logos"
        }

        if ($ErrorCount -ge '1') {
            apprise --notification-type="failure" --title="Posterizarr" --body="$body`n`nDuring execution '$ErrorCount' Errors occurred, please check log." "$global:NotifyUrl"
        }
        else {
            apprise --notification-type="success" --title="Posterizarr" --body="$body" "$global:NotifyUrl"
        }
        return
    }

    # 2. Handle Discord
    if ($global:NotifyUrl -like '*discord*') {

        $desc = "Run took: $FormattedTimespawn"
        if ($ScriptMode -eq 'backup') {
            $desc = "Backup Run took: $FormattedTimespawn"
        }
        if ($ScriptMode -eq 'syncjelly' -or $ScriptMode -eq 'syncemby') {
            $desc = "Sync Run took: $FormattedTimespawn"
        }
        if ($ScriptMode -eq 'testing') {
            $desc = "Test run took: $FormattedTimespawn"
        }
        if ($ScriptMode -eq 'tautulli' -or $ScriptMode -eq 'arr') {
            $desc = "Recently added Run took: $FormattedTimespawn"
        }
        if ($ScriptMode -eq 'logoupdater') {
            $desc = "Logo Updater Run took: $FormattedTimespawn`nOn Lib - $LibName"
        }

        if ($ErrorCount -ge '1') {
            $desc += "`nDuring execution Errors occurred, please check log."
        }

        # Build Fields
        $fieldList = [System.Collections.Generic.List[object]]::new()

        # Stats Section
        $fieldList.Add([PSCustomObject]@{ name = ""; value = ":bar_chart:"; inline = $false })
        if ($ScriptMode -eq 'testing') {
            $fieldList.Add([PSCustomObject]@{ name = "Truncated"; value = $TruncatedCount; inline = $false })
        }
        else {
            if ($ScriptMode -eq 'logoupdater') {
                $fieldList.Add([PSCustomObject]@{ name = "Errors"; value = $ErrorCount; inline = $false })
            }
            Else {
                $fieldList.Add([PSCustomObject]@{ name = "Errors"; value = $ErrorCount; inline = $false })
                $fieldList.Add([PSCustomObject]@{ name = "Fallbacks"; value = $FallbackCount; inline = $true })
                $fieldList.Add([PSCustomObject]@{ name = "Textless"; value = $TextlessCount; inline = $true })
                $fieldList.Add([PSCustomObject]@{ name = "Truncated"; value = $TruncatedCount; inline = $true })
                $fieldList.Add([PSCustomObject]@{ name = "Unknown"; value = $PosterUnknownCount; inline = $true })
                if ($SkipTBA -eq 'true' -or $SkipJapTitle -eq 'true') {
                    $fieldList.Add([PSCustomObject]@{ name = "TBA Skipped"; value = $SkipTBACount; inline = $true })
                    $fieldList.Add([PSCustomObject]@{ name = "Jap/Chinese Skipped"; value = $SkipJapTitleCount; inline = $true })
                }
            }
        }

        # Images / Logos Section
        $fieldList.Add([PSCustomObject]@{ name = ""; value = ":frame_photo:"; inline = $false })
        if ($ScriptMode -eq 'backup') {
            $fieldList.Add([PSCustomObject]@{ name = "Posters Downloaded"; value = ($PosterCount - $SeasonCount - $BackgroundCount - $EpisodeCount); inline = $false })
            $fieldList.Add([PSCustomObject]@{ name = "Backgrounds Downloaded"; value = $BackgroundCount; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "Seasons Downloaded"; value = $SeasonCount; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "TitleCards Downloaded"; value = $EpisodeCount; inline = $true })
        }
        elseif ($ScriptMode -eq 'syncjelly' -or $ScriptMode -eq 'syncemby') {
            $fieldList.Add([PSCustomObject]@{ name = "Posters Uploaded"; value = ($UploadCount - $SeasonCount - $BackgroundCount - $EpisodeCount); inline = $false })
            $fieldList.Add([PSCustomObject]@{ name = "Backgrounds Uploaded"; value = $BackgroundCount; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "Seasons Uploaded"; value = $SeasonCount; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "TitleCards Uploaded"; value = $EpisodeCount; inline = $true })
        }
        elseif ($ScriptMode -eq 'logoupdater') {
            $fieldList.Add([PSCustomObject]@{ name = "Logos Matched"; value = $MatchedCount; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "Logos Updated"; value = $UploadCount; inline = $true })
        }
        else {
            if ($ScriptMode -eq 'testing') {
                $fieldList.Add([PSCustomObject]@{ name = "Posters"; value = $posterscount; inline = $false })
            }
            else {
                # For Normal/Arr/Tautulli, $PosterCount IS the total, so subtraction is correct.
                $fieldList.Add([PSCustomObject]@{ name = "Posters"; value = ($PosterCount - $SeasonCount - $BackgroundCount - $EpisodeCount); inline = $false })
            }
            $fieldList.Add([PSCustomObject]@{ name = "Backgrounds"; value = $BackgroundCount; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "Seasons"; value = $SeasonCount; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "TitleCards"; value = $EpisodeCount; inline = $true })
        }

        # Cleanup Section
        if ($AssetCleanup -eq 'true' -and $ScriptMode -ne 'testing' -and $ScriptMode -ne 'backup' -and $ScriptMode -ne 'syncjelly' -and $ScriptMode -ne 'syncemby' -and $ScriptMode -ne 'logoupdater') {
            $fieldList.Add([PSCustomObject]@{ name = ""; value = ":recycle:"; inline = $false })
            $fieldList.Add([PSCustomObject]@{ name = "Images cleared"; value = $ImagesCleared; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "Folders Cleared"; value = $PathsCleared; inline = $true })
            $fieldList.Add([PSCustomObject]@{ name = "Space saved"; value = $SavedSizeString; inline = $true })
        }

        # Build final payload
        $payloadObject = [PSCustomObject]@{
            username   = $global:DiscordUserName
            avatar_url = "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/docs/images/webhook.png"
            content    = ""
            embeds     = @(
                [PSCustomObject]@{
                    author      = @{
                        name = "Posterizarr @Github"
                        url  = "https://github.com/fscorrupt/posterizarr"
                    }
                    description = $desc
                    timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    color       = $(if ($ErrorCount -ge '1') { 16711680 } Elseif ($Testing) { 8388736 } Elseif ($FallbackCount -gt '1' -or $PosterUnknownCount -ge '1' -or $TruncatedCount -gt '1') { 15120384 } Else { 5763719 })
                    fields      = $fieldList
                    thumbnail   = @{
                        url = "https://github.com/fscorrupt/posterizarr/raw/$($Branch)/docs/images/webhook.png"
                    }
                    footer      = @{
                        text = "$Platform  | vCurr: $CurrentScriptVersion | vNext: $LatestScriptVersion | IM vCurr: $global:CurrentImagemagickversion | IM vNext: $global:LatestImagemagickversion"
                    }
                }
            )
        }

        $jsonPayload = $payloadObject | ConvertTo-Json -Depth 6
        $webhookUrl = $global:NotifyUrl -replace '(?i)^discord://(?:[^@/]+@)?(.*)$', 'https://discord.com/api/webhooks/$1'
        Push-ObjectToDiscord -strDiscordWebhook $webhookUrl -objPayload $jsonPayload
    }
}

#### FUNCTION END ####

##### PRE-START #####
$global:errorCount = 0
# ---- text-size cache stats (minimal) ----
if (-not (Get-Variable -Name tsHits -Scope Script -ErrorAction SilentlyContinue)) { [int]  $script:tsHits = 0 }
if (-not (Get-Variable -Name tsMiss -Scope Script -ErrorAction SilentlyContinue)) { [int]  $script:tsMiss = 0 }
if (-not (Get-Variable -Name tsRuns -Scope Script -ErrorAction SilentlyContinue)) { [int]  $script:tsRuns = 0 }
if (-not (Get-Variable -Name tsMs   -Scope Script -ErrorAction SilentlyContinue)) { [int64]$script:tsMs = 0 }
# -----------------------------------------
function Invoke-MoviePosterCreation {
    param (
        $entry
    )
        try {
            if ($($entry.RootFoldername)) {
                # check if item has skip label
                if ($entry.labels -match 'skip_posterizarr') {
                    Write-Entry -Message "Skipping '$($entry.title)' because it has a skip label..." -Path $global:configLogging -Color Yellow -log Warning
                }
                Else {
                    $SkippingText = 'false'
                    $global:posterurl = $null
                    $global:ImageMagickError = $null
                    $global:TMDBfallbackposterurl = $null
                    $global:fanartfallbackposterurl = $null
                    $global:IsFallback = $null
                    $global:PlexartworkDownloaded = $null
                    $global:langCode = $null
                    $global:direction = $null

                    # Determine the language direction
                    $global:langCode = $entry.'Library Language'
                    $global:direction = $global:languageDirections[$global:langCode]

                    $cjkPattern = '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}\p{IsCyrillic}\p{IsDevanagari}\p{IsThai}\p{IsEthiopic}\p{IsGeorgian}\p{IsArmenian}\p{IsBengali}]'

                    if ($UseOriginalTitle -eq 'true') {
                        if ($entry.originalTitle -match $cjkPattern) {
                            $Titletext = $entry.title
                        }
                        else {
                            $Titletext = $entry.originalTitle
                        }
                    }
                    Else {
                        if ($entry.title -match $cjkPattern) {
                            $Titletext = $entry.originalTitle
                        }
                        else {
                            $Titletext = $entry.title
                        }
                    }

                    if ($LibraryFolders -eq 'true') {
                        $LibraryName = $entry.'Library Name'
                        if ($entry.extraFolder) {
                            $EntryDir = "$AssetPath\$LibraryName\$($entry.extraFolder)\$($entry.RootFoldername)"
                            $ManualEntryDir = "$ManualAssetPath\$LibraryName\$($entry.extraFolder)\$($entry.RootFoldername)"
                        }
                        Else {
                            $EntryDir = "$AssetPath\$LibraryName\$($entry.RootFoldername)"
                            $ManualEntryDir = "$ManualAssetPath\$LibraryName\$($entry.RootFoldername)"
                        }
                        $PosterImageoriginal = "$EntryDir\poster.jpg"
                        $TestPath = $EntryDir
                        $ManualTestPath = $ManualEntryDir
                        $Testfile = "poster"

                        if (!(Get-ChildItem -LiteralPath $EntryDir -ErrorAction SilentlyContinue)) {
                            New-Item -ItemType Directory -path $EntryDir -Force | out-null
                        }
                    }
                    Else {
                        if ($entry.extraFolder) {
                            $PosterImageoriginal = "$AssetPath\$($entry.extraFolder)\$($entry.RootFoldername).jpg"
                        }
                        Else {
                            $PosterImageoriginal = "$AssetPath\$($entry.RootFoldername).jpg"
                        }
                        $TestPath = $AssetPath
                        $ManualTestPath = $ManualPath
                        $Testfile = $($entry.RootFoldername)
                    }

                    if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                        $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                        $PosterImageoriginal = ($PosterImageoriginal).Replace('\', '/').Replace('./', '/')
                        $manualtestpath = ($ManualTestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                    }
                    else {
                        $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                        $fullManualTestPath = Resolve-Path -Path $ManualTestPath -ErrorAction SilentlyContinue
                        if ($fullTestPath) {
                            $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                            $Manualtestpath = ($fullManualTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                        }
                        Else {
                            $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                            $Manualtestpath = ($ManualTestPath + "\" + $Testfile).Replace('/', '\')
                        }
                    }
                    Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Manual Test Path is: $ManualTestPath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved Manual Test Path is: $Manualtestpath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved Manual Full Test Path is: $fullManualTestPath" -Path $global:configLogging -Color Cyan -log Debug
                    $PosterImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername).jpg"
                    $PosterImage = $PosterImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')

                    # Now we can start the Poster Part
                    if ($global:Posters -eq 'true') {
                        $checkedItems.Add($hashtestpath)
                        if (($null -ne $FileTestOnTrigger -and $FileTestOnTrigger -eq 'false') -or (-not $directoryHashtable.ContainsKey("$hashtestpath"))) {
                            # Define Global Variables
                            $SkippingText = 'false'
                            $global:tmdbid = $entry.tmdbid
                            $global:tvdbid = $entry.tvdbid
                            $global:imdbid = $entry.imdbid
                            $global:TextlessPoster = $null
                            $global:posterurl = $null
                            $global:PosterWithText = $null
                            $global:AssetTextLang = $null
                            $global:TMDBAssetTextLang = $null
                            $global:FANARTAssetTextLang = $null
                            $global:TVDBAssetTextLang = $null
                            $global:TMDBAssetChangeUrl = $null
                            $global:FANARTAssetChangeUrl = $null
                            $global:TVDBAssetChangeUrl = $null
                            $global:Fallback = $null
                            $global:IsFallback = $null
                            $global:ImageMagickError = $null
                            $TakeLocal = $null
                            $LocalAssetMissing = $null
                            $Arturl = $null
                            $LocalAddOverlay = $AddOverlay
                            $LocalAddBorder = $AddBorder

                            if ($entry.PlexPosterUrl -like "/library/*") {
                                if ($PlexToken) {
                                    $Arturl = $plexurl + $entry.PlexPosterUrl + "?X-Plex-Token=$PlexToken"
                                }
                                Else {
                                    $Arturl = $plexurl + $entry.PlexPosterUrl
                                }
                            }

                            foreach ($ext in $allowedExtensions) {
                                $filePath = "$ManualTestPath$ext"
                                if (Test-Path -LiteralPath $filePath) {
                                    Write-Entry -Message "Local file exists: $filePath" -Path $global:configLogging -Color Cyan -log Debug
                                    $posterext = $ext
                                    break
                                }
                            }

                            if ((Test-Path -LiteralPath "$($Manualtestpath)$posterext") -and $Manualtestpath -ne '\') {
                                Write-Entry -Message "Found Manual Poster for: $Titletext" -Path $global:configLogging -Color White -log Info
                                $TakeLocal = $true
                            }
                            Elseif ($global:DisableOnlineAssetFetch -eq 'true') {
                                $LocalAssetMissing = 'true'
                            }
                            Else {
                                Write-Entry -Message "Start Poster Search for: $Titletext" -Path $global:configLogging -Color White -log Info
                                switch -Wildcard ($global:FavProvider) {
                                    'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBMoviePoster }Else { Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartMoviePoster } }
                                    'FANART' { $global:posterurl = GetFanartMoviePoster }
                                    'TVDB' { if ($entry.tvdbid) { $global:posterurl = GetTVDBMoviePoster }Else { Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartMoviePoster } }
                                    'PLEX' { if ($ArtUrl) { GetPlexArtwork -Type ' a Movie Poster' -ArtUrl $Arturl -TempImage $PosterImage } }
                                    Default { $global:posterurl = GetFanartMoviePoster }
                                }
                                switch -Wildcard ($global:Fallback) {
                                    'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBMoviePoster } }
                                    'FANART' { $global:posterurl = GetFanartMoviePoster }
                                }
                                if ($global:PosterPreferTextless -eq $true) {
                                    if (!$global:TextlessPoster -and $global:fanartfallbackposterurl) {
                                        $global:posterurl = $global:fanartfallbackposterurl
                                        Write-Entry -Subtext "Took Fanart.tv Fallback poster because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                        $global:IsFallback = $true
                                    }
                                    if (!$global:TextlessPoster -and $global:TMDBfallbackposterurl) {
                                        $global:posterurl = $global:TMDBfallbackposterurl
                                        Write-Entry -Subtext "Took TMDB Fallback poster because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                        $global:IsFallback = $true
                                    }
                                    if (!$global:TextlessPoster -and $global:TVDBfallbackposterurl) {
                                        $global:posterurl = $global:TVDBfallbackposterurl
                                        Write-Entry -Subtext "Took TVDB Fallback poster because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                        $global:IsFallback = $true
                                    }
                                    if ($global:FavProvider -eq 'TVDB' -and !$global:posterurl) {
                                        if ($entry.tmdbid) {
                                            $global:posterurl = GetTMDBMoviePoster
                                            $global:IsFallback = $true
                                        }
                                        if (!$global:posterurl) {
                                            $global:posterurl = GetFanartMoviePoster
                                            $global:IsFallback = $true
                                        }
                                    }
                                }

                                if ($global:PosterOnlyTextless -and !$global:posterurl) {
                                    if ($global:FavProvider -eq 'TVDB') {
                                        if ($entry.tmdbid) {
                                            $global:posterurl = GetTMDBMoviePoster
                                            $global:IsFallback = $true
                                        }
                                        if (!$global:posterurl) {
                                            $global:posterurl = GetFanartMoviePoster
                                            $global:IsFallback = $true
                                        }
                                    }
                                    Elseif ($global:FavProvider -eq 'FANART') {
                                        if ($entry.tmdbid) {
                                            $global:posterurl = GetTMDBMoviePoster
                                            $global:IsFallback = $true
                                        }
                                        if (!$global:posterurl) {
                                            $global:posterurl = GetTVDBMoviePoster
                                            $global:IsFallback = $true
                                        }
                                    }
                                    Else {
                                        $global:posterurl = GetFanartMoviePoster
                                        if (!$global:FavProvider -eq 'FANART') {
                                            $global:IsFallback = $true
                                        }
                                        if (!$global:posterurl) {
                                            $global:posterurl = GetTVDBMoviePoster
                                            $global:IsFallback = $true
                                        }
                                    }
                                }

                                if (!$global:posterurl) {
                                    if ($global:FavProvider -ne 'TVDB' -and !$global:PosterOnlyTextless -and !$global:PosterPreferTextless) {
                                        $global:posterurl = GetTVDBMoviePoster
                                        $global:IsFallback = $true
                                    }
                                    if (!$global:posterurl -and !$global:PosterOnlyTextless) {
                                        if ($ArtUrl) {
                                            GetPlexArtwork -Type ' a Movie Poster' -ArtUrl $Arturl -TempImage $PosterImage
                                            $global:IsFallback = $true
                                        }
                                        Else {
                                            Write-Entry -Subtext "Plex Poster Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                        }
                                    }
                                    if (!$global:posterurl -and $global:imdbid -and !$global:PosterOnlyTextless) {
                                        Write-Entry -Subtext "Searching on IMDB for a movie poster" -Path $global:configLogging -Color Cyan -log Info
                                        $global:posterurl = GetIMDBPoster
                                        $global:IsFallback = $true
                                        if (!$global:posterurl) {
                                            Write-Entry -Subtext "Could not find a poster on any site" -Path $global:configLogging -Color Red -log Error
                                        }
                                    }
                                }
                            }
                            if ($fontAllCaps -eq 'true') {
                                $joinedTitle = $Titletext.ToUpper()
                            }
                            Else {
                                $joinedTitle = $Titletext
                            }
                            if ($global:posterurl -or $global:PlexartworkDownloaded -or $TakeLocal) {
                                if ($TakeLocal) {
                                    Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                        Copy-Item -LiteralPath $_.FullName -Destination $PosterImage | Out-Null
                                    }
                                    if ($SkipLocalPosterTextAdd -eq 'true') {
                                        $SkippingText = 'true'
                                    }
                                    Write-Entry -Subtext "Copy local asset to: $PosterImage" -Path $global:configLogging -Color Green -log Info
                                }
                                Else {
                                    try {
                                        if (!$global:PlexartworkDownloaded) {
                                            $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $PosterImage -ErrorAction Stop
                                        }
                                    }
                                    catch {
                                        if ($_.Exception.Response) {
                                            $statusCode = $_.Exception.Response.StatusCode.value__
                                        }
                                        else {
                                            $statusCode = $_.Exception.Message
                                        }
                                        Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                        $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                    }
                                    Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                    if ($global:posterurl -like 'https://image.tmdb.org*') {
                                        if ($global:PosterWithText) {
                                            Write-Entry -Subtext "Downloading Poster with Text from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TMDBAssetTextLang
                                        }
                                        Else {
                                            Write-Entry -Subtext "Downloading Textless Poster from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TMDBAssetTextLang
                                        }
                                        if ($global:FavProvider -ne 'TMDB') {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    elseif ($global:posterurl -like 'https://assets.fanart.tv*') {
                                        if ($global:PosterWithText) {
                                            Write-Entry -Subtext "Downloading Poster with Text from 'FANART'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:FANARTAssetTextLang
                                        }
                                        Else {
                                            Write-Entry -Subtext "Downloading Textless Poster from 'FANART'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:FANARTAssetTextLang
                                        }
                                        if ($global:FavProvider -ne 'FANART') {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    elseif ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                        if ($global:PosterWithText) {
                                            Write-Entry -Subtext "Downloading Poster with Text from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TVDBAssetTextLang
                                        }
                                        Else {
                                            Write-Entry -Subtext "Downloading Textless Poster from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TVDBAssetTextLang
                                        }
                                        if ($global:FavProvider -ne 'TVDB') {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    elseif ($global:posterurl -like "$PlexUrl*") {
                                        Write-Entry -Subtext "Downloading Poster from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        if ($global:FavProvider -ne 'PLEX') {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    Else {
                                        Write-Entry -Subtext "Downloading Poster from 'IMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:IsFallback = $true
                                    }
                                }
                                $global:IsTruncated = $null
                                if ($global:ImageProcessing -eq 'true') {
                                    Write-Entry -Subtext "Processing Poster for: `"$joinedTitle`"" -Path $global:configLogging -Color White -log Info
                                    $CommentArguments = "`"$PosterImage`" -set `"comment`" `"created with posterizarr`" `"$PosterImage`""
                                    $CommentlogEntry = "`"$magick`" $CommentArguments"
                                    $CommentlogEntry | Out-File $magickLog -Append
                                    InvokeMagickCommand -Command $magick -Arguments $CommentArguments
                                    if ($global:ImageMagickError -ne 'true') {
                                        if ($UsePosterResolutionOverlays -eq 'true') {
                                            switch ($entry.Resolution) {
                                                '4K DoVi/HDR10' { $Posteroverlay = $4KDoViHDR10 }
                                                '4K DoVi' { $Posteroverlay = $4KDoVi }
                                                '4K HDR10' { $Posteroverlay = $4KHDR10 }
                                                '4K' { $Posteroverlay = $4kposter }
                                                '1080p' { $Posteroverlay = $1080pPoster }
                                                Default { $Posteroverlay = $DefaultPosteroverlay }
                                            }
                                        }
                                        Else {
                                            $Posteroverlay = $DefaultPosteroverlay
                                        }
                                        # Logic for SkipAddTextAndOverlay (Skip Overlay, keep Border)
                                        if (($SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                            $LocalAddOverlay = 'false'
                                        }

                                        # Logic for SkipAddTextAndBorder (Skip Border, keep Overlay)
                                        if (($SkipAddTextAndBorder -eq 'true') -and $global:PosterWithText) {
                                            $LocalAddBorder = 'false'
                                        }

                                        # Logic for "If both are true, only resize"
                                        if ($SkipAddTextAndOverlay -eq 'true' -and $SkipAddTextAndBorder -eq 'true' -and $global:PosterWithText) {
                                            $LocalAddBorder = 'false'
                                            $LocalAddOverlay = 'false'
                                        }
                                        # Calculate the height to maintain the aspect ratio with a width of 1000 pixels
                                        if ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'true') {
                                            $Arguments = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$Posteroverlay`" -gravity south -quality $global:outputQuality -composite -shave `"$borderwidthsecond`"  -bordercolor `"$bordercolor`" -border `"$borderwidth`" `"$PosterImage`""
                                            Write-Entry -Subtext "Resizing it | Adding Borders | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                        }
                                        elseif ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'false') {
                                            $Arguments = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" -shave `"$borderwidthsecond`"  -bordercolor `"$bordercolor`" -border `"$borderwidth`" `"$PosterImage`""
                                            Write-Entry -Subtext "Resizing it | Adding Borders" -Path $global:configLogging -Color White -log Info
                                        }
                                        elseif ($LocalAddBorder -eq 'false' -and $LocalAddOverlay -eq 'true') {
                                            $Arguments = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$Posteroverlay`" -gravity south -quality $global:outputQuality -composite `"$PosterImage`""
                                            Write-Entry -Subtext "Resizing it | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                        }
                                        else {
                                            $Arguments = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$PosterImage`""
                                            Write-Entry -Subtext "Resizing it" -Path $global:configLogging -Color White -log Info
                                        }
                                        $logEntry = "`"$magick`" $Arguments"
                                        $logEntry | Out-File $magickLog -Append
                                        InvokeMagickCommand -Command $magick -Arguments $Arguments
                                        if (($SkipAddText -eq 'true' -or $SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                            $SkippingText = 'true'
                                            Write-Entry -Subtext "Skipping 'AddText' because poster already has text." -Path $global:configLogging -Color Yellow -log Info
                                        }
                                        # ONLY proceed with Logo or Text application if SkippingText is NOT true
                                        if ($SkippingText -ne 'true') {
                                            if ($UseLogo -eq 'true' -and ($global:UseClearlogo -eq 'true' -or $global:UseClearart -eq 'true')) {
                                                $ApplyTextInsteadOfLogo = $null
                                                $global:LogoUrl = $null
                                                $global:LogoLanguage = $null
                                                $allProviders = @('TMDB', 'FANART', 'TVDB')
                                                $searchOrder = @($global:FavProvider) + ($allProviders -ne $global:FavProvider)

                                                foreach ($provider in $searchOrder) {
                                                    if (-not [string]::IsNullOrEmpty($global:LogoUrl)) { break }
                                                    switch ($provider) {
                                                        'TMDB' { if ($entry.tmdbid) { $global:LogoUrl = GetTMDBLogo -Type movie } }
                                                        'FANART' { $global:LogoUrl = GetFanartLogo -Type movies }
                                                        'TVDB' { if ($entry.tvdbid) { $global:LogoUrl = GetTVDBLogo -Type movies } }
                                                    }
                                                }
                                                if (-not [string]::IsNullOrEmpty($global:LogoUrl)) {
                                                    $global:IsFallback = $false
                                                    switch ($global:FavProvider) {
                                                        'TMDB' {
                                                            if (-not ($global:LogoUrl.StartsWith("https://image.tmdb.org"))) {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        'TVDB' {
                                                            if (-not ($global:LogoUrl.StartsWith("https://artworks.thetvdb.com"))) {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        'FANART' {
                                                            if (-not ($global:LogoUrl.StartsWith("https://assets.fanart.tv"))) {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                    }
                                                    if ($global:IsFallback) {
                                                        Write-Entry -Subtext "Logo Source: Fallback (URL did not match $global:FavProvider)" -Path $global:configLogging -Color Yellow -log Debug
                                                    }
                                                }
                                                if ([string]::IsNullOrEmpty($global:LogoUrl)) {
                                                    Write-Entry -Subtext "Could not find a logo on any provider (Tried: $($searchOrder -join ', '))" -Path $global:configLogging -Color Yellow -log Warning
                                                }
                                                if (!$global:LogoUrl -and $TextFallback -eq 'true') {
                                                    $ApplyTextInsteadOfLogo = 'true'
                                                    Write-Entry -Subtext "Falling back to text as no logo was found." -Path $global:configLogging -Color Yellow -log Warning
                                                    $global:IsFallback = $true
                                                }
                                                ElseIf ($global:LogoUrl) {
                                                    $urlExtension = [System.IO.Path]::GetExtension($global:LogoUrl).Split('?')[0]
                                                    if ([string]::IsNullOrWhiteSpace($urlExtension)) { $urlExtension = ".png" }
                                                    $LogoImage = Join-Path $TempPath ("logo" + $urlExtension); Write-Entry -Message "Logo Used: $global:LogoUrl" -Path $global:configLogging -Color Cyan -log Debug
                                                    try {
                                                        $response = Invoke-WebRequest -Uri $global:LogoUrl -OutFile $LogoImage -ErrorAction Stop
                                                    }
                                                    catch {
                                                        if ($_.Exception.Response) {
                                                            $statusCode = $_.Exception.Response.StatusCode.value__
                                                        }
                                                        else {
                                                            $statusCode = $_.Exception.Message
                                                        }
                                                        Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                                        $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                    }
                                                    # Only apply color if enabled AND color is defined
                                                    $colorEffect = ""
                                                    if ($ConvertLogoColor -eq "true" -and -not [string]::IsNullOrWhiteSpace($LogoFlatColor)) {
                                                        $_chkLogo = if ($LogoImage -and (Test-Path $LogoImage)) { $LogoImage } elseif ($LogoSource -and (Test-Path $LogoSource)) { $LogoSource } else { $null }

                                                        $_chromaStd = if ($_chkLogo) { (& $magick $_chkLogo -trim +repage -background black -alpha remove -colorspace HCL -channel Green -separate -format "%[fx:standard_deviation]" info: 2>$null) } else { "0" }

                                                        if ([double]$_chromaStd -lt 0.25) { $colorEffect = "-fill `"$LogoFlatColor`" -colorize 100"; Write-Entry -Subtext "Converting logo to $LogoFlatColor (chroma:$([math]::Round([double]$_chromaStd,3)))..." -Path $global:configLogging -Color Cyan -log Info }

                                                        else { $colorEffect = ""; Write-Entry -Subtext "Logo multi-color (chroma:$([math]::Round([double]$_chromaStd,3))), keeping original" -Path $global:configLogging -Color Yellow -log Info }
                                                    }
                                                    if ($urlExtension -match "(?i)\.svg") {
                                                        Write-Entry -Subtext "Detected SVG. Applying High-Res settings." -Path $global:configLogging -Color Cyan -log Info
                                                        $Arguments = "`"$PosterImage`" ( -background none -density 300 `"$LogoImage`" $colorEffect -resize `"$boxsize`" `) -gravity `"$textgravity`" -geometry +0+`"$text_offset`" -quality $global:outputQuality -composite `"$PosterImage`""
                                                    }
                                                    else {
                                                        $Arguments = "`"$PosterImage`" ( -background none `"$LogoImage`" $colorEffect -resize `"$boxsize`" `) -gravity `"$textgravity`" -geometry +0+`"$text_offset`" -quality $global:outputQuality -composite `"$PosterImage`""
                                                    }
                                                    Write-Entry -Subtext "Applying Logo..." -Path $global:configLogging -Color White -log Info
                                                    $logEntry = "`"$magick`" $Arguments"
                                                    $logEntry | Out-File $magickLog -Append
                                                    InvokeMagickCommand -Command $magick -Arguments $Arguments

                                                    Remove-Item -LiteralPath $LogoImage -Force -ErrorAction SilentlyContinue | out-null
                                                }
                                            }
                                            if ($ApplyTextInsteadOfLogo -eq 'true' -or $UseLogo -eq 'false') {
                                                if ($AddText -eq 'true' -and $SkippingText -eq 'false') {
                                                    if ($global:direction -eq "RTL") {
                                                        $fontImagemagick = $RTLfontImagemagick
                                                    }
                                                    $joinedTitle = $joinedTitle -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                    $joinedTitle = $joinedTitle -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                    # Loop through each symbol and replace it with a newline
                                                    if ($NewLineOnSpecificSymbols -eq 'true') {
                                                        foreach ($symbol in $NewLineSymbols) {
                                                            # Replace the symbol with a newline
                                                            $replacementString = "`n"

                                                            # Check if the symbol should be kept
                                                            $keepThisSymbol = $false
                                                            if ($null -ne $SymbolsToKeepOnNewLine) {
                                                                # Loop through all items in $SymbolsToKeepOnNewLine (in case it's an array like [':', '!'])
                                                                foreach ($k in $SymbolsToKeepOnNewLine) {
                                                                    # Check if the $symbol (e.g., ": ") contains the $k character (e.g., ":")
                                                                    if ($symbol -like "*$k*") {
                                                                        $keepThisSymbol = $true
                                                                        break # Match found, no need to keep checking
                                                                    }
                                                                }
                                                            }

                                                            # If it's a "keep" symbol, change the replacement string
                                                            if ($keepThisSymbol) {
                                                                # Replace ": " with ": \n" (keeps the symbol, adds newline after)
                                                                $replacementString = $symbol + "`n"
                                                            }
                                                            $joinedTitle = $joinedTitle -replace [regex]::Escape($symbol), $replacementString
                                                        }
                                                    }
                                                    if ($NewLineOnSpecificWords -eq 'true' -and $null -ne $NewLineWords) {
                                                        $properties = $NewLineWords.PSObject.Properties.Name

                                                        # Check if properties exist and the list is not empty
                                                        if ($null -ne $properties -and $properties.Count -gt 0) {
                                                            foreach ($wordKey in $properties) {
                                                                $replacementValue = $NewLineWords.$wordKey

                                                                # Using [regex]::Escape handles any special characters in the word keys
                                                                $joinedTitle = $joinedTitle -replace [regex]::Escape($wordKey), $replacementValue
                                                            }
                                                        }
                                                    }
                                                    $joinedTitlePointSize = $joinedTitle -replace '""', '""""'
                                                    $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $fontImagemagick -box_width $MaxWidth  -box_height $MaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize -lineSpacing $lineSpacing

                                                    if ($global:IsTruncated -ne $true) {
                                                        Write-Entry -Subtext ("Optimal font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                        $cleanTitle = $joinedTitle -replace 'Â³', '' -replace 'Â²', ''
                                                        $cleanTitle = $joinedTitle -replace 'Â³', '' -replace 'Â²', ''
                                                        $supChar = if ($joinedTitle -match 'Â³') { "3" } elseif ($joinedTitle -match 'Â²') { "2" } else { "" }
                                                        $superSize = [int]($optimalFontSize * 0.55)
                                                        $yNudge = [int]($optimalFontSize * 0.3)
                                                        $gap = 20

                                                        if ($supChar -ne "" -and $AddTextStroke -eq 'true') {
                                                            # SUPERSCRIPT + STROKE MODE
                                                            $Arguments = "`"$PosterImage`" ( -background none " +
                                                            "( ( -font `"$fontImagemagick`" -pointsize $optimalFontSize -fill `"$strokecolor`" -stroke `"$strokecolor`" -strokewidth `"$strokewidth`" label:`"$cleanTitle`" ) " +
                                                            "( -font `"$fontImagemagick`" -pointsize $superSize -fill `"$strokecolor`" -stroke `"$strokecolor`" -strokewidth `"$strokewidth`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                            "( ( -font `"$fontImagemagick`" -pointsize $optimalFontSize -fill `"$fontcolor`" -stroke none label:`"$cleanTitle`" ) " +
                                                            "( -font `"$fontImagemagick`" -pointsize $superSize -fill `"$fontcolor`" -stroke none label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                            "-gravity center -composite ) -gravity south -geometry +0`"$text_offset`" -composite `"$PosterImage`""
                                                        }
                                                        elseif ($supChar -ne "") {
                                                            # SUPERSCRIPT ONLY MODE (No Stroke)
                                                            $Arguments = "`"$PosterImage`" ( -background none " +
                                                            "( -font `"$fontImagemagick`" -pointsize $optimalFontSize -fill `"$fontcolor`" label:`"$cleanTitle`" ) " +
                                                            "( -font `"$fontImagemagick`" -pointsize $superSize -fill `"$fontcolor`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap " +
                                                            ") -gravity south -geometry +0`"$text_offset`" -composite `"$PosterImage`""
                                                        }
                                                        else {
                                                            # STANDARD MODE (Normal caption logic)
                                                            if ($AddTextStroke -eq 'true') {
                                                                $Arguments = "`"$PosterImage`" -gravity center -background None -layers Flatten `( -size `"$boxsize`" -background none `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$strokecolor`" -stroke `"$strokecolor`" -strokewidth `"$strokewidth`" -size `"$boxsize`" -background none -interline-spacing `"$lineSpacing`" -gravity `"$textgravity`" caption:`"$joinedTitle`" `) `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$fontcolor`" -stroke none -size `"$boxsize`" -background none -interline-spacing `"$lineSpacing`" -gravity `"$textgravity`" caption:`"$joinedTitle`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$boxsize`" `) -gravity south -geometry +0`"$text_offset`" -quality $global:outputQuality -composite `"$PosterImage`""
                                                            }
                                                            Else {
                                                                $Arguments = "`"$PosterImage`" -gravity center -background None -layers Flatten ( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$fontcolor`" -size `"$boxsize`" -background none -interline-spacing `"$lineSpacing`" -gravity `"$textgravity`" caption:`"$joinedTitle`" -trim +repage -extent `"$boxsize`" ) -gravity south -geometry +0`"$text_offset`" -quality $global:outputQuality -composite `"$PosterImage`""
                                                            }
                                                        }

                                                        Write-Entry -Subtext "Applying Poster text: `"$joinedTitle`"" -Path $global:configLogging -Color White -log Info
                                                        $logEntry = "`"$magick`" $Arguments"
                                                        $logEntry | Out-File $magickLog -Append
                                                        InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                Else {
                                    $Resizeargument = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$PosterImage`""
                                    Write-Entry -Subtext "Resizing it... " -Path $global:configLogging -Color White -log Info
                                    $logEntry = "`"$magick`" $Resizeargument"
                                    $logEntry | Out-File $magickLog -Append
                                    InvokeMagickCommand -Command $magick -Arguments $Resizeargument
                                }
                                # Move file back to original naming with Brackets.
                                if ($global:ImageMagickError -ne 'true') {
                                    if (Get-ChildItem -LiteralPath $PosterImage -ErrorAction SilentlyContinue) {
                                        if ($global:IsTruncated -ne $true) {
                                            if ($Upload2Plex -eq 'true') {
                                                try {
                                                    Write-Entry -Subtext "Uploading Artwork to Plex..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                    $fileContent = [System.IO.File]::ReadAllBytes($PosterImage)
                                                    # Verify variables before uploading
                                                    Write-Entry -Subtext "PosterImage: $PosterImage" -Path $global:configLogging -Color Cyan -log Debug
                                                    Write-Entry -Subtext "RatingKey: $($entry.ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                                    Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                                    $uri = if ($PlexToken) {
                                                        "$PlexUrl/library/metadata/$($entry.ratingkey)/posters?X-Plex-Token=$PlexToken"
                                                    }
                                                    Else {
                                                        "$PlexUrl/library/metadata/$($entry.ratingkey)/posters"
                                                    }
                                                    Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                                    # Try uploading, capturing the response in detail
                                                    $Upload = Invoke-WebRequest -Uri $uri `
                                                        -Method Post `
                                                        -Headers $extraPlexHeaders `
                                                        -Body $fileContent `
                                                        -ContentType 'application/octet-stream' `
                                                        -SkipHttpErrorCheck `
                                                        -ErrorAction Stop

                                                    if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                                        Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                                        Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                                    }
                                                    else {
                                                        Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                                        Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                                    }
                                                }
                                                catch {
                                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                                    $global:errorCount++
                                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                }
                                            }
                                            try {
                                                # Attempt to move the item
                                                Move-Item -LiteralPath $PosterImage -Destination $PosterImageoriginal -Force -ErrorAction Stop

                                                # Log success if move was successful
                                                Write-Entry -Subtext "Added: $PosterImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                            }
                                            catch {
                                                # Log the error if the move operation fails
                                                Write-Entry -Subtext "Failed to move $PosterImage to $PosterImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                                Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                            }
                                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                            $posterCount++
                                        }
                                        Else {
                                            Write-Entry -Subtext "Skipping asset move because text is truncated..." -Path $global:configLogging -Color Yellow -log Warning
                                        }
                                        $movietemp = New-Object psobject
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $Titletext
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Movie'
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Language" -Value $(if ($TakeLocal) { "false" } Else { if (!$global:AssetTextLang) { "Textless" }Else { $global:AssetTextLang } })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Logo Source" -Value  $(if ($global:LogoUrl) { $global:LogoUrl } Else { "false" })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Logo Language" -Value $(if ($global:LogoLanguage) { $global:LogoLanguage } Else { "false" })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Logo TextFallback" -Value $(if ($ApplyTextInsteadOfLogo) { $ApplyTextInsteadOfLogo } Else { "false" })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value $(if ($global:IsFallback) { 'true' } else { 'false' })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value $(if ($TakeLocal) { $PosterImage } Else { $global:posterurl })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                        $movietemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                        switch -Wildcard ($global:FavProvider) {
                                            'TMDB' { $movietemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                            'FANART' { $movietemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                            'TVDB' { $movietemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                            Default { $movietemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                        }

                                        # Export the array to a CSV file
                                        $movietemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                                    }
                                }
                            }
                            Elseif ($LocalAssetMissing -eq 'true') {
                                Write-Entry -Subtext "Skipping [$Titletext] - local asset missing and online fetch is disabled." -Path $global:configLogging -Color Yellow -log Warning
                            }
                            Else {
                                Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                $movietemp = New-Object psobject
                                $movietemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $Titletext
                                $movietemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Movie'
                                $movietemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                $movietemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                $movietemp | Add-Member -MemberType NoteProperty -Name "Language" -Value 'false'
                                $movietemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value 'false'
                                $movietemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                $movietemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value 'false'
                                $movietemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                $movietemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                $movietemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                $movietemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                switch -Wildcard ($global:FavProvider) {
                                    'TMDB' { $movietemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                    'FANART' { $movietemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                    'TVDB' { $movietemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                    Default { $movietemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                }

                                # Export the array to a CSV file
                                $movietemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                            }
                        }
                        else {
                            if ($global:UploadExistingAssets -eq 'true') {
                                if ($entry.PlexPosterUrl -like "/library/*") {
                                    if ($PlexToken) {
                                        $Arturl = $plexurl + $entry.PlexPosterUrl + "?X-Plex-Token=$PlexToken"
                                    }
                                    Else {
                                        $Arturl = $plexurl + $entry.PlexPosterUrl
                                    }
                                }
                                Write-Entry -Message "Starting Existing Asset Upload..." -Path $global:configLogging -Color Green -log Info
                                try {
                                    GetPlexArtwork -Type "$Titletext Artwork." -ArtUrl $Arturl -TempImage $PosterImage
                                    if ($global:PlexartworkDownloaded -eq 'true') {
                                        Write-Entry -Subtext "Uploading Existing Artwork for: $Titletext" -Path $global:configLogging -Color White -log Info
                                        $fileContent = [System.IO.File]::ReadAllBytes($PosterImageoriginal)
                                        # Verify variables before uploading
                                        Write-Entry -Subtext "PosterImage: $PosterImageoriginal" -Path $global:configLogging -Color Cyan -log Debug
                                        Write-Entry -Subtext "RatingKey: $($entry.ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                        Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                        $uri = if ($PlexToken) {
                                            "$PlexUrl/library/metadata/$($entry.ratingkey)/posters?X-Plex-Token=$PlexToken"
                                        }
                                        Else {
                                            "$PlexUrl/library/metadata/$($entry.ratingkey)/posters"
                                        }
                                        Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                        # Try uploading, capturing the response in detail
                                        $Upload = Invoke-WebRequest -Uri $uri `
                                            -Method Post `
                                            -Headers $extraPlexHeaders `
                                            -Body $fileContent `
                                            -ContentType 'application/octet-stream' `
                                            -SkipHttpErrorCheck `
                                            -ErrorAction Stop

                                        if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                            Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                            Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                        }
                                        else {
                                            Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                            Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                        }
                                        $UploadCount++
                                    }
                                }
                                catch {
                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                    $global:errorCount++
                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                }
                                if (Test-Path $PosterImage -ErrorAction SilentlyContinue) {
                                    Remove-Item -LiteralPath $PosterImage | Out-Null
                                    Write-Entry -Message "Deleting Temp Image: $PosterImage" -Path $global:configLogging -Color White -log Info
                                }
                            }
                            Else {
                                if ($show_skipped -eq 'true' ) {
                                    Write-Entry -Subtext "Already exists: $PosterImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                                }
                            }
                        }
                    }
                    # Now we can start the Background Poster Part
                    if ($global:BackgroundPosters -eq 'true') {
                        if ($LibraryFolders -eq 'true') {
                            $LibraryName = $entry.'Library Name'
                            if ($entry.extraFolder) {
                                $EntryDir = "$AssetPath\$LibraryName\$($entry.extraFolder)\$($entry.RootFoldername)"
                                $ManualEntryDir = "$ManualAssetPath\$LibraryName\$($entry.extraFolder)\$($entry.RootFoldername)"
                            }
                            Else {
                                $EntryDir = "$AssetPath\$LibraryName\$($entry.RootFoldername)"
                                $ManualEntryDir = "$ManualAssetPath\$LibraryName\$($entry.RootFoldername)"
                            }
                            $backgroundImageoriginal = "$EntryDir\background.jpg"
                            $TestPath = $EntryDir
                            $ManualTestPath = $ManualEntryDir
                            $Testfile = "background"

                            if (!(Get-ChildItem -LiteralPath $EntryDir -ErrorAction SilentlyContinue)) {
                                New-Item -ItemType Directory -path $EntryDir -Force | out-null
                            }
                        }
                        Else {
                            if ($entry.extraFolder) {
                                $backgroundImageoriginal = "$AssetPath\$($entry.extraFolder)\$($entry.RootFoldername)_background.jpg"
                            }
                            Else {
                                $backgroundImageoriginal = "$AssetPath\$($entry.RootFoldername)_background.jpg"
                            }
                            $TestPath = $AssetPath
                            $ManualTestPath = $ManualPath
                            $Testfile = "$($entry.RootFoldername)_background"
                        }

                        if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                            $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                            $backgroundImageoriginal = ($backgroundImageoriginal).Replace('\', '/').Replace('./', '/')
                            $manualtestpath = ($ManualTestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                        }
                        else {
                            $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                            $fullManualTestPath = Resolve-Path -Path $ManualTestPath -ErrorAction SilentlyContinue
                            if ($fullTestPath) {
                                $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                                $Manualtestpath = ($fullManualTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                            }
                            Else {
                                $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                                $Manualtestpath = ($ManualTestPath + "\" + $Testfile).Replace('/', '\')
                            }
                        }

                        $backgroundImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername)_background.jpg"
                        $backgroundImage = $backgroundImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')
                        $checkedItems.Add($hashtestpath)
                        if (($null -ne $FileTestOnTrigger -and $FileTestOnTrigger -eq 'false') -or (-not $directoryHashtable.ContainsKey("$hashtestpath"))) {
                            # Define Global Variables
                            $SkippingText = 'false'
                            $global:tmdbid = $entry.tmdbid
                            $global:tvdbid = $entry.tvdbid
                            $global:imdbid = $entry.imdbid
                            $global:posterurl = $null
                            $global:PosterWithText = $null
                            $global:AssetTextLang = $null
                            $global:Fallback = $null
                            $global:IsFallback = $null
                            $global:TMDBAssetTextLang = $null
                            $global:FANARTAssetTextLang = $null
                            $global:TVDBAssetTextLang = $null
                            $global:TMDBAssetChangeUrl = $null
                            $global:FANARTAssetChangeUrl = $null
                            $global:TVDBAssetChangeUrl = $null
                            $global:ImageMagickError = $null
                            $global:TextlessPoster = $null
                            $global:TMDBfallbackposterurl = $null
                            $global:fanartfallbackposterurl = $null
                            $TakeLocal = $null
                            $LocalAssetMissing = $null
                            $Arturl = $null
                            $LocalAddOverlay = $AddBackgroundOverlay
                            $LocalAddBorder = $AddBackgroundBorder

                            if ($entry.PlexBackgroundUrl -like "/library/*") {
                                if ($PlexToken) {
                                    $Arturl = $plexurl + $entry.PlexBackgroundUrl + "?X-Plex-Token=$PlexToken"
                                }
                                Else {
                                    $Arturl = $plexurl + $entry.PlexBackgroundUrl
                                }
                            }

                            foreach ($ext in $allowedExtensions) {
                                $filePath = "$ManualTestPath$ext"
                                if (Test-Path -LiteralPath $filePath) {
                                    Write-Entry -Message "Local file exists: $filePath" -Path $global:configLogging -Color Cyan -log Debug
                                    $posterext = $ext
                                    break
                                }
                            }

                            if ((Test-Path -LiteralPath "$($Manualtestpath)$posterext") -and $Manualtestpath -ne '\') {
                                Write-Entry -Message "Found Manual Background for: $Titletext" -Path $global:configLogging -Color White -log Info
                                $TakeLocal = $true
                            }
                            Elseif ($global:DisableOnlineAssetFetch -eq 'true') {
                                $LocalAssetMissing = 'true'
                            }
                            Else {
                                Write-Entry -Message "Start Background Search for: $Titletext" -Path $global:configLogging -Color White -log Info
                                switch -Wildcard ($global:FavProvider) {
                                    'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBMovieBackground }Else { Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartMovieBackground } }
                                    'FANART' { $global:posterurl = GetFanartMovieBackground }
                                    'TVDB' { if ($entry.tvdbid) { $global:posterurl = GetTVDBMovieBackground }Else { Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartMovieBackground } }
                                    'PLEX' { if ($ArtUrl) { GetPlexArtwork -Type ' a Movie Background' -ArtUrl $Arturl -TempImage $backgroundImage } }
                                    Default { $global:posterurl = GetFanartMovieBackground }
                                }
                                switch -Wildcard ($global:Fallback) {
                                    'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBMovieBackground } }
                                    'FANART' { $global:posterurl = GetFanartMovieBackground }
                                }
                                if ($global:BackgroundPreferTextless -eq $true) {
                                    if (!$global:TextlessPoster -and $global:fanartfallbackposterurl) {
                                        $global:posterurl = $global:fanartfallbackposterurl
                                        Write-Entry -Subtext "Took Fanart.tv Fallback background because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                        $global:IsFallback = $true
                                    }
                                    if (!$global:TextlessPoster -and $global:TMDBfallbackposterurl) {
                                        $global:posterurl = $global:TMDBfallbackposterurl
                                        Write-Entry -Subtext "Took TMDB Fallback background because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                        $global:IsFallback = $true
                                    }
                                    if ($global:FavProvider -eq 'TVDB' -and !$global:posterurl) {
                                        if ($entry.tmdbid) {
                                            $global:posterurl = GetTMDBMovieBackground
                                            $global:IsFallback = $true
                                        }
                                        if (!$global:posterurl) {
                                            $global:posterurl = GetFanartMovieBackground
                                            $global:IsFallback = $true
                                        }
                                    }
                                }
                                if ($global:BackgroundOnlyTextless -and !$global:posterurl) {
                                    if ($global:FavProvider -eq 'TVDB') {
                                        if ($entry.tmdbid) {
                                            $global:posterurl = GetTMDBMovieBackground
                                            $global:IsFallback = $true
                                        }
                                        if (!$global:posterurl) {
                                            $global:posterurl = GetFanartMovieBackground
                                            $global:IsFallback = $true
                                        }
                                    }
                                    Else {
                                        $global:posterurl = GetFanartMovieBackground
                                        if (!$global:FavProvider -eq 'FANART') {
                                            $global:IsFallback = $true
                                        }
                                    }
                                }
                                if (!$global:posterurl) {
                                    if ($global:FavProvider -ne 'TVDB') {
                                        $global:posterurl = GetTVDBMovieBackground
                                        if ($global:posterurl) {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    if (!$global:posterurl) {
                                        if ($ArtUrl) {
                                            GetPlexArtwork -Type ' a Movie Background' -ArtUrl $Arturl -TempImage $backgroundImage
                                            if ($global:posterurl) {
                                                $global:IsFallback = $true
                                            }
                                        }
                                        Else {
                                            Write-Entry -Subtext "Plex Background Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                        }
                                        if (!$global:posterurl) {
                                            Write-Entry -Subtext "Could not find a Background on any site" -Path $global:configLogging -Color Red -log Error
                                        }
                                    }
                                }

                                if ($BackgroundfontAllCaps -eq 'true') {
                                    $joinedTitle = $Titletext.ToUpper()
                                }
                                Else {
                                    $joinedTitle = $Titletext
                                }
                            }
                            if ($global:posterurl -or $global:PlexartworkDownloaded -or $TakeLocal) {
                                if ($TakeLocal) {
                                    Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                        Copy-Item -LiteralPath $_.FullName -Destination $BackgroundImage | Out-Null
                                    }
                                    if ($SkipLocalBackgroundTextAdd -eq 'true') {
                                        $SkippingText = 'true'
                                    }
                                    Write-Entry -Subtext "Copy local asset to: $BackgroundImage" -Path $global:configLogging -Color Green -log Info
                                }
                                Else {
                                    try {
                                        if (!$global:PlexartworkDownloaded) {
                                            $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $BackgroundImage -ErrorAction Stop
                                        }
                                    }
                                    catch {
                                        if ($_.Exception.Response) {
                                            $statusCode = $_.Exception.Response.StatusCode.value__
                                        }
                                        else {
                                            $statusCode = $_.Exception.Message
                                        }
                                        Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                        $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                    }
                                    Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                    if ($global:posterurl -like 'https://image.tmdb.org*') {
                                        if ($global:PosterWithText) {
                                            Write-Entry -Subtext "Downloading background with Text from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TMDBAssetTextLang
                                        }
                                        Else {
                                            Write-Entry -Subtext "Downloading Textless background from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TMDBAssetTextLang
                                        }
                                        if ($global:FavProvider -ne 'TMDB') {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    elseif ($global:posterurl -like 'https://assets.fanart.tv*') {
                                        if ($global:PosterWithText) {
                                            Write-Entry -Subtext "Downloading background with Text from 'FANART'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:FANARTAssetTextLang
                                        }
                                        Else {
                                            Write-Entry -Subtext "Downloading Textless background from 'FANART'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:FANARTAssetTextLang
                                        }
                                        if ($global:FavProvider -ne 'FANART') {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    elseif ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                        if ($global:PosterWithText) {
                                            Write-Entry -Subtext "Downloading background with Text from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TVDBAssetTextLang
                                        }
                                        Else {
                                            Write-Entry -Subtext "Downloading Textless background from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TVDBAssetTextLang
                                        }
                                        if ($global:FavProvider -ne 'TVDB') {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    elseif ($global:posterurl -like "$PlexUrl*") {
                                        Write-Entry -Subtext "Downloading Background from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        if ($global:FavProvider -ne 'PLEX') {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    Else {
                                        Write-Entry -Subtext "Downloading background from 'IMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:IsFallback = $true
                                    }
                                }
                                $global:IsTruncated = $null
                                if ($global:ImageProcessing -eq 'true') {
                                    Write-Entry -Subtext "Processing background for: `"$joinedTitle`"" -Path $global:configLogging -Color White -log Info
                                    $CommentArguments = "`"$backgroundImage`" -set `"comment`" `"created with posterizarr`" `"$backgroundImage`""
                                    $CommentlogEntry = "`"$magick`" $CommentArguments"
                                    $CommentlogEntry | Out-File $magickLog -Append
                                    InvokeMagickCommand -Command $magick -Arguments $CommentArguments
                                    if ($global:ImageMagickError -ne 'true') {
                                        if ($UseBackgroundResolutionOverlays -eq 'true') {
                                            switch ($entry.Resolution) {
                                                '4K DoVi/HDR10' { $backgroundoverlay = $4KDoViHDR10Background }
                                                '4K DoVi' { $backgroundoverlay = $4KDoViBackground }
                                                '4K HDR10' { $backgroundoverlay = $4KHDR10Background }
                                                '4K' { $backgroundoverlay = $4kBackground }
                                                '1080p' { $backgroundoverlay = $1080pBackground }
                                                Default { $backgroundoverlay = $Defaultbackgroundoverlay }
                                            }
                                        }
                                        Else {
                                            $backgroundoverlay = $Defaultbackgroundoverlay
                                        }
                                        # Logic for SkipAddTextAndOverlay (Skip Overlay, keep Border)
                                        if (($SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                            $LocalAddOverlay = 'false'
                                        }

                                        # Logic for SkipAddTextAndBorder (Skip Border, keep Overlay)
                                        if (($SkipAddTextAndBorder -eq 'true') -and $global:PosterWithText) {
                                            $LocalAddBorder = 'false'
                                        }

                                        # Logic for "If both are true, only resize"
                                        if ($SkipAddTextAndOverlay -eq 'true' -and $SkipAddTextAndBorder -eq 'true' -and $global:PosterWithText) {
                                            $LocalAddBorder = 'false'
                                            $LocalAddOverlay = 'false'
                                        }
                                        # Calculate the height to maintain the aspect ratio with a width of 1000 pixels
                                        if ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'true') {
                                            $Arguments = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$backgroundoverlay`" -gravity south -quality $global:outputQuality -composite -shave `"$Backgroundborderwidthsecond`"  -bordercolor `"$Backgroundbordercolor`" -border `"$Backgroundborderwidth`" `"$backgroundImage`""
                                            Write-Entry -Subtext "Resizing it | Adding Borders | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                        }
                                        elseif ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'false') {
                                            $Arguments = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" -shave `"$Backgroundborderwidthsecond`"  -bordercolor `"$Backgroundbordercolor`" -border `"$Backgroundborderwidth`" `"$backgroundImage`""
                                            Write-Entry -Subtext "Resizing it | Adding Borders" -Path $global:configLogging -Color White -log Info
                                        }
                                        elseif ($LocalAddBorder -eq 'false' -and $LocalAddOverlay -eq 'true') {
                                            $Arguments = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$Backgroundoverlay`" -gravity south -quality $global:outputQuality -composite `"$backgroundImage`""
                                            Write-Entry -Subtext "Resizing it | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                        }
                                        else {
                                            $Arguments = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$backgroundImage`""
                                            Write-Entry -Subtext "Resizing it" -Path $global:configLogging -Color White -log Info
                                        }
                                        $logEntry = "`"$magick`" $Arguments"
                                        $logEntry | Out-File $magickLog -Append
                                        InvokeMagickCommand -Command $magick -Arguments $Arguments
                                        if (($SkipAddText -eq 'true' -or $SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                            $SkippingText = 'true'
                                            Write-Entry -Subtext "Skipping 'AddText' because poster already has text." -Path $global:configLogging -Color Yellow -log Info
                                        }
                                        # ONLY proceed with Logo or Text application if SkippingText is NOT true
                                        if ($SkippingText -ne 'true') {
                                            if ($UseBGLogo -eq 'true' -and ($global:UseClearlogo -eq 'true' -or $global:UseClearart -eq 'true')) {
                                                $ApplyTextInsteadOfLogo = $null
                                                $global:LogoUrl = $null
                                                $global:LogoLanguage = $null
                                                $allProviders = @('TMDB', 'FANART', 'TVDB')
                                                $searchOrder = @($global:FavProvider) + ($allProviders -ne $global:FavProvider)

                                                foreach ($provider in $searchOrder) {
                                                    if (-not [string]::IsNullOrEmpty($global:LogoUrl)) { break }
                                                    switch ($provider) {
                                                        'TMDB' { if ($entry.tmdbid) { $global:LogoUrl = GetTMDBLogo -Type movie } }
                                                        'FANART' { $global:LogoUrl = GetFanartLogo -Type movies }
                                                        'TVDB' { if ($entry.tvdbid) { $global:LogoUrl = GetTVDBLogo -Type movies } }
                                                    }
                                                }
                                                if (-not [string]::IsNullOrEmpty($global:LogoUrl)) {
                                                    $global:IsFallback = $false
                                                    switch ($global:FavProvider) {
                                                        'TMDB' {
                                                            if (-not ($global:LogoUrl.StartsWith("https://image.tmdb.org"))) {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        'TVDB' {
                                                            if (-not ($global:LogoUrl.StartsWith("https://artworks.thetvdb.com"))) {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        'FANART' {
                                                            if (-not ($global:LogoUrl.StartsWith("https://assets.fanart.tv"))) {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                    }
                                                    if ($global:IsFallback) {
                                                        Write-Entry -Subtext "Logo Source: Fallback (URL did not match $global:FavProvider)" -Path $global:configLogging -Color Yellow -log Debug
                                                    }
                                                }
                                                if ([string]::IsNullOrEmpty($global:LogoUrl)) {
                                                    Write-Entry -Subtext "Could not find a logo on any provider (Tried: $($searchOrder -join ', '))" -Path $global:configLogging -Color Yellow -log Warning
                                                }
                                                if (!$global:LogoUrl -and $TextFallback -eq 'true') {
                                                    $ApplyTextInsteadOfLogo = 'true'
                                                    Write-Entry -Subtext "Falling back to text as no logo was found." -Path $global:configLogging -Color Yellow -log Warning
                                                    $global:IsFallback = $true
                                                }
                                                ElseIf ($global:LogoUrl) {
                                                    $urlExtension = [System.IO.Path]::GetExtension($global:LogoUrl).Split('?')[0]
                                                    if ([string]::IsNullOrWhiteSpace($urlExtension)) { $urlExtension = ".png" }
                                                    $LogoImage = Join-Path $TempPath ("logo" + $urlExtension); Write-Entry -Message "Logo Used: $global:LogoUrl" -Path $global:configLogging -Color Cyan -log Debug
                                                    try {
                                                        $response = Invoke-WebRequest -Uri $global:LogoUrl -OutFile $LogoImage -ErrorAction Stop
                                                    }
                                                    catch {
                                                        if ($_.Exception.Response) {
                                                            $statusCode = $_.Exception.Response.StatusCode.value__
                                                        }
                                                        else {
                                                            $statusCode = $_.Exception.Message
                                                        }
                                                        Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                                        $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                    }
                                                    # Only apply color if enabled AND color is defined
                                                    $colorEffect = ""
                                                    if ($ConvertLogoColor -eq "true" -and -not [string]::IsNullOrWhiteSpace($LogoFlatColor)) {
                                                        $_chkLogo = if ($LogoImage -and (Test-Path $LogoImage)) { $LogoImage } elseif ($LogoSource -and (Test-Path $LogoSource)) { $LogoSource } else { $null }

                                                        $_chromaStd = if ($_chkLogo) { (& $magick $_chkLogo -trim +repage -background black -alpha remove -colorspace HCL -channel Green -separate -format "%[fx:standard_deviation]" info: 2>$null) } else { "0" }

                                                        if ([double]$_chromaStd -lt 0.25) { $colorEffect = "-fill `"$LogoFlatColor`" -colorize 100"; Write-Entry -Subtext "Converting logo to $LogoFlatColor (chroma:$([math]::Round([double]$_chromaStd,3)))..." -Path $global:configLogging -Color Cyan -log Info }

                                                        else { $colorEffect = ""; Write-Entry -Subtext "Logo multi-color (chroma:$([math]::Round([double]$_chromaStd,3))), keeping original" -Path $global:configLogging -Color Yellow -log Info }
                                                    }
                                                    if ($urlExtension -match "(?i)\.svg") {
                                                        Write-Entry -Subtext "Detected SVG. Applying High-Res settings." -Path $global:configLogging -Color Cyan -log Info
                                                        $Arguments = "`"$backgroundImage`" ( -background none -density 300 `"$LogoImage`" $colorEffect -resize `"$Backgroundboxsize`" `) -gravity `"$Backgroundtextgravity`" -geometry +0+`"$Backgroundtext_offset`" -quality $global:outputQuality -composite `"$backgroundImage`""
                                                    }
                                                    else {
                                                        $Arguments = "`"$backgroundImage`" ( -background none `"$LogoImage`" $colorEffect -resize `"$Backgroundboxsize`" `) -gravity `"$Backgroundtextgravity`" -geometry +0+`"$Backgroundtext_offset`" -quality $global:outputQuality -composite `"$backgroundImage`""
                                                    }
                                                    Write-Entry -Subtext "Applying Logo..." -Path $global:configLogging -Color White -log Info
                                                    $logEntry = "`"$magick`" $Arguments"
                                                    $logEntry | Out-File $magickLog -Append
                                                    InvokeMagickCommand -Command $magick -Arguments $Arguments

                                                    Remove-Item -LiteralPath $LogoImage -Force -ErrorAction SilentlyContinue | out-null
                                                }
                                            }
                                            if ($ApplyTextInsteadOfLogo -eq 'true' -or $UseBGLogo -eq 'false') {
                                                if ($AddBackgroundText -eq 'true' -and $SkippingText -eq 'false') {
                                                    if ($global:direction -eq "RTL") {
                                                        $backgroundfontImagemagick = $RTLfontImagemagick
                                                    }
                                                    $joinedTitle = $joinedTitle -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                    $joinedTitle = $joinedTitle -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                    # Loop through each symbol and replace it with a newline
                                                    if ($NewLineOnSpecificSymbols -eq 'true') {
                                                        foreach ($symbol in $NewLineSymbols) {
                                                            # Replace the symbol with a newline
                                                            $replacementString = "`n"

                                                            # Check if the symbol should be kept
                                                            $keepThisSymbol = $false
                                                            if ($null -ne $SymbolsToKeepOnNewLine) {
                                                                # Loop through all items in $SymbolsToKeepOnNewLine (in case it's an array like [':', '!'])
                                                                foreach ($k in $SymbolsToKeepOnNewLine) {
                                                                    # Check if the $symbol (e.g., ": ") contains the $k character (e.g., ":")
                                                                    if ($symbol -like "*$k*") {
                                                                        $keepThisSymbol = $true
                                                                        break # Match found, no need to keep checking
                                                                    }
                                                                }
                                                            }

                                                            # If it's a "keep" symbol, change the replacement string
                                                            if ($keepThisSymbol) {
                                                                # Replace ": " with ": \n" (keeps the symbol, adds newline after)
                                                                $replacementString = $symbol + "`n"
                                                            }
                                                            $joinedTitle = $joinedTitle -replace [regex]::Escape($symbol), $replacementString
                                                        }
                                                    }
                                                    if ($NewLineOnSpecificWords -eq 'true' -and $null -ne $NewLineWords) {
                                                        $properties = $NewLineWords.PSObject.Properties.Name

                                                        # Check if properties exist and the list is not empty
                                                        if ($null -ne $properties -and $properties.Count -gt 0) {
                                                            foreach ($wordKey in $properties) {
                                                                $replacementValue = $NewLineWords.$wordKey

                                                                # Using [regex]::Escape handles any special characters in the word keys
                                                                $joinedTitle = $joinedTitle -replace [regex]::Escape($wordKey), $replacementValue
                                                            }
                                                        }
                                                    }
                                                    $joinedTitlePointSize = $joinedTitle -replace '""', '""""'
                                                    $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $backgroundfontImagemagick -box_width $BackgroundMaxWidth  -box_height $BackgroundMaxHeight -min_pointsize $BackgroundminPointSize -max_pointsize $BackgroundmaxPointSize -lineSpacing $BackgroundlineSpacing
                                                    if ($global:IsTruncated -ne $true) {
                                                        Write-Entry -Subtext ("Optimal font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                        $cleanTitle = $joinedTitle -replace 'Â³', '' -replace 'Â²', ''
                                                        $cleanTitle = $joinedTitle -replace 'Â³', '' -replace 'Â²', ''
                                                        $supChar = if ($joinedTitle -match 'Â³') { "3" } elseif ($joinedTitle -match 'Â²') { "2" } else { "" }
                                                        $superSize = [int]($optimalFontSize * 0.55)
                                                        $yNudge = [int]($optimalFontSize * 0.3)
                                                        $gap = 20

                                                        if ($supChar -ne "" -and $AddTextStroke -eq 'true') {
                                                            # SUPERSCRIPT + STROKE MODE
                                                            $Arguments = "`"$backgroundImage`" ( -background none " +
                                                            "( ( -font `"$backgroundfontImagemagick`" -pointsize $optimalFontSize -fill `"$Backgroundstrokecolor`" -stroke `"$Backgroundstrokecolor`" -strokewidth `"$Backgroundstrokewidth`" label:`"$cleanTitle`" ) " +
                                                            "( -font `"$backgroundfontImagemagick`" -pointsize $superSize -fill `"$Backgroundstrokecolor`" -stroke `"$Backgroundstrokecolor`" -strokewidth `"$Backgroundstrokewidth`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                            "( ( -font `"$backgroundfontImagemagick`" -pointsize $optimalFontSize -fill `"$Backgroundfontcolor`" -stroke none label:`"$cleanTitle`" ) " +
                                                            "( -font `"$backgroundfontImagemagick`" -pointsize $superSize -fill `"$Backgroundfontcolor`" -stroke none label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                            "-gravity center -composite ) -gravity south -geometry +0`"$Backgroundtext_offset`" -composite `"$backgroundImage`""
                                                        }
                                                        elseif ($supChar -ne "") {
                                                            # SUPERSCRIPT ONLY MODE (No Stroke)
                                                            $Arguments = "`"$backgroundImage`" ( -background none " +
                                                            "( -font `"$backgroundfontImagemagick`" -pointsize $optimalFontSize -fill `"$Backgroundfontcolor`" label:`"$cleanTitle`" ) " +
                                                            "( -font `"$backgroundfontImagemagick`" -pointsize $superSize -fill `"$Backgroundfontcolor`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap " +
                                                            ") -gravity south -geometry +0`"$Backgroundtext_offset`" -composite `"$backgroundImage`""
                                                        }
                                                        else {
                                                            # STANDARD MODE (Normal caption logic)
                                                            if ($AddTextStroke -eq 'true') {
                                                                $Arguments = "`"$backgroundImage`" -gravity center -background None -layers Flatten `( -size `"$Backgroundboxsize`" -background none `( -font `"$backgroundfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Backgroundstrokecolor`" -stroke `"$Backgroundstrokecolor`" -strokewidth `"$Backgroundstrokewidth`" -size `"$Backgroundboxsize`" -background none -interline-spacing `"$BackgroundlineSpacing`" -gravity `"$Backgroundtextgravity`" caption:`"$joinedTitle`" `) `( -font `"$backgroundfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Backgroundfontcolor`" -stroke none -size `"$Backgroundboxsize`" -background none -interline-spacing `"$BackgroundlineSpacing`" -gravity `"$Backgroundtextgravity`" caption:`"$joinedTitle`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$Backgroundboxsize`" `) -gravity south -geometry +0`"$Backgroundtext_offset`" -quality $global:outputQuality -composite `"$backgroundImage`""
                                                            }
                                                            Else {
                                                                $Arguments = "`"$backgroundImage`" -gravity center -background None -layers Flatten ( -font `"$backgroundfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Backgroundfontcolor`" -size `"$Backgroundboxsize`" -background none -interline-spacing `"$BackgroundlineSpacing`" -gravity `"$Backgroundtextgravity`" caption:`"$joinedTitle`" -trim +repage -extent `"$Backgroundboxsize`" ) -gravity south -geometry +0`"$Backgroundtext_offset`" -quality $global:outputQuality -composite `"$backgroundImage`""
                                                            }
                                                        }

                                                        Write-Entry -Subtext "Applying Background text: `"$joinedTitle`"" -Path $global:configLogging -Color White -log Info
                                                        $logEntry = "`"$magick`" $Arguments"
                                                        $logEntry | Out-File $magickLog -Append
                                                        InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                Else {
                                    $Resizeargument = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$backgroundImage`""
                                    Write-Entry -Subtext "Resizing it... " -Path $global:configLogging -Color White -log Info
                                    $logEntry = "`"$magick`" $Resizeargument"
                                    $logEntry | Out-File $magickLog -Append
                                    InvokeMagickCommand -Command $magick -Arguments $Resizeargument
                                }
                                if ($global:ImageMagickError -ne 'true') {
                                    # Move file back to original naming with Brackets.
                                    if (Get-ChildItem -LiteralPath $backgroundImage -ErrorAction SilentlyContinue) {
                                        if ($global:IsTruncated -ne $true) {
                                            if ($Upload2Plex -eq 'true') {
                                                try {
                                                    Write-Entry -Subtext "Uploading Artwork to Plex..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                    $fileContent = [System.IO.File]::ReadAllBytes($backgroundImage)
                                                    # Verify variables before uploading
                                                    Write-Entry -Subtext "BackgroundImage: $backgroundImage" -Path $global:configLogging -Color Cyan -log Debug
                                                    Write-Entry -Subtext "RatingKey: $($entry.ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                                    Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                                    $uri = if ($PlexToken) {
                                                        "$PlexUrl/library/metadata/$($entry.ratingkey)/arts?X-Plex-Token=$PlexToken"
                                                    }
                                                    Else {
                                                        "$PlexUrl/library/metadata/$($entry.ratingkey)/arts"
                                                    }
                                                    Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                                    # Try uploading, capturing the response in detail
                                                    $Upload = Invoke-WebRequest -Uri $uri `
                                                        -Method Post `
                                                        -Headers $extraPlexHeaders `
                                                        -Body $fileContent `
                                                        -ContentType 'application/octet-stream' `
                                                        -SkipHttpErrorCheck `
                                                        -ErrorAction Stop

                                                    if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                                        Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                                        Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                                    }
                                                    else {
                                                        Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                                        Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                                    }
                                                }
                                                catch {
                                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                                    $global:errorCount++
                                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                }
                                            }
                                            try {
                                                # Attempt to move the item
                                                Move-Item -LiteralPath $backgroundImage -Destination $backgroundImageoriginal -Force -ErrorAction Stop

                                                # Log success if move was successful
                                                Write-Entry -Subtext "Added: $backgroundImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                            }
                                            catch {
                                                # Log the error if the move operation fails
                                                Write-Entry -Subtext "Failed to move $backgroundImage to $backgroundImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                                Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                            }
                                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                            $posterCount++
                                            $BackgroundCount++
                                        }
                                        Else {
                                            Write-Entry -Subtext "Skipping asset move because text is truncated..." -Path $global:configLogging -Color Yellow -log Warning
                                        }
                                        $moviebackgroundtemp = New-Object psobject
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $Titletext
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Movie Background'
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Language" -Value $(if ($TakeLocal) { "false" } Else { if (!$global:AssetTextLang) { "Textless" }Else { $global:AssetTextLang } })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Logo Source" -Value  $(if ($global:LogoUrl) { $global:LogoUrl } Else { "false" })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Logo Language" -Value $(if ($global:LogoLanguage) { $global:LogoLanguage } Else { "false" })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Logo TextFallback" -Value $(if ($ApplyTextInsteadOfLogo) { $ApplyTextInsteadOfLogo } Else { "false" })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value $(if ($global:IsFallback) { 'true' } else { 'false' })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value $(if ($TakeLocal) { $backgroundImage } Else { $global:posterurl })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                        $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                        switch -Wildcard ($global:FavProvider) {
                                            'TMDB' { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                            'FANART' { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                            'TVDB' { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                            Default { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                        }
                                        # Export the array to a CSV file
                                        $moviebackgroundtemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                                    }
                                }
                            }
                            Elseif ($LocalAssetMissing -eq 'true') {
                                Write-Entry -Subtext "Skipping [$Titletext] - local asset missing and online fetch is disabled." -Path $global:configLogging -Color Yellow -log Warning
                            }
                            Else {
                                Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                $moviebackgroundtemp = New-Object psobject
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $Titletext
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Movie Background'
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Language" -Value 'false'
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value 'false'
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value 'false'
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                switch -Wildcard ($global:FavProvider) {
                                    'TMDB' { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                    'FANART' { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                    'TVDB' { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                    Default { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                }

                                # Export the array to a CSV file
                                $moviebackgroundtemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                            }
                        }
                        else {
                            if ($global:UploadExistingAssets -eq 'true') {
                                if ($entry.PlexBackgroundUrl -like "/library/*") {
                                    if ($PlexToken) {
                                        $Arturl = $plexurl + $entry.PlexBackgroundUrl + "?X-Plex-Token=$PlexToken"
                                    }
                                    Else {
                                        $Arturl = $plexurl + $entry.PlexBackgroundUrl
                                    }
                                }
                                Write-Entry -Message "Starting Existing Asset Upload..." -Path $global:configLogging -Color Green -log Info
                                try {
                                    GetPlexArtwork -Type " $Titletext | Backgound Artwork." -ArtUrl $Arturl -TempImage $backgroundImage
                                    if ($global:PlexartworkDownloaded -eq 'true') {
                                        Write-Entry -Subtext "Uploading Existing Artwork for: $Titletext" -Path $global:configLogging -Color White -log Info
                                        $fileContent = [System.IO.File]::ReadAllBytes($backgroundImageoriginal)
                                        # Verify variables before uploading
                                        Write-Entry -Subtext "BackgroundImage: $backgroundImageoriginal" -Path $global:configLogging -Color Cyan -log Debug
                                        Write-Entry -Subtext "RatingKey: $($entry.ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                        Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                        $uri = if ($PlexToken) {
                                            "$PlexUrl/library/metadata/$($entry.ratingkey)/arts?X-Plex-Token=$PlexToken"
                                        }
                                        Else {
                                            "$PlexUrl/library/metadata/$($entry.ratingkey)/arts"
                                        }
                                        Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                        # Try uploading, capturing the response in detail
                                        $Upload = Invoke-WebRequest -Uri $uri `
                                            -Method Post `
                                            -Headers $extraPlexHeaders `
                                            -Body $fileContent `
                                            -ContentType 'application/octet-stream' `
                                            -SkipHttpErrorCheck `
                                            -ErrorAction Stop

                                        if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                            Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                            Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                        }
                                        else {
                                            Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                            Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                        }
                                        $UploadCount++
                                    }
                                }
                                catch {
                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                    $global:errorCount++
                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                }
                                if (Test-Path $backgroundImage -ErrorAction SilentlyContinue) {
                                    Remove-Item -LiteralPath $backgroundImage | Out-Null
                                    Write-Entry -Message "Deleting Temp Image: $backgroundImage" -Path $global:configLogging -Color White -log Info
                                }
                            }
                            Else {
                                if ($show_skipped -eq 'true' ) {
                                    Write-Entry -Subtext "Already exists: $backgroundImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                                }
                            }
                        }
                    }
                }
            }
            Else {
                Write-Entry -Message "Rootfolder value: $($entry.RootFoldername)" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Path value: $($entry.Path)" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Missing RootFolder for: $($entry.title) - you have to manually create the poster for it..." -Path $global:configLogging -Color Red -log Error
                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
        }
        catch {
            Write-Entry -Subtext "Could not query entries from movies array, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            write-Entry -Subtext "At line $($_.InvocationInfo.ScriptLineNumber)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
            if ($global:PosterOnlyTextless) {
                $moviebackgroundtemp = New-Object psobject
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $Titletext
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Movie Background'
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Language" -Value 'false'
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value 'false'
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value 'false'
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                switch -Wildcard ($global:FavProvider) {
                    'TMDB' { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                    'FANART' { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                    'TVDB' { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                    Default { $moviebackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                }

                # Export the array to a CSV file
                $moviebackgroundtemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
            }

        }
    }







function Invoke-ShowPosterCreation {
    param (
        $entry
    )

        if ($($entry.RootFoldername)) {
            # check if item has skip label
            if ($entry.labels -match 'skip_posterizarr') {
                Write-Entry -Message "Skipping '$($entry.title)' because it has a skip label..." -Path $global:configLogging -Color Yellow -log Warning
            }
            Else {
                # Define Global Variables
                $SkippingText = 'false'
                $global:tmdbsearched = $null
                $global:tmdbid = $entry.tmdbid
                $global:tvdbid = $entry.tvdbid
                $global:imdbid = $entry.imdbid
                $Seasonpostersearchtext = $null
                $global:ImageMagickError = $null
                $Episodepostersearchtext = $null
                $global:TMDBfallbackposterurl = $null
                $global:fanartfallbackposterurl = $null
                $FanartSearched = $null
                $global:plexalreadysearched = $null
                $global:posterurl = $null
                $global:PosterWithText = $null
                $global:AssetTextLang = $null
                $global:TMDBAssetTextLang = $null
                $global:FANARTAssetTextLang = $null
                $global:TVDBAssetTextLang = $null
                $global:TMDBAssetChangeUrl = $null
                $global:FANARTAssetChangeUrl = $null
                $global:TVDBAssetChangeUrl = $null
                $global:IsFallback = $null
                $global:FallbackText = $null
                $global:Fallback = $null
                $global:TextlessPoster = $null
                $global:tvdbalreadysearched = $null
                $global:PlexartworkDownloaded = $null
                $global:langCode = $null
                $global:direction = $null
                $TakeLocal = $null
                $LocalAssetMissing = $null
                $LocalAddOverlay = $AddOverlay
                $LocalAddBorder = $AddBorder

                # Determine the language direction
                $global:langCode = $entry.'Library Language'
                $global:direction = $global:languageDirections[$global:langCode]

                $cjkPattern = '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}\p{IsCyrillic}\p{IsDevanagari}\p{IsThai}\p{IsEthiopic}\p{IsGeorgian}\p{IsArmenian}\p{IsBengali}]'

                if ($UseOriginalTitle -eq 'true') {
                    if ($entry.originalTitle -match $cjkPattern) {
                        $Titletext = $entry.title
                    }
                    else {
                        $Titletext = $entry.originalTitle
                    }
                }
                Else {
                    if ($entry.title -match $cjkPattern) {
                        $Titletext = $entry.originalTitle
                    }
                    else {
                        $Titletext = $entry.title
                    }
                }

                if ($LibraryFolders -eq 'true') {
                    $LibraryName = $entry.'Library Name'
                    if ($entry.extraFolder) {
                        $EntryDir = "$AssetPath\$LibraryName\$($entry.extraFolder)\$($entry.RootFoldername)"
                        $ManualEntryDir = "$ManualAssetPath\$LibraryName\$($entry.extraFolder)\$($entry.RootFoldername)"
                    }
                    Else {
                        $EntryDir = "$AssetPath\$LibraryName\$($entry.RootFoldername)"
                        $ManualEntryDir = "$ManualAssetPath\$LibraryName\$($entry.RootFoldername)"
                    }
                    $PosterImageoriginal = "$EntryDir\poster.jpg"
                    $TestPath = $EntryDir
                    $ManualTestPath = $ManualEntryDir
                    $Testfile = "poster"

                    if (!(Get-ChildItem -LiteralPath $EntryDir -ErrorAction SilentlyContinue)) {
                        New-Item -ItemType Directory -path $EntryDir -Force | out-null
                    }
                }
                Else {
                    if ($entry.extraFolder) {
                        $PosterImageoriginal = "$AssetPath\$($entry.extraFolder)\$($entry.RootFoldername).jpg"
                    }
                    Else {
                        $PosterImageoriginal = "$AssetPath\$($entry.RootFoldername).jpg"
                    }
                    $TestPath = $AssetPath
                    $ManualTestPath = $ManualPath
                    $Testfile = $($entry.RootFoldername)
                }

                if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                    $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                    $PosterImageoriginal = ($PosterImageoriginal).Replace('\', '/').Replace('./', '/')
                    $manualtestpath = ($ManualTestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                }
                else {
                    $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                    $fullManualTestPath = Resolve-Path -Path $ManualTestPath -ErrorAction SilentlyContinue
                    if ($fullTestPath) {
                        $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                        $Manualtestpath = ($fullManualTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                    }
                    Else {
                        $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                        $Manualtestpath = ($ManualTestPath + "\" + $Testfile).Replace('/', '\')
                    }
                }

                Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Manual Test Path is: $ManualTestPath" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Resolved Manual Test Path is: $Manualtestpath" -Path $global:configLogging -Color Cyan -log Debug
                Write-Entry -Message "Resolved Manual Full Test Path is: $fullManualTestPath" -Path $global:configLogging -Color Cyan -log Debug

                $PosterImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername).jpg"
                $PosterImage = $PosterImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')

                # Now we can start the Poster Part
                if ($global:Posters -eq 'true') {
                    $checkedItems.Add($hashtestpath)
                    if (-not $directoryHashtable.ContainsKey("$hashtestpath")) {
                        $Arturl = $null
                        if ($entry.PlexPosterUrl -like "/library/*") {
                            if ($PlexToken) {
                                $Arturl = $plexurl + $entry.PlexPosterUrl + "?X-Plex-Token=$PlexToken"
                            }
                            Else {
                                $Arturl = $plexurl + $entry.PlexPosterUrl
                            }
                        }
                        foreach ($ext in $allowedExtensions) {
                            $filePath = "$ManualTestPath$ext"
                            if (Test-Path -LiteralPath $filePath) {
                                Write-Entry -Message "Local file exists: $filePath" -Path $global:configLogging -Color Cyan -log Debug
                                $posterext = $ext
                                break
                            }
                        }
                        if ((Test-Path -LiteralPath "$($Manualtestpath)$posterext") -and $Manualtestpath -ne '\') {
                            Write-Entry -Message "Found Manual Poster for: $Titletext" -Path $global:configLogging -Color White -log Info
                            $TakeLocal = $true
                        }
                        Elseif ($global:DisableOnlineAssetFetch -eq 'true') {
                            $LocalAssetMissing = 'true'
                        }
                        Else {
                            Write-Entry -Message "Start Poster Search for: $Titletext" -Path $global:configLogging -Color White -log Info
                            switch -Wildcard ($global:FavProvider) {
                                'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBShowPoster }Else { Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartShowPoster } }
                                'FANART' { $global:posterurl = GetFanartShowPoster }
                                'TVDB' { if ($entry.tvdbid) { $global:posterurl = GetTVDBShowPoster }Else { Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartShowPoster } }
                                'PLEX' { if ($ArtUrl) { GetPlexArtwork -Type ' a Show Poster' -ArtUrl $Arturl -TempImage $PosterImage } }
                                Default { $global:posterurl = GetFanartShowPoster }
                            }
                            if (!$global:posterurl) {
                                Write-Entry -Subtext "Could not find a poster on: $global:FavProvider" -Path $global:configLogging -Color White -log Info
                            }
                            switch -Wildcard ($global:Fallback) {
                                'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBShowPoster } Else { Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning } }
                                'FANART' { $global:posterurl = GetFanartShowPoster }
                            }
                            if ($global:PosterPreferTextless -eq $true) {
                                if (!$global:TextlessPoster -and $global:fanartfallbackposterurl) {
                                    $global:posterurl = $global:fanartfallbackposterurl
                                    Write-Entry -Subtext "Took Fanart.tv Fallback poster because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                    $global:IsFallback = $true
                                }
                                if (!$global:TextlessPoster -and $global:TMDBfallbackposterurl) {
                                    $global:posterurl = $global:TMDBfallbackposterurl
                                    Write-Entry -Subtext "Took TMDB Fallback poster because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                    $global:IsFallback = $true
                                }
                                if (!$global:TextlessPoster -and $global:TVDBfallbackposterurl) {
                                    $global:posterurl = $global:TVDBfallbackposterurl
                                    Write-Entry -Subtext "Took TVDB Fallback poster because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                    $global:IsFallback = $true
                                }
                                # try to find textless on TVDB
                                if ($global:TextlessPoster -ne 'true' -and $entry.tvdbid -and $global:FavProvider -ne 'TVDB') {
                                    $global:posterurl = GetTVDBShowPoster
                                    $global:IsFallback = $true
                                    $global:tvdbalreadysearched = $true
                                }
                                if ($global:FavProvider -eq 'TVDB' -and $global:TextlessPoster -ne 'true') {
                                    $global:posterurl = GetFanartMoviePoster
                                    $global:IsFallback = $true
                                }
                            }

                            if (!$global:TextlessPoster -eq 'true' -and $global:posterurl) {
                                $global:PosterWithText = $true
                            }

                            if (!$global:posterurl -and $global:tvdbalreadysearched -ne "True") {
                                $global:posterurl = GetTVDBShowPoster
                                $global:IsFallback = $true
                                if (!$global:posterurl -and !$global:TMDBfallbackposterurl -and !$global:fanartfallbackposterurl) {
                                    if ($ArtUrl -and !$global:PosterOnlyTextless) {
                                        GetPlexArtwork -Type ' a Show Poster' -ArtUrl $Arturl -TempImage $PosterImage
                                        $global:plexalreadysearched = $True
                                    }
                                    Else {
                                        Write-Entry -Subtext "Plex Poster Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                    }
                                    if (!$global:posterurl) {
                                        Write-Entry -Subtext "Could not find a poster on any site" -Path $global:configLogging -Color Red -log Error
                                    }
                                }
                            }
                            if (!$global:posterurl -and !$global:plexalreadysearched -eq 'true') {
                                $global:IsFallback = $true
                                if ($ArtUrl -and !$global:PosterOnlyTextless) {
                                    GetPlexArtwork -Type ' a Show Poster' -ArtUrl $Arturl -TempImage $PosterImage
                                    $global:plexalreadysearched = $True
                                }
                                Else {
                                    Write-Entry -Subtext "Plex Poster Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                }
                                if (!$global:posterurl) {
                                    Write-Entry -Subtext "Could not find a poster on any site" -Path $global:configLogging -Color Red -log Error
                                }
                            }
                            if (!$global:TextlessPoster -eq 'true' -and $global:TMDBfallbackposterurl) {
                                $global:posterurl = $global:TMDBfallbackposterurl
                            }
                            if (!$global:TextlessPoster -eq 'true' -and $global:fanartfallbackposterurl) {
                                $global:posterurl = $global:fanartfallbackposterurl
                            }
                        }
                        if ($fontAllCaps -eq 'true') {
                            $joinedTitle = $Titletext.ToUpper()
                        }
                        Else {
                            $joinedTitle = $Titletext
                        }
                        if ($global:posterurl -or $global:PlexartworkDownloaded -or $TakeLocal) {
                            if ($TakeLocal) {
                                Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                    Copy-Item -LiteralPath $_.FullName -Destination $PosterImage | Out-Null
                                }
                                if ($SkipLocalPosterTextAdd -eq 'true') {
                                    $SkippingText = 'true'
                                }
                                Write-Entry -Subtext "Copy local asset to: $PosterImage" -Path $global:configLogging -Color Green -log Info
                            }
                            Else {
                                try {
                                    if (!$global:PlexartworkDownloaded) {
                                        $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $PosterImage -ErrorAction Stop
                                    }
                                }
                                catch {
                                    if ($_.Exception.Response) {
                                        $statusCode = $_.Exception.Response.StatusCode.value__
                                    }
                                    else {
                                        $statusCode = $_.Exception.Message
                                    }
                                    Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                }
                                Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                if ($global:posterurl -like 'https://image.tmdb.org*') {
                                    if ($global:PosterWithText) {
                                        Write-Entry -Subtext "Downloading Poster with Text from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:TMDBAssetTextLang
                                    }
                                    Else {
                                        Write-Entry -Subtext "Downloading Textless Poster from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:TMDBAssetTextLang
                                    }
                                    if ($global:FavProvider -ne 'TMDB') {
                                        $global:IsFallback = $true
                                    }
                                }
                                elseif ($global:posterurl -like 'https://assets.fanart.tv*') {
                                    if ($global:PosterWithText) {
                                        Write-Entry -Subtext "Downloading Poster with Text from 'FANART'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:FANARTAssetTextLang
                                    }
                                    Else {
                                        Write-Entry -Subtext "Downloading Textless Poster from 'FANART'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:FANARTAssetTextLang
                                    }
                                    if ($global:FavProvider -ne 'Fanart') {
                                        $global:IsFallback = $true
                                    }
                                }
                                elseif ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                    if ($global:PosterWithText) {
                                        Write-Entry -Subtext "Downloading Poster with Text from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:TVDBAssetTextLang
                                    }
                                    Else {
                                        Write-Entry -Subtext "Downloading Textless Poster from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:TVDBAssetTextLang
                                    }
                                    if ($global:FavProvider -ne 'TVDB') {
                                        $global:IsFallback = $true
                                    }
                                }
                                elseif ($global:posterurl -like "$PlexUrl*") {
                                    Write-Entry -Subtext "Downloading Poster from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                    if ($global:FavProvider -ne 'PLEX') {
                                        $global:IsFallback = $true
                                    }
                                }
                                Else {
                                    Write-Entry -Subtext "Downloading Poster from 'IMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                    $global:IsFallback = $true
                                }
                            }
                            $global:IsTruncated = $null
                            if ($global:ImageProcessing -eq 'true') {
                                Write-Entry -Subtext "Processing Poster for: `"$joinedTitle`"" -Path $global:configLogging -Color White -log Info
                                $CommentArguments = "`"$PosterImage`" -set `"comment`" `"created with posterizarr`" `"$PosterImage`""
                                $CommentlogEntry = "`"$magick`" $CommentArguments"
                                $CommentlogEntry | Out-File $magickLog -Append
                                InvokeMagickCommand -Command $magick -Arguments $CommentArguments
                                if ($global:ImageMagickError -ne 'true') {
                                    if ($UsePosterResolutionOverlays -eq 'true') {
                                        switch ($entry.Resolution) {
                                            '4K DoVi/HDR10' { $Posteroverlay = $4KDoViHDR10 }
                                            '4K DoVi' { $Posteroverlay = $4KDoVi }
                                            '4K HDR10' { $Posteroverlay = $4KHDR10 }
                                            '4K' { $Posteroverlay = $4kposter }
                                            '1080p' { $Posteroverlay = $1080pPoster }
                                            Default { $Posteroverlay = $DefaultShowPosteroverlay }
                                        }
                                    }
                                    Else {
                                        $Posteroverlay = $DefaultShowPosteroverlay
                                    }
                                    # Logic for SkipAddTextAndOverlay (Skip Overlay, keep Border)
                                    if (($SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                        $LocalAddOverlay = 'false'
                                    }

                                    # Logic for SkipAddTextAndBorder (Skip Border, keep Overlay)
                                    if (($SkipAddTextAndBorder -eq 'true') -and $global:PosterWithText) {
                                        $LocalAddBorder = 'false'
                                    }

                                    # Logic for "If both are true, only resize"
                                    if ($SkipAddTextAndOverlay -eq 'true' -and $SkipAddTextAndBorder -eq 'true' -and $global:PosterWithText) {
                                        $LocalAddBorder = 'false'
                                        $LocalAddOverlay = 'false'
                                    }
                                    # Calculate the height to maintain the aspect ratio with a width of 1000 pixels
                                    if ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'true') {
                                        $Arguments = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$Posteroverlay`" -gravity south -quality $global:outputQuality -composite -shave `"$borderwidthsecond`"  -bordercolor `"$bordercolor`" -border `"$borderwidth`" `"$PosterImage`""
                                        Write-Entry -Subtext "Resizing it | Adding Borders | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                    }
                                    elseif ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'false') {
                                        $Arguments = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" -shave `"$borderwidthsecond`"  -bordercolor `"$bordercolor`" -border `"$borderwidth`" `"$PosterImage`""
                                        Write-Entry -Subtext "Resizing it | Adding Borders" -Path $global:configLogging -Color White -log Info
                                    }
                                    elseif ($LocalAddBorder -eq 'false' -and $LocalAddOverlay -eq 'true') {
                                        $Arguments = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$Posteroverlay`" -gravity south -quality $global:outputQuality -composite `"$PosterImage`""
                                        Write-Entry -Subtext "Resizing it | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                    }
                                    else {
                                        $Arguments = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$PosterImage`""
                                        Write-Entry -Subtext "Resizing it" -Path $global:configLogging -Color White -log Info
                                    }
                                    $logEntry = "`"$magick`" $Arguments"
                                    $logEntry | Out-File $magickLog -Append
                                    InvokeMagickCommand -Command $magick -Arguments $Arguments
                                    if (($SkipAddText -eq 'true' -or $SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                        $SkippingText = 'true'
                                        Write-Entry -Subtext "Skipping 'AddText' because poster already has text." -Path $global:configLogging -Color Yellow -log Info
                                    }
                                    # ONLY proceed with Logo or Text application if SkippingText is NOT true
                                    if ($SkippingText -ne 'true') {
                                        if ($UseLogo -eq 'true' -and ($global:UseClearlogo -eq 'true' -or $global:UseClearart -eq 'true')) {
                                            $ApplyTextInsteadOfLogo = $null
                                            $global:LogoUrl = $null
                                            $global:LogoLanguage = $null
                                            $allProviders = @('TMDB', 'FANART', 'TVDB')
                                            $searchOrder = @($global:FavProvider) + ($allProviders -ne $global:FavProvider)

                                            foreach ($provider in $searchOrder) {
                                                if (-not [string]::IsNullOrEmpty($global:LogoUrl)) { break }
                                                switch ($provider) {
                                                    'TMDB' { if ($entry.tmdbid) { $global:LogoUrl = GetTMDBLogo -Type tv } }
                                                    'FANART' { $global:LogoUrl = GetFanartLogo -Type tv }
                                                    'TVDB' { if ($entry.tvdbid) { $global:LogoUrl = GetTVDBLogo -Type series } }
                                                }
                                            }
                                            if (-not [string]::IsNullOrEmpty($global:LogoUrl)) {
                                                $global:IsFallback = $false
                                                switch ($global:FavProvider) {
                                                    'TMDB' {
                                                        if (-not ($global:LogoUrl.StartsWith("https://image.tmdb.org"))) {
                                                            $global:IsFallback = $true
                                                        }
                                                    }
                                                    'TVDB' {
                                                        if (-not ($global:LogoUrl.StartsWith("https://artworks.thetvdb.com"))) {
                                                            $global:IsFallback = $true
                                                        }
                                                    }
                                                    'FANART' {
                                                        if (-not ($global:LogoUrl.StartsWith("https://assets.fanart.tv"))) {
                                                            $global:IsFallback = $true
                                                        }
                                                    }
                                                }
                                                if ($global:IsFallback) {
                                                    Write-Entry -Subtext "Logo Source: Fallback (URL did not match $global:FavProvider)" -Path $global:configLogging -Color Yellow -log Debug
                                                }
                                            }
                                            if ([string]::IsNullOrEmpty($global:LogoUrl)) {
                                                Write-Entry -Subtext "Could not find a logo on any provider (Tried: $($searchOrder -join ', '))" -Path $global:configLogging -Color Yellow -log Warning
                                            }
                                            if (!$global:LogoUrl -and $TextFallback -eq 'true') {
                                                $ApplyTextInsteadOfLogo = 'true'
                                                Write-Entry -Subtext "Falling back to text as no logo was found." -Path $global:configLogging -Color Yellow -log Warning
                                                $global:IsFallback = $true
                                            }
                                            ElseIf ($global:LogoUrl) {
                                                $urlExtension = [System.IO.Path]::GetExtension($global:LogoUrl).Split('?')[0]
                                                if ([string]::IsNullOrWhiteSpace($urlExtension)) { $urlExtension = ".png" }
                                                $LogoImage = Join-Path $TempPath ("logo" + $urlExtension); Write-Entry -Message "Logo Used: $global:LogoUrl" -Path $global:configLogging -Color Cyan -log Debug
                                                try {
                                                    $response = Invoke-WebRequest -Uri $global:LogoUrl -OutFile $LogoImage -ErrorAction Stop
                                                }
                                                catch {
                                                    if ($_.Exception.Response) {
                                                        $statusCode = $_.Exception.Response.StatusCode.value__
                                                    }
                                                    else {
                                                        $statusCode = $_.Exception.Message
                                                    }
                                                    Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                }
                                                # Only apply color if enabled AND color is defined
                                                $colorEffect = ""
                                                if ($ConvertLogoColor -eq "true" -and -not [string]::IsNullOrWhiteSpace($LogoFlatColor)) {
                                                    $_chkLogo = if ($LogoImage -and (Test-Path $LogoImage)) { $LogoImage } elseif ($LogoSource -and (Test-Path $LogoSource)) { $LogoSource } else { $null }

                                                    $_chromaStd = if ($_chkLogo) { (& $magick $_chkLogo -trim +repage -background black -alpha remove -colorspace HCL -channel Green -separate -format "%[fx:standard_deviation]" info: 2>$null) } else { "0" }

                                                    if ([double]$_chromaStd -lt 0.25) { $colorEffect = "-fill `"$LogoFlatColor`" -colorize 100"; Write-Entry -Subtext "Converting logo to $LogoFlatColor (chroma:$([math]::Round([double]$_chromaStd,3)))..." -Path $global:configLogging -Color Cyan -log Info }

                                                    else { $colorEffect = ""; Write-Entry -Subtext "Logo multi-color (chroma:$([math]::Round([double]$_chromaStd,3))), keeping original" -Path $global:configLogging -Color Yellow -log Info }
                                                }
                                                if ($urlExtension -match "(?i)\.svg") {
                                                    Write-Entry -Subtext "Detected SVG. Applying High-Res settings." -Path $global:configLogging -Color Cyan -log Info
                                                    $Arguments = "`"$PosterImage`" ( -background none -density 300 `"$LogoImage`" $colorEffect -resize `"$boxsize`" `) -gravity `"$textgravity`" -geometry +0+`"$text_offset`" -quality $global:outputQuality -composite `"$PosterImage`""
                                                }
                                                else {
                                                    $Arguments = "`"$PosterImage`" ( -background none `"$LogoImage`" $colorEffect -resize `"$boxsize`" `) -gravity `"$textgravity`" -geometry +0+`"$text_offset`" -quality $global:outputQuality -composite `"$PosterImage`""
                                                }
                                                Write-Entry -Subtext "Applying Logo..." -Path $global:configLogging -Color White -log Info
                                                $logEntry = "`"$magick`" $Arguments"
                                                $logEntry | Out-File $magickLog -Append
                                                InvokeMagickCommand -Command $magick -Arguments $Arguments

                                                Remove-Item -LiteralPath $LogoImage -Force -ErrorAction SilentlyContinue | out-null
                                            }
                                        }
                                        if ($ApplyTextInsteadOfLogo -eq 'true' -or $UseLogo -eq 'false') {
                                            if ($AddText -eq 'true' -and $SkippingText -eq 'false') {
                                                if ($global:direction -eq "RTL") {
                                                    $fontImagemagick = $RTLfontImagemagick
                                                }
                                                $joinedTitle = $joinedTitle -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''

                                                # Loop through each symbol and replace it with a newline
                                                if ($NewLineOnSpecificSymbols -eq 'true') {
                                                    foreach ($symbol in $NewLineSymbols) {
                                                        # Replace the symbol with a newline
                                                        $replacementString = "`n"

                                                        # Check if the symbol should be kept
                                                        $keepThisSymbol = $false
                                                        if ($null -ne $SymbolsToKeepOnNewLine) {
                                                            # Loop through all items in $SymbolsToKeepOnNewLine (in case it's an array like [':', '!'])
                                                            foreach ($k in $SymbolsToKeepOnNewLine) {
                                                                # Check if the $symbol (e.g., ": ") contains the $k character (e.g., ":")
                                                                if ($symbol -like "*$k*") {
                                                                    $keepThisSymbol = $true
                                                                    break # Match found, no need to keep checking
                                                                }
                                                            }
                                                        }

                                                        # If it's a "keep" symbol, change the replacement string
                                                        if ($keepThisSymbol) {
                                                            # Replace ": " with ": \n" (keeps the symbol, adds newline after)
                                                            $replacementString = $symbol + "`n"
                                                        }
                                                        $joinedTitle = $joinedTitle -replace [regex]::Escape($symbol), $replacementString
                                                    }
                                                }
                                                if ($NewLineOnSpecificWords -eq 'true' -and $null -ne $NewLineWords) {
                                                    $properties = $NewLineWords.PSObject.Properties.Name

                                                    # Check if properties exist and the list is not empty
                                                    if ($null -ne $properties -and $properties.Count -gt 0) {
                                                        foreach ($wordKey in $properties) {
                                                            $replacementValue = $NewLineWords.$wordKey

                                                            # Using [regex]::Escape handles any special characters in the word keys
                                                            $joinedTitle = $joinedTitle -replace [regex]::Escape($wordKey), $replacementValue
                                                        }
                                                    }
                                                }
                                                $joinedTitlePointSize = $joinedTitle -replace '""', '""""'
                                                $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $fontImagemagick -box_width $MaxWidth  -box_height $MaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize -lineSpacing $lineSpacing
                                                if ($global:IsTruncated -ne $true) {
                                                    Write-Entry -Subtext ("Optimal font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                    $cleanTitle = $joinedTitle -replace 'Â³', '' -replace 'Â²', ''
                                                    $supChar = if ($joinedTitle -match 'Â³') { "3" } elseif ($joinedTitle -match 'Â²') { "2" } else { "" }

                                                    $superSize = [int]($optimalFontSize * 0.55)
                                                    $yNudge = [int]($optimalFontSize * 0.3)
                                                    $gap = 20

                                                    if ($supChar -ne "" -and $AddTextStroke -eq 'true') {
                                                        # SUPERSCRIPT + STROKE MODE
                                                        $Arguments = "`"$PosterImage`" ( -background none " +
                                                        "( ( -font `"$fontImagemagick`" -pointsize $optimalFontSize -fill `"$strokecolor`" -stroke `"$strokecolor`" -strokewidth `"$strokewidth`" label:`"$cleanTitle`" ) " +
                                                        "( -font `"$fontImagemagick`" -pointsize $superSize -fill `"$strokecolor`" -stroke `"$strokecolor`" -strokewidth `"$strokewidth`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                        "( ( -font `"$fontImagemagick`" -pointsize $optimalFontSize -fill `"$fontcolor`" -stroke none label:`"$cleanTitle`" ) " +
                                                        "( -font `"$fontImagemagick`" -pointsize $superSize -fill `"$fontcolor`" -stroke none label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                        "-gravity center -composite ) -gravity south -geometry +0`"$text_offset`" -composite `"$PosterImage`""
                                                    }
                                                    elseif ($supChar -ne "") {
                                                        # SUPERSCRIPT ONLY MODE (No Stroke)
                                                        $Arguments = "`"$PosterImage`" ( -background none " +
                                                        "( -font `"$fontImagemagick`" -pointsize $optimalFontSize -fill `"$fontcolor`" label:`"$cleanTitle`" ) " +
                                                        "( -font `"$fontImagemagick`" -pointsize $superSize -fill `"$fontcolor`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap " +
                                                        ") -gravity south -geometry +0`"$text_offset`" -composite `"$PosterImage`""
                                                    }
                                                    else {
                                                        # STANDARD MODE (Normal caption logic)
                                                        if ($AddTextStroke -eq 'true') {
                                                            $Arguments = "`"$PosterImage`" -gravity center -background None -layers Flatten `( -size `"$boxsize`" -background none `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$strokecolor`" -stroke `"$strokecolor`" -strokewidth `"$strokewidth`" -size `"$boxsize`" -background none -interline-spacing `"$lineSpacing`" -gravity `"$textgravity`" caption:`"$joinedTitle`" `) `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$fontcolor`" -stroke none -size `"$boxsize`" -background none -interline-spacing `"$lineSpacing`" -gravity `"$textgravity`" caption:`"$joinedTitle`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$boxsize`" `) -gravity south -geometry +0`"$text_offset`" -quality $global:outputQuality -composite `"$PosterImage`""
                                                        }
                                                        Else {
                                                            $Arguments = "`"$PosterImage`" -gravity center -background None -layers Flatten ( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$fontcolor`" -size `"$boxsize`" -background none -interline-spacing `"$lineSpacing`" -gravity `"$textgravity`" caption:`"$joinedTitle`" -trim +repage -extent `"$boxsize`" ) -gravity south -geometry +0`"$text_offset`" -quality $global:outputQuality -composite `"$PosterImage`""
                                                        }
                                                    }

                                                    Write-Entry -Subtext "Applying Poster text: `"$joinedTitle`"" -Path $global:configLogging -Color White -log Info
                                                    $logEntry = "`"$magick`" $Arguments"
                                                    $logEntry | Out-File $magickLog -Append
                                                    InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Else {
                                $Resizeargument = "`"$PosterImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$PosterImage`""
                                Write-Entry -Subtext "Resizing it... " -Path $global:configLogging -Color White -log Info
                                $logEntry = "`"$magick`" $Resizeargument"
                                $logEntry | Out-File $magickLog -Append
                                InvokeMagickCommand -Command $magick -Arguments $Resizeargument
                            }
                            if ($global:ImageMagickError -ne 'true') {
                                if (Get-ChildItem -LiteralPath $PosterImage -ErrorAction SilentlyContinue) {
                                    # Move file back to original naming with Brackets.
                                    if ($global:IsTruncated -ne $true) {
                                        if ($Upload2Plex -eq 'true') {
                                            try {
                                                Write-Entry -Subtext "Uploading Artwork to Plex..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                $fileContent = [System.IO.File]::ReadAllBytes($PosterImage)
                                                # Verify variables before uploading
                                                Write-Entry -Subtext "PosterImage: $PosterImage" -Path $global:configLogging -Color Cyan -log Debug
                                                Write-Entry -Subtext "RatingKey: $($entry.ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                                Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                                $uri = if ($PlexToken) {
                                                    "$PlexUrl/library/metadata/$($entry.ratingkey)/posters?X-Plex-Token=$PlexToken"
                                                }
                                                Else {
                                                    "$PlexUrl/library/metadata/$($entry.ratingkey)/posters"
                                                }
                                                Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                                # Try uploading, capturing the response in detail
                                                $Upload = Invoke-WebRequest -Uri $uri `
                                                    -Method Post `
                                                    -Headers $extraPlexHeaders `
                                                    -Body $fileContent `
                                                    -ContentType 'application/octet-stream' `
                                                    -SkipHttpErrorCheck `
                                                    -ErrorAction Stop

                                                if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                                    Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                                    Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                                }
                                                else {
                                                    Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                                    Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                                }
                                            }
                                            catch {
                                                Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                                $global:errorCount++
                                                Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                            }
                                        }
                                        try {
                                            # Attempt to move the item
                                            Move-Item -LiteralPath $PosterImage -Destination $PosterImageoriginal -Force -ErrorAction Stop

                                            # Log success if move was successful
                                            Write-Entry -Subtext "Added: $PosterImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                        }
                                        catch {
                                            # Log the error if the move operation fails
                                            Write-Entry -Subtext "Failed to move $PosterImage to $PosterImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                            Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                        }
                                        Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                        $posterCount++
                                    }
                                    Else {
                                        Write-Entry -Subtext "Skipping asset move because text is truncated..." -Path $global:configLogging -Color Yellow -log Warning
                                    }
                                    $showtemp = New-Object psobject
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $Titletext
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Show'
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Language" -Value $(if ($TakeLocal) { "false" } Else { if (!$global:AssetTextLang) { "Textless" }Else { $global:AssetTextLang } })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Logo Source" -Value  $(if ($global:LogoUrl) { $global:LogoUrl } Else { "false" })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Logo Language" -Value $(if ($global:LogoLanguage) { $global:LogoLanguage } Else { "false" })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Logo TextFallback" -Value $(if ($ApplyTextInsteadOfLogo) { $ApplyTextInsteadOfLogo } Else { "false" })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value $(if ($global:IsFallback) { 'true' } else { 'false' })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value $(if ($TakeLocal) { $PosterImage } Else { $global:posterurl })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                    $showtemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                    switch -Wildcard ($global:FavProvider) {
                                        'TMDB' { $showtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                        'FANART' { $showtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                        'TVDB' { $showtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                        Default { $showtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                    }
                                    # Export the array to a CSV file
                                    $showtemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                                }
                            }
                        }
                        Elseif ($LocalAssetMissing -eq 'true') {
                            Write-Entry -Subtext "Skipping [$Titletext] - local asset missing and online fetch is disabled." -Path $global:configLogging -Color Yellow -log Warning
                        }
                        Else {
                            Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                            $showtemp = New-Object psobject
                            $showtemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $Titletext
                            $showtemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Show'
                            $showtemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                            $showtemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                            $showtemp | Add-Member -MemberType NoteProperty -Name "Language" -Value 'false'
                            $showtemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value 'false'
                            $showtemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                            $showtemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value 'false'
                            $showtemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                            $showtemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                            $showtemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                            $showtemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                            switch -Wildcard ($global:FavProvider) {
                                'TMDB' { $showtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                'FANART' { $showtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                'TVDB' { $showtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                Default { $showtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                            }

                            # Export the array to a CSV file
                            $showtemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                        }
                    }
                    else {
                        if ($global:UploadExistingAssets -eq 'true') {
                            if ($entry.PlexPosterUrl -like "/library/*") {
                                if ($PlexToken) {
                                    $Arturl = $plexurl + $entry.PlexPosterUrl + "?X-Plex-Token=$PlexToken"
                                }
                                Else {
                                    $Arturl = $plexurl + $entry.PlexPosterUrl
                                }
                            }
                            Write-Entry -Message "Starting Existing Asset Upload..." -Path $global:configLogging -Color Green -log Info
                            try {
                                GetPlexArtwork -Type "$Titletext Artwork." -ArtUrl $Arturl -TempImage $PosterImage
                                if ($global:PlexartworkDownloaded -eq 'true') {
                                    Write-Entry -Subtext "Uploading Existing Artwork for: $Titletext" -Path $global:configLogging -Color White -log Info
                                    $fileContent = [System.IO.File]::ReadAllBytes($PosterImageoriginal)
                                    # Verify variables before uploading
                                    Write-Entry -Subtext "PosterImage: $PosterImageoriginal" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Subtext "RatingKey: $($entry.ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                    $uri = if ($PlexToken) {
                                        "$PlexUrl/library/metadata/$($entry.ratingkey)/posters?X-Plex-Token=$PlexToken"
                                    }
                                    Else {
                                        "$PlexUrl/library/metadata/$($entry.ratingkey)/posters"
                                    }
                                    Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                    # Try uploading, capturing the response in detail
                                    $Upload = Invoke-WebRequest -Uri $uri `
                                        -Method Post `
                                        -Headers $extraPlexHeaders `
                                        -Body $fileContent `
                                        -ContentType 'application/octet-stream' `
                                        -SkipHttpErrorCheck `
                                        -ErrorAction Stop

                                    if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                        Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                        Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                    }
                                    else {
                                        Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                        Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                    }
                                    $UploadCount++
                                }
                            }
                            catch {
                                Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                $global:errorCount++
                                Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                            }
                            if (Test-Path $PosterImage -ErrorAction SilentlyContinue) {
                                Remove-Item -LiteralPath $PosterImage | Out-Null
                                Write-Entry -Message "Deleting Temp Image: $PosterImage" -Path $global:configLogging -Color White -log Info
                            }
                        }
                        Else {
                            if ($show_skipped -eq 'true' ) {
                                Write-Entry -Subtext "Already exists: $PosterImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                            }
                        }
                    }
                }
                # Now we can start the Background Part
                if ($global:BackgroundPosters -eq 'true') {
                    if ($LibraryFolders -eq 'true') {
                        $LibraryName = $entry.'Library Name'
                        if ($entry.extraFolder) {
                            $EntryDir = "$AssetPath\$LibraryName\$($entry.extraFolder)\$($entry.RootFoldername)"
                            $ManualEntryDir = "$ManualAssetPath\$LibraryName\$($entry.extraFolder)\$($entry.RootFoldername)"
                        }
                        Else {
                            $EntryDir = "$AssetPath\$LibraryName\$($entry.RootFoldername)"
                            $ManualEntryDir = "$ManualAssetPath\$LibraryName\$($entry.RootFoldername)"
                        }
                        $backgroundImageoriginal = "$EntryDir\background.jpg"
                        $TestPath = $EntryDir
                        $ManualTestPath = $ManualEntryDir
                        $Testfile = "background"

                        if (!(Get-ChildItem -LiteralPath $EntryDir -ErrorAction SilentlyContinue)) {
                            New-Item -ItemType Directory -path $EntryDir -Force | out-null
                        }
                    }
                    Else {
                        if ($entry.extraFolder) {
                            $backgroundImageoriginal = "$AssetPath\$($entry.extraFolder)\$($entry.RootFoldername)_background.jpg"
                        }
                        Else {
                            $backgroundImageoriginal = "$AssetPath\$($entry.RootFoldername)_background.jpg"
                        }
                        $TestPath = $AssetPath
                        $ManualTestPath = $ManualPath
                        $Testfile = "$($entry.RootFoldername)_background"
                    }

                    if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                        $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                        $backgroundImageoriginal = ($backgroundImageoriginal).Replace('\', '/').Replace('./', '/')
                        $manualtestpath = ($ManualTestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                    }
                    else {
                        $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                        $fullManualTestPath = Resolve-Path -Path $ManualTestPath -ErrorAction SilentlyContinue
                        if ($fullTestPath) {
                            $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                            $Manualtestpath = ($fullManualTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                        }
                        Else {
                            $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                            $Manualtestpath = ($ManualTestPath + "\" + $Testfile).Replace('/', '\')
                        }
                    }

                    Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Manual Test Path is: $ManualTestPath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved Manual Test Path is: $Manualtestpath" -Path $global:configLogging -Color Cyan -log Debug
                    Write-Entry -Message "Resolved Manual Full Test Path is: $fullManualTestPath" -Path $global:configLogging -Color Cyan -log Debug

                    $backgroundImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername)_background.jpg"
                    $backgroundImage = $backgroundImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')
                    $checkedItems.Add($hashtestpath)

                    if (-not $directoryHashtable.ContainsKey("$hashtestpath")) {
                        # Define Global Variables
                        $SkippingText = 'false'
                        $global:tmdbid = $entry.tmdbid
                        $global:tvdbid = $entry.tvdbid
                        $global:imdbid = $entry.imdbid
                        $global:posterurl = $null
                        $global:PosterWithText = $null
                        $global:AssetTextLang = $null
                        $global:Fallback = $null
                        $global:IsFallback = $null
                        $global:FallbackText = $null
                        $global:TMDBAssetTextLang = $null
                        $global:FANARTAssetTextLang = $null
                        $global:TVDBAssetTextLang = $null
                        $global:TMDBAssetChangeUrl = $null
                        $global:FANARTAssetChangeUrl = $null
                        $global:TVDBAssetChangeUrl = $null
                        $global:TextlessPoster = $null
                        $global:ImageMagickError = $null
                        $global:TMDBfallbackposterurl = $null
                        $global:fanartfallbackposterurl = $null
                        $TakeLocal = $null
                        $LocalAssetMissing = $null
                        $Arturl = $null
                        $LocalAddOverlay = $AddBackgroundOverlay
                        $LocalAddBorder = $AddBackgroundBorder

                        if ($entry.PlexBackgroundUrl -like "/library/*") {
                            if ($PlexToken) {
                                $Arturl = $plexurl + $entry.PlexBackgroundUrl + "?X-Plex-Token=$PlexToken"
                            }
                            Else {
                                $Arturl = $plexurl + $entry.PlexBackgroundUrl
                            }
                        }

                        foreach ($ext in $allowedExtensions) {
                            $filePath = "$ManualTestPath$ext"
                            if (Test-Path -LiteralPath $filePath) {
                                Write-Entry -Message "Local file exists: $filePath" -Path $global:configLogging -Color Cyan -log Debug
                                $posterext = $ext
                                break
                            }
                        }
                        if ((Test-Path -LiteralPath "$($Manualtestpath)$posterext") -and $Manualtestpath -ne '\') {
                            Write-Entry -Message "Found Manual Background for: $Titletext" -Path $global:configLogging -Color White -log Info
                            $TakeLocal = $true
                        }
                        Elseif ($global:DisableOnlineAssetFetch -eq 'true') {
                            $LocalAssetMissing = 'true'
                        }
                        Else {
                            Write-Entry -Message "Start Background Search for: $Titletext" -Path $global:configLogging -Color White -log Info
                            switch -Wildcard ($global:FavProvider) {
                                'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBShowBackground }Else { Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartShowBackground } }
                                'FANART' { $global:posterurl = GetFanartShowBackground }
                                'TVDB' { if ($entry.tvdbid) { $global:posterurl = GetTVDBShowBackground }Else { Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartShowBackground } }
                                'PLEX' { if ($ArtUrl) { GetPlexArtwork -Type ' a Show Background' -ArtUrl $Arturl -TempImage $backgroundImage } }
                                Default { $global:posterurl = GetFanartShowBackground }
                            }
                            switch -Wildcard ($global:Fallback) {
                                'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBShowBackground } }
                                'FANART' { $global:posterurl = GetFanartShowBackground }
                            }
                            if ($global:BackgroundPreferTextless -eq $true) {
                                if (!$global:TextlessPoster -and $global:fanartfallbackposterurl) {
                                    $global:posterurl = $global:fanartfallbackposterurl
                                    Write-Entry -Subtext "Took Fanart.tv Fallback background because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                    $global:IsFallback = $true
                                }
                                if (!$global:TextlessPoster -and $global:TMDBfallbackposterurl) {
                                    $global:posterurl = $global:TMDBfallbackposterurl
                                    Write-Entry -Subtext "Took TMDB Fallback background because it is your Fav Provider" -Path $global:configLogging -Color Cyan -log Info
                                    $global:IsFallback = $true
                                }
                                if ($global:FavProvider -eq 'TVDB' -and !$global:posterurl) {
                                    if ($entry.tmdbid) {
                                        $global:posterurl = GetTMDBShowBackground
                                        if ($global:posterurl) {
                                            $global:IsFallback = $true
                                        }
                                        $global:FallbackText = 'True-Background'
                                    }
                                    if (!$global:posterurl) {
                                        $global:posterurl = GetFanartShowBackground
                                        if ($global:posterurl) {
                                            $global:IsFallback = $true
                                        }
                                        $global:FallbackText = 'True-Background'
                                    }
                                }
                            }
                            if ($global:BackgroundOnlyTextless -and !$global:posterurl) {
                                if ($global:FavProvider -eq 'TVDB') {
                                    if ($entry.tmdbid) {
                                        $global:posterurl = GetTMDBShowBackground
                                        $global:IsFallback = $true
                                        $global:FallbackText = 'True-Background'
                                    }
                                    if (!$global:posterurl) {
                                        $global:posterurl = GetFanartShowBackground
                                        $global:IsFallback = $true
                                        $global:FallbackText = 'True-Background'
                                    }
                                }
                                Else {
                                    $global:posterurl = GetFanartShowBackground
                                }
                            }
                            if (!$global:posterurl) {
                                if ($global:FavProvider -ne 'TVDB') {
                                    $global:posterurl = GetTVDBShowBackground
                                    if ($global:posterurl) {
                                        $global:IsFallback = $true
                                    }
                                }
                                $global:FallbackText = 'True-Background'
                                if (!$global:posterurl) {
                                    if ($ArtUrl) {
                                        GetPlexArtwork -Type ' a Show Background' -ArtUrl $Arturl -TempImage $backgroundImage
                                        if ($global:posterurl) {
                                            $global:IsFallback = $true
                                        }
                                    }
                                    Else {
                                        Write-Entry -Subtext "Plex Background Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                    }
                                    if (!$global:posterurl) {
                                        Write-Entry -Subtext "Could not find a background on any site" -Path $global:configLogging -Color Red -log Error
                                    }
                                }

                            }
                        }
                        if ($BackgroundfontAllCaps -eq 'true') {
                            $joinedTitle = $Titletext.ToUpper()
                        }
                        Else {
                            $joinedTitle = $Titletext
                        }
                        if ($global:posterurl -or $global:PlexartworkDownloaded -or $TakeLocal) {
                            if ($TakeLocal) {
                                Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                    Copy-Item -LiteralPath $_.FullName -Destination $BackgroundImage | Out-Null
                                }
                                if ($SkipLocalBackgroundTextAdd -eq 'true') {
                                    $SkippingText = 'true'
                                }
                                Write-Entry -Subtext "Copy local asset to: $BackgroundImage" -Path $global:configLogging -Color Green -log Info
                            }
                            Else {
                                try {
                                    if (!$global:PlexartworkDownloaded) {
                                        $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $BackgroundImage -ErrorAction Stop
                                    }
                                }
                                catch {
                                    if ($_.Exception.Response) {
                                        $statusCode = $_.Exception.Response.StatusCode.value__
                                    }
                                    else {
                                        $statusCode = $_.Exception.Message
                                    }
                                    Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                }
                                Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                if ($global:posterurl -like 'https://image.tmdb.org*') {
                                    if ($global:PosterWithText) {
                                        Write-Entry -Subtext "Downloading background with Text from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:TMDBAssetTextLang
                                    }
                                    Else {
                                        Write-Entry -Subtext "Downloading Textless background from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:TMDBAssetTextLang
                                    }
                                    if ($global:FavProvider -ne 'TMDB') {
                                        $global:IsFallback = $true
                                    }
                                }
                                elseif ($global:posterurl -like 'https://assets.fanart.tv*') {
                                    if ($global:PosterWithText) {
                                        Write-Entry -Subtext "Downloading background with Text from 'FANART'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:FANARTAssetTextLang
                                    }
                                    Else {
                                        Write-Entry -Subtext "Downloading Textless background from 'FANART'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:FANARTAssetTextLang
                                    }
                                    if ($global:FavProvider -ne 'FANART') {
                                        $global:IsFallback = $true
                                    }
                                }
                                elseif ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                    if ($global:PosterWithText) {
                                        Write-Entry -Subtext "Downloading background with Text from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:TVDBAssetTextLang
                                    }
                                    Else {
                                        Write-Entry -Subtext "Downloading Textless background from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                        $global:AssetTextLang = $global:TVDBAssetTextLang
                                    }
                                    if ($global:FavProvider -ne 'TVDB') {
                                        $global:IsFallback = $true
                                    }
                                }
                                elseif ($global:posterurl -like "$PlexUrl*") {
                                    Write-Entry -Subtext "Downloading Background from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                    if ($global:FavProvider -ne 'PLEX') {
                                        $global:IsFallback = $true
                                    }
                                }
                                Else {
                                    Write-Entry -Subtext "Downloading background from 'IMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                    $global:IsFallback = $true
                                }
                            }
                            $global:IsTruncated = $null
                            if ($global:ImageProcessing -eq 'true') {
                                Write-Entry -Subtext "Processing background for: `"$joinedTitle`"" -Path $global:configLogging -Color White -log Info
                                $CommentArguments = "`"$backgroundImage`" -set `"comment`" `"created with posterizarr`" `"$backgroundImage`""
                                $CommentlogEntry = "`"$magick`" $CommentArguments"
                                $CommentlogEntry | Out-File $magickLog -Append
                                InvokeMagickCommand -Command $magick -Arguments $CommentArguments
                                if ($global:ImageMagickError -ne 'true') {
                                    if ($UseBackgroundResolutionOverlays -eq 'true') {
                                        switch ($entry.Resolution) {
                                            '4K DoVi/HDR10' { $backgroundoverlay = $4KDoViHDR10Background }
                                            '4K DoVi' { $backgroundoverlay = $4KDoViBackground }
                                            '4K HDR10' { $backgroundoverlay = $4KHDR10Background }
                                            '4K' { $backgroundoverlay = $4kBackground }
                                            '1080p' { $backgroundoverlay = $1080pBackground }
                                            Default { $backgroundoverlay = $DefaultShowBackgroundoverlay }
                                        }
                                    }
                                    Else {
                                        $backgroundoverlay = $DefaultShowBackgroundoverlay
                                    }
                                    # Logic for SkipAddTextAndOverlay (Skip Overlay, keep Border)
                                    if (($SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                        $LocalAddOverlay = 'false'
                                    }

                                    # Logic for SkipAddTextAndBorder (Skip Border, keep Overlay)
                                    if (($SkipAddTextAndBorder -eq 'true') -and $global:PosterWithText) {
                                        $LocalAddBorder = 'false'
                                    }

                                    # Logic for "If both are true, only resize"
                                    if ($SkipAddTextAndOverlay -eq 'true' -and $SkipAddTextAndBorder -eq 'true' -and $global:PosterWithText) {
                                        $LocalAddBorder = 'false'
                                        $LocalAddOverlay = 'false'
                                    }
                                    # Calculate the height to maintain the aspect ratio with a width of 1000 pixels
                                    if ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'true') {
                                        $Arguments = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$Backgroundoverlay`" -gravity south -quality $global:outputQuality -composite -shave `"$Backgroundborderwidthsecond`"  -bordercolor `"$Backgroundbordercolor`" -border `"$Backgroundborderwidth`" `"$backgroundImage`""
                                        Write-Entry -Subtext "Resizing it | Adding Borders | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                    }
                                    elseif ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'false') {
                                        $Arguments = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" -shave `"$Backgroundborderwidthsecond`"  -bordercolor `"$Backgroundbordercolor`" -border `"$Backgroundborderwidth`" `"$backgroundImage`""
                                        Write-Entry -Subtext "Resizing it | Adding Borders" -Path $global:configLogging -Color White -log Info
                                    }
                                    elseif ($LocalAddBorder -eq 'false' -and $LocalAddOverlay -eq 'true') {
                                        $Arguments = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$Backgroundoverlay`" -gravity south -quality $global:outputQuality -composite `"$backgroundImage`""
                                        Write-Entry -Subtext "Resizing it | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                    }
                                    else {
                                        $Arguments = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$backgroundImage`""
                                        Write-Entry -Subtext "Resizing it" -Path $global:configLogging -Color White -log Info
                                    }
                                    $logEntry = "`"$magick`" $Arguments"
                                    $logEntry | Out-File $magickLog -Append
                                    InvokeMagickCommand -Command $magick -Arguments $Arguments
                                    if (($SkipAddText -eq 'true' -or $SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                        $SkippingText = 'true'
                                        Write-Entry -Subtext "Skipping 'AddText' because poster already has text." -Path $global:configLogging -Color Yellow -log Info
                                    }
                                    # ONLY proceed with Logo or Text application if SkippingText is NOT true
                                    if ($SkippingText -ne 'true') {
                                        if ($UseBGLogo -eq 'true' -and ($global:UseClearlogo -eq 'true' -or $global:UseClearart -eq 'true')) {
                                            $ApplyTextInsteadOfLogo = $null
                                            $global:LogoUrl = $null
                                            $global:LogoLanguage = $null
                                            $allProviders = @('TMDB', 'FANART', 'TVDB')
                                            $searchOrder = @($global:FavProvider) + ($allProviders -ne $global:FavProvider)

                                            foreach ($provider in $searchOrder) {
                                                if (-not [string]::IsNullOrEmpty($global:LogoUrl)) { break }
                                                switch ($provider) {
                                                    'TMDB' { if ($entry.tmdbid) { $global:LogoUrl = GetTMDBLogo -Type tv } }
                                                    'FANART' { $global:LogoUrl = GetFanartLogo -Type tv }
                                                    'TVDB' { if ($entry.tvdbid) { $global:LogoUrl = GetTVDBLogo -Type series } }
                                                }
                                            }
                                            if (-not [string]::IsNullOrEmpty($global:LogoUrl)) {
                                                $global:IsFallback = $false
                                                switch ($global:FavProvider) {
                                                    'TMDB' {
                                                        if (-not ($global:LogoUrl.StartsWith("https://image.tmdb.org"))) {
                                                            $global:IsFallback = $true
                                                        }
                                                    }
                                                    'TVDB' {
                                                        if (-not ($global:LogoUrl.StartsWith("https://artworks.thetvdb.com"))) {
                                                            $global:IsFallback = $true
                                                        }
                                                    }
                                                    'FANART' {
                                                        if (-not ($global:LogoUrl.StartsWith("https://assets.fanart.tv"))) {
                                                            $global:IsFallback = $true
                                                        }
                                                    }
                                                }
                                                if ($global:IsFallback) {
                                                    Write-Entry -Subtext "Logo Source: Fallback (URL did not match $global:FavProvider)" -Path $global:configLogging -Color Yellow -log Debug
                                                }
                                            }
                                            if ([string]::IsNullOrEmpty($global:LogoUrl)) {
                                                Write-Entry -Subtext "Could not find a logo on any provider (Tried: $($searchOrder -join ', '))" -Path $global:configLogging -Color Yellow -log Warning
                                            }
                                            if (!$global:LogoUrl -and $TextFallback -eq 'true') {
                                                $ApplyTextInsteadOfLogo = 'true'
                                                Write-Entry -Subtext "Falling back to text as no logo was found." -Path $global:configLogging -Color Yellow -log Warning
                                                $global:IsFallback = $true
                                            }
                                            ElseIf ($global:LogoUrl) {
                                                $urlExtension = [System.IO.Path]::GetExtension($global:LogoUrl).Split('?')[0]
                                                if ([string]::IsNullOrWhiteSpace($urlExtension)) { $urlExtension = ".png" }
                                                $LogoImage = Join-Path $TempPath ("logo" + $urlExtension); Write-Entry -Message "Logo Used: $global:LogoUrl" -Path $global:configLogging -Color Cyan -log Debug
                                                try {
                                                    $response = Invoke-WebRequest -Uri $global:LogoUrl -OutFile $LogoImage -ErrorAction Stop
                                                }
                                                catch {
                                                    if ($_.Exception.Response) {
                                                        $statusCode = $_.Exception.Response.StatusCode.value__
                                                    }
                                                    else {
                                                        $statusCode = $_.Exception.Message
                                                    }
                                                    Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                }
                                                # Only apply color if enabled AND color is defined
                                                $colorEffect = ""
                                                if ($ConvertLogoColor -eq "true" -and -not [string]::IsNullOrWhiteSpace($LogoFlatColor)) {
                                                    $_chkLogo = if ($LogoImage -and (Test-Path $LogoImage)) { $LogoImage } elseif ($LogoSource -and (Test-Path $LogoSource)) { $LogoSource } else { $null }

                                                    $_chromaStd = if ($_chkLogo) { (& $magick $_chkLogo -trim +repage -background black -alpha remove -colorspace HCL -channel Green -separate -format "%[fx:standard_deviation]" info: 2>$null) } else { "0" }

                                                    if ([double]$_chromaStd -lt 0.25) { $colorEffect = "-fill `"$LogoFlatColor`" -colorize 100"; Write-Entry -Subtext "Converting logo to $LogoFlatColor (chroma:$([math]::Round([double]$_chromaStd,3)))..." -Path $global:configLogging -Color Cyan -log Info }

                                                    else { $colorEffect = ""; Write-Entry -Subtext "Logo multi-color (chroma:$([math]::Round([double]$_chromaStd,3))), keeping original" -Path $global:configLogging -Color Yellow -log Info }
                                                }
                                                if ($urlExtension -match "(?i)\.svg") {
                                                    Write-Entry -Subtext "Detected SVG. Applying High-Res settings." -Path $global:configLogging -Color Cyan -log Info
                                                    $Arguments = "`"$backgroundImage`" ( -background none -density 300 `"$LogoImage`" $colorEffect -resize `"$Backgroundboxsize`" `) -gravity `"$Backgroundtextgravity`" -geometry +0+`"$Backgroundtext_offset`" -quality $global:outputQuality -composite `"$backgroundImage`""
                                                }
                                                else {
                                                    $Arguments = "`"$backgroundImage`" ( -background none `"$LogoImage`" $colorEffect -resize `"$Backgroundboxsize`" `) -gravity `"$Backgroundtextgravity`" -geometry +0+`"$Backgroundtext_offset`" -quality $global:outputQuality -composite `"$backgroundImage`""
                                                }
                                                Write-Entry -Subtext "Applying Logo..." -Path $global:configLogging -Color White -log Info
                                                $logEntry = "`"$magick`" $Arguments"
                                                $logEntry | Out-File $magickLog -Append
                                                InvokeMagickCommand -Command $magick -Arguments $Arguments

                                                Remove-Item -LiteralPath $LogoImage -Force -ErrorAction SilentlyContinue | out-null
                                            }
                                        }
                                        if ($ApplyTextInsteadOfLogo -eq 'true' -or $UseBGLogo -eq 'false') {
                                            if ($AddBackgroundText -eq 'true' -and $SkippingText -eq 'false') {
                                                if ($global:direction -eq "RTL") {
                                                    $backgroundfontImagemagick = $RTLfontImagemagick
                                                }
                                                $joinedTitle = $joinedTitle -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''

                                                # Loop through each symbol and replace it with a newline
                                                if ($NewLineOnSpecificSymbols -eq 'true') {
                                                    foreach ($symbol in $NewLineSymbols) {
                                                        # Replace the symbol with a newline
                                                        $replacementString = "`n"

                                                        # Check if the symbol should be kept
                                                        $keepThisSymbol = $false
                                                        if ($null -ne $SymbolsToKeepOnNewLine) {
                                                            # Loop through all items in $SymbolsToKeepOnNewLine (in case it's an array like [':', '!'])
                                                            foreach ($k in $SymbolsToKeepOnNewLine) {
                                                                # Check if the $symbol (e.g., ": ") contains the $k character (e.g., ":")
                                                                if ($symbol -like "*$k*") {
                                                                    $keepThisSymbol = $true
                                                                    break # Match found, no need to keep checking
                                                                }
                                                            }
                                                        }

                                                        # If it's a "keep" symbol, change the replacement string
                                                        if ($keepThisSymbol) {
                                                            # Replace ": " with ": \n" (keeps the symbol, adds newline after)
                                                            $replacementString = $symbol + "`n"
                                                        }
                                                        $joinedTitle = $joinedTitle -replace [regex]::Escape($symbol), $replacementString
                                                    }
                                                }
                                                if ($NewLineOnSpecificWords -eq 'true' -and $null -ne $NewLineWords) {
                                                    $properties = $NewLineWords.PSObject.Properties.Name

                                                    # Check if properties exist and the list is not empty
                                                    if ($null -ne $properties -and $properties.Count -gt 0) {
                                                        foreach ($wordKey in $properties) {
                                                            $replacementValue = $NewLineWords.$wordKey

                                                            # Using [regex]::Escape handles any special characters in the word keys
                                                            $joinedTitle = $joinedTitle -replace [regex]::Escape($wordKey), $replacementValue
                                                        }
                                                    }
                                                }
                                                $joinedTitlePointSize = $joinedTitle -replace '""', '""""'
                                                $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $backgroundfontImagemagick -box_width $BackgroundMaxWidth  -box_height $BackgroundMaxHeight -min_pointsize $BackgroundminPointSize -max_pointsize $BackgroundmaxPointSize -lineSpacing $BackgroundlineSpacing
                                                if ($global:IsTruncated -ne $true) {
                                                    Write-Entry -Subtext ("Optimal font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                    $cleanTitle = $joinedTitle -replace 'Â³', '' -replace 'Â²', ''
                                                    $supChar = if ($joinedTitle -match 'Â³') { "3" } elseif ($joinedTitle -match 'Â²') { "2" } else { "" }

                                                    $superSize = [int]($optimalFontSize * 0.55)
                                                    $yNudge = [int]($optimalFontSize * 0.3)
                                                    $gap = 20

                                                    if ($supChar -ne "" -and $AddTextStroke -eq 'true') {
                                                        # SUPERSCRIPT + STROKE MODE
                                                        $Arguments = "`"$backgroundImage`" ( -background none " +
                                                        "( ( -font `"$backgroundfontImagemagick`" -pointsize $optimalFontSize -fill `"$Backgroundstrokecolor`" -stroke `"$Backgroundstrokecolor`" -strokewidth `"$Backgroundstrokewidth`" label:`"$cleanTitle`" ) " +
                                                        "( -font `"$backgroundfontImagemagick`" -pointsize $superSize -fill `"$Backgroundstrokecolor`" -stroke `"$Backgroundstrokecolor`" -strokewidth `"$Backgroundstrokewidth`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                        "( ( -font `"$backgroundfontImagemagick`" -pointsize $optimalFontSize -fill `"$Backgroundfontcolor`" -stroke none label:`"$cleanTitle`" ) " +
                                                        "( -font `"$backgroundfontImagemagick`" -pointsize $superSize -fill `"$Backgroundfontcolor`" -stroke none label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                        "-gravity center -composite ) -gravity south -geometry +0`"$Backgroundtext_offset`" -composite `"$backgroundImage`""
                                                    }
                                                    elseif ($supChar -ne "") {
                                                        # SUPERSCRIPT ONLY MODE (No Stroke)
                                                        $Arguments = "`"$backgroundImage`" ( -background none " +
                                                        "( -font `"$backgroundfontImagemagick`" -pointsize $optimalFontSize -fill `"$Backgroundfontcolor`" label:`"$cleanTitle`" ) " +
                                                        "( -font `"$backgroundfontImagemagick`" -pointsize $superSize -fill `"$Backgroundfontcolor`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap " +
                                                        ") -gravity south -geometry +0`"$Backgroundtext_offset`" -composite `"$backgroundImage`""
                                                    }
                                                    else {
                                                        # STANDARD MODE (Normal caption logic)
                                                        if ($AddTextStroke -eq 'true') {
                                                            $Arguments = "`"$backgroundImage`" -gravity center -background None -layers Flatten `( -size `"$Backgroundboxsize`" -background none `( -font `"$backgroundfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Backgroundstrokecolor`" -stroke `"$Backgroundstrokecolor`" -strokewidth `"$Backgroundstrokewidth`" -size `"$Backgroundboxsize`" -background none -interline-spacing `"$BackgroundlineSpacing`" -gravity `"$Backgroundtextgravity`" caption:`"$joinedTitle`" `) `( -font `"$backgroundfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Backgroundfontcolor`" -stroke none -size `"$Backgroundboxsize`" -background none -interline-spacing `"$BackgroundlineSpacing`" -gravity `"$Backgroundtextgravity`" caption:`"$joinedTitle`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$Backgroundboxsize`" `) -gravity south -geometry +0`"$Backgroundtext_offset`" -quality $global:outputQuality -composite `"$backgroundImage`""
                                                        }
                                                        Else {
                                                            $Arguments = "`"$backgroundImage`" -gravity center -background None -layers Flatten ( -font `"$backgroundfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Backgroundfontcolor`" -size `"$Backgroundboxsize`" -background none -interline-spacing `"$BackgroundlineSpacing`" -gravity `"$Backgroundtextgravity`" caption:`"$joinedTitle`" -trim +repage -extent `"$Backgroundboxsize`" ) -gravity south -geometry +0`"$Backgroundtext_offset`" -quality $global:outputQuality -composite `"$backgroundImage`""
                                                        }
                                                    }

                                                    Write-Entry -Subtext "Applying Background text: `"$joinedTitle`"" -Path $global:configLogging -Color White -log Info
                                                    $logEntry = "`"$magick`" $Arguments"
                                                    $logEntry | Out-File $magickLog -Append
                                                    InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Else {
                                $Resizeargument = "`"$backgroundImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$backgroundImage`""
                                Write-Entry -Subtext "Resizing it... " -Path $global:configLogging -Color White -log Info
                                $logEntry = "`"$magick`" $Resizeargument"
                                $logEntry | Out-File $magickLog -Append
                                InvokeMagickCommand -Command $magick -Arguments $Resizeargument
                            }
                            if ($global:ImageMagickError -ne 'true') {
                                # Move file back to original naming with Brackets.
                                if (Get-ChildItem -LiteralPath $backgroundImage -ErrorAction SilentlyContinue) {
                                    if ($global:IsTruncated -ne $true) {
                                        if ($Upload2Plex -eq 'true') {
                                            try {
                                                Write-Entry -Subtext "Uploading Artwork to Plex..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                $fileContent = [System.IO.File]::ReadAllBytes($backgroundImage)
                                                # Verify variables before uploading
                                                Write-Entry -Subtext "BackgroundImage: $backgroundImage" -Path $global:configLogging -Color Cyan -log Debug
                                                Write-Entry -Subtext "RatingKey: $($entry.ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                                Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                                $uri = if ($PlexToken) {
                                                    "$PlexUrl/library/metadata/$($entry.ratingkey)/arts?X-Plex-Token=$PlexToken"
                                                }
                                                Else {
                                                    "$PlexUrl/library/metadata/$($entry.ratingkey)/arts"
                                                }
                                                Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                                # Try uploading, capturing the response in detail
                                                $Upload = Invoke-WebRequest -Uri $uri `
                                                    -Method Post `
                                                    -Headers $extraPlexHeaders `
                                                    -Body $fileContent `
                                                    -ContentType 'application/octet-stream' `
                                                    -SkipHttpErrorCheck `
                                                    -ErrorAction Stop

                                                if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                                    Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                                    Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                                }
                                                else {
                                                    Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                                    Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                                }
                                            }
                                            catch {
                                                Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                                $global:errorCount++
                                                Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                            }
                                        }
                                        try {
                                            # Attempt to move the item
                                            Move-Item -LiteralPath $backgroundImage -Destination $backgroundImageoriginal -Force -ErrorAction Stop

                                            # Log success if move was successful
                                            Write-Entry -Subtext "Added: $backgroundImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                        }
                                        catch {
                                            # Log the error if the move operation fails
                                            Write-Entry -Subtext "Failed to move $backgroundImage to $backgroundImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                            Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                        }
                                        $BackgroundCount++
                                        Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                        $posterCount++
                                    }
                                    Else {
                                        Write-Entry -Subtext "Skipping asset move because text is truncated..." -Path $global:configLogging -Color Yellow -log Warning
                                    }
                                    $showbackgroundtemp = New-Object psobject
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $Titletext
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Show Background'
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Language" -Value $(if ($TakeLocal) { "false" } Else { if (!$global:AssetTextLang) { "Textless" }Else { $global:AssetTextLang } })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Logo Source" -Value  $(if ($global:LogoUrl) { $global:LogoUrl } Else { "false" })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Logo Language" -Value $(if ($global:LogoLanguage) { $global:LogoLanguage } Else { "false" })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Logo TextFallback" -Value $(if ($ApplyTextInsteadOfLogo) { $ApplyTextInsteadOfLogo } Else { "false" })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value $(if ($global:IsFallback) { 'true' } else { 'false' })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value $(if ($TakeLocal) { $backgroundImage } Else { $global:posterurl })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                    $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                    switch -Wildcard ($global:FavProvider) {
                                        'TMDB' { $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                        'FANART' { $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                        'TVDB' { $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                        Default { $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                    }
                                    # Export the array to a CSV file
                                    $showbackgroundtemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                                }
                            }
                        }
                        Elseif ($LocalAssetMissing -eq 'true') {
                            Write-Entry -Subtext "Skipping [$Titletext] - local asset missing and online fetch is disabled." -Path $global:configLogging -Color Yellow -log Warning
                        }
                        Else {
                            Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                            $showbackgroundtemp = New-Object psobject
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $Titletext
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Show Background'
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Language" -Value 'false'
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value 'false'
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value 'false'
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                            $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                            switch -Wildcard ($global:FavProvider) {
                                'TMDB' { $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                'FANART' { $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                'TVDB' { $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                Default { $showbackgroundtemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                            }

                            # Export the array to a CSV file
                            $showbackgroundtemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                        }
                    }
                    else {
                        if ($global:UploadExistingAssets -eq 'true') {
                            if ($entry.PlexBackgroundUrl -like "/library/*") {
                                if ($PlexToken) {
                                    $Arturl = $plexurl + $entry.PlexBackgroundUrl + "?X-Plex-Token=$PlexToken"
                                }
                                Else {
                                    $Arturl = $plexurl + $entry.PlexBackgroundUrl
                                }
                            }
                            Write-Entry -Message "Starting Existing Asset Upload..." -Path $global:configLogging -Color Green -log Info
                            try {
                                GetPlexArtwork -Type " $Titletext | Backgound Artwork." -ArtUrl $Arturl -TempImage $backgroundImage
                                if ($global:PlexartworkDownloaded -eq 'true') {
                                    Write-Entry -Subtext "Uploading Existing Artwork for: $Titletext" -Path $global:configLogging -Color White -log Info
                                    $fileContent = [System.IO.File]::ReadAllBytes($backgroundImageoriginal)
                                    # Verify variables before uploading
                                    Write-Entry -Subtext "BackgroundImage: $backgroundImageoriginal" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Subtext "RatingKey: $($entry.ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                    $uri = if ($PlexToken) {
                                        "$PlexUrl/library/metadata/$($entry.ratingkey)/arts?X-Plex-Token=$PlexToken"
                                    }
                                    Else {
                                        "$PlexUrl/library/metadata/$($entry.ratingkey)/arts"
                                    }
                                    Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                    # Try uploading, capturing the response in detail
                                    $Upload = Invoke-WebRequest -Uri $uri `
                                        -Method Post `
                                        -Headers $extraPlexHeaders `
                                        -Body $fileContent `
                                        -ContentType 'application/octet-stream' `
                                        -SkipHttpErrorCheck `
                                        -ErrorAction Stop

                                    if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                        Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                        Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                    }
                                    else {
                                        Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                        Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                    }
                                    $UploadCount++
                                }
                            }
                            catch {
                                Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                $global:errorCount++
                                Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                            }
                            if (Test-Path $backgroundImage -ErrorAction SilentlyContinue) {
                                Remove-Item -LiteralPath $backgroundImage | Out-Null
                                Write-Entry -Message "Deleting Temp Image: $backgroundImage" -Path $global:configLogging -Color White -log Info
                            }
                        }
                        Else {
                            if ($show_skipped -eq 'true' ) {
                                Write-Entry -Subtext "Already exists: $backgroundImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                            }
                        }
                    }
                }
                # Now we can start the Season Part
                if ($global:SeasonPosters -eq 'true') {
                    $global:IsFallback = $null
                    $global:FallbackText = $null
                    $global:AssetTextLang = $null
                    $global:Fallback = $null
                    $global:TMDBAssetTextLang = $null
                    $global:FANARTAssetTextLang = $null
                    $global:TVDBAssetTextLang = $null
                    $global:TMDBAssetChangeUrl = $null
                    $global:FANARTAssetChangeUrl = $null
                    $global:TVDBAssetChangeUrl = $null
                    $global:PosterWithText = $null
                    $global:ImageMagickError = $null
                    $global:TextlessPoster = $null
                    $global:seasonNames = $entry.SeasonNames -split ';'
                    $global:SeasonRatingKeys = $entry.SeasonRatingKeys -split ','
                    $global:seasonNumbers = $entry.seasonNumbers -split ','
                    $global:PlexSeasonUrls = $entry.PlexSeasonUrls -split ','
                    for ($i = 0; $i -lt $global:seasonNames.Count; $i++) {
                        $SkippingText = 'false'
                        $Seasonpostersearchtext = $null
                        $global:seasontmp = $null
                        $global:TextlessPoster = $null
                        $global:tmdbsearched = $null
                        $global:posterurl = $null
                        $global:IsFallback = $null
                        $global:FallbackText = $null
                        $global:AssetTextLang = $null
                        $global:Fallback = $null
                        $global:TMDBAssetTextLang = $null
                        $global:FANARTAssetTextLang = $null
                        $global:TVDBAssetTextLang = $null
                        $global:TMDBAssetChangeUrl = $null
                        $global:FANARTAssetChangeUrl = $null
                        $global:TVDBAssetChangeUrl = $null
                        $global:PosterWithText = $null
                        $global:ImageMagickError = $null
                        $global:TMDBSeasonFallback = $null
                        $global:TVDBSeasonFallback = $null
                        $global:FANARTSeasonFallback = $null
                        $TakeLocal = $null
                        $LocalAssetMissing = $null
                        $LocalAddOverlay = $AddSeasonOverlay
                        $LocalAddBorder = $AddSeasonBorder
                        if ($SeasonfontAllCaps -eq 'true') {
                            if ($OverrideSeasonName -eq 'true') {
                                if ($global:seasonNumbers[$i] -eq '0') {
                                    $global:seasonTitle = $SpecialSeasonOverrideText.ToUpper()
                                }
                                Else {
                                    $global:seasonTitle = $SeasonOverrideText.ToUpper() + " " + $global:seasonNumbers[$i]
                                }
                            }
                            Else {
                                $global:seasonTitle = $global:seasonNames[$i].ToUpper()
                            }
                        }
                        Else {
                            if ($OverrideSeasonName -eq 'true') {
                                if ($global:seasonNumbers[$i] -eq '0') {
                                    $global:seasonTitle = $SpecialSeasonOverrideText
                                }
                                Else {
                                    $global:seasonTitle = $SeasonOverrideText + " " + $global:seasonNumbers[$i]
                                }
                            }
                            Else {
                                $global:seasonTitle = $global:seasonNames[$i]
                            }
                        }
                        $global:SeasonNumber = $global:seasonNumbers[$i]
                        $global:SeasonRatingKey = $global:SeasonRatingKeys[$i]
                        $global:PlexSeasonUrl = $global:PlexSeasonUrls[$i]
                        if ($null -ne $global:SeasonNumber) {
                            $global:seasontmp = "Season" + $global:SeasonNumber.PadLeft(2, '0')
                        }
                        if ($LibraryFolders -eq 'true') {
                            $SeasonImageoriginal = "$EntryDir\$global:seasontmp.jpg"
                            $TestPath = $EntryDir
                            $ManualTestPath = $ManualEntryDir
                            $Testfile = "$global:seasontmp"
                            $TestfileTemplate = "SeasonTemplate"
                        }
                        Else {
                            if ($entry.extraFolder) {
                                $SeasonImageoriginal = "$AssetPath\$($entry.extraFolder)\$($entry.RootFoldername)_$global:seasontmp.jpg"
                            }
                            Else {
                                $SeasonImageoriginal = "$AssetPath\$($entry.RootFoldername)_$global:seasontmp.jpg"
                            }
                            $TestPath = $AssetPath
                            $ManualTestPath = $ManualPath
                            $Testfile = "$($entry.RootFoldername)_$global:seasontmp"
                            $TestfileTemplate = "$($entry.RootFoldername)_SeasonTemplate"
                        }

                        if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                            $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                            $SeasonImageoriginal = ($SeasonImageoriginal).Replace('\', '/').Replace('./', '/')
                            $manualtestpath = ($ManualTestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                            $Templatetestpath = ($ManualEntryDir + "/" + $TestfileTemplate).Replace('\', '/').Replace('./', '/')
                        }
                        else {
                            $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                            $fullManualTestPath = Resolve-Path -Path $ManualTestPath -ErrorAction SilentlyContinue
                            if ($fullTestPath) {
                                $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                                $Manualtestpath = ($fullManualTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                                $Templatetestpath = ($fullManualTestPath.ProviderPath + "\" + $TestfileTemplate).Replace('/', '\')
                            }
                            Else {
                                $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                                $Manualtestpath = ($ManualTestPath + "\" + $Testfile).Replace('/', '\')
                                $Templatetestpath = ($ManualEntryDir + "\" + $TestfileTemplate).Replace('/', '\')
                            }
                        }

                        Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Message "Manual Test Path is: $ManualTestPath" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Message "Resolved Manual Test Path is: $Manualtestpath" -Path $global:configLogging -Color Cyan -log Debug
                        Write-Entry -Message "Resolved Manual Full Test Path is: $fullManualTestPath" -Path $global:configLogging -Color Cyan -log Debug

                        $SeasonImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername)_$global:seasontmp.jpg"
                        $SeasonImage = $SeasonImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')
                        $checkedItems.Add($hashtestpath)

                        if (-not $directoryHashtable.ContainsKey("$hashtestpath")) {
                            $Arturl = $null
                            if ($global:PlexSeasonUrl -like "/library/*") {
                                if ($PlexToken) {
                                    $Arturl = $plexurl + $global:PlexSeasonUrl + "?X-Plex-Token=$PlexToken"
                                }
                                Else {
                                    $Arturl = $plexurl + $global:PlexSeasonUrl
                                }
                            }
                            foreach ($ext in $allowedExtensions) {
                                $manualFile = "$ManualTestPath$ext"
                                $templateFile = "$Templatetestpath$ext"
                                $filePath = $null

                                if (Test-Path -LiteralPath $manualFile) {
                                    $filePath = $manualFile
                                }
                                elseif (Test-Path -LiteralPath $templateFile) {
                                    $filePath = $templateFile
                                }

                                if ($filePath) {
                                    Write-Entry -Message "Local file exists: $filePath" -Path $global:configLogging -Color Cyan -log Debug
                                    $posterext = $ext
                                    break
                                }
                            }
                            if ((Test-Path -LiteralPath "$($Manualtestpath)$posterext") -and $Manualtestpath -ne '\') {
                                Write-Entry -Message "Found Manual Season Poster for: $Titletext" -Path $global:configLogging -Color White -log Info
                                $TakeLocal = $true
                            }
                            elseif ((Test-Path -LiteralPath "$($Templatetestpath)$posterext") -and $Templatetestpath -ne '\') {
                                Write-Entry -Message "Found Template Poster..." -Path $global:configLogging -Color White -log Info
                                $ManualTestPath = $Templatetestpath
                                $TakeLocal = $true
                            }
                            Elseif ($global:DisableOnlineAssetFetch -eq 'true') {
                                $LocalAssetMissing = 'true'
                            }
                            Else {
                                if (!$Seasonpostersearchtext) {
                                    Write-Entry -Message "Start Season Poster Search for: $Titletext | $global:seasonTitle" -Path $global:configLogging -Color White -log Info
                                    $Seasonpostersearchtext = $true
                                }
                                switch -Wildcard ($global:FavProvider) {
                                    'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBSeasonPoster }Else { Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning } }
                                    'FANART' { $global:posterurl = GetFanartSeasonPoster }
                                    'TVDB' { if ($entry.tvdbid) { $global:posterurl = GetTVDBSeasonPoster }Else { Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning } }
                                    'PLEX' { if ($ArtUrl) { GetPlexArtwork -Type ' a Season Poster' -ArtUrl $Arturl -TempImage $SeasonImage } }
                                    Default { $global:posterurl = GetFanartSeasonPoster }
                                }
                                # do a specific order
                                if ($global:SeasonPreferTextless -eq $true) {
                                    if (!$global:posterurl -or !$global:TextlessPoster) {
                                        if (!$entry.tmdbid -and $global:FavProvider -ne 'TMDB') {
                                            Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
                                        }
                                        if (!$entry.tvdbid -and $global:FavProvider -ne 'TVDB') {
                                            Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
                                        }
                                        if ($global:FavProvider -ne 'TMDB' -and $entry.tmdbid) {
                                            $global:posterurl = GetTMDBSeasonPoster
                                            $global:IsFallback = $true
                                            Write-Entry -Subtext "Function GetTMDBSeasonPoster called..." -Path $global:configLogging -Color Cyan -log Debug
                                        }
                                        if (!$global:posterurl -or !$global:TextlessPoster) {
                                            if ($global:FavProvider -ne 'FANART') {
                                                $global:posterurl = GetFanartSeasonPoster
                                                Write-Entry -Subtext "Function GetFanartSeasonPoster called..." -Path $global:configLogging -Color Cyan -log Debug
                                                if ($global:posterurl) {
                                                    $global:IsFallback = $true
                                                }
                                                Write-Entry -Subtext "IsFallback: $global:IsFallback" -Path $global:configLogging -Color Cyan -log Debug
                                            }
                                        }
                                        if ((!$global:posterurl -or !$global:TextlessPoster) -and $entry.tvdbid) {
                                            if ($global:FavProvider -ne 'TVDB') {
                                                $global:posterurl = GetTVDBSeasonPoster
                                                if ($global:posterurl) {
                                                    $global:IsFallback = $true
                                                }
                                                Write-Entry -Subtext "Function GetTVDBSeasonPoster called..." -Path $global:configLogging -Color Cyan -log Debug
                                                Write-Entry -Subtext "IsFallback: $global:IsFallback" -Path $global:configLogging -Color Cyan -log Debug
                                            }
                                        }
                                    }
                                    if (!$global:posterurl) {
                                        Write-Entry -Subtext "Could not find a season poster on any site" -Path $global:configLogging -Color Red -log Error
                                    }
                                    if (!$global:TextlessPoster -and $ShowFallback -eq 'true') {
                                        # Lets just try to grab a show poster.
                                        Write-Entry -Subtext "Fallback to Show Poster..." -Path $global:configLogging -Color DarkMagenta -log Info
                                        switch -Wildcard ($global:FavProvider) {
                                            'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBShowPoster }Else { Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartShowPoster } }
                                            'FANART' { $global:posterurl = GetFanartShowPoster }
                                            'TVDB' { if ($entry.tvdbid) { $global:posterurl = GetTVDBShowPoster }Else { Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartShowPoster } }
                                            'PLEX' { if ($ArtUrl) { GetPlexArtwork -Type ' a Show Poster' -ArtUrl $Arturl -TempImage $PosterImage } }
                                            Default { $global:posterurl = GetFanartShowPoster }
                                        }
                                        if ($global:posterurl) {
                                            Write-Entry -Subtext "Using the Show Poster as Season Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                            $global:IsFallback = $true
                                            $global:FallbackText = 'True-Show'
                                        }
                                        Else {
                                            if ($global:FavProvider -ne 'TMDB') {
                                                $global:posterurl = GetTMDBShowPoster
                                                if ($global:posterurl) {
                                                    Write-Entry -Subtext "Using the Show Poster as Season Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                    $global:IsFallback = $true
                                                    $global:FallbackText = 'True-Show'
                                                }
                                            }
                                            if ($global:FavProvider -ne 'TVDB' -and !$global:posterurl) {
                                                $global:posterurl = GetTVDBShowPoster
                                                if ($global:posterurl) {
                                                    Write-Entry -Subtext "Using the Show Poster as Season Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                    $global:IsFallback = $true
                                                    $global:FallbackText = 'True-Show'
                                                }
                                            }
                                            if ($global:FavProvider -ne 'FANART' -and !$global:posterurl) {
                                                $global:posterurl = GetFanartShowPoster
                                                if ($global:posterurl) {
                                                    Write-Entry -Subtext "Using the Show Poster as Season Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                    $global:IsFallback = $true
                                                    $global:FallbackText = 'True-Show'
                                                }
                                            }
                                        }
                                    }
                                }
                                Else {
                                    if (!$global:posterurl) {
                                        if ($global:FavProvider -ne 'TMDB' -and $entry.tmdbid) {
                                            $global:posterurl = GetTMDBSeasonPoster
                                            if ($global:posterurl) {
                                                $global:IsFallback = $true
                                            }
                                            Write-Entry -Subtext "Function GetTMDBSeasonPoster called..." -Path $global:configLogging -Color Cyan -log Debug
                                        }
                                        if (!$global:posterurl) {
                                            if ($global:FavProvider -ne 'FANART') {
                                                $global:posterurl = GetFanartSeasonPoster
                                                Write-Entry -Subtext "Function GetFanartSeasonPoster called..." -Path $global:configLogging -Color Cyan -log Debug
                                                if ($global:posterurl) {
                                                    $global:IsFallback = $true
                                                }
                                                Write-Entry -Subtext "IsFallback: $global:IsFallback" -Path $global:configLogging -Color Cyan -log Debug
                                            }
                                        }
                                        if (!$global:posterurl -and $entry.tvdbid) {
                                            if ($global:FavProvider -ne 'TVDB') {
                                                $global:posterurl = GetTVDBSeasonPoster
                                                if ($global:posterurl) {
                                                    $global:IsFallback = $true
                                                }
                                                Write-Entry -Subtext "Function GetTVDBSeasonPoster called..." -Path $global:configLogging -Color Cyan -log Debug
                                                Write-Entry -Subtext "IsFallback: $global:IsFallback" -Path $global:configLogging -Color Cyan -log Debug
                                            }
                                        }
                                        if ($ArtUrl) {
                                            if ($global:FavProvider -ne 'PLEX') {
                                                GetPlexArtwork -Type ' a Season Poster' -ArtUrl $Arturl -TempImage $SeasonImage
                                                if ($global:posterurl) {
                                                    $global:IsFallback = $true
                                                }
                                                Write-Entry -Subtext "Function GetPlexArtwork called..." -Path $global:configLogging -Color Cyan -log Debug
                                                Write-Entry -Subtext "IsFallback: $global:IsFallback" -Path $global:configLogging -Color Cyan -log Debug
                                            }
                                        }
                                        Else {
                                            Write-Entry -Subtext "Plex Season Poster Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                        }
                                    }
                                    if (!$global:posterurl) {
                                        Write-Entry -Subtext "Could not find a season poster on any site" -Path $global:configLogging -Color Red -log Error
                                    }
                                }
                                if (!$global:posterurl -and $ShowFallback -eq 'true') {
                                    # Lets just try to grab a show poster.
                                    Write-Entry -Subtext "Fallback to Show Poster..." -Path $global:configLogging -Color DarkMagenta -log Info
                                    switch -Wildcard ($global:FavProvider) {
                                        'TMDB' { if ($entry.tmdbid) { $global:posterurl = GetTMDBShowPoster }Else { Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartShowPoster } }
                                        'FANART' { $global:posterurl = GetFanartShowPoster }
                                        'TVDB' { if ($entry.tvdbid) { $global:posterurl = GetTVDBShowPoster }Else { Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning; $global:posterurl = GetFanartShowPoster } }
                                        'PLEX' { if ($ArtUrl) { GetPlexArtwork -Type ' a Show Poster' -ArtUrl $Arturl -TempImage $PosterImage } }
                                        Default { $global:posterurl = GetFanartShowPoster }
                                    }
                                    if ($global:posterurl) {
                                        Write-Entry -Subtext "Using the Show Poster as Season Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                        $global:IsFallback = $true
                                        $global:FallbackText = 'True-Show'
                                    }
                                    Else {
                                        if ($global:FavProvider -ne 'TMDB') {
                                            $global:posterurl = GetTMDBShowPoster
                                            if ($global:posterurl) {
                                                Write-Entry -Subtext "Using the Show Poster as Season Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                $global:IsFallback = $true
                                                $global:FallbackText = 'True-Show'
                                            }
                                        }
                                        if ($global:FavProvider -ne 'TVDB' -and !$global:posterurl) {
                                            $global:posterurl = GetTVDBShowPoster
                                            if ($global:posterurl) {
                                                Write-Entry -Subtext "Using the Show Poster as Season Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                $global:IsFallback = $true
                                                $global:FallbackText = 'True-Show'
                                            }
                                        }
                                        if ($global:FavProvider -ne 'FANART' -and !$global:posterurl) {
                                            $global:posterurl = GetFanartShowPoster
                                            if ($global:posterurl) {
                                                Write-Entry -Subtext "Using the Show Poster as Season Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                $global:IsFallback = $true
                                                $global:FallbackText = 'True-Show'
                                            }
                                        }
                                    }
                                }
                                if ($global:TMDBSeasonFallback -and $global:PosterWithText -and $global:FavProvider -eq 'TMDB') {
                                    $global:posterurl = $global:TMDBSeasonFallback
                                    Write-Entry -Subtext "Taking Season Poster with text as fallback from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                    $global:IsFallback = $true
                                }
                                if ($global:FANARTSeasonFallback -and $global:PosterWithText -and $global:FavProvider -eq 'FANART') {
                                    $global:posterurl = $global:FANARTSeasonFallback
                                    Write-Entry -Subtext "Taking Season Poster with text as fallback from 'FANART'" -Path $global:configLogging -Color DarkMagenta -log Info
                                    $global:IsFallback = $true
                                }
                                if ($global:TVDBSeasonFallback -and $global:PosterWithText -and $global:FavProvider -eq 'TVDB') {
                                    $global:posterurl = $global:TVDBSeasonFallback
                                    Write-Entry -Subtext "Taking Season Poster with text as fallback from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                    $global:IsFallback = $true
                                }

                            }
                            if ($global:posterurl -or $global:PlexartworkDownloaded -or $TakeLocal) {
                                $global:IsTruncated = $null
                                if ($global:ImageProcessing -eq 'true') {
                                    if ($TakeLocal) {
                                        Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                            Copy-Item -LiteralPath $_.FullName -Destination $SeasonImage
                                        }
                                        if ($SkipLocalSeasonTextAdd -eq 'true') {
                                            $SkippingText = 'true'
                                        }
                                        Write-Entry -Subtext "Copy local asset to: $SeasonImage" -Path $global:configLogging -Color Green -log Info
                                    }
                                    Else {
                                        try {
                                            if (!$global:PlexartworkDownloaded) {
                                                $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $SeasonImage -ErrorAction Stop
                                            }
                                        }
                                        catch {
                                            if ($_.Exception.Response) {
                                                $statusCode = $_.Exception.Response.StatusCode.value__
                                            }
                                            else {
                                                $statusCode = $_.Exception.Message
                                            }
                                            Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                        }
                                        Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                        if ($global:posterurl -like 'https://image.tmdb.org*') {
                                            Write-Entry -Subtext "Downloading Poster from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TMDBAssetTextLang
                                            if ($global:FavProvider -ne 'TMDB') {
                                                $global:IsFallback = $true
                                            }
                                        }
                                        elseif ($global:posterurl -like 'https://assets.fanart.tv*') {
                                            Write-Entry -Subtext "Downloading Poster from 'Fanart.tv'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:FANARTAssetTextLang
                                            if ($global:FavProvider -ne 'FANART') {
                                                $global:IsFallback = $true
                                            }
                                        }
                                        elseif ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                            Write-Entry -Subtext "Downloading Poster from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TVDBAssetTextLang
                                            if ($global:FavProvider -ne 'TVDB') {
                                                $global:IsFallback = $true
                                            }
                                        }
                                        elseif ($global:posterurl -like "$PlexUrl*") {
                                            Write-Entry -Subtext "Downloading Poster from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            if ($global:FavProvider -ne 'PLEX') {
                                                $global:IsFallback = $true
                                            }
                                        }
                                        Else {
                                            Write-Entry -Subtext "Downloading Poster from 'IMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $PosterUnknownCount++
                                            $global:IsFallback = $true
                                        }
                                    }
                                    if (Get-ChildItem -LiteralPath $SeasonImage -ErrorAction SilentlyContinue) {
                                        $CommentArguments = "`"$SeasonImage`" -set `"comment`" `"created with posterizarr`" `"$SeasonImage`""
                                        $CommentlogEntry = "`"$magick`" $CommentArguments"
                                        $CommentlogEntry | Out-File $magickLog -Append
                                        InvokeMagickCommand -Command $magick -Arguments $CommentArguments
                                        if ($global:ImageMagickError -ne 'true') {
                                            # Logic for SkipAddTextAndOverlay (Skip Overlay, keep Border)
                                            if (($SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                                $LocalAddOverlay = 'false'
                                            }

                                            # Logic for SkipAddTextAndBorder (Skip Border, keep Overlay)
                                            if (($SkipAddTextAndBorder -eq 'true') -and $global:PosterWithText) {
                                                $LocalAddBorder = 'false'
                                            }

                                            # Logic for "If both are true, only resize"
                                            if ($SkipAddTextAndOverlay -eq 'true' -and $SkipAddTextAndBorder -eq 'true' -and $global:PosterWithText) {
                                                $LocalAddBorder = 'false'
                                                $LocalAddOverlay = 'false'
                                            }
                                            # Resize Image to 2000x3000 and apply Border and overlay
                                            if ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'true') {
                                                $Arguments = "`"$SeasonImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$Seasonoverlay`" -gravity south -quality $global:outputQuality -composite -shave `"$Seasonborderwidthsecond`"  -bordercolor `"$Seasonbordercolor`" -border `"$Seasonborderwidth`" `"$SeasonImage`""
                                                Write-Entry -Subtext "Resizing it | Adding Borders | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                            }
                                            elseif ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'false') {
                                                $Arguments = "`"$SeasonImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" -shave `"$Seasonborderwidthsecond`"  -bordercolor `"$Seasonbordercolor`" -border `"$Seasonborderwidth`" `"$SeasonImage`""
                                                Write-Entry -Subtext "Resizing it | Adding Borders" -Path $global:configLogging -Color White -log Info
                                            }
                                            elseif ($LocalAddBorder -eq 'false' -and $LocalAddOverlay -eq 'true') {
                                                $Arguments = "`"$SeasonImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$Seasonoverlay`" -gravity south -quality $global:outputQuality -composite `"$SeasonImage`""
                                                Write-Entry -Subtext "Resizing it | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                            }
                                            else {
                                                $Arguments = "`"$SeasonImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$SeasonImage`""
                                                Write-Entry -Subtext "Resizing it" -Path $global:configLogging -Color White -log Info
                                            }

                                            $logEntry = "`"$magick`" $Arguments"
                                            $logEntry | Out-File $magickLog -Append
                                            InvokeMagickCommand -Command $magick -Arguments $Arguments
                                            if (($SkipAddText -eq 'true' -or $SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                                $SkippingText = 'true'
                                                Write-Entry -Subtext "Skipping 'AddText' because poster already has text." -Path $global:configLogging -Color Yellow -log Info
                                            }
                                            if ($AddSeasonText -eq 'true' -and $SkippingText -eq 'false') {
                                                $global:seasonTitle = $global:seasonTitle -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                if ($ShowOnSeasonfontAllCaps -eq 'true') {
                                                    $global:ShowTitleOnSeason = $titletext.ToUpper() -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                }
                                                Else {
                                                    $global:ShowTitleOnSeason = $titletext -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                }
                                                # Loop through each symbol and replace it with a newline
                                                if ($NewLineOnSpecificSymbols -eq 'true') {
                                                    foreach ($symbol in $NewLineSymbols) {
                                                        # Replace the symbol with a newline
                                                        $replacementString = "`n"

                                                        # Check if the symbol should be kept
                                                        $keepThisSymbol = $false
                                                        if ($null -ne $SymbolsToKeepOnNewLine) {
                                                            # Loop through all items in $SymbolsToKeepOnNewLine (in case it's an array like [':', '!'])
                                                            foreach ($k in $SymbolsToKeepOnNewLine) {
                                                                # Check if the $symbol (e.g., ": ") contains the $k character (e.g., ":")
                                                                if ($symbol -like "*$k*") {
                                                                    $keepThisSymbol = $true
                                                                    break # Match found, no need to keep checking
                                                                }
                                                            }
                                                        }

                                                        # If it's a "keep" symbol, change the replacement string
                                                        if ($keepThisSymbol) {
                                                            # Replace ": " with ": \n" (keeps the symbol, adds newline after)
                                                            $replacementString = $symbol + "`n"
                                                        }
                                                        $global:seasonTitle = $global:seasonTitle -replace [regex]::Escape($symbol), $replacementString
                                                        if ($AddShowTitletoSeason -eq 'true') {
                                                            $global:ShowTitleOnSeason = $global:ShowTitleOnSeason -replace [regex]::Escape($symbol), $replacementString
                                                        }
                                                    }
                                                }
                                                if ($NewLineOnSpecificWords -eq 'true' -and $null -ne $NewLineWords) {
                                                    $properties = $NewLineWords.PSObject.Properties.Name

                                                    # Check if properties exist and the list is not empty
                                                    if ($null -ne $properties -and $properties.Count -gt 0) {
                                                        foreach ($wordKey in $properties) {
                                                            $replacementValue = $NewLineWords.$wordKey

                                                            # Using [regex]::Escape handles any special characters in the word keys
                                                            $global:seasonTitle = $global:seasonTitle -replace [regex]::Escape($wordKey), $replacementValue
                                                            if ($AddShowTitletoSeason -eq 'true') {
                                                                $global:ShowTitleOnSeason = $global:ShowTitleOnSeason -replace [regex]::Escape($wordKey), $replacementValue
                                                            }
                                                        }
                                                    }
                                                }
                                                $joinedTitlePointSize = $global:seasonTitle -replace '""', '""""'
                                                $joinedShowTitlePointSize = $global:ShowTitleOnSeason -replace '""', '""""'
                                                if ($AddShowTitletoSeason -eq 'true') {
                                                    $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $fontImagemagick -box_width $SeasonMaxWidth  -box_height $SeasonMaxHeight -min_pointsize $SeasonminPointSize -max_pointsize $SeasonmaxPointSize -lineSpacing $SeasonlineSpacing
                                                    $ShowoptimalFontSize = Get-OptimalPointSize -text $joinedShowTitlePointSize -font $fontImagemagick -box_width $ShowOnSeasonMaxWidth  -box_height $ShowOnSeasonMaxHeight -min_pointsize $ShowOnSeasonminPointSize -max_pointsize $ShowOnSeasonmaxPointSize -lineSpacing $ShowOnSeasonlineSpacing

                                                    if ($global:IsTruncated -ne $true) {
                                                        Write-Entry -Subtext ("Optimal Season font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                        Write-Entry -Subtext ("Optimal Show font size set to: '{0}' [{1}]" -f $showoptimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info

                                                        # Season Text Part
                                                        $cleanTitle = $global:seasonTitle -replace 'Â³', '' -replace 'Â²', ''
                                                        $supChar = if ($global:seasonTitle -match 'Â³') { "3" } elseif ($global:seasonTitle -match 'Â²') { "2" } else { "" }

                                                        $superSize = [int]($optimalFontSize * 0.55)
                                                        $yNudge = [int]($optimalFontSize * 0.3)
                                                        $gap = 20

                                                        if ($supChar -ne "" -and $AddSeasonTextStroke -eq 'true') {
                                                            $SeasonArguments = "`"$SeasonImage`" ( -background none " +
                                                            "( ( -font `"$fontImagemagick`" -pointsize $optimalFontSize -fill `"$Seasonstrokecolor`" -stroke `"$Seasonstrokecolor`" -strokewidth `"$Seasonstrokewidth`" label:`"$cleanTitle`" ) " +
                                                            "( -font `"$fontImagemagick`" -pointsize $superSize -fill `"$Seasonstrokecolor`" -stroke `"$Seasonstrokecolor`" -strokewidth `"$Seasonstrokewidth`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                            "( ( -font `"$fontImagemagick`" -pointsize $optimalFontSize -fill `"$Seasonfontcolor`" -stroke none label:`"$cleanTitle`" ) " +
                                                            "( -font `"$fontImagemagick`" -pointsize $superSize -fill `"$Seasonfontcolor`" -stroke none label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap ) " +
                                                            "-gravity center -composite ) -gravity south -geometry +0`"$Seasontext_offset`" -composite `"$SeasonImage`""
                                                        }
                                                        elseif ($supChar -ne "") {
                                                            $SeasonArguments = "`"$SeasonImage`" ( -background none " +
                                                            "( -font `"$fontImagemagick`" -pointsize $optimalFontSize -fill `"$Seasonfontcolor`" label:`"$cleanTitle`" ) " +
                                                            "( -font `"$fontImagemagick`" -pointsize $superSize -fill `"$Seasonfontcolor`" label:`"$supChar`" -repage +0-$yNudge ) +smush +$gap " +
                                                            ") -gravity south -geometry +0`"$Seasontext_offset`" -composite `"$SeasonImage`""
                                                        }
                                                        else {
                                                            if ($AddSeasonTextStroke -eq 'true') {
                                                                $SeasonArguments = "`"$SeasonImage`" -gravity center -background None -layers Flatten `( -size `"$Seasonboxsize`" -background none `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Seasonstrokecolor`" -stroke `"$Seasonstrokecolor`" -strokewidth `"$Seasonstrokewidth`" -size `"$Seasonboxsize`" -background none -interline-spacing `"$SeasonlineSpacing`" -gravity `"$Seasontextgravity`" caption:`"$global:seasonTitle`" `) `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Seasonfontcolor`" -stroke none -size `"$Seasonboxsize`" -background none -interline-spacing `"$SeasonlineSpacing`" -gravity `"$Seasontextgravity`" caption:`"$global:seasonTitle`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$Seasonboxsize`" `) -gravity south -geometry +0`"$Seasontext_offset`" -quality $global:outputQuality -composite `"$SeasonImage`""
                                                            }
                                                            Else {
                                                                $SeasonArguments = "`"$SeasonImage`" -gravity center -background None -layers Flatten `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Seasonfontcolor`" -size `"$Seasonboxsize`" -background none -interline-spacing `"$SeasonlineSpacing`" -gravity `"$Seasontextgravity`" caption:`"$global:seasonTitle`" -trim +repage -extent `"$Seasonboxsize`" `) -gravity south -geometry +0`"$Seasontext_offset`" -quality $global:outputQuality -composite `"$SeasonImage`""
                                                            }
                                                        }

                                                        Write-Entry -Subtext "Applying seasonTitle text: `"$global:seasonTitle`"" -Path $global:configLogging -Color White -log Info
                                                        $logEntry = "`"$magick`" $SeasonArguments"
                                                        $logEntry | Out-File $magickLog -Append
                                                        InvokeMagickCommand -Command $magick -Arguments $SeasonArguments

                                                        # Show Part (Logo vs Text)
                                                        $ApplyTextInsteadOfLogo = $null

                                                        if ($UseLogo -eq 'true' -and ($global:UseClearlogo -eq 'true' -or $global:UseClearart -eq 'true')) {
                                                            $global:LogoUrl = $null
                                                            $global:LogoLanguage = $null
                                                            $allProviders = @('TMDB', 'FANART', 'TVDB')
                                                            $searchOrder = @($global:FavProvider) + ($allProviders -ne $global:FavProvider)

                                                            foreach ($provider in $searchOrder) {
                                                                if (-not [string]::IsNullOrEmpty($global:LogoUrl)) { break }
                                                                switch ($provider) {
                                                                    'TMDB' { if ($entry.tmdbid) { $global:LogoUrl = GetTMDBLogo -Type tv } }
                                                                    'FANART' { $global:LogoUrl = GetFanartLogo -Type tv }
                                                                    'TVDB' { if ($entry.tvdbid) { $global:LogoUrl = GetTVDBLogo -Type series } }
                                                                }
                                                            }

                                                            if (-not [string]::IsNullOrEmpty($global:LogoUrl)) {
                                                                $global:IsFallback = $false
                                                                switch ($global:FavProvider) {
                                                                    'TMDB' { if (-not ($global:LogoUrl.StartsWith("https://image.tmdb.org"))) { $global:IsFallback = $true } }
                                                                    'TVDB' { if (-not ($global:LogoUrl.StartsWith("https://artworks.thetvdb.com"))) { $global:IsFallback = $true } }
                                                                    'FANART' { if (-not ($global:LogoUrl.StartsWith("https://assets.fanart.tv"))) { $global:IsFallback = $true } }
                                                                }
                                                                if ($global:IsFallback) {
                                                                    Write-Entry -Subtext "Logo Source: Fallback (URL did not match $global:FavProvider)" -Path $global:configLogging -Color Yellow -log Debug
                                                                }
                                                            }

                                                            if ([string]::IsNullOrEmpty($global:LogoUrl)) {
                                                                Write-Entry -Subtext "Could not find a logo on any provider (Tried: $($searchOrder -join ', '))" -Path $global:configLogging -Color Yellow -log Warning
                                                            }

                                                            if (!$global:LogoUrl -and $TextFallback -eq 'true') {
                                                                $ApplyTextInsteadOfLogo = 'true'
                                                                Write-Entry -Subtext "Falling back to text as no logo was found." -Path $global:configLogging -Color Yellow -log Warning
                                                                $global:IsFallback = $true
                                                            }
                                                            ElseIf ($global:LogoUrl) {
                                                                $urlExtension = [System.IO.Path]::GetExtension($global:LogoUrl).Split('?')[0]
                                                                if ([string]::IsNullOrWhiteSpace($urlExtension)) { $urlExtension = ".png" }
                                                                $LogoImage = Join-Path $TempPath ("logo" + $urlExtension); Write-Entry -Message "Logo Used: $global:LogoUrl" -Path $global:configLogging -Color Cyan -log Debug

                                                                try {
                                                                    $response = Invoke-WebRequest -Uri $global:LogoUrl -OutFile $LogoImage -ErrorAction Stop
                                                                }
                                                                catch {
                                                                    if ($_.Exception.Response) {
                                                                        $statusCode = $_.Exception.Response.StatusCode.value__
                                                                    }
                                                                    else {
                                                                        $statusCode = $_.Exception.Message
                                                                    }
                                                                    Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                                                    $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                                }

                                                                $colorEffect = ""
                                                                if ($ConvertLogoColor -eq "true" -and -not [string]::IsNullOrWhiteSpace($LogoFlatColor)) {
                                                                    $_chkLogo = if ($LogoImage -and (Test-Path $LogoImage)) { $LogoImage } elseif ($LogoSource -and (Test-Path $LogoSource)) { $LogoSource } else { $null }
                                                                    $_chromaStd = if ($_chkLogo) { (& $magick $_chkLogo -trim +repage -background black -alpha remove -colorspace HCL -channel Green -separate -format "%[fx:standard_deviation]" info: 2>$null) } else { "0" }

                                                                    if ([double]$_chromaStd -lt 0.25) {
                                                                        $colorEffect = "-fill `"$LogoFlatColor`" -colorize 100"
                                                                        Write-Entry -Subtext "Converting logo to $LogoFlatColor (chroma:$([math]::Round([double]$_chromaStd,3)))..." -Path $global:configLogging -Color Cyan -log Info
                                                                    }
                                                                    else {
                                                                        $colorEffect = ""
                                                                        Write-Entry -Subtext "Logo multi-color (chroma:$([math]::Round([double]$_chromaStd,3))), keeping original" -Path $global:configLogging -Color Yellow -log Info
                                                                    }
                                                                }

                                                                if ($urlExtension -match "(?i)\.svg") {
                                                                    Write-Entry -Subtext "Detected SVG. Applying High-Res settings for Season Show Logo." -Path $global:configLogging -Color Cyan -log Info
                                                                    $ShowOnSeasonArguments = "`"$SeasonImage`" ( -background none -density 300 `"$LogoImage`" $colorEffect -resize `"$ShowOnSeasonboxsize`" `) -gravity `"$ShowOnSeasontextgravity`" -geometry +0+`"$ShowOnSeasontext_offset`" -quality $global:outputQuality -composite `"$SeasonImage`""
                                                                }
                                                                else {
                                                                    $ShowOnSeasonArguments = "`"$SeasonImage`" ( -background none `"$LogoImage`" $colorEffect -resize `"$ShowOnSeasonboxsize`" `) -gravity `"$ShowOnSeasontextgravity`" -geometry +0+`"$ShowOnSeasontext_offset`" -quality $global:outputQuality -composite `"$SeasonImage`""
                                                                }

                                                                Write-Entry -Subtext "Applying Show Logo to Season..." -Path $global:configLogging -Color White -log Info
                                                                $logEntry = "`"$magick`" $ShowOnSeasonArguments"
                                                                $logEntry | Out-File $magickLog -Append
                                                                InvokeMagickCommand -Command $magick -Arguments $ShowOnSeasonArguments

                                                                Remove-Item -LiteralPath $LogoImage -Force -ErrorAction SilentlyContinue | out-null
                                                            }
                                                        }

                                                        # Fallback Text Logic
                                                        if ($ApplyTextInsteadOfLogo -eq 'true' -or $UseLogo -eq 'false') {
                                                            if ($AddShowOnSeasonTextStroke -eq 'true') {
                                                                $ShowOnSeasonArguments = "`"$SeasonImage`" -gravity center -background None -layers Flatten `( -size `"$ShowOnSeasonboxsize`" -background none `( -font `"$fontImagemagick`" -pointsize `"$ShowoptimalFontSize`" -fill `"$ShowOnSeasonstrokecolor`" -stroke `"$ShowOnSeasonstrokecolor`" -strokewidth `"$ShowOnSeasonstrokewidth`" -size `"$ShowOnSeasonboxsize`" -background none -interline-spacing `"$ShowOnSeasonlineSpacing`" -gravity `"$ShowOnSeasontextgravity`" caption:`"$global:ShowTitleOnSeason`" `) `( -font `"$fontImagemagick`" -pointsize `"$ShowoptimalFontSize`" -fill `"$ShowOnSeasonfontcolor`" -stroke none -size `"$ShowOnSeasonboxsize`" -background none -interline-spacing `"$ShowOnSeasonlineSpacing`" -gravity `"$ShowOnSeasontextgravity`" caption:`"$global:ShowTitleOnSeason`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$ShowOnSeasonboxsize`" `) -gravity south -geometry +0`"$ShowOnSeasontext_offset`" -quality $global:outputQuality -composite `"$SeasonImage`""
                                                            }
                                                            Else {
                                                                $ShowOnSeasonArguments = "`"$SeasonImage`" -gravity center -background None -layers Flatten `( -font `"$fontImagemagick`" -pointsize `"$ShowoptimalFontSize`" -fill `"$ShowOnSeasonfontcolor`" -size `"$ShowOnSeasonboxsize`" -background none -interline-spacing `"$ShowOnSeasonlineSpacing`" -gravity `"$ShowOnSeasontextgravity`" caption:`"$global:ShowTitleOnSeason`" -trim +repage -extent `"$ShowOnSeasonboxsize`" `) -gravity south -geometry +0`"$ShowOnSeasontext_offset`" -quality $global:outputQuality -composite `"$SeasonImage`""
                                                            }

                                                            Write-Entry -Subtext "Applying showTitle text: `"$global:ShowTitleOnSeason`"" -Path $global:configLogging -Color White -log Info
                                                            $logEntry = "`"$magick`" $ShowOnSeasonArguments"
                                                            $logEntry | Out-File $magickLog -Append
                                                            InvokeMagickCommand -Command $magick -Arguments $ShowOnSeasonArguments
                                                        }
                                                    }
                                                }
                                                Else {
                                                    $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $fontImagemagick -box_width $SeasonMaxWidth  -box_height $SeasonMaxHeight -min_pointsize $SeasonminPointSize -max_pointsize $SeasonmaxPointSize -lineSpacing $SeasonlineSpacing
                                                    if ($global:IsTruncated -ne $true) {
                                                        Write-Entry -Subtext ("Optimal font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                        # Add Stroke
                                                        if ($AddSeasonTextStroke -eq 'true') {
                                                            $Arguments = "`"$SeasonImage`" -gravity center -background None -layers Flatten `( -size `"$Seasonboxsize`" -background none `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Seasonstrokecolor`" -stroke `"$Seasonstrokecolor`" -strokewidth `"$Seasonstrokewidth`" -size `"$Seasonboxsize`" -background none -interline-spacing `"$SeasonlineSpacing`" -gravity `"$Seasontextgravity`" caption:`"$global:seasonTitle`" `) `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Seasonfontcolor`" -stroke none -size `"$Seasonboxsize`" -background none -interline-spacing `"$SeasonlineSpacing`" -gravity `"$Seasontextgravity`" caption:`"$global:seasonTitle`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$Seasonboxsize`" `) -gravity south -geometry +0`"$Seasontext_offset`" -quality $global:outputQuality -composite `"$SeasonImage`""
                                                        }
                                                        Else {
                                                            $Arguments = "`"$SeasonImage`" -gravity center -background None -layers Flatten `( -font `"$fontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$Seasonfontcolor`" -size `"$Seasonboxsize`" -background none -interline-spacing `"$SeasonlineSpacing`" -gravity `"$Seasontextgravity`" caption:`"$global:seasonTitle`" -trim +repage -extent `"$Seasonboxsize`" `) -gravity south -geometry +0`"$Seasontext_offset`" -quality $global:outputQuality -composite `"$SeasonImage`""
                                                        }

                                                        Write-Entry -Subtext "Applying seasonTitle text: `"$global:seasonTitle`"" -Path $global:configLogging -Color White -log Info
                                                        $logEntry = "`"$magick`" $Arguments"
                                                        $logEntry | Out-File $magickLog -Append
                                                        InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                Else {
                                    if ($TakeLocal) {
                                        Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                            Copy-Item -LiteralPath $_.FullName -Destination $SeasonImage
                                        }
                                        if ($SkipLocalSeasonTextAdd -eq 'true') {
                                            $SkippingText = 'true'
                                        }
                                        Write-Entry -Subtext "Copy local asset to: $SeasonImage" -Path $global:configLogging -Color Green -log Info
                                    }
                                    Else {
                                        try {
                                            if (!$global:PlexartworkDownloaded) {
                                                $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $SeasonImage -ErrorAction Stop
                                            }
                                        }
                                        catch {
                                            if ($_.Exception.Response) {
                                                $statusCode = $_.Exception.Response.StatusCode.value__
                                            }
                                            else {
                                                $statusCode = $_.Exception.Message
                                            }
                                            Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                        }
                                        Write-Entry -Subtext "Poster url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                        if ($global:posterurl -like 'https://image.tmdb.org*') {
                                            Write-Entry -Subtext "Downloading Poster from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TMDBAssetTextLang
                                            if ($global:FavProvider -ne 'TMDB') {
                                                $global:IsFallback = $true
                                            }
                                        }
                                        elseif ($global:posterurl -like 'https://assets.fanart.tv*') {
                                            Write-Entry -Subtext "Downloading Poster from 'Fanart.tv'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:FANARTAssetTextLang
                                            $PosterUnknownCount++
                                            if ($global:FavProvider -ne 'FANART') {
                                                $global:IsFallback = $true
                                            }
                                        }
                                        elseif ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                            Write-Entry -Subtext "Downloading Poster from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $global:AssetTextLang = $global:TVDBAssetTextLang
                                            if ($global:FavProvider -ne 'TVDB') {
                                                $global:IsFallback = $true
                                            }
                                        }
                                        elseif ($global:posterurl -like "$PlexUrl*") {
                                            Write-Entry -Subtext "Downloading Poster from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            if ($global:FavProvider -ne 'PLEX') {
                                                $global:IsFallback = $true
                                            }
                                        }
                                        Else {
                                            Write-Entry -Subtext "Downloading Poster from 'IMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                            $PosterUnknownCount++
                                            $global:IsFallback = $true
                                        }
                                    }
                                    if (Get-ChildItem -LiteralPath $SeasonImage -ErrorAction SilentlyContinue) {
                                        # Resize Image to 2000x3000
                                        $Resizeargument = "`"$SeasonImage`" -resize `"$PosterSize^`" -gravity center -extent `"$PosterSize`" `"$SeasonImage`""
                                        Write-Entry -Subtext "Resizing it... " -Path $global:configLogging -Color White -log Info
                                        $logEntry = "`"$magick`" $Resizeargument"
                                        $logEntry | Out-File $magickLog -Append
                                        InvokeMagickCommand -Command $magick -Arguments $Resizeargument
                                    }
                                }
                                if ($global:ImageMagickError -ne 'true') {
                                    if (Get-ChildItem -LiteralPath $SeasonImage -ErrorAction SilentlyContinue) {
                                        # Move file back to original naming with Brackets.
                                        if ($global:IsTruncated -ne $true) {
                                            if ($Upload2Plex -eq 'true') {
                                                try {
                                                    Write-Entry -Subtext "Uploading Artwork to Plex..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                    $fileContent = [System.IO.File]::ReadAllBytes($SeasonImage)
                                                    # Verify variables before uploading
                                                    Write-Entry -Subtext "SeasonImage: $SeasonImage" -Path $global:configLogging -Color Cyan -log Debug
                                                    Write-Entry -Subtext "RatingKey: $($global:SeasonRatingKey)" -Path $global:configLogging -Color Cyan -log Debug
                                                    Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                                    $uri = if ($PlexToken) {
                                                        "$PlexUrl/library/metadata/$($global:SeasonRatingKey)/posters?X-Plex-Token=$PlexToken"
                                                    }
                                                    Else {
                                                        "$PlexUrl/library/metadata/$($global:SeasonRatingKey)/posters"
                                                    }
                                                    Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                                    # Try uploading, capturing the response in detail
                                                    $Upload = Invoke-WebRequest -Uri $uri `
                                                        -Method Post `
                                                        -Headers $extraPlexHeaders `
                                                        -Body $fileContent `
                                                        -ContentType 'application/octet-stream' `
                                                        -SkipHttpErrorCheck `
                                                        -ErrorAction Stop

                                                    if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                                        Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                                        Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                                    }
                                                    else {
                                                        Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                                        Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                                    }
                                                }
                                                catch {
                                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                                    $global:errorCount++
                                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                }
                                            }
                                            try {
                                                # Attempt to move the item
                                                Move-Item -LiteralPath $SeasonImage -Destination $SeasonImageoriginal -Force -ErrorAction Stop

                                                # Log success if move was successful
                                                Write-Entry -Subtext "Added: $SeasonImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                            }
                                            catch {
                                                # Log the error if the move operation fails
                                                Write-Entry -Subtext "Failed to move $SeasonImage to $SeasonImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                                Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                            }
                                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                            $SeasonCount++
                                            $posterCount++
                                        }
                                        Else {
                                            Write-Entry -Subtext "Skipping asset move because text is truncated..." -Path $global:configLogging -Color Yellow -log Warning
                                        }
                                        $seasontemp = New-Object psobject
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $($Titletext + " | Season " + $global:SeasonNumber)
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Season'
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Language" -Value $(if ($TakeLocal) { "false" } Else { if (!$global:AssetTextLang) { "Textless" }Else { $global:AssetTextLang } })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Logo Source" -Value  $(if ($global:LogoUrl) { $global:LogoUrl } Else { "false" })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Logo Language" -Value $(if ($global:LogoLanguage) { $global:LogoLanguage } Else { "false" })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Logo TextFallback" -Value $(if ($ApplyTextInsteadOfLogo) { $ApplyTextInsteadOfLogo } Else { "false" })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value $(if ($global:IsFallback) { 'true' } else { 'false' })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value $(if ($TakeLocal) { $SeasonImage } Else { $global:posterurl })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                        $seasontemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                        switch -Wildcard ($global:FavProvider) {
                                            'TMDB' { $seasontemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                            'FANART' { $seasontemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                            'TVDB' { $seasontemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                            Default { $seasontemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                        }
                                        # Export the array to a CSV file
                                        $seasontemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                                    }
                                }
                            }
                            Elseif ($LocalAssetMissing -eq 'true') {
                                Write-Entry -Subtext "Skipping [$Titletext] - local asset missing and online fetch is disabled." -Path $global:configLogging -Color Yellow -log Warning
                            }
                            Else {
                                Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                $seasontemp = New-Object psobject
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $($Titletext + " | Season " + $global:SeasonNumber)
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Season'
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "Language" -Value 'false'
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value 'false'
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value 'false'
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                $seasontemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                switch -Wildcard ($global:FavProvider) {
                                    'TMDB' { $seasontemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                    'FANART' { $seasontemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                    'TVDB' { $seasontemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                    Default { $seasontemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                }

                                # Export the array to a CSV file
                                $seasontemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                            }
                        }
                        else {
                            if ($global:UploadExistingAssets -eq 'true') {
                                if ($global:PlexSeasonUrl -like "/library/*") {
                                    if ($PlexToken) {
                                        $Arturl = $plexurl + $global:PlexSeasonUrl + "?X-Plex-Token=$PlexToken"
                                    }
                                    Else {
                                        $Arturl = $plexurl + $global:PlexSeasonUrl
                                    }
                                }
                                Write-Entry -Message "Starting Existing Asset Upload..." -Path $global:configLogging -Color Green -log Info
                                try {
                                    GetPlexArtwork -Type " $Titletext | $global:seasontmp Artwork."  -ArtUrl $Arturl -TempImage $SeasonImage
                                    if ($global:PlexartworkDownloaded -eq 'true') {
                                        Write-Entry -Subtext "Uploading Existing Artwork for: $Titletext" -Path $global:configLogging -Color White -log Info
                                        $fileContent = [System.IO.File]::ReadAllBytes($SeasonImageoriginal)
                                        # Verify variables before uploading
                                        Write-Entry -Subtext "SeasonImage: $SeasonImageoriginal" -Path $global:configLogging -Color Cyan -log Debug
                                        Write-Entry -Subtext "RatingKey: $($global:SeasonRatingKey)" -Path $global:configLogging -Color Cyan -log Debug
                                        Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                        $uri = if ($PlexToken) {
                                            "$PlexUrl/library/metadata/$($global:SeasonRatingKey)/posters?X-Plex-Token=$PlexToken"
                                        }
                                        Else {
                                            "$PlexUrl/library/metadata/$($global:SeasonRatingKey)/posters"
                                        }
                                        Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                        # Try uploading, capturing the response in detail
                                        $Upload = Invoke-WebRequest -Uri $uri `
                                            -Method Post `
                                            -Headers $extraPlexHeaders `
                                            -Body $fileContent `
                                            -ContentType 'application/octet-stream' `
                                            -SkipHttpErrorCheck `
                                            -ErrorAction Stop

                                        if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                            Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                            Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                        }
                                        else {
                                            Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                            Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                        }
                                        $UploadCount++
                                    }
                                }
                                catch {
                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                    $global:errorCount++
                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                }
                                if (Test-Path $SeasonImage -ErrorAction SilentlyContinue) {
                                    Remove-Item -LiteralPath $SeasonImage | Out-Null
                                    Write-Entry -Message "Deleting Temp Image: $SeasonImage" -Path $global:configLogging -Color White -log Info
                                }
                            }
                            Else {
                                if ($show_skipped -eq 'true' ) {
                                    Write-Entry -Subtext "Already exists: $SeasonImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                                }
                            }
                        }
                    }
                }
                # Now we can start the Episode Part
                if ($global:TitleCards -eq 'true') {
                    # Loop through each episode
                    foreach ($episode in $Episodedata) {
                        $SkippingText = 'false'

                        $global:AssetTextLang = $null
                        $global:TMDBAssetTextLang = $null
                        $global:FANARTAssetTextLang = $null
                        $global:TVDBAssetTextLang = $null
                        $global:TMDBAssetChangeUrl = $null
                        $global:FANARTAssetChangeUrl = $null
                        $global:TVDBAssetChangeUrl = $null
                        $global:PosterWithText = $null
                        $global:TempImagecopied = $false
                        $EpisodeTempImage = $null
                        $global:ImageMagickError = $null
                        $global:season_number = $null
                        $Episodepostersearchtext = $null
                        $global:show_name = $null
                        $global:episodenumber = $null
                        $global:episode_numbers = $null
                        $global:titles = $null
                        $global:posterurl = $null
                        $global:FileNaming = $null
                        $EpisodeImageoriginal = $null
                        $EpisodeImage = $null
                        $global:Fallback = $null
                        $global:IsFallback = $null
                        $global:FallbackText = $null
                        $global:TextlessPoster = $null
                        $global:EPResolutions = $null

                        if (($episode.tmdbid -eq $entry.tmdbid -or $episode.tvdbid -eq $entry.tvdbid) -and $episode.'Show Name' -eq $entry.title -and $episode.'Library Name' -eq $entry.'Library Name') {
                            $global:show_name = $episode."Show Name"
                            $global:season_number = $episode."Season Number"
                            $global:EPResolutions = $episode."Resolutions".Split(",")
                            $global:episode_numbers = $episode."Episodes".Split(",")
                            $global:episode_ratingkeys = $episode."ratingKeys".Split(",")
                            $global:titles = $episode."Title".Split(";")
                            $global:PlexTitleCardUrls = $episode."PlexTitleCardUrls".Split(",")
                            if ($UseBackgroundAsTitleCard -eq 'true') {
                                $global:ImageMagickError = $null
                                for ($i = 0; $i -lt $global:episode_numbers.Count; $i++) {
                                    $SkippingText = 'false'
                                    $global:AssetTextLang = $null
                                    $global:TMDBAssetTextLang = $null
                                    $global:FANARTAssetTextLang = $null
                                    $global:TVDBAssetTextLang = $null
                                    $global:TMDBAssetChangeUrl = $null
                                    $global:FANARTAssetChangeUrl = $null
                                    $global:TVDBAssetChangeUrl = $null
                                    $global:PosterWithText = $null
                                    $global:Fallback = $null
                                    $global:IsFallback = $null
                                    $global:posterurl = $null
                                    $Episodepostersearchtext = $null
                                    $ExifFound = $null
                                    $global:PlexartworkDownloaded = $null
                                    $value = $null
                                    $magickcommand = $null
                                    $Arturl = $null
                                    $TakeLocal = $null
                                    $LocalAssetMissing = $null
                                    $LocalAddOverlay = $AddTitleCardOverlay
                                    $LocalAddBorder = $AddTitleCardBorder
                                    $global:PlexTitleCardUrl = $entry.PlexBackgroundUrl
                                    $global:episode_ratingkey = $($global:episode_ratingkeys[$i].Trim())
                                    $global:EPTitle = $($global:titles[$i].Trim())
                                    $global:EPResolution = $($global:EPResolutions[$i].Trim())
                                    $global:episodenumber = $($global:episode_numbers[$i].Trim())
                                    $global:FileNaming = "S" + $global:season_number.PadLeft(2, '0') + "E" + $global:episodenumber.PadLeft(2, '0')
                                    $bullet = [char]0x2022
                                    $global:SeasonEPNumber = "$SeasonTCText $global:season_number $bullet $EpisodeTCText $global:episodenumber"

                                    if ($LibraryFolders -eq 'true') {
                                        $EpisodeImageoriginal = "$EntryDir\$global:FileNaming.jpg"
                                        $TestPath = $EntryDir
                                        $ManualTestPath = $ManualEntryDir
                                        $Testfile = "$global:FileNaming"
                                        $TestfileTemplate = "EpisodeTemplate"
                                    }
                                    Else {
                                        if ($entry.extraFolder) {
                                            $EpisodeImageoriginal = "$AssetPath\$($entry.extraFolder)\$($entry.RootFoldername)_$global:FileNaming.jpg"
                                        }
                                        Else {
                                            $EpisodeImageoriginal = "$AssetPath\$($entry.RootFoldername)_$global:FileNaming.jpg"
                                        }
                                        $TestPath = $AssetPath
                                        $ManualTestPath = $ManualPath
                                        $Testfile = "$($entry.RootFoldername)_$global:FileNaming"
                                        $TestfileTemplate = "$($entry.RootFoldername)_EpisodeTemplate"
                                    }

                                    if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                                        $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                                        $EpisodeImageoriginal = ($EpisodeImageoriginal).Replace('\', '/').Replace('./', '/')
                                        $manualtestpath = ($ManualTestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                                        $Templatetestpath = ($ManualEntryDir + "/" + $TestfileTemplate).Replace('\', '/').Replace('./', '/')
                                    }
                                    else {
                                        $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                                        $fullManualTestPath = Resolve-Path -Path $ManualTestPath -ErrorAction SilentlyContinue
                                        if ($fullTestPath) {
                                            $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                                            $Manualtestpath = ($fullManualTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                                            $Templatetestpath = ($fullManualTestPath.ProviderPath + "\" + $TestfileTemplate).Replace('/', '\')
                                        }
                                        Else {
                                            $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                                            $Manualtestpath = ($ManualTestPath + "\" + $Testfile).Replace('/', '\')
                                            $Templatetestpath = ($ManualEntryDir + "\" + $TestfileTemplate).Replace('/', '\')
                                        }
                                    }

                                    Write-Entry -Message "Test Path is: $TestPath" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Message "Test File is: $Testfile" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Message "Resolved Full Test Path is: $fullTestPath" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Message "Resolved hash Test Path is: $hashtestpath" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Message "Manual Test Path is: $ManualTestPath" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Message "Resolved Manual Test Path is: $Manualtestpath" -Path $global:configLogging -Color Cyan -log Debug
                                    Write-Entry -Message "Resolved Manual Full Test Path is: $fullManualTestPath" -Path $global:configLogging -Color Cyan -log Debug

                                    $EpisodeImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername)_$global:FileNaming.jpg"
                                    $EpisodeImage = $EpisodeImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')

                                    $EpisodeTempImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\temp.jpg"
                                    $cjkTitlePattern = '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}\p{IsThai}]'

                                    # Pre-check the title against skipwords
                                    $matchedWord = $null
                                    foreach ($word in $SkipWords) {
                                        if ($global:EPTitle -match "^$([regex]::Escape($word))") {
                                            $matchedWord = $word
                                            break # Stop checking once we find a match
                                        }
                                    }

                                    if ($SkipTBA -eq 'true' -and $matchedWord) {
                                        Write-Entry -Subtext "Skipping $global:FileNaming of $global:show_name because Title matches '$matchedWord'" -Path $global:configLogging -Color Yellow -log Warning
                                        $SkipTBACount++
                                    }
                                    Elseif ($SkipJapTitle -eq 'true' -and $global:EPTitle -match $cjkTitlePattern) {
                                        Write-Entry -Subtext "Skipping $global:FileNaming of $global:show_name because Title contains Jap/Chinese Chars" -Path $global:configLogging -Color Yellow -log Warning
                                        $SkipJapTitleCount++
                                    }
                                    Else {
                                        $checkedItems.Add($hashtestpath)

                                        if (-not $directoryHashtable.ContainsKey("$hashtestpath")) {
                                            $Arturl = $null
                                            if ($global:PlexTitleCardUrl -like "/library/*") {
                                                if ($PlexToken) {
                                                    $Arturl = $plexurl + $global:PlexTitleCardUrl + "?X-Plex-Token=$PlexToken"
                                                }
                                                Else {
                                                    $Arturl = $plexurl + $global:PlexTitleCardUrl
                                                }
                                            }
                                            foreach ($ext in $allowedExtensions) {
                                                $manualFile = "$ManualTestPath$ext"
                                                $templateFile = "$Templatetestpath$ext"
                                                $filePath = $null

                                                if (Test-Path -LiteralPath $manualFile) {
                                                    $filePath = $manualFile
                                                }
                                                elseif (Test-Path -LiteralPath $templateFile) {
                                                    $filePath = $templateFile
                                                }

                                                if ($filePath) {
                                                    Write-Entry -Message "Local file exists: $filePath" -Path $global:configLogging -Color Cyan -log Debug
                                                    $posterext = $ext
                                                    break
                                                }
                                            }
                                            if ((Test-Path -LiteralPath "$($Manualtestpath)$posterext") -and $Manualtestpath -ne '\') {
                                                Write-Entry -Message "Found Manual Title Card for: $global:show_name - $global:SeasonEPNumber" -Path $global:configLogging -Color White -log Info
                                                $TakeLocal = $true
                                                $Episodepostersearchtext = $true
                                            }
                                            elseif ((Test-Path -LiteralPath "$($Templatetestpath)$posterext") -and $Templatetestpath -ne '\') {
                                                Write-Entry -Message "Found Template Poster..." -Path $global:configLogging -Color White -log Info
                                                $ManualTestPath = $Templatetestpath
                                                $TakeLocal = $true
                                            }
                                            Elseif ($global:DisableOnlineAssetFetch -eq 'true') {
                                                $LocalAssetMissing = 'true'
                                            }
                                            Else {
                                                if (!$Episodepostersearchtext) {
                                                    Write-Entry -Message "Start Title Card Search for: $global:show_name - $global:SeasonEPNumber" -Path $global:configLogging -Color White -log Info
                                                    $Episodepostersearchtext = $true
                                                }
                                                if ($global:TempImagecopied -ne 'true') {
                                                    # now search for TitleCards
                                                    if ($global:FavProvider -eq 'TMDB') {
                                                        if ($episode.tmdbid) {
                                                            $global:posterurl = GetTMDBShowBackground
                                                            if (!$global:posterurl) {
                                                                $global:posterurl = GetTVDBShowBackground
                                                                if (!$global:posterurl) {
                                                                    $global:posterurl = GetFanartShowBackground
                                                                }
                                                            }
                                                            if (!$global:posterurl) {
                                                                $global:IsFallback = $true
                                                                if ($ArtUrl) {
                                                                    GetPlexArtwork -Type ": $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card" -ArtUrl $ArtUrl -TempImage $EpisodeImage
                                                                }
                                                                Else {
                                                                    Write-Entry -Subtext "Plex TitleCard Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                                                }
                                                                if ($global:tmdbfallbackposterurl) {
                                                                    $global:posterurl = $global:tmdbfallbackposterurl
                                                                }
                                                                if (!$global:posterurl) {
                                                                    Write-Entry -Subtext "Could not find a TitleCard on any site" -Path $global:configLogging -Color Red -log Error
                                                                    $global:IsFallback = $false
                                                                }
                                                            }
                                                        }
                                                        else {
                                                            Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
                                                            $global:posterurl = GetTVDBShowBackground
                                                            if (!$global:posterurl) {
                                                                $global:posterurl = GetFanartShowBackground
                                                            }
                                                            if (!$global:posterurl) {
                                                                $global:IsFallback = $true
                                                                if ($ArtUrl) {
                                                                    GetPlexArtwork -Type ": $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card" -ArtUrl $ArtUrl -TempImage $EpisodeImage
                                                                }
                                                                Else {
                                                                    Write-Entry -Subtext "Plex TitleCard Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                                                }
                                                                if (!$global:posterurl) {
                                                                    Write-Entry -Subtext "Could not find a TitleCard on any site" -Path $global:configLogging -Color Red -log Error
                                                                    $global:IsFallback = $false
                                                                }
                                                            }
                                                        }
                                                    }
                                                    Else {
                                                        if ($episode.tvdbid) {
                                                            $global:posterurl = GetTVDBShowBackground
                                                            if (!$global:posterurl) {
                                                                $global:posterurl = GetTMDBShowBackground
                                                                if (!$global:posterurl) {
                                                                    $global:posterurl = GetFanartShowBackground
                                                                }
                                                            }
                                                            if (!$global:posterurl) {
                                                                $global:IsFallback = $true
                                                                if ($ArtUrl) {
                                                                    GetPlexArtwork -Type ": $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card" -ArtUrl $ArtUrl -TempImage $EpisodeImage
                                                                }
                                                                Else {
                                                                    Write-Entry -Subtext "Plex TitleCard Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                                                }
                                                                if (!$global:posterurl) {
                                                                    Write-Entry -Subtext "Could not find a TitleCard on any site" -Path $global:configLogging -Color Red -log Error
                                                                    $global:IsFallback = $false
                                                                }
                                                            }
                                                        }
                                                        else {
                                                            Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
                                                            $global:posterurl = GetTMDBShowBackground
                                                            if (!$global:posterurl) {
                                                                $global:posterurl = GetFanartShowBackground
                                                            }
                                                            if (!$global:posterurl) {
                                                                $global:IsFallback = $true
                                                                if ($ArtUrl) {
                                                                    GetPlexArtwork -Type ": $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card" -ArtUrl $ArtUrl -TempImage $EpisodeImage
                                                                }
                                                                Else {
                                                                    Write-Entry -Subtext "Plex TitleCard Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                                                }
                                                                if (!$global:posterurl) {
                                                                    Write-Entry -Subtext "Could not find a TitleCard on any site" -Path $global:configLogging -Color Red -log Error
                                                                    $global:IsFallback = $false
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            if ($global:posterurl -or $global:PlexartworkDownloaded -or $TakeLocal -or $global:TempImagecopied -eq 'true') {
                                                $global:IsTruncated = $null
                                                if ($global:ImageProcessing -eq 'true') {
                                                    if ($TakeLocal) {
                                                        Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                                            Copy-Item -LiteralPath $_.FullName -Destination $EpisodeImage | Out-Null
                                                        }
                                                        if ($global:TempImagecopied -ne 'true') {
                                                            Copy-Item -LiteralPath $EpisodeImage -destination $EpisodeTempImage | Out-Null
                                                        }
                                                        if ($SkipLocalTCTextAdd -eq 'true') {
                                                            $SkippingText = 'true'
                                                        }
                                                        Write-Entry -Subtext "Copy local asset to: $EpisodeImage" -Path $global:configLogging -Color Green -log Info
                                                    }
                                                    Else {
                                                        try {
                                                            if (!$global:PlexartworkDownloaded -and $global:TempImagecopied -ne 'true') {
                                                                $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $EpisodeImage -ErrorAction Stop
                                                                Copy-Item -LiteralPath $EpisodeImage -destination $EpisodeTempImage | Out-Null
                                                            }
                                                        }
                                                        catch {
                                                            if ($_.Exception.Response) {
                                                                $statusCode = $_.Exception.Response.StatusCode.value__
                                                            }
                                                            else {
                                                                $statusCode = $_.Exception.Message
                                                            }
                                                            Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                        }
                                                        if ($global:TempImagecopied -ne 'true') {
                                                            Write-Entry -Subtext "Title Card url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                                            if ($global:posterurl -like 'https://image.tmdb.org*') {
                                                                Write-Entry -Subtext "Downloading Title Card from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                                $global:AssetTextLang = $global:TMDBAssetTextLang
                                                                if ($global:FavProvider -ne 'TMDB') {
                                                                    $global:IsFallback = $true
                                                                }
                                                            }
                                                            if ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                                                Write-Entry -Subtext "Downloading Title Card from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                                $global:AssetTextLang = $global:TVDBAssetTextLang
                                                                if ($global:FavProvider -ne 'TVDB') {
                                                                    $global:IsFallback = $true
                                                                }
                                                            }
                                                            if ($global:posterurl -like "$PlexUrl*") {
                                                                Write-Entry -Subtext "Downloading Title Card from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                                if ($global:FavProvider -ne 'PLEX') {
                                                                    $global:IsFallback = $true
                                                                }
                                                            }
                                                        }
                                                        Else {
                                                            Write-Entry -Subtext "Taking temp image..." -Path $global:configLogging -Color Green -log Info
                                                            Copy-Item -LiteralPath $EpisodeTempImage -destination $EpisodeImage | Out-Null
                                                        }
                                                    }
                                                    $global:TempImagecopied = $true
                                                    # Check temp image
                                                    if ((Get-ChildItem -LiteralPath $EpisodeTempImage -ErrorAction SilentlyContinue).length -eq '0') {
                                                        Write-Entry -Subtext "Temp image is corrupt, cannot proceed" -Path $global:configLogging -Color Red -log Error
                                                        $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                    }
                                                    Else {
                                                        if (Get-ChildItem -LiteralPath $EpisodeImage -ErrorAction SilentlyContinue) {
                                                            $CommentArguments = "`"$EpisodeImage`" -set `"comment`" `"created with posterizarr`" `"$EpisodeImage`""
                                                            $CommentlogEntry = "`"$magick`" $CommentArguments"
                                                            $CommentlogEntry | Out-File $magickLog -Append
                                                            InvokeMagickCommand -Command $magick -Arguments $CommentArguments
                                                            if ($global:ImageMagickError -ne 'true') {
                                                                if ($UseTCResolutionOverlays -eq 'true') {
                                                                    switch ($global:EPResolution) {
                                                                        '4K DoVi/HDR10' { $TitleCardoverlay = $4KDoViHDR10TC }
                                                                        '4K DoVi' { $TitleCardoverlay = $4KDoViTC }
                                                                        '4K HDR10' { $TitleCardoverlay = $4KHDR10TC }
                                                                        '4K' { $TitleCardoverlay = $4kTC }
                                                                        '1080p' { $TitleCardoverlay = $1080pTC }
                                                                        Default { $TitleCardoverlay = $DefaultTitleCardoverlay }
                                                                    }
                                                                }
                                                                Else {
                                                                    $TitleCardoverlay = $DefaultTitleCardoverlay
                                                                }
                                                                # Logic for SkipAddTextAndOverlay (Skip Overlay, keep Border)
                                                                if (($SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                                                    $LocalAddOverlay = 'false'
                                                                }

                                                                # Logic for SkipAddTextAndBorder (Skip Border, keep Overlay)
                                                                if (($SkipAddTextAndBorder -eq 'true') -and $global:PosterWithText) {
                                                                    $LocalAddBorder = 'false'
                                                                }

                                                                # Logic for "If both are true, only resize"
                                                                if ($SkipAddTextAndOverlay -eq 'true' -and $SkipAddTextAndBorder -eq 'true' -and $global:PosterWithText) {
                                                                    $LocalAddBorder = 'false'
                                                                    $LocalAddOverlay = 'false'
                                                                }
                                                                # Resize Image to 2000x3000 and apply Border and overlay
                                                                if ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'true') {
                                                                    $Arguments = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$TitleCardoverlay`" -gravity south -quality $global:outputQuality -composite -shave `"$TitleCardborderwidthsecond`"  -bordercolor `"$TitleCardbordercolor`" -border `"$TitleCardborderwidth`" `"$EpisodeImage`""
                                                                    Write-Entry -Subtext "Resizing it | Adding Borders | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                                                }
                                                                elseif ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'false') {
                                                                    $Arguments = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" -shave `"$TitleCardborderwidthsecond`"  -bordercolor `"$TitleCardbordercolor`" -border `"$TitleCardborderwidth`" `"$EpisodeImage`""
                                                                    Write-Entry -Subtext "Resizing it | Adding Borders" -Path $global:configLogging -Color White -log Info
                                                                }
                                                                elseif ($LocalAddBorder -eq 'false' -and $LocalAddOverlay -eq 'true') {
                                                                    $Arguments = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$TitleCardoverlay`" -gravity south -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                    Write-Entry -Subtext "Resizing it | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                                                }
                                                                else {
                                                                    $Arguments = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$EpisodeImage`""
                                                                    Write-Entry -Subtext "Resizing it" -Path $global:configLogging -Color White -log Info
                                                                }
                                                                $logEntry = "`"$magick`" $Arguments"
                                                                $logEntry | Out-File $magickLog -Append
                                                                InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                                if (($SkipAddText -eq 'true' -or $SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                                                    $SkippingText = 'true'
                                                                    Write-Entry -Subtext "Skipping 'AddText' because poster already has text." -Path $global:configLogging -Color Yellow -log Info
                                                                }
                                                                if ($AddTitleCardEPTitleText -eq 'true' -and $SkippingText -eq 'false') {
                                                                    if ($TitleCardEPTitlefontAllCaps -eq 'true') {
                                                                        $global:EPTitle = $global:EPTitle.ToUpper()
                                                                    }
                                                                    $global:EPTitle = $global:EPTitle -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''

                                                                    if ($global:direction -eq "RTL") {
                                                                        $TitleCardfontImagemagick = $RTLfontImagemagick
                                                                    }
                                                                    # Loop through each symbol and replace it with a newline
                                                                    if ($NewLineOnSpecificSymbols -eq 'true') {
                                                                        foreach ($symbol in $NewLineSymbols) {
                                                                            # Replace the symbol with a newline
                                                                            $replacementString = "`n"

                                                                            # Check if the symbol should be kept
                                                                            $keepThisSymbol = $false
                                                                            if ($null -ne $SymbolsToKeepOnNewLine) {
                                                                                # Loop through all items in $SymbolsToKeepOnNewLine (in case it's an array like [':', '!'])
                                                                                foreach ($k in $SymbolsToKeepOnNewLine) {
                                                                                    # Check if the $symbol (e.g., ": ") contains the $k character (e.g., ":")
                                                                                    if ($symbol -like "*$k*") {
                                                                                        $keepThisSymbol = $true
                                                                                        break # Match found, no need to keep checking
                                                                                    }
                                                                                }
                                                                            }

                                                                            # If it's a "keep" symbol, change the replacement string
                                                                            if ($keepThisSymbol) {
                                                                                # Replace ": " with ": \n" (keeps the symbol, adds newline after)
                                                                                $replacementString = $symbol + "`n"
                                                                            }
                                                                            $global:EPTitle = $global:EPTitle -replace [regex]::Escape($symbol), $replacementString
                                                                        }
                                                                    }
                                                                    if ($NewLineOnSpecificWords -eq 'true' -and $null -ne $NewLineWords) {
                                                                        $properties = $NewLineWords.PSObject.Properties.Name

                                                                        # Check if properties exist and the list is not empty
                                                                        if ($null -ne $properties -and $properties.Count -gt 0) {
                                                                            foreach ($wordKey in $properties) {
                                                                                $replacementValue = $NewLineWords.$wordKey

                                                                                # Using [regex]::Escape handles any special characters in the word keys
                                                                                $global:EPTitle = $global:EPTitle -replace [regex]::Escape($wordKey), $replacementValue
                                                                            }
                                                                        }
                                                                    }
                                                                    $joinedTitlePointSize = $global:EPTitle -replace '""', '""""'
                                                                    $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $TitleCardfontImagemagick -box_width $TitleCardEPTitleMaxWidth  -box_height $TitleCardEPTitleMaxHeight -min_pointsize $TitleCardEPTitleminPointSize -max_pointsize $TitleCardEPTitlemaxPointSize -lineSpacing $TitleCardEPTitlelineSpacing
                                                                    if ($global:IsTruncated -ne $true) {
                                                                        Write-Entry -Subtext ("Optimal font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                                        # Add Stroke
                                                                        if ($AddTitleCardEPTitleTextStroke -eq 'true') {
                                                                            $Arguments = "`"$EpisodeImage`" -gravity center -background None -layers Flatten `( -size `"$TitleCardEPTitleboxsize`" -background none `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPTitlestrokecolor`" -stroke `"$TitleCardEPTitlestrokecolor`" -strokewidth `"$TitleCardEPTitlestrokewidth`" -size `"$TitleCardEPTitleboxsize`" -background none -interline-spacing `"$TitleCardEPTitlelineSpacing`" -gravity `"$TitleCardEPTitletextgravity`" caption:`"$global:EPTitle`" `) `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPTitlefontcolor`" -stroke none -size `"$TitleCardEPTitleboxsize`" -background none -interline-spacing `"$TitleCardEPTitlelineSpacing`" -gravity `"$TitleCardEPTitletextgravity`" caption:`"$global:EPTitle`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$TitleCardEPTitleboxsize`" `) -gravity south -geometry +0`"$TitleCardEPTitletext_offset`" -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                        }
                                                                        Else {
                                                                            $Arguments = "`"$EpisodeImage`" -gravity center -background None -layers Flatten `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPTitlefontcolor`" -size `"$TitleCardEPTitleboxsize`" -background none -interline-spacing `"$TitleCardEPTitlelineSpacing`" -gravity `"$TitleCardEPTitletextgravity`" caption:`"$global:EPTitle`" -trim +repage -extent `"$TitleCardEPTitleboxsize`" `) -gravity south -geometry +0`"$TitleCardEPTitletext_offset`" -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                        }
                                                                        Write-Entry -Subtext "Applying EPTitle text: `"$global:EPTitle`"" -Path $global:configLogging -Color White -log Info
                                                                        $logEntry = "`"$magick`" $Arguments"
                                                                        $logEntry | Out-File $magickLog -Append
                                                                        InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                                    }
                                                                }
                                                                if ($AddTitleCardEPText -eq 'true' -and $SkippingText -eq 'false') {
                                                                    if ($TitleCardEPfontAllCaps -eq 'true') {
                                                                        $global:SeasonEPNumber = $global:SeasonEPNumber.ToUpper()
                                                                    }
                                                                    $global:SeasonEPNumber = $global:SeasonEPNumber -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                                    $joinedTitlePointSize = $global:SeasonEPNumber -replace '""', '""""'
                                                                    $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $TitleCardfontImagemagick -box_width $TitleCardEPMaxWidth  -box_height $TitleCardEPMaxHeight -min_pointsize $TitleCardEPminPointSize -max_pointsize $TitleCardEPmaxPointSize -lineSpacing $TitleCardEPlineSpacing
                                                                    if ($global:IsTruncated -ne $true) {
                                                                        Write-Entry -Subtext ("Optimal font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                                        # Add Stroke
                                                                        if ($AddTitleCardTextStroke -eq 'true') {
                                                                            $Arguments = "`"$EpisodeImage`" -gravity center -background None -layers Flatten `( -size `"$TitleCardEPboxsize`" -background none `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardstrokecolor`" -stroke `"$TitleCardstrokecolor`" -strokewidth `"$TitleCardstrokewidth`" -size `"$TitleCardEPboxsize`" -background none -interline-spacing `"$TitleCardEPlineSpacing`" -gravity `"$TitleCardEPtextgravity`" caption:`"$global:SeasonEPNumber`" `) `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPfontcolor`" -stroke none -size `"$TitleCardEPboxsize`" -background none -interline-spacing `"$TitleCardEPlineSpacing`" -gravity `"$TitleCardEPtextgravity`" caption:`"$global:SeasonEPNumber`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$TitleCardEPboxsize`" `) -gravity south -geometry +0`"$TitleCardEPtext_offset`" -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                        }
                                                                        Else {
                                                                            $Arguments = "`"$EpisodeImage`" -gravity center -background None -layers Flatten `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPfontcolor`" -size `"$TitleCardEPboxsize`" -background none -interline-spacing `"$TitleCardEPlineSpacing`" -gravity `"$TitleCardEPtextgravity`" caption:`"$global:SeasonEPNumber`" -trim +repage -extent `"$TitleCardEPboxsize`" `) -gravity south -geometry +0`"$TitleCardEPtext_offset`" -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                        }

                                                                        Write-Entry -Subtext "Applying SeasonEPNumber text: `"$global:SeasonEPNumber`"" -Path $global:configLogging -Color White -log Info
                                                                        $logEntry = "`"$magick`" $Arguments"
                                                                        $logEntry | Out-File $magickLog -Append
                                                                        InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                Else {
                                                    if ($TakeLocal) {
                                                        Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                                            Copy-Item -LiteralPath $_.FullName -Destination $EpisodeImage
                                                        }
                                                        if ($SkipLocalTCTextAdd -eq 'true') {
                                                            $SkippingText = 'true'
                                                        }
                                                        Write-Entry -Subtext "Copy local asset to: $EpisodeImage" -Path $global:configLogging -Color Green -log Info
                                                    }
                                                    Else {
                                                        try {
                                                            if (!$global:PlexartworkDownloaded) {
                                                                $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $EpisodeImage -ErrorAction Stop
                                                            }
                                                        }
                                                        catch {
                                                            if ($_.Exception.Response) {
                                                                $statusCode = $_.Exception.Response.StatusCode.value__
                                                            }
                                                            else {
                                                                $statusCode = $_.Exception.Message
                                                            }
                                                            Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                        }
                                                        Write-Entry -Subtext "Title Card url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                                        if ($global:posterurl -like 'https://image.tmdb.org*') {
                                                            Write-Entry -Subtext "Downloading Title Card from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:AssetTextLang = $global:TMDBAssetTextLang
                                                            if ($global:FavProvider -ne 'TMDB') {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        if ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                                            Write-Entry -Subtext "Downloading Title Card from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:AssetTextLang = $global:TVDBAssetTextLang
                                                            if ($global:FavProvider -ne 'TVDB') {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        if ($global:posterurl -like "$PlexUrl*") {
                                                            Write-Entry -Subtext "Downloading Title Card from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                            if ($global:FavProvider -ne 'PLEX') {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                    }
                                                    if (Get-ChildItem -LiteralPath $EpisodeImage -ErrorAction SilentlyContinue) {
                                                        # Resize Image to 2000x3000
                                                        $Resizeargument = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$EpisodeImage`""
                                                        Write-Entry -Subtext "Resizing it... " -Path $global:configLogging -Color White -log Info
                                                        $logEntry = "`"$magick`" $Resizeargument"
                                                        $logEntry | Out-File $magickLog -Append
                                                        InvokeMagickCommand -Command $magick -Arguments $Resizeargument
                                                    }
                                                }
                                                if ($global:ImageMagickError -ne 'true') {
                                                    if (Get-ChildItem -LiteralPath $EpisodeImage -ErrorAction SilentlyContinue) {
                                                        # Move file back to original naming with Brackets.
                                                        if ($global:IsTruncated -ne $true) {
                                                            if ($Upload2Plex -eq 'true') {
                                                                try {
                                                                    Write-Entry -Subtext "Uploading Artwork to Plex..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                                    $fileContent = [System.IO.File]::ReadAllBytes($EpisodeImage)
                                                                    # Verify variables before uploading
                                                                    Write-Entry -Subtext "EpisodeImage: $EpisodeImage" -Path $global:configLogging -Color Cyan -log Debug
                                                                    Write-Entry -Subtext "RatingKey: $($global:episode_ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                                                    Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                                                    $uri = if ($PlexToken) {
                                                                        "$PlexUrl/library/metadata/$($global:episode_ratingkey)/posters?X-Plex-Token=$PlexToken"
                                                                    }
                                                                    Else {
                                                                        "$PlexUrl/library/metadata/$($global:episode_ratingkey)/posters"
                                                                    }
                                                                    Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                                                    # Try uploading, capturing the response in detail
                                                                    $Upload = Invoke-WebRequest -Uri $uri `
                                                                        -Method Post `
                                                                        -Headers $extraPlexHeaders `
                                                                        -Body $fileContent `
                                                                        -ContentType 'application/octet-stream' `
                                                                        -SkipHttpErrorCheck `
                                                                        -ErrorAction Stop

                                                                    if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                                                        Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                                                        Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                                                    }
                                                                    else {
                                                                        Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                                                        Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                                                    }
                                                                }
                                                                catch {
                                                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                                                    $global:errorCount++
                                                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                                }
                                                            }
                                                            try {
                                                                # Attempt to move the item
                                                                Move-Item -LiteralPath $EpisodeImage -Destination $EpisodeImageoriginal -Force -ErrorAction Stop

                                                                # Log success if move was successful
                                                                Write-Entry -Subtext "Added: $EpisodeImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                                            }
                                                            catch {
                                                                # Log the error if the move operation fails
                                                                Write-Entry -Subtext "Failed to move $EpisodeImage to $EpisodeImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                                                Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                            }
                                                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                                            $EpisodeCount++
                                                            $posterCount++
                                                        }
                                                        Else {
                                                            Write-Entry -Subtext "Skipping asset move because text is truncated..." -Path $global:configLogging -Color Yellow -log Warning
                                                        }
                                                        $episodetemp = New-Object psobject
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $($global:FileNaming + " | " + $global:EPTitle)
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Episode'
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Language" -Value $(if ($TakeLocal) { "false" } Else { if (!$global:AssetTextLang) { "Textless" }Else { $global:AssetTextLang } })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Logo Source" -Value  $(if ($global:LogoUrl) { $global:LogoUrl } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Logo Language" -Value $(if ($global:LogoLanguage) { $global:LogoLanguage } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Logo TextFallback" -Value $(if ($ApplyTextInsteadOfLogo) { $ApplyTextInsteadOfLogo } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value $(if ($global:IsFallback -and $global:FallbackText) { $global:FallbackText } elseif ($global:IsFallback -and !$global:FallbackText) { 'true' } Else { 'false' })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value $(if ($TakeLocal) { $EpisodeImage } Else { $global:posterurl })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                                        switch -Wildcard ($global:FavProvider) {
                                                            'TMDB' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                                            'FANART' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                                            'TVDB' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                                            Default { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                                        }
                                                        # Export the array to a CSV file
                                                        $episodetemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                                                    }
                                                }
                                            }
                                            Elseif ($LocalAssetMissing -eq 'true') {
                                                Write-Entry -Subtext "Skipping [$global:show_name - $global:SeasonEPNumber] - local asset missing and online fetch is disabled." -Path $global:configLogging -Color Yellow -log Warning
                                            }
                                            Else {
                                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                if ($global:BackgroundOnlyTextless) {
                                                    $episodetemp = New-Object psobject
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $($global:FileNaming + " | " + $global:EPTitle)
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Episode'
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Language" -Value 'false'
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value 'false'
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value 'false'
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                                    switch -Wildcard ($global:FavProvider) {
                                                        'TMDB' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                                        'FANART' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                                        'TVDB' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                                        Default { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                                    }

                                                    # Export the array to a CSV file
                                                    $episodetemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                                                }

                                            }

                                        }
                                        else {
                                            if ($global:UploadExistingAssets -eq 'true') {
                                                if ($global:PlexTitleCardUrl -like "/library/*") {
                                                    if ($PlexToken) {
                                                        $Arturl = $plexurl + $global:PlexTitleCardUrl + "?X-Plex-Token=$PlexToken"
                                                    }
                                                    Else {
                                                        $Arturl = $plexurl + $global:PlexTitleCardUrl
                                                    }
                                                }
                                                Write-Entry -Message "Starting Existing Asset Upload..." -Path $global:configLogging -Color Green -log Info
                                                try {
                                                    GetPlexArtwork -Type " $Titletext | $global:FileNaming Artwork." -ArtUrl $Arturl -TempImage $EpisodeImage
                                                    if ($global:PlexartworkDownloaded -eq 'true') {
                                                        Write-Entry -Subtext "Uploading Existing Artwork for: $Titletext" -Path $global:configLogging -Color White -log Info
                                                        $fileContent = [System.IO.File]::ReadAllBytes($EpisodeImageoriginal)
                                                        # Verify variables before uploading
                                                        Write-Entry -Subtext "EpisodeImage: $EpisodeImageoriginal" -Path $global:configLogging -Color Cyan -log Debug
                                                        Write-Entry -Subtext "RatingKey: $($global:episode_ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                                        Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                                        $uri = if ($PlexToken) {
                                                            "$PlexUrl/library/metadata/$($global:episode_ratingkey)/posters?X-Plex-Token=$PlexToken"
                                                        }
                                                        Else {
                                                            "$PlexUrl/library/metadata/$($global:episode_ratingkey)/posters"
                                                        }
                                                        Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                                        # Try uploading, capturing the response in detail
                                                        $Upload = Invoke-WebRequest -Uri $uri `
                                                            -Method Post `
                                                            -Headers $extraPlexHeaders `
                                                            -Body $fileContent `
                                                            -ContentType 'application/octet-stream' `
                                                            -SkipHttpErrorCheck `
                                                            -ErrorAction Stop

                                                        if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                                            Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                                            Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                                        }
                                                        else {
                                                            Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                                            Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                                        }
                                                        $UploadCount++
                                                    }
                                                }
                                                catch {
                                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                                    $global:errorCount++
                                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                }
                                                if (Test-Path $EpisodeImage -ErrorAction SilentlyContinue) {
                                                    Remove-Item -LiteralPath $EpisodeImage | Out-Null
                                                    Write-Entry -Message "Deleting Temp Image: $EpisodeImage" -Path $global:configLogging -Color White -log Info
                                                }
                                            }
                                            Else {
                                                if ($show_skipped -eq 'true' ) {
                                                    Write-Entry -Subtext "Already exists: $EpisodeImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                                                }
                                            }
                                        }
                                    }
                                }
                                if (Test-Path $EpisodeTempImage -ErrorAction SilentlyContinue) {
                                    Remove-Item -LiteralPath $EpisodeTempImage | Out-Null
                                    Write-Entry -Message "Deleting EpisodeTempImage: $EpisodeTempImage" -Path $global:configLogging -Color White -log Info
                                }
                            }
                            Else {
                                for ($i = 0; $i -lt $global:episode_numbers.Count; $i++) {
                                    $SkippingText = 'false'

                                    $global:AssetTextLang = $null
                                    $global:TMDBAssetTextLang = $null
                                    $global:FANARTAssetTextLang = $null
                                    $global:TVDBAssetTextLang = $null
                                    $global:TMDBAssetChangeUrl = $null
                                    $global:FANARTAssetChangeUrl = $null
                                    $global:TVDBAssetChangeUrl = $null
                                    $global:PosterWithText = $null
                                    $global:Fallback = $null
                                    $global:IsFallback = $null
                                    $global:FallbackText = $null
                                    $global:ImageMagickError = $null
                                    $global:TextlessPoster = $null
                                    $global:posterurl = $null
                                    $Episodepostersearchtext = $null
                                    $ExifFound = $null
                                    $global:PlexartworkDownloaded = $null
                                    $value = $null
                                    $magickcommand = $null
                                    $Arturl = $null
                                    $TakeLocal = $null
                                    $LocalAssetMissing = $null
                                    $LocalAddOverlay = $AddTitleCardOverlay
                                    $LocalAddBorder = $AddTitleCardBorder
                                    $global:PlexTitleCardUrl = $($global:PlexTitleCardUrls[$i].Trim())
                                    $global:episode_ratingkey = $($global:episode_ratingkeys[$i].Trim())
                                    $global:EPTitle = $($global:titles[$i].Trim())
                                    $global:EPResolution = $($global:EPResolutions[$i].Trim())
                                    $global:episodenumber = $($global:episode_numbers[$i].Trim())
                                    $global:FileNaming = "S" + $global:season_number.PadLeft(2, '0') + "E" + $global:episodenumber.PadLeft(2, '0')
                                    $bullet = [char]0x2022
                                    $global:SeasonEPNumber = "$SeasonTCText $global:season_number $bullet $EpisodeTCText $global:episodenumber"

                                    if ($LibraryFolders -eq 'true') {
                                        $EpisodeImageoriginal = "$EntryDir\$global:FileNaming.jpg"
                                        $TestPath = $EntryDir
                                        $ManualTestPath = $ManualEntryDir
                                        $Testfile = "$global:FileNaming"
                                        $TestfileTemplate = "EpisodeTemplate"
                                    }
                                    Else {
                                        if ($entry.extraFolder) {
                                            $EpisodeImageoriginal = "$AssetPath\$($entry.extraFolder)\$($entry.RootFoldername)_$global:FileNaming.jpg"
                                        }
                                        Else {
                                            $EpisodeImageoriginal = "$AssetPath\$($entry.RootFoldername)_$global:FileNaming.jpg"
                                        }
                                        $TestPath = $AssetPath
                                        $ManualTestPath = $ManualPath
                                        $Testfile = "$($entry.RootFoldername)_$global:FileNaming"
                                        $TestfileTemplate = "$($entry.RootFoldername)_EpisodeTemplate"
                                    }

                                    if ($Platform -eq 'Docker' -or $Platform -eq 'Linux' -or $Platform -eq 'macOS') {
                                        $hashtestpath = ($TestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                                        $EpisodeImageoriginal = ($EpisodeImageoriginal).Replace('\', '/').Replace('./', '/')
                                        $manualtestpath = ($ManualTestPath + "/" + $Testfile).Replace('\', '/').Replace('./', '/')
                                        $Templatetestpath = ($ManualEntryDir + "/" + $TestfileTemplate).Replace('\', '/').Replace('./', '/')
                                    }
                                    else {
                                        $fullTestPath = Resolve-Path -Path $TestPath -ErrorAction SilentlyContinue
                                        $fullManualTestPath = Resolve-Path -Path $ManualTestPath -ErrorAction SilentlyContinue
                                        if ($fullTestPath) {
                                            $hashtestpath = ($fullTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                                            $Manualtestpath = ($fullManualTestPath.ProviderPath + "\" + $Testfile).Replace('/', '\')
                                            $Templatetestpath = ($fullManualTestPath.ProviderPath + "\" + $TestfileTemplate).Replace('/', '\')
                                        }
                                        Else {
                                            $hashtestpath = ($TestPath + "\" + $Testfile).Replace('/', '\')
                                            $Manualtestpath = ($ManualTestPath + "\" + $Testfile).Replace('/', '\')
                                            $Templatetestpath = ($ManualEntryDir + "\" + $TestfileTemplate).Replace('/', '\')
                                        }
                                    }

                                    $EpisodeImage = Join-Path -Path $global:ScriptRoot -ChildPath "temp\$($entry.RootFoldername)_$global:FileNaming.jpg"
                                    $EpisodeImage = $EpisodeImage.Replace('[', '_').Replace(']', '_').Replace('{', '_').Replace('}', '_')
                                    $cjkTitlePattern = '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}\p{IsThai}]'

                                    # Pre-check the title against skipwords
                                    $matchedWord = $null
                                    foreach ($word in $SkipWords) {
                                        if ($global:EPTitle -match "^$([regex]::Escape($word))") {
                                            $matchedWord = $word
                                            break # Stop checking once we find a match
                                        }
                                    }

                                    if ($SkipTBA -eq 'true' -and $matchedWord) {
                                        Write-Entry -Subtext "Skipping $global:FileNaming of $global:show_name because Title matches '$matchedWord'" -Path $global:configLogging -Color Yellow -log Warning
                                        $SkipTBACount++
                                    }
                                    Elseif ($SkipJapTitle -eq 'true' -and $global:EPTitle -match $cjkTitlePattern) {
                                        Write-Entry -Subtext "Skipping $global:FileNaming of $global:show_name because Title contains Jap/Chinese Chars" -Path $global:configLogging -Color Yellow -log Warning
                                        $SkipJapTitleCount++
                                    }
                                    Else {
                                        $checkedItems.Add($hashtestpath)

                                        if (-not $directoryHashtable.ContainsKey("$hashtestpath")) {
                                            $Arturl = $null
                                            if ($global:PlexTitleCardUrl -like "/library/*") {
                                                if ($PlexToken) {
                                                    $Arturl = $plexurl + $global:PlexTitleCardUrl + "?X-Plex-Token=$PlexToken"
                                                }
                                                Else {
                                                    $Arturl = $plexurl + $global:PlexTitleCardUrl
                                                }
                                            }
                                            foreach ($ext in $allowedExtensions) {
                                                $manualFile = "$ManualTestPath$ext"
                                                $templateFile = "$Templatetestpath$ext"
                                                $filePath = $null

                                                if (Test-Path -LiteralPath $manualFile) {
                                                    $filePath = $manualFile
                                                }
                                                elseif (Test-Path -LiteralPath $templateFile) {
                                                    $filePath = $templateFile
                                                }

                                                if ($filePath) {
                                                    Write-Entry -Message "Local file exists: $filePath" -Path $global:configLogging -Color Cyan -log Debug
                                                    $posterext = $ext
                                                    break
                                                }
                                            }
                                            if ((Test-Path -LiteralPath "$($Manualtestpath)$posterext") -and $Manualtestpath -ne '\') {
                                                Write-Entry -Message "Found Manual Title Card for: $global:show_name - $global:SeasonEPNumber" -Path $global:configLogging -Color White -log Info
                                                $TakeLocal = $true
                                            }
                                            elseif ((Test-Path -LiteralPath "$($Templatetestpath)$posterext") -and $Templatetestpath -ne '\') {
                                                Write-Entry -Message "Found Template Poster..." -Path $global:configLogging -Color White -log Info
                                                $ManualTestPath = $Templatetestpath
                                                $TakeLocal = $true
                                            }
                                            Elseif ($global:DisableOnlineAssetFetch -eq 'true') {
                                                $LocalAssetMissing = 'true'
                                            }
                                            Else {
                                                if (!$Episodepostersearchtext) {
                                                    Write-Entry -Message "Start Title Card Search for: $global:show_name - $global:SeasonEPNumber" -Path $global:configLogging -Color White -log Info
                                                    $Episodepostersearchtext = $true
                                                }
                                                # now search for TitleCards
                                                if ($global:FavProvider -eq 'TMDB') {
                                                    if ($episode.tmdbid) {
                                                        $global:posterurl = GetTMDBTitleCard
                                                        if (!$global:posterurl) {
                                                            $global:IsFallback = $true
                                                            $global:posterurl = GetTVDBTitleCard
                                                            if ($global:posterurl) {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        if (!$global:posterurl) {
                                                            $global:IsFallback = $true
                                                            if ($ArtUrl) {
                                                                GetPlexArtwork -Type ": $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card" -ArtUrl $ArtUrl -TempImage $EpisodeImage
                                                            }
                                                            Else {
                                                                Write-Entry -Subtext "Plex TitleCard Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                                            }
                                                            if (!$global:posterurl) {
                                                                Write-Entry -Subtext "Could not find a TitleCard on any site" -Path $global:configLogging -Color Red -log Error
                                                            }
                                                        }
                                                        if (!$global:posterurl -and $BackgroundFallback -eq 'true') {
                                                            # Lets just try to grab a background poster.
                                                            Write-Entry -Subtext "Fallback to Show Background..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:posterurl = GetTMDBShowBackground
                                                            if ($global:posterurl) {
                                                                Write-Entry -Subtext "Using the Show Background Poster as TitleCard Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                                $global:IsFallback = $true
                                                                $global:FallbackText = 'True-Background'
                                                            }
                                                            Else {
                                                                # Lets just try to grab a background poster.
                                                                $global:posterurl = GetTVDBShowBackground
                                                                if ($global:posterurl) {
                                                                    Write-Entry -Subtext "Using the Show Background Poster as TitleCard Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                                    $global:IsFallback = $true
                                                                    $global:FallbackText = 'True-Background'
                                                                }
                                                            }
                                                        }
                                                    }
                                                    else {
                                                        Write-Entry -Subtext "Can't search on TMDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
                                                        $global:posterurl = GetTVDBTitleCard
                                                        if (!$global:posterurl) {
                                                            $global:IsFallback = $true
                                                            if ($ArtUrl) {
                                                                GetPlexArtwork -Type ": $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card" -ArtUrl $ArtUrl -TempImage $EpisodeImage
                                                            }
                                                            Else {
                                                                Write-Entry -Subtext "Plex TitleCard Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                                            }
                                                            if (!$global:posterurl) {
                                                                Write-Entry -Subtext "Could not find a TitleCard on any site" -Path $global:configLogging -Color Red -log Error
                                                            }
                                                        }
                                                        if (!$global:posterurl -and $BackgroundFallback -eq 'true') {
                                                            Write-Entry -Subtext "No Title Cards for this Episode on TVDB or TMDB..." -Path $global:configLogging -Color Red -log Error
                                                            # Lets just try to grab a background poster.
                                                            Write-Entry -Subtext "Fallback to Show Background..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:posterurl = GetTVDBShowBackground
                                                            if ($global:posterurl) {
                                                                Write-Entry -Subtext "Using the Show Background Poster as TitleCard Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                                $global:IsFallback = $true
                                                                $global:FallbackText = 'True-Background'
                                                            }
                                                        }
                                                    }
                                                }
                                                Else {
                                                    if ($episode.tvdbid) {
                                                        $global:posterurl = GetTVDBTitleCard
                                                        if (!$global:posterurl -or $global:Fallback -eq "TMDB") {
                                                            $global:posterurl = GetTMDBTitleCard
                                                            if ($global:FavProvider -ne 'TMDB' -and $global:posterurl) {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        if (!$global:posterurl) {
                                                            $global:IsFallback = $true
                                                            if ($ArtUrl) {
                                                                GetPlexArtwork -Type ": $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card" -ArtUrl $ArtUrl -TempImage $EpisodeImage
                                                            }
                                                            Else {
                                                                Write-Entry -Subtext "Plex TitleCard Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                                            }
                                                            if (!$global:posterurl) {
                                                                Write-Entry -Subtext "Could not find a TitleCard on any site" -Path $global:configLogging -Color Red -log Error
                                                            }
                                                        }
                                                        if (!$global:posterurl -and $BackgroundFallback -eq 'true') {
                                                            # Lets just try to grab a background poster.
                                                            Write-Entry -Subtext "Fallback to Show Background..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:posterurl = GetTVDBShowBackground
                                                            if ($global:posterurl) {
                                                                Write-Entry -Subtext "Using the Show Background Poster as TitleCard Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                                $global:IsFallback = $true
                                                                $global:FallbackText = 'True-Background'
                                                            }
                                                            Else {
                                                                # Lets just try to grab a background poster.
                                                                $global:posterurl = GetTMDBShowBackground
                                                                if ($global:posterurl) {
                                                                    Write-Entry -Subtext "Using the Show Background Poster as TitleCard Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                                    $global:IsFallback = $true
                                                                    $global:FallbackText = 'True-Background'
                                                                }
                                                            }
                                                        }
                                                    }
                                                    else {
                                                        Write-Entry -Subtext "Can't search on TVDB, missing ID..." -Path $global:configLogging -Color Yellow -log Warning
                                                        $global:posterurl = GetTMDBTitleCard
                                                        if ($global:FavProvider -ne 'TMDB' -and $global:posterurl) {
                                                            $global:IsFallback = $true
                                                        }
                                                        if (!$global:posterurl) {
                                                            $global:IsFallback = $true
                                                            if ($ArtUrl) {
                                                                GetPlexArtwork -Type ": $global:show_name 'Season $global:season_number - Episode $global:episodenumber' Title Card" -ArtUrl $ArtUrl -TempImage $EpisodeImage
                                                            }
                                                            Else {
                                                                Write-Entry -Subtext "Plex TitleCard Url empty, cannot search on plex, likely there is no artwork on plex..." -Path $global:configLogging -Color Yellow -log Warning
                                                            }
                                                            if (!$global:posterurl) {
                                                                Write-Entry -Subtext "Could not find a TitleCard on any site" -Path $global:configLogging -Color Red -log Error
                                                            }
                                                        }
                                                        if (!$global:posterurl -and $BackgroundFallback -eq 'true') {
                                                            # Lets just try to grab a background poster.
                                                            Write-Entry -Subtext "Fallback to Show Background..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:posterurl = GetTMDBShowBackground
                                                            if ($global:posterurl) {
                                                                Write-Entry -Subtext "Using the Show Background Poster as TitleCard Fallback..." -Path $global:configLogging -Color Yellow -log Warning
                                                                $global:IsFallback = $true
                                                                $global:FallbackText = 'True-Background'
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            if ($global:posterurl -or $global:PlexartworkDownloaded -or $TakeLocal) {
                                                $global:IsTruncated = $null
                                                if ($global:ImageProcessing -eq 'true') {
                                                    if ($TakeLocal) {
                                                        Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                                            Copy-Item -LiteralPath $_.FullName -Destination $EpisodeImage | Out-Null
                                                        }
                                                        if ($SkipLocalTCTextAdd -eq 'true') {
                                                            $SkippingText = 'true'
                                                        }
                                                        Write-Entry -Subtext "Copy local asset to: $EpisodeImage" -Path $global:configLogging -Color Green -log Info
                                                    }
                                                    Else {
                                                        try {
                                                            if (!$global:PlexartworkDownloaded) {
                                                                $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $EpisodeImage -ErrorAction Stop
                                                            }
                                                        }
                                                        catch {
                                                            if ($_.Exception.Response) {
                                                                $statusCode = $_.Exception.Response.StatusCode.value__
                                                            }
                                                            else {
                                                                $statusCode = $_.Exception.Message
                                                            }
                                                            Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                        }
                                                        Write-Entry -Subtext "Title Card url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                                        if ($global:posterurl -like 'https://image.tmdb.org*') {
                                                            Write-Entry -Subtext "Downloading Title Card from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:AssetTextLang = $global:TMDBAssetTextLang
                                                            if ($global:FavProvider -ne 'TMDB') {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        if ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                                            Write-Entry -Subtext "Downloading Title Card from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:AssetTextLang = $global:TVDBAssetTextLang
                                                            if ($global:FavProvider -ne 'TVDB') {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        if ($global:posterurl -like "$PlexUrl*") {
                                                            Write-Entry -Subtext "Downloading Title Card from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                            if ($global:FavProvider -ne 'PLEX') {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                    }
                                                    if (Get-ChildItem -LiteralPath $EpisodeImage -ErrorAction SilentlyContinue) {
                                                        $CommentArguments = "`"$EpisodeImage`" -set `"comment`" `"created with posterizarr`" `"$EpisodeImage`""
                                                        $CommentlogEntry = "`"$magick`" $CommentArguments"
                                                        $CommentlogEntry | Out-File $magickLog -Append
                                                        InvokeMagickCommand -Command $magick -Arguments $CommentArguments
                                                        if ($global:ImageMagickError -ne 'true') {
                                                            if ($UseTCResolutionOverlays -eq 'true') {
                                                                switch ($global:EPResolution) {
                                                                    '4K DoVi/HDR10' { $TitleCardoverlay = $4KDoViHDR10TC }
                                                                    '4K DoVi' { $TitleCardoverlay = $4KDoViTC }
                                                                    '4K HDR10' { $TitleCardoverlay = $4KHDR10TC }
                                                                    '4K' { $TitleCardoverlay = $4kTC }
                                                                    '1080p' { $TitleCardoverlay = $1080pTC }
                                                                    Default { $TitleCardoverlay = $DefaultTitleCardoverlay }
                                                                }
                                                            }
                                                            Else {
                                                                $TitleCardoverlay = $DefaultTitleCardoverlay
                                                            }
                                                            # Logic for SkipAddTextAndOverlay (Skip Overlay, keep Border)
                                                            if (($SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                                                $LocalAddOverlay = 'false'
                                                            }

                                                            # Logic for SkipAddTextAndBorder (Skip Border, keep Overlay)
                                                            if (($SkipAddTextAndBorder -eq 'true') -and $global:PosterWithText) {
                                                                $LocalAddBorder = 'false'
                                                            }

                                                            # Logic for "If both are true, only resize"
                                                            if ($SkipAddTextAndOverlay -eq 'true' -and $SkipAddTextAndBorder -eq 'true' -and $global:PosterWithText) {
                                                                $LocalAddBorder = 'false'
                                                                $LocalAddOverlay = 'false'
                                                            }
                                                            # Resize Image to 2000x3000 and apply Border and overlay
                                                            if ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'true') {
                                                                $Arguments = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$TitleCardoverlay`" -gravity south -quality $global:outputQuality -composite -shave `"$TitleCardborderwidthsecond`"  -bordercolor `"$TitleCardbordercolor`" -border `"$TitleCardborderwidth`" `"$EpisodeImage`""
                                                                Write-Entry -Subtext "Resizing it | Adding Borders | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                                            }
                                                            elseif ($LocalAddBorder -eq 'true' -and $LocalAddOverlay -eq 'false') {
                                                                $Arguments = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" -shave `"$TitleCardborderwidthsecond`"  -bordercolor `"$TitleCardbordercolor`" -border `"$TitleCardborderwidth`" `"$EpisodeImage`""
                                                                Write-Entry -Subtext "Resizing it | Adding Borders" -Path $global:configLogging -Color White -log Info
                                                            }
                                                            elseif ($LocalAddBorder -eq 'false' -and $LocalAddOverlay -eq 'true') {
                                                                $Arguments = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$TitleCardoverlay`" -gravity south -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                Write-Entry -Subtext "Resizing it | Adding Overlay" -Path $global:configLogging -Color White -log Info
                                                            }
                                                            else {
                                                                $Arguments = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$EpisodeImage`""
                                                                Write-Entry -Subtext "Resizing it" -Path $global:configLogging -Color White -log Info
                                                            }
                                                            $logEntry = "`"$magick`" $Arguments"
                                                            $logEntry | Out-File $magickLog -Append
                                                            InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                            if (($SkipAddText -eq 'true' -or $SkipAddTextAndOverlay -eq 'true') -and $global:PosterWithText) {
                                                                $SkippingText = 'true'
                                                                Write-Entry -Subtext "Skipping 'AddText' because poster already has text." -Path $global:configLogging -Color Yellow -log Info
                                                            }
                                                            if ($AddTitleCardEPTitleText -eq 'true' -and $SkippingText -eq 'false') {
                                                                if ($TitleCardEPTitlefontAllCaps -eq 'true') {
                                                                    $global:EPTitle = $global:EPTitle.ToUpper()
                                                                }
                                                                $global:EPTitle = $global:EPTitle -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                                if ($global:direction -eq "RTL") {
                                                                    $TitleCardfontImagemagick = $RTLfontImagemagick
                                                                }
                                                                # Loop through each symbol and replace it with a newline
                                                                if ($NewLineOnSpecificSymbols -eq 'true') {
                                                                    foreach ($symbol in $NewLineSymbols) {
                                                                        # Replace the symbol with a newline
                                                                        $replacementString = "`n"

                                                                        # Check if the symbol should be kept
                                                                        $keepThisSymbol = $false
                                                                        if ($null -ne $SymbolsToKeepOnNewLine) {
                                                                            # Loop through all items in $SymbolsToKeepOnNewLine (in case it's an array like [':', '!'])
                                                                            foreach ($k in $SymbolsToKeepOnNewLine) {
                                                                                # Check if the $symbol (e.g., ": ") contains the $k character (e.g., ":")
                                                                                if ($symbol -like "*$k*") {
                                                                                    $keepThisSymbol = $true
                                                                                    break # Match found, no need to keep checking
                                                                                }
                                                                            }
                                                                        }

                                                                        # If it's a "keep" symbol, change the replacement string
                                                                        if ($keepThisSymbol) {
                                                                            # Replace ": " with ": \n" (keeps the symbol, adds newline after)
                                                                            $replacementString = $symbol + "`n"
                                                                        }
                                                                        $global:EPTitle = $global:EPTitle -replace [regex]::Escape($symbol), $replacementString
                                                                    }
                                                                }
                                                                if ($NewLineOnSpecificWords -eq 'true' -and $null -ne $NewLineWords) {
                                                                    $properties = $NewLineWords.PSObject.Properties.Name

                                                                    # Check if properties exist and the list is not empty
                                                                    if ($null -ne $properties -and $properties.Count -gt 0) {
                                                                        foreach ($wordKey in $properties) {
                                                                            $replacementValue = $NewLineWords.$wordKey

                                                                            # Using [regex]::Escape handles any special characters in the word keys
                                                                            $global:EPTitle = $global:EPTitle -replace [regex]::Escape($wordKey), $replacementValue
                                                                        }
                                                                    }
                                                                }
                                                                $joinedTitlePointSize = $global:EPTitle -replace '""', '""""' -replace '`', ''
                                                                $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $TitleCardfontImagemagick -box_width $TitleCardEPTitleMaxWidth  -box_height $TitleCardEPTitleMaxHeight -min_pointsize $TitleCardEPTitleminPointSize -max_pointsize $TitleCardEPTitlemaxPointSize -lineSpacing $TitleCardEPTitlelineSpacing
                                                                if ($global:IsTruncated -ne $true) {
                                                                    Write-Entry -Subtext ("Optimal font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                                    # Add Stroke
                                                                    if ($AddTitleCardEPTitleTextStroke -eq 'true') {
                                                                        $Arguments = "`"$EpisodeImage`" -gravity center -background None -layers Flatten `( -size `"$TitleCardEPTitleboxsize`" -background none `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPTitlestrokecolor`" -stroke `"$TitleCardEPTitlestrokecolor`" -strokewidth `"$TitleCardEPTitlestrokewidth`" -size `"$TitleCardEPTitleboxsize`" -background none -interline-spacing `"$TitleCardEPTitlelineSpacing`" -gravity `"$TitleCardEPTitletextgravity`" caption:`"$global:EPTitle`" `) `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPTitlefontcolor`" -stroke none -size `"$TitleCardEPTitleboxsize`" -background none -interline-spacing `"$TitleCardEPTitlelineSpacing`" -gravity `"$TitleCardEPTitletextgravity`" caption:`"$global:EPTitle`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$TitleCardEPTitleboxsize`" `) -gravity south -geometry +0`"$TitleCardEPTitletext_offset`" -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                    }
                                                                    Else {
                                                                        $Arguments = "`"$EpisodeImage`" -gravity center -background None -layers Flatten `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPTitlefontcolor`" -size `"$TitleCardEPTitleboxsize`" -background none -interline-spacing `"$TitleCardEPTitlelineSpacing`" -gravity `"$TitleCardEPTitletextgravity`" caption:`"$global:EPTitle`" -trim +repage -extent `"$TitleCardEPTitleboxsize`" `) -gravity south -geometry +0`"$TitleCardEPTitletext_offset`" -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                    }

                                                                    Write-Entry -Subtext "Applying EPTitle text: `"$global:EPTitle`"" -Path $global:configLogging -Color White -log Info
                                                                    $logEntry = "`"$magick`" $Arguments"
                                                                    $logEntry | Out-File $magickLog -Append
                                                                    InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                                }
                                                            }
                                                            if ($AddTitleCardEPText -eq 'true' -and $SkippingText -eq 'false') {
                                                                if ($TitleCardEPfontAllCaps -eq 'true') {
                                                                    $global:SeasonEPNumber = $global:SeasonEPNumber.ToUpper()
                                                                }
                                                                $global:SeasonEPNumber = $global:SeasonEPNumber -replace 'â€ž', '"' -replace 'â€', '"' -replace 'â€œ', '"' -replace '"', '""' -replace '`', ''
                                                                $joinedTitlePointSize = $global:SeasonEPNumber -replace '""', '""""'
                                                                $optimalFontSize = Get-OptimalPointSize -text $joinedTitlePointSize -font $TitleCardfontImagemagick -box_width $TitleCardEPMaxWidth  -box_height $TitleCardEPMaxHeight -min_pointsize $TitleCardEPminPointSize -max_pointsize $TitleCardEPmaxPointSize -lineSpacing $TitleCardEPlineSpacing
                                                                if ($global:IsTruncated -ne $true) {
                                                                    Write-Entry -Subtext ("Optimal font size set to: '{0}' [{1}]" -f $optimalFontSize, $(if ($null -eq $script:CurrentTextSizeSource) { 'calculated' } else { $script:CurrentTextSizeSource })) -Path $global:configLogging -Color White -log Info
                                                                    # Add Stroke
                                                                    if ($AddTitleCardTextStroke -eq 'true') {
                                                                        $Arguments = "`"$EpisodeImage`" -gravity center -background None -layers Flatten `( -size `"$TitleCardEPboxsize`" -background none `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardstrokecolor`" -stroke `"$TitleCardstrokecolor`" -strokewidth `"$TitleCardstrokewidth`" -size `"$TitleCardEPboxsize`" -background none -interline-spacing `"$TitleCardEPlineSpacing`" -gravity `"$TitleCardEPtextgravity`" caption:`"$global:SeasonEPNumber`" `) `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPfontcolor`" -stroke none -size `"$TitleCardEPboxsize`" -background none -interline-spacing `"$TitleCardEPlineSpacing`" -gravity `"$TitleCardEPtextgravity`" caption:`"$global:SeasonEPNumber`" `) -gravity `"$ShowOnSeasontextgravity`" -composite -trim +repage -extent `"$TitleCardEPboxsize`" `) -gravity south -geometry +0`"$TitleCardEPtext_offset`" -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                    }
                                                                    Else {
                                                                        $Arguments = "`"$EpisodeImage`" -gravity center -background None -layers Flatten `( -font `"$TitleCardfontImagemagick`" -pointsize `"$optimalFontSize`" -fill `"$TitleCardEPfontcolor`" -size `"$TitleCardEPboxsize`" -background none -interline-spacing `"$TitleCardEPlineSpacing`" -gravity `"$TitleCardEPtextgravity`" caption:`"$global:SeasonEPNumber`" -trim +repage -extent `"$TitleCardEPboxsize`" `) -gravity south -geometry +0`"$TitleCardEPtext_offset`" -quality $global:outputQuality -composite `"$EpisodeImage`""
                                                                    }

                                                                    Write-Entry -Subtext "Applying SeasonEPNumber text: `"$global:SeasonEPNumber`"" -Path $global:configLogging -Color White -log Info
                                                                    $logEntry = "`"$magick`" $Arguments"
                                                                    $logEntry | Out-File $magickLog -Append
                                                                    InvokeMagickCommand -Command $magick -Arguments $Arguments
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                Else {
                                                    if ($TakeLocal) {
                                                        Get-ChildItem -LiteralPath "$($ManualTestPath)$posterext" | ForEach-Object {
                                                            Copy-Item -LiteralPath $_.FullName -Destination $EpisodeImage | Out-Null
                                                        }
                                                        if ($SkipLocalTCTextAdd -eq 'true') {
                                                            $SkippingText = 'true'
                                                        }
                                                        Write-Entry -Subtext "Copy local asset to: $EpisodeImage" -Path $global:configLogging -Color Green -log Info
                                                    }
                                                    Else {
                                                        try {
                                                            if (!$global:PlexartworkDownloaded) {
                                                                $response = Invoke-WebRequest -Uri $global:posterurl -OutFile $EpisodeImage -ErrorAction Stop
                                                            }
                                                        }
                                                        catch {
                                                            if ($_.Exception.Response) {
                                                                $statusCode = $_.Exception.Response.StatusCode.value__
                                                            }
                                                            else {
                                                                $statusCode = $_.Exception.Message
                                                            }
                                                            Write-Entry -Subtext "An error occurred while downloading the artwork: $statusCode" -Path $global:configLogging -Color Red -log Error
                                                            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                        }
                                                        Write-Entry -Subtext "Title Card url: $(RedactMediaServerUrl -url $global:posterurl)" -Path $global:configLogging -Color White -log Info
                                                        if ($global:posterurl -like 'https://image.tmdb.org*') {
                                                            Write-Entry -Subtext "Downloading Title Card from 'TMDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:AssetTextLang = $global:TMDBAssetTextLang
                                                            if ($global:FavProvider -ne 'TMDB') {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        if ($global:posterurl -like 'https://artworks.thetvdb.com*') {
                                                            Write-Entry -Subtext "Downloading Title Card from 'TVDB'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                            $global:AssetTextLang = $global:TVDBAssetTextLang
                                                            if ($global:FavProvider -ne 'TVDB') {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                        if ($global:posterurl -like "$PlexUrl*") {
                                                            Write-Entry -Subtext "Downloading Title Card from 'Plex'" -Path $global:configLogging -Color DarkMagenta -log Info
                                                            if ($global:FavProvider -ne 'PLEX') {
                                                                $global:IsFallback = $true
                                                            }
                                                        }
                                                    }
                                                    if (Get-ChildItem -LiteralPath $EpisodeImage -ErrorAction SilentlyContinue) {
                                                        # Resize Image to 2000x3000
                                                        $Resizeargument = "`"$EpisodeImage`" -resize `"$BackgroundSize^`" -gravity center -extent `"$BackgroundSize`" `"$EpisodeImage`""
                                                        Write-Entry -Subtext "Resizing it... " -Path $global:configLogging -Color White -log Info
                                                        $logEntry = "`"$magick`" $Resizeargument"
                                                        $logEntry | Out-File $magickLog -Append
                                                        InvokeMagickCommand -Command $magick -Arguments $Resizeargument
                                                    }
                                                }
                                                if ($global:ImageMagickError -ne 'true') {
                                                    if (Get-ChildItem -LiteralPath $EpisodeImage -ErrorAction SilentlyContinue) {
                                                        # Move file back to original naming with Brackets.
                                                        if ($global:IsTruncated -ne $true) {
                                                            if ($Upload2Plex -eq 'true') {
                                                                try {
                                                                    Write-Entry -Subtext "Uploading Artwork to Plex..." -Path $global:configLogging -Color DarkMagenta -log Info
                                                                    $fileContent = [System.IO.File]::ReadAllBytes($EpisodeImage)
                                                                    # Verify variables before uploading
                                                                    Write-Entry -Subtext "EpisodeImage: $EpisodeImage" -Path $global:configLogging -Color Cyan -log Debug
                                                                    Write-Entry -Subtext "RatingKey: $($global:episode_ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                                                    Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                                                    $uri = if ($PlexToken) {
                                                                        "$PlexUrl/library/metadata/$($global:episode_ratingkey)/posters?X-Plex-Token=$PlexToken"
                                                                    }
                                                                    Else {
                                                                        "$PlexUrl/library/metadata/$($global:episode_ratingkey)/posters"
                                                                    }
                                                                    Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                                                    # Try uploading, capturing the response in detail
                                                                    $Upload = Invoke-WebRequest -Uri $uri `
                                                                        -Method Post `
                                                                        -Headers $extraPlexHeaders `
                                                                        -Body $fileContent `
                                                                        -ContentType 'application/octet-stream' `
                                                                        -SkipHttpErrorCheck `
                                                                        -ErrorAction Stop

                                                                    if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                                                        Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                                                        Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                                                    }
                                                                    else {
                                                                        Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                                                        Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                                                    }
                                                                }
                                                                catch {
                                                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                                                    $global:errorCount++
                                                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                                }
                                                            }
                                                            try {
                                                                # Attempt to move the item
                                                                Move-Item -LiteralPath $EpisodeImage -Destination $EpisodeImageoriginal -Force -ErrorAction Stop

                                                                # Log success if move was successful
                                                                Write-Entry -Subtext "Added: $EpisodeImageoriginal" -Path $global:configLogging -Color Green -Log Info
                                                            }
                                                            catch {
                                                                # Log the error if the move operation fails
                                                                Write-Entry -Subtext "Failed to move $EpisodeImage to $EpisodeImageoriginal." -Path $global:configLogging -Color Red -Log Error
                                                                Write-Entry -Subtext "Error: $_" -Path $global:configLogging -Color Red -Log Error
                                                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                                            }
                                                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                                            $EpisodeCount++
                                                            $posterCount++
                                                        }
                                                        Else {
                                                            Write-Entry -Subtext "Skipping asset move because text is truncated..." -Path $global:configLogging -Color Yellow -log Warning
                                                        }
                                                        $episodetemp = New-Object psobject
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $($global:FileNaming + " | " + $global:EPTitle)
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Episode'
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Language" -Value $(if ($TakeLocal) { "false" } Else { if (!$global:AssetTextLang) { "Textless" }Else { $global:AssetTextLang } })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Logo Source" -Value  $(if ($global:LogoUrl) { $global:LogoUrl } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Logo Language" -Value $(if ($global:LogoLanguage) { $global:LogoLanguage } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Logo TextFallback" -Value $(if ($ApplyTextInsteadOfLogo) { $ApplyTextInsteadOfLogo } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value $(if ($global:IsFallback -and $global:FallbackText) { $global:FallbackText } elseif ($global:IsFallback -and !$global:FallbackText) { 'true' } Else { 'false' })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value $(if ($TakeLocal) { $EpisodeImage } Else { $global:posterurl })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                                        $episodetemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                                        switch -Wildcard ($global:FavProvider) {
                                                            'TMDB' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                                            'FANART' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                                            'TVDB' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                                            Default { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                                        }
                                                        # Export the array to a CSV file
                                                        $episodetemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                                                    }
                                                }
                                            }
                                            Elseif ($LocalAssetMissing -eq 'true') {
                                                Write-Entry -Subtext "Skipping [$global:show_name - $global:SeasonEPNumber] - local asset missing and online fetch is disabled." -Path $global:configLogging -Color Yellow -log Warning
                                            }
                                            Else {
                                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                                $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                if ($global:BackgroundOnlyTextless) {
                                                    $episodetemp = New-Object psobject
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Title" -Value $($global:FileNaming + " | " + $global:EPTitle)
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Type" -Value 'Episode'
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Rootfolder" -Value $($entry.RootFoldername)
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "LibraryName" -Value $($entry.'Library Name')
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Language" -Value 'false'
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Fallback" -Value 'false'
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "TextTruncated" -Value $(if ($global:IsTruncated) { 'true' } else { 'false' })
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Download Source" -Value 'false'
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "Manual" -Value $(if ($TakeLocal) { "true" } Else { "false" })
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "tmdbid" -Value $(if ($entry.tmdbid) { $entry.tmdbid } Else { "false" })
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "tvdbid" -Value $(if ($entry.tvdbid) { $entry.tvdbid } Else { "false" })
                                                    $episodetemp | Add-Member -MemberType NoteProperty -Name "imdbid" -Value $(if ($entry.imdbid) { $entry.imdbid } Else { "false" })
                                                    switch -Wildcard ($global:FavProvider) {
                                                        'TMDB' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TMDBAssetChangeUrl) { $global:TMDBAssetChangeUrl }Else { "false" }) }
                                                        'FANART' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:FANARTAssetChangeUrl) { $global:FANARTAssetChangeUrl }Else { "false" }) }
                                                        'TVDB' { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value $(if ($global:TVDBAssetChangeUrl) { $global:TVDBAssetChangeUrl }Else { "false" }) }
                                                        Default { $episodetemp | Add-Member -MemberType NoteProperty -Name "Fav Provider Link" -Value 'false' }
                                                    }

                                                    # Export the array to a CSV file
                                                    $episodetemp | Export-Csv -Path "$global:ScriptRoot\Logs\ImageChoices.csv" -NoTypeInformation -Delimiter ';' -Encoding UTF8 -Force -Append
                                                }

                                            }

                                        }
                                        else {
                                            if ($global:UploadExistingAssets -eq 'true') {
                                                if ($global:PlexTitleCardUrl -like "/library/*") {
                                                    if ($PlexToken) {
                                                        $Arturl = $plexurl + $global:PlexTitleCardUrl + "?X-Plex-Token=$PlexToken"
                                                    }
                                                    Else {
                                                        $Arturl = $plexurl + $global:PlexTitleCardUrl
                                                    }
                                                }
                                                Write-Entry -Message "Starting Existing Asset Upload..." -Path $global:configLogging -Color Green -log Info
                                                try {
                                                    GetPlexArtwork -Type " $Titletext | $global:FileNaming Artwork." -ArtUrl $Arturl -TempImage $EpisodeImage
                                                    if ($global:PlexartworkDownloaded -eq 'true') {
                                                        Write-Entry -Subtext "Uploading Existing Artwork for: $Titletext" -Path $global:configLogging -Color White -log Info
                                                        $fileContent = [System.IO.File]::ReadAllBytes($EpisodeImageoriginal)
                                                        # Verify variables before uploading
                                                        Write-Entry -Subtext "EpisodeImage: $EpisodeImageoriginal" -Path $global:configLogging -Color Cyan -log Debug
                                                        Write-Entry -Subtext "RatingKey: $($global:episode_ratingkey)" -Path $global:configLogging -Color Cyan -log Debug
                                                        Write-Entry -Subtext "File size: $($fileContent.Length) bytes" -Path $global:configLogging -Color Cyan -log Debug

                                                        $uri = if ($PlexToken) {
                                                            "$PlexUrl/library/metadata/$($global:episode_ratingkey)/posters?X-Plex-Token=$PlexToken"
                                                        }
                                                        Else {
                                                            "$PlexUrl/library/metadata/$($global:episode_ratingkey)/posters"
                                                        }
                                                        Write-Entry -Subtext "Upload URI: $(RedactMediaServerUrl -url $uri)" -Path $global:configLogging -Color Cyan -log Debug
                                                        # Try uploading, capturing the response in detail
                                                        $Upload = Invoke-WebRequest -Uri $uri `
                                                            -Method Post `
                                                            -Headers $extraPlexHeaders `
                                                            -Body $fileContent `
                                                            -ContentType 'application/octet-stream' `
                                                            -SkipHttpErrorCheck `
                                                            -ErrorAction Stop

                                                        if ($Upload.StatusCode -ne 200 -and $Upload.StatusCode -ne 201) {
                                                            Write-Entry -Subtext "Upload failed: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color Red -log Error
                                                            Write-Entry -Subtext "Response body:`n$($Upload.Content)" -Path $global:configLogging -Color Cyan-log Debug
                                                        }
                                                        else {
                                                            Write-Entry -Subtext "Upload OK: HTTP $($Upload.StatusCode)" -Path $global:configLogging -Color White -log Debug
                                                            Write-Entry -Subtext "Artwork uploaded successfully..." -Path $global:configLogging -Color Green -log Info
                                                        }
                                                        $UploadCount++
                                                    }
                                                }
                                                catch {
                                                    Write-Entry -Subtext "Invoke-WebRequest failed at transport level: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error

                                                    $global:errorCount++
                                                    Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                                                }
                                                if (Test-Path $EpisodeImage -ErrorAction SilentlyContinue) {
                                                    Remove-Item -LiteralPath $EpisodeImage | Out-Null
                                                    Write-Entry -Message "Deleting Temp Image: $EpisodeImage" -Path $global:configLogging -Color White -log Info
                                                }
                                            }
                                            Else {
                                                if ($show_skipped -eq 'true' ) {
                                                    Write-Entry -Subtext "Already exists: $EpisodeImageoriginal" -Path $global:configLogging -Color Cyan -log Info
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                    }
                }
            }
        }
        Else {
            Write-Entry -Message "Rootfolder value: $($entry.RootFoldername)" -Path $global:configLogging -Color Cyan -log Debug
            Write-Entry -Message "Path value: $($entry.Path)" -Path $global:configLogging -Color Cyan -log Debug
            Write-Entry -Message "Missing RootFolder for: $($entry.title) - you have to manually create the poster for it..." -Path $global:configLogging -Color Red -log Error
            $global:errorCount++; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

        }
    
}

