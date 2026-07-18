#!/usr/bin/env bash
set -Eeuo pipefail

_create_target_user() {
  if id "$TARGET_USER" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$(id -u)" -ne 0 ]]; then
    printf 'User %s does not exist and root access is unavailable.\n' "$TARGET_USER" >&2
    return 1
  fi

  adduser --disabled-password --gecos "" --shell /usr/bin/zsh "$TARGET_USER"
}

_configure_target_user() {
  local shell_path
  shell_path="$(command -v zsh)"
  as_root usermod -s "$shell_path" "$TARGET_USER"
  as_root usermod -aG sudo "$TARGET_USER"

  local home
  home="$(get_user_home "$TARGET_USER")"
  [[ -n "$home" ]] || return 1

  as_root mkdir -p \
    "$home/projects" \
    "$home/.config/asik-dev" \
    "$home/.local/bin" \
    "$home/.local/share" \
    "$home/.local/state/asik-dev"

  as_root chown "$TARGET_USER:$TARGET_USER" \
    "$home" \
    "$home/projects" \
    "$home/.config" \
    "$home/.config/asik-dev" \
    "$home/.local" \
    "$home/.local/bin" \
    "$home/.local/share" \
    "$home/.local/state" \
    "$home/.local/state/asik-dev"

  # Passwordless sudo is enabled only in Android/PRoot, where the Linux user
  # boundary is convenience rather than a host security boundary.
  if is_android_proot; then
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$TARGET_USER" |
      as_root tee "/etc/sudoers.d/90-asik-dev-${TARGET_USER}" >/dev/null
    as_root chmod 0440 "/etc/sudoers.d/90-asik-dev-${TARGET_USER}"
  fi
}

module_user() {
  run_step "Create Linux user $TARGET_USER" _create_target_user
  run_step "Prepare development user and workspace" _configure_target_user
}
