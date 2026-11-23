"""Tests for deploy_automations.

The deploy tool writes callers that point at templates of this repository.
It rotted unnoticed: profiles named removed workflows and repository-internal
ones without a workflow_call trigger, and every generated caller passed an
input no template declares - GitHub rejected all of them. The registry cases
below run against the real templates, so a template rename, removal or new
required input fails here instead of in somebody else's repository.

Run:  python tools/tests/test_deploy_automations.py   (no pytest required)
      pytest tools/tests/                            (also works)
"""
from __future__ import annotations

import shutil
import sys
import tempfile
from pathlib import Path

import yaml

TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS))

import deploy_automations as da  # noqa: E402

JOB = "delegate-to-automation-templates"


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def repo_with(files: dict) -> Path:
    """A throwaway directory laid out like the repository."""
    root = Path(tempfile.mkdtemp(prefix="deploy-"))
    files = {"tools/deploy-config.yml": "profiles: {}\nworkflows: {}\nactions: {}\n", **files}
    for rel, text in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return root


def deployer(root: Path) -> da.AutomationDeployer:
    return da.AutomationDeployer(da.DeploymentConfig(root / "tools/deploy-config.yml"), root)


def caller_job(text: str) -> dict:
    return yaml.safe_load(text)["jobs"][JOB]


def real_deployer() -> da.AutomationDeployer:
    return deployer(TOOLS.parent)


# --------------------------------------------------------------------------
# the real registry
# --------------------------------------------------------------------------
def case_every_registry_workflow_generates_a_valid_caller():
    dep = real_deployer()
    cfg = dep.config
    names = set(cfg.config.get("workflows", {}))
    for profile in cfg.list_profiles():
        names |= set(cfg.get_profile(profile).get("workflows", []))
    assert names, "registry lists no workflows"
    for name in sorted(names):
        file = dep.resolve_workflow(name)  # raises for missing / not reusable
        call = da.workflow_triggers(dep._workflow_doc(file))["workflow_call"] or {}
        declared = call.get("inputs") or {}
        job = caller_job(dep.generate_workflow(name))
        passed = set(job.get("with") or {})
        unknown = passed - set(declared)
        assert not unknown, f"{name}: passes undeclared inputs {sorted(unknown)}"
        required = {n for n, s in declared.items()
                    if isinstance(s, dict) and s.get("required") is True and "default" not in s}
        assert required <= passed, f"{name}: misses required inputs {sorted(required - passed)}"
        for scope, level in dep.required_permissions(file).items():
            granted = job["permissions"].get(scope, "none")
            assert da.PERMISSION_LEVEL[granted] >= da.PERMISSION_LEVEL[level], \
                f"{name}: grants {scope}: {granted}, template needs {level}"


def case_every_registry_action_exists():
    dep = real_deployer()
    cfg = dep.config
    names = set(cfg.config.get("actions", {}))
    for profile in cfg.list_profiles():
        names |= set(cfg.get_profile(profile).get("actions", []))
    for name in sorted(names):
        dep.generate_action_reference(name)  # raises when the action is gone


# --------------------------------------------------------------------------
# generator rules, on fixtures
# --------------------------------------------------------------------------
def case_permissions_include_nested_calls():
    root = repo_with({
        ".github/workflows/outer.yml": """
on: {workflow_call: {}}
jobs:
  build:
    permissions: {contents: write}
    runs-on: ubuntu-latest
    steps: [{run: "true"}]
  nested:
    uses: ./.github/workflows/inner.yml
  pinned:
    permissions: {issues: write}
    uses: bauer-group/automation-templates/.github/workflows/third.yml@main
""",
        ".github/workflows/inner.yml": """
on: {workflow_call: {}}
jobs:
  sign:
    permissions: {id-token: write, packages: read}
    runs-on: ubuntu-latest
    steps: [{run: "true"}]
""",
        # Called from a job with its own grant: that grant caps it, so its
        # requests do not reach the outer caller.
        ".github/workflows/third.yml": """
on: {workflow_call: {}}
jobs:
  x:
    permissions: {actions: write}
    runs-on: ubuntu-latest
    steps: [{run: "true"}]
""",
    })
    try:
        got = deployer(root).required_permissions("outer.yml")
        assert got == {"contents": "write", "id-token": "write", "packages": "read",
                       "issues": "write"}, got
        perms = caller_job(deployer(root).generate_workflow("outer"))["permissions"]
        assert perms == got, perms
    finally:
        shutil.rmtree(root)


def case_contents_read_is_the_floor():
    root = repo_with({".github/workflows/plain.yml": """
on: {workflow_call: {}}
jobs:
  x: {runs-on: ubuntu-latest, steps: [{run: "true"}]}
"""})
    try:
        perms = caller_job(deployer(root).generate_workflow("plain"))["permissions"]
        assert perms == {"contents": "read"}, perms
    finally:
        shutil.rmtree(root)


def case_only_declared_inputs_are_passed():
    root = repo_with({".github/workflows/inputs.yml": """
on:
  workflow_call:
    inputs:
      image-name: {type: string, required: true, description: "Image to build"}
      push: {type: boolean, required: true}
      platforms: {type: string, required: false}
      tag: {type: string, required: true, default: latest}
jobs:
  x: {runs-on: ubuntu-latest, steps: [{run: "true"}]}
"""})
    try:
        text = deployer(root).generate_workflow("inputs")
        assert caller_job(text)["with"] == {"image-name": "", "push": False}, text
        assert "# TODO: required - Image to build" in text, text
        assert "repository-name" not in text
    finally:
        shutil.rmtree(root)


def case_registry_file_is_used():
    root = repo_with({
        "tools/deploy-config.yml": """
profiles: {}
workflows:
  release: {file: "modules-release.yml"}
actions: {}
""",
        ".github/workflows/modules-release.yml": """
on: {workflow_call: {}}
jobs:
  x: {runs-on: ubuntu-latest, steps: [{run: "true"}]}
""",
    })
    try:
        uses = caller_job(deployer(root).generate_workflow("release"))["uses"]
        assert uses == f"{da.TEMPLATE_REPO}/.github/workflows/modules-release.yml@main", uses
    finally:
        shutil.rmtree(root)


def _raises(fn, needle: str):
    try:
        fn()
    except ValueError as exc:
        assert needle in str(exc), str(exc)
    else:
        raise AssertionError(f"no ValueError mentioning {needle!r}")


def case_non_reusable_and_missing_workflows_are_rejected():
    root = repo_with({".github/workflows/internal.yml": """
on: {push: {branches: [main]}}
jobs:
  x: {runs-on: ubuntu-latest, steps: [{run: "true"}]}
"""})
    try:
        _raises(lambda: deployer(root).generate_workflow("internal"), "workflow_call")
        _raises(lambda: deployer(root).generate_workflow("gone"), "does not exist")
    finally:
        shutil.rmtree(root)


def case_action_wrapper_mirrors_inputs_and_outputs():
    root = repo_with({".github/actions/notify/action.yml": """
name: notify
description: test
inputs:
  token: {description: Token, required: true}
  level: {description: Level, required: false, default: errors-only}
  webhook: {description: Old, deprecationMessage: use token}
outputs:
  sent: {description: Sent, value: "${{ steps.s.outputs.sent }}"}
runs:
  using: composite
  steps: [{id: s, shell: bash, run: "true"}]
"""})
    try:
        wrapper = yaml.safe_load(deployer(root).generate_action_reference("notify"))
        assert set(wrapper["inputs"]) == {"token", "level"}, wrapper["inputs"]
        assert wrapper["inputs"]["level"]["default"] == "errors-only"
        assert wrapper["inputs"]["token"]["required"] is True
        step = wrapper["runs"]["steps"][0]
        assert step["uses"] == f"{da.TEMPLATE_REPO}/.github/actions/notify@main", step
        assert step["with"] == {"token": "${{ inputs.token }}", "level": "${{ inputs.level }}"}, step
        assert wrapper["outputs"]["sent"]["value"] == "${{ steps.central.outputs.sent }}"
        _raises(lambda: deployer(root).generate_action_reference("gone"), "does not exist")
    finally:
        shutil.rmtree(root)


CASES = [
    ("every registry workflow resolves to a reusable template and gets a valid caller",
     case_every_registry_workflow_generates_a_valid_caller),
    ("every registry action exists", case_every_registry_action_exists),
    ("permissions include nested calls, capped where a job sets its own",
     case_permissions_include_nested_calls),
    ("contents: read is granted even when the template asks for nothing",
     case_contents_read_is_the_floor),
    ("only declared inputs are passed, required ones as placeholders",
     case_only_declared_inputs_are_passed),
    ("the registry's file is called, not the registry key",
     case_registry_file_is_used),
    ("non-reusable and missing workflows are rejected",
     case_non_reusable_and_missing_workflows_are_rejected),
    ("action wrappers mirror inputs and outputs, without deprecated inputs",
     case_action_wrapper_mirrors_inputs_and_outputs),
]


def main() -> int:
    passed = failed = 0
    print("Testing deploy_automations\n")
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
