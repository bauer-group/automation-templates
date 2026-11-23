"""Tests for deploy_automations.

The deploy tool writes callers that point at templates of this repository.
It rotted unnoticed: profiles named removed workflows and repository-internal
ones without a workflow_call trigger, and every generated caller passed an
input no template declares - GitHub rejected all of them.

The registry cases run against the real templates. They fail when a registry
entry points at a template that is gone or lost its workflow_call trigger, at
an action that is gone, or at a template whose jobs run with the caller's
grant without the registry saying what that grant must be. They do not catch
a template gaining a new required input: the generator fills that in with a
placeholder, and callers generated earlier are static files elsewhere that no
test here can see.

The generator rules (permission union, inputs, trigger forms) are pinned by
fixtures with known answers - the registry cases cannot check those, because
their only oracle would be the generator's own functions.

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
PLAIN_JOB = 'x: {runs-on: ubuntu-latest, steps: [{run: "true"}]}'


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


def registry_names(dep: da.AutomationDeployer, kind: str) -> set:
    cfg = dep.config
    names = set(cfg.config.get(kind, {}))
    for profile in cfg.list_profiles():
        names |= set(cfg.get_profile(profile).get(kind, []))
    return names


def _raises(fn, needle: str):
    try:
        fn()
    except ValueError as exc:
        assert needle in str(exc), str(exc)
    else:
        raise AssertionError(f"no ValueError mentioning {needle!r}")


# --------------------------------------------------------------------------
# the real registry
# --------------------------------------------------------------------------
def case_every_registry_workflow_generates_a_caller():
    dep = real_deployer()
    names = registry_names(dep, "workflows")
    assert names, "registry lists no workflows"
    for name in sorted(names):
        file = dep.resolve_workflow(name)  # raises for missing / not reusable
        declared = (da.workflow_triggers(dep._workflow_doc(file))["workflow_call"] or {}).get("inputs") or {}
        passed = set(caller_job(dep.generate_workflow(name)).get("with") or {})
        unknown = passed - set(declared)
        assert not unknown, f"{name}: passes undeclared inputs {sorted(unknown)}"


def case_registry_states_the_grant_for_inheriting_jobs():
    # Jobs without a permissions block run with the caller's grant; what they
    # need cannot be read from the template, so the registry has to say it.
    dep = real_deployer()
    workflows = dep.config.config.get("workflows", {})
    missing = []
    for name in sorted(registry_names(dep, "workflows")):
        inheriting = dep.inheriting_jobs(dep.resolve_workflow(name))
        if inheriting and (workflows.get(name) or {}).get("caller_permissions") is None:
            missing.append(f"{name} ({', '.join(inheriting)})")
    assert not missing, "set caller_permissions in tools/deploy-config.yml for: " + "; ".join(missing)


def case_every_registry_action_exists():
    dep = real_deployer()
    for name in sorted(registry_names(dep, "actions")):
        dep.action_usage(name)  # raises when the action is gone


# --------------------------------------------------------------------------
# generator rules, on fixtures
# --------------------------------------------------------------------------
def case_permissions_union_follows_every_level():
    root = repo_with({
        ".github/workflows/outer.yml": """
on: {workflow_call: {}}
jobs:
  build:
    permissions: {contents: write}
    runs-on: ubuntu-latest
    steps: [{run: "true"}]
  local-form:
    uses: ./.github/workflows/inner.yml
  full-form:
    uses: bauer-group/automation-templates/.github/workflows/quality.yml@main
  capped:
    permissions: {issues: write}
    uses: bauer-group/automation-templates/.github/workflows/capped.yml@main
""",
        ".github/workflows/inner.yml": """
on: {workflow_call: {}}
jobs:
  sign:
    permissions: {id-token: write, packages: read}
    runs-on: ubuntu-latest
    steps: [{run: "true"}]
""",
        # Workflow-level block only, reached through the full repository form -
        # the shape python-build and nodejs-build use for modules-code-quality.
        ".github/workflows/quality.yml": f"""
on: {{workflow_call: {{}}}}
permissions: {{contents: read, pull-requests: write}}
jobs:
  {PLAIN_JOB}
""",
        # Called from a job with its own grant: that grant caps it, so its
        # requests do not reach the outer caller.
        ".github/workflows/capped.yml": """
on: {workflow_call: {}}
jobs:
  x:
    permissions: {actions: write}
    runs-on: ubuntu-latest
    steps: [{run: "true"}]
""",
    })
    try:
        expected = {"contents": "write", "id-token": "write", "packages": "read",
                    "pull-requests": "write", "issues": "write"}
        got = deployer(root).required_permissions("outer.yml")
        assert got == expected, got
        perms = caller_job(deployer(root).generate_workflow("outer"))["permissions"]
        assert perms == expected, perms
    finally:
        shutil.rmtree(root)


def case_workflow_level_permissions_count():
    root = repo_with({".github/workflows/top.yml": f"""
on: {{workflow_call: {{}}}}
permissions: {{contents: write, issues: write}}
jobs:
  {PLAIN_JOB}
"""})
    try:
        perms = caller_job(deployer(root).generate_workflow("top"))["permissions"]
        assert perms == {"contents": "write", "issues": "write"}, perms
    finally:
        shutil.rmtree(root)


def case_inheriting_jobs_get_the_registry_grant():
    template = f"""
on: {{workflow_call: {{}}}}
jobs:
  {PLAIN_JOB}
"""
    with_grant = repo_with({
        "tools/deploy-config.yml": """
profiles: {}
workflows:
  cleanup:
    file: cleanup.yml
    caller_permissions: {contents: write, actions: write}
    permissions_note: Opt-in publishing also needs packages write.
actions: {}
""",
        ".github/workflows/cleanup.yml": template,
    })
    without = repo_with({".github/workflows/plain.yml": template})
    try:
        text = deployer(with_grant).generate_workflow("cleanup")
        assert caller_job(text)["permissions"] == {"contents": "write", "actions": "write"}, text
        assert "# Opt-in publishing also needs packages write." in text, text
        assert "TODO" not in text, text
        # No registry grant: contents: read as the floor, and a TODO saying so.
        text = deployer(without).generate_workflow("plain")
        assert caller_job(text)["permissions"] == {"contents": "read"}, text
        assert "# TODO: they may need more" in text, text
    finally:
        shutil.rmtree(with_grant)
        shutil.rmtree(without)


def case_only_declared_inputs_are_passed():
    root = repo_with({".github/workflows/inputs.yml": f"""
on:
  workflow_call:
    inputs:
      image-name: {{type: string, required: true, description: "Image to build"}}
      push: {{type: boolean, required: true}}
      platforms: {{type: string, required: false}}
      tag: {{type: string, required: true, default: latest}}
jobs:
  {PLAIN_JOB}
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
        ".github/workflows/modules-release.yml": f"on: {{workflow_call: {{}}}}\njobs:\n  {PLAIN_JOB}\n",
    })
    try:
        uses = caller_job(deployer(root).generate_workflow("release"))["uses"]
        assert uses == f"{da.TEMPLATE_REPO}/.github/workflows/modules-release.yml@main", uses
    finally:
        shutil.rmtree(root)


def case_short_trigger_forms_are_reusable():
    root = repo_with({
        ".github/workflows/str.yml": f"on: workflow_call\njobs:\n  {PLAIN_JOB}\n",
        ".github/workflows/lst.yml": f"on: [workflow_call, workflow_dispatch]\njobs:\n  {PLAIN_JOB}\n",
    })
    try:
        for name in ("str", "lst"):
            assert caller_job(deployer(root).generate_workflow(name))["uses"].endswith(f"/{name}.yml@main")
    finally:
        shutil.rmtree(root)


def case_non_reusable_and_missing_workflows_are_rejected():
    root = repo_with({
        ".github/workflows/internal.yml": f"on: {{push: {{branches: [main]}}}}\njobs:\n  {PLAIN_JOB}\n",
        ".github/workflows/listed.yml": f"on: [push, pull_request]\njobs:\n  {PLAIN_JOB}\n",
    })
    try:
        _raises(lambda: deployer(root).generate_workflow("internal"), "workflow_call")
        _raises(lambda: deployer(root).generate_workflow("listed"), "workflow_call")
        _raises(lambda: deployer(root).generate_workflow("gone"), "does not exist")
    finally:
        shutil.rmtree(root)


def case_read_all_and_write_all_are_rejected():
    # Their scope set changes as GitHub adds and retires scopes; any list
    # here would go stale and grant less than the template requests.
    root = repo_with({
        ".github/workflows/ra.yml": f"on: workflow_call\npermissions: read-all\njobs:\n  {PLAIN_JOB}\n",
        ".github/workflows/wa.yml": """
on: workflow_call
jobs:
  x:
    permissions: write-all
    runs-on: ubuntu-latest
    steps: [{run: "true"}]
""",
    })
    try:
        _raises(lambda: deployer(root).generate_workflow("ra"), "read-all")
        _raises(lambda: deployer(root).generate_workflow("wa"), "write-all")
    finally:
        shutil.rmtree(root)


def case_actions_are_referenced_directly():
    root = repo_with({".github/actions/notify/action.yml": """
name: notify
description: test
inputs:
  token: {description: GitHub token, required: true}
  level: {description: Level, required: false, default: errors-only}
  event: {description: Event, required: true, default: push}
runs:
  using: composite
  steps: [{shell: bash, run: "true"}]
"""})
    try:
        step = yaml.safe_load(deployer(root).action_usage("notify"))[0]
        assert step["uses"] == f"{da.TEMPLATE_REPO}/.github/actions/notify@main", step
        # Only required inputs without a default - the rest keep the central
        # action's own defaults, which a copied value would freeze.
        assert step["with"] == {"token": ""}, step
        _raises(lambda: deployer(root).action_usage("gone"), "does not exist")
        assert not hasattr(da.AutomationDeployer, "generate_action_reference")
    finally:
        shutil.rmtree(root)


CASES = [
    ("every registry workflow resolves to a reusable template and gets a caller",
     case_every_registry_workflow_generates_a_caller),
    ("the registry states the grant for templates whose jobs inherit it",
     case_registry_states_the_grant_for_inheriting_jobs),
    ("every registry action exists", case_every_registry_action_exists),
    ("permission union follows local and full-form nested calls, capped where a job sets its own",
     case_permissions_union_follows_every_level),
    ("a template's workflow-level permissions reach the caller",
     case_workflow_level_permissions_count),
    ("inheriting jobs get the registry grant, or a TODO without one",
     case_inheriting_jobs_get_the_registry_grant),
    ("only declared inputs are passed, required ones as placeholders",
     case_only_declared_inputs_are_passed),
    ("the registry's file is called, not the registry key",
     case_registry_file_is_used),
    ("on: workflow_call and on: [workflow_call, ...] count as reusable",
     case_short_trigger_forms_are_reusable),
    ("non-reusable and missing workflows are rejected",
     case_non_reusable_and_missing_workflows_are_rejected),
    ("read-all and write-all templates are rejected, not guessed",
     case_read_all_and_write_all_are_rejected),
    ("actions are referenced directly, with only required inputs",
     case_actions_are_referenced_directly),
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
