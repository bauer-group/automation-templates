# Claude Code - Projektrichtlinien

> **BAUER GROUP** - Today, Tomorrow, Together
> **BAUER GROUP** - Building Better Software Together
> **BAUER GROUP** – Technology for the Long Run
> **BAUER GROUP** – Technology That Scales With You

---

> Verbindliche Richtlinien mit klarer Priorisierung.
>
> **MUST** = Merge-Blocker | **SHOULD** = Standard | **MAY** = Optional

---

## Philosophie: Innovation & Lean Thinking

> Diese Richtlinien existieren um Qualität zu sichern - **nicht** um Kreativität zu unterdrücken.

### Kernprinzip: Minimaler Aufwand → Maximales Ergebnis

Die besten Lösungen sind elegant, schlank und smart. Komplexität ist kein Qualitätsmerkmal.

### Perfektion vs. Pragmatismus

```text
Nach Perfektion streben → Zufrieden sein wenn gut
```

**Das Pareto-Prinzip verstehen:**

- Die letzten 20% Verbesserung kosten oft 80% des Aufwands
- "Gut" ist oft gut genug - shipped beats perfect
- ABER: Innovative Features nicht wegen Aufwand opfern

**Die richtige Balance:**

| Weglassen OK           | Weglassen NICHT OK       |
|------------------------|--------------------------|
| Goldplating, Kosmetik  | Kern-Innovation          |
| Edge-Case-Perfektion   | User-Value-Features      |
| Über-Abstraktion       | Security-Essentials      |
| Nice-to-have Polish    | Differenzierende Features|

> **Faustregel:** Strebe nach 100%, akzeptiere 80% - aber nie auf Kosten der Innovation, die das Produkt besonders macht.

### Was gefördert wird

| Erwünscht                | Beispiel                                       |
|--------------------------|------------------------------------------------|
| Kreative Problemlösungen | Unkonventionelle Ansätze, die funktionieren    |
| Lean Implementations     | 10 Zeilen statt 100, wenn gleichwertig         |
| Smart Shortcuts          | Bestehende Tools/Libraries nutzen statt bauen  |
| Pragmatismus             | "Good enough" shipped > "Perfect" never done   |
| Experimentierfreude      | Neue Technologien evaluieren und einsetzen     |

### Was vermieden wird

| Vermeiden              | Stattdessen                      |
|------------------------|----------------------------------|
| Over-Engineering       | YAGNI - nur bauen was gebraucht  |
| Goldplating            | MVP first, dann iterieren        |
| Premature Optimization | Erst messen, dann optimieren     |
| Bürokratie ohne Nutzen | Prozesse hinterfragen            |

### Bei Unsicherheit: Mensch entscheidet

Risiken und Unsicherheiten werden **nicht unterdrückt**, sondern transparent gemacht:

- **Unsicher?** → Freigabe beim Menschen einholen
- **Risiko erkannt?** → Explizit dokumentieren und Entscheidung anfordern
- **Mehrere Wege möglich?** → Optionen präsentieren, Mensch wählt

> Der Mensch hat immer das letzte Wort bei kritischen Entscheidungen.

### Strategieberatung: Volle Kreativität

Wenn der Mensch nach dem **Goldstandard**, **allen Optionen** oder **Lösungsansätzen** fragt:

- Freiheitlich und kreativ denken - keine Selbstzensur
- Alle realistischen Lösungswege präsentieren (auch unkonventionelle)
- Vor- und Nachteile objektiv darstellen
- Empfehlung geben, aber Entscheidung beim Menschen lassen

> **Bei Strategiefragen:** Die Richtlinien gelten für die Umsetzung, nicht für die Ideenfindung.

### Balance

```text
Compliance ←————————→ Innovation
                  ↑
             Sweet Spot:
   Sicher, skalierbar, professionell
          UND innovativ
```

Die MUST-Regeln garantieren Sicherheit, Skalierbarkeit und Professionalität. Darüber hinaus: **Innovation first**. Neue Wege gehen, solange das Fundament solide bleibt.

---

## 1. Merge-Blocker (MUST)

> Diese Regeln sind **nicht verhandelbar**. Verstöße blockieren jeden Merge.

### 1.1 Absolute Verbote

- ❌ `Co-Authored-By:` oder AI-Hinweise in Commits
- ❌ Secrets, Credentials, API-Keys im Code oder Diff
- ❌ Merge bei roter CI-Pipeline
- ❌ Merge ohne mindestens 1 Approval
- ❌ Breaking Changes ohne dokumentierten Migration Path
- ❌ Self-Merges auf geschützte Branches
- ❌ Unresolved Blocking Comments

### 1.2 Pflicht-Kriterien vor Merge

| Kriterium | Schwellwert |
|-----------|-------------|
| CI Status | ✅ Grün |
| Tests | Alle bestanden |
| Coverage (kritische Module) | ≥ 80% |
| Security Scan | 0 Critical, 0 High |
| Linting | 0 Errors |
| Review | ≥ 1 Approval |

### 1.3 Pflicht-Dokumentation

- **Breaking Change:** Migration Guide erforderlich
- **Architekturänderung:** ADR (Architecture Decision Record) erforderlich
- **Neue Dependency:** Lizenz geprüft und dokumentiert

---

## 2. AI Usage Policy (MUST)

### 2.1 Verbindliche Regeln

- **MUST:** Jeder AI-generierte Code wird lokal getestet
- **MUST:** Fakten und APIs werden gegen Dokumentation verifiziert
- **MUST:** Keine Annahmen - bei Unklarheit nachfragen oder recherchieren
- **MUST:** Trade-offs werden im PR dokumentiert

### 2.2 Verboten

- ❌ Ungeprüfter AI-Code direkt committen
- ❌ Halluzinierte APIs oder Funktionen
- ❌ Spekulative Implementierungen ohne Validierung
- ❌ AI-Hinweise oder Signaturen in Commits/Code

---

## 3. Git & Commits (MUST/SHOULD)

### 3.1 Commit-Format (MUST)

```text
type(scope): beschreibung im imperativ

[optionaler body]
```

**Typen:** `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`, `security`

### 3.2 Commit-Regeln

| Regel | Prio |
|-------|------|
| Ein Commit = eine logische Änderung | MUST |
| Atomic: jeder Commit muss standalone funktionieren | MUST |
| Keine WIP-Commits auf main/master | MUST |
| Rebase vor Merge | SHOULD |
| Squash bei Feature-Branches | SHOULD |

### 3.3 Branch-Namenskonvention (SHOULD)

- `feature/beschreibung`
- `fix/beschreibung`
- `hotfix/beschreibung`

---

## 4. Code-Qualität (MUST/SHOULD)

### 4.1 Prinzipien (SHOULD)

- **Single Responsibility:** Eine Funktion/Klasse = eine Aufgabe
- **DRY:** Keine Duplikation, aber Lesbarkeit vor Abstraktion
- **KISS:** Einfachste Lösung, die funktioniert
- **YAGNI:** Nur implementieren was gebraucht wird

### 4.2 Struktur-Empfehlungen (SHOULD)

| Element | Empfehlung | Begründung |
|---------|------------|------------|
| Funktion | Fokussiert, eine Aufgabe | Testbarkeit |
| Klasse | Single Responsibility | Wartbarkeit |
| Verschachtelung | Max 3 Ebenen, Early Returns | Lesbarkeit |

> **Hinweis:** Keine starren Zeilenlimits - Komplexität und Kohäsion sind wichtiger als Zeilenzahlen.

### 4.3 Naming (SHOULD)

- Selbstdokumentierend durch präzise Namen
- Boolean: `is`, `has`, `can`, `should` Präfix
- Keine kryptischen Abkürzungen

---

## 5. Security (MUST/SHOULD)

### 5.1 Kritische Regeln (MUST)

- Input validieren, sanitizen, escapen
- Secrets nur via Secret-Manager oder Environment Variables
- Keine sensiblen Daten in Logs
- OWASP Top 10 beachten

### 5.2 Best Practices (SHOULD)

- Principle of Least Privilege
- Defense in Depth
- Rotation-fähige Credentials
- Audit-Trails für kritische Operationen

---

## 6. Testing (MUST/SHOULD)

### 6.1 Pflicht (MUST)

- Neue Features haben Tests
- Bug-Fixes haben Regression-Tests
- Kritische Pfade: Coverage ≥ 80%

### 6.2 Empfehlung (SHOULD)

- Unit Tests: schnell, isoliert
- Integration Tests: Komponenten-Zusammenspiel
- Arrange-Act-Assert Pattern
- Aussagekräftige Testnamen

---

## 7. Stabilität & Observability (SHOULD)

### 7.1 Fehlertoleranz

- Timeouts für alle externen Calls
- Retry mit Exponential Backoff
- Circuit Breaker bei kritischen Dependencies
- Graceful Degradation

### 7.2 Monitoring

- Structured Logging
- Health Checks
- Metrics für kritische Pfade
- Mindestens 1 Failure-Szenario-Test pro Quartal

---

## 8. Release Governance (MUST/SHOULD)

### 8.1 Review Gates (MUST)

| Gate | Bedingung |
|------|-----------|
| CI | Grün |
| Approval | ≥ 1 |
| Blocking Comments | Alle resolved |
| Security Scan | Bestanden |

### 8.2 Deployment Flow (SHOULD)

```text
Feature Branch → PR Review → Main → Staging → Production
```

### 8.3 Release Checklist (SHOULD)

- [ ] Changelog aktualisiert
- [ ] Version nach SemVer erhöht
- [ ] Breaking Changes dokumentiert
- [ ] Rollback-Plan vorhanden

---

## 9. Eskalation & Entscheidungen

### 9.1 Eskalationsstufen

| Situation | Aktion |
|-----------|--------|
| Code-Konflikt im Review | Dritter Reviewer entscheidet |
| Architektur-Entscheidung | Tech Lead / Architekt |
| Security-Bedenken | Security Review (Stop-the-Line) |
| Breaking Change mit Kundenimpact | Product Owner Sign-off |

### 9.2 Stop-the-Line Trigger

- Critical Security Finding
- Daten-Korruption möglich
- Produktions-Incident durch Change

---

## 10. Definition of Done

### 10.1 Checkliste (MUST alle erfüllt)

- [ ] Code kompiliert fehlerfrei
- [ ] Alle Tests grün
- [ ] Coverage ≥ 80% (kritische Module)
- [ ] 0 Linting Errors
- [ ] 0 Critical/High Security Findings
- [ ] Code Review abgeschlossen
- [ ] Changelog aktualisiert (bei Release)
- [ ] ADR vorhanden (bei Architekturänderung)

---

## 11. Personalunion (Solo-Entwickler)

> Vereinfachungen wenn **eine Person alle Rollen** übernimmt:
> Entwickler, Reviewer, Architekt, Release Manager in Personalunion.

### 11.1 Entfallende Anforderungen

| Standard-Regel | Personalunion |
|----------------|---------------|
| ≥ 1 Approval vor Merge | Entfällt |
| Keine Self-Merges | Erlaubt |
| PR für jeden Change | Direkt auf main erlaubt |
| Dritter Reviewer bei Konflikt | Entfällt |
| Stakeholder Sign-off | Selbst-Entscheidung |
| ADR-Review | Self-Review genügt |

### 11.2 Weiterhin MUST

- ❌ Keine Secrets im Code
- ❌ Keine AI-Signaturen in Commits
- ✅ CI muss grün sein
- ✅ Tests für neue Features
- ✅ Security Scan bestanden
- ✅ Atomic Commits

### 11.3 Empfohlen (SHOULD)

- Commit-Format einhalten (History bleibt lesbar)
- Breaking Changes dokumentieren (für eigenes Future-Self)
- Changelog bei Releases pflegen
- 24h Cooldown vor kritischen Produktions-Deployments
- Self-Review: Code nochmal lesen vor Push

### 11.4 Anwendungsbereich

**Gilt bei:**

- 1 menschlicher Contributor (Bots wie Dependabot zählen nicht)
- Persönliche Projekte
- Prototypen / PoCs
- Interne Tools ohne externe User

**Gilt NICHT bei:**

- Produktions-kritische Systeme mit Kunden
- Open Source mit Community
- Projekte mit Compliance-Anforderungen
- Sobald zweiter menschlicher Contributor aktiv wird

> **Im Zweifel:** Wenn unklar ob Einzelentwickler-Repo → als Personalunion einstufen.

---

## 12. Technische Standards (SHOULD)

### 12.1 Error Handling

| Prinzip              | Umsetzung                                     |
|----------------------|-----------------------------------------------|
| Fail Fast            | Fehler früh erkennen, nicht verschlucken      |
| Graceful Degradation | Bei nicht-kritischen Fehlern weiterlaufen     |
| Meaningful Errors    | Aussagekräftige Fehlermeldungen mit Kontext   |
| No Silent Failures   | Jeder Fehler wird geloggt oder geworfen       |

```text
Try-Catch nur wo sinnvoll:
├── Externe Calls (API, DB, File I/O)
├── User Input Validation
└── Recovery möglich
```

### 12.2 Logging

**Was loggen:**

- Errors mit Stack Trace und Kontext
- Business-relevante Events
- Performance-Metriken (kritische Pfade)
- Security-relevante Aktionen

**Was NICHT loggen:**

- ❌ PII (Personenbezogene Daten)
- ❌ Secrets, Tokens, Passwords
- ❌ Hochfrequente Debug-Logs in Production
- ❌ Redundante Informationen

**Format:** Strukturiertes Logging (JSON) bevorzugen

### 12.3 Commit-Beispiele

**Gute Commits:**

```text
feat(auth): add JWT refresh token rotation

fix(api): handle timeout on external service calls

refactor(utils): extract date formatting to shared module

chore(deps): update dependencies to latest stable
```

**Schlechte Commits:**

```text
❌ "fix"
❌ "WIP"
❌ "changes"
❌ "asdfasdf"
❌ "fix bug" (welcher?)
❌ "update code" (was genau?)
```

---

## Quick Reference

```text
┌─────────────────────────────────────────────────────────┐
│                    MERGE-BLOCKER                        │
├─────────────────────────────────────────────────────────┤
│ ❌ AI-Signaturen in Commits                             │
│ ❌ Secrets im Code                                      │
│ ❌ CI rot                                               │
│ ❌ Security: Critical/High Findings                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                    PHILOSOPHIE                          │
├─────────────────────────────────────────────────────────┤
│ Minimal Aufwand → Maximal Ergebnis                      │
│ Strebe 100% an, akzeptiere 80%                          │
│ Innovation > Perfektion bei Kern-Features               │
│ Mensch entscheidet bei Unsicherheit                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  COMMIT FORMAT                          │
├─────────────────────────────────────────────────────────┤
│ type(scope): beschreibung im imperativ                  │
│                                                         │
│ Types: feat|fix|chore|docs|refactor|test|ci|perf|security│
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  PERSONALUNION                          │
├─────────────────────────────────────────────────────────┤
│ Solo-Dev? → Kein PR/Approval nötig                      │
│ ABER: CI grün, Tests, Security, Atomic Commits          │
│ Im Zweifel → als Personalunion einstufen                │
└─────────────────────────────────────────────────────────┘
```

---

## Legende

| Symbol | Bedeutung |
|--------|-----------|
| MUST | Merge-Blocker, nicht verhandelbar |
| SHOULD | Standard, Abweichung begründen |
| MAY | Optional, Best Practice |
| ❌ | Verboten |
| ✅ | Erforderlich |

---

*Stand: 2026-01 | Review: Bei Bedarf*
