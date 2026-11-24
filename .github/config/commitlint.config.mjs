// ESM (.mjs) is required: wagoid/commitlint-github-action rejects a .js configFile
// outright - "'.js' extension is not allowed for the `configFile`, please use .mjs
// instead" - and it throws BEFORE its existsSync fallback, so the whole commitlint
// step errored on every run. See the rename in this commit.

// Dependabot writes the commit body itself: a "Bumps [pkg](url) ..." line plus
// release-note/compare links that pass 100 characters for any longer package
// name and cannot be wrapped. Only the header prefix is ours (dependabot.yml
// commit-message), so a Dependabot commit is skipped once its header has the
// conventional shape; a Dependabot commit without a prefix is still linted.
const DEPENDABOT_SIGNOFF = /^Signed-off-by: dependabot\[bot\] <support@github\.com>\s*$/m;
const CONVENTIONAL_HEADER = /^[a-z]+(\([^)]+\))?!?: \S/;

export default {
  extends: ['@commitlint/config-conventional'],
  ignores: [(message) => DEPENDABOT_SIGNOFF.test(message) && CONVENTIONAL_HEADER.test(message)],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // Neue Features
        'fix',      // Bug Fixes
        'docs',     // Dokumentation
        'style',    // Formatierung, keine Code-Änderungen
        'refactor', // Code-Refactoring ohne Bugfix oder Feature
        'test',     // Tests hinzufügen oder korrigieren
        'chore',    // Wartungsarbeiten
        'ci',       // CI/CD-Änderungen
        'build',    // Build-System oder externe Dependencies
        'revert',   // Zurücksetzen eines Commits
        'perf'      // Performance-Verbesserungen
      ]
    ],
    'type-case': [2, 'always', 'lower-case'],
    'type-empty': [2, 'never'],
    'scope-case': [2, 'always', 'lower-case'],
    'subject-case': [2, 'never', ['start-case', 'pascal-case', 'upper-case']],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 100],
    'body-leading-blank': [1, 'always'],
    'body-max-line-length': [2, 'always', 100],
    'footer-leading-blank': [1, 'always'],
    'footer-max-line-length': [2, 'always', 100]
  },
  helpUrl: 'https://github.com/conventional-changelog/commitlint/#what-is-commitlint'
};
