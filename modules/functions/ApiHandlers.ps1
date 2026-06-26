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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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

        try { $entrytemp = Get-FanartTv -Type $Type -id $id -ErrorAction SilentlyContinue } catch { 

            Write-Entry -Subtext 'Fanart.tv error: ' + $_.Exception.Message -Path $global:configLogging -Color Yellow -log Warning

            $entrytemp = $null

        }
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
                try { $entrytemp = Get-FanartTv -Type movies -id $id -ErrorAction SilentlyContinue } catch { 
                    Write-Entry -Subtext 'Fanart.tv error: ' + $_.Exception.Message -Path $global:configLogging -Color Yellow -log Warning
                    $entrytemp = $null
                }
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
                try { $entrytemp = Get-FanartTv -Type movies -id $id -ErrorAction SilentlyContinue } catch { 
                    Write-Entry -Subtext 'Fanart.tv error: ' + $_.Exception.Message -Path $global:configLogging -Color Yellow -log Warning
                    $entrytemp = $null
                }
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
            try { $entrytemp = Get-FanartTv -Type movies -id $id -ErrorAction SilentlyContinue } catch { 
                Write-Entry -Subtext 'Fanart.tv error: ' + $_.Exception.Message -Path $global:configLogging -Color Yellow -log Warning
                $entrytemp = $null
            }
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
            try { $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue } catch { 
                Write-Entry -Subtext 'Fanart.tv error: ' + $_.Exception.Message -Path $global:configLogging -Color Yellow -log Warning
                $entrytemp = $null
            }
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
            try { $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue } catch { 
                Write-Entry -Subtext 'Fanart.tv error: ' + $_.Exception.Message -Path $global:configLogging -Color Yellow -log Warning
                $entrytemp = $null
            }
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
        try { $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue } catch { 
            Write-Entry -Subtext 'Fanart.tv error: ' + $_.Exception.Message -Path $global:configLogging -Color Yellow -log Warning
            $entrytemp = $null
        }
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
            try { $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue } catch { 
                Write-Entry -Subtext 'Fanart.tv error: ' + $_.Exception.Message -Path $global:configLogging -Color Yellow -log Warning
                $entrytemp = $null
            }
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
            try { $entrytemp = Get-FanartTv -Type tv -id $id -ErrorAction SilentlyContinue } catch { 
                Write-Entry -Subtext 'Fanart.tv error: ' + $_.Exception.Message -Path $global:configLogging -Color Yellow -log Warning
                $entrytemp = $null
            }
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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                    $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                    $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                    $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($allEpisodes.slug)/#artwork"

                }
            }
            Else {
                Write-Entry -Subtext "No Title Card found on TVDB" -Path $global:configLogging -Color Yellow -log Warning
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
                $global:TVDBAssetChangeUrl = "https://thetvdb.com/series/$($allEpisodes.slug)/#artwork"

            }
        }
        Else {
            Write-Entry -Subtext "TVDB API response is null" -Path $global:configLogging -Color Red -log Error
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
        $requestHeaders = $extraPlexHeaders.Clone()
        if ($OtherMediaServerUrl -and $ArtUrl.StartsWith($OtherMediaServerUrl)) {
            foreach ($key in $global:OtherMediaServerHeaders.Keys) {
                $requestHeaders[$key] = $global:OtherMediaServerHeaders[$key]
            }
        }
        foreach ($key in $requestHeaders.Keys) {
            $client.DefaultRequestHeaders.TryAddWithoutValidation($key, $requestHeaders[$key])
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
            Invoke-WebRequest -Uri $ArtUrl -OutFile $TempImage -Headers $requestHeaders
            $magickcommand = "& `"$magick`" identify -verbose `"$TempImage`""
            if (Invoke-Expression $magickcommand | Select-String -Pattern 'overlay|titlecard|created with ppm|created with posterizarr') {
                $ExifFound = $true
            }
        }
        catch {
            Write-Entry -Subtext "Could not download Artwork from plex: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount = Increment-GlobalStat 'errorCount'; return
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
            Invoke-WebRequest -Uri $ArtUrl -OutFile $TempImage -Headers $requestHeaders
            $global:PlexartworkDownloaded = $true
            $global:posterurl = $ArtUrl
        }
        catch {
            Write-Entry -Subtext "Full download failed: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
        }
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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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

function CheckJellyfinAccess {
    param (
        [string]$JellyfinUrl,
        [string]$JellyfinAPI
    )

    if ($JellyfinAPI) {
        Write-Entry -Message "Checking Jellyfin access now..." -Path $global:configLogging -Color White -log Info
        try {
            $response = Invoke-RestMethod -Method Get -Uri "$JellyfinUrl/System/Info" -ErrorAction Stop -Headers @{ "Authorization" = "MediaBrowser Token=\"$JellyfinAPI\"" }
            if ($response.version) {
                Write-Entry -Subtext "Jellyfin access is working..." -Path $global:configLogging -Color Green -log Info
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
            $response = Invoke-RestMethod -Method Get -Uri "$EmbyUrl/System/Info" -ErrorAction Stop -Headers @{ "Authorization" = "MediaBrowser Token=\"$EmbyAPI\"" }
            if ($response.version) {
                Write-Entry -Subtext "Emby access is working..." -Path $global:configLogging -Color Green -log Info
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

function UploadOtherMediaServerArtwork {
    param (
        [string]$itemId,
        [string]$imageType,
        [string]$imagePath,
        [switch]$SkipExifCheck # Added optional parameter
    )

    # Check if current image already has exif data
    $Imageinfo = Invoke-RestMethod -Method Get -Uri "$OtherMediaServerUrl/items/$itemId/images/" -Headers $global:OtherMediaServerHeaders
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
                $ImageUrl = "$OtherMediaServerUrl/items/$itemId/images/$imageType/?width=$($imageinfotemp.width)&height=$($imageinfotemp.Height)"
                $tempFile = Join-Path -Path $global:ScriptRoot -ChildPath "temp\hashcompare.jpg"

                # Try to download the image
                $response = Invoke-WebRequest -Uri $ImageUrl -OutFile $tempFile -ErrorAction Stop

                $magickcommand = "& `"$magick`" identify -verbose `"$tempFile`""
                $magickcommand | Write-MagickLog
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
        $apiUrl = "$OtherMediaServerUrl/items/$itemId/images/$imageType/"

        if ($imageType -eq "Backdrop") {
            $deleteUrl = "$OtherMediaServerUrl/items/$itemId/images/$imageType/0"
            # Make the API request to delete the backdrop image
            try {
                # Delete the existing image first
                $response = Invoke-RestMethod -Uri $deleteUrl -Method Delete -ErrorAction Stop -Headers $global:OtherMediaServerHeaders
                Write-Entry -Subtext "Image successfully deleted..." -Path $global:configLogging -Color Green -log Info
                $global:UploadCount = Increment-GlobalStat 'UploadCount'
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
                $thumbapiUrl = "$OtherMediaServerUrl/items/$itemId/images/Thumb/"
                try {
                    $response = Invoke-RestMethod -Uri $thumbapiUrl -Method Post -Body $imageBase64 -ContentType $contentType -ErrorAction Stop -Headers $global:OtherMediaServerHeaders

                    Write-Entry -Subtext "Thumb Image successfully uploaded..." -Path $global:configLogging -Color Green -log Info
                    $global:UploadCount = Increment-GlobalStat 'UploadCount'
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
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $imageBase64 -ContentType $contentType -ErrorAction Stop -Headers $global:OtherMediaServerHeaders

            Write-Entry -Subtext "Image successfully uploaded..." -Path $global:configLogging -Color Green -log Info
            $global:UploadCount = Increment-GlobalStat 'UploadCount'
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
                Invoke-WebRequest -Uri $ArtUrl -OutFile $TempImage -Headers $requestHeaders
                $magickcommand = "& `"$magick`" identify -verbose `"$TempImage`""
                if (Invoke-Expression $magickcommand | Select-String -Pattern 'overlay|titlecard|created with ppm|created with posterizarr') {
                    $ExifFound = $true
                }
            }
            catch {
                Write-Entry -Subtext "Could not download Artwork from plex: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
                $global:errorCount = Increment-GlobalStat 'errorCount'; return
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
                                $global:ConnRefusedCount = Increment-GlobalStat 'ConnRefusedCount'
                            }
                            if ($isConnRefused -and $ConnRefusedCount -ge 3) {
                                HandleScriptExit -Message "[FATAL] Connection refused 3 times. Terminating script."
                            }
                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                $global:ConnRefusedCount = Increment-GlobalStat 'ConnRefusedCount'
                            }
                            if ($isConnRefused -and $ConnRefusedCount -ge 3) {
                                HandleScriptExit -Message "[FATAL] Connection refused 3 times. Terminating script."
                            }
                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                $global:ConnRefusedCount = Increment-GlobalStat 'ConnRefusedCount'
                            }
                            if ($isConnRefused -and $ConnRefusedCount -ge 3) {
                                HandleScriptExit -Message "[FATAL] Connection refused 3 times. Terminating script."
                            }
                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                $global:ConnRefusedCount = Increment-GlobalStat 'ConnRefusedCount'
                            }
                            if ($isConnRefused -and $ConnRefusedCount -ge 3) {
                                HandleScriptExit -Message "[FATAL] Connection refused 3 times. Terminating script."
                            }
                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error


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
                                    $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                }
                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                $global:posterCount = Increment-GlobalStat 'posterCount'
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                    $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                }
                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                $global:posterCount = Increment-GlobalStat 'posterCount'
                                $global:BackgroundCount = Increment-GlobalStat 'BackgroundCount'
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

            }
        }
        catch {
            Write-Entry -Subtext "Could not query entries from movies array, error message: $($_.Exception.Message)" -Path $global:configLogging -Color Red -log Error
            write-Entry -Subtext "At line $($_.InvocationInfo.ScriptLineNumber)" -Path $global:configLogging -Color Red -log Error
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                            }
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:posterCount = Increment-GlobalStat 'posterCount'
                        }

                    }
                    Else {
                        Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                        Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                        $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                            }
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:BackgroundCount = Increment-GlobalStat 'BackgroundCount'
                            $global:posterCount = Increment-GlobalStat 'posterCount'
                        }
                    }
                    Else {
                        Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                        Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                        $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                    $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                }
                                Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                $global:SeasonCount = Increment-GlobalStat 'SeasonCount'
                                $global:posterCount = Increment-GlobalStat 'posterCount'
                            }
                        }
                        Else {
                            Write-Entry -Subtext "Missing poster URL for: $($entry.title)" -Path $global:configLogging  -Color Red -log Error
                            Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                        $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
                                            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

                                        }
                                        Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                        $global:EpisodeCount = Increment-GlobalStat 'EpisodeCount'
                                        $global:posterCount = Increment-GlobalStat 'posterCount'
                                    }
                                }
                                Else {
                                    Write-Entry -Subtext "--------------------------------------------------------------------------------" -Path $global:configLogging  -Color White -log Info
                                    $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error

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
            Write-Entry -Subtext "'$($posterCount-$FallbackCount.count)' times the script took the image from fav provider: $global:FavProvider" -Path $global:configLogging -Color Yellow -log Info
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
        $global:OtherMediaServerHeaders = @{ "Authorization" = "MediaBrowser Token=\"$JellyfinAPIKey\"" }
    }
    if ($UseEmby -eq 'true') {
        CheckEmbyAccess -EmbyUrl $EmbyUrl -EmbyAPI $EmbyAPIKey
        $OtherMediaServerUrl = $EmbyUrl
        $OtherMediaServerApiKey = $EmbyAPIKey
        $global:OtherMediaServerHeaders = @{ "Authorization" = "MediaBrowser Token=\"$EmbyAPIKey\"" }
    }

    $Mode = "backup"
    Write-Entry -Message "Backup Mode Started..." -Path $global:configLogging -Color White -log Info
    Write-Entry -Message "Querying Jelly/Emby libraries..." -Path $global:configLogging -Color White -log Info

    $libsResponse = Invoke-RestMethod -Uri "$OtherMediaServerUrl/Library/VirtualFolders" -Headers $global:OtherMediaServerHeaders

    $posterCount = 0
    $BackgroundCount = 0
    $SeasonCount = 0
    $EpisodeCount = 0

    foreach ($lib in $libsResponse) {
        if ($lib.Name -in $LibsToExclude) { continue }

        $collectionType = $lib.CollectionType.ToLower()
        if ($collectionType -notin @("movies", "tvshows")) { continue }

        Write-Entry -Message "--- Processing Library: $($lib.Name) ---" -Path $global:configLogging -Color Cyan -log Info

        $itemsUrl = "$OtherMediaServerUrl/Items?ParentId=$($lib.ItemId)&Recursive=true&IncludeItemTypes=Movie,Series&fields=Path,Id,Name,Type,ProductionYear,OriginalTitle"
        $items = (Invoke-RestMethod -Uri $itemsUrl -Headers $global:OtherMediaServerHeaders).Items

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
            $posterUrl = "$OtherMediaServerUrl/Items/$($item.Id)/Images/Primary"
            if (!(Test-Path -LiteralPath $posterDest)) {
                try {
                    Invoke-WebRequest -Uri $posterUrl -OutFile $posterDest -ErrorAction SilentlyContinue -Headers $global:OtherMediaServerHeaders
                    $global:posterCount = Increment-GlobalStat 'posterCount'
                    Write-Entry -Subtext "Added: $posterDest" -Path $global:configLogging -Color Green -Log Info
                }
                catch {
                    Write-Entry -Subtext "[ERROR-HERE] Failed to download poster for $($item.Name)" -Path $global:configLogging -Color Red -Log Error
                    $global:errorCount = Increment-GlobalStat 'errorCount'
                }
            }

            # 2. Download Backdrop
            if (!(Test-Path -LiteralPath $backdropDest)) {
                try {
                    Invoke-WebRequest -Uri "$OtherMediaServerUrl/Items/$($item.Id)/Images/Backdrop" -OutFile $backdropDest -ErrorAction SilentlyContinue -Headers $global:OtherMediaServerHeaders
                    $global:BackgroundCount = Increment-GlobalStat 'BackgroundCount'
                    $global:posterCount = Increment-GlobalStat 'posterCount'
                    Write-Entry -Subtext "Added: $backdropDest" -Path $global:configLogging -Color Green -Log Info
                }
                catch {
                    Write-Entry -Subtext "No backdrop found for $($item.Name)" -Path $global:configLogging -Color Yellow -Log Debug
                    $global:errorCount = Increment-GlobalStat 'errorCount'
                }
            }

            if ($item.Type -eq "Series") {
                $seasons = (Invoke-RestMethod -Uri "$OtherMediaServerUrl/Shows/$($item.Id)/Seasons" -Headers $global:OtherMediaServerHeaders).Items
                foreach ($season in $seasons) {
                    $sNum = if ($null -ne $season.IndexNumber) { $season.IndexNumber.ToString("D2") } else { "00" }
                    $sDest = if ($LibraryFolders) { Join-Path $entryDir "Season$sNum.jpg" } else { Join-Path $entryDir "$($rootFolderName)_season$sNum.jpg" }

                    if (!(Test-Path -LiteralPath $sDest)) {
                        try {
                            Invoke-WebRequest -Uri "$OtherMediaServerUrl/Items/$($season.Id)/Images/Primary" -OutFile $sDest -ErrorAction SilentlyContinue -Headers $global:OtherMediaServerHeaders
                            Write-Entry -Subtext "Added: $sDest" -Path $global:configLogging -Color Green -Log Info
                        }
                        catch {
                            Write-Entry -Subtext "No season found for $($item.Name) | Season$sNum" -Path $global:configLogging -Color Yellow -Log Info
                            $global:errorCount = Increment-GlobalStat 'errorCount'
                        }
                    }
                }

                $episodes = (Invoke-RestMethod -Uri "$OtherMediaServerUrl/Shows/$($item.Id)/Episodes?Fields=ParentIndexNumber,IndexNumber" -Headers $global:OtherMediaServerHeaders).Items
                foreach ($ep in $episodes) {
                    $sNum = if ($null -ne $ep.ParentIndexNumber) { $ep.ParentIndexNumber.ToString("D2") } else { "00" }
                    $eNum = if ($null -ne $ep.IndexNumber) { $ep.IndexNumber.ToString("D2") } else { "00" }
                    $naming = "S$($sNum)E$($eNum)"
                    $epDest = if ($LibraryFolders) { Join-Path $entryDir "$naming.jpg" } else { Join-Path $entryDir "$($rootFolderName)_$naming.jpg" }

                    if (!(Test-Path -LiteralPath $epDest)) {
                        try {
                            Invoke-WebRequest -Uri "$OtherMediaServerUrl/Items/$($ep.Id)/Images/Primary" -OutFile $epDest -ErrorAction SilentlyContinue -Headers $global:OtherMediaServerHeaders
                            $global:EpisodeCount = Increment-GlobalStat 'EpisodeCount'
                            $global:posterCount = Increment-GlobalStat 'posterCount'
                            Write-Entry -Subtext "Added: $epDest" -Path $global:configLogging -Color Green -Log Info
                        }
                        catch {
                            Write-Entry -Subtext "No episode found for $($item.Name) | $naming" -Path $global:configLogging -Color Yellow -Log Error
                            $global:errorCount = Increment-GlobalStat 'errorCount'
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
            $global:errorCount = Increment-GlobalStat 'errorCount'; Write-Entry -Subtext "[ERROR-HERE] See above. ^^^ errorCount: $errorCount" -Path $global:configLogging -Color Red -log Error
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
        $imageResponse = Invoke-WebRequest -Uri $ArtUrl -Headers $requestHeaders -UseBasicParsing -ErrorAction Stop
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
            'tc' { $global:EpisodeCount = Increment-GlobalStat 'EpisodeCount' }
            'background' { $global:BackgroundCount = Increment-GlobalStat 'BackgroundCount' }
            'season' { $global:SeasonCount = Increment-GlobalStat 'SeasonCount' }
        }
        $global:UploadCount = Increment-GlobalStat 'UploadCount'
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
