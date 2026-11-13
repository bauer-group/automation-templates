#!/usr/bin/env bash
#
# Behavioural test for ../docker-maintenance-dependabot.yml.
#
# The workflow merges a Dependabot PR only after its CI has passed, without
# rulesets or required status checks:
#
#   guard  (id: guard) - GitHub Actions updates (never merged), required-
#                        workflows (empty: nothing is merged), update type
#                        against merge-update-types / allow-major (a minor
#                        update of 0.y.z and a patch update of 0.0.z count as
#                        major, per dependency), input validation
#   wait   (id: ci)    - checks that every commit is a verified Dependabot
#                        commit and that no changed file is under .github/,
#                        polls check runs, check suites, commit statuses
#                        and workflow runs of the PR head commit, leaves out its
#                        own runs, waits for a complete and quiet state, checks
#                        that every required workflow ran and passed, decides
#                        green / failed / not-tested / timeout / unreadable / ...
#   merge  (id: merge) - reads the PR again, optional approval of the checked
#                        commit (a rejection is only a notice), checks that the
#                        base branch is still at the commit CI tested the PR on
#                        (else: no merge, '@dependabot rebase' with the rebase
#                        token, once per head commit), then gh pr merge pinned
#                        to the head commit
#   release (id: release) - after a merge only: dispatches release-workflow on
#                        the base branch, finds its run (returned by the
#                        dispatch, or looked up), waits for it and fails the
#                        job unless it succeeded
#   base image handoff (ids: handoff-*) - after a merge into the default
#                        branch with release-workflow:
#                        reads the base image monitor config from the merge
#                        commit, the PR's changed files, resolves the entries
#                        (the resolve action's own body) and reads the
#                        linux/amd64 digests of the entries whose Dockerfile
#                        the PR changed - before the dispatch; after a
#                        release run that succeeded and cut a release
#                        containing the merge, records them as a git note
#                        (refs/notes/base-image-monitor) for the monitor -
#                        a real repository with a bare origin; never fails
#                        the job, never holds back the release
#   summary (id: summary) - Merge -> Release dispatched (run) -> Release result
#                        -> Base image handoff
#
# The handoff exists because the base image monitor released every Dependabot
# FROM bump a second time: it saw the new tag's digest differ from the one it
# had stored (the old tag's) - one needless production redeploy per bump.
# A missed base image security update is far worse than a redundant release,
# so everything the handoff cannot read or verify is left to the monitor.
#
# Without this, `gh pr merge --auto` on a branch without required checks merged
# at once - bauer-group/CS-BillingStack#12 three seconds after its label check
# went red. That PR was the redpanda 26.1 -> 26.2 bump: a semver-minor. The CI
# wait came with a patch-only default; it would have held #12 only because of
# that unrelated red label check - compose validation was green, the redpanda
# image build was skipped, and nothing in the CI started redpanda. Since
# 2026-11-08 the default merges minor updates too, once the required PR CI
# passed (the owner's decision); majors stay open, and a caller that needs
# patch-only sets merge-update-types: 'patch'. And "any passed check" is
# not a test: bauer-group/CI-GitHubRunner#13 had only GitGuardian (success) and
# CodeQL (neutral), CS-GitHubBackup#1 only notification and AI-summary jobs -
# their build workflows never ran, which is why the named required workflows
# must have passed. And a PR that changes CI is not tested by its CI: the PR's
# run of a changed workflow uses the PR's own version, and a changed push-only
# workflow never runs before the merge. GitHub does not stop such a merge -
# bauer-group/XPD-SonarQube#6, an actions/checkout bump of docker-release.yml
# alone, was merged by github-actions[bot] - which is why the module never
# merges a PR that changes CI.
#
# Each step body is extracted from the workflow at runtime rather than duplicated
# here and run the way a `shell: bash` step runs (-eo pipefail). `gh` is replaced
# by a stub that applies the step's real --jq filters (with jq) to API responses
# shaped like GitHub's, one response file per call so a case can change state
# between polls. `date` and `sleep` are replaced by a simulated clock, so the
# wait runs with its real intervals (30 s polls, 300 s settle time, 180 s quiet
# period) in no time, and a case can say at which second a check appears.
#
# Poll n happens at: n=1..11 -> 0, 30, ..., 300 s; then every 60 s up to 900 s
# (n=21); then every 180 s.
#
# Usage: bash .github/workflows/tests/docker-maintenance-dependabot.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../docker-maintenance-dependabot.yml"
ACTION_DIR="$(cd "$SCRIPT_DIR/../../actions/docker-base-image-resolve" 2>/dev/null && pwd)"
ACTION_FILE="$ACTION_DIR/action.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: workflow not found at $WORKFLOW_FILE"
  exit 1
fi
if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: the docker-base-image-resolve action was not found at $ACTION_FILE"
  exit 1
fi
if ! command -v jq > /dev/null; then
  echo "FATAL: jq is required to evaluate the steps' --jq filters"
  exit 1
fi
# The base image handoff: notes in a real repository, the real resolver.
for tool in git python3; do
  if ! command -v "$tool" > /dev/null; then
    echo "FATAL: $tool is required for the base image handoff cases"
    exit 1
  fi
done

extract_step() {
  awk -v id="        id: $1" '
    $0 == id { found = 1; next }
    found && /^        run: \|$/ { collecting = 1; next }
    collecting {
      if ($0 == "") { print ""; next }
      if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
      exit
    }
  ' "$WORKFLOW_FILE"
}

GUARD_BODY=$(extract_step guard)
CI_BODY=$(extract_step ci)
MERGE_BODY=$(extract_step merge)
RELEASE_BODY=$(extract_step release)
SUMMARY_BODY=$(extract_step summary)
HFILES_BODY=$(extract_step handoff-files)
HDIGESTS_BODY=$(extract_step handoff-digests)
HNOTE_BODY=$(extract_step handoff-note)
# The resolve action's step, which the handoff uses: a composite step,
# indented two less.
RESOLVE_BODY=$(awk '
  $0 == "      id: resolve" { found = 1; next }
  found && /^      run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^        /) { sub(/^        /, ""); print; next }
    exit
  }
' "$ACTION_FILE")
for step in GUARD_BODY CI_BODY MERGE_BODY RELEASE_BODY SUMMARY_BODY HFILES_BODY HDIGESTS_BODY HNOTE_BODY RESOLVE_BODY; do
  if [ -z "${!step}" ]; then
    echo "FATAL: could not extract the run block for $step from the workflow."
    echo "       The step was renamed, removed, or re-indented - update this test."
    exit 1
  fi
done

PASSED=0
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass() { echo "PASS $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL $1"; FAILED=$((FAILED + 1)); }

# --- static: what the steps must be wired to ------------------------------------
static_has() {
  if grep -qF -- "$2" "$WORKFLOW_FILE"; then pass "$1"; else fail "$1: '$2' not found"; fi
}
static_lacks() {
  if grep -qE -- "$2" "$WORKFLOW_FILE"; then fail "$1: '$2' found"; else pass "$1"; fi
}
# static_line <name> <line>: the workflow has exactly this line - a gate that
# is extended (`|| always()`, another condition) no longer matches.
static_line() {
  if grep -qxF -- "$2" "$WORKFLOW_FILE"; then pass "$1"; else fail "$1: line '$2' not found"; fi
}
# The step gates. The behavioural tests below run each step on its own, and
# the flow/ tests chain merge and release the way these gates do - in the
# harness. Only these exact lines hold the gates themselves.
static_line  "wait is gated by the guard"        "        if: steps.guard.outputs.ok == 'true'"
# shellcheck disable=SC2016 # literal workflow text
static_has   "guard reads required-workflows"    'REQUIRED_WORKFLOWS: ${{ inputs.required-workflows }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "guard reads the ecosystem"         'PACKAGE_ECOSYSTEM: ${{ steps.metadata.outputs.package-ecosystem }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "guard reads every dependency's versions" 'UPDATED_DEPENDENCIES_JSON: ${{ steps.metadata.outputs.updated-dependencies-json }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "summary shows a 0.x update counted as major" 'TYPE_NOTE: ${{ steps.guard.outputs.type-note }}'
static_has   "summary explains unreadable versions" 'versions-unreadable) DECISION='
# shellcheck disable=SC2016 # literal workflow text
static_has   "wait gets the checked list"        'REQUIRED: ${{ steps.guard.outputs.required }}'
static_line  "merge is gated by green CI"        "        if: steps.ci.outputs.result == 'green'"
# shellcheck disable=SC2016 # literal workflow text
static_has   "merge is pinned to the head"       '--match-head-commit "$HEAD_SHA"'
# shellcheck disable=SC2016 # literal workflow text
static_has   "approval is pinned to the head"    '-f commit_id="$HEAD_SHA"'
static_lacks "no gh pr review (it approves the latest commit)" 'gh pr review'
# The base CI tested the PR on is the first parent of the merge commit the
# event's runs checked out (github.sha, refs/pull/N/merge); the event's base
# is the fallback. The rebase command needs a token Dependabot accepts.
# shellcheck disable=SC2016 # literal workflow text
static_has   "merge reads the merge commit CI tested" 'TESTED_MERGE: ${{ github.sha }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "merge knows the event's base"     'EVENT_BASE: ${{ github.event.pull_request.base.sha }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "rebase token comes from the optional secret" 'REBASE_TOKEN: ${{ secrets.DEPENDABOT_REBASE_TOKEN }}'
static_has   "rebase token is declared optional"  '      DEPENDABOT_REBASE_TOKEN:'
if [ "$(grep -c 'secrets.DEPENDABOT_REBASE_TOKEN' "$WORKFLOW_FILE")" -eq 1 ]; then pass "rebase token reaches the merge step only"; else fail "rebase token used more than once"; fi
# shellcheck disable=SC2016 # literal workflow text
static_has   "own check run is passed in"        'OWN_CHECK_RUN_ID: ${{ job.check_run_id }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "own workflow run is passed in"     'RUN_ID: ${{ github.run_id }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "one run per PR"                    'group: docker-maintenance-dependabot-pr-${{ github.event.pull_request.number }}'
static_lacks "no native auto-merge"              'enable-pull-request-automerge|gh pr merge .*--auto'
# Declaring checks/statuses would make GitHub reject every caller that does not
# grant them; declaring only contents/pull-requests would take away the read
# access a private repository's caller grants. So: none at all.
static_lacks "no permissions of its own"         '^ *permissions:'
# The job timeout has to cover the longest allowed CI wait (60 min) and its
# last poll (3 min) and the merge (1); with release-workflow also finding the
# release run (2), the longest allowed release wait (180) and its last poll
# (1). Callers without release-workflow keep the shorter one.
# shellcheck disable=SC2016 # literal workflow text
TIMEOUTS=$(sed -n 's/^    timeout-minutes: ${{ inputs.release-workflow != '"''"' \&\& \([0-9]*\) || \([0-9]*\) }}$/\1 \2/p' "$WORKFLOW_FILE")
read -r TIMEOUT_RELEASE TIMEOUT_MERGE_ONLY <<< "$TIMEOUTS"
if [ -n "$TIMEOUT_RELEASE" ] && [ "$TIMEOUT_RELEASE" -ge 247 ]; then pass "job timeout with a release covers both waits ($TIMEOUT_RELEASE min)"; else fail "job timeout with a release '$TIMEOUT_RELEASE' < 247"; fi
if [ -n "$TIMEOUT_MERGE_ONLY" ] && [ "$TIMEOUT_MERGE_ONLY" -ge 64 ] && [ "$TIMEOUT_MERGE_ONLY" -lt "$TIMEOUT_RELEASE" ]; then pass "job timeout without a release covers the CI wait ($TIMEOUT_MERGE_ONLY min)"; else fail "job timeout without a release '$TIMEOUT_MERGE_ONLY'"; fi
if grep -qF "release-wait-minutes must be from 0 to 180" "$WORKFLOW_FILE"; then pass "release wait capped where the timeout expects it"; else fail "release-wait-minutes cap changed - check the job timeout"; fi
# A release is dispatched only after this run merged the PR.
static_line  "release only after a merge"        "        if: steps.merge.outputs.merged == 'true' && steps.guard.outputs.release-workflow != ''"
# shellcheck disable=SC2016 # literal workflow text
static_has   "release gets the merge commit"     'MERGE_COMMIT: ${{ steps.merge.outputs.merge-commit }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "release gets the checked file"     'RELEASE_WORKFLOW: ${{ steps.guard.outputs.release-workflow }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "run URL is a workflow output"      'value: ${{ jobs.maintenance.outputs.release-run-url }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "job exposes the run URL"           'release-run-url: ${{ steps.release.outputs.run-url }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "merged is a workflow output"       'value: ${{ jobs.maintenance.outputs.merged }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "job exposes merged"                'merged: ${{ steps.merge.outputs.merged }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "release result is a workflow output" 'value: ${{ jobs.maintenance.outputs.release-result }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "job exposes the release result"    'release-result: ${{ steps.release.outputs.result }}'
# One line per step: <id, else name> <continue-on-error> <timeout-minutes> <uses>
# A step starts at any "      - " line, whichever key comes first.
STEP_ATTRS=$(awk '
  function flush() { if (n) printf "%s\t%s\t%s\t%s\n", (id != "" ? id : (name != "" ? name : "<unnamed>")), coe, tmo, uses }
  /^      - / {
    flush(); n++; name = ""; id = ""; coe = "-"; tmo = "-"; uses = "-"; first = substr($0, 9)
    if (first ~ /^name: /) name = substr(first, 7)
    else if (first ~ /^id: /) id = substr(first, 5)
    else if (first ~ /^uses: /) uses = substr(first, 7)
    else if (first ~ /^continue-on-error: /) coe = substr(first, 20)
    next
  }
  n && /^        name: / { name = substr($0, 15) }
  n && /^        id: / { id = substr($0, 13) }
  n && /^        continue-on-error: / { coe = substr($0, 28) }
  n && /^        timeout-minutes: / { tmo = substr($0, 26) }
  n && /^        uses: / { uses = substr($0, 15) }
  END { flush() }
' "$WORKFLOW_FILE")
HANDOFF_STEPS="handoff-checkout handoff-files handoff-resolve handoff-login handoff-digests handoff-note"
# A failed release fails the job: no step may swallow its failure - but the
# base image handoff's, which must never fail the job.
got=$(awk -F'\t' '$2 != "-" { printf "%s%s", sep, $1; sep = " " }' <<< "$STEP_ATTRS")
if [ "$got" = "$HANDOFF_STEPS" ]; then pass "only the base image handoff continues on error"; else fail "steps with continue-on-error: '$got', want '$HANDOFF_STEPS'"; fi
# The same over the whole file, whatever the layout: one continue-on-error per
# handoff step, each at step level - none on the job, where it would hide a
# failed release.
got="$(grep -cE '^ *continue-on-error:' "$WORKFLOW_FILE") $(grep -cE '^        continue-on-error: true$' "$WORKFLOW_FILE")"
want="$(wc -w <<< "$HANDOFF_STEPS" | tr -d ' ')"
if [ "$got" = "$want $want" ]; then pass "continue-on-error only on the handoff steps (whole file)"; else fail "continue-on-error lines (all, step-level true): '$got', want '$want $want'"; fi
got=$(awk -F'\t' '$1 ~ /^handoff-/ && $2 != "true" { printf " %s", $1 }' <<< "$STEP_ATTRS")
if [ -z "$got" ]; then pass "every handoff step has continue-on-error: true"; else fail "handoff steps without continue-on-error: true:$got"; fi
# In the job's order: the handoff reads the digests between the merge and the
# release, and records them after the release.
got=$(awk -F'\t' '{ printf "%s%s", sep, $1; sep = " " }' <<< "$STEP_ATTRS")
want="metadata guard ci merge handoff-checkout handoff-files handoff-resolve handoff-login handoff-digests release handoff-note summary"
if [ "$got" = "$want" ]; then pass "step order: merge, handoff, release, note, summary"; else fail "step order '$got', want '$want'"; fi
# They delay the dispatch: each has a short timeout, and the job timeout
# covers them on top of the CI and release waits.
HANDOFF_MINUTES=$(awk -F'\t' '$1 ~ /^handoff-/ { if ($3 !~ /^[0-9]+$/) bad = 1; sum += $3 } END { print bad ? "x" : sum }' <<< "$STEP_ATTRS")
if [ "$HANDOFF_MINUTES" != x ] && [ -n "$TIMEOUT_RELEASE" ] && [ "$TIMEOUT_RELEASE" -ge $((255 + HANDOFF_MINUTES)) ]; then
  pass "every handoff step has a timeout, covered by the job timeout ($HANDOFF_MINUTES of $TIMEOUT_RELEASE min)"
else
  fail "handoff step timeouts '$HANDOFF_MINUTES' not covered by the job timeout '$TIMEOUT_RELEASE' (255 + them)"
fi
# The release step does not depend on the handoff: its gate is the line
# checked below, and nothing in it reads a handoff output.
got=$(awk '$0 == "        id: release" { found = 1; next } found && /^      - / { exit } found && /handoff/ { print }' "$WORKFLOW_FILE")
if [ -z "$got" ]; then pass "the release step reads nothing of the handoff"; else fail "the release step reads the handoff: $got"; fi
# The self filter keys on the job's display name and on the file name in the
# callers' referenced_workflows.
static_has   "self filter matches the job name"  'SELF_JOB_NAME: Docker Maintenance'
static_has   "job name is what the filter uses"  '    name: Docker Maintenance'
static_has   "module filter matches this file"   "contains(\"/.github/workflows/$(basename "$WORKFLOW_FILE")@\")"
# Only Dependabot's PRs, and only events Dependabot raised.
static_line  "job runs for Dependabot's PRs and events only" "    if: github.event.pull_request.user.login == 'dependabot[bot]' && github.actor == 'dependabot[bot]'"
# fetch-metadata's own author and signature checks stay on.
static_lacks "fetch-metadata verification is not skipped" 'skip-verification|skip-commit-verification'
# The job runs with a write token: nothing from the PR is checked out or run.
# The one checkout is the base image handoff's: the merge commit, after the
# merge (step order above), gated on it; read as data. git fetches nothing but
# the notes ref, and the checkout keeps its credentials for that ref's push.
got=$(awk -F'\t' '$4 ~ /^actions\/checkout@/ { printf "%s%s", sep, $1; sep = " " }' <<< "$STEP_ATTRS")
if [ "$got" = handoff-checkout ]; then pass "one checkout, the handoff's"; else fail "checkout steps: '$got'"; fi
# The same over the whole file, whatever the layout of a step.
got=$(grep -cE 'actions/checkout@' "$WORKFLOW_FILE")
if [ "$got" = 1 ]; then pass "one checkout in the whole file"; else fail "actions/checkout@ appears $got times, want 1"; fi
# ... and only after a merge into the default branch: the monitor checks that
# branch, and the contract promises notes on its merge commits only.
static_line  "the checkout runs only after a merge into the default branch" "        if: steps.merge.outputs.merged == 'true' && steps.guard.outputs.release-workflow != '' && inputs.base-image-config != '' && steps.merge.outputs.merge-commit != '' && github.event.pull_request.base.ref == github.event.repository.default_branch"
# shellcheck disable=SC2016 # literal workflow text
static_line  "the checkout is the merge commit"  '          ref: ${{ steps.merge.outputs.merge-commit }}'
static_line  "the checkout is shallow"           "          fetch-depth: 1"
static_lacks "the checkout keeps its credentials for the notes push" 'persist-credentials'
static_lacks "nothing is cloned or switched to"  'git (clone|checkout|switch)|submodules:|lfs:'
# shellcheck disable=SC2016 # literal workflow text
if [ "$(grep -c 'git fetch' "$WORKFLOW_FILE")" -eq 1 ] && grep -qF 'git fetch --quiet --no-tags origin "+$NOTES_REF:$NOTES_REF"' "$WORKFLOW_FILE"; then
  pass "git fetches the notes ref only"
else
  fail "git fetch of something else than the notes ref"
fi
# The handoff gates: each step only after the one before it decided to go on;
# the note only after a release that succeeded.
static_line  "handoff files after the checkout"  "        if: steps.handoff-checkout.outcome == 'success'"
static_line  "GHCR login only for GHCR images"   "        if: steps.handoff-files.outputs.go == 'true' && steps.handoff-files.outputs.ghcr == 'true'"
if [ "$(grep -cxF "        if: steps.handoff-files.outputs.go == 'true'" "$WORKFLOW_FILE")" -eq 2 ]; then pass "resolve and digests only when the files step goes on"; else fail "resolve/digests gates changed"; fi
static_line  "note only after a successful release" "        if: steps.release.outputs.result == 'success' && steps.handoff-digests.outputs.digests != ''"
# shellcheck disable=SC2016 # literal workflow text
static_line  "the resolver gets the changed entries" '          images: ${{ steps.handoff-files.outputs.entries }}'
static_line  "the resolve action is the monitor's" "        uses: bauer-group/automation-templates/.github/actions/docker-base-image-resolve@main"
# shellcheck disable=SC2016 # literal workflow text
static_has   "the digests step gets the changed variables" 'CHANGED_VARIABLES: ${{ steps.handoff-files.outputs.variables }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "the digests step gets the resolved tags" 'RESOLVED_IMAGES: ${{ steps.handoff-resolve.outputs.images }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "the note gets the digests"         'DIGESTS: ${{ steps.handoff-digests.outputs.digests }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "the note gets the time they were read" 'RECORDED_AT: ${{ steps.handoff-digests.outputs.recorded-at }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "the files step reads the config input" 'CONFIG_FILE: ${{ inputs.base-image-config }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "handoff result is a workflow output" 'value: ${{ jobs.maintenance.outputs.base-image-handoff }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "handoff images are a workflow output" 'value: ${{ jobs.maintenance.outputs.base-image-handoff-images }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "job exposes the handoff result" 'base-image-handoff: ${{ steps.handoff-note.outputs.result || steps.handoff-digests.outputs.result || steps.handoff-files.outputs.result }}'
# The default is the path every caller of the monitor uses.
got=$(awk '$0 == "      base-image-config:" { found = 1; next } found && /^        default: / { sub(/^        default: /, ""); gsub(/\047/, ""); print; exit } found && /^      [^ ]/ { exit }' "$WORKFLOW_FILE")
if [ "$got" = ".github/config/docker-base-image-monitor/base-images.json" ]; then pass "base-image-config defaults to the monitor's config"; else fail "base-image-config default '$got'"; fi
# The digest a check compares - byte for byte the filter of the monitor and
# of auto-maintenance: linux/amd64 without a variant, then any linux/amd64,
# an index without linux/amd64 the legacy pick.
WANT_FILTER='if .config.digest then
  .config.digest
elif .manifests then
  ([.manifests[] | select(.platform.os == "linux" and .platform.architecture == "amd64")]
    | (map(select((.platform.variant // "") == "")) + .) | first | .digest)
  // (.manifests | sort_by(.platform.architecture) | .[0].digest)
else
  empty
end'
got=$(awk "/^DIGEST_FILTER='\$/ { found = 1; next } found && /^'\$/ { exit } found { print }" <<< "$HDIGESTS_BODY")
if [ "$got" = "$WANT_FILTER" ]; then pass "the digest filter is the shared one, verbatim"; else fail "the digest filter differs from the shared one: $got"; fi
# Event data (PR title, branch, labels, ...) reaches the scripts only through
# env, never as an expression inside a run block, where it would become code.
EXPR_IN_RUN=$(awk '
  /^ *run: \|$/ { match($0, /^ */); ind = RLENGTH; inrun = 1; next }
  inrun {
    if ($0 ~ /^ *$/) next
    match($0, /^ */)
    if (RLENGTH <= ind) inrun = 0
    else if (index($0, "${{")) print NR ": " $0
  }
' "$WORKFLOW_FILE")
if [ -z "$EXPR_IN_RUN" ]; then pass "no expressions inside run blocks"; else fail "expressions inside run blocks: $EXPR_IN_RUN"; fi

# --- gh, date and sleep stubs -------------------------------------------------------
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
# gh api [--paginate] <path> --jq <filter>: answers from $FAKE/<kind>.<n>.json, n
# counting the calls per kind (the highest file is reused once n runs past it).
# A file holding HTTP403, HTTP404, HTTP422, HTTP500 or RATELIMIT simulates that
# error, NOCONTENT an answer without a body (HTTP 204). POST .../dispatches
# answers from $FAKE/dispatch.<n>.json the same way.
# gh api --method POST .../reviews, POST .../comments and gh pr merge: logged
# to $FAKE/calls; FAKE_REVIEW_FAIL / FAKE_COMMENT_FAIL / FAKE_MERGE_FAIL fail
# them. A comment's token goes to $FAKE/tokens. After gh pr merge the PR is
# read from $FAKE/prmerged.<n>.json - unless FAKE_MERGE_QUEUED: gh succeeds,
# but only adds the PR to a merge queue, and it stays open.
echo "$*" >> "$FAKE/calls"
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "merge" ]; then
  [ -n "${FAKE_MERGE_FAIL:-}" ] && { echo "X Pull request o/r#7 is not mergeable: the base branch policy prohibits the merge." >&2; exit 1; }
  [ -n "${FAKE_MERGE_QUEUED:-}" ] || : > "$FAKE/merged"
  exit 0
fi
[ "${1:-}" = "api" ] || { echo "unexpected gh call: $*" >&2; exit 2; }
shift
path="" filter="." method=GET
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) filter="$2"; shift 2 ;;
    --method) method="$2"; shift 2 ;;
    -f|-F) shift 2 ;;
    --paginate|--silent) shift ;;
    *) path="$1"; shift ;;
  esac
done
case "$method $path" in
  "POST repos/"*"/pulls/"*"/reviews")
    [ -n "${FAKE_REVIEW_FAIL:-}" ] && { echo "gh: GitHub Actions is not permitted to approve pull requests. (HTTP 422)" >&2; exit 1; }
    exit 0 ;;
  "POST repos/"*"/issues/"*"/comments")
    echo "${GH_TOKEN:-}" >> "$FAKE/tokens"
    [ -n "${FAKE_COMMENT_FAIL:-}" ] && { echo "gh: Bad credentials (HTTP 401)" >&2; exit 1; }
    exit 0 ;;
  "POST repos/"*"/actions/workflows/"*"/dispatches") kind=dispatch ;;
  "GET "*) kind="" ;;
  *) echo "unexpected gh api call: $*" >&2; exit 2 ;;
esac
[ -n "$kind" ] || case "$path" in
  repos/*/pulls/*/commits*)        kind=commits ;;
  repos/*/pulls/*/files*)          kind=files ;;
  repos/*/pulls/*)                 kind=pr; [ -f "$FAKE/merged" ] && kind=prmerged ;;
  repos/*/commits/*/check-runs*)   kind=runs ;;
  repos/*/commits/*/check-suites*) kind=suites ;;
  repos/*/commits/*/status\?*)     kind=status ;;
  repos/*/git/ref/heads/*)         kind=baseref ;;
  repos/*/git/commits/tested*)     kind=tested ;;
  repos/*/git/commits/*)           kind=gitcommit ;;
  repos/*/commits/*)               kind=commit ;;
  repos/*/issues/*/comments*)      kind=comments ;;
  repos/*/actions/runs\?*)         kind=actions ;;
  repos/*/actions/runs/*)          kind=release ;;
  repos/*/actions/workflows/*/runs\?*) kind=lookup ;;
  repos/*/releases/latest)         kind=latest ;;
  repos/*/compare/*)               kind=compare ;;
  *) echo "unexpected path: $path" >&2; exit 2 ;;
esac
n=$(( $(cat "$FAKE/$kind.count" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FAKE/$kind.count"
file="$FAKE/$kind.$n.json"
while [ ! -f "$file" ] && [ "$n" -gt 1 ]; do n=$((n - 1)); file="$FAKE/$kind.$n.json"; done
[ -f "$file" ] || { echo "no fixture for $kind" >&2; exit 2; }
case "$(cat "$file")" in
  HTTP403) echo "gh: Resource not accessible by integration (HTTP 403)" >&2; exit 1 ;;
  HTTP404) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  HTTP500) echo "gh: Server Error (HTTP 500)" >&2; exit 1 ;;
  HTTP422) echo "gh: Workflow does not have 'workflow_dispatch' trigger (HTTP 422)" >&2; exit 1 ;;
  HTTP422PARAM) printf 'gh: Invalid request.\n\n"return_run_details" is not a permitted key. (HTTP 422)\n' >&2; exit 1 ;;
  RATELIMIT) echo "gh: API rate limit exceeded for installation ID 1. (HTTP 403)" >&2; exit 1 ;;
  NOCONTENT) exit 0 ;;
esac
jq -r "$filter" < "$file"
STUB
# Simulated clock: `date +%s` prints $FAKE/clock, `sleep N` adds N to it.
cat > "$WORK/bin/date" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = "+%s" ] || { echo "unexpected date call: $*" >&2; exit 2; }
cat "$FAKE/clock"
STUB
cat > "$WORK/bin/sleep" <<'STUB'
#!/usr/bin/env bash
echo $(( $(cat "$FAKE/clock") + $1 )) > "$FAKE/clock"
STUB
chmod +x "$WORK/bin/gh" "$WORK/bin/date" "$WORK/bin/sleep"

# --- fixtures, shaped like GitHub's responses -------------------------------------
OWN=100
RUN=900
SELF="Auto-merge Dependabot PRs / Docker Maintenance"
MODULE_PATH="bauer-group/automation-templates/.github/workflows/docker-maintenance-dependabot.yml@main"
OTHER_PATH="bauer-group/automation-templates/.github/workflows/docker-build.yml@main"
# run <id> <suite> <status> <conclusion|-> <name>   (a check run)
run() {
  local c="null"; [ "$4" = "-" ] || c="\"$4\""
  printf '{"id":%s,"name":"%s","status":"%s","conclusion":%s,"check_suite":{"id":%s},"app":{"slug":"github-actions"}}' "$1" "$5" "$3" "$c" "$2"
}
# suite <id> <status> <conclusion|-> <check run count> <app>
suite() {
  local c="null"; [ "$3" = "-" ] || c="\"$3\""
  printf '{"id":%s,"status":"%s","conclusion":%s,"latest_check_runs_count":%s,"app":{"slug":"%s"}}' "$1" "$2" "$c" "$4" "$5"
}
# status <state> <context>
status() { printf '{"state":"%s","context":"%s"}' "$1" "$2"; }
# wfrun <id> <suite> <status> <conclusion|-> <workflow id> <event> <name> <calls this module: 1|0> [attempt] [head repository]
# Its workflow file is the name in lower case, spaces as dashes: "Docker
# Release" -> .github/workflows/docker-release.yml (GitHub's `path`).
wfrun() {
  local c="null" ref="$OTHER_PATH" file="${7,,}"; [ "$4" = "-" ] || c="\"$4\""; [ "$8" = "1" ] && ref="$MODULE_PATH"
  file=".github/workflows/${file// /-}.yml"
  printf '{"id":%s,"check_suite_id":%s,"status":"%s","conclusion":%s,"workflow_id":%s,"event":"%s","name":"%s","path":"%s","run_attempt":%s,"head_repository":{"full_name":"%s"},"referenced_workflows":[{"path":"%s","sha":"0"}]}' \
    "$1" "$2" "$3" "$c" "$5" "$6" "$7" "$file" "${9:-1}" "${10:-o/r}" "$ref"
}
join() { local IFS=,; echo "$*"; }

# A commit of the PR as GET pulls/{n}/commits returns it (verified: Dependabot
# commits are signed by GitHub).
DEPENDABOT_COMMIT='{"sha":"abc","author":{"login":"dependabot[bot]"},"commit":{"verification":{"verified":true}}}'
# A changed file as GET pulls/{n}/files returns it.
DOCKERFILE_CHANGE='{"filename":"src/Dockerfile","status":"modified"}'

OWN_RUN=$(run $OWN 10 in_progress - "$SELF")
OWN_SUITE=$(suite 10 in_progress - 1 github-actions)
OWN_WFRUN=$(wfrun $RUN 10 in_progress - 1 pull_request "Docker Maintenance" 1)
# The required workflow of most cases (REQUIRED below): .github/workflows/ci.yml,
# its jobs in check suite 20.
REQ_CI=".github/workflows/ci.yml"
CI_RUN=$(wfrun 20 20 in_progress - 2 pull_request "CI" 0)
CI_DONE=$(wfrun 20 20 completed success 2 pull_request "CI" 0)

# fixture <case dir> <kind> <n> <json items...>: the response from poll n on
fixture() {
  local dir="$1" kind="$2" n="$3"; shift 3
  case "$kind" in
    runs)    echo "{\"total_count\":$#,\"check_runs\":[$(join "$@")]}" > "$dir/runs.$n.json" ;;
    suites)  echo "{\"total_count\":$#,\"check_suites\":[$(join "$@")]}" > "$dir/suites.$n.json" ;;
    status)  echo "{\"state\":\"x\",\"statuses\":[$(join "$@")]}" > "$dir/status.$n.json" ;;
    actions) echo "{\"total_count\":$#,\"workflow_runs\":[$(join "$@")]}" > "$dir/actions.$n.json" ;;
  esac
}
raw() { echo "$3" > "$1/$2"; }

# A PR that changes src/Dockerfile, whose only check so far is this job, with
# the required CI workflow run done - its jobs (check runs in suite 20) are up
# to each case.
new_case() {
  local dir="$WORK/case-$1"
  mkdir -p "$dir/temp"
  : > "$dir/output"; : > "$dir/calls"; echo 0 > "$dir/clock"
  echo '{"state":"open","head":{"sha":"abc"}}' > "$dir/pr.1.json"
  echo "[$DEPENDABOT_COMMIT]" > "$dir/commits.1.json"
  echo "[$DOCKERFILE_CHANGE]" > "$dir/files.1.json"
  fixture "$dir" runs 1 "$OWN_RUN"
  fixture "$dir" suites 1 "$OWN_SUITE"
  fixture "$dir" status 1
  fixture "$dir" actions 1 "$OWN_WFRUN" "$CI_DONE"
  echo "$dir"
}

# check <name> <dir> <rc> <want rc> <key> <want> <annotation|-> [grep-in-log]
check() {
  local name="$1" dir="$2" rc="$3" want_rc="$4" key="$5" want="$6" annotation="$7" needle="${8:-}"
  local ok=true why="" got
  got=$(sed -n "s/^$key=//p" "$dir/output")
  [ "$rc" -eq "$want_rc" ] || { ok=false; why="$why exit $rc"; }
  [ "$got" = "$want" ] || { ok=false; why="$why $key='$got'"; }
  if [ "$annotation" = "-" ]; then
    grep -q '^::\(notice\|warning\|error\)' "$dir/log" && { ok=false; why="$why unexpected annotation"; }
  else
    grep -q "^::${annotation} " "$dir/log" || { ok=false; why="$why missing ::${annotation}"; }
  fi
  if [ -n "$needle" ]; then
    grep -qF -- "$needle" "$dir/log" "$dir/calls" || { ok=false; why="$why missing '$needle'"; }
  fi
  if [ "$ok" = true ]; then
    pass "$name"
  else
    fail "$name:$why"
    sed 's/^/     | /' "$dir/log"
  fi
}
# decided_at <name> <dir> <second>: the decision fell at that simulated second
decided_at() {
  local got; got=$(cat "$2/clock")
  if [ "$got" -eq "$3" ]; then pass "$1: decided at ${3}s"; else fail "$1: decided at ${got}s, want ${3}s"; fi
}
# listed <name> <dir> <text>: the job summary's check list has the line
listed() {
  if grep -qF -- "$3" "$2/temp/dependabot-ci-checks.md" 2>/dev/null; then pass "$1: lists '$3'"; else fail "$1: summary lacks '$3'"; fi
}
# logged / not_logged <name> <dir> <text>: the log has / does not have the text
logged() {
  if grep -qF -- "$3" "$2/log"; then pass "$1: log has '$3'"; else fail "$1: log lacks '$3'"; fi
}
not_logged() {
  if grep -qF -- "$3" "$2/log"; then fail "$1: log has '$3'"; else pass "$1: log lacks '$3'"; fi
}
calls_to() { grep -c -- "$2" "$1/calls"; }

# --- guard ----------------------------------------------------------------------
# dep <name> <previous version> <new version> <update type>: one dependency as
# dependabot/fetch-metadata (v3) lists it in updated-dependencies-json
dep() {
  printf '{"dependencyName":"%s","dependencyType":"direct:production","updateType":"%s","directory":"/","packageEcosystem":"docker","targetBranch":"main","prevVersion":"%s","newVersion":"%s","compatScore":0,"maintainerChanges":false,"dependencyGroup":"","alertState":"","ghsaId":"","cvss":0}' \
    "$1" "$4" "$2" "$3"
}
deps() { echo "[$(join "$@")]"; }

# guard_case <name> <update-type> <merge-update-types> <allow-major> <want rc> <ok> <reason> <annotation|-> [merge-method] [wait-minutes]
# required-workflows is $GUARD_REQUIRED, if set (also empty), else ci.yml;
# release-workflow is $GUARD_RELEASE (default empty), release-wait-minutes
# $GUARD_RELEASE_WAIT (default 60); the
# ecosystem is $GUARD_ECOSYSTEM, if set (also empty), else docker; the updated
# dependencies are $GUARD_DEPS, if set (also empty), else one 7.2.4 -> 7.2.5
# update of the given type (1.0.0 or later: the 0.x rule does not apply).
# $GUARD_PATH replaces PATH (to take jq away).
guard_case() {
  local name="$1" dir="$WORK/guard-$1"
  mkdir -p "$dir"; : > "$dir/output"
  ( cd "$dir" && PATH="${GUARD_PATH-$PATH}" GITHUB_OUTPUT="$dir/output" PACKAGE_ECOSYSTEM="${GUARD_ECOSYSTEM-docker}" \
      UPDATE_TYPE="$2" MERGE_UPDATE_TYPES="$3" ALLOW_MAJOR="$4" \
      UPDATED_DEPENDENCIES_JSON="${GUARD_DEPS-$(deps "$(dep redis 7.2.4 7.2.5 "$2")")}" \
      MERGE_METHOD="${9:-squash}" WAIT_MINUTES="${10:-60}" REQUIRED_WORKFLOWS="${GUARD_REQUIRED-$REQ_CI}" \
      RELEASE_WORKFLOW="${GUARD_RELEASE-}" RELEASE_WAIT_MINUTES="${GUARD_RELEASE_WAIT-60}" \
      bash --noprofile --norc -eo pipefail -c "$GUARD_BODY" ) > "$dir/log" 2>&1
  local rc=$?
  check "guard/$name" "$dir" "$rc" "$5" ok "$6" "$8"
  if [ "$5" -eq 0 ]; then
    local got; got=$(sed -n 's/^reason=//p' "$dir/output")
    [ "$got" = "$7" ] || fail "guard/$name: reason='$got', want '$7'"
  fi
}

P="version-update:semver-patch"
MI="version-update:semver-minor"
MA="version-update:semver-major"

# The default of merge-update-types, as the workflow declares it: what a
# caller that does not set the input gets.
DEFAULT_TYPES=$(awk '
  $0 == "      merge-update-types:" { found = 1; next }
  found && /^        default: / { sub(/^        default: /, ""); gsub(/\047/, ""); print; exit }
  found && /^      [^ ]/ { exit }
' "$WORKFLOW_FILE")
if [ "$DEFAULT_TYPES" = "patch,minor" ]; then
  pass "merge-update-types defaults to patch,minor - majors stay open"
else
  fail "merge-update-types default is '$DEFAULT_TYPES', want 'patch,minor'"
fi

# Default: patch and minor updates are merged (after the required CI passed),
# majors stay open. A caller that sets 'patch' keeps patch-only.
guard_case patch-default          "$P"  "$DEFAULT_TYPES"      false 0 true  patch                -
guard_case minor-default          "$MI" "$DEFAULT_TYPES"      false 0 true  minor                -
guard_case major-default          "$MA" "$DEFAULT_TYPES"      false 0 false update-type          notice
if grep -qF "Merged automatically: patch minor (input merge-update-types)" "$WORK/guard-major-default/log"; then pass "guard/major-default: notice names patch and minor"; else fail "guard/major-default: notice lacks 'patch minor'"; fi
guard_case patch-only-patch       "$P"  "patch"               false 0 true  patch                -
guard_case patch-only-minor       "$MI" "patch"               false 0 false update-type          notice
guard_case patch-only-major       "$MA" "patch"               false 0 false update-type          notice
guard_case allow-major-default    "$MA" "$DEFAULT_TYPES"      true  0 true  major                -
guard_case minor-opted-in         "$MI" "patch,minor"         false 0 true  minor                -
guard_case major-opted-in-spaces  "$MA" "patch, minor, major" false 0 true  major                -
guard_case case-insensitive       "$P"  "Patch"               false 0 true  patch                -
guard_case only-minor-not-patch   "$P"  "minor"               false 0 false update-type          notice
guard_case allow-major-major      "$MA" "patch"               true  0 true  major                -
guard_case allow-major-minor      "$MI" "patch"               true  0 true  minor                -
guard_case unknown-update-type    ""    "patch,minor,major"   false 0 false unknown-update-type  notice
guard_case bad-type               "$P"  "pach"                false 1 ""    ""                   error
guard_case empty-types            "$P"  ""                    false 1 ""    ""                   error
guard_case empty-types-allow-major "$MA" ""                   true  0 true  major                -
guard_case bad-merge-method       "$P"  "patch"               false 1 ""    ""                   error fast
guard_case wait-nine              "$P"  "patch"               false 1 ""    ""                   error squash 9
guard_case wait-ten               "$P"  "patch"               false 0 true  patch                -     squash 10
guard_case wait-too-long          "$P"  "patch"               false 1 ""    ""                   error squash 61
guard_case wait-not-a-number      "$P"  "patch"               false 1 ""    ""                   error squash abc

# required-workflows: empty means nothing is merged - a notice, the job stays
# green, and no wait (no runner minutes for a PR that cannot be merged).
GUARD_REQUIRED=""         guard_case required-empty        "$P"  "patch" false 0 false no-required-workflows notice
GUARD_REQUIRED=" , "      guard_case required-blank        "$P"  "patch" false 0 false no-required-workflows notice
GUARD_REQUIRED=""         guard_case required-empty-major  "$MA" "patch" true  0 false no-required-workflows notice
# The default merges minor updates only through the required CI as well.
GUARD_REQUIRED=""         guard_case required-empty-minor-default "$MI" "$DEFAULT_TYPES" false 0 false no-required-workflows notice
if grep -qF "required-workflows: .github/workflows/docker-release.yml" "$WORK/guard-required-empty/log"; then pass "guard/required-empty: notice says how to set it"; else fail "guard/required-empty: notice lacks the example"; fi
# Workflow files as GitHub names them in a run's `path`, directly in
# .github/workflows - anything else is a typo that would never match.
GUARD_REQUIRED="docker-release.yml"                       guard_case required-bare-name   "$P" "patch" false 1 "" "" error
GUARD_REQUIRED=".github/workflows/ci/build.yml"           guard_case required-subdirectory "$P" "patch" false 1 "" "" error
GUARD_REQUIRED=".github/workflows/ci.json"                guard_case required-not-yaml    "$P" "patch" false 1 "" "" error
GUARD_REQUIRED=$' .github/workflows/ci.yml ,\n\t.github/workflows/docker-release.yaml \n' \
                                                          guard_case required-list        "$P" "patch" false 0 true patch -
got=$(sed -n 's/^required=//p' "$WORK/guard-required-list/output")
if [ "$got" = ".github/workflows/ci.yml,.github/workflows/docker-release.yaml" ]; then pass "guard/required-list: normalized"; else fail "guard/required-list: required='$got'"; fi

# release-workflow: one workflow file directly in .github/workflows - its name
# goes into the dispatch URL. Checked before any decision, so a typo fails
# every run, not only the one that merges.
release_is() {
  local got; got=$(sed -n 's/^release-workflow=//p' "$WORK/guard-$1/output")
  if [ "$got" = "$2" ]; then pass "guard/$1: release-workflow '$2'"; else fail "guard/$1: release-workflow '$got', want '$2'"; fi
}
guard_case release-unset "$P" "patch" false 0 true patch -
release_is release-unset ""
GUARD_RELEASE=" .github/workflows/docker-release.yml "  guard_case release-set        "$P" "patch" false 0 true patch -
release_is release-set ".github/workflows/docker-release.yml"
GUARD_RELEASE=".github/workflows/Release_2.yaml"         guard_case release-yaml       "$P" "patch" false 0 true patch -
release_is release-yaml ".github/workflows/Release_2.yaml"
GUARD_RELEASE="   "                                      guard_case release-blank      "$P" "patch" false 0 true patch -
release_is release-blank ""
for bad in "docker-release.yml" ".github/workflows/ci/release.yml" ".github/workflows/release.json" ".github/workflows/.yml" \
           ".github/workflows/a.yml,.github/workflows/b.yml" ".github/workflows/my release.yml" ".github/workflows/../x.yml" \
           "x/.github/workflows/release.yml" ".github/workflows/release.yml?ref=x"; do
  name="release-invalid-${bad//[^A-Za-z0-9.-]/_}"
  GUARD_RELEASE="$bad" guard_case "$name" "$P" "patch" false 1 "" "" error
done
# Invalid even where nothing would be merged.
GUARD_ECOSYSTEM=github_actions GUARD_RELEASE="release.yml" guard_case release-invalid-actions-update "$P" "patch" false 1 "" "" error
# release-wait-minutes: 0 (do not wait) to 180 (the job timeout covers it).
GUARD_RELEASE_WAIT=0    guard_case release-wait-zero      "$P" "patch" false 0 true patch -
GUARD_RELEASE_WAIT=180  guard_case release-wait-180       "$P" "patch" false 0 true patch -
GUARD_RELEASE_WAIT=181  guard_case release-wait-too-long  "$P" "patch" false 1 "" "" error
GUARD_RELEASE_WAIT=abc  guard_case release-wait-not-a-number "$P" "patch" false 1 "" "" error
GUARD_RELEASE_WAIT=""   guard_case release-wait-empty     "$P" "patch" false 1 "" "" error
GUARD_RELEASE_WAIT=-5   guard_case release-wait-negative  "$P" "patch" false 1 "" "" error

# A GitHub Actions update changes the CI itself: never merged, whatever the
# update type and required-workflows say - and without a wait. fetch-metadata
# names the ecosystem as the branch name does: dependabot/github_actions/...
GUARD_ECOSYSTEM=github_actions                   guard_case actions-update             "$P"  "patch"             false 0 false ci-change notice
GUARD_ECOSYSTEM=github_actions                   guard_case actions-update-all-types   "$MA" "patch,minor,major" false 0 false ci-change notice
GUARD_ECOSYSTEM=github_actions                   guard_case actions-update-minor-default "$MI" "$DEFAULT_TYPES" false 0 false ci-change notice
GUARD_ECOSYSTEM=github_actions GUARD_REQUIRED="" guard_case actions-update-no-required "$P"  "patch"             false 0 false ci-change notice
if grep -qF "GitHub Actions updates change the CI itself" "$WORK/guard-actions-update/log"; then pass "guard/actions-update: notice says why"; else fail "guard/actions-update: notice lacks the reason"; fi
# Invalid input is still an error for a GitHub Actions update.
GUARD_ECOSYSTEM=github_actions                   guard_case actions-update-bad-input   "$P"  "pach"              false 1 ""    ""        error
# Other ecosystems, or none known: the wait checks the changed files.
GUARD_ECOSYSTEM=docker_compose                   guard_case compose-update             "$P"  "patch"             false 0 true  patch     -
GUARD_ECOSYSTEM=""                               guard_case ecosystem-unknown          "$P"  "patch"             false 0 true  patch     -

# --- guard: versions below 1.0.0 -------------------------------------------------
# SemVer 4: a 0.y.z version may break on any change. Dependabot (and
# fetch-metadata) call 0.3.1 -> 0.4.0 semver-minor; like npm's caret ranges the
# guard counts a minor update of a 0.y.z version and a patch update of a 0.0.z
# version as major. Per dependency, the strictest one decides.
# type_note_is <name> <want>: the guard's type-note output
type_note_is() {
  local got; got=$(sed -n 's/^type-note=//p' "$WORK/guard-$1/output")
  if [ "$got" = "$2" ]; then pass "guard/$1: type-note '$2'"; else fail "guard/$1: type-note '$got', want '$2'"; fi
}
glogged()     { logged "guard/$1" "$WORK/guard-$1" "$2"; }
gnot_logged() { not_logged "guard/$1" "$WORK/guard-$1" "$2"; }

# 0.3.1 -> 0.4.0: what a caller that merges minor updates used to merge.
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") guard_case zero-minor-minor-allowed  "$MI" "patch,minor"       false 0 false update-type notice
glogged     zero-minor-minor-allowed "0.x minor treated as major: lib 0.3.1 -> 0.4.0"
glogged     zero-minor-minor-allowed "semver-major update (0.x minor treated as major: lib 0.3.1 -> 0.4.0) - left open for review"
type_note_is zero-minor-minor-allowed "0.x minor treated as major: lib 0.3.1 -> 0.4.0"
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") guard_case zero-minor-all-allowed    "$MI" "patch,minor,major" false 0 true  major       -
glogged     zero-minor-all-allowed "0.x minor treated as major: lib 0.3.1 -> 0.4.0"
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") guard_case zero-minor-allow-major    "$MI" "patch"             true  0 true  major       -
# The default (patch,minor) merges no 0.x minor update.
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") guard_case zero-minor-default        "$MI" "$DEFAULT_TYPES"    false 0 false update-type notice
glogged     zero-minor-default "0.x minor treated as major: lib 0.3.1 -> 0.4.0"
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") guard_case zero-minor-patch-only     "$MI" "patch"             false 0 false update-type notice
# 0.0.3 -> 0.0.4: merged as a patch before the 0.x rule - now left open.
GUARD_DEPS=$(deps "$(dep lib 0.0.3 0.0.4 "$P")")  guard_case zero-zero-patch-default   "$P"  "$DEFAULT_TYPES"    false 0 false update-type notice
glogged     zero-zero-patch-default "0.0.x patch treated as major: lib 0.0.3 -> 0.0.4"
type_note_is zero-zero-patch-default "0.0.x patch treated as major: lib 0.0.3 -> 0.0.4"
GUARD_DEPS=$(deps "$(dep lib 0.0.3 0.0.4 "$P")")  guard_case zero-zero-patch-all       "$P"  "patch,minor,major" false 0 true  major       -
GUARD_DEPS=$(deps "$(dep lib 0.0.3 0.1.0 "$MI")") guard_case zero-zero-minor           "$MI" "patch,minor"       false 0 false update-type notice
glogged     zero-zero-minor "0.x minor treated as major: lib 0.0.3 -> 0.1.0"
# Within the caret range: a patch update of 0.y.z (y > 0) stays a patch.
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.3.2 "$P")")  guard_case zero-patch-stays-patch    "$P"  "patch"             false 0 true  patch       -
gnot_logged zero-patch-stays-patch "treated as major"
type_note_is zero-patch-stays-patch ""
# Already major, and 1.0.0 or later: as Dependabot reported.
GUARD_DEPS=$(deps "$(dep lib 0.9.2 1.0.0 "$MA")") guard_case zero-to-one-major         "$MA" "patch,minor"       false 0 false update-type notice
gnot_logged zero-to-one-major "treated as major"
GUARD_DEPS=$(deps "$(dep lib 1.2.3 1.3.0 "$MI")") guard_case one-minor-stays-minor     "$MI" "patch,minor"       false 0 true  minor       -
GUARD_DEPS=$(deps "$(dep lib 1.0.0 1.0.1 "$P")")  guard_case one-zero-zero-patch       "$P"  "patch"             false 0 true  patch       -
# Plain X.Y.Z, with a leading v and a pre-release or build suffix.
GUARD_DEPS=$(deps "$(dep redpanda v0.3.1 v0.4.0 "$MI")")                guard_case zero-minor-v-prefix  "$MI" "patch,minor" false 0 false update-type notice
glogged     zero-minor-v-prefix "0.x minor treated as major: redpanda v0.3.1 -> v0.4.0"
GUARD_DEPS=$(deps "$(dep lib 0.3.1-rc.1 0.4.0+build.7 "$MI")")         guard_case zero-minor-suffixes  "$MI" "patch,minor" false 0 false update-type notice
GUARD_DEPS=$(deps "$(dep app 0.3.1-alpine3.20 0.4.0-alpine3.20 "$MI")") guard_case zero-minor-tag-variant "$MI" "patch,minor" false 0 false update-type notice
# Anything else keeps the type Dependabot reported - and never fails the job:
# a two-part tag, a tag like 18-alpine, leading zeros, a date, a digest, a
# missing version, a new version that is not plain semver.
for v in "0.3 0.4" "0.3-alpine 0.4-alpine" "0.03.1 0.04.0" "2024-01-15 2024-02-01" "- 0.4.0" "0.3.1 0.4" "0.3.1 0.4.0.1" "V0.3.1 V0.4.0" "0.3.1 sha256:0123abcd"; do
  read -r prev new <<< "$v"; [ "$prev" = "-" ] && prev=""
  name="not-plain-semver-${prev:-none}-$new"; name="${name//[^A-Za-z0-9.-]/_}"
  GUARD_DEPS=$(deps "$(dep lib "$prev" "$new" "$MI")") guard_case "$name" "$MI" "patch,minor" false 0 true minor -
  gnot_logged "$name" "treated as major"
done
GUARD_DEPS='[{"dependencyName":"lib","updateType":"version-update:semver-minor","prevVersion":null}]' \
                                                 guard_case versions-missing          "$MI" "patch,minor"       false 0 true  minor       -
# The update type of each dependency is the one fetch-metadata lists for it;
# without one (no versions it could compare) the dependency changes nothing.
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "")")   guard_case dependency-type-unknown   "$MI" "patch,minor"       false 0 true  minor       -

# A grouped update: the strictest dependency decides.
GUARD_DEPS=$(deps "$(dep redis 7.2.4 7.2.5 "$P")" "$(dep lib 0.3.1 0.4.0 "$MI")") \
                                                 guard_case group-zero-minor          "$MI" "patch,minor"       false 0 false update-type notice
glogged     group-zero-minor "0.x minor treated as major: lib 0.3.1 -> 0.4.0"
gnot_logged group-zero-minor "redis 7.2.4 -> 7.2.5"
GUARD_DEPS=$(deps "$(dep redis 7.2.4 7.3.0 "$MI")" "$(dep lib 0.0.3 0.0.4 "$P")") \
                                                 guard_case group-zero-zero-patch     "$MI" "patch,minor"       false 0 false update-type notice
glogged     group-zero-zero-patch "0.0.x patch treated as major: lib 0.0.3 -> 0.0.4"
GUARD_DEPS=$(deps "$(dep a 0.3.1 0.4.0 "$MI")" "$(dep b 0.0.1 0.0.2 "$P")") \
                                                 guard_case group-two-zero            "$MI" "patch,minor,major" false 0 true  major       -
type_note_is group-two-zero "0.x minor treated as major: a 0.3.1 -> 0.4.0; 0.0.x patch treated as major: b 0.0.1 -> 0.0.2"
GUARD_DEPS=$(deps "$(dep redis 7.2.4 7.2.5 "$P")" "$(dep lib 0.3.1 0.3.2 "$P")") \
                                                 guard_case group-within-caret        "$P"  "patch"             false 0 true  patch       -
GUARD_DEPS=$(deps "$(dep redis 7.2.4 7.2.5 "$P")" "$(dep app 0.3-alpine 0.4-alpine "$MI")") \
                                                 guard_case group-not-plain-semver    "$MI" "patch,minor"       false 0 true  minor       -

# Per-dependency data that cannot be read: the 0.x rule cannot be checked, so
# the PR is left open (fail closed) - a notice, the job stays green, no wait.
GUARD_DEPS="not json"  guard_case deps-not-json  "$MI" "patch,minor" false 0 false versions-unreadable notice
glogged     deps-not-json "so it cannot be shown that this is not a 0.x update, which may break on any change. Review and merge it by hand."
GUARD_DEPS=""          guard_case deps-empty     "$P"  "patch"       false 0 false versions-unreadable notice
GUARD_DEPS="[]"        guard_case deps-none      "$P"  "patch"       false 0 false versions-unreadable notice
GUARD_DEPS='{"a":1}'   guard_case deps-not-list  "$P"  "patch"       false 0 false versions-unreadable notice
mkdir -p "$WORK/nojq"
printf '#!/usr/bin/env bash\necho "jq: command not found" >&2\nexit 127\n' > "$WORK/nojq/jq"; chmod +x "$WORK/nojq/jq"
GUARD_PATH="$WORK/nojq:$PATH" GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") \
                       guard_case jq-missing     "$MI" "patch,minor" false 0 false versions-unreadable notice

# The order stays: a GitHub Actions update, a missing required-workflows and
# an unknown update type decide before the versions are looked at.
GUARD_ECOSYSTEM=github_actions GUARD_DEPS=$(deps "$(dep actions/checkout 0.3.1 0.4.0 "$MI")") \
                                                 guard_case zero-actions-update       "$MI" "patch,minor"       false 0 false ci-change notice
GUARD_REQUIRED="" GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") \
                                                 guard_case zero-required-empty       "$MI" "patch,minor"       false 0 false no-required-workflows notice
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "")")  guard_case zero-unknown-update-type  ""    "patch,minor,major" false 0 false unknown-update-type notice
gnot_logged zero-unknown-update-type "treated as major"

# --- wait for CI ----------------------------------------------------------------
# run_ci <dir> [VAR=value ...]   (REQUIRED: the guard's checked list)
run_ci() {
  local dir="$1"; shift
  ( cd "$dir" && env PATH="$WORK/bin:$PATH" FAKE="$dir" GITHUB_OUTPUT="$dir/output" RUNNER_TEMP="$dir/temp" \
      GH_TOKEN=test REPO=o/r PR_NUMBER=7 HEAD_SHA=abc RUN_ID=$RUN OWN_CHECK_RUN_ID=$OWN SELF_JOB_NAME="Docker Maintenance" \
      WAIT_MINUTES=60 REQUIRED="$REQ_CI" "$@" \
      bash --noprofile --norc -eo pipefail -c "$CI_BODY" ) > "$dir/log" 2>&1
}

# CI finishes at 30 s. Green needs 300 s since the start and 180 s without a
# change: the poll at 300 s.
D=$(new_case green-after-wait)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 in_progress - 1 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$CI_RUN"
fixture "$D" runs 2 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 2 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 2 "$OWN_WFRUN" "$CI_DONE"
run_ci "$D"; check ci/green-after-wait "$D" $? 0 result green - "checks: 1, passed: 1, pending: 0, failed: 0"
decided_at ci/green-after-wait "$D" 300
listed ci/green-after-wait "$D" "OK check: build (success)"
listed ci/green-after-wait "$D" "OK required: .github/workflows/ci.yml (run 20, attempt 1: success)"

# Everything was done before the job started (e.g. a re-run): the settle time
# still applies.
D=$(new_case done-before-start)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/done-before-start "$D" $? 0 result green -
decided_at ci/done-before-start "$D" 300

D=$(new_case failed-check)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed failure "🔍 Validate Base Image Labels")" "$(run 201 21 in_progress - build)"
run_ci "$D"; check ci/failed-check-stops-at-once "$D" $? 0 result failed notice "🔍 Validate Base Image Labels (failure)"
decided_at ci/failed-check-stops-at-once "$D" 0

D=$(new_case failed-status)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" status 1 "$(status failure ci/external)"
run_ci "$D"; check ci/failed-status "$D" $? 0 result failed notice "ci/external (failure)"

D=$(new_case status-pending-then-success)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" status 1 "$(status pending ci/external)"
fixture "$D" status 2 "$(status success ci/external)"
run_ci "$D"; check ci/status-pending-then-success "$D" $? 0 result green -
decided_at ci/status-pending-then-success "$D" 300

D=$(new_case timeout)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
run_ci "$D" WAIT_MINUTES=10; check ci/timeout "$D" $? 0 result timeout notice
decided_at ci/timeout "$D" 600

# 60 min of polling: 36 polls of 5 requests - a few PRs at once stay below the
# job token's 1,000 requests per hour and repository.
D=$(new_case poll-budget)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
run_ci "$D"; check ci/poll-budget-timeout "$D" $? 0 result timeout notice
decided_at ci/poll-budget-timeout "$D" 3600
POLLS=$(calls_to "$D" check-runs)
if [ "$POLLS" -le 36 ]; then pass "ci/poll-budget: $POLLS polls in 60 min"; else fail "ci/poll-budget: $POLLS polls in 60 min, want <= 36"; fi

# Nothing ran at all: the required workflow did not run - decided once the
# settle time is over (a workflow GitHub starts late is still waited for).
D=$(new_case nothing-ran)
fixture "$D" actions 1 "$OWN_WFRUN"
run_ci "$D"; check ci/nothing-ran "$D" $? 0 result not-tested notice "Required workflow .github/workflows/ci.yml did not run for this change - not tested"
decided_at ci/nothing-ran "$D" 300

# neutral and skipped are no failure, but nothing passed either. A workflow
# run whose jobs were all skipped concludes "skipped" (seen on
# bauer-group/CS-BackupHelper run 37917566835) - not a test.
D=$(new_case all-skipped)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed skipped deploy)" "$(run 201 21 completed neutral CodeQL)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 20 20 completed skipped 2 pull_request "CI" 0)"
run_ci "$D"; check ci/required-workflow-skipped "$D" $? 0 result not-tested notice ".github/workflows/ci.yml (run 20, attempt 1: skipped) - not tested"

D=$(new_case neutral-skipped)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed neutral lint)" "$(run 201 20 completed skipped deploy)" "$(run 202 20 completed success build)"
run_ci "$D"; check ci/neutral-and-skipped-pass "$D" $? 0 result green - "checks: 3, passed: 1"

# The race this wait is built for: build is done at 240 s, the settle time is
# over at 300 s - and at 360 s a check appears that was not there before (a
# code scanning result posted after its analysis job, a workflow GitHub started
# late). The quiet period has not passed (240 + 180 s), so it is waited for;
# done at 420 s, green at 420 + 180 s = 600 s. A wait with only the settle
# time would have merged at 300 s, before the check existed.
D=$(new_case late-check)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
fixture "$D" runs 9 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" runs 12 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 300 30 in_progress - CodeQL)"
fixture "$D" suites 12 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-advanced-security)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 300 30 completed success CodeQL)"
fixture "$D" suites 13 "$OWN_SUITE" "$(suite 30 completed success 1 github-advanced-security)"
run_ci "$D"; check ci/late-check-is-waited-for "$D" $? 0 result green - "checks: 2, passed: 2"
decided_at ci/late-check-is-waited-for "$D" 600
listed ci/late-check-is-waited-for "$D" "OK check: CodeQL (success)"

D=$(new_case late-check-fails)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
fixture "$D" runs 9 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" runs 12 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 300 30 in_progress - CodeQL)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 300 30 completed failure CodeQL)"
run_ci "$D"; check ci/late-check-failure-counts "$D" $? 0 result failed notice "CodeQL (failure)"
decided_at ci/late-check-failure-counts "$D" 420

# A result that arrives already finished (a status posted by an external
# service) also restarts the quiet period: changed at 150 s -> green at 330 s
# at the earliest, i.e. the poll at 360 s instead of 300 s.
D=$(new_case late-result-restarts-quiet)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" status 6 "$(status success codecov/patch)"
run_ci "$D"; check ci/late-result-restarts-quiet-period "$D" $? 0 result green - "checks: 2, passed: 2"
decided_at ci/late-result-restarts-quiet-period "$D" 360

# A workflow run that is queued shows in the workflow runs before it has any
# check run: pending until it is done at 420 s -> green at 600 s, not at 300 s
# on the strength of lint alone. Here it is the required workflow.
D=$(new_case queued-workflow-run)
fixture "$D" runs 1 "$OWN_RUN" "$(run 201 21 completed success lint)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 40 40 queued - 4 pull_request "Release" 0)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 201 21 completed success lint)" "$(run 400 40 completed success build)"
fixture "$D" suites 13 "$OWN_SUITE" "$(suite 40 completed success 1 github-actions)"
fixture "$D" actions 13 "$OWN_WFRUN" "$(wfrun 40 40 completed success 4 pull_request "Release" 0)"
run_ci "$D" REQUIRED=.github/workflows/release.yml; check ci/queued-workflow-run-is-waited-for "$D" $? 0 result green - "pending: 1"
decided_at ci/queued-workflow-run-is-waited-for "$D" 600

# The check suite of a workflow run whose jobs do not exist yet - and that
# the workflow runs do not list yet - keeps the wait going until it is done
# at 420 s.
D=$(new_case workflow-without-jobs-yet)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success labels)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 50 queued - 0 github-actions)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 200 20 completed success labels)" "$(run 500 50 completed success build)"
fixture "$D" suites 13 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 50 completed success 1 github-actions)"
run_ci "$D"; check ci/waits-for-workflow-without-jobs "$D" $? 0 result green - "checks: 2,"
decided_at ci/waits-for-workflow-without-jobs "$D" 600

# Without the workflow runs (private repository, no actions: read) nothing
# shows that the required workflows ran: closed at once, not after the wait.
D=$(new_case actions-not-readable)
raw "$D" actions.1.json HTTP403
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/workflow-runs-403-fails-closed "$D" $? 0 result unreadable notice "'actions: read'"
decided_at ci/workflow-runs-403-fails-closed "$D" 0
if [ "$(calls_to "$D" actions/runs)" -eq 1 ]; then pass "ci/workflow-runs-403-asked-once"; else fail "ci/workflow-runs-403-asked-once: $(calls_to "$D" actions/runs) calls"; fi

D=$(new_case actions-not-found)
raw "$D" actions.1.json HTTP404
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/workflow-runs-404-fails-closed "$D" $? 0 result unreadable notice "HTTP 404"

# Other runs of this module - another caller workflow, queued without a job yet
# or running - are not waited for.
D=$(new_case siblings-ignored)
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "Other caller / Docker Maintenance")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 31 queued - 0 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 30 30 in_progress - 3 pull_request "Actions Maintenance" 1)" "$(wfrun 31 31 queued - 3 pull_request "Actions Maintenance" 1)" "$CI_DONE"
run_ci "$D"; check ci/other-runs-of-this-module-ignored "$D" $? 0 result green - "checks: 1,"

# A workflow runs list without this run is not trusted (not complete yet): the
# job names decide which checks are this module's, and the required workflows
# count as pending until the list has this run.
D=$(new_case siblings-by-name)
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "Other caller / Docker Maintenance")" "$(run 400 40 queued - "$SELF")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 40 queued - 1 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$CI_DONE"
fixture "$D" actions 2 "$OWN_WFRUN" "$(wfrun 30 30 in_progress - 3 pull_request "Actions Maintenance" 1)" "$(wfrun 40 40 queued - 1 pull_request "Docker Maintenance" 1)" "$CI_DONE"
run_ci "$D"; check ci/other-runs-ignored-by-job-name "$D" $? 0 result green - "checks: 1, passed: 1, pending: 1, failed: 0"

D=$(new_case runs-without-own-run)
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "Other caller / Docker Maintenance")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$CI_DONE"
run_ci "$D" WAIT_MINUTES=10; check ci/runs-without-this-run-not-trusted "$D" $? 0 result timeout notice "checks: 1, passed: 1, pending: 1, failed: 0"
listed ci/runs-without-this-run-not-trusted "$D" "PENDING required: .github/workflows/ci.yml (the workflow runs do not list this run yet)"

# With the workflow runs known, the job name alone does not make a check this
# module's: a CI job that happens to be called "... / Docker Maintenance".
D=$(new_case name-outside-module)
fixture "$D" runs 1 "$OWN_RUN" "$(run 600 60 completed failure "Lint / Docker Maintenance")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 60 completed failure 1 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 60 60 completed failure 6 pull_request "Lint" 0)" "$CI_DONE"
run_ci "$D"; check ci/job-name-alone-is-not-this-module "$D" $? 0 result failed notice "Lint / Docker Maintenance (failure)"

D=$(new_case own-id-only)
fixture "$D" runs 1 "$(run $OWN 10 in_progress - "renamed job")" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/own-run-found-by-id "$D" $? 0 result green -

D=$(new_case rerun-newest-wins)
fixture "$D" runs 1 "$OWN_RUN" "$(run 201 20 completed success build)" "$(run 200 20 completed failure build)"
run_ci "$D"; check ci/re-run-newest-counts "$D" $? 0 result green -

D=$(new_case rerun-newest-fails)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 201 20 completed failure build)"
run_ci "$D"; check ci/re-run-newest-failure-counts "$D" $? 0 result failed notice

# GitHub returns the latest check run per name *per check suite* (verified:
# 9 Teams Notifications runs on one commit, same job names, all returned).
# Two workflows with a job called "build" are two checks; the newer one
# passing must not hide the older one failing.
D=$(new_case same-name-other-workflow)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed failure build)" "$(run 201 21 completed success build)"
run_ci "$D"; check ci/same-job-name-in-two-workflows "$D" $? 0 result failed notice "build (failure)"

D=$(new_case foreign-idle-suites)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 60 queued - 0 claude)" "$(suite 61 queued - 0 -)" "$(suite 62 completed stale 0 codecov)"
run_ci "$D"; check ci/idle-app-suites-ignored "$D" $? 0 result green -

D=$(new_case startup-failure)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 70 completed startup_failure 0 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$CI_DONE" "$(wfrun 70 70 completed startup_failure 7 pull_request_target "Issue AI Summary" 0)"
run_ci "$D"; check ci/startup-failure-counts "$D" $? 0 result failed notice "Issue AI Summary (pull_request_target, startup_failure)"

# The same seen from its check suite alone (the run not listed yet).
D=$(new_case startup-failure-suites-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 70 completed startup_failure 0 github-actions)"
run_ci "$D"; check ci/startup-failure-counts-from-suites "$D" $? 0 result failed notice "startup_failure, no job ran"

# A run cancelled by its concurrency group, replaced by a newer run of the same
# workflow for the same commit: it and its cancelled jobs are left out.
D=$(new_case cancelled-replaced)
fixture "$D" runs 1 "$OWN_RUN" "$(run 700 70 completed cancelled build)" "$(run 710 71 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 70 completed cancelled 1 github-actions)" "$(suite 72 completed cancelled 0 github-actions)" "$(suite 71 completed success 1 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 70 70 completed cancelled 5 pull_request "CI" 0)" "$(wfrun 72 72 completed cancelled 5 pull_request "CI" 0)" "$(wfrun 73 71 completed success 5 pull_request "CI" 0)"
run_ci "$D"; check ci/replaced-cancelled-run-ignored "$D" $? 0 result green - "checks: 1, passed: 1"
listed ci/replaced-cancelled-run-ignored "$D" "SKIP workflow: CI (pull_request, cancelled, replaced by a newer run)"

D=$(new_case cancelled-not-replaced)
fixture "$D" runs 1 "$OWN_RUN" "$(run 700 70 completed cancelled build)" "$(run 200 20 completed success lint)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 70 70 completed cancelled 5 pull_request "CI" 0)" "$(wfrun 20 20 completed success 2 pull_request "Lint" 0)"
run_ci "$D"; check ci/cancelled-run-fails "$D" $? 0 result failed notice "CI (pull_request, cancelled)"

# A cancelled suite whose run the workflow runs do not list cannot be told
# from a stopped run: failed.
D=$(new_case cancelled-suites-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 71 completed cancelled 0 github-actions)"
run_ci "$D"; check ci/cancelled-suite-fails-without-runs "$D" $? 0 result failed notice "cancelled, no job ran"

for c in cancelled timed_out action_required startup_failure stale some_new_value; do
  D=$(new_case "conclusion-$c")
  fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed "$c" build)" "$(run 201 21 completed success lint)"
  run_ci "$D"; check "ci/conclusion-$c-fails" "$D" $? 0 result failed notice "build ($c)"
done

D=$(new_case status-error)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" status 1 "$(status error ci/external)"
run_ci "$D"; check ci/status-error-fails "$D" $? 0 result failed notice "ci/external (error)"

D=$(new_case checks-unreadable)
raw "$D" runs.1.json HTTP403
run_ci "$D"; check ci/checks-403 "$D" $? 0 result unreadable notice "checks: read"

D=$(new_case statuses-unreadable)
raw "$D" status.1.json HTTP403
run_ci "$D"; check ci/statuses-403 "$D" $? 0 result unreadable notice "statuses: read"

D=$(new_case transient-error)
raw "$D" runs.1.json HTTP500
fixture "$D" runs 2 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/transient-error-retried "$D" $? 0 result green - "API error 1/3"

D=$(new_case actions-transient)
raw "$D" actions.1.json HTTP500
fixture "$D" actions 2 "$OWN_WFRUN" "$CI_DONE"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/workflow-runs-error-retried "$D" $? 0 result green - "API error 1/3"
if [ "$(calls_to "$D" actions/runs)" -gt 1 ]; then pass "ci/workflow-runs-asked-again-after-500"; else fail "ci/workflow-runs-asked-again-after-500"; fi

D=$(new_case rate-limit)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
raw "$D" status.1.json RATELIMIT
fixture "$D" status 2
run_ci "$D"; check ci/rate-limit-is-retried "$D" $? 0 result green - "API error 1/3"

D=$(new_case persistent-error)
raw "$D" runs.1.json HTTP500
run_ci "$D"; check ci/three-errors-give-up "$D" $? 0 result api-error warning

# Every commit of the PR must be a verified commit by Dependabot -
# fetch-metadata checks only the first one. Asked once per run.
D=$(new_case commits-checked-once)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/commits-checked-once "$D" $? 0 result green -
if [ "$(calls_to "$D" pulls/7/commits)" -eq 1 ]; then pass "ci/commits-asked-once"; else fail "ci/commits-asked-once: $(calls_to "$D" pulls/7/commits) calls"; fi
if [ "$(calls_to "$D" pulls/7/files)" -eq 1 ]; then pass "ci/changed-files-asked-once"; else fail "ci/changed-files-asked-once: $(calls_to "$D" pulls/7/files) calls"; fi

D=$(new_case foreign-commit)
echo "[$DEPENDABOT_COMMIT,{\"sha\":\"0123456789abcdef\",\"author\":{\"login\":\"mallory\"},\"commit\":{\"verification\":{\"verified\":true}}}]" > "$D/commits.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/commit-by-someone-else "$D" $? 0 result foreign-commits notice "0123456789ab (mallory, verified: true)"
decided_at ci/commit-by-someone-else "$D" 0

D=$(new_case unverified-commit)
echo '[{"sha":"abc","author":{"login":"dependabot[bot]"},"commit":{"verification":{"verified":false}}}]' > "$D/commits.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/unverified-commit "$D" $? 0 result foreign-commits notice "(dependabot[bot], verified: false)"

D=$(new_case unknown-author)
echo '[{"sha":"abc","author":null,"commit":{"verification":{"verified":true}}}]' > "$D/commits.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/commit-without-github-author "$D" $? 0 result foreign-commits notice "(-, verified: true)"

D=$(new_case pr-closed)
echo '{"state":"closed","head":{"sha":"abc"}}' > "$D/pr.1.json"
run_ci "$D"; check ci/pr-closed "$D" $? 0 result closed notice

# Merged before this run decided - by hand, or by the first attempt of a job
# that is re-run after its release failed: said with a warning, since a
# re-run neither merges nor releases, and the job turns green.
D=$(new_case pr-merged-before)
echo '{"state":"closed","merged":true,"head":{"sha":"abc"}}' > "$D/pr.1.json"
run_ci "$D"; check ci/pr-merged-before "$D" $? 0 result merged-before warning "re-running this job does not retry a release"
decided_at ci/pr-merged-before "$D" 0

# Dependabot rebased the PR during the wait: the run for the new commit decides.
D=$(new_case superseded)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
echo '{"state":"open","head":{"sha":"def"}}' > "$D/pr.4.json"
run_ci "$D"; check ci/new-head-commit "$D" $? 0 result superseded notice
decided_at ci/new-head-commit "$D" 90

# --- required workflows -----------------------------------------------------------
REQ_REL=".github/workflows/docker-release.yml"
REL_DONE=$(wfrun 50 50 completed success 5 pull_request "Docker Release" 0)

# B1 regression, the shape of bauer-group/CI-GitHubRunner#13 (semver-patch):
# GitGuardian passed, CodeQL neutral, nothing else - the build workflow has no
# pull_request trigger. Any-passed-check would have merged it at 300 s.
D=$(new_case b1-gitguardian-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 800 80 completed success "GitGuardian Security Checks")" "$(run 810 81 completed neutral CodeQL)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 80 completed success 1 gitguardian)" "$(suite 81 completed neutral 1 github-advanced-security)"
fixture "$D" actions 1 "$OWN_WFRUN"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/b1-only-gitguardian-passed-not-merged "$D" $? 0 result not-tested notice "Required workflow .github/workflows/docker-release.yml did not run for this change - not tested"
decided_at ci/b1-only-gitguardian-passed-not-merged "$D" 300
logged ci/b1-only-gitguardian-passed-not-merged "$D" "checks: 2, passed: 1, pending: 0, failed: 0"

# B1 regression, the shape of bauer-group/CS-GitHubBackup#1 (root Dockerfile,
# not in the release workflow's paths): Teams notification, AI summary and
# GitGuardian passed, all on pull_request.
D=$(new_case b1-notifications-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 820 82 completed success "Notify")" "$(run 821 82 completed skipped "Notify Teams (closed)")" \
  "$(run 830 83 completed success "Generate AI Summary")" "$(run 800 80 completed success "GitGuardian Security Checks")"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 82 completed success 2 github-actions)" "$(suite 83 completed success 1 github-actions)" "$(suite 80 completed success 1 gitguardian)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 82 82 completed success 8 pull_request "Pull Request Notifications" 0)" "$(wfrun 83 83 completed success 9 pull_request "AI Summary" 0)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/b1-only-notifications-passed-not-merged "$D" $? 0 result not-tested notice "docker-release.yml did not run for this change"
logged ci/b1-only-notifications-passed-not-merged "$D" "checks: 4, passed: 3, pending: 0, failed: 0"
listed ci/b1-only-notifications-passed-not-merged "$D" "UNTESTED required: .github/workflows/docker-release.yml did not run for this change"

# Runs of the required workflow that do not test this PR: a push run on the
# Dependabot branch, and a fork PR's pull_request run on the same commit.
D=$(new_case required-push-run-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 completed success 5 push "Docker Release" 0)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-push-run-does-not-count "$D" $? 0 result not-tested notice "docker-release.yml did not run for this change"

D=$(new_case required-fork-run-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 completed success 5 pull_request "Docker Release" 0 1 mallory/r)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-fork-pr-run-does-not-count "$D" $? 0 result not-tested notice "docker-release.yml did not run for this change"

# The required workflow appears late (GitHub started it with a delay): waited
# for, then green.
D=$(new_case required-late)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success lint)"
fixture "$D" runs 8 "$OWN_RUN" "$(run 200 20 completed success lint)" "$(run 500 50 in_progress - build)"
fixture "$D" actions 8 "$OWN_WFRUN" "$CI_DONE" "$(wfrun 50 50 in_progress - 5 pull_request "Docker Release" 0)"
fixture "$D" runs 10 "$OWN_RUN" "$(run 200 20 completed success lint)" "$(run 500 50 completed success build)"
fixture "$D" actions 10 "$OWN_WFRUN" "$CI_DONE" "$REL_DONE"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-workflow-started-late "$D" $? 0 result green -
decided_at ci/required-workflow-started-late "$D" 480

# The required workflow failed or was cancelled: failed at once.
for c in failure cancelled; do
  D=$(new_case "required-$c")
  fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed "$c" build)"
  fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 completed "$c" 5 pull_request "Docker Release" 0)"
  run_ci "$D" REQUIRED="$REQ_REL"; check "ci/required-workflow-$c" "$D" $? 0 result failed notice "Docker Release (pull_request, $c)"
  decided_at "ci/required-workflow-$c" "$D" 0
done

# Its pull_request run was cancelled and a push run of the same workflow
# replaced it: no failure, but the PR is still not tested.
D=$(new_case required-replaced-by-push)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed cancelled build)" "$(run 510 51 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 completed cancelled 5 pull_request "Docker Release" 0)" "$(wfrun 51 51 completed success 5 push "Docker Release" 0)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-replaced-by-push-run "$D" $? 0 result not-tested notice "docker-release.yml (run 50, attempt 1: cancelled) - not tested"

# Still running: the PR is not merged before it is done.
D=$(new_case required-running)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 in_progress - build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 in_progress - 5 pull_request "Docker Release" 0)"
run_ci "$D" REQUIRED="$REQ_REL" WAIT_MINUTES=10; check ci/required-workflow-still-running "$D" $? 0 result timeout notice
decided_at ci/required-workflow-still-running "$D" 600
listed ci/required-workflow-still-running "$D" "PENDING required: .github/workflows/docker-release.yml (run 50, attempt 1: in_progress)"

# A re-run: attempt 1 failed, attempt 2 runs and passes. The runs list shows
# the run with its latest attempt (seen on bauer-group/CS-ZAMMAD run
# 37835873163: run_attempt 2, same check suite), the new jobs are newer check
# runs in the same suite.
D=$(new_case required-rerun)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed failure build)" "$(run 501 50 in_progress - build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 in_progress - 5 pull_request "Docker Release" 0 2)"
fixture "$D" runs 3 "$OWN_RUN" "$(run 500 50 completed failure build)" "$(run 501 50 completed success build)"
fixture "$D" actions 3 "$OWN_WFRUN" "$(wfrun 50 50 completed success 5 pull_request "Docker Release" 0 2)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-rerun-latest-attempt-wins "$D" $? 0 result green -
decided_at ci/required-rerun-latest-attempt-wins "$D" 300
listed ci/required-rerun-latest-attempt-wins "$D" "OK required: .github/workflows/docker-release.yml (run 50, attempt 2: success)"

# Two runs of the required workflow for the commit (e.g. reopened): the newest
# counts - here it is still running, so the older success is not enough.
D=$(new_case required-newest-run)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed success build)" "$(run 520 52 in_progress - build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$REL_DONE" "$(wfrun 52 52 in_progress - 5 pull_request "Docker Release" 0)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 500 50 completed success build)" "$(run 520 52 completed success build)"
fixture "$D" actions 13 "$OWN_WFRUN" "$REL_DONE" "$(wfrun 52 52 completed success 5 pull_request "Docker Release" 0)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-newest-run-counts "$D" $? 0 result green -
decided_at ci/required-newest-run-counts "$D" 600
listed ci/required-newest-run-counts "$D" "OK required: .github/workflows/docker-release.yml (run 52, attempt 1: success)"

# Several required workflows: all of them must have passed.
D=$(new_case required-two-passed)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success lint)" "$(run 500 50 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$CI_DONE" "$REL_DONE"
run_ci "$D" REQUIRED="$REQ_CI,$REQ_REL"; check ci/required-two-both-passed "$D" $? 0 result green -
listed ci/required-two-both-passed "$D" "OK required: .github/workflows/ci.yml (run 20, attempt 1: success)"
listed ci/required-two-both-passed "$D" "OK required: .github/workflows/docker-release.yml (run 50, attempt 1: success)"

D=$(new_case required-two-one-missing)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success lint)"
run_ci "$D" REQUIRED="$REQ_CI,$REQ_REL"; check ci/required-two-one-missing "$D" $? 0 result not-tested notice "Required workflow .github/workflows/docker-release.yml did not run for this change - not tested"
not_logged ci/required-two-one-missing "$D" "ci.yml did not run"

# Without a required workflow the wait does not start (the guard stops first;
# the step is closed on its own too).
D=$(new_case required-none)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D" REQUIRED=""; check ci/no-required-workflow-not-merged "$D" $? 0 result not-tested notice "required-workflows"
if [ ! -s "$D/calls" ]; then pass "ci/no-required-workflow: no API call"; else fail "ci/no-required-workflow: $(wc -l < "$D/calls") API calls"; fi

# The required run passed, but its jobs are not listed (the check runs lag
# behind): nothing passed that shows it - left open.
D=$(new_case required-jobs-not-listed)
run_ci "$D"; check ci/required-passed-without-listed-jobs "$D" $? 0 result not-tested notice "No check passed"

# --- CI files ---------------------------------------------------------------------
# A PR like bauer-group/XPD-SonarQube#6 (dependabot/github_actions/actions/
# checkout-7), which changed only docker-release.yml - the required workflow,
# whose pull_request paths now include its own file. Its run uses the PR's own
# version and passes: it vouches for itself - left open at once, before any
# wait.
D=$(new_case ci-change-required-workflow)
echo '[{"filename":".github/workflows/docker-release.yml","status":"modified"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$REL_DONE"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/ci-change-required-workflow-not-merged "$D" $? 0 result ci-change notice "This PR changes CI files (.github/workflows/docker-release.yml)"
decided_at ci/ci-change-required-workflow-not-merged "$D" 0
if [ "$(calls_to "$D" check-runs)" -eq 0 ]; then pass "ci/ci-change: no CI read"; else fail "ci/ci-change: $(calls_to "$D" check-runs) CI reads"; fi

# A composite action changed together with a Dockerfile: only the CI file is
# named.
D=$(new_case ci-change-action)
echo "[$DOCKERFILE_CHANGE,{\"filename\":\".github/actions/setup/action.yml\",\"status\":\"modified\"}]" > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/ci-change-composite-action "$D" $? 0 result ci-change notice "CI files (.github/actions/setup/action.yml)"

# Moved out of .github/: the old path counts.
D=$(new_case ci-change-renamed)
echo '[{"filename":"ci/release.yml","status":"renamed","previous_filename":".github/workflows/release.yml"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/ci-change-renamed-out-of-github "$D" $? 0 result ci-change notice "CI files (.github/workflows/release.yml)"

# Two pages (gh --paginate applies the filter to each): a CI file on the
# second one counts too.
D=$(new_case ci-change-second-page)
printf '[%s]\n[{"filename":".github/workflows/ci.yml","status":"modified"}]\n' "$DOCKERFILE_CHANGE" > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/ci-change-on-second-page "$D" $? 0 result ci-change notice "CI files (.github/workflows/ci.yml)"

# Names that only contain .github, not under it: tested as usual.
D=$(new_case not-ci-similar-name)
echo '[{"filename":"docs/.github/notes.md","status":"modified"},{"filename":"src/.github.Dockerfile","status":"added"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/similar-names-are-no-ci-change "$D" $? 0 result green -

# No file listed, or 3000 - GitHub's maximum, so the list may be cut off: a
# CI change cannot be ruled out.
D=$(new_case files-none)
echo '[]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/no-changed-file-listed "$D" $? 0 result ci-change notice "could not be listed in full (0 listed)"

D=$(new_case files-cut-off)
jq -cn '[range(3000) | {filename: "src/f\(.)", status: "added"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/changed-files-cut-off "$D" $? 0 result ci-change notice "could not be listed in full (3000 listed)"

D=$(new_case files-2999)
jq -cn '[range(2999) | {filename: "src/f\(.)", status: "added"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/changed-files-below-the-limit "$D" $? 0 result green -

# The changed files not readable: closed at once. A server error is retried.
D=$(new_case files-unreadable)
raw "$D" files.1.json HTTP403
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/changed-files-403-fails-closed "$D" $? 0 result unreadable notice
decided_at ci/changed-files-403-fails-closed "$D" 0

D=$(new_case files-transient)
raw "$D" files.1.json HTTP500
echo "[$DOCKERFILE_CHANGE]" > "$D/files.2.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/changed-files-error-retried "$D" $? 0 result green - "API error 1/3"

D=$(new_case files-transient-ci-change)
raw "$D" files.1.json HTTP500
echo '[{"filename":".github/workflows/ci.yml","status":"modified"}]' > "$D/files.2.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/ci-change-after-an-error "$D" $? 0 result ci-change notice "CI files (.github/workflows/ci.yml)"

# --- approve and merge ------------------------------------------------------------
# The PR as read again right before merging: $dir/pr.<n>.json, ready by default.
# merge_commit_sha of an open PR is GitHub's test merge commit.
PR_READY='{"state":"open","head":{"sha":"abc"},"base":{"ref":"main"},"draft":false,"mergeable":true,"mergeable_state":"clean","merged":false,"merge_commit_sha":"t1"}'
# The PR as read back after the merge: merged as m1.
PR_MERGED='{"state":"closed","head":{"sha":"abc"},"base":{"ref":"main"},"draft":false,"mergeable":null,"mergeable_state":"unknown","merged":true,"merge_commit_sha":"m1"}'
APPROVAL="api --method POST repos/o/r/pulls/7/reviews -f event=APPROVE -f commit_id=abc --silent"
# The event's runs checked out tested0, the head commit abc merged onto base0
# (the event's base too), and base0 is the head of main (git/ref) - unchanged
# by default. After the merge the PR reads as merged, and its commit m1 sits
# on base0. The head commit abc was made at 10:00; the PR has no comments by
# default.
merge_dir() {
  local dir="$WORK/merge-$1"
  mkdir -p "$dir"; : > "$dir/output"; : > "$dir/calls"; : > "$dir/tokens"; echo 0 > "$dir/clock"
  echo "$PR_READY" > "$dir/pr.1.json"
  echo "$PR_MERGED" > "$dir/prmerged.1.json"
  tested_on "$dir" base0
  echo '{"ref":"refs/heads/main","object":{"sha":"base0","type":"commit"}}' > "$dir/baseref.1.json"
  echo '{"sha":"m1","parents":[{"sha":"base0"}]}' > "$dir/gitcommit.1.json"
  echo '{"sha":"abc","commit":{"committer":{"date":"2026-01-01T10:00:00Z"}}}' > "$dir/commit.1.json"
  echo '[]' > "$dir/comments.1.json"
  echo "$dir"
}
# merge_run <dir> <auto-approve> <merge-method> [VAR=value ...]
merge_run() {
  local dir="$1" approve="$2" method="$3"; shift 3
  ( cd "$dir" && env PATH="$WORK/bin:$PATH" FAKE="$dir" GITHUB_OUTPUT="$dir/output" \
      GH_TOKEN=test REPO=o/r PR_NUMBER=7 HEAD_SHA=abc BASE_REF=main TESTED_MERGE=tested0 EVENT_BASE=base0 REBASE_TOKEN= \
      AUTO_APPROVE="$approve" MERGE_METHOD="$method" "$@" \
      bash --noprofile --norc -eo pipefail -c "$MERGE_BODY" ) > "$dir/log" 2>&1
}
# tested_on <dir> <sha>: the merge commit tested0 the event's runs checked out
# is the head abc merged onto <sha>
tested_on() { printf '{"sha":"tested0","parents":[{"sha":"%s"},{"sha":"abc"}]}\n' "$2" > "$1/tested.1.json"; }
# moved_to <dir> <sha>: main is at <sha> now
moved_to() { printf '{"ref":"refs/heads/main","object":{"sha":"%s","type":"commit"}}\n' "$2" > "$1/baseref.1.json"; }
# comment <created_at> <login> <body> [author_association]: a comment on the
# PR, by an organization member unless said otherwise
comment() { printf '{"created_at":"%s","user":{"login":"%s"},"author_association":"%s","body":"%s"}' "$1" "$2" "${4:-MEMBER}" "$3"; }
# output_is <name> <dir> <key> <want>
output_is() {
  local got; got=$(sed -n "s/^$3=//p" "$2/output")
  if [ "$got" = "$4" ]; then pass "$1: $3 '$4'"; else fail "$1: $3 '$got', want '$4'"; fi
}
reason_is() {
  local got; got=$(sed -n 's/^reason=//p' "$2/output")
  if [ "$got" = "$3" ]; then pass "$1: reason $3"; else fail "$1: reason '$got', want '$3'"; fi
}
called() {
  if grep -qxF -- "$3" "$2/calls"; then pass "$1: called '$3'"; else fail "$1: '$3' not called"; fi
}
not_called() {
  if grep -qF -- "$3" "$2/calls"; then fail "$1: '$3' was called"; else pass "$1: no '$3'"; fi
}

# The approval names the checked commit: without commit_id GitHub approves the
# PR's latest commit, which could be one pushed after CI was checked.
D=$(merge_dir approve-and-merge); merge_run "$D" true squash
check merge/approve-and-merge "$D" $? 0 merged true -
reason_is merge/approve-and-merge "$D" merged
called merge/approve-and-merge "$D" "$APPROVAL"
called merge/approve-and-merge "$D" "pr merge 7 --repo o/r --squash --match-head-commit abc"

D=$(merge_dir approve-rejected); merge_run "$D" true squash FAKE_REVIEW_FAIL=1
check merge/approval-rejected-still-merges "$D" $? 0 merged true notice "not permitted to approve"

D=$(merge_dir no-approve); merge_run "$D" false squash
check merge/no-approve "$D" $? 0 merged true -
not_called merge/no-approve "$D" "pulls/7/reviews"

D=$(merge_dir rebase); merge_run "$D" true rebase
check merge/rebase "$D" $? 0 merged true -
called merge/rebase "$D" "pr merge 7 --repo o/r --rebase --match-head-commit abc"

D=$(merge_dir merge-rejected); merge_run "$D" true squash FAKE_MERGE_FAIL=1
check merge/merge-rejected "$D" $? 0 merged false warning "base branch policy prohibits the merge"
reason_is merge/merge-rejected "$D" merge-failed

# Merged in the meantime (by hand): nothing to merge or release - a warning.
D=$(merge_dir merged-before); echo '{"state":"closed","head":{"sha":"abc"},"base":{"ref":"main"},"draft":false,"mergeable":null,"mergeable_state":"unknown","merged":true}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/merged-before "$D" $? 0 merged false warning "re-running this job does not retry a release"
reason_is merge/merged-before "$D" merged-before
not_called merge/merged-before "$D" "pr merge"

# Re-read right before merging: whatever changed since the CI decision wins.
D=$(merge_dir closed); echo '{"state":"closed","head":{"sha":"abc"},"base":{"ref":"main"},"draft":false,"mergeable":null,"mergeable_state":"unknown"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/closed-meanwhile "$D" $? 0 merged false notice
reason_is merge/closed-meanwhile "$D" closed
not_called merge/closed-meanwhile "$D" "pulls/7/reviews"
not_called merge/closed-meanwhile "$D" "pr merge"

D=$(merge_dir new-head); echo '{"state":"open","head":{"sha":"def"},"base":{"ref":"main"},"draft":false,"mergeable":true,"mergeable_state":"clean"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/new-head-meanwhile "$D" $? 0 merged false notice "new head commit (def)"
reason_is merge/new-head-meanwhile "$D" superseded
not_called merge/new-head-meanwhile "$D" "pulls/7/reviews"
not_called merge/new-head-meanwhile "$D" "pr merge"

D=$(merge_dir draft); echo '{"state":"open","head":{"sha":"abc"},"base":{"ref":"main"},"draft":true,"mergeable":true,"mergeable_state":"draft"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/draft "$D" $? 0 merged false notice
reason_is merge/draft "$D" draft
not_called merge/draft "$D" "pr merge"

D=$(merge_dir conflict); echo '{"state":"open","head":{"sha":"abc"},"base":{"ref":"main"},"draft":false,"mergeable":false,"mergeable_state":"dirty"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/conflict "$D" $? 0 merged false notice "dirty"
reason_is merge/conflict "$D" not-mergeable
not_called merge/conflict "$D" "pulls/7/reviews"
not_called merge/conflict "$D" "pr merge"

# GitHub computes `mergeable` in the background (null until then).
D=$(merge_dir mergeability-computing)
echo '{"state":"open","head":{"sha":"abc"},"base":{"ref":"main"},"draft":false,"mergeable":null,"mergeable_state":"unknown"}' > "$D/pr.1.json"
echo "$PR_READY" > "$D/pr.3.json"
merge_run "$D" true squash
check merge/waits-for-mergeability "$D" $? 0 merged true -
READS=$(grep -c 'pulls/7 --jq \[.state' "$D/calls")
if [ "$READS" -eq 3 ] && [ "$(cat "$D/clock")" -eq 10 ]; then pass "merge/waits-for-mergeability: 3 reads, 10 s"; else fail "merge/waits-for-mergeability: $READS reads, $(cat "$D/clock") s"; fi

D=$(merge_dir mergeability-unknown)
echo '{"state":"open","head":{"sha":"abc"},"base":{"ref":"main"},"draft":false,"mergeable":null,"mergeable_state":"unknown"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/unknown-mergeability-merge-call-decides "$D" $? 0 merged true - "the merge call decides"
if [ "$(cat "$D/clock")" -eq 30 ]; then pass "merge/unknown-mergeability: gave up after 30 s"; else fail "merge/unknown-mergeability: $(cat "$D/clock") s"; fi

D=$(merge_dir pr-unreadable); raw "$D" pr.1.json HTTP500
merge_run "$D" true squash
check merge/pr-unreadable "$D" $? 0 merged false warning
not_called merge/pr-unreadable "$D" "pr merge"

# --- approve and merge: only the combination CI tested ------------------------------
# CI tested refs/pull/7/merge: the head merged onto base0. The head of main is
# read last before the merge call - after the approval, right before the merge.
D=$(merge_dir base-unchanged); merge_run "$D" true squash
check merge/base-unchanged-merges "$D" $? 0 merged true -
called merge/base-unchanged-merges "$D" "api repos/o/r/git/ref/heads/main --jq .object.sha"
ORDER=$(awk '/pulls\/7\/reviews/ { a = NR } /git\/ref\/heads\/main/ { b = NR } /^pr merge/ { c = NR } END { print (a < b && b < c) ? "ok" : a " " b " " c }' "$D/calls")
if [ "$ORDER" = ok ]; then pass "merge/base-checked-right-before-the-merge"; else fail "merge/base-checked-right-before-the-merge: lines $ORDER"; fi
output_is merge/base-unchanged-merges "$D" merge-commit m1
not_called merge/base-unchanged-merges "$D" "issues/7/comments"
# The tested base is read from the merge commit the event's runs checked out.
called merge/base-unchanged-merges "$D" "api repos/o/r/git/commits/tested0 --jq [.parents[].sha] | @tsv"

# That commit decides, not the event's base.sha. Where the two differ, its
# first parent is what CI tested: the event naming the newer base1 while CI
# tested base0 must not let a merge onto base1 through ...
D=$(merge_dir event-base-newer); moved_to "$D" base1
merge_run "$D" true squash EVENT_BASE=base1
check merge/event-base-newer-than-the-tested-one "$D" $? 0 merged false notice "main moved from base0 (tested by CI) to base1"
logged merge/event-base-newer-than-the-tested-one "$D" "The event names base1 as the base, but CI tested the PR on base0"
not_called merge/event-base-newer-than-the-tested-one "$D" "pr merge"
# ... and CI having tested base1 while the event names base0 is a merge.
D=$(merge_dir tested-base-newer); tested_on "$D" base1; moved_to "$D" base1
echo '{"sha":"m1","parents":[{"sha":"base1"}]}' > "$D/gitcommit.1.json"
merge_run "$D" true squash
check merge/tested-base-from-the-merge-commit "$D" $? 0 merged true - "main is at base1, the base CI tested the PR on."
# Not readable: nothing shows which base was tested - left open, unapproved.
D=$(merge_dir tested-merge-unreadable); raw "$D" tested.1.json HTTP500
merge_run "$D" true squash
check merge/tested-merge-unreadable "$D" $? 0 merged false warning "could not be read to tell which base it tested"
reason_is merge/tested-merge-unreadable "$D" api-error
not_called merge/tested-merge-unreadable "$D" "pulls/7/reviews"
not_called merge/tested-merge-unreadable "$D" "pr merge"
# A github.sha that is not the head merged onto a base (not a pull_request
# event): the event's base counts, as before.
D=$(merge_dir not-a-pr-merge); echo '{"sha":"tested0","parents":[{"sha":"base9"}]}' > "$D/tested.1.json"
merge_run "$D" true squash
check merge/no-pr-merge-commit-uses-the-event-base "$D" $? 0 merged true - "tested0 is not a merge of the head commit - the event's base base0 counts."

# An unrelated push moved main: not merged, CI runs again after a rebase. The
# command is posted with the rebase token - Dependabot refuses the job token.
D=$(merge_dir base-moved); moved_to "$D" base1
merge_run "$D" true squash REBASE_TOKEN=rebase-token
check merge/base-moved-not-merged "$D" $? 0 merged false notice "Asked Dependabot to rebase the PR"
reason_is merge/base-moved-not-merged "$D" base-moved
not_called merge/base-moved-not-merged "$D" "pr merge"
called merge/base-moved-not-merged "$D" "api --method POST repos/o/r/issues/7/comments -f body=@dependabot rebase --silent"
if [ "$(cat "$D/tokens")" = "rebase-token" ]; then pass "merge/base-moved: command posted with the rebase token"; else fail "merge/base-moved: posted with '$(cat "$D/tokens")'"; fi
output_is merge/base-moved-not-merged "$D" detail "main moved from base0 (tested by CI) to base1; rebase requested"

# Two Dependabot PRs: the first one's merge commit m0 moved main under the
# second, which CI tested on base0 - rebased and tested again, not merged.
D=$(merge_dir second-of-two); moved_to "$D" m0
merge_run "$D" true squash REBASE_TOKEN=rebase-token
check merge/second-of-two-prs-rebased "$D" $? 0 merged false notice "main moved from base0 (tested by CI) to m0"
not_called merge/second-of-two-prs-rebased "$D" "pr merge"
if [ "$(wc -l < "$D/tokens")" -eq 1 ]; then pass "merge/second-of-two-prs: one rebase command"; else fail "merge/second-of-two-prs: $(wc -l < "$D/tokens") commands"; fi

# Without the rebase token: a notice says how - no command the job token would
# have refused.
D=$(merge_dir base-moved-no-token); moved_to "$D" base1
merge_run "$D" true squash
check merge/base-moved-without-token "$D" $? 0 merged false notice "Comment '@dependabot rebase' on the PR"
logged merge/base-moved-without-token "$D" "Dependabot secret DEPENDABOT_REBASE_TOKEN"
not_called merge/base-moved-without-token "$D" "issues/7/comments"
not_called merge/base-moved-without-token "$D" "pr merge"
output_is merge/base-moved-without-token "$D" detail "main moved from base0 (tested by CI) to base1; rebase not requested (no DEPENDABOT_REBASE_TOKEN)"

# Once per head commit: a rebase or recreate command since the head commit was
# made is pending (a re-run of the job, a person who asked already).
for c in "@dependabot rebase" "@dependabot recreate"; do
  n="${c#@dependabot }"
  D=$(merge_dir "base-moved-requested-$n"); moved_to "$D" base1
  echo "[$(comment 2026-01-01T10:05:00Z karl "$c")]" > "$D/comments.1.json"
  merge_run "$D" true squash REBASE_TOKEN=rebase-token
  check "merge/base-moved-$n-already-requested" "$D" $? 0 merged false notice "already requested"
  not_called "merge/base-moved-$n-already-requested" "$D" "--method POST repos/o/r/issues/7/comments"
done
# A command from before the head commit was made (an older head), or one of
# github-actions[bot], which Dependabot refused, does not count.
D=$(merge_dir base-moved-old-request); moved_to "$D" base1
echo "[$(comment 2026-01-01T09:59:59Z karl "@dependabot rebase"),$(comment 2026-01-01T10:05:00Z "github-actions[bot]" "@dependabot rebase"),$(comment 2026-01-01T10:06:00Z karl "LGTM")]" > "$D/comments.1.json"
merge_run "$D" true squash REBASE_TOKEN=rebase-token
check merge/base-moved-stale-requests-ignored "$D" $? 0 merged false notice "Asked Dependabot to rebase the PR"
called merge/base-moved-stale-requests-ignored "$D" "api --method POST repos/o/r/issues/7/comments -f body=@dependabot rebase --silent"

# Who asked counts: Dependabot takes commands from users with push access
# only. The owner, a member or a collaborator asked - pending.
for a in OWNER COLLABORATOR; do
  D=$(merge_dir "base-moved-requested-by-$a"); moved_to "$D" base1
  echo "[$(comment 2026-01-01T10:05:00Z someone "@dependabot rebase" "$a")]" > "$D/comments.1.json"
  merge_run "$D" true squash REBASE_TOKEN=rebase-token
  check "merge/base-moved-requested-by-$a" "$D" $? 0 merged false notice "already requested"
  not_called "merge/base-moved-requested-by-$a" "$D" "--method POST repos/o/r/issues/7/comments"
done
# An outsider's command (a public repository), which Dependabot refuses, does
# not hold the PR back: the rebase is requested.
D=$(merge_dir base-moved-outsider-request); moved_to "$D" base1
echo "[$(comment 2026-01-01T10:05:00Z visitor "@dependabot rebase" CONTRIBUTOR),$(comment 2026-01-01T10:06:00Z drive-by "@dependabot recreate" NONE)]" > "$D/comments.1.json"
merge_run "$D" true squash REBASE_TOKEN=rebase-token
check merge/base-moved-outsider-request-ignored "$D" $? 0 merged false notice "Asked Dependabot to rebase the PR"
called merge/base-moved-outsider-request-ignored "$D" "api --method POST repos/o/r/issues/7/comments -f body=@dependabot rebase --silent"

# The head commit's date not readable: nothing tells which requests are
# older, so the rebase is requested - even with a request on the PR.
D=$(merge_dir base-moved-commit-unreadable); moved_to "$D" base1; raw "$D" commit.1.json HTTP500
echo "[$(comment 2026-01-01T10:05:00Z karl "@dependabot rebase")]" > "$D/comments.1.json"
merge_run "$D" true squash REBASE_TOKEN=rebase-token
check merge/base-moved-commit-date-unreadable "$D" $? 0 merged false notice "Asked Dependabot to rebase the PR"
logged merge/base-moved-commit-date-unreadable "$D" "Earlier rebase requests could not be read"
not_called merge/base-moved-commit-date-unreadable "$D" "issues/7/comments?per_page"

# Earlier requests not readable: requested anyway (a second command is harmless).
D=$(merge_dir base-moved-comments-unreadable); moved_to "$D" base1; raw "$D" comments.1.json HTTP500
merge_run "$D" true squash REBASE_TOKEN=rebase-token
check merge/base-moved-comments-unreadable "$D" $? 0 merged false notice "Asked Dependabot to rebase the PR"

# The command could not be posted (token expired): a warning, still green.
D=$(merge_dir base-moved-comment-fails); moved_to "$D" base1
merge_run "$D" true squash REBASE_TOKEN=rebase-token FAKE_COMMENT_FAIL=1
check merge/base-moved-rebase-request-fails "$D" $? 0 merged false warning "Bad credentials"
reason_is merge/base-moved-rebase-request-fails "$D" base-moved
not_called merge/base-moved-rebase-request-fails "$D" "pr merge"

# The PR's base branch was changed to another branch.
D=$(merge_dir base-ref-changed); echo "${PR_READY/\"ref\":\"main\"/\"ref\":\"develop\"}" > "$D/pr.1.json"
merge_run "$D" true squash
check merge/base-branch-changed "$D" $? 0 merged false notice "the base branch was changed from main to develop"
not_called merge/base-branch-changed "$D" "pr merge"

# The head of main not readable: nothing shows the combination was tested.
D=$(merge_dir base-unreadable); raw "$D" baseref.1.json HTTP500
merge_run "$D" true squash
check merge/base-unreadable "$D" $? 0 merged false warning "could not be read"
reason_is merge/base-unreadable "$D" api-error
not_called merge/base-unreadable "$D" "pr merge"

# A push in the moment between the base check and the merge call: merged, but
# the merge commit sits on another base - said loudly.
D=$(merge_dir landed-elsewhere); echo '{"sha":"m1","parents":[{"sha":"base9"}]}' > "$D/gitcommit.1.json"
merge_run "$D" true squash
check merge/landed-on-another-base "$D" $? 0 merged true warning "Merged onto an untested base"
output_is merge/landed-on-another-base "$D" detail "landed on base9, not on the tested base0"

# The PR is read back after the merge call. gh also succeeds when it only adds
# the PR to a merge queue: the PR is still open, and its merge_commit_sha t1 is
# GitHub's test merge - not merged by this run, nothing to release.
D=$(merge_dir merge-queued); merge_run "$D" true squash FAKE_MERGE_QUEUED=1
check merge/queued-is-not-merged "$D" $? 0 merged false warning "the PR is still not merged"
reason_is merge/queued-is-not-merged "$D" not-merged
output_is merge/queued-is-not-merged "$D" merge-commit ""
if [ "$(calls_to "$D" 'merge_commit_sha //')" -eq 3 ]; then pass "merge/queued-is-not-merged: read back 3 times"; else fail "merge/queued-is-not-merged: read back $(calls_to "$D" 'merge_commit_sha //') times"; fi
# A read that lags behind the merge is retried.
D=$(merge_dir merge-read-lags); echo "$PR_READY" > "$D/prmerged.1.json"; echo "$PR_MERGED" > "$D/prmerged.2.json"
merge_run "$D" true squash
check merge/read-back-lags "$D" $? 0 merged true -
output_is merge/read-back-lags "$D" merge-commit m1
# Not readable at all: gh reported the merge, so it counts - but the merge
# commit is unknown, and that is said.
D=$(merge_dir merge-read-fails); raw "$D" prmerged.1.json HTTP500
merge_run "$D" true squash
check merge/read-back-fails "$D" $? 0 merged true warning "could not be read back"
output_is merge/read-back-fails "$D" merge-commit ""
# The base the merge landed on is not looked up without the merge commit.
not_called merge/read-back-fails "$D" ".parents[0].sha"

# --- release ------------------------------------------------------------------------
# The merge commit m1 is on main; release-workflow is docker-release.yml. The
# dispatch answers with run 555 (return_run_details) by default; the run is
# queued, then in progress - each case says when and how it completes. The
# clock starts at 2025-10-09T08:53:20Z, so runs created since 08:51:20Z count.
REL_WF=".github/workflows/docker-release.yml"
DISPATCH="api --method POST repos/o/r/actions/workflows/docker-release.yml/dispatches -f ref=main -F return_run_details=true"
RUN_555="https://github.com/o/r/actions/runs/555"
# relrun <status> <conclusion|->: the run as GET actions/runs/{id} returns it
relrun() {
  local c="null"; [ "$2" = "-" ] || c="\"$2\""
  printf '{"id":555,"event":"workflow_dispatch","head_sha":"m1","status":"%s","conclusion":%s,"html_url":"%s"}\n' "$1" "$c" "$RUN_555"
}
# looked <id> <head sha> <created at>: a run as the workflow's runs list has it
looked() { printf '{"id":%s,"event":"workflow_dispatch","head_sha":"%s","created_at":"%s","html_url":"https://github.com/o/r/actions/runs/%s"}' "$1" "$2" "$3" "$1"; }
release_dir() {
  local dir="$WORK/release-$1"
  mkdir -p "$dir"; : > "$dir/output"; : > "$dir/calls"; echo 1760000000 > "$dir/clock"
  printf '{"workflow_run_id":555,"run_url":"https://api.github.com/repos/o/r/actions/runs/555","html_url":"%s"}\n' "$RUN_555" > "$dir/dispatch.1.json"
  relrun queued - > "$dir/release.1.json"
  relrun in_progress - > "$dir/release.2.json"
  echo '{"total_count":0,"workflow_runs":[]}' > "$dir/lookup.1.json"
  echo "$dir"
}
# release_run <dir> [VAR=value ...]
release_run() {
  local dir="$1"; shift
  ( cd "$dir" && env PATH="$WORK/bin:$PATH" FAKE="$dir" GITHUB_OUTPUT="$dir/output" GITHUB_SERVER_URL=https://github.com \
      GH_TOKEN=test REPO=o/r BASE_REF=main MERGE_COMMIT=m1 RELEASE_WORKFLOW="$REL_WF" WAIT_MINUTES=60 "$@" \
      bash --noprofile --norc -eo pipefail -c "$RELEASE_BODY" ) > "$dir/log" 2>&1
}
# waited <name> <dir> <seconds>: the step ended that many seconds after it started
waited() {
  local got; got=$(( $(cat "$2/clock") - 1760000000 ))
  if [ "$got" -eq "$3" ]; then pass "$1: ended after ${3}s"; else fail "$1: ended after ${got}s, want ${3}s"; fi
}

# Dispatched on the base branch with run details, the run waited for: green.
D=$(release_dir success); relrun completed success > "$D/release.4.json"
release_run "$D"; check release/success "$D" $? 0 result success -
called release/success "$D" "$DISPATCH"
output_is release/success "$D" run-url "$RUN_555"
output_is release/success "$D" run-id 555
not_called release/success "$D" "actions/workflows/docker-release.yml/runs"
waited release/success "$D" 90
if [ "$(calls_to "$D" "actions/runs/555")" -eq 4 ]; then pass "release/success: 4 polls"; else fail "release/success: $(calls_to "$D" "actions/runs/555") polls"; fi

# Anything but success fails the job and names the run.
for c in failure cancelled timed_out startup_failure action_required skipped neutral; do
  D=$(release_dir "conclusion-$c"); relrun completed "$c" > "$D/release.3.json"
  release_run "$D"; check "release/$c-fails-the-job" "$D" $? 1 result failed error "release run $RUN_555 concluded '$c'"
  output_is "release/$c-fails-the-job" "$D" conclusion "$c"
  # The fix it names: re-running all jobs or starting a new run finds the
  # version the failed run may have created and skips its image.
  logged "release/$c-fails-the-job" "$D" "re-run the failed jobs of that run (gh run rerun 555 --failed) - not all jobs, and not a new run"
  logged "release/$c-fails-the-job" "$D" "Run $REL_WF by hand only if the run failed before its release job."
done

# Still running at the deadline: failed, with the run named.
D=$(release_dir timeout)
release_run "$D" WAIT_MINUTES=15; check release/still-running-at-the-deadline "$D" $? 1 result timeout error "was still in_progress after 15 min"
waited release/still-running-at-the-deadline "$D" 900
logged release/still-running-at-the-deadline "$D" "$RUN_555"

# release-wait-minutes 0: dispatched and reported, not waited for.
D=$(release_dir no-wait)
release_run "$D" WAIT_MINUTES=0; check release/wait-zero-does-not-wait "$D" $? 0 result not-waited notice "$RUN_555"
not_called release/wait-zero-does-not-wait "$D" "actions/runs/555"
output_is release/wait-zero-does-not-wait "$D" run-url "$RUN_555"

# A GitHub that answers 204 without run details: the run is looked up - a
# workflow_dispatch run of the workflow on main, created since the dispatch,
# on the merge commit. A run on another commit and one created before do not
# count.
D=$(release_dir lookup); echo NOCONTENT > "$D/dispatch.1.json"
echo "{\"workflow_runs\":[$(looked 570 other 2025-10-09T08:53:30Z),$(looked 560 m1 2025-10-09T08:40:00Z)]}" > "$D/lookup.2.json"
echo "{\"workflow_runs\":[$(looked 570 other 2025-10-09T08:53:30Z),$(looked 556 m1 2025-10-09T08:53:25Z),$(looked 560 m1 2025-10-09T08:40:00Z)]}" > "$D/lookup.3.json"
printf '{"id":556,"status":"completed","conclusion":"success","html_url":"https://github.com/o/r/actions/runs/556"}\n' > "$D/release.1.json"
release_run "$D"; check release/run-looked-up "$D" $? 0 result success - "looking it up"
output_is release/run-looked-up "$D" run-id 556
output_is release/run-looked-up "$D" run-url "https://github.com/o/r/actions/runs/556"
called release/run-looked-up "$D" "api repos/o/r/actions/workflows/docker-release.yml/runs?event=workflow_dispatch&branch=main&created=%3E%3D2025-10-09T08:51:20Z&per_page=20 --jq .workflow_runs[] | [.id, .head_sha, .created_at, .html_url] | @tsv"
if [ "$(calls_to "$D" "docker-release.yml/runs?")" -eq 3 ]; then pass "release/run-looked-up: found on the 3rd lookup"; else fail "release/run-looked-up: $(calls_to "$D" "docker-release.yml/runs?") lookups"; fi

# Another base branch: dispatched there, and its name encoded in the lookup.
D=$(release_dir lookup-branch); echo NOCONTENT > "$D/dispatch.1.json"
echo "{\"workflow_runs\":[$(looked 556 m1 2025-10-09T08:53:25Z)]}" > "$D/lookup.1.json"
relrun completed success > "$D/release.1.json"
release_run "$D" BASE_REF=release/1.x; check release/lookup-on-another-branch "$D" $? 0 result success -
called release/lookup-on-another-branch "$D" "api --method POST repos/o/r/actions/workflows/docker-release.yml/dispatches -f ref=release/1.x -F return_run_details=true"
if grep -qF "runs?event=workflow_dispatch&branch=release%2F1.x&created=" "$D/calls"; then pass "release/lookup-on-another-branch: branch encoded"; else fail "release/lookup-on-another-branch: branch not encoded"; fi

# Not found within 2 min: its result cannot be confirmed - red; without a wait
# only a warning.
D=$(release_dir not-found); echo NOCONTENT > "$D/dispatch.1.json"
release_run "$D"; check release/run-not-found "$D" $? 1 result not-found error "was not found within 2 min"
waited release/run-not-found "$D" 120
D=$(release_dir not-found-no-wait); echo NOCONTENT > "$D/dispatch.1.json"
release_run "$D" WAIT_MINUTES=0; check release/run-not-found-without-wait "$D" $? 0 result not-found warning "was not found within 2 min"
D=$(release_dir no-merge-commit); echo NOCONTENT > "$D/dispatch.1.json"
release_run "$D" MERGE_COMMIT=; check release/no-merge-commit-no-lookup "$D" $? 1 result not-found error "without the merge commit it cannot be looked up"
not_called release/no-merge-commit-no-lookup "$D" "docker-release.yml/runs?"

# The dispatch is refused: red, with the cause named - no wait.
D=$(release_dir dispatch-403); echo HTTP403 > "$D/dispatch.1.json"
release_run "$D"; check release/dispatch-403-names-the-permission "$D" $? 1 result dispatch-failed error "grant 'actions: write'"
if [ "$(calls_to "$D" "/dispatches")" -eq 1 ]; then pass "release/dispatch-403: not retried"; else fail "release/dispatch-403: $(calls_to "$D" "/dispatches") dispatches"; fi
not_called release/dispatch-403-names-the-permission "$D" "actions/runs/"
output_is release/dispatch-403-names-the-permission "$D" detail "the job token may not start workflows - grant 'actions: write' in the calling workflow's permissions"
# A 422 is tried once more without return_run_details (a GitHub that does not
# know the parameter may say so in other words); a second 422 is the trigger.
D=$(release_dir dispatch-422); echo HTTP422 > "$D/dispatch.1.json"
release_run "$D"; check release/dispatch-422-names-the-trigger "$D" $? 1 result dispatch-failed error "it needs an 'on: workflow_dispatch' trigger"
if [ "$(calls_to "$D" "/dispatches")" -eq 2 ]; then pass "release/dispatch-422: tried once without run details"; else fail "release/dispatch-422: $(calls_to "$D" "/dispatches") dispatches"; fi
called release/dispatch-422-names-the-trigger "$D" "api --method POST repos/o/r/actions/workflows/docker-release.yml/dispatches -f ref=main"
not_called release/dispatch-422-names-the-trigger "$D" "docker-release.yml/runs?"
D=$(release_dir dispatch-404); echo HTTP404 > "$D/dispatch.1.json"
release_run "$D"; check release/dispatch-404-names-the-file "$D" $? 1 result dispatch-failed error "$REL_WF was not found on main"

# A GitHub that does not know return_run_details (an older GHES): dispatched
# again without it, the run looked up.
D=$(release_dir unknown-parameter); echo HTTP422PARAM > "$D/dispatch.1.json"; echo NOCONTENT > "$D/dispatch.2.json"
echo "{\"workflow_runs\":[$(looked 556 m1 2025-10-09T08:53:25Z)]}" > "$D/lookup.1.json"
printf '{"id":556,"status":"completed","conclusion":"success","html_url":"https://github.com/o/r/actions/runs/556"}\n' > "$D/release.1.json"
release_run "$D"; check release/dispatch-without-run-details "$D" $? 0 result success - "looking it up"
called release/dispatch-without-run-details "$D" "api --method POST repos/o/r/actions/workflows/docker-release.yml/dispatches -f ref=main"

# A server error or a rate limit is retried; three in a row give up. A rate
# limit refused the request - retried at once. After a server error the run
# may exist all the same: looked for first, so a retry never starts a second
# release run.
D=$(release_dir dispatch-retried); echo HTTP500 > "$D/dispatch.1.json"; echo RATELIMIT > "$D/dispatch.2.json"
printf '{"workflow_run_id":555,"html_url":"%s"}\n' "$RUN_555" > "$D/dispatch.3.json"; relrun completed success > "$D/release.1.json"
release_run "$D"; check release/dispatch-error-retried "$D" $? 0 result success - "retrying"
if [ "$(calls_to "$D" "docker-release.yml/runs?")" -eq 1 ]; then pass "release/dispatch-retried: looked for the run after the server error only"; else fail "release/dispatch-retried: $(calls_to "$D" "docker-release.yml/runs?") lookups"; fi
D=$(release_dir dispatch-fails); echo HTTP500 > "$D/dispatch.1.json"
release_run "$D"; check release/dispatch-gives-up-after-three "$D" $? 1 result dispatch-failed error "Server Error"
if [ "$(calls_to "$D" "/dispatches")" -eq 3 ]; then pass "release/dispatch-fails: 3 attempts"; else fail "release/dispatch-fails: $(calls_to "$D" "/dispatches") attempts"; fi
if [ "$(calls_to "$D" "docker-release.yml/runs?")" -eq 3 ]; then pass "release/dispatch-fails: looked for a run after each error"; else fail "release/dispatch-fails: $(calls_to "$D" "docker-release.yml/runs?") lookups"; fi
# The server error came after GitHub created the run: found, not dispatched
# again, and that run is waited for.
D=$(release_dir dispatch-error-run-created); echo HTTP500 > "$D/dispatch.1.json"
echo "{\"workflow_runs\":[$(looked 556 m1 2025-10-09T08:53:25Z)]}" > "$D/lookup.1.json"
printf '{"id":556,"status":"completed","conclusion":"success","html_url":"https://github.com/o/r/actions/runs/556"}\n' > "$D/release.1.json"
release_run "$D"; check release/dispatch-error-but-run-created "$D" $? 0 result success - "its run exists - not dispatched again"
if [ "$(calls_to "$D" "/dispatches")" -eq 1 ]; then pass "release/dispatch-error-but-run-created: one dispatch"; else fail "release/dispatch-error-but-run-created: $(calls_to "$D" "/dispatches") dispatches"; fi
output_is release/dispatch-error-but-run-created "$D" run-id 556
output_is release/dispatch-error-but-run-created "$D" run-url "https://github.com/o/r/actions/runs/556"
# Without the merge commit the run cannot be told apart: no look, retried.
D=$(release_dir dispatch-retried-no-commit); echo HTTP500 > "$D/dispatch.1.json"
printf '{"workflow_run_id":555,"html_url":"%s"}\n' "$RUN_555" > "$D/dispatch.2.json"; relrun completed success > "$D/release.1.json"
release_run "$D" MERGE_COMMIT=; check release/dispatch-retried-without-merge-commit "$D" $? 0 result success - "retrying"
not_called release/dispatch-retried-without-merge-commit "$D" "docker-release.yml/runs?"

# The run not readable: retried; five errors in a row fail the job.
D=$(release_dir run-read-retried); echo HTTP500 > "$D/release.1.json"; relrun completed success > "$D/release.2.json"
release_run "$D"; check release/run-read-error-retried "$D" $? 0 result success - "API error 1/5"
D=$(release_dir run-unreadable); echo HTTP500 > "$D/release.1.json"; rm "$D/release.2.json"
release_run "$D"; check release/run-unreadable "$D" $? 1 result unreadable error "could not be read"
# Only errors in a row count: a read in between starts the count anew, so
# errors spread over a long release do not fail the job.
D=$(release_dir run-read-errors-spread); echo HTTP500 > "$D/release.1.json"
for n in 3 4 5 6; do echo HTTP500 > "$D/release.$n.json"; done; relrun completed success > "$D/release.7.json"
release_run "$D"; check release/run-read-errors-not-in-a-row "$D" $? 0 result success - "API error 4/5"

# --- merge -> release ---------------------------------------------------------------
# The release step runs only when the merge step merged (if: on the step, held
# by a static check above) - here the two steps run in that order, the merge's
# outputs feeding the release, as the job does.
flow_run() {
  local dir="$1"; shift
  merge_run "$dir" true squash "$@"
  if [ "$(sed -n 's/^merged=//p' "$dir/output")" = true ]; then
    cp "$dir/log" "$dir/merge.log"
    release_run "$dir" MERGE_COMMIT="$(sed -n 's/^merge-commit=//p' "$dir/output")" "$@"
  fi
}
flow_dir() {
  local dir; dir=$(merge_dir "flow-$1")
  printf '{"workflow_run_id":555,"html_url":"%s"}\n' "$RUN_555" > "$dir/dispatch.1.json"
  relrun completed success > "$dir/release.1.json"
  echo "$dir"
}
D=$(flow_dir merged); flow_run "$D"
called flow/merged-then-released "$D" "pr merge 7 --repo o/r --squash --match-head-commit abc"
called flow/merged-then-released "$D" "$DISPATCH"
output_is flow/merged-then-released "$D" result success
ORDER=$(awk '/^pr merge/ { a = NR } /dispatches/ { b = NR } END { print (a && a < b) ? "ok" : a " " b }' "$D/calls")
if [ "$ORDER" = ok ]; then pass "flow/merged-then-released: dispatched after the merge"; else fail "flow/merged-then-released: order $ORDER"; fi
for c in base-moved conflict merge-rejected merge-queued merged-before; do
  D=$(flow_dir "$c")
  case "$c" in
    base-moved) moved_to "$D" base1 ;;
    conflict) echo '{"state":"open","head":{"sha":"abc"},"base":{"ref":"main"},"draft":false,"mergeable":false,"mergeable_state":"dirty"}' > "$D/pr.1.json" ;;
    merged-before) echo "$PR_MERGED" > "$D/pr.1.json" ;;
  esac
  case "$c" in
    merge-rejected) flow_run "$D" FAKE_MERGE_FAIL=1 ;;
    merge-queued) flow_run "$D" FAKE_MERGE_QUEUED=1 ;;
    *) flow_run "$D" ;;
  esac
  not_called "flow/$c-no-release" "$D" "/dispatches"
done

# --- base image handoff ---------------------------------------------------------------
# Each case: a checkout of the merge commit ($D/repo) with a bare origin
# ($D/origin.git), the monitor config and the Dockerfiles in it; the PR's
# changed files, the latest release and the compare answer as gh fixtures; the
# registry as files for the docker stub. The steps run in the job's order,
# each only if its `if:` - read from the workflow - holds for the outputs of
# the steps before it (hstep_runs). The uses: steps are stood in for: the
# checkout is $D/repo, the resolve step is the action's own body with its
# real resolver, the GHCR login is only noted.
mkdir -p "$WORK/hbin" "$WORK/racebin"
cp "$WORK/bin/gh" "$WORK/hbin/gh"
cat > "$WORK/hbin/docker" <<'STUB'
#!/usr/bin/env bash
# docker manifest inspect <ref>: answers from $FAKE/manifests/<ref, / and :
# as _>; no file: an unknown manifest. A file holding DENIED answers as GHCR
# does without packages: read; FLAKY fails once, then answers with its other
# lines.
echo "$*" >> "$FAKE/docker-calls"
[ "${1:-} ${2:-}" = "manifest inspect" ] || { echo "unexpected docker call: $*" >&2; exit 2; }
f="$FAKE/manifests/$(printf '%s' "$3" | tr '/:' '__')"
[ -f "$f" ] || { echo "manifest unknown: manifest unknown" >&2; exit 1; }
case "$(head -n 1 "$f")" in
  DENIED) echo "Error response from daemon: Head \"https://ghcr.io/v2/acme/base/manifests/1.2\": denied: denied" >&2; exit 1 ;;
  FLAKY)
    if [ ! -f "$f.failed" ]; then : > "$f.failed"; echo "Get \"https://registry-1.docker.io/v2/\": net/http: TLS handshake timeout" >&2; exit 1; fi
    tail -n +2 "$f"; exit 0 ;;
esac
cat "$f"
STUB
# shellcheck disable=SC2016 # expanded when the stub runs
printf '#!/usr/bin/env bash\necho "$1" >> "$FAKE/sleeps"\n' > "$WORK/hbin/sleep"
# The first push of the notes ref meets a note another run pushed in the
# meantime - on another merge commit - and is rejected.
cat > "$WORK/racebin/git" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = push ] && [ ! -f "$FAKE/raced" ]; then
  : > "$FAKE/raced"
  "$REAL_GIT" -C "$FAKE/other" notes --ref=refs/notes/base-image-monitor add -f -m '{"schema":1,"other":true}' "$(cat "$FAKE/other-commit")" || exit 3
  "$REAL_GIT" -C "$FAKE/other" push -q origin refs/notes/base-image-monitor || exit 3
fi
exec "$REAL_GIT" "$@"
STUB
chmod +x "$WORK/hbin/docker" "$WORK/hbin/sleep" "$WORK/racebin/git"
REAL_GIT=$(command -v git)
export REAL_GIT
# Git must not pick up the identity, signing or hooks of the machine - and the
# note step sets its own identity.
printf '[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n' > "$WORK/gitconfig"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig" GIT_CONFIG_NOSYSTEM=1

NOTES_REF=refs/notes/base-image-monitor
BOT="github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>"
HCFG=".github/config/docker-base-image-monitor/base-images.json"
hex() { printf '%064d' 0 | tr 0 "$1"; }
D_PY="sha256:$(hex a)"; D_PY386="sha256:$(hex 3)"; D_NODE="sha256:$(hex b)"; D_BASE="sha256:$(hex c)"
# index <linux/amd64 digest> <linux/386 digest>: a Docker official image's
# multi-arch index - 386 sorts first, an attestation entry last.
index() {
  printf '{"schemaVersion":2,"manifests":[{"digest":"%s","platform":{"architecture":"386","os":"linux"}},{"digest":"%s","platform":{"architecture":"amd64","os":"linux"}},{"digest":"sha256:%s","platform":{"architecture":"unknown","os":"unknown"}}]}' "$2" "$1" "$(hex 9)"
}
# The monitor config of most cases:
#   python  ./Dockerfile      the PR bumps its FROM line (3.14 -> 3.15)
#   node    web/Dockerfile    not changed by the PR
#   redis   a fixed tag       never recorded
HCONFIG='{"images": [
  {"name": "python", "image": "python", "dockerfile": "./Dockerfile", "variable": "PYTHON_DIGEST"},
  {"name": "node", "image": "node", "dockerfile": "web/Dockerfile", "variable": "NODE_DIGEST"},
  {"name": "redis", "image": "redis", "tag": "7-alpine", "variable": "REDIS_DIGEST"}
], "settings": {"commit-prefix": "chore(deps)"}}'

# Fixed dates: the same content makes the same commits in every case.
hcommit() {
  GIT_AUTHOR_DATE=2026-11-01T10:00:00Z GIT_COMMITTER_DATE=2026-11-01T10:00:00Z \
    git -C "$1/repo" -c user.name=test -c user.email=test@example.invalid commit -q -am "$2"
}
# hput <dir> <path> <content>: a file in the checkout
hput() { mkdir -p "$(dirname "$1/repo/$2")"; printf '%s\n' "$3" > "$1/repo/$2"; }
# hmanifest <dir> <image:tag> <manifest|DENIED|FLAKY...>: the registry's answer
hmanifest() { printf '%s\n' "$3" > "$1/manifests/$(printf '%s' "$2" | tr '/:' '__')"; }
handoff_dir() {
  local dir="$WORK/handoff-$1"
  mkdir -p "$dir/manifests" "$dir/temp"
  : > "$dir/output"; : > "$dir/calls"; : > "$dir/ctx"; : > "$dir/steps"; : > "$dir/log"; : > "$dir/docker-calls"
  echo 1760000000 > "$dir/clock"
  git init -q --bare "$dir/origin.git"
  git init -q "$dir/repo"
  git -C "$dir/repo" remote add origin "$dir/origin.git"
  hput "$dir" "$HCFG" "$HCONFIG"
  hput "$dir" Dockerfile 'FROM python:3.14-alpine'
  hput "$dir" web/Dockerfile 'FROM node:22-alpine'
  git -C "$dir/repo" add -A
  hcommit "$dir" "feat: initial"
  git -C "$dir/repo" rev-parse HEAD > "$dir/other-commit"
  hput "$dir" Dockerfile 'FROM python:3.15-alpine'
  hcommit "$dir" "build(deps): bump python from 3.14-alpine to 3.15-alpine"
  git -C "$dir/repo" push -q origin HEAD:main
  git -C "$dir/repo" rev-parse HEAD > "$dir/merge-commit"
  echo '[{"filename":"Dockerfile","status":"modified"}]' > "$dir/files.1.json"
  hmanifest "$dir" python:3.15-alpine "$(index "$D_PY" "$D_PY386")"
  hmanifest "$dir" node:22-alpine "$(index "$D_NODE" "sha256:$(hex 4)")"
  hmanifest "$dir" redis:7-alpine "$(index "sha256:$(hex 5)" "sha256:$(hex 6)")"
  # created_at is the date of the tagged commit (GitHub's docs): older than
  # the digests. published_at is when the release run published it.
  echo '{"tag_name":"v1.4.0","created_at":"2000-01-01T00:00:00Z","published_at":"2099-01-01T00:00:00Z"}' > "$dir/latest.1.json"
  echo '{"status":"ahead","ahead_by":1,"behind_by":0}' > "$dir/compare.1.json"
  echo "$dir"
}

# hctx <dir> <name>: a value the steps' `if:` and env see (the last one set)
hctx() { awk -v k="$2=" 'index($0, k) == 1 { v = substr($0, length(k) + 1) } END { print v }' "$1/ctx"; }
hout() { hctx "$1" "steps.$2.outputs.$3"; }
# hstep_runs <dir> <step id>: whether GitHub runs the step - its `if:` from the
# workflow: terms joined by &&, each steps.<id>.outputs.<name>,
# steps.<id>.outcome, inputs.<name> or github.event.<path> compared (== or !=)
# with a string or with another of these.
hstep_runs() {
  local dir="$1" id="$2" cond rest term got want left op right literal other
  local ctx="steps\.[a-z0-9_-]+\.(outputs\.[a-z0-9_-]+|outcome)|inputs\.[a-z0-9_-]+|github\.event\.[a-z0-9_.]+"
  local compare="^($ctx) (==|!=) ('([^']*)'|($ctx))$"
  cond=$(awk -v id="        id: $id" '$0 == id { found = 1; next }
    found && /^        if: / { sub(/^        if: /, ""); print; exit } found && /^      - / { exit }' "$WORKFLOW_FILE")
  if [ -z "$cond" ]; then echo "FATAL: no 'if:' after 'id: $id' in the workflow - update this test"; exit 1; fi
  rest="$cond"
  while [ -n "$rest" ]; do
    term="${rest%% && *}"
    if [ "$term" = "$rest" ]; then rest=""; else rest="${rest#* && }"; fi
    if [[ ! $term =~ $compare ]]; then echo "FATAL: hstep_runs cannot evaluate '$term' of step $id - update this test"; exit 1; fi
    left="${BASH_REMATCH[1]}" op="${BASH_REMATCH[3]}" right="${BASH_REMATCH[4]}" literal="${BASH_REMATCH[5]}" other="${BASH_REMATCH[6]}"
    got=$(hctx "$dir" "$left")
    if [ "${right:0:1}" = "'" ]; then want="$literal"; else want=$(hctx "$dir" "$other"); fi
    if [ "$op" = "==" ]; then [ "$got" = "$want" ] || return 1; else [ "$got" != "$want" ] || return 1; fi
  done
}
# hrun <dir> <step id> <body> [VAR=value ...]: runs a step in the checkout, as
# a `shell: bash` step runs; its outputs and outcome go to the context.
hrun() {
  local dir="$1" id="$2" body="$3" rc line; shift 3
  : > "$dir/out-$id"
  ( cd "$dir/repo" && env PATH="$WORK/hbin:$PATH" FAKE="$dir" GITHUB_OUTPUT="$dir/out-$id" RUNNER_TEMP="$dir/temp" \
      GH_TOKEN=test REPO=o/r PR_NUMBER=7 "$@" bash --noprofile --norc -eo pipefail -c "$body" ) >> "$dir/log" 2>&1
  rc=$?
  echo "$id" >> "$dir/steps"
  while IFS= read -r line; do echo "steps.$id.outputs.$line" >> "$dir/ctx"; done < "$dir/out-$id"
  if [ "$rc" -eq 0 ]; then echo "steps.$id.outcome=success" >> "$dir/ctx"; else echo "steps.$id.outcome=failure" >> "$dir/ctx"; fi
}
# handoff_before <dir> [KEY=value ...]: the handoff steps before the dispatch,
# after a merge as the merge step reports it. KEY: CONFIG (the input
# base-image-config), WAIT (release-wait-minutes), MERGED, MERGE_COMMIT,
# CHECKOUT (its outcome), HPATH (put first on PATH of the bash steps),
# BASE_REF (the PR's base branch) and DEFAULT_BRANCH (the repository's; both
# main by default).
handoff_before() {
  local dir="$1" kv config="$HCFG" wait=60 merged=true checkout=success mc hpath="" base_ref=main default_branch=main; shift
  mc=$(cat "$dir/merge-commit")
  for kv in "$@"; do
    case "$kv" in
      CONFIG=*) config="${kv#*=}" ;; WAIT=*) wait="${kv#*=}" ;; MERGED=*) merged="${kv#*=}" ;;
      MERGE_COMMIT=*) mc="${kv#*=}" ;; CHECKOUT=*) checkout="${kv#*=}" ;; HPATH=*) hpath="${kv#*=}:" ;;
      BASE_REF=*) base_ref="${kv#*=}" ;; DEFAULT_BRANCH=*) default_branch="${kv#*=}" ;;
    esac
  done
  {
    echo "github.event.pull_request.base.ref=$base_ref"
    echo "github.event.repository.default_branch=$default_branch"
    echo "inputs.base-image-config=$config"
    echo "steps.merge.outputs.merged=$merged"
    echo "steps.merge.outputs.merge-commit=$mc"
    echo "steps.guard.outputs.release-workflow=$REL_WF"
  } >> "$dir/ctx"
  if hstep_runs "$dir" handoff-checkout; then
    echo handoff-checkout >> "$dir/steps"; echo "steps.handoff-checkout.outcome=$checkout" >> "$dir/ctx"
  fi
  if hstep_runs "$dir" handoff-files; then
    hrun "$dir" handoff-files "$HFILES_BODY" PATH="$hpath$WORK/hbin:$PATH" CONFIG_FILE="$config" MERGE_COMMIT="$mc" WAIT_MINUTES="$wait"
  fi
  if hstep_runs "$dir" handoff-resolve; then
    hrun "$dir" handoff-resolve "$RESOLVE_BODY" GITHUB_ACTION_PATH="$ACTION_DIR" CONFIG_FILE="" INLINE_IMAGES="$(hout "$dir" handoff-files entries)"
  fi
  if hstep_runs "$dir" handoff-login; then
    echo handoff-login >> "$dir/steps"; echo "steps.handoff-login.outcome=success" >> "$dir/ctx"
  fi
  if hstep_runs "$dir" handoff-digests; then
    hrun "$dir" handoff-digests "$HDIGESTS_BODY" PATH="$hpath$WORK/hbin:$PATH" \
      CHANGED_VARIABLES="$(hout "$dir" handoff-files variables)" RESOLVED_IMAGES="$(hout "$dir" handoff-resolve images)"
  fi
}
# handoff_after <dir> [VAR=value ...]: the note step, after the release step
# reported its result (steps.release.outputs.* in the context).
handoff_after() {
  local dir="$1"; shift
  if hstep_runs "$dir" handoff-note; then
    hrun "$dir" handoff-note "$HNOTE_BODY" MERGE_COMMIT="$(hctx "$dir" steps.merge.outputs.merge-commit)" \
      RELEASE_RUN_URL="$(hout "$dir" release run-url)" DIGESTS="$(hout "$dir" handoff-digests digests)" \
      IMAGES="$(hout "$dir" handoff-digests images)" RECORDED_AT="$(hout "$dir" handoff-digests recorded-at)" "$@"
  fi
}
# handoff_flow <dir> [KEY=value ...]: before, a release run that ended with
# RELEASE (default success), after. NOTE_PATH: put first on the note's PATH.
handoff_flow() {
  local dir="$1" kv release=success note_path=""; shift
  for kv in "$@"; do
    case "$kv" in RELEASE=*) release="${kv#*=}" ;; NOTE_PATH=*) note_path="${kv#*=}:" ;; esac
  done
  handoff_before "$dir" "$@"
  echo "steps.release.outputs.result=$release" >> "$dir/ctx"
  echo "steps.release.outputs.run-url=$RUN_555" >> "$dir/ctx"
  handoff_after "$dir" PATH="$note_path$WORK/hbin:$PATH"
}

# hresult <name> <dir> <want>: the handoff's verdict, as the job output
# base-image-handoff takes it (the note's, else the digests', else the files').
hresult() {
  local got
  got=$(hout "$2" handoff-note result); [ -n "$got" ] || got=$(hout "$2" handoff-digests result); [ -n "$got" ] || got=$(hout "$2" handoff-files result)
  if [ "$got" = "$3" ]; then pass "$1: handoff $3"; else fail "$1: handoff '$got', want '$3'"; sed 's/^/     | /' "$2/log"; fi
}
heq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1: '$2', want '$3'"; fi; }
hran() { if grep -qx "$3" "$2/steps"; then pass "$1: $3 ran"; else fail "$1: $3 did not run"; fi; }
hskipped() { if grep -qx "$3" "$2/steps"; then fail "$1: $3 ran"; else pass "$1: $3 skipped"; fi; }
# hannotations <name> <dir> <want>: the annotation kinds in the log, e.g.
# "notice" or "notice warning"; "-": none
hannotations() {
  local got; got=$(sed -n 's/^::\(notice\|warning\|error\)[ :].*/\1/p' "$2/log" | sort -u | paste -sd' ' -)
  [ -n "$got" ] || got="-"
  if [ "$got" = "$3" ]; then pass "$1: annotations '$3'"; else fail "$1: annotations '$got', want '$3'"; sed 's/^/     | /' "$2/log"; fi
}
note_of() { git -C "$1/origin.git" notes --ref="$NOTES_REF" show "$2" 2>/dev/null; }
no_note() { if git -C "$2/origin.git" rev-parse -q --verify "$NOTES_REF" > /dev/null; then fail "$1: origin has a note"; else pass "$1: no note on origin"; fi; }

# The bump of python's FROM line, released: the linux/amd64 digest of the new
# tag is recorded on the merge commit, nothing else.
D=$(handoff_dir recorded); MC=$(cat "$D/merge-commit")
handoff_flow "$D"
hresult handoff/recorded "$D" recorded
hannotations handoff/recorded "$D" -
heq "handoff/recorded: only the changed Dockerfile's digest, linux/amd64 (not 386)" "$(hout "$D" handoff-digests digests)" "{\"PYTHON_DIGEST\":\"$D_PY\"}"
heq "handoff/recorded: names" "$(hout "$D" handoff-note images)" '["python"]'
heq "handoff/recorded: release" "$(hout "$D" handoff-note release)" v1.4.0
heq "handoff/recorded: only the changed image was read" "$(cat "$D/docker-calls")" "manifest inspect python:3.15-alpine"
hskipped handoff/recorded "$D" handoff-login
RECORDED_AT=$(hout "$D" handoff-digests recorded-at)
if [[ "$RECORDED_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then pass "handoff/recorded: read at $RECORDED_AT (UTC)"; else fail "handoff/recorded: recorded-at '$RECORDED_AT'"; fi
called handoff/recorded "$D" "api repos/o/r/releases/latest --jq [(.tag_name // \"\"), (.published_at // \"\")] | @tsv"
called handoff/recorded "$D" "api repos/o/r/compare/$MC...v1.4.0 --jq .status"
# The contract with the monitor: exactly one JSON object, in this shape.
NOTE=$(note_of "$D" "$MC")
WANT=$(jq -cn --arg t "$RECORDED_AT" --arg m "$MC" --arg u "$RUN_555" --arg d "$D_PY" \
  '{schema: 1, source: "docker-maintenance-dependabot", recorded_at: $t, merge_commit: $m, release: "v1.4.0", release_run_url: $u, digests: {PYTHON_DIGEST: $d}}')
heq "handoff/recorded: the note is the contract's object" "$(jq -c . <<< "$NOTE" 2>/dev/null)" "$WANT"
heq "handoff/recorded: one line, one JSON value" "$(printf '%s\n' "$NOTE" | wc -l | tr -d ' ') $(jq -s length <<< "$NOTE")" "1 1"
heq "handoff/recorded: keys in the contract's order" "$(jq -c keys_unsorted <<< "$NOTE")" '["schema","source","recorded_at","merge_commit","release","release_run_url","digests"]'
heq "handoff/recorded: schema is a number" "$(jq -r '.schema | type' <<< "$NOTE")" number
heq "handoff/recorded: notes commit by github-actions[bot]" "$(git -C "$D/origin.git" log -1 --format='%an <%ae>|%cn <%ce>' "$NOTES_REF")" "$BOT|$BOT"
heq "handoff/recorded: the merge commit has the only note" "$(git -C "$D/origin.git" notes --ref="$NOTES_REF" list | awk '{ print $2 }')" "$MC"

# Only the changed entries are resolved: a broken entry the PR did not touch
# (its Dockerfile is gone) is the monitor's to report, not this job's.
D=$(handoff_dir unrelated-broken)
hput "$D" "$HCFG" "$(jq -c '.images += [{"name": "worker", "image": "golang", "dockerfile": "worker/Dockerfile", "variable": "GO_DIGEST"}]' <<< "$HCONFIG")"
handoff_flow "$D"
hresult handoff/unrelated-broken-entry "$D" recorded
hannotations handoff/unrelated-broken-entry "$D" -
heq "handoff/unrelated-broken-entry: only python resolved" "$(hout "$D" handoff-files entries | jq -c 'map(.name)')" '["python"]'

# Entries with a fixed tag are never recorded - also when the PR changed the
# Dockerfile that uses the image - and nothing is resolved or read.
D=$(handoff_dir fixed-tag)
hput "$D" "$HCFG" '{"images": [{"name": "python", "image": "python", "tag": "3.15-alpine", "variable": "PYTHON_DIGEST"}]}'
handoff_flow "$D"
hresult handoff/fixed-tag "$D" none
hannotations handoff/fixed-tag "$D" -
hskipped handoff/fixed-tag "$D" handoff-resolve
hskipped handoff/fixed-tag "$D" handoff-digests
heq "handoff/fixed-tag: no registry read" "$(cat "$D/docker-calls")" ""
no_note handoff/fixed-tag "$D"
# One digest per variable: a variable is recorded only if every entry using
# it names a Dockerfile the PR changed.
D=$(handoff_dir shared-variable)
hput "$D" "$HCFG" '{"images": [{"name": "python", "image": "python", "dockerfile": "Dockerfile", "variable": "PYTHON_DIGEST"},
                               {"name": "python-tools", "image": "python", "tag": "3.15-alpine", "variable": "PYTHON_DIGEST"}]}'
handoff_flow "$D"
hresult handoff/shared-with-a-fixed-tag "$D" none
no_note handoff/shared-with-a-fixed-tag "$D"
# The PR changed only web/Dockerfile: node is recorded, python - whose
# digest may have moved too - is left to the monitor.
D=$(handoff_dir other-dockerfile)
hput "$D" web/Dockerfile 'FROM node:24-alpine'; hcommit "$D" "build(deps): bump node"; git -C "$D/repo" rev-parse HEAD > "$D/merge-commit"
echo '[{"filename":"web/Dockerfile","status":"modified"}]' > "$D/files.1.json"
hmanifest "$D" node:24-alpine "$(index "$D_NODE" "sha256:$(hex 4)")"
handoff_flow "$D"
hresult handoff/only-the-changed-dockerfile "$D" recorded
heq "handoff/only-the-changed-dockerfile: node only" "$(jq -c .digests <<< "$(note_of "$D" "$(cat "$D/merge-commit")")")" "{\"NODE_DIGEST\":\"$D_NODE\"}"
# A PR that changed no watched Dockerfile (an npm update): nothing to say.
D=$(handoff_dir no-dockerfile); echo '[{"filename":"package-lock.json","status":"modified"}]' > "$D/files.1.json"
handoff_flow "$D"
hresult handoff/no-watched-dockerfile-changed "$D" none
hannotations handoff/no-watched-dockerfile-changed "$D" -
hskipped handoff/no-watched-dockerfile-changed "$D" handoff-resolve

# Most repositories have no monitor: skipped without a word, before any API call.
D=$(handoff_dir no-config); rm "$D/repo/$HCFG"
handoff_flow "$D"
hresult handoff/no-config "$D" none
hannotations handoff/no-config "$D" -
not_called handoff/no-config "$D" "pulls/7/files"
hskipped handoff/no-config "$D" handoff-resolve
no_note handoff/no-config "$D"
# base-image-config empty: off - not even the checkout.
D=$(handoff_dir input-empty)
handoff_flow "$D" CONFIG=
heq "handoff/input-empty: no handoff step ran" "$(cat "$D/steps")" ""
no_note handoff/input-empty "$D"
# Nothing merged, no release workflow, merge commit unknown: no checkout.
D=$(handoff_dir not-merged); handoff_flow "$D" MERGED=false
heq "handoff/not-merged: no handoff step ran" "$(cat "$D/steps")" ""
D=$(handoff_dir merge-commit-unknown); handoff_flow "$D" MERGE_COMMIT=
heq "handoff/merge-commit-unknown: no handoff step ran" "$(cat "$D/steps")" ""
# A Dependabot target-branch other than the default branch (here: release):
# merged and released as before, but nothing handed over - the monitor checks
# the default branch, and a note on a commit that is not on it could make the
# monitor store a digest the default branch's image was never built from.
D=$(handoff_dir other-base-branch); handoff_flow "$D" BASE_REF=release
heq "handoff/other-base-branch: no handoff step ran" "$(cat "$D/steps")" ""
heq "handoff/other-base-branch: no API call" "$(cat "$D/calls")" ""
heq "handoff/other-base-branch: no registry read" "$(cat "$D/docker-calls")" ""
no_note handoff/other-base-branch "$D"
# The gate compares the two branches, not a name: a default branch called
# develop is handed over like main.
D=$(handoff_dir default-branch-develop); handoff_flow "$D" BASE_REF=develop DEFAULT_BRANCH=develop
hresult handoff/default-branch-develop "$D" recorded
heq "handoff/default-branch-develop: the note is on the merge commit" "$(jq -r .merge_commit <<< "$(note_of "$D" "$(cat "$D/merge-commit")")")" "$(cat "$D/merge-commit")"
D=$(handoff_dir checkout-failed); handoff_flow "$D" CHECKOUT=failure
heq "handoff/checkout-failed: nothing after the checkout" "$(cat "$D/steps")" "handoff-checkout"
# release-wait-minutes 0: whether the release succeeds is not seen - a notice,
# and nothing resolved or read.
D=$(handoff_dir wait-zero); handoff_flow "$D" WAIT=0
hresult handoff/wait-zero "$D" skipped
hannotations handoff/wait-zero "$D" notice
logged handoff/wait-zero "$D" "release-wait-minutes is 0, so this run does not see whether the release succeeds."
hskipped handoff/wait-zero "$D" handoff-resolve
heq "handoff/wait-zero: no registry read" "$(cat "$D/docker-calls")" ""
# The changed files not readable: a notice, nothing recorded.
D=$(handoff_dir files-unreadable); raw "$D" files.1.json HTTP500
handoff_flow "$D"
hresult handoff/files-unreadable "$D" skipped
hannotations handoff/files-unreadable "$D" notice

# Two changed images: the internal GHCR one is unreadable (callers grant no
# packages: read) - a notice, the other is recorded. "web/./Dockerfile" is
# normalised as the resolver reads it.
D=$(handoff_dir ghcr-denied)
hput "$D" "$HCFG" '{"images": [{"name": "python", "image": "python", "dockerfile": "Dockerfile", "variable": "PYTHON_DIGEST"},
                               {"name": "base", "image": "ghcr.io/acme/base", "dockerfile": "web/./Dockerfile", "variable": "BASE_DIGEST"}]}'
hput "$D" web/Dockerfile 'FROM ghcr.io/acme/base:1.2'; hcommit "$D" "build(deps): bump both"; git -C "$D/repo" rev-parse HEAD > "$D/merge-commit"
echo '[{"filename":"Dockerfile"},{"filename":"web/Dockerfile"}]' > "$D/files.1.json"
hmanifest "$D" ghcr.io/acme/base:1.2 DENIED
handoff_flow "$D"
hresult handoff/ghcr-denied "$D" recorded
hran handoff/ghcr-denied "$D" handoff-login
hannotations handoff/ghcr-denied "$D" notice
logged handoff/ghcr-denied "$D" "ghcr.io/acme/base:1.2 could not be read (access denied) - for an internal or private GHCR image the calling workflow has to grant 'packages: read'."
heq "handoff/ghcr-denied: the readable one recorded" "$(hout "$D" handoff-digests digests)" "{\"PYTHON_DIGEST\":\"$D_PY\"}"
heq "handoff/ghcr-denied: access denied is not retried" "$(grep -c 'ghcr.io/acme/base:1.2' "$D/docker-calls")" 1
# Both readable: both recorded.
D=$(handoff_dir two-images)
hput "$D" "$HCFG" '{"images": [{"name": "python", "image": "python", "dockerfile": "Dockerfile", "variable": "PYTHON_DIGEST"},
                               {"name": "base", "image": "ghcr.io/acme/base", "dockerfile": "web/./Dockerfile", "variable": "BASE_DIGEST"}]}'
hput "$D" web/Dockerfile 'FROM ghcr.io/acme/base:1.2'; hcommit "$D" "build(deps): bump both"; git -C "$D/repo" rev-parse HEAD > "$D/merge-commit"
echo '[{"filename":"Dockerfile"},{"filename":"web/Dockerfile"}]' > "$D/files.1.json"
hmanifest "$D" ghcr.io/acme/base:1.2 "{\"schemaVersion\":2,\"config\":{\"digest\":\"$D_BASE\"}}"
handoff_flow "$D"
hresult handoff/two-images "$D" recorded
heq "handoff/two-images: both recorded" "$(jq -cS .digests <<< "$(note_of "$D" "$(cat "$D/merge-commit")")")" "{\"BASE_DIGEST\":\"$D_BASE\",\"PYTHON_DIGEST\":\"$D_PY\"}"
heq "handoff/two-images: names" "$(hout "$D" handoff-note images)" '["base","python"]'
# A transient registry error is retried (10 s later); an unknown manifest is not.
D=$(handoff_dir flaky); hmanifest "$D" python:3.15-alpine "$(printf 'FLAKY\n%s' "$(index "$D_PY" "$D_PY386")")"
handoff_flow "$D"
hresult handoff/transient-error-retried "$D" recorded
heq "handoff/transient-error-retried: waited 10 s" "$(paste -sd' ' - 2>/dev/null < "$D/sleeps")" 10
D=$(handoff_dir unknown-manifest); rm "$D/manifests/python_3.15-alpine"
handoff_flow "$D"
hresult handoff/unknown-manifest "$D" skipped
hannotations handoff/unknown-manifest "$D" notice
heq "handoff/unknown-manifest: not retried" "$(wc -l < "$D/docker-calls" | tr -d ' ')" 1
hskipped handoff/unknown-manifest "$D" handoff-note
# An index without linux/amd64 keeps the legacy pick; a manifest without a
# digest is not recorded.
D=$(handoff_dir no-amd64)
hmanifest "$D" python:3.15-alpine "{\"manifests\":[{\"digest\":\"$D_PY386\",\"platform\":{\"architecture\":\"arm64\",\"os\":\"linux\"}},{\"digest\":\"$D_NODE\",\"platform\":{\"architecture\":\"386\",\"os\":\"linux\"}}]}"
handoff_flow "$D"
heq "handoff/index-without-amd64: the legacy pick" "$(hout "$D" handoff-digests digests)" "{\"PYTHON_DIGEST\":\"$D_NODE\"}"
D=$(handoff_dir no-digest); hmanifest "$D" python:3.15-alpine '{"schemaVersion":2}'
handoff_flow "$D"
hresult handoff/manifest-without-digest "$D" skipped
hannotations handoff/manifest-without-digest "$D" notice
# The FROM line names another image than the entry: the resolver's error, and
# that entry is not recorded.
D=$(handoff_dir not-resolved); hput "$D" Dockerfile 'FROM pypy:3.11'; hcommit "$D" "build(deps): switch"; git -C "$D/repo" rev-parse HEAD > "$D/merge-commit"
handoff_flow "$D"
hresult handoff/tag-not-resolved "$D" skipped
hannotations handoff/tag-not-resolved "$D" "error notice"
heq "handoff/tag-not-resolved: no registry read" "$(cat "$D/docker-calls")" ""

# Only after a release run that succeeded: anything else, no note.
for r in failed timeout not-found unreadable dispatch-failed; do
  D=$(handoff_dir "release-$r"); handoff_flow "$D" RELEASE="$r"
  hskipped "handoff/release-$r" "$D" handoff-note
  no_note "handoff/release-$r" "$D"
done
# The run succeeded, but did it cut a release for the merge? No release at
# all, one published before the digests were read (its created_at - the
# tagged commit's date - newer does not count), one without the merge commit,
# answers that cannot be read: a notice, no note.
D=$(handoff_dir no-release); raw "$D" latest.1.json HTTP404
handoff_flow "$D"
hresult handoff/no-release "$D" not-verified
hannotations handoff/no-release "$D" notice
no_note handoff/no-release "$D"
D=$(handoff_dir old-release)
echo '{"tag_name":"v1.3.9","created_at":"2099-01-01T00:00:00Z","published_at":"2000-01-01T00:00:00Z"}' > "$D/latest.1.json"
handoff_flow "$D"
hresult handoff/release-older-than-the-digests "$D" not-verified
logged handoff/release-older-than-the-digests "$D" "is not newer than the digests read before the dispatch"
not_called handoff/release-older-than-the-digests "$D" "compare/"
no_note handoff/release-older-than-the-digests "$D"
D=$(handoff_dir draft-like); echo '{"tag_name":"v1.4.0","created_at":"2099-01-01T00:00:00Z","published_at":null}' > "$D/latest.1.json"
handoff_flow "$D"
hresult handoff/release-without-publish-time "$D" not-verified
for s in behind diverged; do
  D=$(handoff_dir "compare-$s"); echo "{\"status\":\"$s\"}" > "$D/compare.1.json"
  handoff_flow "$D"
  hresult "handoff/release-$s-the-merge" "$D" not-verified
  logged "handoff/release-$s-the-merge" "$D" "does not contain the merge commit"
  no_note "handoff/release-$s-the-merge" "$D"
done
D=$(handoff_dir compare-unreadable); raw "$D" compare.1.json HTTP500
handoff_flow "$D"
hresult handoff/compare-unreadable "$D" not-verified
no_note handoff/compare-unreadable "$D"
D=$(handoff_dir identical); echo '{"status":"identical"}' > "$D/compare.1.json"
handoff_flow "$D"
hresult handoff/release-tags-the-merge-commit "$D" recorded

# A note of another merge commit on origin stays.
D=$(handoff_dir earlier-note); MC=$(cat "$D/merge-commit"); OTHER=$(cat "$D/other-commit")
git -C "$D/repo" -c user.name=test -c user.email=test@example.invalid notes --ref="$NOTES_REF" add -m '{"schema":1,"earlier":true}' "$OTHER"
git -C "$D/repo" push -q origin "$NOTES_REF"; git -C "$D/repo" update-ref -d "$NOTES_REF"
handoff_flow "$D"
hresult handoff/earlier-note "$D" recorded
heq "handoff/earlier-note: still there" "$(note_of "$D" "$OTHER")" '{"schema":1,"earlier":true}'
heq "handoff/earlier-note: this one added" "$(jq -r .merge_commit <<< "$(note_of "$D" "$MC")")" "$MC"
# Another run pushed a note in between: the push is rejected, the next attempt
# adds this note on top of origin's - both notes are there.
D=$(handoff_dir race); MC=$(cat "$D/merge-commit"); OTHER=$(cat "$D/other-commit")
git clone -q "$D/origin.git" "$D/other"
handoff_flow "$D" NOTE_PATH="$WORK/racebin"
hresult handoff/push-rejected-once "$D" recorded
hannotations handoff/push-rejected-once "$D" -
logged handoff/push-rejected-once "$D" "Attempt 1/3 to record the note failed"
heq "handoff/push-rejected-once: the other run's note" "$(note_of "$D" "$OTHER")" '{"schema":1,"other":true}'
heq "handoff/push-rejected-once: this run's note" "$(jq -r .merge_commit <<< "$(note_of "$D" "$MC")")" "$MC"
# Pushing is refused for good: three attempts, a warning - the step and the
# job stay green.
D=$(handoff_dir push-refused)
printf '#!/bin/sh\necho "push refused by policy" >&2\nexit 1\n' > "$D/origin.git/hooks/pre-receive"; chmod +x "$D/origin.git/hooks/pre-receive"
handoff_flow "$D"
hresult handoff/push-refused "$D" failed
hannotations handoff/push-refused "$D" warning
heq "handoff/push-refused: the step succeeds" "$(hctx "$D" steps.handoff-note.outcome)" success
heq "handoff/push-refused: three attempts" "$(grep -c 'to record the note failed' "$D/log")" 3
no_note handoff/push-refused "$D"
# Malformed input (never written by the digests step): a warning, no note.
D=$(handoff_dir bad-input); MC=$(cat "$D/merge-commit")
echo "steps.merge.outputs.merge-commit=$MC" >> "$D/ctx"; echo "steps.release.outputs.run-url=$RUN_555" >> "$D/ctx"
hrun "$D" handoff-note "$HNOTE_BODY" MERGE_COMMIT="$MC" RELEASE_RUN_URL="$RUN_555" DIGESTS='{"PYTHON_DIGEST":"sha256:short"}' IMAGES='["python"]' RECORDED_AT=2026-11-12T10:00:00Z
hresult handoff/malformed-digests "$D" failed
hannotations handoff/malformed-digests "$D" warning
not_called handoff/malformed-digests "$D" "releases/latest"
no_note handoff/malformed-digests "$D"
# git not usable: three attempts, a warning.
D=$(handoff_dir no-git); mkdir -p "$D/nogit"; printf '#!/usr/bin/env bash\nexit 127\n' > "$D/nogit/git"; chmod +x "$D/nogit/git"
handoff_flow "$D" NOTE_PATH="$D/nogit"
heq "handoff/git-broken: the step succeeds" "$(hctx "$D" steps.handoff-note.outcome)" success
hresult handoff/git-broken "$D" failed
hannotations handoff/git-broken "$D" warning
# An error nobody expected (here: no temporary directory) is a warning too,
# never a red step.
D=$(handoff_dir unexpected); mkdir -p "$D/nomktemp"; printf '#!/usr/bin/env bash\nexit 1\n' > "$D/nomktemp/mktemp"; chmod +x "$D/nomktemp/mktemp"
handoff_flow "$D" NOTE_PATH="$D/nomktemp"
heq "handoff/unexpected-error: the step succeeds" "$(hctx "$D" steps.handoff-note.outcome)" success
hresult handoff/unexpected-error "$D" failed
hannotations handoff/unexpected-error "$D" warning
logged handoff/unexpected-error "$D" "Unexpected error (exit 1)"
no_note handoff/unexpected-error "$D"

# --- merge -> base image handoff -> release -> note ----------------------------------
# The job's chain with the real merge and release steps. The release step
# behaves the same, byte for byte, whatever the handoff did: recorded, its
# checkout failed, or its tools are broken (jq missing).
full_flow() {
  local dir="$1" mc; shift
  mc=$(cat "$dir/merge-commit")
  echo "$PR_READY" > "$dir/pr.1.json"
  echo "${PR_MERGED/\"m1\"/\"$mc\"}" > "$dir/prmerged.1.json"
  tested_on "$dir" base0
  echo '{"ref":"refs/heads/main","object":{"sha":"base0","type":"commit"}}' > "$dir/baseref.1.json"
  echo "{\"sha\":\"$mc\",\"parents\":[{\"sha\":\"base0\"}]}" > "$dir/gitcommit.1.json"
  echo '{"sha":"abc","commit":{"committer":{"date":"2026-01-01T10:00:00Z"}}}' > "$dir/commit.1.json"
  echo '[]' > "$dir/comments.1.json"
  printf '{"workflow_run_id":555,"html_url":"%s"}\n' "$RUN_555" > "$dir/dispatch.1.json"
  relrun completed success > "$dir/release.1.json"
  merge_run "$dir" true squash; cp "$dir/log" "$dir/merge.log"; : > "$dir/log"
  handoff_before "$dir" MERGED="$(sed -n 's/^merged=//p' "$dir/output")" MERGE_COMMIT="$(sed -n 's/^merge-commit=//p' "$dir/output")" "$@"
  cp "$dir/log" "$dir/handoff.log"
  : > "$dir/output"
  release_run "$dir" MERGE_COMMIT="$(hctx "$dir" steps.merge.outputs.merge-commit)"; echo "rc=$?" >> "$dir/log"
  cp "$dir/log" "$dir/release.log"; cp "$dir/output" "$dir/release.output"
  while IFS= read -r line; do echo "steps.release.outputs.$line" >> "$dir/ctx"; done < "$dir/output"
  cp "$dir/handoff.log" "$dir/log"
  handoff_after "$dir" PATH="$WORK/hbin:$PATH"
}
D=$(handoff_dir full-recorded); full_flow "$D"; FULL="$D"
hresult flow/handoff-recorded "$D" recorded
heq "flow/handoff-recorded: merged" "$(hctx "$D" steps.merge.outputs.merged)" true
heq "flow/handoff-recorded: released" "$(sed -n 's/^result=//p' "$D/release.output")" success
called flow/handoff-recorded "$D" "$DISPATCH"
ORDER=$(awk '/^pr merge/ { a = NR } /pulls\/7\/files/ { b = NR } /dispatches/ { c = NR } /releases\/latest/ { d = NR } END { print (a && a < b && b < c && c < d) ? "ok" : a " " b " " c " " d }' "$D/calls")
if [ "$ORDER" = ok ]; then pass "flow/handoff-recorded: merge, digests, dispatch, note - in that order"; else fail "flow/handoff-recorded: order $ORDER"; fi
heq "flow/handoff-recorded: the note is on the merge commit" "$(jq -r .merge_commit <<< "$(note_of "$D" "$(cat "$D/merge-commit")")")" "$(cat "$D/merge-commit")"
for c in checkout-failed tools-broken; do
  D=$(handoff_dir "full-$c")
  case "$c" in
    checkout-failed) full_flow "$D" CHECKOUT=failure ;;
    tools-broken)
      mkdir -p "$D/nojq"; printf '#!/usr/bin/env bash\necho "jq: command not found" >&2\nexit 127\n' > "$D/nojq/jq"; chmod +x "$D/nojq/jq"
      full_flow "$D" HPATH="$D/nojq" ;;
  esac
  hskipped "flow/handoff-$c" "$D" handoff-note
  no_note "flow/handoff-$c" "$D"
  if cmp -s "$FULL/release.log" "$D/release.log" && cmp -s "$FULL/release.output" "$D/release.output"; then
    pass "flow/handoff-$c: the release step ran exactly as with the handoff recorded"
  else
    fail "flow/handoff-$c: the release step behaved differently"; diff "$FULL/release.log" "$D/release.log" | sed 's/^/     | /'
  fi
  heq "flow/handoff-$c: release dispatched once" "$(calls_to "$D" "/dispatches")" 1
done

# --- summary ------------------------------------------------------------------------
# summary_run <name> [VAR=value ...]: the job summary for these step outputs,
# in $WORK/summary-<name>/summary
summary_run() {
  local name="$1" dir="$WORK/summary-$1" rc; shift
  mkdir -p "$dir/temp"; : > "$dir/summary"
  ( cd "$dir" && env GITHUB_STEP_SUMMARY="$dir/summary" RUNNER_TEMP="$dir/temp" PR_NUMBER=7 DEPENDENCIES=redis \
      UPDATE_TYPE=version-update:semver-patch MERGE_METHOD=squash ALLOWED=patch REQUIRED="$REQ_CI" GUARD_REASON=patch \
      CI_RESULT=green CI_DETAIL="required workflows passed" BASE_REF=main JOB_STATUS=success "$@" \
      bash --noprofile --norc -eo pipefail -c "$SUMMARY_BODY" ) > "$dir/log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then pass "summary/$name: written"; else fail "summary/$name: exit $rc"; sed 's/^/     | /' "$dir/log"; fi
}
shows() {
  if grep -qF -- "$3" "$2/summary"; then pass "$1: shows '$3'"; else fail "$1: summary lacks '$3'"; sed 's/^/     | /' "$2/summary"; fi
}
lacks() {
  if grep -qF -- "$3" "$2/summary"; then fail "$1: summary has '$3'"; else pass "$1: no '$3'"; fi
}
summary_run released MERGE_REASON=merged MERGED=true MERGE_COMMIT=m1abcdef01234567 RELEASE_WORKFLOW="$REL_WF" \
  RELEASE_RESULT=success RELEASE_DETAIL="$RUN_555" RELEASE_RUN_URL="$RUN_555"
S="$WORK/summary-released"
shows summary/released "$S" "| **Merge** | ✅ Merged into \`main\` as \`m1abcdef0123\` |"
shows summary/released "$S" "| **Release dispatched** | \`$REL_WF\` on \`main\` - [run]($RUN_555) |"
shows summary/released "$S" "| **Release result** | ✅ Succeeded |"
summary_run release-failed MERGE_REASON=merged MERGED=true MERGE_COMMIT=m1 RELEASE_WORKFLOW="$REL_WF" \
  RELEASE_RESULT=failed RELEASE_DETAIL=startup_failure RELEASE_RUN_URL="$RUN_555" JOB_STATUS=failure
S="$WORK/summary-release-failed"
shows summary/release-failed "$S" "| **Release result** | ❌ Failed: the run concluded \`startup_failure\` - fix the cause, then re-run its failed jobs (\`gh run rerun 555 --failed\`), not all jobs |"
summary_run dispatch-failed MERGE_REASON=merged MERGED=true MERGE_COMMIT=m1 RELEASE_WORKFLOW="$REL_WF" \
  RELEASE_RESULT=dispatch-failed RELEASE_DETAIL="the job token may not start workflows" JOB_STATUS=failure
S="$WORK/summary-dispatch-failed"
shows summary/dispatch-failed "$S" "| **Release dispatched** | ❌ Not dispatched: the job token may not start workflows |"
# Every release result has its row.
for r in "timeout|still in_progress after 60 min|❌ Not finished: still in_progress after 60 min (release-wait-minutes)" \
         "not-found|run not found|❓ Unknown: run not found" \
         "unreadable|HTTP 500|❌ Not confirmed: the run could not be read (HTTP 500)" \
         "not-waited|not waited for|⏭️ Not waited for (release-wait-minutes: 0)"; do
  IFS='|' read -r result detail row <<< "$r"
  summary_run "release-$result" MERGE_REASON=merged MERGED=true MERGE_COMMIT=m1 RELEASE_WORKFLOW="$REL_WF" \
    RELEASE_RESULT="$result" RELEASE_DETAIL="$detail" RELEASE_RUN_URL="$RUN_555"
  shows "summary/release-$result" "$WORK/summary-release-$result" "| **Release result** | $row |"
done
summary_run no-release-workflow MERGE_REASON=merged MERGED=true MERGE_COMMIT=m1
S="$WORK/summary-no-release-workflow"
shows summary/no-release-workflow "$S" "No release started: release-workflow is not set"
# Not "released with the next push": a chore(deps) update is not released.
shows summary/no-release-workflow "$S" "whether that releases this update depends on its commit type"
lacks summary/no-release-workflow "$S" "**Release dispatched**"
summary_run left-open MERGE_REASON=base-moved MERGED=false RELEASE_WORKFLOW="$REL_WF" \
  MERGE_DETAIL="main moved from base0 (tested by CI) to base1; rebase requested"
S="$WORK/summary-left-open"
shows summary/left-open "$S" "🔄 Left open: CI passed, but not on the current base - main moved from base0 (tested by CI) to base1; rebase requested."
shows summary/left-open "$S" "No release started: nothing was merged."
lacks summary/left-open "$S" "**Release dispatched**"
summary_run queued MERGE_REASON=not-merged MERGED=false RELEASE_WORKFLOW="$REL_WF"
S="$WORK/summary-queued"
shows summary/queued "$S" "⚠️ Not merged by this run: the merge call succeeded, but the PR is still open"
shows summary/queued "$S" "No release started: nothing was merged."
lacks summary/queued "$S" "**Release dispatched**"
# A re-run of a job whose release failed: the PR is merged already. Said, not
# reported as "not merged" - and no release by this run.
summary_run rerun CI_RESULT=merged-before CI_DETAIL="PR merged before this run decided" RELEASE_WORKFLOW="$REL_WF" JOB_STATUS=success
S="$WORK/summary-rerun"
shows summary/rerun "$S" "⚠️ Already merged before this run decided (by hand, or by an earlier attempt of this job)"
shows summary/rerun "$S" "Re-running this job does not retry a release"
shows summary/rerun "$S" "No release started by this run. If the release of that merge failed, re-run the failed jobs of its run; run \`$REL_WF\` by hand only if it never ran or failed before releasing."
lacks summary/rerun "$S" "Not merged"
lacks summary/rerun "$S" "**Release dispatched**"
summary_run merged-by-hand MERGE_REASON=merged-before MERGED=false
S="$WORK/summary-merged-by-hand"
shows summary/merged-by-hand "$S" "⚠️ Already merged before this run decided"
lacks summary/merged-by-hand "$S" "No release started"
# The same found by the merge step, with release-workflow set: not "nothing
# was merged" - how to retry that merge's release.
summary_run merged-by-hand-release MERGE_REASON=merged-before MERGED=false RELEASE_WORKFLOW="$REL_WF"
S="$WORK/summary-merged-by-hand-release"
shows summary/merged-by-hand-release "$S" "⚠️ Already merged before this run decided"
shows summary/merged-by-hand-release "$S" "No release started by this run. If the release of that merge failed, re-run the failed jobs of its run"
lacks summary/merged-by-hand-release "$S" "nothing was merged"
lacks summary/merged-by-hand-release "$S" "**Release dispatched**"
# The base image handoff: one row after the release result - none for "none"
# (no monitor config, no watched Dockerfile changed) or when it did not run.
lacks summary/released "$WORK/summary-released" "Base image handoff"
for r in "recorded|release v1.4.0|✅ Recorded for the base image monitor: python, node (release \`v1.4.0\`) - its next check stores these digests instead of releasing again" \
         "not-verified|no release after the dispatch|⏭️ Not recorded: no release after the dispatch - the base image monitor releases this update once more on its next check" \
         "skipped|release-wait-minutes is 0|⏭️ Not recorded: release-wait-minutes is 0 - the base image monitor releases this update once more on its next check" \
         "failed|note not pushed|⚠️ Not recorded: note not pushed - the base image monitor releases this update once more on its next check"; do
  IFS='|' read -r result detail row <<< "$r"
  summary_run "handoff-$result" MERGE_REASON=merged MERGED=true MERGE_COMMIT=m1 RELEASE_WORKFLOW="$REL_WF" \
    RELEASE_RESULT=success RELEASE_DETAIL="$RUN_555" RELEASE_RUN_URL="$RUN_555" \
    HANDOFF_RESULT="$result" HANDOFF_DETAIL="$detail" HANDOFF_IMAGES='["python","node"]' HANDOFF_RELEASE=v1.4.0
  shows "summary/handoff-$result" "$WORK/summary-handoff-$result" "| **Base image handoff** | $row |"
done
summary_run handoff-none MERGE_REASON=merged MERGED=true MERGE_COMMIT=m1 RELEASE_WORKFLOW="$REL_WF" \
  RELEASE_RESULT=success RELEASE_DETAIL="$RUN_555" RELEASE_RUN_URL="$RUN_555" HANDOFF_RESULT=none HANDOFF_DETAIL="no base image monitor config"
lacks summary/handoff-none "$WORK/summary-handoff-none" "Base image handoff"

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
