#!/usr/bin/env bash
# Shared installer helpers. This file is sourced by install.sh.
set -Eeuo pipefail

declare -ag ASIK_SUCCESSES=()
declare -ag ASIK_FAILURES=()
declare -ag _ASIK_CLEANUP_DIRS=()
ASIK_DEV_LOG_FILE="${ASIK_DEV_LOG_FILE:-/tmp/asik-dev-bootstrap.log}"

# ---------------------------------------------------------------------------
# Unified trap-based cleanup (improvement #5)
# Registers a temporary directory for automatic removal on EXIT, ERR, INT, or
# TERM. Call register_cleanup_dir "$dir" after every mktemp -d invocation.
# ---------------------------------------------------------------------------
_asik_cleanup() {
  local sig="${1:-EXIT}"
  for dir in "${_ASIK_CLEANUP_DIRS[@]+"${_ASIK_CLEANUP_DIRS[@]}"}"; do
    rm -rf "$dir" 2>/dev/null || true
  done
  if [[ "$sig" == "ERR" ]]; then
    _log_line FATAL "Unexpected error on line ${BASH_LINENO[0]} in ${BASH_SOURCE[1]:-unknown}"
    _fail "Unexpected error — check log: ${ASIK_DEV_LOG_FILE}"
  fi
}

register_cleanup_dir() {
  _ASIK_CLEANUP_DIRS+=("$1")
}

# Register the unified cleanup handler for all relevant signals.
trap '_asik_cleanup ERR'  ERR
trap '_asik_cleanup INT'  INT
trap '_asik_cleanup TERM' TERM
trap '_asik_cleanup EXIT' EXIT

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
_color() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    printf '\033[%sm' "$1"
  fi
}

_reset() { _color 0; }
_info()  { _color '1;34'; printf '[INFO]'; _reset; printf ' %s\n' "$*"; }
_ok()    { _color '1;32'; printf '[ OK ]'; _reset; printf ' %s\n' "$*"; }
_warn()  { _color '1;33'; printf '[WARN]'; _reset; printf ' %s\n' "$*"; }
_fail()  { _color '1;31'; printf '[FAIL]'; _reset; printf ' %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
initialize_log() {
  ASIK_DEV_LOG_FILE="$1"
  local parent
  parent="$(dirname "$ASIK_DEV_LOG_FILE")"
  if [[ "$(id -u)" -eq 0 ]]; then
    mkdir -p "$parent"
    touch "$ASIK_DEV_LOG_FILE"
    if id "$TARGET_USER" >/dev/null 2>&1; then
      chown -R "$TARGET_USER:$TARGET_USER" "$parent"
    fi
  else
    mkdir -p "$parent"
    touch "$ASIK_DEV_LOG_FILE"
  fi
  chmod 0600 "$ASIK_DEV_LOG_FILE" 2>/dev/null || true
  export ASIK_DEV_LOG_FILE
}

_log_line() {
  local level="$1"; shift
  printf '%s [%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$level" "$*" \
    >>"$ASIK_DEV_LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Step runner — deliberately continues after failure so independent components
# still install.
# ---------------------------------------------------------------------------
run_step() {
  local title="$1"
  shift
  _info "$title"
  _log_line INFO "$title"

  local rc=0
  set +e
  "$@" >>"$ASIK_DEV_LOG_FILE" 2>&1
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    ASIK_SUCCESSES+=("$title")
    _ok "$title"
    _log_line OK "$title"
  else
    ASIK_FAILURES+=("$title (exit $rc)")
    _fail "$title (exit $rc)"
    _warn "Details: $ASIK_DEV_LOG_FILE"
    _log_line FAIL "$title (exit $rc)"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Retry with exponential backoff
# ---------------------------------------------------------------------------
retry() {
  local attempts="${ASIK_RETRY_ATTEMPTS:-4}"
  local delay="${ASIK_RETRY_DELAY:-2}"
  local n=1 rc=0
  while true; do
    set +e
    "$@"
    rc=$?
    set -e
    [[ "$rc" -eq 0 ]] && return 0
    [[ "$n" -ge "$attempts" ]] && return "$rc"
    sleep "$delay"
    n=$((n + 1))
    delay=$((delay * 2))
  done
}

# ---------------------------------------------------------------------------
# Privilege helpers
# ---------------------------------------------------------------------------
as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    _fail "Root access is required for: $*"
    return 1
  fi
}

get_user_home() {
  local user="$1"
  getent passwd "$user" | awk -F: '{print $6}'
}

run_as_user() {
  local command_string="$1"
  local home
  home="$(get_user_home "$TARGET_USER")"
  [[ -n "$home" ]] || {
    _fail "Unable to resolve home directory for $TARGET_USER"
    return 1
  }

  if [[ "$(id -u)" -eq 0 ]]; then
    if command -v runuser >/dev/null 2>&1; then
      runuser -u "$TARGET_USER" -- env \
        HOME="$home" USER="$TARGET_USER" LOGNAME="$TARGET_USER" \
        SHELL="/usr/bin/zsh" PATH="$home/.local/bin:/usr/local/bin:/usr/bin:/bin" \
        bash -lc "$command_string"
    else
      su - "$TARGET_USER" -s /bin/bash -c "$command_string"
    fi
  elif [[ "$(id -un)" == "$TARGET_USER" ]]; then
    HOME="$home" bash -lc "$command_string"
  else
    sudo -H -u "$TARGET_USER" bash -lc "$command_string"
  fi
}

safe_mkdir_user() {
  local path="$1"
  as_root mkdir -p "$path"
  if id "$TARGET_USER" >/dev/null 2>&1; then
    as_root chown "$TARGET_USER:$TARGET_USER" "$path"
  fi
}

install_user_file() {
  local source="$1" destination="$2" mode="${3:-0755}"
  local parent
  parent="$(dirname "$destination")"
  as_root mkdir -p "$parent"
  as_root install -m "$mode" "$source" "$destination"
  as_root chown "$TARGET_USER:$TARGET_USER" "$destination"
}

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
is_android_proot() {
  [[ -n "${PROOT_TMP_DIR:-}" ]] ||
  grep -Eqi 'android|termux' /proc/version 2>/dev/null ||
  [[ -d /data/data/com.termux ]]
}

deb_arch() {
  dpkg --print-architecture
}

binary_arch() {
  case "$(uname -m)" in
    aarch64|arm64) printf 'arm64\n' ;;
    x86_64|amd64) printf 'amd64\n' ;;
    armv7l|armhf) printf 'arm\n' ;;
    *) uname -m ;;
  esac
}

# ---------------------------------------------------------------------------
# Download helpers
# ---------------------------------------------------------------------------
download_file() {
  local url="$1" output="$2"
  retry curl --fail --silent --show-error --location \
    --retry 3 --retry-delay 2 --retry-all-errors \
    "$url" -o "$output"
}

# verify_sha256 <file> <expected_hex_digest>
# Returns 0 on match, 1 on mismatch, and prints a clear error message.
verify_sha256() {
  local file="$1" expected="$2"
  local actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    _fail "SHA256 mismatch for $(basename "$file")"
    _fail "  expected: $expected"
    _fail "  actual:   $actual"
    return 1
  fi
  _log_line OK "SHA256 verified: $(basename "$file")"
  return 0
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive as_root apt-get install -y --no-install-recommends "$@"
}

command_exists_for_user() {
  local name="$1"
  run_as_user "command -v '$name' >/dev/null 2>&1"
}

replace_managed_block() {
  local file="$1" block_name="$2" content_file="$3"
  local begin="# >>> asik-dev:${block_name} >>>"
  local end="# <<< asik-dev:${block_name} <<<"
  local tmp
  tmp="$(mktemp)"
  register_cleanup_dir "$tmp"

  if [[ -f "$file" ]]; then
    awk -v begin="$begin" -v end="$end" '
      $0 == begin {skip=1; next}
      $0 == end   {skip=0; next}
      !skip       {print}
    ' "$file" >"$tmp"
  fi

  {
    cat "$tmp"
    printf '\n%s\n' "$begin"
    cat "$content_file"
    printf '%s\n' "$end"
  } >"${tmp}.new"

  as_root mkdir -p "$(dirname "$file")"
  as_root install -m 0644 "${tmp}.new" "$file"
  as_root chown "$TARGET_USER:$TARGET_USER" "$file"
  rm -f "$tmp" "${tmp}.new"
}

# ---------------------------------------------------------------------------
# Framework installation (improvement #8)
# Uses `install -m 0755` for atomic, permission-correct binary placement
# instead of cp + chmod, eliminating any race window.
# ---------------------------------------------------------------------------
install_framework() {
  local source_dir="$1" install_root="$2"
  as_root rm -rf "$install_root"
  as_root mkdir -p "$install_root"
  as_root cp -a "$source_dir/." "$install_root/"

  local bin
  for bin in install.sh bin/asik-dev bin/ollama bin/camera-ai \
              bin/claude-zai bin/claude-anthropic \
              bin/aider-xai bin/aider-openrouter; do
    [[ -f "$install_root/$bin" ]] || continue
    as_root install -m 0755 "$install_root/$bin" "$install_root/$bin"
  done

  as_root ln -sfn "$install_root/bin/asik-dev" /usr/local/bin/asik-dev
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  printf '\n'
  _color '1;36'; printf 'Installation summary\n'; _reset
  printf '  Successful steps: %d\n' "${#ASIK_SUCCESSES[@]}"
  printf '  Failed steps:     %d\n' "${#ASIK_FAILURES[@]}"

  if ((${#ASIK_FAILURES[@]})); then
    printf '\nFailed optional/required steps:\n'
    printf '  - %s\n' "${ASIK_FAILURES[@]}"
    printf '\nLog: %s\n' "$ASIK_DEV_LOG_FILE"
    return 1
  fi

  printf '  Log: %s\n' "$ASIK_DEV_LOG_FILE"
  return 0
}
