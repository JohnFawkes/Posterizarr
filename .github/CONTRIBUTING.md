# Contributing to Posterizarr

First off, thank you for taking the time to contribute! 🎉 Contributions from the community keep Posterizarr improving and supporting more media setups.

Please take a moment to review this document before submitting contributions.

---

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Pull Requests](#pull-requests)
- [Pull Request Guidelines & Checklist](#pull-request-guidelines--checklist)
- [Project Architecture Overview](#project-architecture-overview)
- [Development & Testing](#development--testing)
- [Questions & Community](#questions--community)

---

## Code of Conduct

This project and everyone participating in it is governed by the [Posterizarr Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please check existing issues to ensure it hasn't already been reported.

When opening an issue:
- Use the **[BUG] Bug Report** template.
- Specify your environment (Docker, Windows, Linux, macOS, Unraid, etc.) and target media server (Plex, Jellyfin, Emby).
- **Attach logs:**
  - **Via Web UI (Recommended):** Open the Log Viewer in the Web UI and click **"Gather Support Logs"** to download an automatically compiled, sanitized support zip.
  - **Via CLI:** Run `Posterizarr.ps1 -GatherLogs` (or `docker exec -it posterizarr pwsh /app/Posterizarr.ps1 -GatherLogs` in Docker) to generate the sanitized support zip.
  - **Manual:** If neither is accessible, attach relevant redacted logs from `Logs/` or `UILogs/` (ensure API keys, tokens, and personal URLs are removed).

> [!NOTE]
> For security vulnerabilities, refer to our [Security Policy](../SECURITY.md). Do not report security flaws via public issues.

### Suggesting Enhancements

Feature requests are welcome! Please open an issue using the **Feature Request** template explaining:
- The problem you are trying to solve.
- Your proposed solution or workflow.
- Any alternative approaches considered.

### Pull Requests

> [!IMPORTANT]
> **All pull requests must target the `dev` branch.** Pull requests targeted at `main` will be asked to rebase against `dev`.

1. **Fork the repository** and clone your fork locally.
2. Create a branch off `dev`:
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b feature/my-new-feature
   ```
3. Make your modifications adhering to the project's formatting and style.
4. Verify your changes across relevant media servers and environments.
5. Follow the [Pull Request Guidelines & Checklist](#pull-request-guidelines--checklist) below.
6. Submit your PR against `fscorrupt/posterizarr:dev`.

---

## Pull Request Guidelines & Checklist

Every PR must comply with the following checklist (also enforced in our pull request template):

- [ ] **Target `dev` branch:** Do not target `main`.
- [ ] **Synchronize Version Numbers:**
  - Bump `$CurrentScriptVersion` in `Posterizarr.ps1` (e.g. line 78).
  - Update `Release.txt` with the matching version number. *(This is required because the script compares against `Release.txt` to detect newer versions).*
- [ ] **No Images or Binaries:** Do not commit poster images, logs, temporary files, or unnecessary binary assets into git.
- [ ] **Documentation:** If your PR adds or alters configuration options or endpoints, update the documentation in `docs/` or `config.example.json`.
- [ ] **Follow Existing Style:** Match existing code formatting in PowerShell (`.ps1`), Python (`.py`), and WebUI (`.js`, `.html`, `.css`).

---

## Project Architecture Overview

- **PowerShell Core (`Posterizarr.ps1`, `Start.ps1`, `modules/`):** Core automation logic, image processing pipelines, overlay rendering, and media server API integration.
- **Web UI & Backend (`webui/`, `update_manifest.py`):** Frontend dashboard, REST/WebSocket API endpoints, and configuration managers.
- **Documentation (`docs/`, `mkdocs.yml`):** MkDocs Material documentation site.

---

## Development & Testing

When testing changes locally, please verify that:
- Core operations execute cleanly without PowerShell terminating errors.
- Web UI endpoints respond properly and don't introduce regressions to other server types.
- Tested environment(s) are noted in your PR description:
  - **OS:** Docker, Windows, Linux, macOS, Unraid
  - **Media Server:** Plex, Jellyfin, Emby

---

## Questions & Community

Need help or want to bounce an idea around before coding?
- **Discord:** Join our [Discord Server](https://discord.gg/fYyJQSGt54)
- **Direct Contact:** Reach out to `fs.corrupt` on Discord.
