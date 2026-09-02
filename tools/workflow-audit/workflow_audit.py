#!/usr/bin/env python3
"""Workflow Audit - static checks for script injection in GitHub Actions.

Siehe README für vollständige Beschreibung.

`${{ }}` expressions are substituted by the Actions runner BEFORE the shell
starts, so an expression inside a `run:` body is textual pasting, not a
variable. A value carrying a quote, a newline or a shell metacharacter
therefore executes. This tool finds the places where that can happen.

Five checks, each usable on its own:

  injection    untrusted event data pasted into a run: body
  dispatch     workflow_dispatch free-text inputs pasted into a run: body
  second-hop   a step output built from untrusted text, re-pasted downstream
  env-decls    a run: body using $VAR that its step never declares
  dup-env      a step carrying two `env:` keys

Exit code is 1 when any gating check reports a finding, so this can gate a
job if desired. `caller` findings are advisory and never gate.
"""
from __future__ import annotations

import argparse
import glob
import io
import json
import os
import re
import sys
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover
    print("[error] Paket 'PyYAML' fehlt. Installation: pip install -r requirements.txt",
          file=sys.stderr)
    raise

DEFAULT_PATHS = (
    ".github/workflows/*.yml",
    ".github/workflows/*.yaml",
    ".github/actions/*/action.yml",
    ".github/actions/*/action.yaml",
    "github/workflows/examples/*/*.yml",
    "github/workflows/examples/*/*.yaml",
)

EXPR = re.compile(r"\$\{\{(.*?)\}\}", re.S)
# `- run: |` is as valid as `run: |` on its own line; missing the dashed form
# would silently skip whole steps, so match both and take the indentation from
# where `run:` actually starts.
RUN_RE = re.compile(r"^(\s*)(?:-\s+)?run:\s*[|>][-+]?\s*$")
STEP_RE = re.compile(r"^(\s*)-\s")
KEY_RE = re.compile(r"^(\s*)([A-Za-z_][A-Za-z0-9_-]*):")

# Fully controlled by someone outside the repository: a fork PR author, an
# issue or comment author, whoever names a branch.
UNTRUSTED = [
    (r"github\.event\.issue\.(title|body)", "issue text"),
    (r"github\.event\.pull_request\.(title|body)", "pull request text"),
    (r"github\.event\.pull_request\.head\.(ref|label)", "fork branch name"),
    (r"github\.event\.comment\.body", "comment body"),
    (r"github\.event\.review\.body", "review body"),
    (r"github\.event\.discussion\.", "discussion field"),
    (r"github\.event\.head_commit\.(message|author)", "commit metadata"),
    (r"github\.event\.commits", "commit metadata"),
    (r"github\.event\.workflow_run\.(head_branch|head_commit|display_title)",
     "workflow_run metadata"),
    (r"github\.event\.release\.(body|name)", "release text"),
    (r"github\.head_ref", "fork branch name"),
]

# Controlled by anyone who can push a branch or tag, or trigger a run.
SEMI = [
    (r"github\.ref_name\b", "branch/tag name"),
    (r"github\.ref_type\b", "ref type"),
    (r"github\.ref\b", "git ref"),
]

# Supplied by the calling workflow. Advisory: for a reusable workflow the
# caller is another workflow file, which is as trusted as this repository.
CALLER = [(r"\binputs\.[A-Za-z0-9_-]+", "caller input")]

# Inputs whose type constrains them to a fixed set; GitHub validates these.
CONSTRAINED_TYPES = {"choice", "boolean", "environment"}


class Finding:
    def __init__(self, path: str, line: int, kind: str, detail: str,
                 context: str = "", step: str = "") -> None:
        self.path = path
        self.line = line
        self.kind = kind
        self.detail = detail
        self.context = context
        self.step = step

    def as_dict(self) -> Dict[str, Any]:
        return {
            "file": self.path, "line": self.line, "check": self.kind,
            "detail": self.detail, "step": self.step, "context": self.context,
        }

    def __str__(self) -> str:
        head = f"{self.path}:{self.line}"
        step = f"  [{self.step}]" if self.step else ""
        body = f"\n      {self.context}" if self.context else ""
        return f"{head}{step}\n      {self.detail}{body}"


# --------------------------------------------------------------------------
# file helpers
# --------------------------------------------------------------------------
def iter_files(root: str, patterns: Sequence[str]) -> List[str]:
    out: List[str] = []
    for pat in patterns:
        out.extend(glob.glob(os.path.join(root, pat)))
    return sorted(set(out))


def rel(root: str, path: str) -> str:
    return os.path.relpath(path, root).replace("\\", "/")


def load(path: str) -> Optional[Any]:
    try:
        return yaml.safe_load(io.open(path, encoding="utf-8"))
    except Exception:
        return None


def lines_of(path: str) -> List[str]:
    return io.open(path, encoding="utf-8", errors="replace").read().split("\n")


def run_blocks(path: str) -> Iterable[Tuple[int, int, List[str]]]:
    """Yield (run_line_index, body_start_index, body_lines) per run: block.

    Tracks block-scalar indentation rather than grepping, so an expression in
    `if:`, `with:`, `env:` or `name:` is never mistaken for one in a script.
    """
    lines = lines_of(path)
    for idx, line in enumerate(lines):
        if not RUN_RE.match(line):
            continue
        # column of `run:` itself, so `- run: |` ends at the next sibling key
        # rather than swallowing it
        key_indent = line.index("run:")
        i = idx + 1
        start = i
        while i < len(lines):
            if lines[i].strip() == "":
                i += 1
                continue
            if len(lines[i]) - len(lines[i].lstrip()) <= key_indent:
                break
            i += 1
        yield idx, start, lines[start:i]


def walk_steps(node: Any, out: List[Dict[str, Any]]) -> None:
    if isinstance(node, dict):
        if isinstance(node.get("run"), str):
            out.append(node)
        for value in node.values():
            walk_steps(value, out)
    elif isinstance(node, list):
        for value in node:
            walk_steps(value, out)


def triggers(doc: Any) -> Dict[str, Any]:
    if not isinstance(doc, dict):
        return {}
    # `on:` parses as the boolean True in YAML 1.1
    on = doc.get(True, doc.get("on"))
    if isinstance(on, dict):
        return on
    if isinstance(on, str):
        return {on: None}
    if isinstance(on, list):
        return {str(k): None for k in on}
    return {}


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------
def check_injection(root: str, files: Sequence[str], include_caller: bool
                    ) -> Tuple[List[Finding], List[Finding]]:
    """Untrusted / semi-trusted / caller expressions inside run: bodies."""
    gating: List[Finding] = []
    advisory: List[Finding] = []
    for path in files:
        r = rel(root, path)
        for _run_idx, start, body in run_blocks(path):
            for offset, text in enumerate(body):
                for match in EXPR.finditer(text):
                    expr = match.group(1).strip()
                    line = start + offset + 1
                    snippet = text.strip()[:100]
                    hit = False
                    for pattern, label in UNTRUSTED:
                        if re.search(pattern, expr):
                            gating.append(Finding(
                                r, line, "injection",
                                f"untrusted ({label}) in a shell body: {expr[:70]}",
                                snippet))
                            hit = True
                            break
                    if hit:
                        continue
                    for pattern, label in SEMI:
                        if re.search(pattern, expr):
                            gating.append(Finding(
                                r, line, "injection",
                                f"semi-trusted ({label}) in a shell body: {expr[:70]}",
                                snippet))
                            hit = True
                            break
                    if hit or not include_caller:
                        continue
                    for pattern, label in CALLER:
                        if re.search(pattern, expr):
                            advisory.append(Finding(
                                r, line, "injection",
                                f"caller input in a shell body: {expr[:70]}",
                                snippet))
                            break
    return gating, advisory


def check_dispatch(root: str, files: Sequence[str]) -> List[Finding]:
    """workflow_dispatch free-text inputs reaching a run: body.

    `inputs.x` is caller-controlled for workflow_call but free text typed into
    the Actions UI for workflow_dispatch. Missing that distinction is what let
    a confirmed injection through in this repository.
    """
    findings: List[Finding] = []
    for path in files:
        doc = load(path)
        on = triggers(doc)
        if "workflow_dispatch" not in on:
            continue
        spec = on.get("workflow_dispatch") or {}
        declared = (spec.get("inputs") or {}) if isinstance(spec, dict) else {}
        free = {
            name for name, meta in declared.items()
            if not isinstance(meta, dict) or meta.get("type") not in CONSTRAINED_TYPES
        }
        if not free:
            continue
        r = rel(root, path)
        for _run_idx, start, body in run_blocks(path):
            for offset, text in enumerate(body):
                for match in EXPR.finditer(text):
                    expr = match.group(1).strip()
                    # a ternary that only ever emits fixed literals is safe
                    if re.search(r"&&\s*'[^']*'\s*\|\|", expr):
                        continue
                    for name in sorted(free):
                        if re.search(rf"(?:inputs|github\.event\.inputs)\.{re.escape(name)}\b",
                                     expr):
                            findings.append(Finding(
                                r, start + offset + 1, "dispatch",
                                f"free-text workflow_dispatch input '{name}' in a shell body",
                                text.strip()[:100]))
                            break
    return findings


def check_second_hop(root: str, files: Sequence[str]) -> List[Finding]:
    """A step output built from untrusted text and re-pasted into a run: body.

    Routing an input through env: protects the step that reads it. If that
    step then writes the value verbatim to $GITHUB_OUTPUT and a later step
    pastes ${{ steps.x.outputs.y }} into its script, the injection returns.
    Guard the value where it is produced, or env: every consumer.
    """
    assign = re.compile(r'echo\s+"([A-Za-z0-9_-]+)=\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?"')
    local = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)="\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?"',
                       re.M)
    guard = re.compile(r'=~\s*\^|\bcase\s+"\$')
    ref = re.compile(r"\$\{\{\s*(?:steps\.[A-Za-z0-9_-]+\.outputs\.([A-Za-z0-9_-]+)"
                     r"|needs\.[A-Za-z0-9_-]+\.outputs\.([A-Za-z0-9_-]+))[^}]*\}\}")
    env_sourced = re.compile(r"\$\{\{\s*(?:inputs|github)\.")

    findings: List[Finding] = []
    for path in files:
        doc = load(path)
        if doc is None:
            continue
        steps: List[Dict[str, Any]] = []
        walk_steps(doc, steps)

        tainted: Dict[str, str] = {}
        for step in steps:
            body = step["run"]
            env = step.get("env") or {}
            # variables the step imports from an expression
            imported = {
                key for key, value in env.items()
                if isinstance(value, str) and env_sourced.search(value)
            }
            if not imported:
                continue
            aliases = dict(local.findall(body))
            for key, var in assign.findall(body):
                origin = var if var in imported else aliases.get(var)
                if origin in imported or (origin and origin in imported):
                    # a validated value cannot carry a metacharacter downstream
                    if guard.search(body):
                        continue
                    tainted[key] = var
        if not tainted:
            continue

        r = rel(root, path)
        for _run_idx, start, block in run_blocks(path):
            for offset, text in enumerate(block):
                for match in ref.finditer(text):
                    key = match.group(1) or match.group(2)
                    if key in tainted:
                        findings.append(Finding(
                            r, start + offset + 1, "second-hop",
                            f"output '{key}' carries unvalidated input "
                            f"(${tainted[key]}) and is pasted into a shell body",
                            text.strip()[:100]))
    return findings


def check_env_decls(root: str, files: Sequence[str]) -> List[Finding]:
    """A run: body using $VAR whose step never declares it.

    Catches the classic refactor slip: the expression is moved out of the
    script but the env: entry is added to the wrong step, so the variable
    silently expands to nothing.
    """
    # Every shape that binds a name in bash. Deliberately not anchored to the
    # start of a line: bash binds names after `if !`, after `then`, inside a
    # case branch and after `;`, and anchoring missed all four.
    assigned = re.compile(
        r"(?:^|[;&|(){}!]|\b(?:then|else|elif|do|local|export|readonly|declare)\b|\s)"
        r"\s*([A-Z_][A-Z0-9_]*)=(?!=)|"
        r"\bread\s+(?:-\w+\s+)*(?:-d\s+\S+\s+)*([A-Z_][A-Z0-9_ ]*)|"
        r"\bfor\s+([A-Z_][A-Z0-9_]*)\s+in\b|"
        r"\bmapfile\s+(?:-\w+\s+)*([A-Z_][A-Z0-9_]*)",
        re.M)
    # `\$FOO` is an escaped literal (e.g. the search half of ${VAR//\$FOO/...}),
    # not a variable read, so require the $ not be backslash-escaped.
    used = re.compile(r"(?<!\\)\$\{?([A-Z][A-Z0-9_]{2,})\}?")
    # ${FOO:-}, ${FOO-x}, ${FOO:=x}, ${FOO:?x}: the author has said in the code
    # that the name may be unset, so an absent declaration is deliberate.
    defaulted = re.compile(r"(?<!\\)\$\{([A-Z][A-Z0-9_]{2,}):?[-=?+]")
    comment = re.compile(r"^\s*#.*$", re.M)
    # written to $GITHUB_ENV, so available to every LATER step in the same file
    to_github_env = re.compile(
        r'(?:echo|printf)[^\n]*?["\x27]?([A-Z_][A-Z0-9_]*)=[^\n]*>>\s*"?\$\{?GITHUB_ENV|'
        r'^\s*echo\s+"([A-Z_][A-Z0-9_]*)<<', re.M)
    # variables the runner or the shell provides
    builtin = {
        "HOME", "PATH", "PWD", "OLDPWD", "USER", "SHELL", "TMPDIR", "RANDOM",
        "IFS", "PIPESTATUS", "BASH_VERSION", "BASH_REMATCH", "BASH_SOURCE",
        "FUNCNAME", "LINENO", "SECONDS", "REPLY", "HOSTNAME", "LANG", "LC_ALL",
        "PS1", "PS2", "PS4", "OSTYPE", "MACHTYPE", "EDITOR", "TERM", "CI",
        "SHLVL", "UID", "EUID", "PPID", "COLUMNS", "LINES", "SHELLOPTS",
    }
    findings: List[Finding] = []
    for path in files:
        doc = load(path)
        if doc is None:
            continue
        steps: List[Dict[str, Any]] = []
        walk_steps(doc, steps)
        r = rel(root, path)
        # a name exported to GITHUB_ENV anywhere in the file is reachable later;
        # ordering is not modelled, which keeps this check quiet rather than noisy
        exported: set = set()
        for step in steps:
            for groups in to_github_env.findall(step["run"]):
                exported.update(g for g in groups if g)
        # workflow-level and job-level env: are inherited by every step
        if isinstance(doc, dict):
            if isinstance(doc.get("env"), dict):
                exported.update(doc["env"].keys())
            for job in (doc.get("jobs") or {}).values() if isinstance(
                    doc.get("jobs"), dict) else []:
                if isinstance(job, dict) and isinstance(job.get("env"), dict):
                    exported.update(job["env"].keys())
        for step in steps:
            # a variable named in a comment is documentation, not a use
            body = comment.sub("", step["run"])
            env = set((step.get("env") or {}).keys())
            bound = {g for groups in assigned.findall(body) for g in groups if g}
            # `read A B C` binds several names at once
            bound = {n for chunk in bound for n in chunk.split()}
            bound |= set(defaulted.findall(body))
            missing = sorted({
                name for name in used.findall(body)
                if name not in env and name not in bound and name not in exported
                and name not in builtin and not name.startswith("GITHUB_")
                and not name.startswith("RUNNER_") and not name.startswith("INPUT_")
                and "_" in name
            })
            if missing:
                findings.append(Finding(
                    r, 0, "env-decls",
                    f"uses undeclared variable(s): {', '.join(missing[:6])}",
                    step=str(step.get("name") or step.get("id") or "")))
    return findings


def check_dup_env(root: str, files: Sequence[str]) -> List[Finding]:
    """A step carrying two `env:` keys.

    PyYAML silently keeps the last duplicate, so a parsed check cannot see
    this; GitHub rejects the workflow. Happens when an `env:` block is added
    to a step that already has one placed after `run:`.
    """
    findings: List[Finding] = []
    for path in files:
        lines = lines_of(path)
        r = rel(root, path)
        i = 0
        while i < len(lines):
            match = STEP_RE.match(lines[i])
            if not match:
                i += 1
                continue
            base = len(match.group(1))
            key_indent = base + 2
            envs: List[int] = []
            j = i
            while j < len(lines):
                if j > i:
                    if lines[j].strip() == "":
                        j += 1
                        continue
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    if indent <= base:
                        break
                candidate = lines[j].replace("- ", "  ", 1) if j == i else lines[j]
                key = KEY_RE.match(candidate)
                if key and len(key.group(1)) == key_indent and key.group(2) == "env":
                    envs.append(j + 1)
                j += 1
            if len(envs) > 1:
                findings.append(Finding(
                    r, envs[0], "dup-env",
                    f"step declares env: twice (lines {', '.join(map(str, envs))})"))
            i = j
    return findings


CHECKS = ("injection", "dispatch", "second-hop", "env-decls", "dup-env")


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="workflow_audit.py",
        description="Static checks for script injection in GitHub Actions workflows.")
    parser.add_argument("--root", default=".",
                        help="repository root (default: current directory)")
    parser.add_argument("--check", action="append", choices=CHECKS + ("all",),
                        help="run only this check (repeatable, default: all)")
    parser.add_argument("--path", action="append",
                        help="glob to scan, relative to --root (repeatable). "
                             "Defaults cover workflows, composite actions and "
                             "the shipped examples.")
    parser.add_argument("--include-caller", action="store_true",
                        help="also report caller-controlled inputs (advisory, "
                             "never gates; expect hundreds in a template repo)")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args(argv)

    root = os.path.abspath(args.root)
    patterns = tuple(args.path) if args.path else DEFAULT_PATHS
    files = iter_files(root, patterns)
    if not files:
        print(f"no files matched under {root}", file=sys.stderr)
        return 2

    selected = set(CHECKS) if not args.check or "all" in args.check else set(args.check)

    gating: List[Finding] = []
    advisory: List[Finding] = []
    if "injection" in selected:
        g, a = check_injection(root, files, args.include_caller)
        gating += g
        advisory += a
    if "dispatch" in selected:
        gating += check_dispatch(root, files)
    if "second-hop" in selected:
        gating += check_second_hop(root, files)
    if "env-decls" in selected:
        gating += check_env_decls(root, files)
    if "dup-env" in selected:
        gating += check_dup_env(root, files)

    if args.format == "json":
        print(json.dumps({
            "files_scanned": len(files),
            "gating": [f.as_dict() for f in gating],
            "advisory": [f.as_dict() for f in advisory],
        }, indent=2))
        return 1 if gating else 0

    print(f"Scanned {len(files)} file(s) under {rel(root, root) or '.'}")
    for name in sorted(selected):
        hits = [f for f in gating if f.kind == name]
        mark = "FAIL" if hits else "ok  "
        print(f"  [{mark}] {name:<11} {len(hits)} finding(s)")
    if gating:
        print()
        for finding in gating:
            print(f"  {finding}")
    if advisory:
        print(f"\n  {len(advisory)} advisory (caller-controlled) finding(s); "
              f"these never gate.")
    print()
    if gating:
        print(f"FAILED: {len(gating)} finding(s)")
        return 1
    print("PASSED: no findings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
