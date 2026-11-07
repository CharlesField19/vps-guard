# Security policy

This tool runs as root and changes SSH and firewall configuration. Treat every change as potentially remote-access affecting.

## Reporting a vulnerability

Please do not open a public issue with working exploit details, credentials, private keys, or live hostnames.

Use GitHub's private security advisory for this repository, or contact the maintainer through the repository owner's public profile. Include:

- the affected version (`bash vps-guard.sh --version` or `VERSION`),
- the command or menu path used,
- the expected and actual result,
- a minimal reproduction that does not contain live secrets.

## Supported versions

Security fixes are applied to the current `main` branch. Older tags are not guaranteed to receive backports.

## Safe testing

- Use a disposable VM or container for destructive checks.
- Keep a provider console or rescue path available before changing SSH or UFW.
- Never paste `authorized_keys` private material, API tokens, or full authentication logs into an issue.
