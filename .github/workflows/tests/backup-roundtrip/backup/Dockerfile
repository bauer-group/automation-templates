# Thin meta image on the central BackupHelper engine, built the same way the
# consumer repositories build theirs. The module builds it with --pull, so every
# self-test run exercises the newest engine release.
FROM ghcr.io/bauer-group/cs-backuphelper/backuphelper:latest

LABEL org.opencontainers.image.title="Backup round-trip fixture"
LABEL org.opencontainers.image.source="https://github.com/bauer-group/automation-templates"

# Inherit ENTRYPOINT, USER (uid 1000), ENV and HEALTHCHECK from the engine.
