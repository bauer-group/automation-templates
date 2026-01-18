# Claude Code - Projektrichtlinien

> Verbindliche Richtlinien für alle Code-Änderungen in diesem Repository.

---

## 1. Git & Versionskontrolle

### 1.1 Commit-Hygiene

**Absolut verboten:**

- `Co-Authored-By:` Zeilen jeglicher Art
- Hinweise auf AI, Claude oder automatische Generierung
- Signaturen, Footer oder Attributionen
- Merge-Commits bei linearer History

**Commit-Format:**

```text
type(scope): kurze Beschreibung im Imperativ

- Detailpunkt bei Bedarf
- Maximal 72 Zeichen pro Zeile
```

**Typen:** `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`, `security`

**Regeln:**

- Ein Commit = eine logische Änderung
- Atomic Commits: jeder Commit muss standalone funktionieren
- Keine WIP-Commits auf main/master
- Rebase vor Merge, niemals Merge-Commits

### 1.2 Branch-Strategie

- Feature-Branches: `feature/beschreibung`
- Bugfixes: `fix/beschreibung`
- Hotfixes: `hotfix/beschreibung`
- Keine direkten Pushes auf geschützte Branches

### 1.3 Fortgeschrittene Git-Konzepte

- **Interactive Rebase:** History aufräumen vor PR
- **Squash:** Logische Einheiten zusammenfassen
- **Cherry-Pick:** Gezielte Commits übertragen
- **Bisect:** Systematische Fehlersuche
- **Reflog:** Recovery bei Fehlern
- **Stash:** Kontextwechsel ohne Commit
- **Worktrees:** Paralleles Arbeiten an Branches

### 1.4 History-Integrität

- Lineare History auf main/master
- Force-Push nur auf eigenen Feature-Branches
- Signed Commits bei kritischen Änderungen
- Keine History-Rewrites nach Merge

---

## 2. Code-Qualität

### 2.1 Fundamentale Prinzipien

- **SOLID:** Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **DRY:** Don't Repeat Yourself - aber nicht auf Kosten der Lesbarkeit
- **KISS:** Keep It Simple, Stupid - Einfachheit vor Cleverness
- **YAGNI:** You Ain't Gonna Need It - keine spekulativen Features

### 2.2 Code-Struktur

- Funktionen: maximal 20-30 Zeilen, eine Aufgabe
- Klassen: maximal 200-300 Zeilen, eine Verantwortung
- Dateien: logisch gruppiert, keine God-Files
- Verschachtelung: maximal 3 Ebenen, Early Returns bevorzugen

### 2.3 Naming Conventions

- Selbstdokumentierender Code durch präzise Namen
- Keine Abkürzungen außer etablierte (ID, URL, HTTP)
- Boolean-Variablen: `is`, `has`, `can`, `should` Präfix
- Funktionen: Verben für Aktionen, Substantive für Getter

### 2.4 Fehlerbehandlung

- Fail Fast: Fehler früh erkennen und abbrechen
- Defensive Programming an System-Grenzen
- Keine leeren Catch-Blöcke
- Strukturierte Fehlermeldungen mit Kontext
- Graceful Degradation wo sinnvoll

---

## 3. Architektur

### 3.1 Design-Prinzipien

- Separation of Concerns: klare Schichtentrennung
- Loose Coupling: minimale Abhängigkeiten zwischen Modulen
- High Cohesion: zusammengehörige Logik gruppieren
- Dependency Injection: Abhängigkeiten explizit machen

### 3.2 API-Design

- Konsistente Namensgebung und Struktur
- Versionierung bei Breaking Changes
- Idempotenz wo möglich
- Defensive Input-Validierung

### 3.3 Konfiguration

- Keine Hardcoded Values für Umgebungsspezifisches
- Secrets niemals im Code oder Commits
- Environment-basierte Konfiguration
- Sinnvolle Defaults mit Override-Möglichkeit

---

## 4. Security

### 4.1 Grundregeln

- Input ist immer feindlich: validieren, sanitizen, escapen
- Principle of Least Privilege
- Defense in Depth: mehrere Sicherheitsebenen
- Keine sensiblen Daten in Logs

### 4.2 Secrets Management

- Secrets nur über Secret-Manager oder Environment Variables
- Keine Credentials in Repositories
- Rotation-fähige Architekturen
- Audit-Trails für Zugriffe

### 4.3 OWASP Top 10 Awareness

- Injection Prevention
- Authentication/Authorization korrekt implementieren
- Sensitive Data Exposure vermeiden
- Security Misconfiguration prüfen

---

## 5. Performance

### 5.1 Grundsätze

- Messen vor Optimieren: keine premature optimization
- Bottlenecks identifizieren, nicht raten
- Caching strategisch einsetzen
- Resource Cleanup sicherstellen

### 5.2 Effizienz

- O(n) Komplexität verstehen und beachten
- Unnötige Iterationen vermeiden
- Lazy Loading wo sinnvoll
- Connection Pooling nutzen

---

## 6. Testing

### 6.1 Test-Pyramide

- Unit Tests: schnell, isoliert, viele
- Integration Tests: Komponenten-Zusammenspiel
- E2E Tests: kritische Pfade, wenige

### 6.2 Test-Qualität

- Arrange-Act-Assert Pattern
- Ein Assert pro Test (logisch)
- Aussagekräftige Testnamen
- Keine Test-Interdependenzen

---

## 7. Dokumentation

### 7.1 Code-Dokumentation

- Code ist die primäre Dokumentation
- Kommentare nur für das WARUM, nicht das WAS
- README aktuell halten
- API-Dokumentation bei öffentlichen Schnittstellen

### 7.2 Inline-Kommentare

- Nur bei komplexer Business-Logik
- Keine auskommentierten Code-Blöcke
- TODOs mit Kontext und Ticket-Referenz

---

## 8. CI/CD & DevOps

### 8.1 GitHub Actions

- Aktuelle Action-Versionen verwenden
- Composite Actions konsistent halten
- README-Beispiele synchron halten
- Secrets über GitHub Secrets, niemals hardcoded

### 8.2 Pipeline-Prinzipien

- Fast Feedback: schnelle Checks zuerst
- Reproducible Builds
- Infrastructure as Code
- Rollback-Fähigkeit sicherstellen

---

## 9. Wartbarkeit

### 9.1 Technische Schulden

- Boy Scout Rule: Code besser hinterlassen als vorgefunden
- Refactoring in separaten Commits
- Deprecation vor Removal
- Breaking Changes dokumentieren

### 9.2 Dependencies

- Minimale externe Abhängigkeiten
- Regelmäßige Updates (Security!)
- Lock-Files committen
- Lizenzen prüfen

---

## 10. Review-Standards

### 10.1 Code Review Fokus

- Korrektheit der Logik
- Edge Cases und Fehlerbehandlung
- Security-Implikationen
- Performance-Auswirkungen
- Wartbarkeit und Lesbarkeit

### 10.2 Review-Etikette

- Konstruktives Feedback
- Fragen statt Anweisungen
- Lob für gute Lösungen
- Zeitnahes Review

---

## 11. Workflow

### 11.1 Änderungen

- Bestehende Patterns verstehen bevor ändern
- Minimale, fokussierte Änderungen
- Backwards Compatibility beachten
- Keine Breaking Changes ohne Migration Path

### 11.2 Kommunikation

- Commit-Messages sind Dokumentation
- PR-Descriptions vollständig
- Blocking Issues sofort kommunizieren
- Assumptions validieren

---

## 12. Arbeitsweise

### 12.1 Keine Spekulationen

- **Faktenbasiert:** Nur implementieren was verifiziert ist
- **Keine Annahmen:** Bei Unklarheit nachfragen oder recherchieren
- **Kein Raten:** Code muss auf Wissen basieren, nicht auf Vermutungen
- **Validieren:** Jeden Ansatz vor Implementation prüfen

### 12.2 Verifikation

- Änderungen vor Commit lokal testen
- Edge Cases durchdenken und abdecken
- Regressions-Risiko bewerten
- Bei Unsicherheit: lieber nachfragen

---

## 13. Moderne Standards

### 13.1 Technologie-Stack

- Aktuelle, stabile Versionen verwenden
- LTS-Versionen bevorzugen
- Security-Updates zeitnah einspielen
- Deprecated Features aktiv ersetzen

### 13.2 Patterns & Practices

- Industry Best Practices befolgen
- Etablierte Design Patterns nutzen
- Anti-Patterns vermeiden
- Clean Code Prinzipien

### 13.3 Skalierbarkeit

- Horizontal skalierbare Architekturen
- Stateless Design wo möglich
- Asynchrone Verarbeitung für lange Operationen
- Resource Limits definieren

---

## 14. Stabilität & Robustheit

### 14.1 Fehlertoleranz

- Graceful Degradation implementieren
- Circuit Breaker bei externen Abhängigkeiten
- Retry-Strategien mit Exponential Backoff
- Timeouts für alle externen Calls

### 14.2 Observability

- Structured Logging
- Metrics für kritische Pfade
- Health Checks implementieren
- Tracing bei verteilten Systemen

### 14.3 Resilienz

- Keine Single Points of Failure
- Fallback-Strategien definieren
- Chaos Engineering Mindset
- Disaster Recovery berücksichtigen

---

## 15. Qualitätssicherung

### 15.1 Definition of Done

- Code kompiliert fehlerfrei
- Alle Tests grün
- Keine Linting-Fehler
- Security-Scan bestanden
- Code Review abgeschlossen
- Dokumentation aktualisiert

### 15.2 Metriken

- Code Coverage > 80% für kritische Pfade
- Keine kritischen Security-Findings
- Performance-Benchmarks eingehalten
- Technische Schulden dokumentiert

---

## 16. Effizienz & Lean Development

### 16.1 Maximaler Output, Minimaler Aufwand

- **80/20 Regel:** Fokus auf das Wesentliche
- **Automation First:** Wiederkehrende Tasks automatisieren
- **Reuse vor Rebuild:** Bestehende Lösungen nutzen
- **MVP Mindset:** Erst funktionieren, dann optimieren

### 16.2 Smarte Entscheidungen

- Pragmatismus über Dogmatismus
- Trade-offs bewusst abwägen
- Technical Debt kalkuliert eingehen
- Opportunity Cost berücksichtigen

### 16.3 Zeitmanagement

- Blocker sofort eskalieren
- Parallelisierbare Tasks identifizieren
- Quick Wins priorisieren
- Deep Work für komplexe Probleme

---

## 17. Zukunftsfähigkeit

### 17.1 Evolutionäres Design

- Erweiterbarkeit einplanen
- Modulare Architektur
- Versionierte APIs
- Feature Flags für Rollouts

### 17.2 Technologie-Radar

- Emerging Technologies beobachten
- Proof of Concepts vor Adoption
- Migration Paths definieren
- Vendor Lock-in minimieren

### 17.3 Nachhaltigkeit

- Wartbare Codebasis
- Wissenstransfer sicherstellen
- Dokumentierte Architektur-Entscheidungen (ADRs)
- Onboarding-freundliche Strukturen

---

## 18. Kernprinzipien

> **Schlank** - Kein Overhead, kein Bloat, nur das Nötige
>
> **Professionell** - Enterprise-Grade Qualität in jedem Commit
>
> **Performant** - Optimiert wo es zählt, effizient überall
>
> **Sicher** - Security by Design, nicht als Afterthought
>
> **Modern** - Aktuelle Standards, bewährte Patterns
>
> **Zukunftsfähig** - Heute bauen, morgen erweitern
>
> **Smart** - Clevere Lösungen, keine komplexen

---

*Diese Richtlinien sind verbindlich und werden bei jedem Review geprüft.*
