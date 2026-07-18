#!/usr/bin/env bash
set -Eeuo pipefail

_install_zsh_stack() {
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$PATH"

    if [[ ! -d "$HOME/.oh-my-zsh/.git" ]]; then
      git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
    else
      git -C "$HOME/.oh-my-zsh" pull --ff-only
    fi

    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k/.git" ]]; then
      git clone --depth 1 https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM/themes/powerlevel10k"
    else
      git -C "$ZSH_CUSTOM/themes/powerlevel10k" pull --ff-only
    fi

    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions/.git" ]]; then
      git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    else
      git -C "$ZSH_CUSTOM/plugins/zsh-autosuggestions" pull --ff-only
    fi

    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/.git" ]]; then
      git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    else
      git -C "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" pull --ff-only
    fi
  '
}

_install_nvm_node() {
  run_as_user '
    set -e
    export NVM_DIR="$HOME/.nvm"
    mkdir -p "$NVM_DIR"

    version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest |
      jq -r ".tag_name // empty" 2>/dev/null || true)"
    version="${version:-v0.40.3}"

    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
      curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${version}/install.sh" |
        PROFILE=/dev/null bash
    fi

    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm alias default "lts/*"
    nvm use default
    corepack enable || true
    npm install -g npm@latest pnpm@latest
  '
}

_install_uv() {
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$PATH"
    curl -LsSf https://astral.sh/uv/install.sh | sh
  '
}

_install_rust() {
  run_as_user '
    set -e
    if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
      curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs |
        sh -s -- -y --profile minimal
    fi
    "$HOME/.cargo/bin/rustup" update stable
  '
}

_install_go() {
  apt_install golang-go
}

_write_shell_config() {
  local block
  block="$(mktemp)"
  cat >"$block" <<'BLOCK'
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$HOME/.config/asik-dev/providers.env" ]] && source "$HOME/.config/asik-dev/providers.env"

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git sudo fzf zsh-autosuggestions zsh-syntax-highlighting)

if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

alias ll='ls -lah'
alias gs='git status -sb'
alias gp='git pull --ff-only'
alias projects='cd "$HOME/projects"'
alias claude='claude-zai'
alias ccz='claude-zai'
alias cca='claude-anthropic'
alias cx='codex'
alias oc='opencode'
alias ag='agy'
alias gr='grok'
BLOCK

  replace_managed_block "$TARGET_HOME/.zshrc" shell "$block"
  replace_managed_block "$TARGET_HOME/.bashrc" shell "$block"
  rm -f "$block"
}

module_shell() {
  run_step "Install Oh My Zsh, Powerlevel10k, and plugins" _install_zsh_stack
  run_step "Install Node.js LTS, npm, and pnpm with NVM" _install_nvm_node
  run_step "Install uv Python package manager" _install_uv
  run_step "Install Rust toolchain" _install_rust
  run_step "Install Go toolchain" _install_go
  run_step "Write managed Bash and Zsh configuration" _write_shell_config
}
