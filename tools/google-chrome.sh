#!/usr/bin/env bash
set -euo pipefail
# DevChest tool: Google Chrome
# Requires: lib/common.sh, lib/debian.sh, lib/redhat.sh

export TOOL_ID="google-chrome"
export TOOL_DISPLAY_NAME="Google Chrome"
export TOOL_DESCRIPTION="Google Chrome browser"

export TOOL_SUPPORTED_OS_IDS=("ubuntu" "debian" "fedora" "rhel" "centos")
export TOOL_CATEGORIES=("dev")
export TOOL_CORE_COMMANDS=("google-chrome")
export TOOL_DEBIAN_PACKAGES=("wget" "gnupg")
export TOOL_REDHAT_PACKAGES=("wget")

install_google_chrome() {
  dc_log_info "Installing ${TOOL_DISPLAY_NAME}..."

  if ! dc_tool_check_deps "${TOOL_ID}"; then
    dc_log_warn "Skipping ${TOOL_DISPLAY_NAME} install due to missing dependencies."
    export DC_LAST_SKIP_REASON="missing dependency: user refused or install failed"
    return 2
  fi

  if dc_check_command google-chrome 2>/dev/null || dc_check_command google-chrome-stable 2>/dev/null; then
    dc_log_info "Google Chrome is already installed."
    return 0
  fi

  case "${OS_FAMILY}" in
    debian)
      dc_apt_update_cache
      dc_apt_install wget gnupg
      local list="/etc/apt/sources.list.d/google-chrome.list"
      if [[ ! -f "${list}" ]]; then
        wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > "${list}"
        dc_apt_update_cache
      fi
      dc_apt_install google-chrome-stable
      ;;
    redhat)
      dc_yum_or_dnf_install wget
      local repo="/etc/yum.repos.d/google-chrome.repo"
      if [[ ! -f "$repo" ]] || ! grep -q "dl.google.com" "$repo"; then
        cat > "$repo" <<EOF
[google-chrome]
name=Google Chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
      fi

      dc_yum_or_dnf_install google-chrome-stable
      ;;
    *)
      dc_log_error "Unsupported OS family '${OS_FAMILY}' for ${TOOL_DISPLAY_NAME}"
      return 1
      ;;
  esac
  return 0
}

uninstall_google_chrome() {
  dc_log_info "Uninstalling ${TOOL_DISPLAY_NAME}..."
  case "${OS_FAMILY}" in
    debian)
      dc_apt_remove google-chrome-stable 2>/dev/null || true
      rm -f /etc/apt/sources.list.d/google-chrome.list /usr/share/keyrings/google-chrome.gpg 2>/dev/null || true
      dc_apt_update_cache 2>/dev/null || true
      ;;
    redhat)
      dc_yum_or_dnf_remove google-chrome-stable 2>/dev/null || true
      rm -f /etc/yum.repos.d/google-chrome.repo 2>/dev/null || true
      ;;
    *) ;;
  esac
  return 0
}

is_google_chrome_installed() {
  dc_check_command google-chrome 2>/dev/null || dc_check_command google-chrome-stable 2>/dev/null
}
