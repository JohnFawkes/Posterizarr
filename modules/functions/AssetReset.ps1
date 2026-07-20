function Reset-PlexLibraryPictures {
    param (
        [string]$LibraryName
    )

    # Fetch the sections of the Plex library
    try {
        $sections = Invoke-RestMethod -Uri "$PlexUrl/library/sections" -Headers $extraPlexHeaders
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
        $sections = Invoke-RestMethod -Uri "$PlexUrl/library/sections" -Headers $PlexHeaders
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
