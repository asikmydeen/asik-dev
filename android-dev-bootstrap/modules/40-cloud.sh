#!/usr/bin/env bash
set -Eeuo pipefail

_install_github_cli() {
  as_root install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
    as_root tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  as_root chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' \
    "$(deb_arch)" |
    as_root tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  retry as_root apt-get update
  apt_install gh
}

_install_aws_cli() {
  local arch url tmpdir
  arch="$(binary_arch)"
  case "$arch" in
    arm64) url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
    amd64) url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
    *)
      printf 'AWS CLI v2 binary is unavailable for architecture %s\n' "$arch" >&2
      return 1
      ;;
  esac

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"
  download_file "$url" "$tmpdir/awscliv2.zip"
  unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir"
  as_root "$tmpdir/aws/install" --update
}

_install_azure_cli() {
  local script
  script="$(mktemp)"
  download_file https://aka.ms/InstallAzureCLIDeb "$script"
  as_root bash "$script"
  rm -f "$script"
}

_install_gcloud_cli() {
  as_root install -m 0755 -d /usr/share/keyrings
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg |
    as_root gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg

  printf '%s\n' \
    'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' |
    as_root tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null

  retry as_root apt-get update
  apt_install google-cloud-cli
}

_install_terraform() {
  as_root install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://apt.releases.hashicorp.com/gpg |
    as_root gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg

  local codename
  codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-jammy}")"
  printf 'deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com %s main\n' \
    "$codename" |
    as_root tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

  retry as_root apt-get update
  apt_install terraform
}

_install_opentofu() {
  local script
  script="$(mktemp)"
  download_file https://get.opentofu.org/install-opentofu.sh "$script"
  chmod 0755 "$script"
  as_root "$script" --install-method deb
  rm -f "$script"
}

_install_kubectl() {
  # improvement #9: SHA256 checksum verified via the official .sha256 file.
  local version arch tmpdir
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  arch="$(binary_arch)"
  [[ "$arch" == "arm64" || "$arch" == "amd64" ]] || return 1

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"
  download_file "https://dl.k8s.io/release/${version}/bin/linux/${arch}/kubectl" \
    "$tmpdir/kubectl"
  download_file "https://dl.k8s.io/release/${version}/bin/linux/${arch}/kubectl.sha256" \
    "$tmpdir/kubectl.sha256"

  local expected_hash
  expected_hash="$(cat "$tmpdir/kubectl.sha256")"
  verify_sha256 "$tmpdir/kubectl" "$expected_hash"

  as_root install -m 0755 "$tmpdir/kubectl" /usr/local/bin/kubectl
}

_install_helm() {
  local script
  script="$(mktemp)"
  download_file https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 "$script"
  chmod 0755 "$script"
  as_root "$script"
  rm -f "$script"
}

_install_k9s() {
  # improvement #9: SHA256 checksum verified against the upstream checksums file.
  local arch version tmpdir
  arch="$(binary_arch)"
  case "$arch" in
    arm64) arch="arm64" ;;
    amd64) arch="amd64" ;;
    *) return 1 ;;
  esac

  version="$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest |
    jq -r '.tag_name // empty')"
  [[ -n "$version" ]] || return 1

  tmpdir="$(mktemp -d)"
  register_cleanup_dir "$tmpdir"

  local tarball="k9s_Linux_${arch}.tar.gz"
  local checksums_url="https://github.com/derailed/k9s/releases/download/${version}/checksums.sha256"

  download_file \
    "https://github.com/derailed/k9s/releases/download/${version}/${tarball}" \
    "$tmpdir/${tarball}"
  download_file "$checksums_url" "$tmpdir/checksums.sha256"

  # Extract the expected hash for this specific tarball from the checksums file.
  local expected_hash
  expected_hash="$(grep " ${tarball}$" "$tmpdir/checksums.sha256" | awk '{print $1}')"
  [[ -n "$expected_hash" ]] || { _fail "Could not find checksum for ${tarball} in release checksums"; return 1; }
  verify_sha256 "$tmpdir/${tarball}" "$expected_hash"

  tar -xzf "$tmpdir/${tarball}" -C "$tmpdir" k9s
  as_root install -m 0755 "$tmpdir/k9s" /usr/local/bin/k9s
}

_install_kubectx_kubens() {
  local base=/opt/kubectx
  if [[ ! -d "$base/.git" ]]; then
    as_root git clone --depth 1 https://github.com/ahmetb/kubectx "$base"
  else
    as_root git -C "$base" pull --ff-only
  fi
  as_root ln -sfn "$base/kubectx" /usr/local/bin/kubectx
  as_root ln -sfn "$base/kubens" /usr/local/bin/kubens
}

module_cloud() {
  run_step "Install GitHub CLI" _install_github_cli
  run_step "Install AWS CLI v2" _install_aws_cli
  run_step "Install Azure CLI" _install_azure_cli
  run_step "Install Google Cloud CLI" _install_gcloud_cli
  run_step "Install Terraform" _install_terraform
  run_step "Install OpenTofu" _install_opentofu
  run_step "Install kubectl with checksum verification" _install_kubectl
  run_step "Install Helm" _install_helm
  run_step "Install k9s" _install_k9s
  run_step "Install kubectx and kubens" _install_kubectx_kubens
}
