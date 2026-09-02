#!/usr/bin/env bash
#
# Behavioural test for the @semantic-release/exec handling in ../action.yml.
#
# The action reserves six plugins so its own decoupled notes generator cannot be
# registered twice, and exec is one of them. But exec is the only reserved plugin
# the action does not fully own: it owns generateNotesCmd, while prepareCmd,
# verifyConditionsCmd, publishCmd and successCmd belong to the consumer. A repo
# uses prepareCmd to stamp the next version into its own files before
# @semantic-release/git commits them.
#
# 3adf5e08 enforced the reservation by dropping the consumer's exec entry from
# EXTRA_PLUGINS outright, which took those hooks with it. Nothing failed: the run
# stayed green, the tag and the GitHub release were correct, and only the version
# INSIDE the artifacts stopped advancing. It survived four releases across three
# repositories before anyone noticed, and by then published images carried a
# version label two minor versions stale.
#
# That is the failure mode this test exists for - a silent one. It is the same
# class as ../../security-scan/tests/process-gitleaks.test.sh: green, plausible,
# wrong.
#
# The two jq programs are extracted from action.yml at runtime rather than copied
# here. A copied program would keep passing after the real one regressed, which
# would make this test worse than none.
#
# Usage: bash .github/actions/semantic-release/tests/merge-exec-hooks.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FATAL: jq is required to run this test"
  exit 1
fi

# --- Pull the two programs out of the action ------------------------------------
#
# Extraction: the single-line assignment `CUSTOM_EXEC=$(jq -c '<program>' ...)`.
# sed is used rather than a shell parse so the program text is taken verbatim,
# including the quoting the action actually ships.
EXTRACT_PROGRAM=$(sed -n "s/^ *CUSTOM_EXEC=\$(jq -c '\(.*\)' \"\$REPO_CONFIG\".*$/\1/p" "$ACTION_FILE")

if [ -z "$EXTRACT_PROGRAM" ]; then
  echo "FATAL: could not extract the CUSTOM_EXEC jq program from action.yml."
  echo "       The assignment was renamed, reformatted or split across lines - update this test."
  exit 1
fi

# Merge: the multi-line program between `jq --argjson exec "$CUSTOM_EXEC" '` and
# the line that closes the quote.
MERGE_PROGRAM=$(awk '
  /jq --argjson exec "\$CUSTOM_EXEC" .$/ { collecting = 1; next }
  collecting && /^ *'\'' / { exit }
  collecting { print }
' "$ACTION_FILE")

if [ -z "$MERGE_PROGRAM" ]; then
  echo "FATAL: could not extract the exec merge jq program from action.yml."
  echo "       The invocation was renamed or reformatted - update this test."
  exit 1
fi

# The same pair for @semantic-release/github. It is reserved like exec, but the
# action owns no option on it, so reserving it discarded every option a repository
# set - successComment, failComment, releasedLabels, assets - silently.
GITHUB_EXTRACT_PROGRAM=$(sed -n "s/^ *CUSTOM_GITHUB=\$(jq -c '\(.*\)' \"\$REPO_CONFIG\".*$/\1/p" "$ACTION_FILE")

GITHUB_MERGE_PROGRAM=$(awk '
  /jq --argjson gh "\$CUSTOM_GITHUB" .$/ { collecting = 1; next }
  collecting && /^ *'\'' / { exit }
  collecting { print }
' "$ACTION_FILE")

if [ -z "$GITHUB_EXTRACT_PROGRAM" ] || [ -z "$GITHUB_MERGE_PROGRAM" ]; then
  echo "FATAL: could not extract the github option programs from action.yml."
  echo "       Reserving @semantic-release/github without reading its options is how"
  echo "       every successComment/failComment/assets setting was silently dropped."
  exit 1
fi

PASSED=0
FAILED=0
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# The plugin ORDER is read out of action.yml's heredoc rather than written here.
# Order is load-bearing: exec must stay ahead of changelog and git, or a restored
# prepareCmd runs after the release commit and stamps nothing that gets committed -
# green again, wrong again, the same silent shape as the original bug. A hardcoded
# fixture would assert its own contents and pass no matter where the real entry
# moved, which is exactly what an earlier draft of this test did.
#
# Only the order is taken from the file. Option VALUES are placeholders, because
# the heredoc interpolates shell variables and is not valid JSON as it stands.
PLUGIN_ORDER=$(awk '
  /cat > \.releaserc\.json << EOF/ { collecting = 1; next }
  collecting && /^ *EOF$/          { exit }
  collecting                       { print }
' "$ACTION_FILE" | grep -oE '@semantic-release/[a-z-]+')

if [ -z "$PLUGIN_ORDER" ]; then
  echo "FATAL: could not read the plugin array out of action.yml."
  echo "       The config heredoc was renamed or reformatted - update this test."
  exit 1
fi

if ! printf '%s\n' "$PLUGIN_ORDER" | grep -qx '@semantic-release/exec'; then
  echo "FATAL: action.yml's plugin array contains no @semantic-release/exec entry."
  exit 1
fi

# NOTES_CMD is the placeholder standing in for the action's own generateNotesCmd.
# Asserting it survives a merge is what proves `.[1] + $exec` cannot clobber the
# action's own option.
NOTES_CMD="node notes.mjs"

write_action_config() {
  local first=1
  {
    printf '{\n  "branches": ["main"],\n  "plugins": [\n'
    while IFS= read -r plugin; do
      [ -n "$plugin" ] || continue
      [ "$first" -eq 1 ] || printf ',\n'
      first=0
      if [ "$plugin" = "@semantic-release/exec" ]; then
        printf '    ["%s", {"generateNotesCmd": "%s"}]' "$plugin" "$NOTES_CMD"
      elif [ "$plugin" = "@semantic-release/github" ]; then
        # action.yml emits github as a BARE STRING, holding no options of its own.
        # The fixture has to present it that way or the merge is never exercised on
        # the shape it actually meets.
        printf '    "%s"' "$plugin"
      else
        printf '    ["%s", {}]' "$plugin"
      fi
    done <<< "$PLUGIN_ORDER"
    printf '\n  ]\n}\n'
  } > "$WORK/releaserc.json"
}

# Replays what action.yml does, using the programs read out of it above.
run_pipeline() {
  local repo_config="$1"
  CUSTOM_EXEC=$(jq -c "$EXTRACT_PROGRAM" "$repo_config" 2>/dev/null || echo "{}")
  if [ -n "$CUSTOM_EXEC" ] && [ "$CUSTOM_EXEC" != "{}" ] && [ "$CUSTOM_EXEC" != "null" ]; then
    :
  else
    CUSTOM_EXEC="{}"
  fi

  CUSTOM_GITHUB=$(jq -c "$GITHUB_EXTRACT_PROGRAM" "$repo_config" 2>/dev/null || echo "{}")
  if [ -n "$CUSTOM_GITHUB" ] && [ "$CUSTOM_GITHUB" != "{}" ] && [ "$CUSTOM_GITHUB" != "null" ]; then
    :
  else
    CUSTOM_GITHUB="{}"
  fi

  write_action_config
  if [ "$CUSTOM_EXEC" != "{}" ]; then
    jq --argjson exec "$CUSTOM_EXEC" "$MERGE_PROGRAM" "$WORK/releaserc.json" > "$WORK/out.json" \
      && mv "$WORK/out.json" "$WORK/releaserc.json"
  fi
  if [ "$CUSTOM_GITHUB" != "{}" ]; then
    jq --argjson gh "$CUSTOM_GITHUB" "$GITHUB_MERGE_PROGRAM" "$WORK/releaserc.json" > "$WORK/out.json" \
      && mv "$WORK/out.json" "$WORK/releaserc.json"
  fi
}

# assert <description> <repo-config-json> <expectation>...
#   exec=a,b,c     the exec plugin's option keys, sorted and comma-joined
#   execval=k=v    the exec plugin's option `k` holds exactly `v`. Keys alone are not
#                  enough: dropping del(.generateNotesCmd) lets a consumer's value win
#                  while the key set stays identical, which a keys-only assertion
#                  cannot see. That was the first thing this test failed to catch.
#   len=N          the plugin array length (the extra-plugins merge indexes it positionally)
#   order=a>b      plugin `a` appears before plugin `b`
assert() {
  local desc="$1" config_json="$2"; shift 2
  local cfg="$WORK/repo-config.json"
  printf '%s' "$config_json" > "$cfg"

  run_pipeline "$cfg"

  local ok=1 detail=""
  local exec_keys len
  exec_keys=$(jq -r '[.plugins[] | select(type == "array") | select(.[0] == "@semantic-release/exec") | .[1] | keys[]] | sort | join(",")' "$WORK/releaserc.json" 2>/dev/null)
  len=$(jq '.plugins | length' "$WORK/releaserc.json" 2>/dev/null)

  local e
  for e in "$@"; do
    case "$e" in
      exec=*)
        if [ "$exec_keys" != "${e#exec=}" ]; then
          ok=0; detail="$detail\n    exec options: expected '${e#exec=}', got '$exec_keys'"
        fi ;;
      execval=*)
        local kv key want got
        kv="${e#execval=}"
        key="${kv%%=*}"
        want="${kv#*=}"
        got=$(jq -r --arg k "$key" '[.plugins[] | select(type == "array") | select(.[0] == "@semantic-release/exec") | .[1][$k]] | first // "<absent>"' "$WORK/releaserc.json")
        if [ "$got" != "$want" ]; then
          ok=0; detail="$detail\n    exec.$key: expected '$want', got '$got'"
        fi ;;
      ghval=*)
        local gkv gkey gwant ggot
        gkv="${e#ghval=}"
        gkey="${gkv%%=*}"
        gwant="${gkv#*=}"
        ggot=$(jq -r --arg k "$gkey" '[.plugins[] | select(type == "array") | select(.[0] == "@semantic-release/github") | .[1][$k]] | first | if . == null then "<absent>" else tostring end' "$WORK/releaserc.json")
        if [ "$ggot" != "$gwant" ]; then
          ok=0; detail="$detail\n    github.$gkey: expected '$gwant', got '$ggot'"
        fi ;;
      len=*)
        if [ "$len" != "${e#len=}" ]; then
          ok=0; detail="$detail\n    plugin count: expected ${e#len=}, got $len"
        fi ;;
      order=*)
        local pair first second idx_first idx_second
        pair="${e#order=}"
        first="${pair%%>*}"
        second="${pair##*>}"
        idx_first=$(jq --arg p "$first"  '[.plugins[] | if type == "array" then .[0] else . end] | index($p)' "$WORK/releaserc.json")
        idx_second=$(jq --arg p "$second" '[.plugins[] | if type == "array" then .[0] else . end] | index($p)' "$WORK/releaserc.json")
        if [ "$idx_first" = "null" ] || [ "$idx_second" = "null" ] || [ "$idx_first" -ge "$idx_second" ]; then
          ok=0; detail="$detail\n    order: expected $first before $second, got indexes $idx_first and $idx_second"
        fi ;;
      *) ok=0; detail="$detail\n    unknown expectation '$e'" ;;
    esac
  done

  if [ "$ok" -eq 1 ]; then
    PASSED=$((PASSED + 1)); echo "  PASS  $desc"
  else
    FAILED=$((FAILED + 1)); echo "  FAIL  $desc"; printf "$detail\n"
  fi
}

echo "Testing the exec programs as they stand in action.yml"
echo

# --- The regression itself ------------------------------------------------------
# A repository that stamps its own version files. Before the fix these three hooks
# were dropped and the release commit carried CHANGELOG.md alone.
assert "a consumer's prepareCmd survives the reservation" \
  '{"plugins":[["@semantic-release/exec",{"prepareCmd":"sed -i s/x/y/ pyproject.toml"}]]}' \
  "exec=generateNotesCmd,prepareCmd" "len=5"

assert "every other exec hook survives too" \
  '{"plugins":[["@semantic-release/exec",{"prepareCmd":"a","verifyConditionsCmd":"b","publishCmd":"c","successCmd":"d"}]]}' \
  "exec=generateNotesCmd,prepareCmd,publishCmd,successCmd,verifyConditionsCmd" "len=5"

# --- The reservation still has to hold -------------------------------------------
# The notes seam is the reason exec is reserved at all. A consumer must not be able
# to displace it, deliberately or by copying a config from elsewhere.
assert "a consumer cannot override the action's generateNotesCmd" \
  '{"plugins":[["@semantic-release/exec",{"generateNotesCmd":"displaced","prepareCmd":"kept"}]]}' \
  "exec=generateNotesCmd,prepareCmd" \
  "execval=generateNotesCmd=node notes.mjs" \
  "execval=prepareCmd=kept"

# The action's own value must also survive the ordinary case, where the consumer
# never mentions generateNotesCmd at all - `.[1] + $exec` must not clobber it.
assert "the action's notes command survives an ordinary merge" \
  '{"plugins":[["@semantic-release/exec",{"prepareCmd":"a"}]]}' \
  "execval=generateNotesCmd=node notes.mjs"

# --- Order is load-bearing -------------------------------------------------------
# A restored prepareCmd is only useful ahead of the commit. If exec ever moves
# behind git, the hooks run but nothing they touch is committed - green again,
# wrong again.
assert "exec stays ahead of changelog and git" \
  '{"plugins":[["@semantic-release/exec",{"prepareCmd":"a"}]]}' \
  "order=@semantic-release/exec>@semantic-release/changelog" \
  "order=@semantic-release/exec>@semantic-release/git"

# --- Repositories that configure no exec at all ----------------------------------
# The overwhelming majority. Their config must come out byte-identical to what the
# action builds on its own.
assert "no exec entry leaves the config untouched" \
  '{"plugins":[["@semantic-release/npm",{"npmPublish":false}]]}' \
  "exec=generateNotesCmd" "len=5"

assert "no plugins key at all is not an error" \
  '{"tagFormat":"v${version}"}' \
  "exec=generateNotesCmd" "len=5"

# --- Shapes a hand-written config really takes -----------------------------------
assert "exec listed as a bare string is a no-op" \
  '{"plugins":["@semantic-release/exec","@semantic-release/npm"]}' \
  "exec=generateNotesCmd" "len=5"

assert "exec with no options object is a no-op" \
  '{"plugins":[["@semantic-release/exec"]]}' \
  "exec=generateNotesCmd" "len=5"

assert "two exec entries are merged, not the last one wins" \
  '{"plugins":[["@semantic-release/exec",{"prepareCmd":"a"}],["@semantic-release/exec",{"publishCmd":"b"}]]}' \
  "exec=generateNotesCmd,prepareCmd,publishCmd"

# --- Malformed input must not corrupt the config ---------------------------------
# jq exits non-zero here; the action's `|| echo "{}"` has to catch it. Producing a
# broken .releaserc.json would be worse than dropping the hooks.
assert "a non-object options value is rejected, not merged" \
  '{"plugins":[["@semantic-release/exec","not-an-object"]]}' \
  "exec=generateNotesCmd" "len=5"

# --- The plugin array must keep its shape ----------------------------------------
# The extra-plugins merge further down action.yml splices with
# `[.plugins[0], .plugins[1], .plugins[2]] + $extra + [.plugins[3], .plugins[4]]`.
# It is positional, so anything that changes the array's length silently rebuilds
# the pipeline in the wrong order.
assert "the merge preserves array length for the positional splice below" \
  '{"plugins":[["@semantic-release/exec",{"prepareCmd":"a","successCmd":"b"}]]}' \
  "len=5" "order=@semantic-release/commit-analyzer>@semantic-release/exec" \
  "order=@semantic-release/git>@semantic-release/github"

# --- @semantic-release/github options --------------------------------------------
# The second half of the same mistake. github is reserved like exec, but the action
# owns no option on it, so reserving it discarded everything a repository set. Unlike
# the exec case this one left no trace at all: there was no extraction to inspect and
# no key to notice missing, only a release that quietly kept commenting on issues a
# repository had asked it not to touch.
assert "a consumer's github options reach the plugin" \
  '{"plugins":[["@semantic-release/github",{"successComment":false,"failComment":false,"releasedLabels":false}]]}' \
  "ghval=successComment=false" "ghval=failComment=false" "ghval=releasedLabels=false" "len=5"

assert "github stays in place when its options are merged" \
  '{"plugins":[["@semantic-release/github",{"successComment":false}]]}' \
  "len=5" "order=@semantic-release/git>@semantic-release/github"

assert "no github options leaves the bare entry alone" \
  '{"plugins":[["@semantic-release/exec",{"prepareCmd":"a"}]]}' \
  "ghval=successComment=<absent>" "len=5"

assert "github as a bare string in the repo config is a no-op" \
  '{"plugins":["@semantic-release/github"]}' \
  "ghval=successComment=<absent>" "len=5"

# exec and github hooks arriving together must not interfere - they are separate
# merges over the same array, and each has to leave the other's entry intact.
assert "exec hooks and github options merge independently" \
  '{"plugins":[["@semantic-release/exec",{"prepareCmd":"stamp"}],["@semantic-release/github",{"successComment":false}]]}' \
  "exec=generateNotesCmd,prepareCmd" "execval=generateNotesCmd=node notes.mjs" \
  "ghval=successComment=false" "len=5"

# The merge's second branch handles a github entry already in array form. action.yml
# emits it bare today, so that branch is unreachable through the fixture above and
# would sit untested until the day it is not - a defensive branch nobody has ever
# run is not a defence. Exercised directly against the extracted program instead.
echo
if jq -n --argjson gh '{"successComment":false}' \
     '{"plugins":[["@semantic-release/github",{"assets":["dist/*"]}]]}' > "$WORK/arrayform.json" 2>/dev/null \
   && jq --argjson gh '{"successComment":false}' "$GITHUB_MERGE_PROGRAM" "$WORK/arrayform.json" > "$WORK/arrayform.out" 2>/dev/null; then
  KEPT=$(jq -r '.plugins[0][1].assets[0] // "<lost>"' "$WORK/arrayform.out")
  ADDED=$(jq -r '.plugins[0][1].successComment | tostring' "$WORK/arrayform.out")
  if [ "$KEPT" = "dist/*" ] && [ "$ADDED" = "false" ]; then
    PASSED=$((PASSED + 1)); echo "  PASS  an array-form github entry keeps its existing options"
  else
    FAILED=$((FAILED + 1)); echo "  FAIL  an array-form github entry keeps its existing options"
    echo "        assets: expected 'dist/*', got '$KEPT'; successComment: expected 'false', got '$ADDED'"
  fi
else
  FAILED=$((FAILED + 1)); echo "  FAIL  an array-form github entry keeps its existing options (merge program errored)"
fi

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
