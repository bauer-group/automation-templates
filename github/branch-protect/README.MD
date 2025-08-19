# Branch Protection Automation (Python CLI)

Dieses Tool setzt oder aktualisiert **Branch-Protection-Regeln** für einen Ziel-Branch (Standard `main`) in allen Repositories einer GitHub-Organisation oder in einer expliziten Repo-Liste.  
Es verwendet direkte GitHub REST-API Aufrufe (Token-basiert) und kann optional Protection wieder entfernen.

---

## 📌 Features

- PR-Pflicht vor jedem Merge
- Mindestens **2 Reviews** erforderlich (konfigurierbar)
- Alte Reviews werden ungültig, wenn neue Commits kommen
- Branch muss **up-to-date** mit `main` sein, bevor gemergt werden darf
- Offene Diskussionen in PRs müssen gelöst sein
- Optionale **Status-Checks** (Kontextnamen)
- Optionale **Push-Restrictions** (Teams/Benutzer)
- Optional **signierte Commits** erzwingen
- Option, Admins in den Schutz einzubeziehen
- Idempotentes Re-Apply (einfach erneut ausführen)
- Entfernen der Protection (`--delete`)
- Dry-Run zur sicheren Vorschau

---

## 📦 Voraussetzungen

Python (protect_main.py):
- Python 3.9+
- Paket `requests` (wird vom Wrapper automatisch installiert)
- Personal Access Token: `export GITHUB_TOKEN=...` (oder `GH_TOKEN`)

Allgemein:
- Admin / Maintain Rechte auf den Repositories
- Branch muss existieren (sonst Warnung)

---

## ⚙️ Konfiguration

Konfiguration ausschließlich über Flags / Environment. Du musst ENTWEDER Organisation ODER Repo-Liste definieren. Bei beidem gewinnt die Organisation.

| Variable                          | Beschreibung                                                                                          | Standard |
| --------------------------------- | ----------------------------------------------------------------------------------------------------- | -------- |
| `ORG` / `--org`                   | Name der GitHub Organisation. Wird ignoriert, wenn leer.                                              | –        |
| `REPO_LIST` / `--repos`           | Whitespace- oder zeilen-separierte Liste `owner/repo`. Nur nutzen, wenn `ORG` leer ist.               | –        |
| `BRANCH`                          | Zu schützender Branch                                                                                 | `main`   |
| `REVIEWS`                         | Anzahl benötigter Reviews                                                                             | `2`      |
| `INCLUDE_ADMINS`                  | Admins in den Schutz einbeziehen (`true/false`)                                                       | `true`   |
| `LINEAR_HISTORY`                  | Lineare Historie erzwingen                                                                            | `true`   |
| `ALLOW_FORCE_PUSHES`              | Force-Pushes erlauben                                                                                 | `false`  |
| `ALLOW_DELETIONS`                 | Branch löschen erlauben                                                                               | `false`  |
| `REQUIRE_CONVERSATION_RESOLUTION` | Offene PR-Diskussionen müssen gelöst sein                                                             | `true`   |
| `STRICT_UPTODATE`                 | PR muss vor Merge up-to-date mit Ziel-Branch sein                                                     | `true`   |
| `STATUS_CHECKS`                   | Liste von Status-Check Kontexten (z. B. `"ci/test lint build"`)                                      | –        |
| `RESTRICT_TEAMS`                  | Teams mit Push-/Bypass-Rechten                                                                        | –        |
| `RESTRICT_USERS`                  | Benutzer mit Push-/Bypass-Rechten                                                                     | –        |
| `REQUIRE_SIGNED_COMMITS`          | Signierte Commits erzwingen (`true/false`)                                                            | `false`  |
| `--delete`                        | Protection entfernen (statt setzen)                                                                  | –        |
| `--dry-run`                       | Nur anzeigen, keine Änderungen                                                                       | –        |

### Wichtige Flags (Kurzreferenz)

| Flag / Env                         | Wirkung                                          |
| ---------------------------------- | ------------------------------------------------- |
| --org ORG                          | Alle Repos der Organisation                       |
| --repos r1 r2                      | Explizite Liste (owner/repo)                      |
| --branch main                      | Ziel-Branch                                       |
| --reviews 2                        | Anzahl benötigter Reviews                         |
| --status-check build (repeatable)  | Status-Check Kontexte hinzufügen                  |
| --team t1 (repeatable)             | Team mit Push-/Bypass-Rechten                     |
| --user u1 (repeatable)             | Benutzer mit Push-/Bypass-Rechten                 |
| --require-signed-commits           | Signierte Commits erzwingen                       |
| --allow-force-pushes               | Force-Pushes erlauben                             |
| --allow-deletions                  | Branch-Löschung erlauben                          |
| --no-include-admins                | Admins nicht einbeziehen                          |
| --no-linear-history                | Lineare Historie NICHT erzwingen                  |
| --no-require-conversation-resolution | Gesprächsauflösung nicht erzwingen             |
| --no-strict-up-to-date             | Up-to-date Pflicht deaktivieren                   |
| --delete                           | Protection komplett entfernen                     |
| --dry-run                          | Nur anzeigen (keine Änderungen)                   |

Hinweis: Mehrfach-Flags (`--status-check`, `--team`, `--user`) einfach wiederholen.

---

## 🚀 Nutzung

### 1. Alle Repos einer Organisation
```bash
export GITHUB_TOKEN=ghp_xxx
python src/protect_main.py --org mein-org
```

### 2. Organisation + Status-Checks
```bash
export GITHUB_TOKEN=ghp_xxx
python src/protect_main.py --org mein-org --status-check ci/test --status-check lint --status-check build
```

### 3. Team-Einschränkungen
```bash
export GITHUB_TOKEN=ghp_xxx
python src/protect_main.py --org mein-org --team maintainers --team release-managers
```

### 4. Signierte Commits erzwingen
```bash
export GITHUB_TOKEN=ghp_xxx
python src/protect_main.py --org mein-org --require-signed-commits
```

### 5. Konkrete Repo-Liste statt Organisation
```bash
export GITHUB_TOKEN=ghp_xxx
python src/protect_main.py --repos owner1/repoA owner2/repoB
```

Multiline Variante (bessere Lesbarkeit):
```bash
export GITHUB_TOKEN=ghp_xxx
python src/protect_main.py --repos owner1/repoA owner2/repoB owner3/repoC
```

### 6. Kombination: Repo-Liste + Status-Checks + Signaturen
```bash
export GITHUB_TOKEN=ghp_xxx
python src/protect_main.py --repos owner/repo1 owner/repo2 --status-check build --status-check lint --status-check test --require-signed-commits
```

### 7. Entfernen & Dry-Run
```bash
# Schutz entfernen (alle Regeln des Branches)
export GITHUB_TOKEN=ghp_xxx
python src/protect_main.py --repos owner1/repoA --delete

# Dry-Run (zeigt geplante REST-Calls)
python src/protect_main.py --org mein-org --dry-run

### 8. Wrapper verwenden (führt Auto-Install aus)
```bash
./run_protection.sh --org mein-org --status-check build --status-check test
```
```

---

## 🔐 Sicherheits-Workflow für das Team

Damit die Branch-Protection-Regeln auch im Alltag eingehalten werden, sollte das Team folgenden Ablauf nutzen:

1. **Feature-Branch anlegen**

   ```bash
   git checkout -b feature/neues-feature
   ```

2. **Änderungen commiten**

   ```bash
   git add .
   git commit -m "feat: neues Feature hinzugefügt"
   git push origin feature/neues-feature
   ```

3. **Pull Request erstellen**

   * Auf GitHub einen PR von `feature/neues-feature` → `main` öffnen.
   * Prüfen, ob alle **Status-Checks** (Tests, Builds, Linter) durchlaufen.

4. **Code-Review**

   * Mindestens **2 Teammitglieder** müssen den PR genehmigen.
   * Bei neuen Commits im PR müssen Reviews erneut erfolgen.

5. **Merge**

   * PR muss **up-to-date** mit `main` sein.
   * Alle Diskussionen müssen auf „resolved“ stehen.
   * Merge-Strategie: Squash & Merge oder Rebase & Merge (keine Merge-Commits, wenn möglich).

6. **Branch löschen**

   * Nach dem Merge den Feature-Branch löschen (lokal und remote), um die Repo sauber zu halten.

💡 **Wichtig:** Direktes Pushen auf `main` ist durch die Regeln gesperrt – Änderungen *müssen* den PR-Prozess durchlaufen.

---

## 🛠 Hinweise

* Ohne Branch-Protection kann **jeder mit Push-Rechten** direkt auf `main` committen.
* Dieses Script erstellt eine **einheitliche Sicherheitskonfiguration** für alle Repos.
* Änderungen an den Regeln können jederzeit erneut mit dem Script ausgerollt werden.
* Falls `ORG` leer ist, MUSS `REPO_LIST` über die Umgebung gesetzt werden – das Script bricht sonst ab.
* Bei gleichzeitiger Angabe von `ORG` und `REPO_LIST` wird `REPO_LIST` ignoriert.
* Script-Ausgabe enthält Warnungen, falls ein Branch nicht existiert oder Rechte fehlen.
* Wrapper `run_protection.sh` installiert Abhängigkeiten automatisch.
* Entfernen einzelner Teilaspekte (z. B. nur Signaturen) wird von der GitHub API nicht granulär angeboten – `--delete` entfernt die komplette Protection-Konfiguration für den Branch.
* Re-Apply ist idempotent: unveränderte Regeln verursachen keinen Fehler.
* Für sehr große Organisationen kann Paging > 100 Repos erforderlich sein (Python paged; Shell nutzt `gh repo list --limit 1000`).
