# Releasing Spark

1. Make sure the working tree is clean and the version in `package.json` is the version you intend to publish.
2. Run the local checks:
   - `npm test`
   - `for f in spark.sh spark-precompact.sh spark-stop.sh spark-widgets.sh install.sh; do bash -n "$f"; done`
   - `node --check bin/cli.js`
   - `shellcheck spark.sh spark-precompact.sh spark-stop.sh spark-widgets.sh install.sh`
   - `npm pack --dry-run`
3. Review docs when behavior or trust boundaries changed.
4. Commit using the repo Lore commit format.
5. Create and push the release tag: `git tag vX.Y.Z && git push origin vX.Y.Z`
6. Confirm the `CI` workflow passes and then verify the `Publish to npm` workflow completes successfully.
