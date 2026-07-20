#!/usr/bin/env bash
set -Eeuo pipefail

_user_node_command() {
  local command_string="$1"
  run_as_user "
    set -e
    export NVM_DIR=\"\$HOME/.nvm\"
    [[ -s \"\$NVM_DIR/nvm.sh\" ]] && source \"\$NVM_DIR/nvm.sh\"
    export PATH=\"\$HOME/.local/bin:\$HOME/.cargo/bin:\$HOME/.opencode/bin:\$PATH\"
    ${command_string}
  "
}

_install_claude() {
  _user_node_command '
    npm install -g --no-audit --no-fund @anthropic-ai/claude-code@latest
    hash -r
    command -v claude >/dev/null
  '
}

_install_codex() {
  _user_node_command '
    npm install -g --no-audit --no-fund @openai/codex@latest
    hash -r
    command -v codex >/dev/null
  '
}

_install_gemini_cli() {
  # Google Gemini CLI — open-source AI agent (released June 2025).
  # Uses GEMINI_API_KEY from providers.env; free tier includes Gemini 2.5 Pro.
  # https://github.com/google-gemini/gemini-cli
  _user_node_command '
    npm install -g --no-audit --no-fund @google/gemini-cli@latest
    hash -r
    command -v gemini >/dev/null
  '
}

_install_copilot_cli() {
  # GitHub Copilot CLI — AI coding assistant integrated with the gh CLI.
  # Requires gh auth login; installs as a gh extension (Jan 2026 GA).
  # https://github.com/github/copilot-cli
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$PATH"
    if command -v gh >/dev/null 2>&1; then
      gh extension install github/gh-copilot --force 2>/dev/null || true
    fi
  '
}

_install_goose() {
  # Goose (Block) — open-source extensible AI agent, MCP-native, 45k+ stars.
  # Supports all provider keys already in providers.env.
  # https://github.com/aaif-goose/goose
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$PATH"
    curl -fsSL https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh | bash
    hash -r
    command -v goose >/dev/null || true
  '
}

_install_opencode() {
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
    curl -fsSL https://opencode.ai/install | bash
    hash -r
    export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
    command -v opencode >/dev/null
  '
}

_install_aider() {
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
      uv tool install --force aider-chat
    else
      pipx install --force aider-chat
    fi
  '
}

_install_cursor_agent() {
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$HOME/.cursor/bin:$PATH"
    curl -fsS https://cursor.com/install | bash
  '
}

_install_grok_build() {
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$PATH"
    curl -fsSL https://x.ai/cli/install.sh | bash
  '
}

_install_antigravity() {
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$PATH"
    curl -fsSL https://antigravity.google/cli/install.sh | bash
  '
}

module_ai() {
  run_step "Install Claude Code" _install_claude
  run_step "Install OpenAI Codex" _install_codex
  run_step "Install Gemini CLI" _install_gemini_cli
  run_step "Install GitHub Copilot CLI" _install_copilot_cli
  run_step "Install Goose (Block AI agent)" _install_goose
  run_step "Install OpenCode" _install_opencode
  run_step "Install Aider" _install_aider
  run_step "Install Cursor Agent CLI" _install_cursor_agent
  run_step "Install Grok Build CLI" _install_grok_build
  run_step "Install Google Antigravity CLI (agy)" _install_antigravity
}
