# DevChest

DevChest simplifies and accelerates the setup of your Linux environment with a curated collection of Bash automation scripts. It installs and configures a consistent set of development and everyday tools across supported Linux distributions.

> For implementation details and contracts (for humans and AI agents), see [REQUIREMENTS.md](REQUIREMENTS.md).

---

## Overview

DevChest provides a single entry point for installing and uninstalling tools:

- `install.sh` – install selected tools.
- `uninstall.sh` – uninstall selected tools.

The entry scripts:

- Detect your OS and validate support.
- Run pre-flight checks (sudo, package manager, network, curl/wget).
- Discover tools from `tools/*.sh` dynamically.
- Present a multi-select menu to install or uninstall tools.
- Run each tool script in an idempotent, distro-aware way.

---

## Supported distributions

DevChest v1 supports the following distributions and versions:

- **Ubuntu:** 20.04 and newer (LTS).
- **Debian:** 10 and newer.
- **RHEL / CentOS (including Stream):** 8 and newer.
- **Fedora:** 39 and newer.

If your OS or version is not supported, DevChest will abort early with a clear message instead of failing midway.

---

## Requirements

Runtime and environment:

- A supported Linux distribution (see above).
- **Bash 4.0+**.
- **`sudo`** (or run as root).
- **Network access** (for fetching packages and repositories).
- At least one of:
  - `curl`
  - `wget`

Git is **only required** if you choose to clone the repository locally. Remote one-liner usage does **not** require `git`.

DevChest will check for required dependencies at startup and offer to install missing ones when possible, or abort with a clear error if it cannot safely continue.

---

## Quick start (remote)

Install DevChest tools directly via `curl`:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/groot-arena/devchest/main/install.sh)"
```

Or via `wget`:

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/groot-arena/devchest/main/install.sh)"
```

This will:

1. Detect your OS.
2. Run pre-flight checks (sudo, package manager, network, curl/wget).
3. Show a multi-select menu of available tools.
4. Install each selected tool for your distro.

---

## Local clone usage

Clone and run from a local checkout:

```bash
git clone https://github.com/groot-arena/devchest.git
cd devchest
sudo ./install.sh
```

To uninstall tools from a local checkout:

```bash
sudo ./uninstall.sh
```

Local usage is functionally equivalent to the remote one-liners, but makes it easier to inspect and modify scripts.

---

## Uninstallation

You can uninstall tools the same way you installed them.

Remote uninstall (via `curl`):

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/groot-arena/devchest/main/uninstall.sh)"
```

Remote uninstall (via `wget`):

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/groot-arena/devchest/main/uninstall.sh)"
```

From a local clone:

```bash
sudo ./uninstall.sh
```

The uninstall flow:

- Detects which tools DevChest believes are installed (via tool-specific checks).
- Presents a multi-select uninstall menu.
- For each chosen tool:
  - Removes packages and system integration DevChest added.
  - Optionally asks whether to remove user data/config (default is **no**).
- Prints a summary of:
  - Installed / removed successfully.
  - Skipped (with reason).
  - Failed (with reason).

---

## How it works

High-level architecture:

- **Entry scripts**
  - `install.sh` and `uninstall.sh` are thin shims.
  - Handle OS detection, sudo, pre-flight dependency checks, and library loading.
  - Delegate to `dc_main_install` / `dc_main_uninstall` in `lib/`.

- **Libraries (`lib/`)**
  - `common.sh`: strict mode, OS detection, logging, core dependency checks, sudo helpers.
  - `debian.sh`: APT helpers for Debian/Ubuntu.
  - `redhat.sh`: DNF/YUM helpers for RHEL/CentOS/Fedora.
  - `menu.sh`: menu rendering via `whiptail`, `dialog`, or a text-only fallback.

- **Tools (`tools/*.sh`)**
  - One script per tool, with:
    - Metadata (`TOOL_ID`, `TOOL_DISPLAY_NAME`, `TOOL_DESCRIPTION`, optional categories and OS support).
    - `install_<tool_id>` and `uninstall_<tool_id>` functions.
    - Optional `is_<tool_id>_installed` detection function.
  - Each tool script is idempotent and uses the shared helpers instead of doing its own OS detection or package-manager plumbing.

For full contracts and examples (especially for new tools or automated agents), see [REQUIREMENTS.md](REQUIREMENTS.md).

---

## Tools

Tools are discovered dynamically from `tools/*.sh` – nothing is hard-coded in the entry scripts.

Each tool script:

- Declares a stable `TOOL_ID` and display metadata.
- Declares optional dependency metadata (packages and commands).
- Implements install/uninstall for all supported distros.
- May restrict itself to specific OS IDs via metadata (in which case it will be hidden on unsupported distros).

Example (current placeholder):

- `tools/vscode.sh` – Visual Studio Code installation logic.

Planned categories (for future profiles):

- Developer tools (IDEs, editors, language runtimes).
- Bug-hunting / security tools.
- Everyday utilities (browsers, terminals, etc.).

---

## Contributing

Contributions are welcome—whether you want to:

- Add a new tool script under `tools/`.
- Improve the core framework in `lib/`.
- Fix bugs or improve robustness.
- Enhance documentation.

Before contributing:

1. Read [CONTRIBUTING.md](CONTRIBUTING.md) for:
   - Branching and commit guidelines.
   - Code style and CI expectations.
   - How to open issues and pull requests.
2. Read [REQUIREMENTS.md](REQUIREMENTS.md) for:
   - Architecture and responsibilities (entry scripts vs `lib/` vs tools).
   - Tool metadata conventions and naming.
   - Dependency handling and idempotency rules.
   - Security and forbidden patterns.

All shell scripts should:

- Target Bash 4.0+.
- Pass `shellcheck` and `shfmt` in CI.
- Follow the `dc_*` / `DC_*` namespacing and strict-mode conventions.

---

## Support

If you run into issues or have questions:

- Open an issue at: <https://github.com/groot-arena/devchest/issues>

Please include:

- Your distro and version.
- The exact command you ran.
- Relevant output from DevChest (especially the final summary and any `[ERROR]` logs).

---

## License

DevChest is open source software. See [LICENSE](LICENSE) for details.