"""Branch Protection Management (Python Version)

Plattformunabhängiges Tool zum Setzen, Aktualisieren oder Entfernen von
Branch-Protection-Regeln über die GitHub REST API.

Funktional entspricht es grob dem Shell-Script `protect-main.sh`, erweitert um:
  * Reine Python-Implementierung (Windows / macOS / Linux)
  * ORG ODER explizite Repo-Liste (ORG hat Priorität)
  * Aktualisierung existierender Regeln (PUT ist idempotent)
  * Option zum Entfernen aller Regeln (--delete)
  * Dry-Run Modus

Authentifizierung:
  * Personal Access Token (classic oder fine-grained) mit mindestens `repo` + `admin:repo_hook` (oder "Maintain" Rechte) Rechten.
  * Bereitstellung via --token oder Environment: GITHUB_TOKEN / GH_TOKEN

Beispiel:
  python protect_main.py --org mein-org
  python protect_main.py --org mein-org --status-check build --status-check test --require-signed-commits
  python protect_main.py --repos owner1/r1 owner2/r2 --delete
  python protect_main.py --org mein-org --dry-run

Hinweis: Beim Entfernen (--delete) werden alle Protection-Regeln inklusive Signaturpflicht entfernt.
"""
from __future__ import annotations

import argparse
import os
import sys
from typing import Iterable, List, Optional, Sequence

try:
    import requests  # type: ignore
except ImportError as e:  # pragma: no cover
    print("[error] Das Paket 'requests' wird benötigt. Installation: pip install requests", file=sys.stderr)
    raise

API_BASE = "https://api.github.com"
DEFAULT_BRANCH = "main"
SESSION = requests.Session()
TIMEOUT = 30


class Config:
    def __init__(
        self,
        org: Optional[str],
        repos: Sequence[str],
        branch: str,
        reviews: int,
        include_admins: bool,
        linear_history: bool,
        allow_force_pushes: bool,
        allow_deletions: bool,
        require_conversation_resolution: bool,
        strict_up_to_date: bool,
        status_checks: Sequence[str],
        restrict_teams: Sequence[str],
        restrict_users: Sequence[str],
        require_signed_commits: bool,
        delete_mode: bool,
        dry_run: bool,
        token: str,
    ) -> None:
        self.org = org
        self.repos = list(repos)
        self.branch = branch
        self.reviews = reviews
        self.include_admins = include_admins
        self.linear_history = linear_history
        self.allow_force_pushes = allow_force_pushes
        self.allow_deletions = allow_deletions
        self.require_conversation_resolution = require_conversation_resolution
        self.strict_up_to_date = strict_up_to_date
        self.status_checks = list(status_checks)
        self.restrict_teams = list(restrict_teams)
        self.restrict_users = list(restrict_users)
        self.require_signed_commits = require_signed_commits
        self.delete_mode = delete_mode
        self.dry_run = dry_run
        self.token = token


def _auth_headers(token: str) -> dict:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "branch-protect-python/1.0",
    }


def list_org_repos(org: str, token: str) -> List[str]:
    repos: List[str] = []
    page = 1
    while True:
        url = f"{API_BASE}/orgs/{org}/repos"
        resp = SESSION.get(url, headers=_auth_headers(token), params={"per_page": 100, "page": page}, timeout=TIMEOUT)
        if resp.status_code == 404:
            raise SystemExit(f"[error] Organisation '{org}' nicht gefunden")
        if resp.status_code != 200:
            raise SystemExit(f"[error] Konnte Repos nicht laden (Status {resp.status_code}): {resp.text[:200]}")
        batch = resp.json()
        if not batch:
            break
        repos.extend(item["full_name"] for item in batch)
        page += 1
    return repos


def build_payload(cfg: Config) -> dict:
    restrictions = None
    if cfg.restrict_teams or cfg.restrict_users:
        restrictions = {
            "users": cfg.restrict_users,
            "teams": cfg.restrict_teams,
            "apps": [],
        }
    payload = {
        "required_status_checks": {
            "strict": cfg.strict_up_to_date,
            "contexts": cfg.status_checks,
        },
        "enforce_admins": cfg.include_admins,
        "required_pull_request_reviews": {
            "dismiss_stale_reviews": True,
            "required_approving_review_count": cfg.reviews,
        },
        "restrictions": restrictions,
        "required_linear_history": cfg.linear_history,
        "allow_force_pushes": cfg.allow_force_pushes,
        "allow_deletions": cfg.allow_deletions,
        "required_conversation_resolution": cfg.require_conversation_resolution,
    }
    return payload


def apply_protection(cfg: Config, repo: str) -> None:
    url = f"{API_BASE}/repos/{repo}/branches/{cfg.branch}/protection"
    if cfg.dry_run:
        print(f"[dry-run] PUT {url}")
        return
    payload = build_payload(cfg)
    resp = SESSION.put(url, json=payload, headers=_auth_headers(cfg.token), timeout=TIMEOUT)
    if resp.status_code not in (200, 201):
        print(f"[warn] Schutz fehlgeschlagen für {repo}@{cfg.branch}: {resp.status_code} {resp.text[:180]}")
        return
    print(f"[ok] Protection gesetzt/aktualisiert für {repo}@{cfg.branch}")

    if cfg.require_signed_commits:
        sig_url = f"{url}/required_signatures"
        sig_resp = SESSION.post(sig_url, headers=_auth_headers(cfg.token), timeout=TIMEOUT)
        if sig_resp.status_code in (201, 204):
            print(f"[ok] Signierte Commits aktiviert für {repo}")
        elif sig_resp.status_code == 409:
            print(f"[info] Signierte Commits evtl. bereits aktiv für {repo}")
        else:
            print(f"[warn] Konnte Signaturen nicht aktivieren für {repo}: {sig_resp.status_code} {sig_resp.text[:120]}")


def remove_protection(cfg: Config, repo: str) -> None:
    url = f"{API_BASE}/repos/{repo}/branches/{cfg.branch}/protection"
    if cfg.dry_run:
        print(f"[dry-run] DELETE {url}")
        return
    resp = SESSION.delete(url, headers=_auth_headers(cfg.token), timeout=TIMEOUT)
    if resp.status_code in (204, 200):
        print(f"[ok] Protection entfernt für {repo}@{cfg.branch}")
    elif resp.status_code == 404:
        print(f"[info] Keine Protection vorhanden für {repo}@{cfg.branch}")
    else:
        print(f"[warn] Entfernen fehlgeschlagen für {repo}@{cfg.branch}: {resp.status_code} {resp.text[:160]}")


def parse_args(argv: Optional[Sequence[str]] = None) -> Config:
    p = argparse.ArgumentParser(description="GitHub Branch Protection verwalten (setzen/aktualisieren/entfernen)")
    g_target = p.add_mutually_exclusive_group(required=False)
    g_target.add_argument("--org", dest="org", help="Organisation (alle Repos)")
    g_target.add_argument("--repos", nargs="*", help="Explizite owner/repo Einträge (Whitespace getrennt)")

    p.add_argument("--branch", default=DEFAULT_BRANCH, help=f"Ziel-Branch (Default: {DEFAULT_BRANCH})")
    p.add_argument("--reviews", type=int, default=2, help="Benötigte Review-Anzahl")
    p.add_argument("--status-check", dest="status_checks", action="append", default=[], help="Status-Check Kontext (mehrfach)")
    p.add_argument("--team", dest="teams", action="append", default=[], help="Team mit Push/Bypass-Recht (mehrfach)")
    p.add_argument("--user", dest="users", action="append", default=[], help="User mit Push/Bypass-Recht (mehrfach)")
    p.add_argument("--no-include-admins", action="store_true", help="Admins NICHT einbeziehen")
    p.add_argument("--no-linear-history", action="store_true", help="Lineare Historie nicht erzwingen")
    p.add_argument("--allow-force-pushes", action="store_true", help="Force-Pushes erlauben")
    p.add_argument("--allow-deletions", action="store_true", help="Branch löschen erlauben")
    p.add_argument("--no-require-conversation-resolution", action="store_true", help="PR-Konversationen müssen NICHT gelöst sein")
    p.add_argument("--no-strict-up-to-date", action="store_true", help="Branch muss vor Merge NICHT up-to-date sein")
    p.add_argument("--require-signed-commits", action="store_true", help="Signierte Commits erzwingen")
    p.add_argument("--delete", dest="delete_mode", action="store_true", help="Protection entfernen statt setzen")
    p.add_argument("--dry-run", action="store_true", help="Nur anzeigen, keine Änderungen senden")
    p.add_argument("--token", help="GitHub Token (statt Env)")

    args = p.parse_args(argv)

    token = args.token or os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN")
    if not token:
        p.error("GitHub Token fehlt (Option --token oder Env GITHUB_TOKEN / GH_TOKEN setzen)")

    if not args.org and not args.repos:
        p.error("Entweder --org ODER --repos angeben")

    repos: List[str] = []
    org: Optional[str] = None
    if args.org:
        org = args.org.strip()
    else:
        repos = [r.strip() for r in args.repos if r.strip()]

    cfg = Config(
        org=org,
        repos=repos,
        branch=args.branch,
        reviews=args.reviews,
        include_admins=not args.no_include_admins,
        linear_history=not args.no_linear_history,
        allow_force_pushes=args.allow_force_pushes,
        allow_deletions=args.allow_deletions,
        require_conversation_resolution=not args.no_require_conversation_resolution,
        strict_up_to_date=not args.no_strict_up_to_date,
        status_checks=args.status_checks,
        restrict_teams=args.teams,
        restrict_users=args.users,
        require_signed_commits=args.require_signed_commits,
        delete_mode=args.delete_mode,
        dry_run=args.dry_run,
        token=token,
    )
    return cfg


def main(argv: Optional[Sequence[str]] = None) -> int:
    cfg = parse_args(argv)

    # Repos bestimmen
    if cfg.org:
        try:
            target_repos = list_org_repos(cfg.org, cfg.token)
        except SystemExit as e:
            print(e, file=sys.stderr)
            return 1
    else:
        target_repos = cfg.repos

    count = 0
    for full_name in target_repos:
        count += 1
        repo = full_name if "/" in full_name else f"{cfg.org}/{full_name}" if cfg.org else full_name
        if cfg.delete_mode:
            remove_protection(cfg, repo)
        else:
            apply_protection(cfg, repo)
    print(f"[info] Bearbeitet: {count} Repositories.")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
