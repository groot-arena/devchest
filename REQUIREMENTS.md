# DevChest — Requirements

## 1. Project overview

| Item | Description |
|------|-------------|
| **Name** | DevChest |
| **Purpose** | Simplify and accelerate Linux environment setup via curated automation scripts that install and configure development and everyday tools. |
| **Entry point** | Install: `install.sh`<br>Uninstall: `uninstall.sh` |
| **Target users** | Users who want a quick, repeatable way to get a dev/everyday stack on supported Linux distros. |

---

## 2. Supported platforms and assumptions

### 2.1 Supported operating systems

DevChest v1 supports the following Linux distributions and versions:

- **Ubuntu:** 20.04 and newer (LTS releases).
- **Debian:** 10 and newer.
- **RHEL / CentOS (including Stream):** 8 and newer.
- **Fedora:** 39 and newer (latest stable releases).

If the detected OS does not match one of the supported IDs and minimum versions, DevChest must:

- Abort early with a clear error message.
- Exit with a non-zero status.

### 2.2 Shell requirements

- **Minimum Bash version:** 4.0 or newer.
- All scripts must start with:

  ```sh
  #!/usr/bin/env bash
  set -euo pipefail
  ```

  and use a safe `IFS` where needed, following modern Bash best practices.

---

## 3. Stated requirements (refined)

### 3.1 Core requirements

- **Supported operating systems:** Ubuntu, Debian, CentOS, RHEL, Fedora (see version minima above).
- **Runtime:** Bash (4.0+).
- **Network:** Required for fetching scripts and packages; DevChest fails fast if network is unavailable.
- **Behavior:** Detect OS, run pre-flight dependency checks, present a CLI menu for tool selection, then run the appropriate setup per selected tool.
- **Tools list:** Discovered dynamically from script files in `tools/`; no hard-coded tool list in entry scripts.

### 3.2 Usage

- **Remote install (curl):**
  ```sh
  sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/groot-arena/devchest/main/install.sh)"
  ```
- **Remote install (wget):**
  ```sh
  sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/groot-arena/devchest/main/install.sh)"
  ```
- **Remote uninstall (curl):**
  ```sh
  sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/groot-arena/devchest/main/uninstall.sh)"
  ```
- **Remote uninstall (wget):**
  ```sh
  sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/groot-arena/devchest/main/uninstall.sh)"
  ```
- **Local clone:**
  ```sh
  sudo ./install.sh
  sudo ./uninstall.sh
  ```

These one-liners must work without any mode-specific path assumptions (remote vs local).

---

## 4. Architecture overview

DevChest is a modular Bash framework with three main layers:

1. **Entry scripts (`install.sh`, `uninstall.sh`)**
   - Ultra-thin bootstrap shims.
   - Handle path resolution, privilege escalation, OS detection, and pre-flight checks.
   - Delegate all core logic to functions in `lib/`.

2. **Libraries (`lib/`)**
   - Contain shared framework code:
     - OS detection.
     - Logging.
     - Dependency checks.
     - Menu/TUI handling.
     - Package management helpers.
   - No side-effectful logic at top-level on `source` (only definitions and safe initialization).

3. **Tools (`tools/*.sh`)**
   - One script per tool (e.g. `docker.sh`, `vscode.sh`).
   - Expose metadata and idempotent `install_*` / `uninstall_*` functions.
   - Use `lib/` helpers for all shared concerns (logging, packages, dependency checks).

This design is intended to be consumed by automated agents and human contributors alike. Each layer has a clearly defined contract so that tools can be implemented and extended without modifying core logic.

---

## 5. Repository layout

```text
devchest/
├── install.sh                 # Main entry point for installation (thin shim)
├── uninstall.sh               # Main entry point for uninstallation (thin shim)
├── tools/                     # Tool install/uninstall scripts (one per tool)
│   ├── google-chrome.sh       # Google Chrome logic
│   ├── docker.sh              # Docker Engine logic
│   ├── nvm.sh                 # Node Version Manager logic
│   ├── vscode.sh              # Visual Studio Code logic
│   └── ...                    # Additional tool scripts
├── lib/                       # Shared utility functions and helpers
│   ├── common.sh              # OS detection, logging, sudo, path resolution, core deps
│   ├── debian.sh              # Debian/Ubuntu-specific helpers
│   ├── redhat.sh              # CentOS/RHEL/Fedora-specific helpers
│   └── menu.sh                # TUI/text menu helpers (whiptail/dialog/fallback)
├── .github/                   # GitHub templates and workflows
│   ├── ISSUE_TEMPLATE/
│   │   ├── config.yml
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   ├── update.md
│   │   └── question.md
│   └── PULL_REQUEST_TEMPLATE.md
├── README.md                  # Project overview, quick start, usage
├── CONTRIBUTING.md            # Contribution guidelines and PR process
├── REQUIREMENTS.md            # Detailed requirements and architecture (this file)
└── LICENSE                    # Open source license (MIT/Apache 2.0)
```

---

## 6. Entry scripts (`install.sh`, `uninstall.sh`)

### 6.1 `install.sh`

**Purpose:** Main entry point for installing tools.

**Responsibilities:**

1. **Bootstrap:**
   - Ensure running under Bash 4+.
   - Resolve repository root and `lib/` path, compatible with:
     - Remote `bash -c "$(curl …)"` / `bash -c "$(wget …)"`.
     - Local `./install.sh` from a clone.

2. **Privilege handling:**
   - If `EUID == 0`: continue.
   - Else:
     - Run `sudo -v` once at startup to cache credentials.
     - If `sudo -v` fails or user cancels, abort with a clear error and non-zero exit.

3. **Library loading:**
   - Source `lib/common.sh`, `lib/debian.sh`, `lib/redhat.sh`, `lib/menu.sh`.

4. **Pre-flight checks:**
   - Call a `dc_preflight_install` (or equivalent) function that:
     - Detects OS and validates support.
     - Checks core dependencies (Section 9.4).
     - Handles interactive install of missing core/UI deps.

5. **Main orchestration:**
   - After successful pre-flight, call a single main function in `lib/`, e.g.:
     - `dc_main_install`.
   - That function is responsible for:
     - Discovering tools from `tools/`.
     - Building the installation menu (multi-select).
     - Running selected tools’ install functions.
     - Printing a summary (success, skipped, failed).

`install.sh` must not contain complex business logic, large `case` blocks, or per-tool handling.

### 6.2 `uninstall.sh`

**Purpose:** Main entry point for uninstalling tools.

**Responsibilities:**

1. Same bootstrap and privilege steps as `install.sh`.
2. Same `lib/` loading.
3. Same pre-flight checks (`dc_preflight_uninstall` or shared).
4. Call a single orchestration function, e.g.:
   - `dc_main_uninstall`, which:
     - Discovers tools from `tools/`.
     - Determines which tools are “installed” via per-tool detection helpers.
     - Shows only installed tools in a multi-select uninstall menu.
     - Invokes uninstall functions for selected tools.
     - Optionally prompts for user-data purge per tool.
     - Prints a summary at the end.

### 6.3 Remote bootstrap behavior

DevChest supports two execution modes for the entry scripts:

1. **Local mode**
   - User has cloned the repository locally.
   - `install.sh` / `uninstall.sh` are executed from within the cloned repo.
   - The script resolves the repo root directory using its own path (e.g. `BASH_SOURCE[0]`) and loads `lib/` and `tools/` from there.

2. **Remote mode (curl/wget)**
   - User runs a one-liner such as:
     - `sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/groot-arena/devchest/main/install.sh)"`
     - `sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/groot-arena/devchest/main/install.sh)"`
   - In this mode, the script is read from stdin and has no adjacent `lib/` or `tools/` directory.

In **remote mode**, the entry script must:

1. Detect that it is not running from a checked-out repository (e.g. `BASH_SOURCE[0]` is `-bash` or `lib/common.sh` cannot be found relative to the script).
2. Create a temporary working directory using `mktemp -d` under the system temp directory (e.g. `/tmp/devchest-XXXXXXXX`).[web:61][web:65]
3. Download the DevChest repository tarball (for the main branch or a tagged release) using `curl` or `wget`:
   - Example (legacy GitHub tarball URL):
     - `https://github.com/groot-arena/devchest/tarball/main`
   - The script must use `curl -L` or `wget` with redirect-following and extract the tarball into the temporary directory.[web:70][web:66]
4. Change directory into the extracted repository root (e.g. `devchest-main`).
5. Re-exec the real `install.sh` (or `uninstall.sh`) from the extracted tree, forwarding any flags/arguments:
   - This second-stage script then runs in **local mode**, with `lib/` and `tools/` available via relative paths.
6. After the invoked script finishes:
   - By default, remove the temporary directory to keep the system clean.
   - Optionally support a debug flag (e.g. `--keep-workdir` or environment variable) to skip cleanup.

Remote bootstrap **must not** depend on `git` being installed; repository content is obtained via HTTP tarball download only. Git remains optional and is required only if the user chooses to clone the repository manually.

---

## 7. Libraries (`lib/`)

### 7.1 `lib/common.sh`

**Purpose:** Core framework utilities and global initialization.

**Responsibilities:**

- **Strict mode & environment:**
  - Enforce `set -euo pipefail` and safe `IFS` at the framework level.
- **Path resolution:**
  - Determine the DevChest root directory whether running:
    - From a remote one-liner (script loaded via stdin).
    - From a local checkout.
- **OS detection:**
  - Detect OS using `/etc/os-release` where available; fall back to other `*-release` files as needed.
  - Export:
    - `OS_FAMILY` (e.g. `debian`, `redhat`).
    - `OS_ID` (e.g. `ubuntu`, `debian`, `centos`, `rhel`, `fedora`).
    - `OS_VERSION` (normalized).
  - Validate versions against supported minima (Section 2); abort if unsupported.
- **Logging:**
  - Provide standard logging helpers:
    - `dc_log_info`, `dc_log_warn`, `dc_log_error`.
    - `dc_die` for fatal errors (logs and exits non-zero).
  - Prefix logs with `[INFO]`, `[WARN]`, `[ERROR]` and time stamps where helpful.
- **Privilege helpers:**
  - `dc_ensure_root_or_sudo`:
    - Implement the `sudo -v` logic for non-root, or confirm root.
- **Dependency helpers:**
  - `dc_check_command <cmd>`: return success if `command -v` finds `<cmd>`.
  - `dc_require_core_dep <capability> <cmd1> [cmd2…]`:
    - Ensure at least one of the given commands exists or can be installed.
    - If user refuses or all install attempts fail, abort.
  - `dc_offer_optional_dep <description> <pkg>`:
    - Prompt to install optional deps (e.g. UI helpers).
    - If user refuses, mark feature as unavailable but continue.
- **User prompts:**
  - Simple `yes/no` prompts using `read`/`printf`, working before any TUI is available.
- **Summary aggregation:**
  - Helpers for recording per-tool outcomes: `dc_record_result <tool_id> <status> <reason>`.

### 7.2 `lib/debian.sh`

**Purpose:** Debian/Ubuntu-specific helpers.

**Responsibilities:**

- Provide functions like:
  - `dc_apt_update_cache`.
  - `dc_apt_install <pkg...>`.
  - `dc_apt_remove <pkg...>`.
- Wrap APT/DPKG with consistent logging and error handling.
- Provide distro checks:
  - `dc_is_ubuntu`, `dc_is_debian`.

### 7.3 `lib/redhat.sh`

**Purpose:** CentOS/RHEL/Fedora-specific helpers.

**Responsibilities:**

- Provide functions like:
  - `dc_yum_or_dnf_install <pkg...>`.
  - `dc_yum_or_dnf_remove <pkg...>`.
  - `dc_yum_or_dnf_update_cache`.
- Handle `dnf` vs `yum` automatically based on OS version.
- Provide distro checks:
  - `dc_is_rhel`, `dc_is_centos`, `dc_is_fedora`.

### 7.4 `lib/menu.sh`

**Purpose:** Menu and TUI behavior.

**Responsibilities:**

- Detect available menu UIs:
  - Prefer `whiptail`, then `dialog`, else fall back to a text-only menu.
- Provide menu helpers:
  - Multi-select checklist for tool installation/uninstallation.
  - Single-choice menus where needed.
- Implement a plain-text fallback that:
  - Uses numbered lists and `read` prompts.
  - Works even if `whiptail`/`dialog` are missing.
- No tool-specific or business logic; only menu rendering and choice parsing.

---

## 8. Tool scripts (`tools/*.sh`)

### 8.1 Purpose and constraints

- One script per tool, containing all logic for that tool across:
  - Install and uninstall.
  - All supported distros (using shared helpers).
- Tools must be:
  - **Idempotent**: safe on repeated runs without duplicate changes.
  - **Side-effect controlled**: uninstall only removes what DevChest added, via explicit markers.

### 8.2 Naming and structure

- Files under `tools/` follow the pattern:
  - `<tool>.sh` (e.g. `google-chrome.sh`, `docker.sh`).
- Each file must define:
  - Metadata variables (see below).
  - An `install_<tool_id>` function.
  - An `uninstall_<tool_id>` function.
  - Optionally `is_<tool_id>_installed` function.

Dashes in `TOOL_ID` map to underscores in function names (e.g. `TOOL_ID="google-chrome"` → `install_google_chrome`).

### 8.3 Metadata interface

Each tool script **must** expose the following variables:

- `TOOL_ID`: stable, machine-readable ID (lowercase, `a-z0-9-`).
- `TOOL_DISPLAY_NAME`: human-friendly name (e.g. `Google Chrome`).
- `TOOL_DESCRIPTION`: short sentence for menu display.
- `TOOL_SUPPORTED_OS_IDS` (optional):
  - Array of OS IDs for which this tool is supported (e.g. `("ubuntu" "debian" "fedora")`).
  - If not set, defaults to “all supported OSes”.
- `TOOL_CATEGORIES` (optional):
  - Array of category tags (e.g. `("dev" "browser" "frontend")`) to support future profiles.

Dependency metadata (optional but recommended):

- `TOOL_CORE_COMMANDS`: commands that indicate the tool is present (e.g. `("code")`).
- `TOOL_DEBIAN_PACKAGES`: Debian/Ubuntu package names used to install this tool.
- `TOOL_REDHAT_PACKAGES`: RHEL/CentOS/Fedora package names used to install this tool.

Framework helpers will use these to check and offer to install dependencies where appropriate.

### 8.4 Canonical tool script skeleton

```sh
#!/usr/bin/env bash

# Metadata
TOOL_ID="google-chrome"
TOOL_DISPLAY_NAME="Google Chrome"
TOOL_DESCRIPTION="Google Chrome browser"

TOOL_SUPPORTED_OS_IDS=("ubuntu" "debian" "fedora")
TOOL_CATEGORIES=("browser" "dev")

TOOL_CORE_COMMANDS=("google-chrome")
TOOL_DEBIAN_PACKAGES=("google-chrome-stable")
TOOL_REDHAT_PACKAGES=("google-chrome-stable")

install_google_chrome() {
  dc_log_info "Installing ${TOOL_DISPLAY_NAME}..."

  # Respect tool-level dependencies (may prompt user).
  if ! dc_tool_check_deps "${TOOL_ID}"; then
    dc_log_warn "Skipping ${TOOL_DISPLAY_NAME} install due to missing dependencies."
    return 0
  fi

  case "$OS_FAMILY" in
    debian)
      dc_debian_install_google_chrome
      ;;
    redhat)
      dc_redhat_install_google_chrome
      ;;
    *)
      dc_log_error "Unsupported OS family '$OS_FAMILY' for ${TOOL_DISPLAY_NAME}"
      return 1
      ;;
  esac
}

uninstall_google_chrome() {
  dc_log_info "Uninstalling ${TOOL_DISPLAY_NAME}..."

  case "$OS_FAMILY" in
    debian)
      dc_debian_remove_google_chrome
      ;;
    redhat)
      dc_redhat_remove_google_chrome
      ;;
  esac

  # Optionally ask to remove user data/config here.
}

is_google_chrome_installed() {
  # Simple heuristic: command present or package installed
  if dc_check_command "google-chrome"; then
    return 0
  fi

  # Additional dpkg/rpm checks can be added as needed.
  return 1
}
```

Tool scripts must **not** do their own OS detection; they rely on `OS_FAMILY`, `OS_ID`, and `OS_VERSION` set by the framework.

---

## 9. Functional requirements

### 9.1 Entry scripts

- **FR-1 (OS detection)**  
  Detect OS via standard mechanisms (prefer `/etc/os-release`) and support only Ubuntu, Debian, CentOS, RHEL, and Fedora at or above the specified versions; fail clearly and early for unsupported OSes or versions.

- **FR-2 (Dynamic CLI menu)**  
  Present an interactive CLI menu (whiptail, dialog, or text-mode fallback) so the user can choose which tools to install or uninstall.  
  - Menu options are built dynamically by sourcing `tools/*.sh` and reading their metadata.

- **FR-3 (Tool orchestration)**  
  After selection, run the appropriate install or uninstall function for each chosen tool for the detected OS.  
  - Functions are named according to `TOOL_ID` (with `-` → `_` mapping).

- **FR-4 (Execution modes)**  
  Work correctly when run via pipe-from-curl/wget and from a local clone, without relying on mode-specific path assumptions.

### 9.2 Tools

- **FR-5 (Single file per tool)**  
  Each tool lives in one script under `tools/`, named `<tool>.sh`, containing:
  - Metadata.
  - Idempotent install and uninstall functions.
  - Optional `is_*_installed` function.

- **FR-6 (Metadata interface)**  
  Each tool script exposes metadata variables (`TOOL_ID`, `TOOL_DISPLAY_NAME`, `TOOL_DESCRIPTION`, etc.) so the framework can:
  - Build menus.
  - Filter by OS support.
  - Dynamically invoke install/uninstall functions.

- **FR-7 (Multi-distro support)**  
  Each tool script handles all supported distros internally using:
  - `OS_FAMILY`, `OS_ID`, `OS_VERSION` from `lib/common.sh`.
  - Shared helpers from `lib/debian.sh` / `lib/redhat.sh`.

- **FR-8 (Idempotency)**  
  Tool scripts must be safe to run multiple times:
  - Avoid re-adding repos or duplicate config entries (use checks before modifying files/packages).
  - Skip work when the desired state is already achieved.

### 9.3 Privileges and uninstall

- **FR-9 (Privilege handling)**  
  DevChest requires root privileges for installation/uninstallation:
  - If not root, entry scripts must request sudo once (`sudo -v`) at startup.
  - If sudo is unavailable or user cancels, DevChest aborts with a clear error and non-zero exit.

- **FR-10 (Uninstall flow)**  
  `uninstall.sh` must:
  - Show a menu of tools that DevChest believes are installed (based on per-tool detection).
  - Call each tool’s uninstall function.
  - Optionally prompt to remove user data/config for each tool (default “no”).

### 9.4 Safety, dependencies, and failure handling

- **FR-11 (Failure behavior)**  
  DevChest must:
  - Fail clearly when preconditions are not met (unsupported OS, missing network, missing sudo, missing package manager, etc.).
  - Continue processing remaining tools if some fail, and present a final summary of success/skip/failure.

- **FR-12 (Security hygiene)**  
  DevChest must:
  - Not store secrets or credentials.
  - Not collect sensitive data from users.
  - Use only HTTPS for remote downloads.
  - Avoid piping remote scripts directly into the shell (`curl|bash`, `wget|bash`).

- **FR-13 (Core dependency pre-checks)**  
  Before displaying any banner or menu, DevChest must verify that:

  - It is running on a supported OS/version.
  - It has sufficient privileges (root or sudo).
  - A supported package manager exists (`apt`/`apt-get`, `dnf`/`yum`).
  - Network connectivity is available (simple HTTPS check).
  - At least one of `curl` or `wget` is present or can be installed.
  - Basic utilities (`grep`, `sed`, `awk`) are available (if not, abort as system is broken).

- **FR-14 (Interactive installation of missing dependencies)**  
  For each missing core/UI dependency:

  - DevChest must explain:
    - What is missing.
    - Why it is needed.
    - Whether it is **core** or **optional**.
  - If user agrees to install:
    - Attempt installation via the detected package manager.
    - If all candidates for a core capability (e.g. both curl and wget) fail to install, abort.
  - If user refuses:
    - For **core** deps: abort with a clear error and non-zero exit.
    - For **UI** deps (whiptail/dialog): proceed using the plain-text fallback.

- **FR-15 (Tool-level dependency handling)**  
  When a tool is selected:

  - Use its dependency metadata to:
    - Check presence of core commands.
    - Offer to install required packages.
  - If user refuses tool-level deps or installation fails:
    - Mark that tool as “unavailable” for this run.
    - Skip its install/uninstall and show it disabled with a reason in menus.
  - This decision is **per run** only (no persistent “never ask again” yet).

---

## 10. Non-functional requirements

### 10.1 Maintainability

- Clear separation of concerns between:
  - Entry scripts.
  - Core libraries.
  - Individual tools.
- Shared functionality (OS detection, logging, dependency and package handling, menus) lives in `lib/` to avoid duplication.
- Code must pass `shellcheck` and `shfmt` in CI with no errors and consistent style.

### 10.2 Safety and minimalism

- Safe to run on clean environments:
  - No destructive actions without explicit user confirmation.
  - Uninstall attempts to remove only DevChest-managed artifacts using explicit markers (comments, file names, paths).
- Default uninstall keeps user data unless user explicitly chooses to purge it.

### 10.3 Observability and UX

- All logging is via stdout/stderr:
  - No dedicated log file in v1.
  - Messages use standardized prefixes and are readable in remote/TTY contexts.
- A `--verbose` flag increases log detail:
  - Shows underlying commands and more granular debug information.
- After any multi-tool install/uninstall run, DevChest prints a summary such as:

  ```text
  ===== DevChest Summary =====
  [OK]     docker
  [OK]     vscode
  [SKIP]   google-chrome    (missing dependency: user refused java)
  [FAIL]   nvm              (apt-get error: dpkg lock held)
  ```

---

## 11. Coding standards and CI

### 11.1 Style and patterns

- **Shell mode:**
  - Use `set -euo pipefail`.
  - Prefer `[[ ... ]]` over `[ ... ]`.
  - Quote variable expansions by default, except in known-safe cases.
- **Namespacing:**
  - Framework functions: `dc_*` prefix.
  - Framework globals: `DC_*` prefix.
  - Tool-local variables: lowercase, tool-specific prefixes to avoid collisions.
- **Structure:**
  - `lib/*.sh` contain function and variable definitions only; no unguarded side effects on `source`.
  - Entry scripts call into `dc_main_*` functions and avoid large logic blocks.

### 11.2 CI checks

- GitHub Actions must run:
  - `shellcheck` on all `*.sh` files; no errors or high-severity warnings allowed.
  - `shfmt` to enforce formatting.
  - Simple smoke tests in Docker containers for each supported family (Ubuntu, Debian, Fedora, RHEL/CentOS), at minimum:
    - `./install.sh --help` / `./uninstall.sh --help`.
    - Tool discovery (`tools` sourcing) without execution.

### 11.3 Forbidden patterns

The following are explicitly forbidden unless there is a very narrowly scoped, well-documented exception:

- `eval` on dynamically assembled or untrusted input.
- Unquoted variable expansions in general flow (except where word splitting is deliberately required).
- Piping remote scripts directly into the shell:
  - `curl ... | sh/bash`, `wget ... | sh/bash`.
- Dangerous `rm -rf` usage:
  - No `rm -rf` on paths derived directly from user input.
  - Destructive operations must use known-safe directories and explicit markers.
- Directly embedding secrets or credentials anywhere in the repo.

These rules exist to keep the automation safe for users and predictable for AI agents implementing or modifying scripts.

---

## 12. Future directions (V2+)

The architecture is intentionally designed to accommodate the following in future versions without breaking changes:

- **Profiles and categories:**
  - Predefined profiles (e.g. “Backend dev”, “Bug hunter”, “Pentester”) mapping to curated sets of tools using `TOOL_CATEGORIES`.
- **Config-driven / non-interactive mode:**
  - Reading a `devchest.yml` or flags for fully non-interactive provisioning.
- **Extended tool actions:**
  - Additional actions such as `reconfigure`, `upgrade`, or `repair`, alongside install/uninstall.
- **External tool sources:**
  - Support for external `tools.d` trees (private or user-specific tool collections).

These are out of scope for v1 but are considered in how metadata, menus, and orchestration are structured.