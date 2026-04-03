# Contributing

## Shell Portability

Spark ships Bash hooks that run locally on macOS and in GitHub Actions on Ubuntu. Treat both environments as first-class targets.

- Avoid GNU-only or BSD-only shell behavior unless it is explicitly gated.
- Be careful with `tr`, `sed`, `date`, `grep`, `mktemp`, and inline regex or character ranges.
- In `tr` character sets, put `-` at the edge of the set or escape it.
- Prefer simple Bash and portable coreutils usage over clever one-liners.
- Run `npm test` before pushing shell changes.
- Let CI be the final check: the repo verifies shell changes on both `ubuntu-latest` and `macos-latest`.
