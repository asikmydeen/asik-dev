#!/usr/bin/env bash
set -Eeuo pipefail

_install_management_commands() {
  local install_root=/opt/asik-dev-bootstrap
  local command
  for command in asik-dev ollama claude-zai claude-anthropic aider-xai aider-openrouter; do
    as_root install -m 0755 "$install_root/bin/$command" "/usr/local/bin/$command"
  done
}

_initialize_provider_file() {
  local config_dir="$TARGET_HOME/.config/asik-dev"
  local providers="$config_dir/providers.env"
  safe_mkdir_user "$config_dir"

  if [[ ! -f "$providers" ]]; then
    install_user_file \
      /opt/asik-dev-bootstrap/templates/providers.env.example \
      "$providers" \
      0600
  else
    as_root chmod 0600 "$providers"
    as_root chown "$TARGET_USER:$TARGET_USER" "$providers"
  fi
}

_generate_configs() {
  run_as_user '/usr/local/bin/asik-dev configure'
}

module_config() {
  run_step "Install asik-dev management and provider wrappers" _install_management_commands
  run_step "Initialize secure provider file" _initialize_provider_file
  run_step "Generate shared MCP and AI configuration" _generate_configs
}
