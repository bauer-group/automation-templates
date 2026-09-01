# Workflow Audit

Static checks for script injection in GitHub Actions workflows, composite
actions and the example workflows shipped for consumers.

## Why

`${{ }}` expressions are substituted by the Actions runner **before** the shell
starts. Inside a `run:` body they are textual pasting, not variables:

```yaml
run: |
  VERSION="${{ inputs.custom-version }}"     # value is pasted into the script
```

A value carrying a quote, a newline or a shell metacharacter therefore
executes. The fix is always the same shape — move the value into `env:` and
reference it as a quoted shell variable:

```yaml
env:
  INPUT_CUSTOM_VERSION: ${{ inputs.custom-version }}
run: |
  VERSION="$INPUT_CUSTOM_VERSION"
```

Note that a **quoted heredoc does not help**: `<< 'EOF'` stops expansion of the
*content*, but expression substitution has already happened, so a value
containing a newline followed by a bare `EOF` closes the heredoc early and the
remainder runs as shell.

## Usage

```bash
pip install -r requirements.txt

python tools/workflow-audit/workflow_audit.py                 # all checks
python tools/workflow-audit/workflow_audit.py --check dispatch
python tools/workflow-audit/workflow_audit.py --format json
python tools/workflow-audit/workflow_audit.py --include-caller
```

Exit code is `1` when any check reports a finding, `0` when clean, so it can
gate a job. It is **not** wired into CI — run it after touching workflows, or
add it to a job if you want it enforced.

Scanned by default: `.github/workflows/`, `.github/actions/*/action.yml` and
`github/workflows/examples/`. Override with `--path` (repeatable).

## Checks

| Check | Finds |
|-------|-------|
| `injection` | untrusted event data (issue/PR/comment text, fork branch names) or a git ref pasted into a `run:` body |
| `dispatch` | free-text `workflow_dispatch` inputs pasted into a `run:` body |
| `second-hop` | a step output built from untrusted text, re-pasted into a later `run:` body |
| `env-decls` | a `run:` body using `$VAR` that neither its step, its job, nor the workflow declares |
| `dup-env` | a step carrying two `env:` keys — GitHub rejects the workflow, PyYAML hides it |

### On the three trust levels

- **untrusted** — a fork PR author, an issue or comment author, or whoever
  names a branch controls this. Always gating.
- **semi-trusted** — anyone who can push a branch or tag. Git allows
  ``$ ` ; | & ( )`` in ref names, so these are gating too.
- **caller** — supplied by the calling workflow, which is another file in a
  repository you trust. Advisory only, shown with `--include-caller`; expect
  four figures in a template repository.

### Why `dispatch` is separate from `injection`

`inputs.x` is caller-controlled for `workflow_call` but **free text typed into
the Actions UI** for `workflow_dispatch`. Treating the two alike is what let a
confirmed injection through here: a `custom-version` of
`$(id)` executed on a `workflow_dispatch`-only workflow. Inputs typed
`choice`, `boolean` or `environment` are constrained by GitHub and are not
reported.

### Why `second-hop` exists

Routing an input through `env:` protects the step that *reads* it. If that step
then writes the value verbatim to `$GITHUB_OUTPUT` and a later step pastes
`${{ steps.x.outputs.y }}` into its script, the injection returns one hop
downstream. Guard the value where it is produced — one check per value instead
of one per consumer, and it stays correct when a consumer is added later:

```bash
if [[ ! "$VERSION" =~ ^[A-Za-z0-9._+-]+$ ]]; then
  echo "::error::not a plain version string"; exit 1
fi
```

The check stays quiet once such a guard is present in the producing step.

## What it does not do

- It does not model step ordering for `$GITHUB_ENV`, so a name exported
  anywhere in a file counts as available everywhere in it. That errs toward
  silence rather than noise.
- `caller` findings are advisory by design. A reusable workflow cannot know
  what its callers pass; judging those is a human call.
- It reads YAML, not shell semantics. A value laundered through a construct it
  does not model will not be reported.

## Tests

```bash
python tools/workflow-audit/tests/test_workflow_audit.py   # no pytest needed
pytest tools/workflow-audit/tests/                          # also works
```

Every case is taken from a defect that actually shipped in this repository, and
each check is asserted both ways — it fires on the vulnerable fixture and stays
quiet on the fixed one. A checker reporting zero findings proves nothing unless
it is also shown to fire on the real defect.
