# Contributing

## Checks

Run the local checks before opening a pull request:

```bash
make syntax
make test
make lint   # requires shellcheck
```

`make test` runs `tests/run.sh`. Tests that need root or `sshd` skip automatically when those prerequisites are unavailable. On a normal Linux host, run them as root for full coverage.

## Guidelines

- Keep menu text bilingual through `ui_text` or `lib/i18n.sh`.
- Put system-changing logic in `lib/`, not in `modules/ui/`.
- Use `VPS_GUARD_SSH_DIR`, `VPS_GUARD_SYSTEMD_DIR`, `VPS_GUARD_UFW_DEFAULTS`, and `VPS_GUARD_ROOT_AUTHORIZED_KEYS` instead of hardcoded paths.
- Add a test under `tests/` for behavior changes. Prefer command mocks over touching the live host.
- Never commit secrets, keys, tokens, or real host output.
- Do not add a global `set -e` to interactive menus.
