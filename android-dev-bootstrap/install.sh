#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${ASIK_DEV_REPO:-asikmydeen/asik-dev}"
REF="${ASIK_DEV_REF:-main}"
SUBDIR="${ASIK_DEV_SUBDIR:-android-dev-bootstrap}"
TARGET_USER="${ASIK_DEV_USER:-asik}"
UPDATE_MODE=0
NON_INTERACTIVE=0

usage() {
  cat <<'USAGE'
Asik Dev Bootstrap

Usage:
  install.sh [options]

Options:
  --user NAME          Linux user to create/configure (default: asik)
  --ref REF            Git branch or tag to install (default: main)
  --update             Refresh an existing installation
  --non-interactive    Never prompt for secrets
  -h, --help           Show help

Environment overrides:
  ASIK_DEV_REPO, ASIK_DEV_REF, ASIK_DEV_SUBDIR, ASIK_DEV_USER
USAGE
}

while (($#)); do
  case "$1" in
    --user) TARGET_USER="${2:?--user requires a value}"; shift 2 ;;
    --ref) REF="${2:?--ref requires a value}"; shift 2 ;;
    --update) UPDATE_MODE=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

RAW_BASE="https://raw.githubusercontent.com/${REPO}/${REF}/${SUBDIR}"

termux_phase() {
  printf '\n[INFO] Termux detected. Preparing the Android host.\n'
  pkg update -y || true
  pkg install -y curl wget git tar proot proot-distro coreutils findutils || true

  if command -v termux-setup-storage >/dev/null 2>&1 && [[ ! -d "$HOME/storage/shared" ]]; then
    printf '[INFO] Android may ask you to grant shared-storage permission.\n'
    termux-setup-storage || true
  fi

  command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock || true

  if proot-distro login ubuntu -- /usr/bin/true >/dev/null 2>&1; then
    printf '[OK] Ubuntu proot-distro installation already exists.\n'
  else
    printf '[INFO] Installing Ubuntu 24.04 with proot-distro. Keep Termux open.\n'
    proot-distro install ubuntu:24.04 --name ubuntu
  fi

  local forwarded_args=""
  [[ "$UPDATE_MODE" -eq 1 ]] && forwarded_args=" --update"
  [[ "$NON_INTERACTIVE" -eq 1 ]] && forwarded_args+=" --non-interactive"

  cat >"$HOME/asik-dev-next.sh" <<NEXT
#!/data/data/com.termux/files/usr/bin/bash
set -e
proot-distro login ubuntu -- bash -lc 'unset TERMUX_VERSION PREFIX; curl -fsSL ${RAW_BASE}/install.sh | bash -s --${forwarded_args}'
NEXT
  chmod 0755 "$HOME/asik-dev-next.sh"

  if [[ "$UPDATE_MODE" -eq 1 ]]; then
    printf '[INFO] Continuing the update inside Ubuntu.\n'
    exec "$HOME/asik-dev-next.sh"
  fi

  cat <<NEXT

Ubuntu is ready.

Run the full setup now with:
  ~/asik-dev-next.sh

Or enter Ubuntu manually:
  proot-distro login ubuntu

Then run inside Ubuntu:
  unset TERMUX_VERSION PREFIX
  curl -fsSL ${RAW_BASE}/install.sh | bash

Future Ubuntu login:
  proot-distro login ubuntu --user ${TARGET_USER}
NEXT
  exit 0
}

if [[ -n "${TERMUX_VERSION:-}" || "${PREFIX:-}" == *com.termux* ]]; then
  termux_phase
fi

if ! command -v apt-get >/dev/null 2>&1; then
  printf '[FAIL] Supported targets are Ubuntu/Debian and Termux.\n' >&2
  exit 1
fi

if [[ ! "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  printf '[FAIL] Invalid Linux username: %s\n' "$TARGET_USER" >&2
  exit 2
fi

TMP_DIR="$(mktemp -d)"
chmod 0755 "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

FILES=(
  VERSION README.md lib/common.sh
  modules/10-base.sh modules/20-user.sh modules/30-shell.sh
  modules/40-cloud.sh modules/50-ai.sh modules/60-config.sh
  bin/asik-dev bin/ollama bin/camera-ai
  bin/claude-zai bin/claude-anthropic bin/aider-xai bin/aider-openrouter
  templates/providers.env.example
)

printf '[INFO] Downloading bootstrap modules from %s\n' "$RAW_BASE"
for file in "${FILES[@]}"; do
  mkdir -p "$TMP_DIR/$(dirname "$file")"
  curl --fail --silent --show-error --location \
    --retry 4 --retry-delay 2 --retry-all-errors \
    "$RAW_BASE/$file" -o "$TMP_DIR/$file"
done
chmod -R a+rX "$TMP_DIR"

# shellcheck source=/dev/null
source "$TMP_DIR/lib/common.sh"
export ASIK_DEV_REPO="$REPO" ASIK_DEV_REF="$REF" ASIK_DEV_SUBDIR="$SUBDIR"
export ASIK_DEV_RAW_BASE="$RAW_BASE" TARGET_USER UPDATE_MODE NON_INTERACTIVE

source "$TMP_DIR/modules/10-base.sh"
source "$TMP_DIR/modules/20-user.sh"
source "$TMP_DIR/modules/30-shell.sh"
source "$TMP_DIR/modules/40-cloud.sh"
source "$TMP_DIR/modules/50-ai.sh"
source "$TMP_DIR/modules/60-config.sh"

module_base
module_user
TARGET_HOME="$(get_user_home "$TARGET_USER")"
export TARGET_HOME
initialize_log "$TARGET_HOME/.local/state/asik-dev/install.log"
module_shell
module_cloud
module_ai

INSTALL_ROOT="/opt/asik-dev-bootstrap"
run_step "Install bootstrap framework" install_framework "$TMP_DIR" "$INSTALL_ROOT"
module_config

if [[ "$NON_INTERACTIVE" -eq 0 && -t 0 && -t 1 ]]; then
  printf '\n[INFO] API keys are optional. Input is hidden and stored with mode 600.\n'
  run_as_user "/usr/local/bin/asik-dev secrets" || true
  run_as_user "/usr/local/bin/asik-dev configure" || true
fi

run_as_user "/usr/local/bin/asik-dev doctor" || true

if ! print_summary; then
  cat <<'PARTIAL'

Some independent components failed. Working tools remain installed.
Review the log, then rerun the installer or use:
  asik-dev repair
PARTIAL
  exit 1
fi

cat <<DONE

Setup complete.

Enter the development user:
  su - ${TARGET_USER}

Then:
  cd ~/projects
  asik-dev secrets
  asik-dev configure
  asik-dev doctor

Camera/AI helper:
  camera-ai "Describe this scene"
DONE
