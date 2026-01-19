import json
import os
import sys
import hashlib
from datetime import datetime

def get_md5(file_path):
    """Calculates MD5 checksum in uppercase."""
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest().upper()

def process_manifest(platform, manifest_path, zip_name):
    plugin_name = "Posterizarr"
    repo = os.getenv("GITHUB_REPOSITORY")
    version_str = os.getenv("VERSION")
    event_name = os.getenv("GITHUB_EVENT_NAME")

    zip_path = os.path.join("release_package", zip_name)

    if not os.path.exists(zip_path):
        print(f"Error: {platform} ZIP not found at {zip_path}")
        return # Skip if file doesn't exist

    checksum = get_md5(zip_path)

    # Load existing or create new
    if os.path.exists(manifest_path):
        with open(manifest_path, "r") as f:
            manifest = json.load(f)
    else:
        manifest = [{
            "name": f"{plugin_name} ({platform})",
            "guid": "f62d8560-6123-4567-89ab-cdef12345678",
            "description": f"Middleware for asset lookup ({platform}). Maps local assets to library items.",
            "overview": f"A custom plugin for Posterizarr acting as a local asset proxy for {platform}.",
            "owner": "Posterizarr",
            "category": "Metadata",
            "versions": []
        }]

    plugin = manifest[0]

    if event_name == "release":
        source_url = f"https://github.com/{repo}/releases/download/{version_str}/{zip_name}"
        changelog = f"Official Release {version_str} for {platform}"
        plugin["versions"] = [v for v in plugin["versions"] if not v["version"].startswith("99.0.")]
    else:
        source_url = f"https://raw.githubusercontent.com/{repo}/builds/{zip_name}"
        changelog = f"Dev build ({platform}): {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        if version_str.startswith("99.0."):
            plugin["versions"] = [v for v in plugin["versions"] if not v["version"].startswith("99.0.")]

    new_version = {
        "version": version_str,
        "changelog": changelog,
        "targetAbi": "10.9.0.0" if platform == "Jellyfin" else "4.8.0.0",
        "sourceUrl": source_url,
        "checksum": checksum
    }

    plugin["versions"].insert(0, new_version)

    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"Successfully updated {manifest_path} for {platform}")

if __name__ == "__main__":
    version = os.getenv("VERSION")
    # Process Jellyfin
    process_manifest("Jellyfin", "manifest.json", f"Posterizarr.Plugin_Jellyfin_v{version}.zip")
    # Process Emby
    process_manifest("Emby", "manifest_emby.json", f"Posterizarr.Plugin_Emby_v{version}.zip")