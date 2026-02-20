#!/usr/bin/env bash
set -euo pipefail

# DevChest tool: Docker Engine
# Requires: lib/common.sh, lib/debian.sh, lib/redhat.sh

export TOOL_ID="docker"
export TOOL_DISPLAY_NAME="Docker Engine"
export TOOL_DESCRIPTION="Container runtime and CLI"

export TOOL_CATEGORIES=("dev")
export TOOL_CORE_COMMANDS=("docker")
export TOOL_DEBIAN_PACKAGES=("ca-certificates" "curl" "gnupg")
export TOOL_REDHAT_PACKAGES=("ca-certificates" "curl" "gnupg2")

install_docker() {
  dc_log_info "Installing ${TOOL_DISPLAY_NAME}..."

  if ! dc_tool_check_deps "${TOOL_ID}"; then
    dc_log_warn "Skipping ${TOOL_DISPLAY_NAME} install due to missing dependencies."
    export DC_LAST_SKIP_REASON="missing dependency: user refused or install failed"
    return 2
  fi

  if dc_check_command docker; then
    dc_log_info "Docker is already installed."
    return 0
  fi

  case "${OS_FAMILY}" in
    debian)
      dc_apt_update_cache
      dc_apt_install ca-certificates curl gnupg

      local keyring="/usr/share/keyrings/docker-archive-keyring.gpg"
      local list="/etc/apt/sources.list.d/docker.list"

      if [[ ! -f "${keyring}" ]]; then
        curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
          | gpg --dearmor -o "${keyring}"
      fi

      local codename=""
      if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        codename="${VERSION_CODENAME:-}"
      fi

      if [[ -z "${codename}" ]]; then
        dc_log_error "Could not determine distribution codename. Install lsb-release or set VERSION_CODENAME."
        return 1
      fi

      echo "deb [arch=$(dpkg --print-architecture) signed-by=${keyring}] https://download.docker.com/linux/${OS_ID} ${codename} stable" > "${list}"

      dc_apt_update_cache
      dc_apt_install docker-ce docker-ce-cli containerd.io
      ;;

    redhat)
      dc_yum_or_dnf_install ca-certificates curl gnupg2

      local repo="/etc/yum.repos.d/docker-ce.repo"

      if [[ ! -f "$repo" ]] || ! grep -q "download.docker.com" "$repo"; then
        case "$OS_ID" in
          fedora) distro="fedora" ;;
          centos | rhel | rocky | almalinux) distro="centos" ;;
          *)
            dc_log_error "Unsupported RedHat variant: $OS_ID"
            return 1
            ;;
        esac

        cat > "$repo" << EOF
[docker-ce]
name=Docker CE
baseurl=https://download.docker.com/linux/${distro}/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/${distro}/gpg
EOF
      fi

      dc_yum_or_dnf_install docker-ce docker-ce-cli containerd.io
      systemctl enable --now docker 2> /dev/null || true
      ;;
      

    *)
      dc_log_error "Unsupported OS family '${OS_FAMILY}' for ${TOOL_DISPLAY_NAME}"
      return 1
      ;;
  esac

  # Add current sudo user to docker group (if applicable)
  if getent group docker > /dev/null 2>&1; then
    if [[ -n "${SUDO_USER:-}" ]]; then
      usermod -aG docker "$SUDO_USER" 2> /dev/null || true
      dc_log_info "Added ${SUDO_USER} to docker group (logout/login required)."
    fi
  fi

  return 0
}

uninstall_docker() {
  dc_log_info "Uninstalling ${TOOL_DISPLAY_NAME}..."

  case "${OS_FAMILY}" in
    debian)
      dc_apt_remove docker-ce docker-ce-cli containerd.io 2> /dev/null || true
      rm -f /etc/apt/sources.list.d/docker.list \
        /usr/share/keyrings/docker-archive-keyring.gpg 2> /dev/null || true
      dc_apt_update_cache 2> /dev/null || true
      ;;
      
    redhat)
      dc_yum_or_dnf_remove docker-ce docker-ce-cli containerd.io 2> /dev/null || true
      rm -f /etc/yum.repos.d/docker-ce.repo 2> /dev/null || true
      ;;
      
    *) ;;
  esac

  return 0
}

is_docker_installed() {
  dc_check_command docker
}
