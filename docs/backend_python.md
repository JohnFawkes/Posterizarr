# Backend Python Architecture & Documentation

This document provides a technical overview of the Python backend files used in Posterizarr's WebUI. The backend is built using FastAPI and serves as the intermediary between the React frontend and the underlying PowerShell scripts or local databases.

---

## Architecture Overview

The backend handles the following core responsibilities:

1. **API Endpoints**: Serves data to the frontend (FastAPI).
2. **Configuration Management**: Reads, writes, and maps the `config.json` file.
3. **Database Operations**: Manages SQLite databases for runtime statistics, exported media, and caching.
4. **Task Orchestration**: Triggers PowerShell scripts via a queue manager or scheduler.

---

## File Breakdown (`webui\backend\`)

### Core API & Application

- **`main.py`**: The primary FastAPI application entry point. It defines all the API routes, initializes the server, handles CORS, and integrates with other backend modules.
- **`auth_middleware.py`**: Handles authentication and security middleware for the FastAPI routes, ensuring that unauthorized users cannot trigger operations or read configurations.

### Configuration & Data Mapping

- **`config_database.py`**: Interacts with the backend database storing configuration states.
- **`config_mapper.py`**: A crucial file that maps frontend JSON/API payloads to the expected `config.json` format required by the PowerShell scripts. It ensures data sanitization and type casting.
- **`config_tooltips.py`**: Stores the tooltip descriptions and metadata for configuration fields, served dynamically to the frontend `ConfigEditor`.
- **`defaults.py`**: Contains default settings, schemas, and fallback configurations for the application.

### Databases & State

- **`database.py`**: The core SQLAlchemy/SQLite configuration file that establishes connections and base models.
- **`media_export_database.py`**: Manages the database schema and operations for media exported from Plex/Jellyfin/Emby.
- **`runtime_database.py`**: Manages the schema for runtime statistics (successes, failures, durations).
- **`server_libraries_database.py`**: Caches the library configurations of connected media servers.

### Task Management & Scheduling

- **`queue_manager.py`**: Manages the execution queue for PowerShell scripts, ensuring that multiple operations (like manual generation vs library sync) don't conflict or overlap destructively.
- **`scheduler.py`**: Handles cron-like scheduling for automated tasks (e.g., triggering `Posterizarr.ps1` at set intervals).
- **`runtime_parser.py`**: Parses the output of the PowerShell scripts to update the `runtime_database.py` with execution statistics.

### Utilities

- **`logs_watcher.py`**: A utility that monitors Posterizarr log files in real-time, allowing the frontend to stream logs via WebSockets.
- **`improve_logging.py`**: Enhances standard Python logging for the backend application.
- **`overlay_generator.py`**: A backend helper script, potentially used for generating quick preview overlays for the UI without invoking the full PowerShell stack.
- **`migrate_runtime_data.py`**: A migration script used to upgrade database schemas or runtime data formats between versions.

---

## Contribution Guidelines
When making a Pull Request to the Python backend:

- 
- **New Endpoints**: Define routes in `main.py` (or a dedicated router file if it grows) and ensure they are protected by `auth_middleware.py`.
- **Database Schema Changes**: Ensure you provide a migration strategy or update `migrate_runtime_data.py` so existing users do not lose their data.
- **Configuration Parsing**: If a new feature introduces a new `config.json` field, update `config_mapper.py` and provide a tooltip in `config_tooltips.py`.
