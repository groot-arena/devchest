#!/usr/bin/env bash
set -euo pipefail

# DevChest tool: Visual Studio Code
# Requires: lib/common.sh, lib/debian.sh, lib/redhat.sh

export TOOL_ID="vscode"
export TOOL_DISPLAY_NAME="Visual Studio Code"
export TOOL_DESCRIPTION="Code editor by Microsoft"

export TOOL_CATEGORIES=("dev" "editor")
export TOOL_CORE_COMMANDS=("code")
export TOOL_DEBIAN_PACKAGES=("curl" "gnupg" "apt-transport-https")
export TOOL_REDHAT_PACKAGES=("curl")

install_vscode() {
  dc_log_info "Installing ${TOOL_DISPLAY_NAME}..."

  if ! dc_tool_check_deps "${TOOL_ID}"; then
    dc_log_warn "Skipping ${TOOL_DISPLAY_NAME} install due to missing dependencies."
    export DC_LAST_SKIP_REASON="missing dependency: user refused or install failed"
    return 2
  fi

  if dc_check_command code; then
    dc_log_info "VS Code is already installed."
    return 0
  fi

  case "${OS_FAMILY}" in
    debian)
      dc_apt_update_cache
      dc_apt_install curl gnupg apt-transport-https

      local keyring="/usr/share/keyrings/packages.microsoft.gpg"
      local list="/etc/apt/sources.list.d/vscode.list"

      if [[ ! -f "$keyring" ]]; then
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
          | gpg --dearmor -o "$keyring"
      fi

      if [[ ! -f "$list" ]] || ! grep -q "packages.microsoft.com/repos/vscode" "$list"; then
        cat > "$list" <<EOF
deb [arch=amd64 signed-by=${keyring}] https://packages.microsoft.com/repos/vscode stable main
EOF
      fi

      dc_apt_update_cache
      dc_apt_install code
      ;;

    redhat)
      dc_yum_or_dnf_install curl

      local repo="/etc/yum.repos.d/vscode.repo"

      if [[ ! -f "$repo" ]] || ! grep -q "packages.microsoft.com/yumrepos/vscode" "$repo"; then
        if dc_check_command dnf; then
          rpm --import https://packages.microsoft.com/keys/microsoft.asc

          cat > "$repo" <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
        else
          dc_log_error "VS Code repo setup requires dnf."
          return 1
        fi
      fi

      dc_yum_or_dnf_install code
      ;;

    *)
      dc_log_error "Unsupported OS family '${OS_FAMILY}' for ${TOOL_DISPLAY_NAME}"
      return 1
      ;;
  esac

  return 0
}

uninstall_vscode() {
  dc_log_info "Uninstalling ${TOOL_DISPLAY_NAME}..."

  case "${OS_FAMILY}" in
    debian)
      dc_apt_remove code 2>/dev/null || true
      rm -f /etc/apt/sources.list.d/vscode.list \
            /usr/share/keyrings/packages.microsoft.gpg 2>/dev/null || true
      dc_apt_update_cache 2>/dev/null || true
      ;;

    redhat)
      dc_yum_or_dnf_remove code 2>/dev/null || true
      rm -f /etc/yum.repos.d/vscode.repo 2>/dev/null || true
      ;;

    *) ;;
  esac

  return 0
}

is_vscode_installed() {
  dc_check_command code
}
