module.exports = {
  extends: ['@commitlint/config-conventional'],
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
