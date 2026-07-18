#region Restore Mode
    Write-Entry -Message "Restore Mode Started..." -Path $global:configLogging -Color White -log Info

    $restoreQueueFile = Join-Path $global:ScriptRoot "restore_queue.json"
    $restoreItems = $null

    # Create temporary isolated staging directory
    $TempAssetPath = Join-Path $global:ScriptRoot "RestoreTemp"
    if (Test-Path $TempAssetPath) {
        Remove-Item -Path "$TempAssetPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -ItemType Directory -Path $TempAssetPath -Force | Out-Null
    }

    if (Test-Path $restoreQueueFile) {
        $restoreItems = Get-Content -Raw $restoreQueueFile | ConvertFrom-Json
        Write-Entry -Message "Found restore_queue.json with $($restoreItems.Count) item(s)." -Path $global:configLogging -Color Cyan -log Info
        
        foreach ($item in $restoreItems) {
            if ($item -eq "ALL") {
                Write-Entry -Message "Restoring ALL assets from backup..." -Path $global:configLogging -Color Yellow -log Warning
                Copy-Item -Path "$BackupPath\*" -Destination $AssetPath -Recurse -Force
                Copy-Item -Path "$BackupPath\*" -Destination $TempAssetPath -Recurse -Force
                break
            } else {
                $sourcePath = Join-Path $BackupPath $item
                
                # 1. Restore to permanent AssetPath
                $destPathPermanent = Join-Path $AssetPath $item
                # 2. Stage to temporary AssetPath
                $destPathTemp = Join-Path $TempAssetPath $item
                
                if (Test-Path $sourcePath -PathType Container) {
                    if (-not (Test-Path $destPathPermanent)) { New-Item -ItemType Directory -Path $destPathPermanent -Force | Out-Null }
                    if (-not (Test-Path $destPathTemp)) { New-Item -ItemType Directory -Path $destPathTemp -Force | Out-Null }
                    
                    Copy-Item -Path "$sourcePath\*" -Destination $destPathPermanent -Recurse -Force
                    Copy-Item -Path "$sourcePath\*" -Destination $destPathTemp -Recurse -Force
                    Write-Entry -Subtext "Restored Directory: $item" -Path $global:configLogging -Color Cyan -log Debug
                } elseif (Test-Path $sourcePath -PathType Leaf) {
                    $destDirPermanent = Split-Path $destPathPermanent -Parent
                    $destDirTemp = Split-Path $destPathTemp -Parent
                    
                    if (-not (Test-Path $destDirPermanent)) { New-Item -ItemType Directory -Path $destDirPermanent -Force | Out-Null }
                    if (-not (Test-Path $destDirTemp)) { New-Item -ItemType Directory -Path $destDirTemp -Force | Out-Null }
                    
                    Copy-Item -Path $sourcePath -Destination $destPathPermanent -Force
                    Copy-Item -Path $sourcePath -Destination $destPathTemp -Force
                    Write-Entry -Subtext "Restored File: $item" -Path $global:configLogging -Color Cyan -log Debug
                } else {
                    Write-Entry -Message "Backup file not found: $sourcePath" -Path $global:configLogging -Color Red -log Error
                }
            }
        }
        # Optionally remove the queue file after reading
        Remove-Item -Path $restoreQueueFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Entry -Message "No restore_queue.json found. Restoring all assets from backup..." -Path $global:configLogging -Color Yellow -log Warning
        Copy-Item -Path "$BackupPath\*" -Destination $AssetPath -Recurse -Force
        Copy-Item -Path "$BackupPath\*" -Destination $TempAssetPath -Recurse -Force
    }

    # IMPORTANT: Temporarily override global variables so NormalMode ONLY finds the restored files
    $originalAssetPath = $global:AssetPath
    $global:AssetPath = $TempAssetPath

    $global:UploadExistingAssets = 'true'
    $global:DisableHashValidation = 'true'
    $global:DisableOnlineAssetFetch = 'true'

    Write-Entry -Message "Files dynamically isolated in $TempAssetPath. Triggering NormalMode..." -Path $global:configLogging -Color Green -log Info

    try {
        . "$PSScriptRoot\modules\modes\NormalMode.ps1"
    }
    finally {
        # Cleanup temporary staging directory and restore original AssetPath reference
        $global:AssetPath = $originalAssetPath
        if (Test-Path $TempAssetPath) {
            Remove-Item -Path $TempAssetPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Entry -Message "Restore staging directory cleaned up." -Path $global:configLogging -Color Cyan -log Debug
        }
    }
#endregion
