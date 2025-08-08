#!/usr/bin/env python3

import os
import subprocess
from datetime import datetime, timezone
from typing import Optional

TEMPLATE_PATH = "docs/README.template.MD"
OUTPUT_PATH = "README.MD"

def get_initial_version() -> str:
    """
    Returns the initial semantic version to use when no tag exists.
    Can be overridden with the INIT_VERSION environment variable.
    Default: 0.1.0 (pre-1.0 development).
    """
    return os.getenv("INIT_VERSION", "0.1.0")

def get_latest_tag() -> Optional[str]:
    """
    Returns the latest tag (without leading 'v') or None if no tag exists.
    """
    try:
        tag = subprocess.check_output(
            ["git", "describe", "--tags", "--abbrev=0"],
            stderr=subprocess.STDOUT,
        ).decode().strip()
        return tag.lstrip("v")
    except Exception:
        return None

def render_template(template: str, vars: dict) -> str:
    out = template
    for k, v in vars.items():
        out = out.replace("{{" + k + "}}", v)
    return out

def main():
    # Priority order:
    # 1) RELEASE_VERSION (from semantic-release prepare step)
    # 2) latest git tag
    # 3) initial fallback (INIT_VERSION or 0.1.0)
    version = os.getenv("RELEASE_VERSION")
    if not version:
        version = get_latest_tag() or get_initial_version()

    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    with open(TEMPLATE_PATH, "r", encoding="utf-8") as f:
        template = f.read()

    content = render_template(template, {
        "VERSION": version,
        "DATE": date
    })

    banner = "<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.md instead. -->\n\n"
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(banner + content)

if __name__ == "__main__":
    main()
