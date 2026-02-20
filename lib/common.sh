#!/usr/bin/env bash
# DevChest core library: path resolution, OS detection, logging, privilege, deps, summary.
# Source this from entry scripts after bootstrap; requires Bash 4+.

set -euo pipefail

# ---------------------------------------------------------------------------
# Path resolution (assume we are sourced from local mode: script has real path)
# ---------------------------------------------------------------------------
_devchest_common_src="${BASH_SOURCE[0]}"
_devchest_lib_dir=""
_devchest_root=""
if [[ -n "${_devchest_common_src}" && "${_devchest_common_src}" != "-" && -e "${_devchest_common_src}" ]]; then
  _devchest_lib_dir="$(cd "$(dirname "${_devchest_common_src}")" && pwd)"
  _devchest_root="$(dirname "${_devchest_lib_dir}")"
fi
export DEVCHEST_LIB="${_devchest_lib_dir}"
export DEVCHEST_ROOT="${_devchest_root}"
readonly DEVCHEST_LIB DEVCHEST_ROOT

# ---------------------------------------------------------------------------
# Globals (flags; set by entry scripts or env)
# ---------------------------------------------------------------------------
export DC_VERBOSE="${DC_VERBOSE:-0}"
export DC_KEEP_WORKDIR="${DC_KEEP_WORKDIR:-0}"

# Summary buffer: array of "tool_id|status|reason"
declare -a DC_RESULTS=()

# ---------------------------------------------------------------------------
# Bash version (call early when common is sourced)
# ---------------------------------------------------------------------------
dc_require_bash4() {
  if [[ -z "${BASH_VERSINFO[0]:-}" ]] || [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "[ERROR] DevChest requires Bash 4.0 or newer. Current: ${BASH_VERSION:-unknown}" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
dc_log_info() {
  echo "[INFO] $*" >&2
}

dc_log_warn() {
  echo "[WARN] $*" >&2
}

dc_log_error() {
  echo "[ERROR] $*" >&2
}

dc_die() {
  dc_log_error "$@"
  exit 1
}

dc_log_verbose() {
  if [[ "${DC_VERBOSE}" -ne 0 ]]; then
    echo "[VERBOSE] $*" >&2
  fi
}

# ---------------------------------------------------------------------------
# OS detection (use /etc/os-release; fallback to *-release files)
# ---------------------------------------------------------------------------
dc_detect_os() {
  local os_release="/etc/os-release"
  local id=""
  local version_id=""
  local id_like=""

  if [[ -f "${os_release}" ]]; then
    # shellcheck source=/dev/null
    source "${os_release}"
    id="${ID:-}"
    version_id="${VERSION_ID:-}"
    id_like="${ID_LIKE:-}"
  fi

  if [[ -z "${id}" ]]; then
    if [[ -f /etc/redhat-release ]]; then
      id="rhel"
      version_id="$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release 2> /dev/null || true)"
    elif [[ -f /etc/debian_version ]]; then
      id="debian"
      version_id="$(cat /etc/debian_version 2> /dev/null || true)"
    fi
  fi

  id="${id,,}"
  # Normalize ID: centos stream, rocky, alma -> treat as rhel/centos family
  case "${id}" in
    ubuntu) ;;
    debian) ;;
    rhel | centos | fedora | rocky | almalinux) ;;
    *)
      # id_like can be "fedora" or "rhel fedora" etc
      if [[ "${id_like,,}" == *"fedora"* ]]; then
        id="fedora"
      elif [[ "${id_like,,}" == *"rhel"* ]] || [[ "${id_like,,}" == *"centos"* ]]; then
        id="rhel"
      fi
      ;;
  esac

  # Map to OS_FAMILY and normalize OS_ID
  case "${id}" in
    ubuntu | debian)
      export OS_FAMILY="debian"
      export OS_ID="${id}"
      ;;
    rhel | centos | fedora | rocky | almalinux)
      export OS_FAMILY="redhat"
      if [[ "${id}" == "centos" ]] || [[ "${id}" == "rocky" ]] || [[ "${id}" == "almalinux" ]]; then
        export OS_ID="centos"
      else
        export OS_ID="${id}"
      fi
      ;;
    *)
      dc_die "Unsupported operating system: ID=${id}. DevChest supports Ubuntu, Debian, RHEL/CentOS, and Fedora."
      ;;
  esac

  # Normalize version (strip / and space; take first number part for debian)
  OS_VERSION="${version_id%%[[:space:]/]*}"
  OS_VERSION="${OS_VERSION:-0}"
  export OS_VERSION

  dc_log_verbose "Detected OS_FAMILY=${OS_FAMILY} OS_ID=${OS_ID} OS_VERSION=${OS_VERSION}"

  # Version checks per REQUIREMENTS §2.1
  dc_validate_os_version
}

# Returns 0 if first version >= second (by sort -V)
dc_version_gte() {
  local a="$1"
  local b="$2"
  local min
  min="$(printf '%s\n%s' "${a}" "${b}" | sort -V | head -1)"
  [[ "${min}" == "${b}" ]]
}

dc_validate_os_version() {
  case "${OS_ID}" in
    ubuntu)
      if ! dc_version_gte "${OS_VERSION}" "20.04"; then
        dc_die "Ubuntu version ${OS_VERSION} is not supported. DevChest requires Ubuntu 20.04 or newer."
      fi
      ;;
    debian)
      if ! dc_version_gte "${OS_VERSION}" "10"; then
        dc_die "Debian version ${OS_VERSION} is not supported. DevChest requires Debian 10 or newer."
      fi
      ;;
    centos | rhel)
      if ! dc_version_gte "${OS_VERSION}" "8"; then
        dc_die "RHEL/CentOS version ${OS_VERSION} is not supported. DevChest requires 8 or newer."
      fi
      ;;
    fedora)
      if ! dc_version_gte "${OS_VERSION}" "39"; then
        dc_die "Fedora version ${OS_VERSION} is not supported. DevChest requires Fedora 39 or newer."
      fi
      ;;
    *) ;;
  esac
}

# ---------------------------------------------------------------------------
# Privilege
# ---------------------------------------------------------------------------
dc_ensure_root_or_sudo() {
  if [[ "${EUID}" -eq 0 ]]; then
    return 0
  fi
  if ! sudo -v 2> /dev/null; then
    dc_die "DevChest needs root privileges. Please run with sudo or as root, and ensure sudo is available."
  fi
}

# ---------------------------------------------------------------------------
# Dependency helpers
# ---------------------------------------------------------------------------
dc_check_command() {
  command -v "$1" &> /dev/null
}

# Prompt with read; returns 0 for yes, 1 for no
dc_prompt_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local answer=""
  if [[ "${default}" == "y" ]]; then
    printf '%s [Y/n]: ' "${prompt}" >&2
  else
    printf '%s [y/N]: ' "${prompt}" >&2
  fi
  read -r answer || true
  answer="${answer,,}"
  if [[ -z "${answer}" ]]; then
    [[ "${default}" == "y" ]]
    return $?
  fi
  [[ "${answer}" == "y" || "${answer}" == "yes" ]]
}

# Check that at least one of the given commands exists; otherwise die.
# Preflight is responsible for offering to install and calling package manager.
dc_require_core_dep() {
  local capability="$1"
  shift
  local cmd
  for cmd in "$@"; do
    if dc_check_command "${cmd}"; then
      return 0
    fi
  done
  dc_die "Missing required capability: ${capability}. Need one of: $*"
}

dc_offer_optional_dep() {
  local description="$1"
  local pkg="$2"
  if dc_check_command "${pkg}"; then
    return 0
  fi
  if dc_prompt_yes_no "Install optional dependency ${description} (${pkg})?" "n"; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Summary aggregation
# ---------------------------------------------------------------------------
dc_record_result() {
  local tool_id="$1"
  local status="$2"
  local reason="${3:-}"
  DC_RESULTS+=("${tool_id}|${status}|${reason}")
}

dc_print_summary() {
  echo "===== DevChest Summary =====" >&2
  local entry
  for entry in "${DC_RESULTS[@]}"; do
    local tool_id rest status reason
    tool_id="${entry%%|*}"
    rest="${entry#*|}"
    status="${rest%%|*}"
    reason="${rest#*|}"
    if [[ -n "${reason}" && "${reason}" != "${status}" ]]; then
      printf '[%s]\t%s\t(%s)\n' "${status}" "${tool_id}" "${reason}" >&2
    else
      printf '[%s]\t%s\n' "${status}" "${tool_id}" >&2
    fi
  done
}

# Reset results (e.g. at start of install or uninstall run)
dc_reset_summary() {
  DC_RESULTS=()
}

# ---------------------------------------------------------------------------
# Tool ID to function name: replace - with _
# ---------------------------------------------------------------------------
dc_tool_id_to_fn_suffix() {
  local id="$1"
  echo "${id//-/_}"
}

# ---------------------------------------------------------------------------
# Tool discovery and dependency check
# ---------------------------------------------------------------------------
# Discovered tools: parallel arrays and script path map
declare -a DC_TOOL_IDS=()
declare -a DC_TOOL_ITEMS=()  # "id|Display Name" for menu
declare -A DC_TOOL_SCRIPT=() # id -> path

# Discover tools; mode=install | uninstall. For uninstall, only include installed tools.
dc_discover_tools() {
  local mode="${1:-install}"
  DC_TOOL_IDS=()
  DC_TOOL_ITEMS=()
  DC_TOOL_SCRIPT=()

  local tools_dir="${DEVCHEST_ROOT}/tools"
  if [[ ! -d "${tools_dir}" ]]; then
    return 0
  fi

  local f
  for f in "${tools_dir}"/*.sh; do
    [[ -f "${f}" ]] || continue
    unset TOOL_ID TOOL_DISPLAY_NAME TOOL_DESCRIPTION TOOL_SUPPORTED_OS_IDS TOOL_CATEGORIES 2> /dev/null || true
    unset TOOL_CORE_COMMANDS TOOL_DEBIAN_PACKAGES TOOL_REDHAT_PACKAGES 2> /dev/null || true
    # shellcheck source=/dev/null
    source "${f}"
    local supported=1
    if [[ -n "${TOOL_SUPPORTED_OS_IDS[*]:-}" ]]; then
      supported=0
      local os
      for os in "${TOOL_SUPPORTED_OS_IDS[@]}"; do
        if [[ "${os}" == "${OS_ID}" ]]; then
          supported=1
          break
        fi
      done
    fi
    if [[ "${supported}" -eq 0 ]]; then
      continue
    fi
    if [[ "${mode}" == "uninstall" ]]; then
      local fn_suffix check_fn
      fn_suffix="$(dc_tool_id_to_fn_suffix "${TOOL_ID:-}")"
      check_fn="is_${fn_suffix}_installed"
      if [[ "$(type -t "${check_fn}" 2> /dev/null)" != "function" ]]; then
        continue
      fi
      if ! "${check_fn}" 2> /dev/null; then
        continue
      fi
    fi
    DC_TOOL_IDS+=("${TOOL_ID}")
    DC_TOOL_ITEMS+=("${TOOL_ID}|${TOOL_DISPLAY_NAME:-${TOOL_ID}}")
    DC_TOOL_SCRIPT["${TOOL_ID}"]="${f}"
  done
}

# Check tool-level deps (call after sourcing the tool script so TOOL_* are set).
# Offer to install TOOL_DEBIAN_PACKAGES or TOOL_REDHAT_PACKAGES. Return 0 if ok, 1 if refused/failed.
dc_tool_check_deps() {
  local tool_id="${1:-}"
  if [[ -z "${tool_id}" ]]; then
    return 1
  fi
  case "${OS_FAMILY:-}" in
    debian)
      if [[ -z "${TOOL_DEBIAN_PACKAGES[*]:-}" ]]; then
        return 0
      fi
      if dc_prompt_yes_no "Install required packages for ${tool_id}? (${TOOL_DEBIAN_PACKAGES[*]})" "y"; then
        dc_apt_update_cache
        dc_apt_install "${TOOL_DEBIAN_PACKAGES[@]}" 2> /dev/null || return 1
      else
        return 1
      fi
      ;;
    redhat)
      if [[ -z "${TOOL_REDHAT_PACKAGES[*]:-}" ]]; then
        return 0
      fi
      if dc_prompt_yes_no "Install required packages for ${tool_id}? (${TOOL_REDHAT_PACKAGES[*]})" "y"; then
        dc_yum_or_dnf_install "${TOOL_REDHAT_PACKAGES[@]}" 2> /dev/null || return 1
      else
        return 1
      fi
      ;;
    *) return 0 ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Pre-flight: core deps and optional UI
# ---------------------------------------------------------------------------
dc_preflight_checks() {
  # Package manager (required)
  case "${OS_FAMILY:-}" in
    debian)
      if ! dc_check_command apt-get; then
        dc_die "apt-get not found. This system does not appear to be a supported Debian/Ubuntu."
      fi
      ;;
    redhat)
      if ! dc_check_command dnf && ! dc_check_command yum; then
        dc_die "Neither dnf nor yum found. This system does not appear to be a supported RHEL/CentOS/Fedora."
      fi
      ;;
    *)
      dc_die "Unsupported OS_FAMILY: ${OS_FAMILY:-unknown}"
      ;;
  esac

  # Basic utilities (required)
  for _cmd in grep sed awk; do
    if ! dc_check_command "${_cmd}"; then
      dc_die "Required utility '${_cmd}' not found. The system environment is incomplete."
    fi
  done

  # At least one of curl or wget (required)
  if ! dc_check_command curl && ! dc_check_command wget; then
    dc_log_error "Need curl or wget for downloads and network checks."
    if dc_prompt_yes_no "Attempt to install curl via package manager?" "y"; then
      case "${OS_FAMILY:-}" in
        debian)
          dc_apt_update_cache
          dc_apt_install curl || dc_die "Failed to install curl."
          ;;
        redhat) dc_yum_or_dnf_install curl || dc_die "Failed to install curl." ;;
        *) dc_die "Cannot install curl on this OS." ;;
      esac
    else
      dc_die "DevChest requires curl or wget. Install one and re-run."
    fi
  fi

  # Network (required)
  if dc_check_command curl; then
    if ! curl -fsSL --connect-timeout 5 -o /dev/null "https://github.com/robots.txt" 2> /dev/null; then
      dc_die "Network check failed (curl). Ensure you have internet access and try again."
    fi
  elif dc_check_command wget; then
    if ! wget -q --spider --timeout=5 "https://github.com/robots.txt" 2> /dev/null; then
      dc_die "Network check failed (wget). Ensure you have internet access and try again."
    fi
  fi

  dc_log_verbose "Pre-flight core checks passed"
}

# Offer to install a package; return 0 if installed or already present, 1 if user refused/failed
dc_offer_install_package() {
  local pkg="$1"
  local description="${2:-${pkg}}"
  if dc_check_command "${pkg}"; then
    return 0
  fi
  if ! dc_prompt_yes_no "Install ${description} (${pkg})?" "y"; then
    return 1
  fi
  case "${OS_FAMILY:-}" in
    debian)
      dc_apt_install "${pkg}" 2> /dev/null || return 1
      ;;
    redhat)
      dc_yum_or_dnf_install "${pkg}" 2> /dev/null || return 1
      ;;
    *) return 1 ;;
  esac
  return 0
}

dc_preflight_install() {
  dc_preflight_checks

  # Optional: whiptail/dialog for TUI
  if ! dc_check_command whiptail && ! dc_check_command dialog; then
    if dc_prompt_yes_no "Install whiptail for a nicer menu? (Otherwise plain text menu)" "n"; then
      case "${OS_FAMILY:-}" in
        debian) dc_apt_install whiptail 2> /dev/null || true ;;
        redhat) dc_yum_or_dnf_install newt 2> /dev/null || true ;;
        *) true ;;
      esac
    fi
  fi

  dc_log_verbose "Pre-flight install complete"
}

dc_preflight_uninstall() {
  dc_preflight_checks
  dc_log_verbose "Pre-flight uninstall complete"
}

# ---------------------------------------------------------------------------
# Main orchestration
# ---------------------------------------------------------------------------
dc_main_install() {
  dc_reset_summary
  dc_discover_tools "install"

  if [[ ${#DC_TOOL_IDS[@]} -eq 0 ]]; then
    dc_log_info "No tools available for this OS. Add scripts to tools/ and run again."
    dc_print_summary
    return 0
  fi

  local selected
  selected="$(dc_menu_multi_select "Select tools to install" "${DC_TOOL_ITEMS[@]}" | tr ' ' '\n' | grep -v '^$' || true)"
  if [[ -z "${selected}" ]]; then
    dc_log_info "No tools selected."
    dc_print_summary
    return 0
  fi

  local id fn_suffix install_fn
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    fn_suffix="$(dc_tool_id_to_fn_suffix "${id}")"
    install_fn="install_${fn_suffix}"
    if [[ "$(type -t "${install_fn}" 2> /dev/null)" != "function" ]]; then
      dc_record_result "${id}" "FAIL" "install function not found"
      continue
    fi
    # Re-source so TOOL_* and dc_tool_check_deps use correct metadata
    # shellcheck source=/dev/null
    source "${DC_TOOL_SCRIPT["${id}"]}"
    DC_LAST_SKIP_REASON=""
    set +e
    "${install_fn}" 2> /dev/null
    _ret=$?
    set -e
    if [[ "${_ret}" -eq 0 ]]; then
      dc_record_result "${id}" "OK" ""
    elif [[ "${_ret}" -eq 2 ]]; then
      dc_record_result "${id}" "SKIP" "${DC_LAST_SKIP_REASON:-skipped}"
    else
      dc_record_result "${id}" "FAIL" "install failed"
    fi
  done <<< "${selected}"

  dc_print_summary
}

dc_main_uninstall() {
  dc_reset_summary
  dc_discover_tools "uninstall"

  if [[ ${#DC_TOOL_IDS[@]} -eq 0 ]]; then
    dc_log_info "No DevChest-installed tools detected."
    dc_print_summary
    return 0
  fi

  local selected
  selected="$(dc_menu_multi_select "Select tools to uninstall" "${DC_TOOL_ITEMS[@]}" | tr ' ' '\n' | grep -v '^$' || true)"
  if [[ -z "${selected}" ]]; then
    dc_log_info "No tools selected."
    dc_print_summary
    return 0
  fi

  local id fn_suffix uninstall_fn
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    fn_suffix="$(dc_tool_id_to_fn_suffix "${id}")"
    uninstall_fn="uninstall_${fn_suffix}"
    if [[ "$(type -t "${uninstall_fn}" 2> /dev/null)" != "function" ]]; then
      dc_record_result "${id}" "FAIL" "uninstall function not found"
      continue
    fi
    # shellcheck source=/dev/null
    source "${DC_TOOL_SCRIPT["${id}"]}"
    set +e
    "${uninstall_fn}" 2> /dev/null
    _ret=$?
    set -e
    if [[ "${_ret}" -eq 0 ]]; then
      dc_record_result "${id}" "OK" ""
    else
      dc_record_result "${id}" "FAIL" "uninstall failed"
    fi
  done <<< "${selected}"

  dc_print_summary
}

# ---------------------------------------------------------------------------
# Initialize when sourced: Bash 4 and OS (when we have a valid root)
# ---------------------------------------------------------------------------
dc_require_bash4
if [[ -n "${DEVCHEST_ROOT}" && -d "${DEVCHEST_ROOT}" ]]; then
  dc_detect_os
fi
