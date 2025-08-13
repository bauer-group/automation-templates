# protect-main.sh – GitHub Branch-Protection Automation

Dieses Script setzt **Branch-Protection-Regeln** für den `main`-Branch in allen Repositories einer GitHub-Organisation oder einer definierten Repo-Liste.  
Es nutzt die **GitHub CLI** (`gh`) und konfiguriert den Branch so, dass er nur noch über geprüfte Pull Requests verändert werden kann.

---

## 📌 Features

- PR-Pflicht vor jedem Merge
- Mindestens **2 Reviews** erforderlich (konfigurierbar)
- Alte Reviews werden ungültig, wenn neue Commits kommen
- Branch muss **up-to-date** mit `main` sein, bevor gemergt werden darf
- Offene Diskussionen in PRs müssen gelöst sein
- Optionale **Status-Checks** erzwingen (z. B. CI-Builds)
- Optionale **Push-Restrictions** für bestimmte Teams/Benutzer
- Optional **signierte Commits** erzwingen
- Option, Admins in den Schutz einzubeziehen

---

## 📦 Voraussetzungen

- **GitHub CLI** installiert:  
  [Installation](https://cli.github.com/manual/installation)
- Bei GitHub eingeloggt:  
  ```bash
  gh auth login
````

* Admin- oder Maintainer-Rechte auf den Ziel-Repos

---

## ⚙️ Konfiguration

Die Konfiguration erfolgt ausschließlich über Umgebungsvariablen.
Du musst ENTWEDER `ORG` ODER `REPO_LIST` setzen (wenn beide gesetzt sind, gewinnt `ORG`). Sind beide leer, bricht das Script mit einer Usage-Ausgabe ab.

| Variable                          | Beschreibung                                                                                          | Standard |
| --------------------------------- | ----------------------------------------------------------------------------------------------------- | -------- |
| `ORG`                             | Name der GitHub Organisation. Wird ignoriert, wenn leer.                                              | –        |
| `REPO_LIST`                       | Whitespace- oder zeilen-separierte Liste `owner/repo`. Nur nutzen, wenn `ORG` leer ist.               | –        |
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

Hinweis: Für `STATUS_CHECKS`, `RESTRICT_TEAMS`, `RESTRICT_USERS` einfach durch Leerzeichen trennen oder multiline export nutzen.

---

## 🚀 Nutzung

### 1. Alle Repos einer Organisation
```bash
export ORG="mein-org"
bash protect-main.sh
```

### 2. Organisation + Status-Checks
```bash
export ORG="mein-org"
export STATUS_CHECKS="ci/test lint build"  # Leerzeichen-getrennt
bash protect-main.sh
```

### 3. Team-Einschränkungen
```bash
export ORG="mein-org"
export RESTRICT_TEAMS="maintainers release-managers"
bash protect-main.sh
```

### 4. Signierte Commits erzwingen
```bash
export ORG="mein-org"
export REQUIRE_SIGNED_COMMITS=true
bash protect-main.sh
```

### 5. Konkrete Repo-Liste statt Organisation
```bash
unset ORG
export REPO_LIST="owner1/repoA owner2/repoB"
bash protect-main.sh
```

Multiline Variante (bessere Lesbarkeit):
```bash
unset ORG
export REPO_LIST=$'owner1/repoA\nowner2/repoB\nowner3/repoC'
bash protect-main.sh
```

### 6. Kombination: Repo-Liste + Status-Checks + Signaturen
```bash
unset ORG
export REPO_LIST=$'owner/repo1\nowner/repo2'
export STATUS_CHECKS="build lint test"
export REQUIRE_SIGNED_COMMITS=true
bash protect-main.sh
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
