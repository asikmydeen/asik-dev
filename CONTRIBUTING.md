# Contributing to asik-dev

Thank you for your interest in contributing! This guide covers everything you need to know to get started, from setting up a local development environment to submitting a pull request.

## Code of Conduct

Please be respectful and constructive in all interactions. This project is maintained by a single developer and contributions of all sizes are welcome.

## Development Setup

The bootstrap scripts are designed to run inside a Termux + Ubuntu PRoot environment on Android, but you can develop and test them on any standard Ubuntu 22.04 or 24.04 system. To set up a local development environment:

1. Clone the repository: `git clone https://github.com/asikmydeen/asik-dev.git`
2. Install test dependencies: `sudo apt-get install -y shellcheck`
3. Navigate to the bootstrap directory: `cd asik-dev/android-dev-bootstrap`
4. Run the smoke test suite: `tests/smoke.sh`

The smoke tests validate Bash and Python syntax, run ShellCheck on all shell scripts, verify that the `asik-dev configure` command generates valid JSON configuration files, and confirm that the `ollama` wrapper reports its version correctly.

## Coding Conventions

All shell scripts **must** begin with `#!/usr/bin/env bash` and `set -Eeuo pipefail`. This ensures that the script exits immediately on any error, unset variable reference, or failed pipe command, which is critical for a bootstrap installer that runs with elevated privileges.

New binary wrappers placed in `bin/` should follow the existing pattern: source `providers.env`, validate that the required API key is set, and `exec` the underlying tool so that the wrapper process is replaced rather than forked. This keeps the process tree clean and ensures that signals are forwarded correctly.

When adding a new installation step to a module, always wrap it in a `run_step "Descriptive title" _function_name` call. This integrates the step into the summary report and the log file automatically.

## Adding a New Module or Tool

New installation logic should be placed in the appropriate numbered module file under `modules/`. If the tool does not fit an existing category, create a new numbered module file (e.g., `70-new-category.sh`) and call its `module_*` function from `install.sh`. Update `install.sh`'s `FILES` array to include the new module so it is downloaded during installation.

If the new tool requires an API key, add the key name to `templates/providers.env.example` with an empty default value and a short comment. Update the `cmd_secrets` function in `bin/asik-dev` to prompt for the new key.

## Pull Request Process

1. Fork the repository and create a branch from `main` with a descriptive name (e.g., `feat/add-new-tool` or `fix/idempotent-install`).
2. Make your changes, ensuring all smoke tests pass locally.
3. Update `CHANGELOG.md` under the `[Unreleased]` section to describe your changes.
4. Open a pull request against `main`. The CI workflow will automatically run the smoke tests and ShellCheck linter.
5. Address any review comments and ensure the CI checks pass before requesting a merge.

## Reporting Bugs

Please open a GitHub Issue with a clear title and description. Include the output of `asik-dev doctor` and `asik-dev versions`, the contents of your install log (found at `~/.local/state/asik-dev/install.log`), and the steps to reproduce the problem. Do **not** include the contents of `providers.env` or any API keys in the issue.
