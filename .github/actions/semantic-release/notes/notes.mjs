#!/usr/bin/env node
// Decoupled changelog notes generator.
//
// Produces the same sectioned release notes semantic-release's
// @semantic-release/release-notes-generator used to emit, but built on the
// CURRENT conventional-changelog stack (writer@9 + parser@6 + conventionalcommits
// preset@10), pinned independently in this folder's package.json. This is invoked
// by @semantic-release/exec's generateNotesCmd; whatever it prints to stdout
// becomes nextRelease.notes.
//
// Usage: node notes.mjs <lastReleaseGitTag> <nextReleaseGitTag> <version>
//   - lastReleaseGitTag: empty on the very first release (no compare link then)
//
// Why we replicate the commit filter here: writer@9 no longer honours the
// preset's `hidden` flag, so we drop hidden types ourselves.
//
// These section titles are the ONLY ones that apply. A repository's own
// `presetConfig` for @semantic-release/release-notes-generator does not reach this
// script and never did - the plugin is reserved and not provided at all. The action
// warns when it finds one. See docs/workflows/semantic-release-config.md.

import { execFileSync } from 'node:child_process';
import { CommitParser } from 'conventional-commits-parser';
import { writeChangelogString } from 'conventional-changelog-writer';
import createPreset from 'conventional-changelog-conventionalcommits';

const [lastTag = '', nextTag = '', version = ''] = process.argv.slice(2);
const repoDir = process.env.GITHUB_WORKSPACE || process.cwd();

// Visible types are rendered; the rest are dropped (but breaking changes always
// surface — see filter). Titles and visibility follow what the repository configs
// had been asking for while the plugin that would have honoured them was inert:
// style and chore visible as UI/UX Improvements and Maintenance, refactor spelled
// out. Reader-facing changes and dependency bumps are things a release audience
// wants to see; docs, tests, build and CI churn is not.
//
// chore(release) commits are excluded further down regardless, so a visible chore
// section does not fill up with the pipeline's own release commits.
const TYPES = [
  { type: 'feat', section: '🚀 Features' },
  { type: 'fix', section: '🐛 Bug Fixes' },
  { type: 'perf', section: '⚡ Performance' },
  { type: 'revert', section: '⏪ Reverts' },
  { type: 'refactor', section: '♻️ Code Refactoring' },
  { type: 'style', section: '💄 UI/UX Improvements' },
  { type: 'chore', section: '🔧 Maintenance' },
  { type: 'docs', section: '📚 Documentation', hidden: true },
  { type: 'test', section: '🧪 Tests', hidden: true },
  { type: 'build', section: '🔨 Build', hidden: true },
  { type: 'ci', section: '👷 CI', hidden: true },
];
const VISIBLE = new Set(TYPES.filter((t) => !t.hidden).map((t) => t.type));

function git(args) {
  return execFileSync('git', ['-C', repoDir, ...args], {
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
  });
}

// Resolve host / owner / repository for links. Prefer the CI-provided values,
// fall back to the git remote so the same script works locally for verification.
function resolveRepo() {
  const serverUrl = (process.env.GITHUB_SERVER_URL || 'https://github.com').replace(/\/$/, '');
  let slug = process.env.GITHUB_REPOSITORY || '';
  if (!slug) {
    try {
      const remote = git(['remote', 'get-url', 'origin']).trim();
      const m = remote.match(/[/:]([^/:]+\/[^/]+?)(?:\.git)?$/);
      if (m) slug = m[1];
    } catch {
      /* no remote (e.g. detached CI checkout) — links degrade gracefully */
    }
  }
  const [owner = '', repository = ''] = slug.split('/');
  return { host: serverUrl, owner, repository, repoUrl: `${serverUrl}/${owner}/${repository}` };
}

const preset = await createPreset({ types: TYPES });
const parser = new CommitParser(preset.parser);

// Collect commits in range. First release (no lastTag) -> full history.
const range = lastTag ? `${lastTag}..HEAD` : 'HEAD';
const raw = git(['log', range, '--no-merges', '--format=%H%x1f%cI%x1f%B%x1e']);

const isBreaking = (c) =>
  (Array.isArray(c.notes) && c.notes.length > 0) || /^\w+(\([^)]*\))?!:/.test(c.header || '');

const commits = raw
  .split('\x1e')
  .map((r) => r.trim())
  .filter(Boolean)
  .map((rec) => {
    const [hash, cdate, ...rest] = rec.split('\x1f');
    const message = rest.join('\x1f').trim();
    return { ...parser.parse(message), hash: hash.trim(), committerDate: cdate.trim() };
  })
  // Skip the automated release commit; keep visible types + any breaking change.
  .filter((c) => !/^chore\(release\)/.test(c.header || ''))
  .filter((c) => VISIBLE.has(c.type) || isBreaking(c));

const { host, owner, repository, repoUrl } = resolveRepo();
const hasCompare = Boolean(lastTag && nextTag);
const date = new Date().toISOString().slice(0, 10);

const context = {
  version,
  host,
  owner,
  repository,
  repoUrl,
  commit: 'commit',
  issue: 'issues',
  date,
  previousTag: lastTag || undefined,
  currentTag: nextTag || undefined,
  linkCompare: hasCompare,
  linkReferences: true,
};

const notes = await writeChangelogString(commits, context, preset.writer);
process.stdout.write(notes);
