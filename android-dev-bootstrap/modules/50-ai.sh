#!/usr/bin/env bash
set -Eeuo pipefail

_user_node_command() {
  local command_string="$1"
  run_as_user "
    set -e
    export NVM_DIR=\"\$HOME/.nvm\"
    [[ -s \"\$NVM_DIR/nvm.sh\" ]] && source \"\$NVM_DIR/nvm.sh\"
    export PATH=\"\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH\"
    ${command_string}
  "
}

_install_claude() {
  _user_node_command 'npm install -g @anthropic-ai/claude-code@latest'
}

_install_codex() {
  _user_node_command 'npm install -g @openai/codex@latest'
}

_install_opencode() {
  _user_node_command 'npm install -g opencode-ai@latest'
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
  run_step "Install OpenCode" _install_opencode
  run_step "Install Aider" _install_aider
  run_step "Install Cursor Agent CLI" _install_cursor_agent
  run_step "Install Grok Build CLI" _install_grok_build
  run_step "Install Google Antigravity CLI (agy)" _install_antigravity
}
