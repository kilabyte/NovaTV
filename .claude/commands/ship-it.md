---
description: Bump app version and build number, commit, push, and tag to trigger the GitHub Actions release
---

Ship a new NovaTV release. Follow these steps exactly and in order:

1. Confirm the working tree is clean with `git status`. If there are uncommitted changes, stop and ask whether they should be committed first or shipped separately.

2. Read the current version from `pubspec.yaml` (format `X.Y.Z+N`). Increment the patch version and the build number together: `X.Y.Z+N` becomes `X.Y.(Z+1)+(N+1)`. For example `1.0.20+19` becomes `1.0.21+20`.

3. Update the `version:` line in `pubspec.yaml` with the new value.

4. Commit with the message `build: bump version to X.Y.(Z+1)+(N+1)`.

5. Push main to both remotes: `git push origin main && git push github main`.

6. Create an annotated tag `vX.Y.(Z+1)` with a short message summarizing what is in the release (check `git log` since the previous tag for the highlights).

7. Push the tag to both remotes: `git push origin vX.Y.(Z+1) && git push github vX.Y.(Z+1)`.

8. Confirm the release workflow started: `gh run list --repo kilabyte/NovaTV --limit 2` should show a "Build and Release" run for the new tag. Report the run status to the user.

Notes:
- Releases publish from the tag push on the github remote. The origin remote is the private GitLab and does not run the release.
- Never retag or force-push an existing tag. If the tag already exists, stop and report it.
