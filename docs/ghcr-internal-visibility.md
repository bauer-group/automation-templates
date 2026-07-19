# GHCR mit `internal`-Sichtbarkeit

Wie Workflows dieses Repos auf Container-Images zugreifen, die nicht öffentlich sind — und was aufrufende Repositories dafür setzen müssen.

## Überblick

Container-Pakete unter `ghcr.io/bauer-group/*` werden von `public` auf `internal` umgestellt. `internal` bedeutet: sichtbar für **alle Mitglieder der Enterprise**, auch organisationsübergreifend — aber **nicht anonym**. Anonyme Pulls antworten mit `403 DENIED`.

Für Workflows heißt das:

- Der eingebaute `GITHUB_TOKEN` **genügt**. Es braucht keinen PAT, keine Änderung an den Paket-Einstellungen und kein neues Secret.
- Zwei Bedingungen müssen erfüllt sein:
  1. Der Token muss per `docker login` **präsentiert** werden.
  2. Der **aufrufende** Workflow muss `packages: read` gewähren.

> Empirisch verifiziert (2026-07-19): Ein `GITHUB_TOKEN` aus Organisation A liest ein `internal`-Paket aus Organisation B, solange beide zur selben Enterprise gehören. REST-Token-Exchange: anonym `403`, authentifiziert `200`.

## Für aufrufende Repositories

### Der häufigste Fehler

Ein **partieller** `permissions:`-Block bricht den Pull. Ein **fehlender** Block nicht.

```yaml
# ❌ BRICHT den Pull interner Images
permissions:
  contents: read
  # packages ist nicht genannt -> GitHub setzt es auf `none`

# ✅ funktioniert
permissions:
  contents: read
  packages: read

# ✅ funktioniert ebenfalls (Default enthält bereits packages: read)
# (gar kein permissions-Block)
```

Die maßgebliche Regel aus der GitHub-Dokumentation:

> *"If you specify the access for any of these permissions, all of those that are not specified are set to `none`."*
> — [workflow-syntax#permissions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions)

Das ist kontraintuitiv: **Wer Least Privilege sauber deklariert, bricht sich den Zugriff — wer gar nichts deklariert, behält ihn.** Beide Default-Einstellungen (`Read and write permissions` wie `Read repository contents and packages permissions`) enthalten `packages: read`.

### Was zu tun ist

Hat euer aufrufender Workflow einen `permissions:`-Block, ergänzt `packages: read`:

```yaml
jobs:
  build:
    permissions:
      contents: read
      packages: read      # Pflicht für internal/private GHCR-Pakete
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    secrets: inherit
```

Hat er keinen Block, ist nichts zu tun.

### Warum das Modul das nicht für euch erledigen kann

Ein reusable Workflow kann die Permissions des Callers nur **einschränken**, nie erweitern:

> *"The `GITHUB_TOKEN` permissions passed from the caller workflow can be only downgraded (not elevated) by the called workflow."*
> — [reusing-workflow-configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)

Ein `permissions: packages: read` im Modul dokumentiert die Anforderung, erfüllt sie aber nicht.

### Fehlerbild

Fordert ein reusable Workflow einen Scope an, den der Caller nicht hat, **degradiert er nicht** — GitHub verweigert den Start des Runs:

```text
The workflow is requesting 'packages: read', but is only allowed 'packages: none'.
```

Kommt diese Meldung, fehlt `packages: read` im **aufrufenden** Workflow.

Beim Pull selbst sieht es so aus:

```text
denied: denied
unauthorized: authentication required
```

## Für Maintainer dieses Repos

### Die Login-Regel

> **Die `if:`-Bedingung des Logins muss gleich oder breiter sein als die `if:`-Bedingung des Steps, der die Registry berührt — und der Login muss im *selben Job* davor stehen.**

Alle bisher gefundenen Defekte waren Verletzungen genau dieser Regel, in drei Ausprägungen:

| Ausprägung | Muster |
|------------|--------|
| Login fehlt ganz | Registry-Zugriff ohne jeden Login im Job |
| Login falsch bedingt | Login an `push` gekoppelt, obwohl der **Pull** der Base-Images ihn genauso braucht |
| Login zu spät | `docker build` läuft **vor** `docker login` |

Drei Fallen, die dabei regelmäßig übersehen werden:

- **Ein eigener Job braucht einen eigenen Login.** Jobs teilen weder Dateisystem noch Docker-Daemon noch Credential-Store. Ein Login im Build-Job wirkt nicht im Scan-Job.
- **Der lokale Build braucht den Login auch bei `push: false`.** Die `FROM`-Direktiven werden dort aufgelöst. Login gehört an "habe ich Credentials?" gebunden, nicht an "will ich pushen?".
- **Reihenfolge zählt.** Ein Login nach dem Build kommt zu spät.

### Die Ceiling-Regel für `permissions:`

Beim Ergänzen von `packages: read` in einem `workflow_call`-Workflow gilt:

| Situation | Vorgehen |
|-----------|----------|
| Block existiert und nennt `packages` **nicht** | Scope ist effektiv `none` → `packages: read` **ergänzen** |
| **Kein** Block vorhanden | Caller-Default gilt bereits (`packages: read`) → **nicht anfassen** |

> In einem `workflow_call`-Workflow ist ein `permissions:`-Block eine **Obergrenze**. Existiert er und nennt `packages` nicht, hat der Token `packages: none` — unabhängig davon, was der Caller gewährt.

Daraus folgt unmittelbar: **Einem Workflow ohne `permissions:`-Block einen hinzuzufügen, kann nur wegnehmen.** Wer `nodejs-build.yml` "repariert", indem er einen Block ergänzt, bricht damit jeden Caller, der auf einen dort nicht genannten Scope angewiesen ist (z. B. `id-token: write` für npm-Provenance).

### Der Leerpasswort-Fallstrick

`docker/login-action` bricht hart ab (`Password required`), wenn `username` gesetzt und `password` leer ist. Bei **Fork-PRs** und **Dependabot-PRs** sind `secrets.*` leer. Jeder Login mit Custom-Registry-Secret braucht deshalb einen Guard:

```yaml
- name: 🔐 Log in to Registry
  if: inputs.registry-password != ''
  uses: docker/login-action@v4
  with:
    registry: ${{ inputs.registry }}
    username: ${{ inputs.registry-username || github.actor }}
    password: ${{ inputs.registry-password }}
```

Der Guard ist gleichzeitig die Fork-Behandlung: ohne Secrets kein Login, wie bisher, ohne Fehler.

### Rollback

Consumer pinnen auf `@main`. Eine Änderung wirkt damit sofort bei allen — ein `git revert` aber genauso. Färbt eine Änderung fremde Pipelines rot, ist der Revert des einen Commits die Behebung; Consumer erholen sich beim nächsten Lauf. Kein Version-Bump nötig.

Deshalb sind die Änderungen dieses Themas bewusst in kleine, einzeln revertierbare Commits geschnitten.

## Grenzen

### Dependabot und Renovate

Beide laufen **außerhalb** eurer Workflows und haben deshalb keinen Zugriff auf den automatischen `GITHUB_TOKEN`. Hier ist ein PAT mit `read:packages` tatsächlich nötig — anders als bei allen Workflows dieses Repos.

Ohne diese Konfiguration melden beide Tools für interne Base-Images dauerhaft **"keine Updates"** — still, ohne Fehlermeldung. Das ist dieselbe Blindheit, die der Base-Image-Monitor jetzt laut meldet, nur in den Tools, die die meisten Consumer tatsächlich als Drift-Erkennung nutzen.

**Dependabot** liest aus einem eigenen Secret-Store: *Settings → Secrets and variables → **Dependabot*** — nicht aus den Actions-Secrets. Benötigt werden dort:

| Secret | Inhalt |
|--------|--------|
| `DEPENDABOT_GHCR_USER` | GitHub-Benutzername, zu dem der Token gehört |
| `DEPENDABOT_GHCR_TOKEN` | PAT mit `read:packages` |

Im Template [`.github/config/docker-maintenance-dependabot/dependabot.yml`](../.github/config/docker-maintenance-dependabot/dependabot.yml) sind der `registries:`-Block und der zugehörige Verweis auskommentiert vorbereitet — bewusst, damit ein `registries:`-Eintrag, der auf ein nie gesetztes Secret zeigt, nicht auf neue und verwirrendere Weise scheitert als das heutige Schweigen.

**Renovate** braucht eine `hostRules`-Regel für `ghcr.io`. Je nach Betriebsart (Mend-App mit verschlüsseltem Token oder self-hosted mit Environment-Variable) unterscheidet sich die Einrichtung — siehe [`.github/config/docker-maintenance-renovate/README.md`](../.github/config/docker-maintenance-renovate/README.md) und die dort liegende Variante `docker-maintenance-internal-ghcr.json`.

### Nicht abschließend verifiziert

- Ob Workflow-Runs auf einem **Dependabot-Branch** `packages: read` besitzen, ist nicht dokumentiert. Aus zwei Regeln ableitbar (Defaults gelten, Writes werden zu Reads herabgestuft), aber das ist eine Inferenz.
- Die GitHub-Doku widerspricht sich, ob Dependabot-Runs überhaupt Secrets sehen: die Dependabot-Referenzseite sagt ja (Dependabot-Secrets), ein anderer Doku-Baustein sagt nein.

## Referenzen

- [Berechnung der Permissions eines Jobs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#how-permissions-are-calculated-for-a-workflow-job)
- [Reusable Workflows: nur Downgrade möglich](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)
- [Sichtbarkeit und Zugriff von Paketen](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility)
- [Workflow-Permissions in der Enterprise-Policy](https://docs.github.com/en/admin/enforcing-policies/enforcing-policies-for-your-enterprise/enforcing-policies-for-github-actions-in-your-enterprise#workflow-permissions)
- [`docker/login-action`](https://github.com/docker/login-action)
- [Secrets-Referenz dieses Repos](./secrets-reference.md)
