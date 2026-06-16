# Posterizarr Telemetry

Posterizarr includes an anonymous, opt-out telemetry system to help understand the usage and deployment environments of the script.

The developer instructions for deploying the telemetry server itself can be found in the [telemetry README](https://github.com/fscorrupt/posterizarr/blob/main/telemetry-worker/README.md) file located alongside the worker script. This page explains what data Posterizarr collects and how you can disable it.

## Why do we collect telemetry?
We use this data to understand how many unique active installations exist, what operating systems Posterizarr is running on, and which media servers (Plex, Jellyfin, Emby) are most popular.

Because Posterizarr is open-source and downloaded manually, it can be difficult to know if the script is actually being used. This high-level data helps guide development priorities and keeps motivation high by showing the real-world impact of the project!

## What is collected?
When Posterizarr runs, it generates a random unique identifier (UUID) that is stored locally in your `.cache` folder. A very small JSON payload is sent during execution:

- **Instance ID**: A randomly generated UUID used to deduplicate installation counts.
- **App Version**: The version of Posterizarr you are currently running.
- **OS Platform**: Your operating system (e.g., Windows, Linux).
- **Target Server**: Which media server you have enabled.
- **Country**: Cloudflare automatically determines the 2-letter country code of the request origin.

### What is NOT collected:
- Your IP Address
- Your filenames, library names, or media data
- Your API keys, domains, or server addresses
- Any PII (Personally Identifiable Information)

## How to Disable Telemetry
Telemetry is completely optional, and we respect your privacy. If you do not wish to participate, you can easily disable it in your configuration file.

Open your `config.json` file and locate the `PrerequisitePart` block:

```json
  "PrerequisitePart": {
    "telemetry": "false"
  }
```

Set the `telemetry` value to `false`. Posterizarr will immediately stop sending any telemetry data.
