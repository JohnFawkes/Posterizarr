!!! warning "Requirements"

    Before you begin, make sure you have:

    - **A media server (Plex, Jellyfin, or Emby)**
    - **TMDB API Read Access Token**
        - [Obtain TMDB API Token](https://www.themoviedb.org/settings/api) (Free) -    **NOTE** the **TMDB API Read Access Token** is the really, really long one
    - **Fanart Personal API Key**
        - [Obtain Fanart API Key](https://fanart.tv/get-an-api-key) (Free)
    - **TVDB API Key**
        - [Obtain TVDB API Key](https://thetvdb.com/api-information/signup) (Free) -    **Do not** use `"Legacy API Key"`, it only works with a Project Api Key. *(The key is free for personal use. If configured, Posterizarr can utilize data provided by TheTVDB. If you would like to support their work, please consider paying for a subscription!)*
    - **ImageMagick (already integrated in container)**
        - **Version 7.x is required** - The script handles downloading and using a portable version of ImageMagick for all platforms. **(You may need to run the Script as Admin on first run)**. If you prefer to reference your own installation or prefer to download and install it yourself, goto: [Download ImageMagick](https://imagemagick.org/script/download.php)
    - **Powershell Version (already integrated in container)**
        - 7.x or higher.
    - **FanartTv Powershell Module (already integrated in container)**
        - This module is required, goto: [Install Module](https://github.com/Celerium/Celerium.FanartTV)

## 📏 Image Size Requirements
When uploading custom images through the Web UI or Manual mode, Posterizarr recommends the following dimensions for optimal quality:

- **Posters** (Movies/Shows/Seasons): **1000×1500px** (base) or **2000×3000px** or higher (**2:3 ratio**)
- **Backgrounds**: **1920×1080px** (base) or **3840×2160px** or higher (**16:9 ratio / 4K**)
- **Title Cards**: **1920×1080px** (base) or **3840×2160px** or higher (**16:9 ratio / 4K**)

The Web UI will display warnings if uploaded images are smaller than these recommended sizes, but will still process them.