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
    --user)
      TARGET_USER="${2:?--user requires a value}"
      shift 2
      ;;
    --ref)
      REF="${2:?--ref requires a value}"
      shift 2
      ;;
    --update)
      UPDATE_MODE=1
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

RAW_BASE="https://raw.githubusercontent.com/${REPO}/${REF}/${SUBDIR}"

termux_phase() {
  printf '\n[INFO] Termux detected. Preparing the Android host.\n'
  pkg update -y || true
  pkg install -y curl wget git tar proot coreutils findutils || true

  if command -v termux-setup-storage >/dev/null 2>&1 && [[ ! -d "$HOME/storage/shared" ]]; then
    printf '[INFO] Android may ask you to grant shared-storage permission.\n'
    termux-setup-storage || true
  fi

  local start_script
  start_script="$(find "$HOME" -maxdepth 4 -type f \
    \( -name 'start-ubuntu*.sh' -o -name 'startubuntu*.sh' \) \
    2>/dev/null | head -n 1 || true)"

  cat >"$HOME/asik-dev-next.sh" <<NEXT
#!/data/data/com.termux/files/usr/bin/bash
set -e
printf '%s\n' 'Start your Andronix Ubuntu shell, then run:'
printf '%s\n' 'curl -fsSL ${RAW_BASE}/install.sh | bash'
NEXT
  chmod 0755 "$HOME/asik-dev-next.sh"

  if [[ -n "$start_script" ]]; then
    cat <<FOUND

[OK] Found an Andronix Ubuntu launcher:
  $start_script

Run it, then execute this inside Ubuntu:

  curl -fsSL ${RAW_BASE}/install.sh | bash

FOUND
  else
    cat <<MISSING

[NOTICE] Ubuntu is not installed yet.

Andronix must generate its own distro command, so this is the only manual step:
  1. Install/open Andronix.
  2. Select Ubuntu, then the CLI/unmodded installation.
  3. Paste the generated command into Termux and let it finish.
  4. Start Ubuntu with the generated start-ubuntu*.sh script.
  5. Inside Ubuntu run:

     curl -fsSL ${RAW_BASE}/install.sh | bash

Everything after the Andronix distro installation is automated and safe to rerun.
MISSING
  fi
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
  VERSION
  README.md
  lib/common.sh
  modules/10-base.sh
  modules/20-user.sh
  modules/30-shell.sh
  modules/40-cloud.sh
  modules/50-ai.sh
  modules/60-config.sh
  bin/asik-dev
  bin/ollama
  bin/claude-zai
  bin/claude-anthropic
  bin/aider-xai
  bin/aider-openrouter
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

export ASIK_DEV_REPO="$REPO"
export ASIK_DEV_REF="$REF"
export ASIK_DEV_SUBDIR="$SUBDIR"
export ASIK_DEV_RAW_BASE="$RAW_BASE"
export TARGET_USER UPDATE_MODE NON_INTERACTIVE

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
  printf '\n[INFO] API keys are optional. Input is hidden and secrets are stored with mode 600.\n'
  run_as_user "/usr/local/bin/asik-dev secrets" || true
  run_as_user "/usr/local/bin/asik-dev configure" || true
fi

run_as_user "/usr/local/bin/asik-dev doctor" || true

if ! print_summary; then
  cat <<'PARTIAL'

Some optional components failed, usually because a vendor installer does not yet support
this Android/PRoot architecture or because the network was interrupted. The working tools
remain installed. Rerun the same installer or use:

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

Useful AI commands:
  claude-zai        Claude Code through Z.AI / GLM
  claude-anthropic  Claude Code through Anthropic
  codex             OpenAI Codex
  cursor-agent      Cursor Agent
  grok              Grok Build
  agy               Google Antigravity CLI
  opencode          OpenCode
  aider             Aider
  ollama            Cloud-only Ollama API wrapper (no local model daemon)
DONE
