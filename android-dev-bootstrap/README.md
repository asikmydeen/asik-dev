# Asik Dev Bootstrap

A repeatable Android development workstation for **Termux + Ubuntu through proot-distro**. It installs cloud, DevOps, language, AI coding, and camera-processing tools, then manages provider secrets and MCP configuration from one place.

## One-line setup

Run in Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/asikmydeen/asik-dev/main/android-dev-bootstrap/install.sh | bash
```

The Termux phase installs `proot-distro`, creates an Ubuntu 24.04 container when needed, and writes `~/asik-dev-next.sh`.

Run:

```bash
~/asik-dev-next.sh
```

Future login:

```bash
proot-distro login ubuntu --user asik
```

The installer is idempotent: rerunning it repairs missing components without deleting projects or credentials.

## Installed foundations

- Zsh, Oh My Zsh, Powerlevel10k, autosuggestions, and syntax highlighting
- Node.js LTS with NVM, npm, and Corepack-managed pnpm
- Python 3 plus the `python` alias, pipx, and uv
- OpenJDK 21, Go, and Rust
- GitHub, AWS, Azure, and Google Cloud CLIs
- Terraform, OpenTofu, kubectl, Helm, k9s, kubectx, and kubens
- FFmpeg and FFprobe for RTSP camera streams
- Claude Code, Codex, Cursor Agent, Grok Build, Antigravity (`agy`), OpenCode, and Aider
- Cloud-only Ollama wrapper; no local model daemon or weights

## Secrets

```bash
asik-dev secrets
asik-dev secrets status
```

Values are stored at `~/.config/asik-dev/providers.env` with mode `600` and are never printed by `asik-dev doctor`.

## Ollama Cloud

Always inspect the current model catalog first because cloud models can be retired:

```bash
ollama list
ollama run gpt-oss:120b "Explain this repository"
```

The wrapper returns a specific hint when Ollama reports HTTP 410 for a retired model.

## Android camera to AI

Install an Android IP-camera app that exposes an RTSP URL. Save the URL without committing it:

```bash
asik-dev secrets set OPENROUTER_API_KEY
printf "RTSP_URL='%s'\n" 'rtsp://USER:PASSWORD@PHONE_IP:8554/live/0' >> ~/.config/asik-dev/providers.env
```

Then capture one frame and process it with OpenRouter vision:

```bash
camera-ai "Describe everything visible and mention safety concerns"
```

Images and analyses are stored under `~/camera-ai-output`.

## Authentication flows

```bash
gh auth login
aws configure sso
az login --use-device-code
gcloud auth login --no-launch-browser
cursor-agent login
grok login --device-auth
codex
agy
```

## Maintenance

```bash
asik-dev doctor
asik-dev versions
asik-dev update
asik-dev repair
asik-dev backup
```

## PRoot limitations

This is a userspace Ubuntu environment, not a booted Linux kernel. It is excellent for CLI development and network camera processing, but it does not provide systemd, privileged containers, nested virtualization, or a native `/dev/video0`. Camera access is through RTSP/HTTP streams.

## Security

- Change default IP-camera credentials.
- Do not expose camera streams directly to the internet.
- Keep provider files at mode `600`.
- MCP filesystem access is restricted to `~/projects`.
- Backups exclude secrets unless explicitly requested.

## Validation

```bash
cd android-dev-bootstrap
tests/smoke.sh
```

## License

MIT
