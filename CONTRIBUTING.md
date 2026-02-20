# Contributing to DevChest

Thank you for your interest in contributing to DevChest. This document explains how to propose changes, add new scripts, and open issues or pull requests.

## How to Contribute

### Reporting issues

- Use the [issue templates](https://github.com/groot-arena/devchest/issues/new/choose) when opening an issue (bug report, feature request, update/improvement, or question).
- Search existing issues first to avoid duplicates.
- Include your OS and version, and steps to reproduce when reporting bugs.

### Proposing changes (pull requests)

1. **Fork the repository** and clone your fork locally.

2. **Create a branch** from `main` using the naming convention:
   ```bash
   git checkout -b feat/flavour/package-name
   ```
   Examples:
   - `feat/ubuntu/docker` — new Docker install script for Ubuntu
   - `fix/install-curl-fallback` — fix in main install script
   - `docs/readme-quickstart` — documentation only

3. **Make your changes** and keep commits focused and clear.

4. **Push to your fork**:
   ```bash
   git push origin feat/flavour/package-name
   ```

5. **Open a pull request** against `main`. Use the [PR template](.github/PULL_REQUEST_TEMPLATE.md) and describe what you changed and why.

### Adding a new tool

1. Create a new file under `tools/` named `<tool-id>.sh` (e.g. `my-tool.sh`).
2. Define metadata at the top:
   - `TOOL_ID` (lowercase, `a-z0-9-`), `TOOL_DISPLAY_NAME`, `TOOL_DESCRIPTION`.
   - Optional: `TOOL_SUPPORTED_OS_IDS`, `TOOL_CATEGORIES`, `TOOL_CORE_COMMANDS`, `TOOL_DEBIAN_PACKAGES`, `TOOL_REDHAT_PACKAGES`.
3. Implement `install_<tool_id>` and `uninstall_<tool_id>` (replace `-` with `_` in the function name).
4. Optionally implement `is_<tool_id>_installed` so the tool appears in the uninstall menu when installed.
5. Use only `OS_FAMILY`, `OS_ID`, `OS_VERSION` and helpers from `lib/` (e.g. `dc_log_info`, `dc_apt_install`, `dc_tool_check_deps`). Do not detect OS inside the tool script.

See [REQUIREMENTS.md](REQUIREMENTS.md) for the full tool contract, metadata, and the canonical tool skeleton.

### Code style and CI

- All shell scripts must pass **shellcheck** (no errors; address high-severity warnings) and **shfmt** (consistent formatting).
- Follow the conventions in [REQUIREMENTS.md](REQUIREMENTS.md): `dc_*` / `DC_*` namespacing, `set -euo pipefail`, no `eval` on untrusted input, no unsafe `rm -rf` on user input, no embedded secrets.

### Verification (run locally before pushing)

Run these checks to match what CI runs (see [.github/workflows/lint.yml](.github/workflows/lint.yml)):

1. **ShellCheck** — lint all shell scripts:
   ```bash
   shellcheck lib/*.sh install.sh uninstall.sh tools/*.sh
   ```
   Install: `apt install shellcheck` (Debian/Ubuntu) or [shellcheck.net](https://www.shellcheck.net/).

2. **shfmt** — check or apply formatting:
   ```bash
   shfmt -d -i 2 -ci -bn -sr lib/*.sh install.sh uninstall.sh tools/*.sh
   ```
   To fix formatting:
   ```bash
   shfmt -i 2 -ci -bn -sr -w lib/*.sh install.sh uninstall.sh tools/*.sh
   ```
   Install: `apt install shfmt` (Debian/Ubuntu) or [mvdan.cc/sh](https://mvdan.cc/sh/).

3. **Standards verification** — forbidden patterns (eval, curl|bash, unsafe rm -rf):
   ```bash
   bash scripts/verify-standards.sh
   ```
   Exits non-zero if any forbidden pattern is found.

### What we look for

- **New scripts**: Automation for installing or configuring tools on supported Linux distros.
- **Improvements**: Fixes, better error handling, idempotency, or clearer output in existing scripts.
- **Documentation**: Clear README updates, comments in scripts, or CONTRIBUTING improvements.

### Branch naming

- `feat/<scope>/<short-description>` — new feature or script
- `fix/<scope>/<short-description>` — bug fix
- `docs/<short-description>` — documentation only
- `chore/<short-description>` — maintenance (deps, CI, etc.)

## Questions?

Open a [question/support issue](https://github.com/groot-arena/devchest/issues/new/choose) or start a discussion. We’re happy to help.

Thanks for contributing!
