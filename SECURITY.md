# Security Policy

## Supported Versions

Only the latest version of the bootstrap script on the `main` branch is actively maintained and receives security fixes.

| Version | Supported          |
| ------- | ------------------ |
| latest (main) | Yes |
| older tags    | No  |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please **do not** open a public GitHub Issue. Instead, report it privately by emailing the repository maintainer directly via the contact information on their [GitHub profile](https://github.com/asikmydeen).

Please include a clear description of the vulnerability, the steps required to reproduce it, and the potential impact. You can expect an acknowledgment within 72 hours and a resolution or mitigation plan within 14 days for confirmed vulnerabilities.

## Security Boundaries and Assumptions

This project is designed to run inside a **Termux + Ubuntu PRoot environment** on Android. Users should be aware of the following security properties and limitations of this environment.

**PRoot is not a security boundary.** PRoot is a userspace chroot implementation. It does not provide kernel-level isolation, namespaces, or cgroups. A process inside the PRoot environment can, in principle, interact with the host Android system. Do not use this environment to handle secrets that must be isolated from the Android host OS.

**Passwordless sudo is intentional in PRoot.** The installer grants the development user passwordless `sudo` access inside the Ubuntu PRoot container. This is a deliberate convenience trade-off because the Linux user boundary inside PRoot is not a meaningful security boundary on Android. Do not replicate this configuration on a shared or production server.

**API keys are stored at mode 600.** All provider secrets are stored in `~/.config/asik-dev/providers.env` with file permissions set to `0600`, meaning they are readable only by the owning user. The `asik-dev doctor` command will never print the contents of this file. Do not commit the populated `providers.env` file to version control.

**Camera streams should not be exposed to the internet.** The `camera-ai` helper is designed to connect to an RTSP stream on a local network. Always change the default credentials on your IP camera application and ensure the RTSP port is not forwarded through your router or firewall.

**Downloaded binaries are verified by checksum.** The installer verifies the SHA256 checksum of downloaded external binaries (e.g., `kubectl`, `k9s`, `helm`) against the official release checksums before installing them. If a checksum fails, the installation step is aborted and logged as a failure.
