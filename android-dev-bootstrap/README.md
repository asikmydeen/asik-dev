# Asik Dev Bootstrap

A repeatable Android development workstation for **Termux + Andronix Ubuntu**.
It installs cloud, DevOps, language, and AI coding CLIs, then manages provider
secrets and MCP configuration from one place.

## One-line setup

### First run in Termux

```bash
curl -fsSL https://raw.githubusercontent.com/asikmydeen/asik-dev/main/android-dev-bootstrap/install.sh | bash
```

The Termux phase installs host prerequisites and looks for an existing Andronix
Ubuntu launcher. Andronix itself has one unavoidable manual step because its app
generates the distro-specific Ubuntu command.

After Andronix finishes installing Ubuntu, enter Ubuntu and run the same command:

```bash
curl -fsSL https://raw.githubusercontent.com/asikmydeen/asik-dev/main/android-dev-bootstrap/install.sh | bash
```

The default Linux development user is `asik`. To use another name:

```bash
curl -fsSL https://raw.githubusercontent.com/asikmydeen/asik-dev/main/android-dev-bootstrap/install.sh |
  bash -s -- --user myuser
```

The installer is idempotent: rerunning it repairs missing components and updates
managed configuration without deleting projects or credentials.

## What is installed

### Shell and languages

- Zsh, Oh My Zsh, Powerlevel10k
- zsh-autosuggestions and zsh-syntax-highlighting
- Node.js LTS through NVM, npm, and pnpm
- Python, pipx, and uv
- Go and Rust
- Git, tmux, fzf, ripgrep, jq, yq, bat, eza, btop, and common build tools

### Cloud and DevOps

- GitHub CLI
- AWS CLI v2
- Azure CLI
- Google Cloud CLI
- Terraform and OpenTofu
- kubectl, Helm, k9s, kubectx, and kubens

### AI coding tools

- Claude Code
- OpenAI Codex
- Cursor Agent CLI
- Grok Build CLI
- Google Antigravity CLI (`agy`)
- OpenCode
- Aider
- Cloud-only Ollama API wrapper

The `ollama` command in this project calls `https://ollama.com/api` directly.
It does **not** start a local Ollama daemon or download model weights to Android.

## Add all API keys safely

```bash
su - asik
asik-dev secrets
```

Input is hidden. Values are stored in:

```text
~/.config/asik-dev/providers.env
```

The file is mode `600`, never committed by this repository, and values are not
shown by `asik-dev doctor`.

Add or change one key:

```bash
asik-dev secrets set OPENAI_API_KEY
asik-dev secrets set ZAI_API_KEY
asik-dev secrets set XAI_API_KEY
asik-dev secrets set CURSOR_API_KEY
asik-dev secrets set OLLAMA_API_KEY
```

Review configured/missing keys without printing values:

```bash
asik-dev secrets status
```

Supported values include OpenAI, Anthropic, Z.AI, xAI, Gemini, OpenRouter,
Cursor, Ollama Cloud, Brave, Tavily, Groq, DeepSeek, Together, Mistral,
Cerebras, Azure OpenAI, AWS Bedrock, and Google Cloud defaults.

## AI commands

```bash
claude-zai
claude-anthropic
codex
cursor-agent
grok
agy
opencode
aider
aider-xai
aider-openrouter
ollama run qwen3-coder:480b "Explain this repository"
```

`claude-zai` configures Claude Code for the Z.AI Anthropic-compatible endpoint
and GLM models only for that process. It does not overwrite your normal Claude
Code account configuration.

## Authentication that still requires a browser/device flow

API keys are centralized, but account-based CLIs intentionally keep their own
secure login state:

```bash
gh auth login
aws configure sso
az login --use-device-code
gcloud auth login --no-launch-browser
cursor-agent login
grok login --device-auth
agy
codex
```

## Shared MCP configuration

Run:

```bash
asik-dev configure
```

The configuration includes:

- filesystem access limited to `~/projects`
- memory
- sequential thinking

It is adapted for Cursor, Antigravity, OpenCode, Grok, Claude Code, and Codex
where their installed CLI/config format supports it.

Canonical configuration:

```text
~/.config/asik-dev/mcp.json
```

## Maintenance

```bash
asik-dev doctor
asik-dev versions
asik-dev update
asik-dev repair
asik-dev backup
```

Backups exclude secrets by default. `asik-dev backup --include-secrets` is
available only for a destination you will encrypt and protect.

## Android/PRoot limitations

Andronix uses PRoot rather than a real booted Linux kernel. This environment is
excellent for command-line clients and development, but it does not provide a
normal systemd host, privileged containers, nested virtualization, or reliable
local Docker/Kubernetes daemons. This project installs cloud control-plane
clients rather than pretending those kernel capabilities exist.

## Security

- No API key is embedded in source code.
- The public repository contains templates only.
- Provider values are stored under your home directory with mode `600`.
- MCP filesystem access is restricted to `~/projects`.
- The installer does not upload configuration or credentials.
- Review remote installers before use in high-security environments.

## Validate locally

```bash
cd android-dev-bootstrap
tests/smoke.sh
```

## License

MIT
