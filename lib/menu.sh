#!/usr/bin/env bash
# DevChest menu/TUI helpers. Source after lib/common.sh.
# Prefer whiptail, then dialog, else text fallback. No tool-specific logic.

set -euo pipefail

# One of: whiptail, dialog, text
DC_MENU_UI="text"

dc_menu_detect_ui() {
  if dc_check_command whiptail; then
    DC_MENU_UI="whiptail"
    return
  fi
  if dc_check_command dialog; then
    DC_MENU_UI="dialog"
    return
  fi
  DC_MENU_UI="text"
}

# Multi-select: pass list of "id|display" lines; returns selected ids (newline-separated).
# Usage: dc_menu_multi_select "Title" "id1|Label 1" "id2|Label 2" ...
dc_menu_multi_select() {
  local title="$1"
  shift
  local items=("$@")
  dc_menu_detect_ui

  if [[ "${DC_MENU_UI}" == "whiptail" ]]; then
    _dc_menu_whiptail_multi "$title" "${items[@]}"
    return
  fi
  if [[ "${DC_MENU_UI}" == "dialog" ]]; then
    _dc_menu_dialog_multi "$title" "${items[@]}"
    return
  fi
  _dc_menu_text_multi "$title" "${items[@]}"
}

_dc_menu_whiptail_multi() {
  local title="$1"
  shift
  local items=("$@")
  local checklist_args=()
  local id label
  for item in "${items[@]}"; do
    id="${item%%|*}"
    label="${item#*|}"
    checklist_args+=("$id" "$label" "OFF")
  done
  local selected
  selected="$(whiptail --title "$title" --checklist "Select items (Space to toggle, Enter to confirm):" 20 78 10 "${checklist_args[@]}" 3>&1 1>&2 2>&3)" || true
  if [[ -n "${selected}" ]]; then
    echo "${selected}" | tr -d '"' | tr ' ' '\n'
  fi
}

_dc_menu_dialog_multi() {
  local title="$1"
  shift
  local items=("$@")
  local checklist_args=()
  local id label
  for item in "${items[@]}"; do
    id="${item%%|*}"
    label="${item#*|}"
    checklist_args+=("$id" "$label" "off")
  done
  local selected
  selected="$(dialog --stdout --title "$title" --checklist "Select items (Space to toggle, Enter to confirm):" 20 78 10 "${checklist_args[@]}" 2> /dev/null)" || true
  if [[ -n "${selected}" ]]; then
    echo "${selected}"
  fi
}

_dc_menu_text_multi() {
  local title="$1"
  shift
  local items=("$@")
  echo "" >&2
  echo "===== ${title} =====" >&2
  local i=1
  local id label
  for item in "${items[@]}"; do
    id="${item%%|*}"
    label="${item#*|}"
    echo "  ${i}) ${label} (${id})" >&2
    ((i++)) || true
  done
  echo "" >&2
  printf "Enter numbers to select (space-separated, e.g. 1 3): " >&2
  local line
  read -r line || true
  local result=""
  local num
  for num in ${line}; do
    if [[ "${num}" =~ ^[0-9]+$ ]] && [[ "${num}" -ge 1 ]] && [[ "${num}" -le ${#items[@]} ]]; then
      item="${items[$((num - 1))]}"
      id="${item%%|*}"
      if [[ -n "${result}" ]]; then
        result="${result}"$'\n'"${id}"
      else
        result="${id}"
      fi
    fi
  done
  if [[ -n "${result}" ]]; then
    echo "${result}"
  fi
}
