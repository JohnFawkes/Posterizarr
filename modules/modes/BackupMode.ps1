#region Backup Mode
    if ($UsePlex -eq 'true') {
        MassDownloadPlexArtwork
    }
    Else {
        MassDownloadJellyEmbyArtwork
    }
