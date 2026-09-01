"""Tests for workflow_audit.

Each check is asserted against a fixture that IS vulnerable and one that is
not. A checker reporting zero findings proves nothing unless it is also shown
to fire on the real defect - every case here is taken from a bug that actually
shipped in this repository.

Run:  python tests/test_workflow_audit.py     (no pytest required)
      pytest tests/                           (also works)
"""
from __future__ import annotations

import io
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import workflow_audit as wa  # noqa: E402


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
class Repo:
    """A throwaway directory laid out like the repository."""

    def __init__(self) -> None:
        self.root = tempfile.mkdtemp(prefix="wfaudit-")
        os.makedirs(os.path.join(self.root, ".github/workflows"))

    def write(self, rel_path: str, text: str) -> None:
        full = os.path.join(self.root, rel_path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        io.open(full, "w", encoding="utf-8", newline="\n").write(text)

    def files(self):
        return wa.iter_files(self.root, wa.DEFAULT_PATHS)

    def close(self) -> None:
        shutil.rmtree(self.root, ignore_errors=True)


VULNERABLE_DISPATCH = """\
name: t
on:
  workflow_dispatch:
    inputs:
      custom-version:
        type: string
      bump:
        type: choice
        options: [major, minor]
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - id: version
        run: |
          if [ -n "${{ inputs.custom-version }}" ]; then
            V="${{ inputs.custom-version }}"
          fi
          echo "v=$V" >> "$GITHUB_OUTPUT"
"""

SAFE_DISPATCH = """\
name: t
on:
  workflow_dispatch:
    inputs:
      custom-version:
        type: string
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - id: version
        env:
          INPUT_CUSTOM_VERSION: ${{ inputs.custom-version }}
        run: |
          if [ -n "$INPUT_CUSTOM_VERSION" ]; then
            V="$INPUT_CUSTOM_VERSION"
          fi
          if [[ ! "$V" =~ ^[A-Za-z0-9._+-]+$ ]]; then exit 1; fi
          echo "v=$V" >> "$GITHUB_OUTPUT"
"""

VULNERABLE_INJECTION = """\
name: t
on: [issues]
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "Title: ${{ github.event.issue.title }}"
"""

SAFE_INJECTION = """\
name: t
on: [issues]
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - env:
          ISSUE_TITLE: ${{ github.event.issue.title }}
        run: |
          echo "Title: $ISSUE_TITLE"
"""

# the expression sits in if:, which is a YAML context and must NOT be reported
SAFE_YAML_CONTEXT = """\
name: t
on: [push]
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - if: github.ref_name == 'main'
        with:
          tag: ${{ github.ref_name }}
        run: |
          echo hello
"""

VULNERABLE_SECOND_HOP = """\
name: t
on:
  workflow_dispatch:
    inputs:
      v:
        type: string
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - id: mk
        env:
          INPUT_V: ${{ inputs.v }}
        run: |
          VER="$INPUT_V"
          echo "ver=$VER" >> "$GITHUB_OUTPUT"
      - run: |
          TARGET="${{ steps.mk.outputs.ver }}"
          echo "$TARGET"
"""

SAFE_SECOND_HOP = """\
name: t
on:
  workflow_dispatch:
    inputs:
      v:
        type: string
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - id: mk
        env:
          INPUT_V: ${{ inputs.v }}
        run: |
          VER="$INPUT_V"
          if [[ ! "$VER" =~ ^[A-Za-z0-9._+-]+$ ]]; then exit 1; fi
          echo "ver=$VER" >> "$GITHUB_OUTPUT"
      - run: |
          TARGET="${{ steps.mk.outputs.ver }}"
          echo "$TARGET"
"""

DUP_ENV = """\
name: t
on: [push]
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - name: s
        env:
          A: '1'
        run: |
          echo "$A $B"
        env:
          B: '2'
"""

MISSING_ENV = """\
name: t
on: [push]
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - name: s
        run: |
          echo "$SOME_VALUE"
"""

# job-level env is inherited; must NOT be reported
JOB_LEVEL_ENV = """\
name: t
on: [push]
jobs:
  j:
    runs-on: ubuntu-latest
    env:
      SOME_VALUE: x
    steps:
      - name: s
        run: |
          echo "$SOME_VALUE"
"""

# ${VAR:-} says "may be unset" on purpose; must NOT be reported
DEFAULTED_ENV = """\
name: t
on: [push]
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - name: s
        run: |
          echo "${SOME_VALUE:-}"
"""


# --------------------------------------------------------------------------
# cases
# --------------------------------------------------------------------------
def case_dispatch_fires():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", VULNERABLE_DISPATCH)
        f = wa.check_dispatch(r.root, r.files())
        assert len(f) >= 2, f"expected the free-text input to be reported, got {len(f)}"
        assert all("custom-version" in x.detail for x in f)
        # `bump` is a choice, so GitHub constrains it and it must not be reported
        assert not any("bump" in x.detail for x in f)
    finally:
        r.close()


def case_dispatch_quiet_when_fixed():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", SAFE_DISPATCH)
        assert wa.check_dispatch(r.root, r.files()) == []
    finally:
        r.close()


def case_injection_fires():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", VULNERABLE_INJECTION)
        gating, _ = wa.check_injection(r.root, r.files(), False)
        assert len(gating) == 1, f"expected 1 finding, got {len(gating)}"
        assert "issue text" in gating[0].detail
    finally:
        r.close()


def case_injection_quiet_when_fixed():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", SAFE_INJECTION)
        gating, _ = wa.check_injection(r.root, r.files(), False)
        assert gating == [], f"unexpected: {[str(x) for x in gating]}"
    finally:
        r.close()


def case_injection_ignores_yaml_contexts():
    """if:/with: are not shell. Rewriting them breaks the workflow."""
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", SAFE_YAML_CONTEXT)
        gating, _ = wa.check_injection(r.root, r.files(), False)
        assert gating == [], f"YAML context reported: {[str(x) for x in gating]}"
    finally:
        r.close()


def case_second_hop_fires():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", VULNERABLE_SECOND_HOP)
        f = wa.check_second_hop(r.root, r.files())
        assert len(f) == 1, f"expected 1 finding, got {len(f)}"
        assert "ver" in f[0].detail
    finally:
        r.close()


def case_second_hop_quiet_when_guarded():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", SAFE_SECOND_HOP)
        f = wa.check_second_hop(r.root, r.files())
        assert f == [], f"guarded value still reported: {[str(x) for x in f]}"
    finally:
        r.close()


def case_dup_env_fires():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", DUP_ENV)
        f = wa.check_dup_env(r.root, r.files())
        assert len(f) == 1, f"expected 1 finding, got {len(f)}"
    finally:
        r.close()


def case_env_decls_fires():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", MISSING_ENV)
        f = wa.check_env_decls(r.root, r.files())
        assert len(f) == 1, f"expected 1 finding, got {len(f)}"
        assert "SOME_VALUE" in f[0].detail
    finally:
        r.close()


def case_env_decls_honours_job_level_env():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", JOB_LEVEL_ENV)
        f = wa.check_env_decls(r.root, r.files())
        assert f == [], f"job-level env not honoured: {[str(x) for x in f]}"
    finally:
        r.close()


def case_env_decls_honours_default_idiom():
    r = Repo()
    try:
        r.write(".github/workflows/a.yml", DEFAULTED_ENV)
        f = wa.check_env_decls(r.root, r.files())
        assert f == [], f"${{VAR:-}} reported: {[str(x) for x in f]}"
    finally:
        r.close()


CASES = [
    ("a free-text workflow_dispatch input in a shell body is reported",
     case_dispatch_fires),
    ("the same input routed through env: is not reported",
     case_dispatch_quiet_when_fixed),
    ("untrusted event data in a shell body is reported", case_injection_fires),
    ("the same data routed through env: is not reported",
     case_injection_quiet_when_fixed),
    ("an expression in if:/with: is never reported",
     case_injection_ignores_yaml_contexts),
    ("an output built from an input and re-pasted downstream is reported",
     case_second_hop_fires),
    ("the same output is not reported once the value is validated",
     case_second_hop_quiet_when_guarded),
    ("a step with two env: keys is reported", case_dup_env_fires),
    ("a run: body using an undeclared variable is reported", case_env_decls_fires),
    ("a variable from job-level env: is not reported",
     case_env_decls_honours_job_level_env),
    ("a variable used as ${VAR:-} is not reported",
     case_env_decls_honours_default_idiom),
]


def main() -> int:
    passed = failed = 0
    print("Testing workflow_audit\n")
    for desc, fn in CASES:
        try:
            fn()
        except AssertionError as exc:
            print(f"FAIL {desc}\n       {exc}")
            failed += 1
        except Exception as exc:  # pragma: no cover
            print(f"FAIL {desc}\n       unexpected {type(exc).__name__}: {exc}")
            failed += 1
        else:
            print(f"ok   {desc}")
            passed += 1
    print(f"\n{passed} passed, {failed} failed")
    return 1 if failed else 0


# pytest discovers these too
for _desc, _fn in CASES:
    globals()["test_" + _fn.__name__[len("case_"):]] = _fn

if __name__ == "__main__":
    sys.exit(main())
