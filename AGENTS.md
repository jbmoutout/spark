# Repo Notes

- When editing shell scripts, assume both macOS/BSD and Ubuntu/GNU userlands. Avoid platform-specific flags and character-class quirks unless they are explicitly gated.
- Keep shell verification portable: prefer `npm test`, `shellcheck`, and commands that run the same in local development and GitHub Actions.
- If shell portability becomes tricky, prefer a small `python3` helper over clever shell syntax.
- Do not introduce repo-controlled execution or network behavior without explicit external opt-in.
- Do not restore remote installer downloads or repo-controlled custom widgets without re-evaluating the trust boundary.
- When changing hook output, installer behavior, or trust-boundary logic, update tests and docs in the same change.
- If you change shell portability rules or verification steps, keep `.github/workflows/ci.yml` in sync.
