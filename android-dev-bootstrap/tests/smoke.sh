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

if command -v shellcheck >/dev/null 2>&1; then
  printf 'Running ShellCheck...\n'
  mapfile -d '' shell_files < <(
    find "$ROOT" -type f \
      \( -name '*.sh' -o -path "$ROOT/bin/asik-dev" -o -path "$ROOT/bin/camera-ai" \
         -o -path "$ROOT/bin/claude-*" -o -path "$ROOT/bin/aider-*" \) -print0
  )
  shellcheck -x "${shell_files[@]}"
fi

printf 'All smoke tests passed.\n'
