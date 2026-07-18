#!/usr/bin/env bash
set -Eeuo pipefail

_base_update() {
  retry as_root apt-get update
}

_base_packages() {
  apt_install \
    apt-transport-https bash-completion build-essential ca-certificates curl \
    dnsutils ffmpeg file findutils fzf git gnupg htop jq less locales lsb-release \
    make nano ncdu openjdk-21-jdk-headless openssh-client openssl pipx procps \
    python-is-python3 python3 python3-pip python3-venv ripgrep rsync shellcheck \
    software-properties-common sudo tar tmux tree unzip vim wget xz-utils zip zsh

  # Package names vary by Ubuntu release; install these independently.
  apt_install bat || true
  apt_install eza || true
  apt_install btop || true
  apt_install yq || true
}

_base_locale() {
  if command -v locale-gen >/dev/null 2>&1; then
    as_root locale-gen en_US.UTF-8
  fi
}

module_base() {
  run_step "Refresh Ubuntu package metadata" _base_update
  run_step "Install base development, Java, Python, and camera packages" _base_packages
  run_step "Configure UTF-8 locale" _base_locale
}
