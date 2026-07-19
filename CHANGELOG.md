# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `CHANGELOG.md` to track all notable changes per version.
- `CONTRIBUTING.md` guide for contributors.
- `SECURITY.md` policy for responsible vulnerability disclosure.
- Dedicated ShellCheck linting step in the `android-dev-bootstrap` CI workflow.
- Matrix strategy in CI to run smoke tests across `ubuntu-22.04` and `ubuntu-24.04`.
- Checksum (SHA256) verification for downloaded external binaries (`k9s`, `kubectl`, `helm`).
- Unified trap-based cleanup mechanism in `lib/common.sh` for graceful error handling.
- Retry with exponential backoff and improved network error messaging in the `ollama` cloud wrapper.

### Changed
- `install_framework` in `lib/common.sh` now uses `install -m 0755` for atomic, permission-safe binary placement.
- `_install_nvm_node` in `30-shell.sh` is now fully idempotent: it skips the LTS download if the current LTS version is already installed and set as default.
- `_install_k9s` and `_install_kubectl` in `40-cloud.sh` now verify SHA256 checksums before installing binaries.

## [1.2.1] - 2026-07-18

### Fixed
- Use a proot login probe to reliably detect an existing Ubuntu container during updates.

## [1.2.0] - 2026-07-18

### Added
- RTSP camera-to-AI helper (`camera-ai`) using FFmpeg and OpenRouter vision models.
- Cloud-only Ollama wrapper (`ollama`) that proxies to the Ollama cloud API.
- Hint message when Ollama returns HTTP 410 for a retired model.

### Changed
- Replaced retired Ollama default model with `gpt-oss:120b`.
- Switched to `proot-distro` for Ubuntu bootstrap on Termux.
- Activated `pnpm` via Corepack instead of a standalone install.
- Removed broken `fzf` Oh My Zsh plugin hook.

### Fixed
- Export provider variables from the managed shell config so AI wrappers inherit them.

## [1.1.0] - 2026-06-08

### Added
- Initial modular bootstrap structure with numbered modules (`10-base` through `60-config`).
- Support for multiple AI coding tools: Claude Code, OpenAI Codex, Aider, Cursor Agent, Grok Build, Google Antigravity.
- Secrets management via `asik-dev secrets` with mode-600 `providers.env`.
- MCP configuration generation for Claude, Cursor, Gemini, and OpenCode.
- `asik-dev doctor`, `versions`, `update`, `repair`, and `backup` commands.

[Unreleased]: https://github.com/asikmydeen/asik-dev/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/asikmydeen/asik-dev/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/asikmydeen/asik-dev/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/asikmydeen/asik-dev/releases/tag/v1.1.0
