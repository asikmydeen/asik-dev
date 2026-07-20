#!/usr/bin/env bash
set -Eeuo pipefail
# Module 45: Security tools and additional infrastructure CLIs.
# Installs: age, sops, Pulumi, ArgoCD CLI, Flux CLI.

# ---------------------------------------------------------------------------
# Security & Secrets Tools
# ---------------------------------------------------------------------------

_install_age() {
  # age — simple, modern file encryption (replaces GPG for most use cases).
  # Small explicit keys, no config options, UNIX-composable.
  # Used to encrypt providers.env backups and secrets-in-git workflows.
  # https://github.com/FiloSottile/age
  local arch version tmpdir
  arch="$(binary_arch)"
  case "$arch" in
    amd64) arch="amd64" ;;
    arm64) arch="arm64" ;;
    *) printf '[WARN] age: unsupported arch %s\n' "$arch" >&2; return 0 ;;
  esac

  version="$(curl -fsSL https://api.github.com/repos/FiloSottile/age/releases/latest |
    jq -r '.tag_name // empty')"
  [[ -n "$version" ]] || return 0

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"
  local tarball="age-${version}-linux-${arch}.tar.gz"
  download_file \
    "https://github.com/FiloSottile/age/releases/download/${version}/${tarball}" \
    "$tmpdir/${tarball}"
  tar -xzf "$tmpdir/${tarball}" -C "$tmpdir" age/age age/age-keygen
  as_root install -m 0755 "$tmpdir/age/age" /usr/local/bin/age
  as_root install -m 0755 "$tmpdir/age/age-keygen" /usr/local/bin/age-keygen
}

_install_sops() {
  # sops — encrypted secrets editor for YAML/JSON/ENV/INI files.
  # Works with age, AWS KMS, GCP KMS, and Azure Key Vault.
  # Enables safe secrets-in-git workflows alongside providers.env.
  # https://github.com/getsops/sops
  local arch version tmpdir
  arch="$(binary_arch)"
  case "$arch" in
    amd64) arch="amd64" ;;
    arm64) arch="arm64" ;;
    *) printf '[WARN] sops: unsupported arch %s\n' "$arch" >&2; return 0 ;;
  esac

  version="$(curl -fsSL https://api.github.com/repos/getsops/sops/releases/latest |
    jq -r '.tag_name // empty')"
  [[ -n "$version" ]] || return 0

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"
  local binary="sops-${version}.linux.${arch}"
  download_file \
    "https://github.com/getsops/sops/releases/download/${version}/${binary}" \
    "$tmpdir/sops"
  as_root install -m 0755 "$tmpdir/sops" /usr/local/bin/sops
}

# ---------------------------------------------------------------------------
# Infrastructure CLIs
# ---------------------------------------------------------------------------

_install_pulumi() {
  # Pulumi — Infrastructure as Code in real languages (Python, TypeScript, Go).
  # Complements the existing Terraform/OpenTofu install.
  # https://www.pulumi.com/docs/install/
  run_as_user '
    set -e
    export PATH="$HOME/.pulumi/bin:$HOME/.local/bin:$PATH"
    if ! command -v pulumi >/dev/null 2>&1; then
      curl -fsSL https://get.pulumi.com | sh
    else
      pulumi version >/dev/null
    fi
  '
}

_install_argocd_cli() {
  # ArgoCD CLI — GitOps CD for Kubernetes; natural extension of kubectl/helm/k9s.
  # https://argo-cd.readthedocs.io/en/stable/cli_installation/
  local arch version tmpdir
  arch="$(binary_arch)"
  case "$arch" in
    amd64) arch="amd64" ;;
    arm64) arch="arm64" ;;
    *) printf '[WARN] argocd: unsupported arch %s\n' "$arch" >&2; return 0 ;;
  esac

  version="$(curl -fsSL https://api.github.com/repos/argoproj/argo-cd/releases/latest |
    jq -r '.tag_name // empty')"
  [[ -n "$version" ]] || return 0

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"
  download_file \
    "https://github.com/argoproj/argo-cd/releases/download/${version}/argocd-linux-${arch}" \
    "$tmpdir/argocd"
  as_root install -m 0755 "$tmpdir/argocd" /usr/local/bin/argocd
}

_install_flux_cli() {
  # Flux CLI — Flux GitOps operator CLI; alternative GitOps path to ArgoCD.
  # https://fluxcd.io/flux/installation/
  local script
  script="$(mktemp)"
  register_cleanup_dir "$(dirname "$script")"
  download_file https://fluxcd.io/install.sh "$script"
  chmod 0755 "$script"
  as_root "$script"
}

module_security() {
  run_step "Install age file encryption" _install_age
  run_step "Install sops secrets editor" _install_sops
  run_step "Install Pulumi IaC CLI" _install_pulumi
  run_step "Install ArgoCD CLI" _install_argocd_cli
  run_step "Install Flux GitOps CLI" _install_flux_cli
}
