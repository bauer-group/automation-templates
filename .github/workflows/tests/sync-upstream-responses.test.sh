#!/usr/bin/env bash
#
# Behavioural test for the merge-upstream call of ../sync-upstream.yml.
#
# When upstream changed a file under .github/workflows/, merge-upstream answers
# 422 "refusing to allow a GitHub App to create or update workflow ... without
# `workflows` permission". That fell through to the generic "Upstream sync
# failed" error, which names no cause, and karlspace/Dashboard stayed red for
# months without anyone learning that the token lacks the workflows scope. This
# pins how each response is classified:
#
#   - 422 without `workflows` permission (GitHub App / GITHUB_TOKEN) and without
#     `workflow` scope (PAT) fail as auth-error with an error naming the
#     workflow permission and the explicit secrets mapping for user-owned forks;
#   - 401/403 stay auth-error, 409 stays a conflict warning (exit 0), anything
#     else stays the generic error, and a 200 reports the merge type.
#
# The step body is extracted from the workflow at runtime and run the way a
# `shell: bash` step runs, against a stubbed `gh`.
#
# Usage: bash .github/workflows/tests/sync-upstream-responses.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../sync-upstream.yml"
[ -f "$WORKFLOW" ] || { echo "FATAL: workflow not found at $WORKFLOW"; exit 1; }
command -v jq > /dev/null || { echo "FATAL: jq is required"; exit 1; }

FAILED=0
check() {
  if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 (expected '$3', got '$2')"; FAILED=$((FAILED + 1)); fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# shellcheck disable=SC2016 # literal workflow expression
awk '
  $0 == "        id: sync" { found = 1; next }
  found && /^        run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
    exit
  }
' "$WORKFLOW" | sed 's/\${{ github\.repository }}/karlspace\/Dashboard/g' > "$WORK/sync.sh"
if [ ! -s "$WORK/sync.sh" ] || grep -q '\${{' "$WORK/sync.sh"; then
  echo "FATAL: could not extract the 'sync' run block from the workflow."
  exit 1
fi

mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *merge-upstream*)
    printf '%s\n' "$MERGE_RESPONSE"
    exit "$MERGE_RC" ;;
  *)
    echo '{"full_name":"karlspace/Dashboard","parent":{"full_name":"gethomepage/homepage"}}' ;;
esac
EOF
chmod +x "$WORK/bin/gh"

# run_case <response> <gh exit code>
run_case() {
  CASE="$WORK/case.$RANDOM"
  mkdir -p "$CASE"
  export GITHUB_OUTPUT="$CASE/output" MIRROR_BRANCH=dev DRY_RUN=false MERGE_RESPONSE="$1" MERGE_RC="$2"
  : > "$GITHUB_OUTPUT"
  PATH="$WORK/bin:$PATH" bash -eo pipefail "$WORK/sync.sh" > "$CASE/out" 2>&1
  RC=$?
  STATUS=$(sed -n 's/^status=//p' "$GITHUB_OUTPUT" | tail -1)
}

APP_422='{"message":"refusing to allow a GitHub App to create or update workflow `.github/workflows/crowdin.yml` without `workflows` permission","documentation_url":"https://docs.github.com/rest/branches/branches#sync-a-fork-branch-with-the-upstream-repository","status":"422"}
gh: refusing to allow a GitHub App to create or update workflow `.github/workflows/crowdin.yml` without `workflows` permission (HTTP 422)'
PAT_422='gh: refusing to allow a Personal Access Token to create or update workflow `.github/workflows/ci.yml` without `workflow` scope (HTTP 422)'

echo "- 422, GitHub App / GITHUB_TOKEN without workflows permission"
run_case "$APP_422" 1
check "fails" "$RC" 1
check "status" "$STATUS" auth-error
check "error names the workflow permission" "$(grep -c "^::error::Upstream changed files under .github/workflows/ .*'Workflows: Read and write'.*classic: 'repo' + 'workflow'" "$CASE/out")" 1
check "error names the secrets mapping for user-owned forks" "$(grep -c "^::error::.*'secrets: inherit' passes nothing across owner boundaries" "$CASE/out")" 1
check "not the generic error" "$(grep -c '^::error::Upstream sync failed' "$CASE/out")" 0

echo "- 422, PAT without workflow scope"
run_case "$PAT_422" 1
check "fails" "$RC" 1
check "status" "$STATUS" auth-error
check "error names the workflow permission" "$(grep -c '^::error::Upstream changed files under .github/workflows/' "$CASE/out")" 1

echo "- 403"
run_case 'gh: Resource not accessible by integration (HTTP 403)' 1
check "fails" "$RC" 1
check "status" "$STATUS" auth-error
check "the 401/403 error" "$(grep -c '^::error::Upstream sync for .dev. was rejected with 401/403' "$CASE/out")" 1

echo "- 409"
run_case 'gh: There are merge conflicts (HTTP 409)' 1
check "a conflict is a warning, not a failure" "$RC" 0
check "status" "$STATUS" conflict

echo "- 404"
run_case 'gh: Not Found (HTTP 404)' 1
check "fails" "$RC" 1
check "status" "$STATUS" error
check "the generic error" "$(grep -c '^::error::Upstream sync failed' "$CASE/out")" 1

echo "- 200"
run_case '{"message":"Successfully fetched and fast-forwarded from upstream gethomepage:dev.","merge_type":"fast-forward","base_branch":"gethomepage:dev"}' 0
check "succeeds" "$RC" 0
check "status" "$STATUS" synced
check "merge type" "$(sed -n 's/^merge-type=//p' "$GITHUB_OUTPUT" | tr -d '\r')" fast-forward

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
