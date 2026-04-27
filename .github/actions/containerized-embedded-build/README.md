# Containerized Embedded Build

A composite GitHub Action that materialises a project-supplied Docker
toolchain image (with the GitHub Actions layer cache wired up) and runs
a build command inside it. Intended for **embedded** projects where the
toolchain stack is too heterogeneous to install on the runner host —
ARM-cross compilers, kernel headers, distro-pinned `rustc`, vendored
SDKs — and is bundled into one Dockerfile instead.

The action is the building block underneath the
[`containerized-embedded-build` reusable workflow][reusable] and works
equally well as a single step inside any custom workflow.

[reusable]: ../../workflows/containerized-embedded-build.yml

## When to use this

Reach for this action when **all** of the following hold:

- Your build environment is captured in a `Dockerfile` (the toolchain
  is too thick to set up via `apt install` in a workflow step).
- You want **bit-identical** local-developer and CI builds — same
  image, same `build.sh` (or equivalent), same flags.
- You don't want to push the toolchain image to a registry on every
  commit (this is a *throwaway* container, not a deliverable).

If you instead want to **build and publish** a Docker image as the
deliverable (push to GHCR, run security scans, sync README to Docker
Hub), use the [`docker-build` reusable][docker-build] — that is a
different concern.

[docker-build]: ../../workflows/docker-build.yml

## How it works

```text
runner (ubuntu-latest)
└── docker/setup-buildx-action     ← provisions buildx
└── docker/build-push-action       ← pulls layers from GHA cache,
                                      materialises image as TAG,
                                      pushes new layers back to cache
└── tools/build.sh <component>     ← user's build entrypoint;
                                      it re-execs inside the container
                                      and runs the native build
└── docker image rm TAG            ← optional cleanup
```

The GHA cache (`cache-from: type=gha`) is global across runs of the
same workflow on the same scope — the second invocation on a branch
finds every layer pre-warm and the materialise step finishes in
seconds instead of minutes.

## Inputs

| Name | Description | Default |
| ---- | ----------- | ------- |
| `component` | Build target passed verbatim to the build command (e.g. `firmware`, `driver`, `userspace`). | **required** |
| `build-args` | Extra arguments appended after the component (e.g. a board name or cross-build flag). | `''` |
| `build-command` | Path to the project's build entrypoint. | `tools/build.sh` |
| `dockerfile-path` | Path to the toolchain `Dockerfile`. | `tools/docker/builder.Dockerfile` |
| `dockerfile-context` | Build context handed to `docker build`. | `tools/docker` |
| `image-tag` | Local tag the materialised image is bound to. | `rpbridge-builder:local` |
| `cache-scope` | buildx GHA cache scope. Keep the same value across all jobs in a project so they share a warm cache. | `containerized-embedded-build` |
| `cleanup-image` | Remove the materialised image from the runner after the build. The GHA cache survives. | `'false'` |
| `working-directory` | Repository-relative directory the build command runs in. | `.` |

## Outputs

| Name | Description |
| ---- | ----------- |
| `image-digest` | Digest of the materialised toolchain image. |
| `build-duration` | Duration of the build command in seconds. |
| `build-status` | `success` or `failure`. |

## Usage

### Minimal example (firmware)

```yaml
- uses: actions/checkout@v6
  with:
    submodules: recursive

- uses: bauer-group/automation-templates/.github/actions/containerized-embedded-build@main
  with:
    component: firmware
    build-args: rpbridge_rp2354b
```

### Inside a matrix

```yaml
strategy:
  matrix:
    board: [rpbridge_rp2354b, rpbridge_pico2]

steps:
  - uses: actions/checkout@v6
    with:
      submodules: recursive
  - uses: bauer-group/automation-templates/.github/actions/containerized-embedded-build@main
    with:
      component: firmware
      build-args: ${{ matrix.board }}
```

### Self-hosted runner with disk pressure

```yaml
- uses: bauer-group/automation-templates/.github/actions/containerized-embedded-build@main
  with:
    component: all
    cleanup-image: 'true'
```

## Project requirements

The consumer project must provide:

1. **A toolchain Dockerfile** at `dockerfile-path`. Anything that builds
   under `docker build`. Multi-stage is welcome but not required.
2. **A build entrypoint** at `build-command` that, when run on the host,
   detects it is outside the container and re-execs itself inside.
   The reference implementation is `tools/build.sh` from
   [USB-Multi-Bus-Bridge][rpbridge].

[rpbridge]: https://github.com/bauer-group/USB-Multi-Bus-Bridge/blob/main/tools/build.sh

The build entrypoint receives `RPBRIDGE_IMAGE_TAG` from this action so
it can find the pre-built image; consumer projects that don't honour
that variable will simply do their own (cached, fast) `docker build`.
