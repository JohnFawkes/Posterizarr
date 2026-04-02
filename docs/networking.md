# Networking

## FAQ: Why the change to 127.0.0.1?

Previously, the application listened on `0.0.0.0` by default, which means it was accessible from any device on your network. For security reasons, the default has been changed to `127.0.0.1` (localhost) for non-Docker installations. This ensures that the application is only accessible from the machine it's running on unless you explicitly choose to expose it.

!!! note "Docker Users"
    This change does not affect Docker installations, which still default to `0.0.0.0` for ease of use within containers.

## Troubleshooting: Cannot access the Web UI from another device?

By default, the app now listens on `127.0.0.1` (localhost) for security. If you are running this on a server and need to access it via your network, set the environment variable `APP_HOST=0.0.0.0` before starting the application.

## Recommended: Using a Reverse Proxy

The most secure and recommended way to expose Posterizarr to your network or the internet is by using a reverse proxy (such as Nginx, Caddy, or Traefik).

When using a reverse proxy, you **do not need to change** `APP_HOST`. You can leave Posterizarr safely running on its default `127.0.0.1` (localhost) and configure your reverse proxy to forward traffic to Posterizarr's internal port. This is the recommended way because the application is still usable with `127.0.0.1` while securely handling external requests through the proxy.

## How to set the APP_HOST environment variable

If you prefer to expose the application directly without a reverse proxy, how you set the `APP_HOST` environment variable depends entirely on how you are running the application. Since this change specifically affects those not using Docker (who want LAN access), here are the three most common ways to set it:

### 1. Using a .env file

Posterizarr supports `.env` files out of the box. This is the easiest way to manage your environment variables if you are not using a reverse proxy. Simply create a file named `.env` in the same folder as `main.py` with the following content:

```plaintext
APP_HOST=0.0.0.0
PORT=8000
```

### 2. Persistent (System Service / Systemd)

If you are running your app as a background service on a Linux server (like Ubuntu or Raspberry Pi OS), you likely have a `.service` file. You need to add the `Environment` line to your configuration:

1.  Edit the service file (usually in `/etc/systemd/system/posterizarr.service`).
2.  Add the variable under the `[Service]` section:
    ```ini
    [Service]
    ExecStart=/usr/bin/python3 /path/to/main.py
    Environment="APP_HOST=0.0.0.0"
    User=youruser
    ```
3.  Reload and restart:
    ```bash
    systemctl daemon-reload && systemctl restart posterizarr
    ```

### 3. Temporary (Command Line)

If you are just testing the app or running it manually from a terminal, you can prepend the variable to the start command.

**Linux / macOS:**
```bash
APP_HOST=0.0.0.0 python main.py
```

**Windows (PowerShell):**
```powershell
$env:APP_HOST="0.0.0.0"; python main.py
```

**Windows (Command Prompt):**
```cmd
set APP_HOST=0.0.0.0 && python main.py
```

---

## Why 0.0.0.0 vs 192.168.x.x?

*   **0.0.0.0**: Tells the app to listen on every available network interface (Ethernet, Wi-Fi, and Localhost). This is the easiest "catch-all" for users.
*   **192.168.1.50**: Tells the app to only listen on that specific IP. If the server's IP changes (DHCP), the app will fail to start.

**Verdict**: Most users will prefer setting `APP_HOST=0.0.0.0` as it is the most flexible for home server environments.
