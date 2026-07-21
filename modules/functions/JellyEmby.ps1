function CheckJellyfinAccess {
    param (
        [string]$JellyfinUrl,
        [string]$JellyfinAPI
    )

    if ($JellyfinAPI) {
        Write-Entry -Message "Checking Jellyfin access now..." -Path $global:configLogging -Color White -log Info
        try {
            $response = Invoke-RestMethod -Method Get -Uri "$JellyfinUrl/System/Info" -ErrorAction Stop -Headers @{ "Authorization" = "MediaBrowser Token=`"$JellyfinAPI`"" }
            if ($response.version) {
                Write-Entry -Subtext "Jellyfin access is working..." -Path $global:configLogging -Color Green -log Info
                $global:OtherMediaServerHeaders = @{ "Authorization" = "MediaBrowser Token=`"$JellyfinAPI`"" }
            }
            else {
                Write-Entry -Message "Could not access Jellyfin" -Path $global:configLogging -Color Red -Log Error
                Write-Entry -Subtext "Please check token and url..." -Path $global:configLogging -Color Red -log Error
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
            $response = Invoke-RestMethod -Method Get -Uri "$EmbyUrl/System/Info" -ErrorAction Stop -Headers @{ "Authorization" = "MediaBrowser Token=`"$EmbyAPI`"" }
            if ($response.version) {
                Write-Entry -Subtext "Emby access is working..." -Path $global:configLogging -Color Green -log Info
                $global:OtherMediaServerHeaders = @{ "Authorization" = "MediaBrowser Token=`"$EmbyAPI`"" }
            }
            else {
                Write-Entry -Message "Could not access Emby" -Path $global:configLogging -Color Red -Log Error
                Write-Entry -Subtext "Please check token and url..." -Path $global:configLogging -Color Red -log Error
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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