#!/usr/bin/env bash
# Verify DevChest scripts against REQUIREMENTS.md forbidden patterns and basic conventions.
# Exit 0 if all checks pass, non-zero otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
cd "${REPO_ROOT}"

FAILED=0

# Scripts to check: lib/*.sh, entry scripts, tools/*.sh
SH_FILES=()
for f in lib/*.sh install.sh uninstall.sh tools/*.sh; do
  [[ -f "$f" ]] && SH_FILES+=("$f")
done

# Forbidden: eval on untrusted/dynamic input (grep for eval; allow in comments)
check_eval() {
  local file
  for file in "${SH_FILES[@]}"; do
    [[ -f "$file" ]] || continue
    if grep -n 'eval\s' "$file" | grep -v '^\s*#' > /dev/null 2>&1; then
      echo "[FAIL] $file: contains 'eval' (forbidden unless documented exception)" >&2
      grep -n 'eval\s' "$file" | grep -v '^\s*#' >&2
      FAILED=1
    fi
  done
}

# Forbidden: piping remote scripts into shell
check_pipe_bash() {
  local file
  for file in "${SH_FILES[@]}"; do
    [[ -f "$file" ]] || continue
    if grep -nE 'curl[^|]*\|\s*(sh|bash)' "$file" > /dev/null 2>&1; then
      echo "[FAIL] $file: curl ... | sh/bash is forbidden" >&2
      FAILED=1
    fi
    if grep -nE 'wget[^|]*\|\s*(sh|bash)' "$file" > /dev/null 2>&1; then
      echo "[FAIL] $file: wget ... | sh/bash is forbidden" >&2
      FAILED=1
    fi
  done
}

# Dangerous rm -rf: only allow on known-safe paths (e.g. _tmp from mktemp -d)
check_rm_rf() {
  local file line
  for file in "${SH_FILES[@]}"; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line; do
      # Skip comment and log lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" =~ dc_log_info|echo.*rm ]] && continue
      if [[ "$line" =~ rm[[:space:]]+-rf ]]; then
        if [[ ! "$line" =~ _tmp|mktemp ]]; then
          echo "[FAIL] $file: unsafe 'rm -rf' (only _tmp from mktemp -d allowed)" >&2
          echo "  $line" >&2
          FAILED=1
        fi
      fi
    done < "$file"
  done
}

# Optional: shebang and set -euo pipefail
check_shebang() {
  local file
  for file in "${SH_FILES[@]}"; do
    [[ -f "$file" ]] || continue
    if ! head -1 "$file" | grep -q '^#!/usr/bin/env bash'; then
      echo "[FAIL] $file: missing shebang #!/usr/bin/env bash" >&2
      FAILED=1
    fi
    if ! grep -q 'set -euo pipefail' "$file"; then
      echo "[WARN] $file: missing 'set -euo pipefail'" >&2
    fi
  done
}

check_eval
check_pipe_bash
check_rm_rf
check_shebang

if [[ $FAILED -ne 0 ]]; then
  echo "Standards verification failed." >&2
  exit 1
fi
echo "Standards verification passed."
exit 0
