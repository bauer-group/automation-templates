#!/usr/bin/env node
// Extract the changelog "preamble" — everything above the first "## " release
// heading (title + intro text). Emitted so the action can pass it to
// @semantic-release/changelog as `changelogTitle`, which keeps it pinned at the
// top of the file while new entries are inserted below it.
//
// Usage: node preamble.mjs <changelogFile>
// Prints the preamble (trailing whitespace trimmed) to stdout, or nothing if the
// file is missing/empty or has no preamble.
import { readFileSync } from 'node:fs';

const file = process.argv[2];
let content = '';
try {
  content = readFileSync(file, 'utf8');
} catch {
  process.stdout.write('');
  process.exit(0);
}

const lines = content.split(/\r?\n/);
const firstEntry = lines.findIndex((l) => /^## /.test(l));
const preamble = (firstEntry === -1 ? content : lines.slice(0, firstEntry).join('\n')).replace(
  /\s+$/,
  ''
);
process.stdout.write(preamble);
