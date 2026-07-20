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
      git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    else
      git -C "$ZSH_CUSTOM/themes/powerlevel10k" pull --ff-only
    fi

    for repo in \
      zsh-users/zsh-autosuggestions \
      zsh-users/zsh-syntax-highlighting; do
      name="${repo##*/}"
      if [[ ! -d "$ZSH_CUSTOM/plugins/$name/.git" ]]; then
        git clone --depth 1 "https://github.com/$repo" "$ZSH_CUSTOM/plugins/$name"
      else
        git -C "$ZSH_CUSTOM/plugins/$name" pull --ff-only
      fi
    done
  '
}

_install_nvm_node() {
  # improvement #6: fully idempotent — skip the LTS download when the current
  # LTS version is already installed and set as the NVM default.
  run_as_user '
    set -e
    export NVM_DIR="$HOME/.nvm"
    mkdir -p "$NVM_DIR"

    nvm_version="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest |
      jq -r ".tag_name // empty" 2>/dev/null || true)"
    nvm_version="${nvm_version:-v0.40.3}"

    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
      curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" |
        PROFILE=/dev/null bash
    fi

    source "$NVM_DIR/nvm.sh"

    # Resolve the latest available LTS alias without downloading it yet.
    desired_lts="$(nvm version-remote --lts 2>/dev/null || true)"

    if [[ -n "$desired_lts" ]] && nvm ls "$desired_lts" 2>/dev/null | grep -q "$desired_lts"; then
      # LTS already installed — just make sure the alias and active version are correct.
      nvm alias default "lts/*"
      nvm use default
      printf "[INFO] Node.js %s already installed, skipping download.\n" "$desired_lts"
    else
      nvm install --lts
      nvm alias default "lts/*"
      nvm use default
    fi

    node --version
    npm --version
  '
}

_install_pnpm() {
  run_as_user '
    set -e
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
    nvm use default >/dev/null

    corepack enable
    corepack prepare pnpm@latest --activate
    hash -r
    pnpm --version
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

_install_go() { apt_install golang-go; }

# ---------------------------------------------------------------------------
# New productivity tools
# ---------------------------------------------------------------------------

_install_mise() {
  # mise — universal version manager replacing nvm/pyenv/rbenv/asdf.
  # Per-project .mise.toml pins exact runtimes; integrates with existing NVM.
  # https://mise.jdx.dev/
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v mise >/dev/null 2>&1; then
      curl https://mise.run | sh
    else
      mise self-update --yes 2>/dev/null || true
    fi
    "$HOME/.local/bin/mise" --version
  '
}

_install_lazygit() {
  # lazygit — terminal UI for git; branch/commit/rebase without leaving shell.
  # https://github.com/jesseduffield/lazygit
  local arch version tmpdir
  arch="$(binary_arch)"
  case "$arch" in
    amd64) arch="x86_64" ;;
    arm64) arch="arm64" ;;
    *) printf '[WARN] lazygit: unsupported arch %s\n' "$arch" >&2; return 0 ;;
  esac

  version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
    jq -r '.tag_name // empty')"
  version="${version#v}"
  [[ -n "$version" ]] || return 0

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"
  local tarball="lazygit_${version}_Linux_${arch}.tar.gz"
  download_file \
    "https://github.com/jesseduffield/lazygit/releases/download/v${version}/${tarball}" \
    "$tmpdir/${tarball}"
  tar -xzf "$tmpdir/${tarball}" -C "$tmpdir" lazygit
  as_root install -m 0755 "$tmpdir/lazygit" /usr/local/bin/lazygit
}

_install_lazydocker() {
  # lazydocker — terminal UI for Docker containers, images, and volumes.
  # https://github.com/jesseduffield/lazydocker
  local arch version tmpdir
  arch="$(binary_arch)"
  case "$arch" in
    amd64) arch="x86_64" ;;
    arm64) arch="arm64" ;;
    *) printf '[WARN] lazydocker: unsupported arch %s\n' "$arch" >&2; return 0 ;;
  esac

  version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazydocker/releases/latest |
    jq -r '.tag_name // empty')"
  version="${version#v}"
  [[ -n "$version" ]] || return 0

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"
  local tarball="lazydocker_${version}_Linux_${arch}.tar.gz"
  download_file \
    "https://github.com/jesseduffield/lazydocker/releases/download/v${version}/${tarball}" \
    "$tmpdir/${tarball}"
  tar -xzf "$tmpdir/${tarball}" -C "$tmpdir" lazydocker
  as_root install -m 0755 "$tmpdir/lazydocker" /usr/local/bin/lazydocker
}

_install_atuin() {
  # atuin — encrypted shell history with cross-device sync via SQLite.
  # Replaces plain .zsh_history; optional E2E encrypted cloud sync.
  # https://atuin.sh/
  run_as_user '
    set -e
    export PATH="$HOME/.local/bin:$HOME/.atuin/bin:$PATH"
    if ! command -v atuin >/dev/null 2>&1; then
      curl --proto "=https" --tlsv1.2 -LsSf https://setup.atuin.sh | sh
    else
      atuin self-update 2>/dev/null || true
    fi
  '
}

_install_zoxide() {
  # zoxide — frecency-based smart cd; jump to any dir by partial name.
  # https://github.com/ajeetdsouza/zoxide
  local arch version tmpdir
  arch="$(binary_arch)"
  case "$arch" in
    amd64) arch="x86_64-unknown-linux-musl" ;;
    arm64) arch="aarch64-unknown-linux-musl" ;;
    *) printf '[WARN] zoxide: unsupported arch %s\n' "$arch" >&2; return 0 ;;
  esac

  version="$(curl -fsSL https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest |
    jq -r '.tag_name // empty')"
  version="${version#v}"
  [[ -n "$version" ]] || return 0

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"
  local tarball="zoxide-${version}-${arch}.tar.gz"
  download_file \
    "https://github.com/ajeetdsouza/zoxide/releases/download/v${version}/${tarball}" \
    "$tmpdir/${tarball}"
  tar -xzf "$tmpdir/${tarball}" -C "$tmpdir" zoxide
  as_root install -m 0755 "$tmpdir/zoxide" /usr/local/bin/zoxide
}

_install_delta() {
  # delta — syntax-highlighted side-by-side git diff viewer.
  # Set as core.pager in git config for instant upgrade to all diffs.
  # https://github.com/dandavison/delta
  local arch version tmpdir
  arch="$(binary_arch)"
  case "$arch" in
    amd64) arch="x86_64-unknown-linux-musl" ;;
    arm64) arch="aarch64-unknown-linux-gnu" ;;
    *) printf '[WARN] delta: unsupported arch %s\n' "$arch" >&2; return 0 ;;
  esac

  version="$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest |
    jq -r '.tag_name // empty')"
  [[ -n "$version" ]] || return 0

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"
  local tarball="delta-${version}-${arch}.tar.gz"
  download_file \
    "https://github.com/dandavison/delta/releases/download/${version}/${tarball}" \
    "$tmpdir/${tarball}"
  tar -xzf "$tmpdir/${tarball}" -C "$tmpdir" --strip-components=1 \
    "delta-${version}-${arch}/delta"
  as_root install -m 0755 "$tmpdir/delta" /usr/local/bin/delta

  # Configure git to use delta as the default pager.
  run_as_user '
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.light false
    git config --global delta.side-by-side true
  '
}

_install_tldr() {
  # tldr — community-maintained simplified man pages; ideal on a phone screen.
  # https://tldr.sh/
  run_as_user '
    set -e
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    npm install -g --no-audit --no-fund tldr
    hash -r
  '
}

_install_modern_unix_tools() {
  # duf  — better df (disk usage overview with TUI)
  # dust — better du (intuitive directory size tree)
  # sd   — simpler sed replacement (sd "old" "new" file)
  # These are available as apt packages on Ubuntu 22.04+ or via cargo.
  apt_install duf || true
  apt_install dust || true

  # sd is not in Ubuntu apt; install via cargo if Rust is available.
  run_as_user '
    set -e
    export PATH="$HOME/.cargo/bin:$PATH"
    if command -v cargo >/dev/null 2>&1; then
      cargo install sd --locked 2>/dev/null || true
    fi
  '
}

_write_shell_config() {
  local block
  block="$(mktemp)"
  cat >"$block" <<'BLOCK'
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.cursor/bin:$HOME/.opencode/bin:$HOME/.atuin/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
if [[ -s "$HOME/.config/asik-dev/providers.env" ]]; then
  set -a
  source "$HOME/.config/asik-dev/providers.env"
  set +a
fi

# Load per-project environment overrides (.asik-dev.env in any parent directory).
_asik_load_project_env() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.asik-dev.env" ]]; then
      set -a
      # shellcheck source=/dev/null
      source "$dir/.asik-dev.env"
      set +a
      break
    fi
    dir="$(dirname "$dir")"
  done
}
_asik_load_project_env

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
# Ubuntu's packaged fzf plugin references files absent in minimal PRoot installs,
# so fzf remains installed as a binary but is not loaded as an OMZ plugin.
plugins=(git sudo zsh-autosuggestions zsh-syntax-highlighting)

if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# mise — universal version manager (node/python/ruby/go per project).
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# zoxide — smart cd replacement (use 'z' to jump, 'zi' for interactive).
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# atuin — encrypted shell history (Ctrl-R for fuzzy search).
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
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
alias lg='lazygit'
alias lzd='lazydocker'
alias z='zoxide'
alias cat='bat --paging=never 2>/dev/null || cat'
alias ls='eza --icons 2>/dev/null || ls'
alias du='dust 2>/dev/null || du'
alias df='duf 2>/dev/null || df'
alias top='btop 2>/dev/null || htop 2>/dev/null || top'

# Background update check — prints a one-line notice if a newer asik-dev is available.
_asik_update_check() {
  local current_ver latest_ver
  current_ver="$(asik-dev version 2>/dev/null | awk '{print $2}' || true)"
  latest_ver="$(curl -fsSL --max-time 5 \
    https://api.github.com/repos/asikmydeen/asik-dev/releases/latest 2>/dev/null |
    jq -r '.tag_name // empty' 2>/dev/null || true)"
  if [[ -n "$current_ver" && -n "$latest_ver" && "$current_ver" != "$latest_ver" ]]; then
    printf '\n[asik-dev] Update available: %s → %s  (run: asik-dev update)\n\n' \
      "$current_ver" "$latest_ver"
  fi
}
# Run in background so it never blocks shell startup.
( _asik_update_check & ) 2>/dev/null
BLOCK

  replace_managed_block "$TARGET_HOME/.zshrc" shell "$block"
  replace_managed_block "$TARGET_HOME/.bashrc" shell "$block"
  rm -f "$block"
}

module_shell() {
  run_step "Install Oh My Zsh, Powerlevel10k, and plugins" _install_zsh_stack
  run_step "Install Node.js LTS and npm with NVM" _install_nvm_node
  run_step "Activate pnpm with Corepack" _install_pnpm
  run_step "Install uv Python package manager" _install_uv
  run_step "Install Rust toolchain" _install_rust
  run_step "Install Go toolchain" _install_go
  run_step "Install mise universal version manager" _install_mise
  run_step "Install lazygit terminal UI" _install_lazygit
  run_step "Install lazydocker terminal UI" _install_lazydocker
  run_step "Install atuin encrypted shell history" _install_atuin
  run_step "Install zoxide smart cd" _install_zoxide
  run_step "Install delta git diff viewer" _install_delta
  run_step "Install tldr simplified man pages" _install_tldr
  run_step "Install modern Unix tools (duf, dust, sd)" _install_modern_unix_tools
  run_step "Write managed Bash and Zsh configuration" _write_shell_config
}
