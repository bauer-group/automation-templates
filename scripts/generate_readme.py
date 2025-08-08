#!/usr/bin/env python3
import os
import subprocess
from datetime import datetime, timezone

TEMPLATE_PATH = "docs/README.template.MD"
OUTPUT_PATH = "README.MD"

def get_latest_tag() -> str:
    try:
        tag = subprocess.check_output(
            ["git", "describe", "--tags", "--abbrev=0"],
            stderr=subprocess.STDOUT,
        ).decode().strip()
        return tag.lstrip("v")
    except Exception:
        return "0.0.0"

def render_template(template: str, vars: dict) -> str:
    out = template
    for k, v in vars.items():
        out = out.replace("{{" + k + "}}", v)
    return out

def main():
    with open(TEMPLATE_PATH, "r", encoding="utf-8") as f:
        template = f.read()

    version = os.getenv("RELEASE_VERSION") or get_latest_tag()
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    content = render_template(template, {
        "VERSION": version,
        "DATE": date
    })

    banner = "<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.MD instead. -->\n\n"
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(banner + content)

if __name__ == "__main__":
    main()