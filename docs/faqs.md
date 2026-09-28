# Frequently Asked Questions (FAQs)

## Plex: Secure Connection Issues

**Question:** I changed my Plex server to "Secure connections: Required" and now Posterizarr cannot reconnect. I tried using the server's IP address and port, but it doesn't work. What should I do?

**Answer:** 
When you require secure connections in Plex, you can no longer connect using a plain IP address because the SSL certificate is tied to a specific Plex domain name. 

To fix this, you must use your server's exact, secure domain name. This is a long string that looks something like this:
`https://192-168-1-50.abcdef1234567890.plex.direct:32400`

### How to find your secure Plex URL:

1.  Open your browser and navigate to the following URL (replace `YOUR_TOKEN_HERE` with your actual Plex token):
    `https://plex.tv/api/resources?includeHttps=1&X-Plex-Token=YOUR_TOKEN_HERE`
2.  Look for the `<Connection>` tag that has `protocol="https"` and `local="1"`.
3.  Copy the value of the `uri` attribute. It should look like the `plex.direct` example above.
4.  Use this full URI as your Plex URL in the Posterizarr configuration.

!!! tip "Finding your Plex Token"
    If you don't know how to find your Plex token, refer to the [official Plex documentation](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/).

## UI: Action Center Alerts

**Question:** I just setup Posterizarr and I'm getting a lot of errors/alerts in my Action Center. What do I do with these?

**Answer:** 
Don't worry! These aren't system errors. The **Action Center** is simply a list of assets (posters, backgrounds, etc.) that Posterizarr thinks you might want to review. 

Common reasons for alerts include:
*   A poster was found but in a different language than your preferred one.
*   An image was sourced from a secondary provider (like Fanart.tv) instead of your primary one (like TMDB).
*   The text on a logo might be truncated.

You can read more about how to manage these in the [Action Center Guide](action_center.md).

## Plex & Automation: Why does Posterizarr upload artwork during Tautulli / *Arr runs even if `PlexUpload` is `false`?

**Question:** I set `PlexUpload: "false"` in my configuration because I use Kometa to manage asset uploads and overlays. However, when new media is imported via Tautulli or Radarr/Sonarr triggers, Posterizarr still uploads the poster/background directly to Plex. Is this intended?

**Answer:** 
**Yes, this is completely intentional by design.**

Here is why:
* **`PlexUpload: "false"`** is designed specifically for **scheduled, batch, and normal library runs**. In this workflow, Posterizarr generates and stores stylized assets in your `/assets` directory. Kometa then runs subsequently on a schedule, applies its own overlays/metadata, and pushes the final combined artwork to Plex.
* **Auto-triggers (Tautulli and Radarr/Sonarr webhooks)** are designed for **instant real-time fulfillment**. When a new movie, show, or episode is added, the trigger's sole purpose is to immediately supply custom Posterizarr artwork to your media server so the new media has a clean, styled poster immediately. If uploads were disabled in trigger mode, the trigger would have no visible effect in Plex until a subsequent Kometa cycle ran (which might be hours or days away).

### Recommended Workflows

1. **If you want immediate artwork upon media addition (Recommended):**
   Leave Tautulli or *Arr triggers enabled. Newly added media receives styled Posterizarr artwork right away, and whenever Kometa runs later, Kometa will add its overlay flags on top.
2. **If you want ONLY Kometa to ever touch Plex artwork:**
   **Disable Tautulli and *Arr triggers entirely**. Instead, schedule Posterizarr to run periodically (e.g., daily at 02:00) before your scheduled Kometa run (e.g., daily at 03:00). With `PlexUpload: "false"`, Posterizarr will generate images exclusively into the `/assets` directory, and Kometa will perform 100% of the uploads to Plex.
