# Claude Code - Projektrichtlinien

> Verbindliche Richtlinien mit klarer Priorisierung.
>
> **MUST** = Merge-Blocker | **SHOULD** = Standard | **MAY** = Optional

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
