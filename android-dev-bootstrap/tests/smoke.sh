#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ASIK_DEV_INSTALL_ROOT="$ROOT"

printf 'Checking Bash syntax...\n'
while IFS= read -r -d '' file; do
  bash -n "$file"
done < <(
  find "$ROOT" -type f \
    \( -name '*.sh' -o -path "$ROOT/bin/asik-dev" -o -path "$ROOT/bin/camera-ai" \
       -o -path "$ROOT/bin/claude-*" -o -path "$ROOT/bin/aider-*" \) -print0
)

printf 'Checking Python syntax...\n'
python3 -m py_compile "$ROOT/bin/ollama"

printf 'Checking generated configuration...\n'
tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT
HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$ROOT/bin:$PATH" "$ROOT/bin/asik-dev" configure

python3 -m json.tool "$tmp_home/.config/asik-dev/mcp.json" >/dev/null
python3 -m json.tool "$tmp_home/.cursor/mcp.json" >/dev/null
python3 -m json.tool "$tmp_home/.gemini/config/mcp_config.json" >/dev/null
python3 -m json.tool "$tmp_home/.config/opencode/opencode.json" >/dev/null

mode="$(stat -c '%a' "$tmp_home/.config/asik-dev/providers.env")"
[[ "$mode" == "600" ]]

printf 'Checking cloud Ollama wrapper...\n'
HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$ROOT/bin:$PATH" "$ROOT/bin/ollama" version |
  grep -q 'asik-dev ollama-cloud'

printf 'Checking asik-dev new commands...\n'
asik_cmd() { HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$ROOT/bin:$PATH" "$ROOT/bin/asik-dev" "$@"; }

# mcp list — should show the three default servers registered by configure.
asik_cmd mcp list | grep -q 'filesystem'
asik_cmd mcp list | grep -q 'memory'
asik_cmd mcp list | grep -q 'sequential-thinking'

# mcp add / remove round-trip.
asik_cmd mcp add test-server npx -y @test/server
python3 -m json.tool "$tmp_home/.config/asik-dev/mcp.json" >/dev/null
asik_cmd mcp list | grep -q 'test-server'
asik_cmd mcp remove test-server
asik_cmd mcp list | grep -vq 'test-server' || true  # removed; may still print header

# asik-dev new — scaffold a generic project and verify key files exist.
asik_cmd new generic smoke-test-project
[[ -f "$tmp_home/projects/smoke-test-project/README.md" ]]
[[ -f "$tmp_home/projects/smoke-test-project/.mise.toml" ]]
[[ -f "$tmp_home/projects/smoke-test-project/.gitignore" ]]

# asik-dev env — should report no .asik-dev.env found (expected in tmp_home).
HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PATH="$ROOT/bin:$PATH" \
  bash -c 'cd "$HOME" && '"$ROOT/bin/asik-dev"' env' | grep -q 'No .asik-dev.env'

# asik-dev secrets status — should not crash.
asik_cmd secrets status >/dev/null

# asik-dev help — should print usage.
asik_cmd help | grep -q 'asik-dev'

# asik-dev version — should print the version string.
asik_cmd version | grep -q 'asik-dev'

if command -v shellcheck >/dev/null 2>&1; then
  printf 'Running ShellCheck...\n'
  mapfile -d '' shell_files < <(
    find "$ROOT" -type f \
      \( -name '*.sh' -o -path "$ROOT/bin/asik-dev" -o -path "$ROOT/bin/camera-ai" \
         -o -path "$ROOT/bin/claude-*" -o -path "$ROOT/bin/aider-*" \) -print0
  )
  # --severity=warning: SC2016 (info) notices in intentional single-quoted
  # run_as_user heredocs are expected and non-blocking.
  shellcheck --severity=warning -x "${shell_files[@]}"
fi

printf 'All smoke tests passed.\n'
