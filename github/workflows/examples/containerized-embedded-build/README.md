# containerized-embedded-build — Examples

Drop-in workflow templates that consume the
[`containerized-embedded-build`][reusable] reusable workflow.

[reusable]: ../../../../.github/workflows/containerized-embedded-build.yml

## When to pick what

| Example | Use when |
| ------- | -------- |
| [`rpbridge-firmware-only.yml`](rpbridge-firmware-only.yml) | Single component (firmware), multi-board matrix. The simplest possible consumer — one job, one reusable call. |
| [`rpbridge-full-matrix.yml`](rpbridge-full-matrix.yml) | Multi-component embedded repo (firmware + driver + userspace + tests). Demonstrates one reusable call per component, sharing a warm toolchain cache. |
| [`rpbridge-release.yml`](rpbridge-release.yml) | Tag-driven release pipeline that calls the reusable per component, downloads all artefacts, and publishes a GitHub Release with SBOM + checksums. |
| [`self-hosted-runner.yml`](self-hosted-runner.yml) | Run on BAUER-internal hardware runners instead of `ubuntu-latest`. Demonstrates the runner-flex JSON-array form and `cleanup-image: true` to spare bench-runner disk. |
| [`custom-toolchain-paths.yml`](custom-toolchain-paths.yml) | Project layout that doesn't follow the reference defaults (Dockerfile in `ci/`, build script at `scripts/ci-build.sh`, custom dist layout). Every path-related input is overridable. |

## Anatomy of a consumer

Every example follows the same shape:

```yaml
on:        what triggers a run (push to main, tag, PR, …)
jobs:
  <name>:
    name: 🔥 Firmware           # consumer-side label + emoji
    uses: bauer-group/automation-templates/.github/workflows/containerized-embedded-build.yml@main
    with:
      component: firmware       # firmware | driver | userspace | test | all
      matrix-variants: |
        [
          { "args": "<build-flag>", "id": "<artefact-slug>", "label": "<UI display name>" },
          …
        ]
      attach-driver-binary: false   # opt-in for binary kernel-module deliverables
```

Each matrix entry is an object with `args` (passed verbatim to the
build command), `id` (used in artefact names — must be unique), and
optional `label` (the human-friendly name shown in the GitHub UI;
falls back to `id`). The reusable does the rest: buildx cache, image
materialisation, build-script invocation, artefact upload, summary
rendering.

## Project requirements

Your consumer repo must have:

1. **A toolchain Dockerfile** that bundles all build dependencies
   (default location: `tools/docker/builder.Dockerfile`).
2. **A build entrypoint script** that re-execs itself inside the
   container when run on the host (default: `tools/build.sh`).

The reference implementation is
[USB-Multi-Bus-Bridge][rpbridge]. Copy `tools/build.sh` and
`tools/docker/builder.Dockerfile` from there as a starting point if
you're bootstrapping a new project.

[rpbridge]: https://github.com/bauer-group/USB-Multi-Bus-Bridge

## Driver compatibility matrix

When `emit-driver-compat-matrix: true` is set, the workflow renders
the project's `docs/driver-compatibility.yml` into the run summary.
The schema is intentionally tiny:

```yaml
compatibility:
  - kernel:    '7.0.0-14-generic'
    rustc:     '—'
    r4l_api:   '—'
    status:    'builds + module link'
    notes:     'C kernel module, auxiliary_bus parent.'
```

Missing fields render as `—`. The schema is generic — fill the columns
that match your driver's reality (rustc/r4l_api are leftover from the
Rust-for-Linux era; for a C driver, leave them as `—` or repurpose the
fields by editing the renderer in the reusable workflow).
