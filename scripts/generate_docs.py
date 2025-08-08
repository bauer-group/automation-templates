#!/usr/bin/env python3
import os, yaml
from pathlib import Path

ORG = os.environ.get("ORG", "bauer-group")
REPO = os.environ.get("REPO", "automation-templates")
WF_DIR = Path(".github/workflows")

def parse_workflow(path: Path):
    data = yaml.safe_load(path.read_text())
    name = data.get("name", path.name)
    call = (data.get("on") or {}).get("workflow_call", {})
    inputs = (call.get("inputs") or {})
    secrets = (call.get("secrets") or {})
    return {
        "file": path.name,
        "name": name,
        "inputs": {k: {
            "type": v.get("type","string"),
            "required": bool(v.get("required", False)),
            "default": v.get("default", None),
            "description": v.get("description","").strip()
        } for k,v in inputs.items()},
        "secrets": {k: {
            "required": bool(v.get("required", False)),
            "description": v.get("description","").strip()
        } for k,v in secrets.items()}
    }

def render_usage(workflows):
    lines = ["# Usage","","This document is auto-generated. Do not edit manually.",""]
    for wf in workflows:
        lines += [f"## {wf['name']} (`{wf['file']}`)","","### How to use","```yaml",
                  f"jobs:",
                  f"  example:",
                  f"    uses: {ORG}/{REPO}/.github/workflows/{wf['file']}@v1"]
        if wf['inputs']:
            lines += ["    with:"]
            for k,v in wf['inputs'].items():
                default = v['default']
                sample = "true" if v['type']=="boolean" else (str(default) if default is not None else "<value>")
                lines += [f"      {k}: {sample}"]
        if wf['secrets']:
            lines += ["    secrets:"]
            for k,_ in wf['secrets'].items():
                lines += [f"      {k}: ${{{{ secrets.{k} }}}}"]
        lines += ["```",""]
    return "\n".join(lines)

def render_readme(workflows):
    lines = ["# Automation Templates","","Centralized, reusable CI/CD workflow templates for GitHub Actions across all BAUER GROUP projects.","",
             "> This README is auto-generated. Do not edit manually.","","## Available Workflows","","| Workflow | File |","|----------|------|"]
    for wf in workflows:
        lines += [f"| {wf['name']} | `.github/workflows/{wf['file']}` |"]
    return "\n".join(lines)

def main():
    workflows = []
    for path in sorted(WF_DIR.glob("*.yml")):
        if path.name in ("docs-autogen.yml","release-please.yml"):
            continue
        workflows.append(parse_workflow(path))
    Path("docs").mkdir(exist_ok=True)
    Path("README.md").write_text(render_readme(workflows))
    Path("docs/usage.md").write_text(render_usage(workflows))

if __name__ == "__main__":
    main()
