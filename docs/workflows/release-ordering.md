# Release Ordering: Publish Last

How to build a release chain where a failed artifact build produces **no release**,
rather than a release with nothing behind it.

## The problem

The intuitive chain runs the release first and gates the build on its result:

```yaml
release:
  uses: .../modules-semantic-release.yml@main       # tag + Release + CHANGELOG

build:
  needs: release
  if: needs.release.outputs.release-created == 'true'
  uses: .../docker-build.yml@main                   # may fail
```

By the time the build runs, the git tag, the GitHub Release and the CHANGELOG entry
are already public. If the build then fails — a Trivy gate refusing an image with
unfixed CRITICALs, a unit test failing in the image test stage — the release stands
with no artifact behind it.

Observed in `IP-Kleinanzeigen-MCPServer`: two such releases in a single day, from two
unrelated build failures.

| Tag | Release job | Docker build | Image on GHCR |
| --- | --- | --- | --- |
| `v1.0.0` | ✅ 36s | ❌ 9m25s — Trivy gate blocked the push | none |
| `v1.0.1` | ✅ | ✅ | ✅ |
| `v1.0.2` | ✅ 51s | ❌ 2m5s — unit test failed in the image test stage | none |
| `v1.0.3` | ✅ | ✅ | ✅ |

Both gates behaved correctly. Neither is the problem — the problem is that the release
had already been cut when they fired.

Note what does *not* break: `latest` and `stable` still point at the last image that
actually built, so nothing deploys wrongly. The damage is to the record, and to anyone
pinning an exact version — `docker pull …:1.0.2` fails against a tag GitHub presents
as a shipped release.

## Why the ordering looks forced

The image tag *is* the release version, so the version has to exist before the image
can be labelled — which makes it look like the release job must run first. It does not.
Determining the version and publishing it are separate acts, and only the first one is
needed up front.

## The fix

Three jobs: determine → build → publish.

```yaml
determine:                                    # dry-run: writes nothing
  uses: .../modules-semantic-release.yml@main
  with:
    dry-run: true
    ref: ${{ github.sha }}

build:
  needs: determine
  if: needs.determine.outputs.will-release == 'true'
  uses: .../docker-build.yml@main
  with:
    release-version: ${{ needs.determine.outputs.next-version }}

publish:                                      # only now: tag, Release, CHANGELOG
  needs: [determine, build]
  uses: .../modules-semantic-release.yml@main
  with:
    ref: ${{ github.sha }}
```

`docker-build.yml`'s `release-version` input takes the number directly and generates
semver tags without requiring a tag to exist — which is what makes the split possible
without inventing a placeholder tag.

A full working file: [`docker-release-publish-last.yml`](../../github/workflows/examples/release/docker-release-publish-last.yml).

## The two guards, and why they are not optional

### `concurrency` — one release at a time

```yaml
concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false
```

Without it, two runs can both observe "nothing published yet", both legitimately
determine the same next version, and both publish it.

### `ref: github.sha` — same commit set in both jobs

The determine job and the publish job each run semantic-release independently. They
agree on the version only if they see the same commits. The build sits between them and
is the slow step — 9m25s in the case above — which is ample room for another push to
land on `main`.

Pinning both to `github.sha` closes that window. Without it you get the mirror image of
the original bug: an image tagged `1.0.2` under a release labelled `1.0.3`.

`modules-semantic-release.yml` defaults to the tip of `target-branch` when `ref` is
empty, preserving existing behaviour for callers that do not split the chain.

## Outputs: which question are you asking?

The module answers two different questions, and mixing them up is what makes the naive
chain look correct:

| Output | Question | In dry-run |
| --- | --- | --- |
| `will-release` | Would this commit set produce a release? | **meaningful** |
| `next-version` | What version would it be? | **meaningful** |
| `release-created` | Was a release actually published? | always `false` |
| `version`, `tag-name` | What was published? | empty |

Gate the build on `will-release`, not on `release-created` — in a dry-run the latter is
correctly `false`, because nothing was created.

## Version-number policy when the build fails

| Situation at the moment of failure | Version number | Why |
| --- | --- | --- |
| Nothing published — no tag, no Release, **no CHANGELOG commit** | **Reused** by the next attempt | Nothing outside CI ever saw it, so it is still free |
| Anything already written | **Burned** — stays a version without a release | The record already claims it; reusing it would make one number mean two things |

The trigger is *"has anything been written"*, not *"did the build succeed"* — which is
observable, because the publish job either ran or it did not.

Under the ordering above the reuse branch is the normal case: the build fails before
anything is written, so the next push simply retries the same number.

The burn branch covers only a publish that fails partway through. Do **not** add a
cleanup job that deletes the tag to reclaim the number. Deleting the tag does not undo
the CHANGELOG commit `@semantic-release/git` already pushed to `main`, so the next run
would compute the same version again and append a second entry for it — trading a wrong
release record for a wrong *and duplicated* changelog.

## Migration

For an existing repo using the naive chain:

1. Add the `concurrency` block.
2. Split the release job into `determine` (`dry-run: true`) and `publish`.
3. Move the build between them; feed it `needs.determine.outputs.next-version`.
4. Change the build's gate from `release-created` to `will-release`.
5. Add `ref: ${{ github.sha }}` to both release jobs.

No input or output was renamed or removed, so a chain that does not split keeps working
unchanged.
