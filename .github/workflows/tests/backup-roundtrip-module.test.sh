#!/usr/bin/env bash
#
# Behavioural test for the 'Create Backup' (id: create) and 'Pull Images'
# (id: pull) steps of ../modules-backup-roundtrip-test.yml - the two decisions
# the fixture round trip in backup-roundtrip-selftest.yml cannot reach.
#
# Create Backup: since BackupHelper 1.7.7 'backuphelper create' exits 1 when a
# component failed, yet the snapshot is still stored. The step used to end on
# that exit code, so the snapshot id stayed unknown and Inspect Snapshot - the
# step that names the failed component - never ran. A failing create cannot be
# provoked in the self-test without turning it red, so it is tested here:
#
#   exit 0, new snapshot            -> snapshot-id set, step passes
#   exit 1, new (partial) snapshot  -> snapshot-id set, step fails
#   exit 1, no new snapshot         -> no snapshot-id, step fails
#   exit 0, no new snapshot         -> step fails (zero jobs ran)
#
# Pull Images: only the services Start Stack starts (the 'services' input and
# their dependencies, transitively) are pulled, never an image under test.
#
# Validate Inputs (id: validate): the opt-in inputs are checked before anything
# is pulled or started.
#
# Create External Networks (id: networks): 'auto' creates every external
# network of the configuration, explicit names are created once, networks that
# exist already are left alone and are not removed at the end.
#
# s3-destination: Prepare Environment (id: prepare) writes the throwaway
# server's values into exactly the variables s3-env names, over env-overrides
# and generated-secrets; Prepare S3
# Destination (id: s3-prepare) puts the server on the backup service's
# networks; Check Off-Site Copy (id: s3-upload) fails unless archive and
# manifest are in the bucket with the local size - a failed upload does not
# fail 'create'; Simulate New Host (id: new-host) wipes the data dir and
# demands that the snapshot is listed off-site only.
#
# upgrade-from: Pull Previous Release (id: previous) resolves 'latest-release',
# tags and full references per service and gives the previous release the
# references the services resolve to; Build Images Under Test (id: build)
# keeps an upgraded service's build under a staging tag; Check Previous
# Release (id: previous-running) fails unless the started stack runs the
# previous release; Upgrade Stack (id: upgrade) runs the hook first, switches
# to the compose files of this commit, hands the references to the builds and
# fails when a container does not run the build afterwards - also when 'up'
# pulled or built over a reference (pull_policy: always or build).
#
# The step bodies are extracted from the workflow at runtime and run the way a
# `shell: bash` step runs (-eo pipefail). The engine CLI ('bh' from lib.sh) and
# `docker` are stubs.
#
# Usage: bash .github/workflows/tests/backup-roundtrip-module.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../modules-backup-roundtrip-test.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: workflow not found at $WORKFLOW_FILE"
  exit 1
fi
if ! command -v jq > /dev/null; then
  echo "FATAL: jq is required"
  exit 1
fi

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

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for STEP in validate prepare networks s3-prepare previous build create pull previous-running s3-upload upgrade new-host; do
  extract_step "$STEP" > "$WORK/$STEP.sh"
  if [ ! -s "$WORK/$STEP.sh" ]; then
    echo "FATAL: could not extract the '$STEP' run block from the workflow."
    echo "       The step was renamed, removed, or re-indented - update this test."
    exit 1
  fi
done

PASSED=0
FAILED=0
pass() { echo "PASS $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED + 1)); }
expect_eq() {
  local name="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$name"; else fail "$name" "got '$got', want '$want'"; fi
}
expect_rc() {
  local name="$1" got="$2" want="$3"
  if [ "$got" -eq "$want" ]; then pass "$name"; else fail "$name" "exit $got, want $want - log: $(tr '\n' ' ' < "$DIR/log" | cut -c1-400)"; fi
}
expect_log() {
  if grep -qF -- "$2" "$DIR/log"; then pass "$1"; else fail "$1" "log lacks '$2'"; fi
}

# --- wiring the tests below rely on ------------------------------------------
static_check() {
  if grep -qF -- "$2" "$WORKFLOW_FILE"; then pass "$1"; else fail "$1" "'$2' not found"; fi
}
static_check "Inspect Snapshot runs after a failed create that stored a snapshot" \
  "if: \${{ !cancelled() && steps.create.outputs.snapshot-id != '' }}"
static_check "the summary reports the create exit code" \
  "CREATE_EXIT: \${{ steps.create.outputs.create-exit-code }}"
# Verify and everything after it must keep the implicit success(): after a
# failed create the job ends with Inspect Snapshot.
VERIFY_IF=$(awk '/- name: "🔍 Verify Snapshot"/ { getline; print; exit }' "$WORKFLOW_FILE")
if [[ "$VERIFY_IF" == *"if:"* ]]; then
  fail "Verify Snapshot keeps the implicit success()" "has '$VERIFY_IF'"
else
  pass "Verify Snapshot keeps the implicit success()"
fi

mkdir -p "$WORK/bin"
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$DIR/docker.log"
[ "$1 $2" = "compose pull" ] || { echo "unexpected docker call: $*" >&2; exit 2; }
exit 0
STUB
chmod +x "$WORK/bin/docker"

reset() {
  DIR="$WORK/case-$1"
  rm -rf "$DIR"
  mkdir -p "$DIR/diagnostics"
  : > "$DIR/output"; : > "$DIR/env"; : > "$DIR/docker.log"
  export DIR
}
run_step() {
  local step="$1"; shift
  env PATH="$WORK/bin:$PATH" ROUNDTRIP_DIR="$DIR" GITHUB_OUTPUT="$DIR/output" GITHUB_ENV="$DIR/env" \
    BACKUP_SERVICE=backup START_SERVICES="" "$@" bash -eo pipefail "$WORK/$step.sh" > "$DIR/log" 2>&1
}
out() { grep "^$1=" "$DIR/output" | tail -n 1 | cut -d= -f2-; }

# === Create Backup ==============================================================
# The fake engine: 'list' prints list.before until 'create' ran, then list.after;
# 'create' exits with the code in create-exit.
cat > "$WORK/lib.sh" <<'LIB'
bh() {
  case "$1" in
    list)
      if [ -f "$DIR/created" ]; then
        [ ! -f "$DIR/list-fails" ] || { echo "Error: service not running" >&2; return 1; }
        cat "$DIR/list.after"
      else
        cat "$DIR/list.before"
      fi ;;
    create)
      touch "$DIR/created"
      echo "job main snapshot fake finished: $(cat "$DIR/create-status")"
      return "$(cat "$DIR/create-exit")" ;;
    *) echo "unexpected bh call: $*" >&2; return 2 ;;
  esac
}
LIB
OLD="2026-10-08_03-15-00"
NEW="2026-10-09_09-14-46"
NEWER="2026-10-09_09-14-58"
create_case() {
  reset "$1"
  cp "$WORK/lib.sh" "$DIR/lib.sh"
  echo "$2" > "$DIR/create-exit"
  if [ "$2" -eq 0 ]; then echo success; else echo error; fi > "$DIR/create-status"
  printf '%-24s %12d bytes\n' "$OLD" 2048 > "$DIR/list.before"
  cp "$DIR/list.before" "$DIR/list.after"
}
add_after() { printf '%-24s %12d bytes%s\n' "$1" "$2" "${3:-}" >> "$DIR/list.after"; }

create_case ok 0; add_after "$NEW" 4096
run_step create; expect_rc "create ok: step passes" $? 0
expect_eq "create ok: snapshot id" "$(out snapshot-id)" "$NEW"
expect_eq "create ok: exit code recorded" "$(out create-exit-code)" 0
if grep -q "^ROUNDTRIP_SNAPSHOT_ID=$NEW$" "$DIR/env"; then pass "create ok: id exported to the scripts"; else fail "create ok: id exported to the scripts" "missing in GITHUB_ENV"; fi
if [ -s "$DIR/diagnostics/create.log" ]; then pass "create ok: create.log written"; else fail "create ok: create.log written" "empty"; fi

create_case partial 1; add_after "$NEW" 4096
run_step create; expect_rc "failed component: step fails" $? 1
expect_eq "failed component: snapshot id still resolved" "$(out snapshot-id)" "$NEW"
expect_eq "failed component: exit code recorded" "$(out create-exit-code)" 1
expect_log "failed component: error names the stored snapshot" "'backuphelper create' exited 1: snapshot $NEW was stored"
if grep -q "^ROUNDTRIP_SNAPSHOT_ID=$NEW$" "$DIR/env"; then pass "failed component: id exported"; else fail "failed component: id exported" "missing"; fi

create_case aborted 1
run_step create; expect_rc "aborted run: step fails" $? 1
expect_eq "aborted run: no snapshot id" "$(out snapshot-id)" ""
expect_log "aborted run: error says nothing was stored" "exited 1 and stored no local snapshot"

create_case zero-jobs 0
run_step create; expect_rc "zero jobs: step fails" $? 1
expect_eq "zero jobs: no snapshot id" "$(out snapshot-id)" ""
expect_log "zero jobs: error explains the empty job list" "exited 0 but no new local snapshot appeared"

create_case sidecar-gone 1; add_after "$NEW" 4096; touch "$DIR/list-fails"
run_step create; expect_rc "sidecar gone: step fails" $? 1
expect_log "sidecar gone: error names the failing list" "'backuphelper list' failed after 'backuphelper create' (exit code 1)"

create_case two-new 0; add_after "$NEW" 4096; add_after "$NEWER" 4096
run_step create; expect_rc "two new snapshots: step passes" $? 0
expect_eq "two new snapshots: newest used" "$(out snapshot-id)" "$NEWER"
expect_log "two new snapshots: warning" "::warning::2 new snapshots"

create_case offsite-only 0; add_after "$NEW" 0 "  (off-site only)"
run_step create; expect_rc "off-site-only row: not a local snapshot" $? 1

# === Pull Images ================================================================
# Every shape the step has to handle: dependencies (map and list form, and a
# chain), an image under test, a service with a build section, services that
# are configured but not started.
cat > "$WORK/compose-config.json" <<'JSON'
{
  "services": {
    "database":   {"image": "postgres:18-alpine"},
    "files-init": {"image": "alpine:3"},
    "app":        {"image": "alpine:3", "depends_on": {"files-init": {"condition": "service_completed_successfully", "required": true}}},
    "backup":     {"image": "roundtrip-fixture/backup:ci",
                   "depends_on": {"database": {"condition": "service_healthy", "required": true},
                                  "files-init": {"condition": "service_completed_successfully", "required": true}}},
    "worker":     {"image": "acme/worker:1", "depends_on": {"database": {"condition": "service_started", "required": true}}},
    "runner":     {"image": "acme/runner:1", "depends_on": ["worker"]},
    "devtool":    {"image": "acme/devtool:1", "build": {"context": "."}},
    "decoy":      {"image": "registry.invalid/decoy:never"},
    "chain-a":    {"image": "acme/a:1", "depends_on": {"chain-b": {}}},
    "chain-b":    {"image": "acme/b:1", "depends_on": {"chain-c": {}}},
    "chain-c":    {"image": "acme/c:1", "depends_on": {"devtool": {}}}
  }
}
JSON
pull_case() {
  reset "$1"
  cp "$WORK/compose-config.json" "$DIR/compose-config.json"
  echo "roundtrip-fixture/backup:ci" > "$DIR/built-images.txt"
}
pulled() { sed -n 's/^docker compose pull --quiet //p' "$DIR/docker.log" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//'; }

pull_case all
run_step pull; expect_rc "all services: step passes" $? 0
expect_eq "all services: every pullable image" "$(pulled)" "app chain-a chain-b chain-c database decoy files-init runner worker"

pull_case selected
run_step pull START_SERVICES="app backup"; expect_rc "selected services: step passes" $? 0
expect_eq "selected services: started ones and their dependencies, no image under test" "$(pulled)" "app database files-init"

pull_case newline
run_step pull START_SERVICES=$'app\nbackup'
expect_eq "newline-separated services" "$(pulled)" "app database files-init"

pull_case list-form
run_step pull START_SERVICES="runner"
expect_eq "depends_on in list form, transitively" "$(pulled)" "database runner worker"

pull_case chain
run_step pull START_SERVICES="chain-a"
expect_eq "dependency chain, build section skipped" "$(pulled)" "chain-a chain-b chain-c"

pull_case nothing
run_step pull START_SERVICES="backup devtool"
expect_rc "only built images and their deps: step passes" $? 0
expect_eq "only built images: their dependencies" "$(pulled)" "database files-init"

pull_case only-built
run_step pull START_SERVICES="devtool"
expect_rc "nothing to pull: step passes" $? 0
if [ -s "$DIR/docker.log" ]; then fail "nothing to pull: no docker call" "$(cat "$DIR/docker.log")"; else pass "nothing to pull: no docker call"; fi
expect_log "nothing to pull: says so" "Nothing to pull"

pull_case unknown
run_step pull START_SERVICES="app not-configured"
expect_rc "unknown service: left to 'up'" $? 0
expect_eq "unknown service: the known ones still pulled" "$(pulled)" "app files-init"

# === Validate Inputs ============================================================
# Runs in a directory that holds the files the inputs name. Every input has
# its default unless the case sets it.
validate_case() {
  reset "$1"; shift
  touch "$DIR/docker-compose.yml"
  (cd "$DIR" && run_step validate \
    COMPOSE_FILE_INPUT=docker-compose.yml COMPOSE_FILES_INPUT="" PROFILES_INPUT=backup \
    PROJECT_NAME=backup-roundtrip ENV_OVERRIDES="" GENERATED_SECRETS="" BUILD_IMAGES="" \
    PREPARE_SCRIPT="" SEED_SCRIPT="" MUTATE_SCRIPT="" CHECK_SCRIPT="" STOP_SERVICES="" \
    SCRIPT_TIMEOUT=600 WAIT_TIMEOUT=600 EXTERNAL_NETWORKS="" \
    S3_DESTINATION=false S3_ENV="" S3_IMAGE="" S3_CLIENT_IMAGE="" \
    UPGRADE_FROM="" UPGRADE_FROM_COMPOSE_FILES="" UPGRADE_SCRIPT="" "$@")
}

validate_case defaults
expect_rc "validate: defaults pass" $? 0

validate_case networks EXTERNAL_NETWORKS=$'auto, proxy\ncoolify'
expect_rc "validate: external-networks 'auto' and names" $? 0

validate_case bad-network EXTERNAL_NETWORKS='proxy bad/name'
expect_rc "validate: external-networks with an invalid name" $? 1
expect_log "validate: names the invalid network" "external-networks entry 'bad/name' is neither 'auto' nor a network name"

S3_MAPPING=$'# the stack\'s names\nendpoint   APP_S3_ENDPOINT\nbucket\tAPP_S3_BUCKET\n  access-key APP_S3_ACCESS_KEY  \nsecret-key APP_S3_SECRET_KEY\nregion APP_S3_REGION\npath-style APP_S3_PATH_STYLE\nprefix APP_S3_PREFIX'
S3_IMAGES=(S3_IMAGE=ghcr.io/bauer-group/cs-minio/minio:latest S3_CLIENT_IMAGE=ghcr.io/bauer-group/cs-minio/minio-init:latest)

validate_case s3-ok S3_DESTINATION=true S3_ENV="$S3_MAPPING" "${S3_IMAGES[@]}"
expect_rc "validate: s3-env with every setting, a comment and padding" $? 0

validate_case s3-off S3_DESTINATION=false S3_ENV='nonsense' "${S3_IMAGES[@]}"
expect_rc "validate: s3-env is ignored without s3-destination" $? 0

validate_case s3-missing S3_DESTINATION=true S3_ENV=$'endpoint A\nbucket B' "${S3_IMAGES[@]}"
expect_rc "validate: s3-env without credentials" $? 1
expect_log "validate: names the missing access-key" "s3-env must map 'access-key'"
expect_log "validate: names the missing secret-key" "s3-env must map 'secret-key'"

validate_case s3-empty S3_DESTINATION=true S3_ENV="" "${S3_IMAGES[@]}"
expect_rc "validate: s3-destination without s3-env" $? 1
expect_log "validate: says s3-env is needed" "s3-destination needs s3-env"

validate_case s3-bad S3_DESTINATION=true "${S3_IMAGES[@]}" \
  S3_ENV=$'endpoint A\nbucket B\naccess-key C\nsecret-key D\nsecret-key E\nregion 1BAD\ntoken F\nprefix=G'
expect_rc "validate: broken s3-env lines" $? 1
expect_log "validate: duplicate setting" "s3-env maps 'secret-key' twice"
expect_log "validate: invalid variable name" "s3-env line is not 'setting VARIABLE' (whitespace, no '='): 'region 1BAD'"
expect_log "validate: no assignment syntax" "s3-env line is not 'setting VARIABLE' (whitespace, no '='): 'prefix=G'"
expect_log "validate: unknown setting" "s3-env: unknown setting 'token'"

validate_case s3-same-variable S3_DESTINATION=true "${S3_IMAGES[@]}" \
  S3_ENV=$'endpoint A\nbucket B\naccess-key APP_S3_KEY\nsecret-key APP_S3_KEY'
expect_rc "validate: one variable for two settings" $? 1
expect_log "validate: names the variable used twice" "s3-env names 'APP_S3_KEY' for two settings"

validate_case s3-image S3_DESTINATION=true S3_ENV="$S3_MAPPING" S3_IMAGE='minio:latest; rm -rf /' S3_CLIENT_IMAGE=mc
expect_rc "validate: s3-image that is no image reference" $? 1
expect_log "validate: names the bad image" "is not an image reference"

BUILDS='[{"service": "app", "context": "src/app"}, {"service": "app-backup", "context": "src/app-backup"}]'
validate_case upgrade-latest BUILD_IMAGES="$BUILDS" UPGRADE_FROM=latest-release
expect_rc "validate: upgrade-from latest-release" $? 0

validate_case upgrade-tag BUILD_IMAGES="$BUILDS" UPGRADE_FROM=1.4.2
expect_rc "validate: upgrade-from one tag" $? 0

validate_case upgrade-object BUILD_IMAGES="$BUILDS" \
  UPGRADE_FROM='{"app": "latest-release", "app-backup": "ghcr.io/acme/app-backup:1.4.2"}'
expect_rc "validate: upgrade-from per service" $? 0

validate_case upgrade-files BUILD_IMAGES="$BUILDS" UPGRADE_FROM=latest-release \
  UPGRADE_FROM_COMPOSE_FILES='["docker-compose.yml"]' UPGRADE_SCRIPT=docker-compose.yml
expect_rc "validate: upgrade-from with previous compose files and a hook" $? 0

validate_case upgrade-unknown BUILD_IMAGES="$BUILDS" UPGRADE_FROM='{"worker": "1.0"}'
expect_rc "validate: upgrade-from for a service that is not built" $? 1
expect_log "validate: names the service" "upgrade-from: 'worker' is not a build-images service"

validate_case upgrade-bad-spec BUILD_IMAGES="$BUILDS" UPGRADE_FROM='{"app": "1.0 && curl evil"}'
expect_rc "validate: upgrade-from spec that is neither tag nor reference" $? 1
expect_log "validate: names the spec" "upgrade-from: '1.0 && curl evil' for 'app' is neither"

validate_case upgrade-ref-string BUILD_IMAGES="$BUILDS" UPGRADE_FROM='ghcr.io/acme/app:1.0'
expect_rc "validate: a plain upgrade-from is a tag, never one reference for every service" $? 1

validate_case upgrade-no-builds UPGRADE_FROM=latest-release
expect_rc "validate: upgrade-from without build-images" $? 1
expect_log "validate: explains why builds are needed" "upgrade-from needs build-images"

validate_case upgrade-orphans UPGRADE_SCRIPT=docker-compose.yml UPGRADE_FROM_COMPOSE_FILES='["docker-compose.yml"]'
expect_rc "validate: upgrade-script without upgrade-from" $? 1
expect_log "validate: says upgrade-from is needed" "upgrade-from-compose-files and upgrade-script need upgrade-from"

validate_case upgrade-missing-file BUILD_IMAGES="$BUILDS" UPGRADE_FROM=1.0 \
  UPGRADE_FROM_COMPOSE_FILES='["docker-compose.yml", "previous.yml"]' UPGRADE_SCRIPT=upgrade.sh
expect_rc "validate: missing previous compose file and hook" $? 1
expect_log "validate: names the missing compose file" "compose file 'previous.yml' (upgrade-from-compose-files) not found"
expect_log "validate: names the missing hook" "script 'upgrade.sh' not found"

# === Prepare Environment (s3-destination) ======================================
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  version) echo "Docker 28.0.0" ;;
  compose) echo "Docker Compose version v2.40.0" ;;
  *) echo "unexpected docker call: $*" >&2; exit 2 ;;
esac
STUB
prepare_case() {
  reset "$1"; shift
  cat > "$DIR/.env.example" <<'ENV'
STACK_NAME=app
APP_S3_ENDPOINT=
APP_S3_BUCKET=
APP_S3_ACCESS_KEY=
APP_S3_SECRET_KEY=
APP_S3_REGION=
APP_S3_PREFIX=app/
OTHER_S3_BUCKET=untouched
ENV
  (cd "$DIR" && run_step prepare \
    COMPOSE_FILE_INPUT=docker-compose.yml COMPOSE_FILES_INPUT="" PROFILES_INPUT=backup \
    PROJECT_NAME=backup-roundtrip ENV_TEMPLATE=.env.example ENV_OVERRIDES="" GENERATED_SECRETS="" \
    PREPARE_SCRIPT="" SCRIPT_TIMEOUT=600 RUNNER_TEMP="$DIR/runner" GITHUB_RUN_ID=1 GITHUB_RUN_ATTEMPT=1 \
    ROUNDTRIP_S3_SERVICE=roundtrip-s3 ROUNDTRIP_S3_CLIENT=roundtrip-s3-client ROUNDTRIP_S3_BUCKET=backup-roundtrip \
    S3_IMAGE=ghcr.io/bauer-group/cs-minio/minio:latest S3_CLIENT_IMAGE=ghcr.io/bauer-group/cs-minio/minio-init:latest \
    UPGRADE_FROM_COMPOSE_FILES="" "$@")
}
env_value() { grep "^$1=" "$DIR/.env" | tail -n 1 | cut -d= -f2-; }

prepare_case s3-env S3_DESTINATION=true S3_ENV="$S3_MAPPING"
expect_rc "prepare s3: step passes" $? 0
expect_eq "prepare s3: endpoint" "$(env_value APP_S3_ENDPOINT)" "http://roundtrip-s3:9000"
expect_eq "prepare s3: bucket" "$(env_value APP_S3_BUCKET)" "backup-roundtrip"
expect_eq "prepare s3: region" "$(env_value APP_S3_REGION)" "us-east-1"
expect_eq "prepare s3: path style" "$(env_value APP_S3_PATH_STYLE)" "true"
expect_eq "prepare s3: prefix" "$(env_value APP_S3_PREFIX)" "backup-roundtrip/"
expect_eq "prepare s3: the caller's access key is the server's" "$(env_value APP_S3_ACCESS_KEY)" "$(env_value ROUNDTRIP_S3_ACCESS_KEY)"
expect_eq "prepare s3: the caller's secret key is the server's" "$(env_value APP_S3_SECRET_KEY)" "$(env_value ROUNDTRIP_S3_SECRET_KEY)"
if [[ "$(env_value ROUNDTRIP_S3_SECRET_KEY)" =~ ^[0-9a-f]{48}$ ]]; then pass "prepare s3: secret key generated"; else fail "prepare s3: secret key generated" "'$(env_value ROUNDTRIP_S3_SECRET_KEY)'"; fi
expect_log "prepare s3: secret key masked" "::add-mask::$(env_value ROUNDTRIP_S3_SECRET_KEY)"
expect_eq "prepare s3: server image" "$(env_value ROUNDTRIP_S3_IMAGE)" "ghcr.io/bauer-group/cs-minio/minio:latest"
expect_eq "prepare s3: unmapped variables untouched" "$(env_value OTHER_S3_BUCKET)" "untouched"
expect_eq "prepare s3: a key is replaced in place, not repeated" "$(grep -c '^APP_S3_BUCKET=' "$DIR/.env")" 1

# The server's values are written last: an override or a generated secret for
# a mapped variable must not point the sidecar elsewhere.
prepare_case s3-wins S3_DESTINATION=true S3_ENV="$S3_MAPPING" GENERATED_SECRETS="APP_S3_SECRET_KEY" \
  ENV_OVERRIDES=$'APP_S3_BUCKET=from-overrides\nAPP_S3_ENDPOINT=https://s3.example.test'
expect_rc "prepare s3 over overrides: step passes" $? 0
expect_eq "prepare s3: the server's bucket wins over env-overrides" "$(env_value APP_S3_BUCKET)" "backup-roundtrip"
expect_eq "prepare s3: the server's endpoint wins over env-overrides" "$(env_value APP_S3_ENDPOINT)" "http://roundtrip-s3:9000"
expect_eq "prepare s3: the server's secret key wins over generated-secrets" "$(env_value APP_S3_SECRET_KEY)" "$(env_value ROUNDTRIP_S3_SECRET_KEY)"

prepare_case s3-off S3_DESTINATION=false S3_ENV="$S3_MAPPING"
expect_rc "prepare without s3-destination: step passes" $? 0
expect_eq "prepare without s3-destination: endpoint untouched" "$(env_value APP_S3_ENDPOINT)" ""
expect_eq "prepare without s3-destination: no server keys" "$(grep -c '^ROUNDTRIP_S3_' "$DIR/.env")" 0

# === Create External Networks ===================================================
# The fake docker: 'network inspect' succeeds for the names in
# existing-networks, 'network create' records the name.
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$DIR/docker.log"
case "$1 $2" in
  "network inspect") grep -qxF "$3" "$DIR/existing-networks" ;;
  "network create")  echo "$3" >> "$DIR/created.log" ;;
  *) echo "unexpected docker call: $*" >&2; exit 2 ;;
esac
STUB
networks_case() {
  reset "$1"
  : > "$DIR/existing-networks"; : > "$DIR/created.log"
  cat > "$DIR/compose-config.json" <<'JSON'
{
  "networks": {
    "default": {"name": "rt_default", "ipam": {}},
    "local":   {"name": "rt-local", "driver": "bridge"},
    "proxy":   {"name": "roundtrip-proxy", "external": true},
    "coolify": {"name": "coolify", "external": true}
  },
  "services": {}
}
JSON
}
created() { sort "$DIR/created.log" | tr '\n' ' ' | sed 's/ $//'; }
recorded() { sort "$DIR/created-networks.txt" | tr '\n' ' ' | sed 's/ $//'; }

networks_case auto; echo coolify > "$DIR/existing-networks"
run_step networks EXTERNAL_NETWORKS=auto; expect_rc "networks auto: step passes" $? 0
expect_eq "networks auto: the missing external network is created" "$(created)" "roundtrip-proxy"
expect_eq "networks auto: only the created one is removed at the end" "$(recorded)" "roundtrip-proxy"
expect_log "networks auto: an existing one is left alone" "coolify exists already - left as it is"

networks_case explicit
run_step networks EXTERNAL_NETWORKS=$'edge, edge\nproxy-b'; expect_rc "networks explicit: step passes" $? 0
expect_eq "networks explicit: each name created once" "$(created)" "edge proxy-b"

networks_case mixed
run_step networks EXTERNAL_NETWORKS="auto coolify"
expect_eq "networks auto plus a name it also finds: created once" "$(created)" "coolify roundtrip-proxy"

networks_case none
echo '{"networks": {"default": {"name": "rt_default"}}, "services": {}}' > "$DIR/compose-config.json"
run_step networks EXTERNAL_NETWORKS=auto; expect_rc "networks auto without external networks: step passes" $? 0
expect_eq "networks auto without external networks: nothing created" "$(created)" ""
expect_log "networks auto without external networks: says so" "'auto' found no external network"

# === Prepare S3 Destination =====================================================
# The fake docker renders the configuration with the override, as Compose
# merges it: the fixture's own services plus the two the override adds.
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$DIR/docker.log"
case "$*" in
  "compose config --quiet") ;;
  "compose config --format json")
    jq --arg s3 "$ROUNDTRIP_S3_SERVICE" --arg client "$ROUNDTRIP_S3_CLIENT" \
      '.services[$s3] = {"image": "minio"} | .services[$client] = {"image": "mc"}' "$DIR/config.in" ;;
  *) echo "unexpected docker call: $*" >&2; exit 2 ;;
esac
STUB
s3_prepare_case() {
  reset "$1"
  printf '%s\n' "$2" > "$DIR/config.in"
  cp "$DIR/config.in" "$DIR/compose-config.json"
}
run_s3_prepare() {
  run_step s3-prepare COMPOSE_FILE=docker-compose.yml \
    ROUNDTRIP_S3_SERVICE=roundtrip-s3 ROUNDTRIP_S3_CLIENT=roundtrip-s3-client
}
OVERRIDE_FILE() { echo "$DIR/s3-destination.compose.yml"; }

s3_prepare_case networks '{"services": {"backup": {"image": "b", "networks": {"local": null, "proxy": {"aliases": ["x"]}}}}}'
run_s3_prepare; expect_rc "s3-prepare: step passes" $? 0
expect_eq "s3-prepare: the server joins the backup service's networks" \
  "$(grep -c '^    networks: \["local","proxy"\]$' "$(OVERRIDE_FILE)")" 2
if grep -q "^COMPOSE_FILE=docker-compose.yml:$(OVERRIDE_FILE)$" "$DIR/env"; then pass "s3-prepare: the override joins COMPOSE_FILE"; else fail "s3-prepare: the override joins COMPOSE_FILE" "$(cat "$DIR/env")"; fi
# shellcheck disable=SC2016 # the generated file holds the literal reference
if grep -q '^      MINIO_ROOT_PASSWORD: \${ROUNDTRIP_S3_SECRET_KEY}$' "$(OVERRIDE_FILE)"; then pass "s3-prepare: credentials stay .env references"; else fail "s3-prepare: credentials stay .env references" "$(cat "$(OVERRIDE_FILE)")"; fi
expect_eq "s3-prepare: the client only runs on demand" "$(grep -c '^    profiles: \["roundtrip-s3-client"\]$' "$(OVERRIDE_FILE)")" 1
if jq -e '.services | has("roundtrip-s3")' "$DIR/compose-config.json" > /dev/null; then pass "s3-prepare: configuration re-rendered with the server"; else fail "s3-prepare: configuration re-rendered with the server" "missing"; fi

s3_prepare_case default '{"services": {"backup": {"image": "b"}}}'
run_s3_prepare; expect_rc "s3-prepare: backup service on the default network" $? 0
expect_eq "s3-prepare: the server joins the default network" "$(grep -c '^    networks: \["default"\]$' "$(OVERRIDE_FILE)")" 2

s3_prepare_case collision '{"services": {"backup": {"image": "b"}, "roundtrip-s3": {"image": "x"}}}'
run_s3_prepare; expect_rc "s3-prepare: a service named like the server" $? 1
expect_log "s3-prepare: names the collision" "the configuration already has a service 'roundtrip-s3'"

s3_prepare_case network-mode '{"services": {"backup": {"image": "b", "network_mode": "host"}}}'
run_s3_prepare; expect_rc "s3-prepare: backup service with network_mode" $? 1
expect_log "s3-prepare: explains network_mode" "uses network_mode"

# === Check Off-Site Copy ========================================================
# The fake engine lists the local snapshot; the fake client prints the bucket
# listing the way 'mc ls --recursive --json' does, one object per line.
cat > "$WORK/lib.sh" <<'LIB'
bh() { [ "$1" = list ] || { echo "unexpected bh call: $*" >&2; return 2; }; cat "$DIR/list"; }
s3c() { echo "$*" >> "$DIR/s3c.log"; cat "$DIR/bucket"; }
LIB
SID="2026-10-09_09-14-46"
upload_case() {
  reset "$1"
  cp "$WORK/lib.sh" "$DIR/lib.sh"
  mkdir -p "$DIR/diagnostics"
  printf '%-24s %12d bytes\n' "$SID" 4096 > "$DIR/list"
  : > "$DIR/bucket"
}
object() { printf '{"status":"success","type":"file","size":%d,"key":"%s","storageClass":"STANDARD"}\n' "$2" "$1" >> "$DIR/bucket"; }
run_upload() { run_step s3-upload SNAPSHOT_ID="$SID" ROUNDTRIP_S3_BUCKET=backup-roundtrip; }

upload_case ok; object "app/$SID.tar.gz" 4096; object "app/$SID.manifest.json" 900
run_upload; expect_rc "s3-upload: archive and manifest in the bucket" $? 0
expect_eq "s3-upload: the bucket is listed recursively" "$(cat "$DIR/s3c.log")" "ls --recursive --json rt/backup-roundtrip"
if [ -s "$DIR/diagnostics/s3-objects.json" ]; then pass "s3-upload: listing kept for the summary and artifact"; else fail "s3-upload: listing kept for the summary and artifact" "empty"; fi

upload_case encrypted; object "$SID.tar.gz.age" 4096; object "$SID.manifest.json" 900
run_upload; expect_rc "s3-upload: encrypted archive without prefix" $? 0

upload_case noise; echo "Container backup-roundtrip-roundtrip-s3-client-run-1 Creating" >> "$DIR/bucket"
object "app/$SID.tar.gz" 4096; object "app/$SID.manifest.json" 900
run_upload; expect_rc "s3-upload: client chatter is not an object" $? 0

upload_case no-manifest; object "app/$SID.tar.gz" 4096
run_upload; expect_rc "s3-upload: manifest missing" $? 1
expect_log "s3-upload: names the missing manifest" "the manifest $SID.manifest.json is not in the bucket"

upload_case empty-manifest; object "app/$SID.tar.gz" 4096; object "app/$SID.manifest.json" 0
run_upload; expect_rc "s3-upload: empty manifest object" $? 1
expect_log "s3-upload: an empty manifest does not count" "the manifest $SID.manifest.json is not in the bucket"

upload_case truncated; object "app/$SID.tar.gz" 1024; object "app/$SID.manifest.json" 900
run_upload; expect_rc "s3-upload: archive smaller than the local one" $? 1
expect_log "s3-upload: names both sizes" "the archive in the bucket has 1024 bytes, the local one 4096"

upload_case empty
run_upload; expect_rc "s3-upload: empty bucket" $? 1
expect_log "s3-upload: archive missing" "the archive of snapshot $SID is not in the bucket"
expect_log "s3-upload: explains why create passed" "'create' exits 0 in that case"

upload_case other-snapshot; object "app/2026-10-08_03-15-00.tar.gz" 4096; object "app/2026-10-08_03-15-00.manifest.json" 900
run_upload; expect_rc "s3-upload: only another snapshot in the bucket" $? 1

# === Simulate New Host ==========================================================
# The fake docker answers the inspections from files and records what is
# removed, wiped and started; once the sidecar is started again, the fake
# engine lists list.after.
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$DIR/docker.log"
case "$1 $2" in
  "compose ps") cat "$DIR/container" ;;
  "inspect --format")
    case "$3" in
      "{{.Image}}") echo "sha256:sidecar" ;;
      "{{range .Config.Env}}{{println .}}{{end}}") cat "$DIR/container-env" ;;
      "{{json .Mounts}}") cat "$DIR/mounts.json" ;;
      *) echo "unexpected inspect: $*" >&2; exit 2 ;;
    esac ;;
  "compose rm") echo "removed ${*: -1}" >> "$DIR/actions" ;;
  "run --rm") echo "wiped $(printf '%s\n' "$@" | grep ':/wipe$') with $(printf '%s\n' "$@" | grep '^sha256:')" >> "$DIR/actions" ;;
  "compose up") echo "started ${*: -1}" >> "$DIR/actions"; touch "$DIR/restarted" ;;
  *) echo "unexpected docker call: $*" >&2; exit 2 ;;
esac
STUB
cat > "$WORK/lib.sh" <<'LIB'
bh() {
  [ "$1" = list ] || { echo "unexpected bh call: $*" >&2; return 2; }
  if [ -f "$DIR/restarted" ]; then cat "$DIR/list.after"; else cat "$DIR/list.before"; fi
}
LIB
host_case() {
  reset "$1"
  cp "$WORK/lib.sh" "$DIR/lib.sh"
  echo "0123456789ab" > "$DIR/container"
  printf 'PATH=/usr/bin\nBACKUP_DATA_DIR=/data\n' > "$DIR/container-env"
  echo '[{"Type": "volume", "Name": "rt-backup-data", "Source": "/var/lib/docker/volumes/rt-backup-data/_data", "Destination": "/data"},
         {"Type": "volume", "Name": "rt-files", "Destination": "/srv/files"}]' > "$DIR/mounts.json"
  printf '%-24s %12d bytes\n' "$SID" 4096 > "$DIR/list.before"
  printf '%-24s %12d bytes  (off-site only)\n' "$SID" 0 > "$DIR/list.after"
  : > "$DIR/actions"
}
run_host() { run_step new-host SNAPSHOT_ID="$SID" WAIT_TIMEOUT=60; }
actions() { tr '\n' '|' < "$DIR/actions" | sed 's/|$//'; }

host_case volume
run_host; expect_rc "new-host: data volume wiped, snapshot off-site only" $? 0
expect_eq "new-host: removes the container, wipes the data volume with the sidecar image, starts it again" \
  "$(actions)" "removed backup|wiped rt-backup-data:/wipe with sha256:sidecar|started backup"

host_case bind
echo '[{"Type": "bind", "Source": "/srv/backup", "Destination": "/backup"}]' > "$DIR/mounts.json"
printf 'BACKUP_DATA_DIR=/backup\n' > "$DIR/container-env"
run_host; expect_rc "new-host: bind mount at BACKUP_DATA_DIR" $? 0
expect_eq "new-host: wipes the bind mount" "$(actions)" "removed backup|wiped /srv/backup:/wipe with sha256:sidecar|started backup"

host_case no-mount
echo '[]' > "$DIR/mounts.json"
run_host; expect_rc "new-host: data dir inside the container" $? 0
expect_eq "new-host: nothing to wipe besides the container" "$(actions)" "removed backup|started backup"

host_case tmpfs
echo '[{"Type": "tmpfs", "Destination": "/data"}]' > "$DIR/mounts.json"
run_host; expect_rc "new-host: a tmpfs data dir" $? 1
expect_log "new-host: names the mount type" "is a tmpfs mount"

host_case survived
printf '%-24s %12d bytes\n' "$SID" 4096 > "$DIR/list.after"
run_host; expect_rc "new-host: a local snapshot survived" $? 1
expect_log "new-host: names the surviving snapshot" "local snapshots survived the wipe: $SID"

host_case unreachable
echo "no snapshots found" > "$DIR/list.after"
run_host; expect_rc "new-host: the new sidecar does not see the bucket" $? 1
expect_log "new-host: says the snapshot is not listed off-site" "does not list snapshot $SID as off-site"

host_case not-running
: > "$DIR/container"
run_host; expect_rc "new-host: sidecar not running" $? 1
expect_log "new-host: says so" "'backup' is not running"

# === Pull Previous Release ======================================================
# The fake docker records pulls and tags; a reference listed in unpullable
# fails to pull. The fake curl answers the releases API from release.json.
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$DIR/docker.log"
case "$1" in
  pull) ! grep -qxF "$2" "$DIR/unpullable" ;;
  tag)  echo "$2 -> $3" >> "$DIR/tags" ;;
  *) echo "unexpected docker call: $*" >&2; exit 2 ;;
esac
STUB
cat > "$WORK/bin/curl" <<'STUB'
#!/usr/bin/env bash
echo "curl ${*: -1}" >> "$DIR/curl.log"
[ -f "$DIR/release.json" ] || { echo "curl: (22) The requested URL returned error: 404" >&2; exit 22; }
cat "$DIR/release.json"
STUB
chmod +x "$WORK/bin/curl"
previous_case() {
  reset "$1"
  : > "$DIR/unpullable"; : > "$DIR/tags"; : > "$DIR/curl.log"
  cat > "$DIR/compose-config.json" <<'JSON'
{"services": {
  "app":        {"image": "ghcr.io/acme/app:stable"},
  "worker":     {"image": "ghcr.io/acme/app:stable"},
  "app-backup": {"image": "registry.example.com:5000/acme/app-backup@sha256:0123"},
  "cache":      {"image": "redis:8"}
}}
JSON
}
PREVIOUS_BUILDS='[{"service": "app", "context": "src/app"}, {"service": "app-backup", "context": "src/app-backup"}]'
run_previous() {
  run_step previous BUILD_IMAGES="$PREVIOUS_BUILDS" GH_TOKEN=token-for-the-test \
    GITHUB_API_URL=https://api.github.test GITHUB_REPOSITORY=acme/stack "$@"
}
tags() { tr '\n' '|' < "$DIR/tags" | sed 's/|$//'; }

previous_case latest; echo '{"tag_name": "v0.2.61", "name": "v0.2.61"}' > "$DIR/release.json"
run_previous UPGRADE_FROM=latest-release; expect_rc "previous latest-release: step passes" $? 0
expect_eq "previous latest-release: asks the releases API of this repository" "$(cat "$DIR/curl.log")" "curl https://api.github.test/repos/acme/stack/releases/latest"
expect_eq "previous latest-release: the release's images take over the references (leading v dropped, tag and digest replaced, registry port kept)" \
  "$(tags)" "ghcr.io/acme/app:0.2.61 -> ghcr.io/acme/app:stable|registry.example.com:5000/acme/app-backup:0.2.61 -> registry.example.com:5000/acme/app-backup@sha256:0123"
expect_eq "previous latest-release: references kept out of Pull Images" "$(sort "$DIR/previous-images.txt" | tr '\n' ' ')" "ghcr.io/acme/app:stable registry.example.com:5000/acme/app-backup@sha256:0123 "
if grep -q '^ROUNDTRIP_PREVIOUS_RELEASE=v0.2.61$' "$DIR/env"; then pass "previous latest-release: release exported for the scripts"; else fail "previous latest-release: release exported for the scripts" "$(cat "$DIR/env")"; fi
expect_eq "previous latest-release: images exported for the scripts" \
  "$(sed -n 's/^ROUNDTRIP_PREVIOUS_IMAGES=//p' "$DIR/env" | jq -c .)" \
  '{"app":"ghcr.io/acme/app:0.2.61","app-backup":"registry.example.com:5000/acme/app-backup:0.2.61"}'
expect_eq "previous latest-release: plan for the upgrade and the summary" "$(cut -f 1,2 "$DIR/upgrade-plan.tsv" | tr '\t\n' ' |')" \
  "app ghcr.io/acme/app:0.2.61|app-backup registry.example.com:5000/acme/app-backup:0.2.61|"

previous_case tag
run_previous UPGRADE_FROM=1.4.2; expect_rc "previous tag: step passes" $? 0
expect_eq "previous tag: no API call for a plain tag" "$(cat "$DIR/curl.log")" ""
expect_eq "previous tag: one tag for every built service" "$(cut -d' ' -f1 "$DIR/tags" | tr '\n' ' ')" \
  "ghcr.io/acme/app:1.4.2 registry.example.com:5000/acme/app-backup:1.4.2 "

previous_case object; echo '{"tag_name": "2.0.0"}' > "$DIR/release.json"
run_previous UPGRADE_FROM='{"app-backup": "ghcr.io/acme/legacy-backup:0.17.29", "app": "latest-release"}'
expect_rc "previous per service: step passes" $? 0
expect_eq "previous per service: a full reference is used as given, latest-release resolved" "$(tags)" \
  "ghcr.io/acme/legacy-backup:0.17.29 -> registry.example.com:5000/acme/app-backup@sha256:0123|ghcr.io/acme/app:2.0.0 -> ghcr.io/acme/app:stable"

previous_case only-one
run_previous UPGRADE_FROM='{"app": "1.0.0"}'
expect_eq "previous per service: a service left out keeps its reference" "$(tags)" "ghcr.io/acme/app:1.0.0 -> ghcr.io/acme/app:stable"

previous_case no-release
run_previous UPGRADE_FROM=latest-release; expect_rc "previous: repository without a release" $? 1
expect_log "previous: says there is no release" "acme/stack has no published release to upgrade from"

previous_case odd-release; echo '{"tag_name": "release/2026-10"}' > "$DIR/release.json"
run_previous UPGRADE_FROM=latest-release; expect_rc "previous: release tag that is no image tag" $? 1
expect_log "previous: asks for the tag instead" "does not give an image tag"

previous_case unpublished; echo "ghcr.io/acme/app:9.9.9" > "$DIR/unpullable"
run_previous UPGRADE_FROM=9.9.9; expect_rc "previous: image not published under the tag" $? 1
expect_log "previous: names the image" "'ghcr.io/acme/app:9.9.9' could not be pulled"

previous_case no-image
jq '.services.app |= del(.image)' "$DIR/compose-config.json" > "$DIR/c.json" && mv "$DIR/c.json" "$DIR/compose-config.json"
run_previous UPGRADE_FROM=1.0.0; expect_rc "previous: service without an image reference" $? 1
expect_log "previous: names the service" "service 'app' has no image reference"
rm -f "$WORK/bin/curl"

# === Build Images Under Test ====================================================
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
[ "$1" = build ] || { echo "unexpected docker call: $*" >&2; exit 2; }
# Records the tags of each build.
TAGS=(); while [ $# -gt 0 ]; do [ "$1" != --tag ] || TAGS+=("$2"); shift; done
echo "${TAGS[*]}" >> "$DIR/builds"
STUB
build_case() {
  reset "$1"
  : > "$DIR/builds"
  echo '{"services": {"app": {"image": "ghcr.io/acme/app:stable"}, "worker": {"image": "ghcr.io/acme/worker:stable"}}}' > "$DIR/compose-config.json"
}
BUILD_BOTH='[{"service": "app", "context": "."}, {"service": "worker", "context": "."}]'

build_case plain
run_step build BUILD_IMAGES="$BUILD_BOTH"; expect_rc "build: step passes" $? 0
expect_eq "build: tagged as the references, as before" "$(tr '\n' '|' < "$DIR/builds")" "ghcr.io/acme/app:stable|ghcr.io/acme/worker:stable|"
if [ -f "$DIR/staged-images.txt" ]; then fail "build: no staging without upgrade-from" "staged-images.txt exists"; else pass "build: no staging without upgrade-from"; fi

build_case upgrade; printf 'app\tghcr.io/acme/app:1.0\tghcr.io/acme/app:stable\n' > "$DIR/upgrade-plan.tsv"
run_step build BUILD_IMAGES="$BUILD_BOTH"; expect_rc "build with upgrade-from: step passes" $? 0
expect_eq "build with upgrade-from: the upgraded service waits under a staging tag, the other runs from the start" \
  "$(tr '\n' '|' < "$DIR/builds")" "roundtrip-staged/image-0:build|roundtrip-staged/image-1:build ghcr.io/acme/worker:stable|"
expect_eq "build with upgrade-from: only the image running from the start is under test yet" "$(cat "$DIR/built-images.txt")" "ghcr.io/acme/worker:stable"
expect_eq "build with upgrade-from: every build is staged for the upgrade" "$(tr '\t\n' ' |' < "$DIR/staged-images.txt")" \
  "app roundtrip-staged/image-0:build|worker roundtrip-staged/image-1:build|"

# === Pull Images (upgrade-from) =================================================
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$DIR/docker.log"
[ "$1 $2" = "compose pull" ] || { echo "unexpected docker call: $*" >&2; exit 2; }
STUB
pull_case previous
echo "alpine:3" > "$DIR/previous-images.txt"
run_step pull START_SERVICES="app backup"
expect_eq "pull: the previous release's images are local, not pulled" "$(pulled)" "database"

# === Upgrade Stack ==============================================================
# The fake docker keeps image ids per reference (images/) and the image each
# container runs (running/). 'tag' moves a reference to the staged image,
# 'up' recreates the containers of every service whose reference moved -
# unless keep-running names the service, to fake Compose missing the change.
# Lines "REF ID" in pull-over make 'up' first point REF at ID, the way
# Compose pulls (pull_policy: always) or builds (pull_policy: build) over it.
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$DIR/docker.log"
key() { printf '%s' "$1" | tr '/:@' '___'; }
case "$*" in
  "compose config --quiet") ;;
  "compose config --format json") cat "$DIR/target-config.json" ;;
  "compose ps") ;;
  "compose ps -a -q "*) cat "$DIR/containers/${*: -1}" 2>/dev/null || true ;;
  "compose up "*)
    echo "up" >> "$DIR/order"
    if [ -f "$DIR/pull-over" ]; then
      while read -r REF ID; do echo "$ID" > "$DIR/images/$(key "$REF")"; done < "$DIR/pull-over"
    fi
    for f in "$DIR"/containers/*; do
      SERVICE=$(basename "$f")
      grep -qxF "$SERVICE" "$DIR/keep-running" && continue
      REF=$(jq -r --arg s "$SERVICE" '.services[$s].image' "$DIR/target-config.json")
      while read -r C; do cp "$DIR/images/$(key "$REF")" "$DIR/running/$C"; done < "$f"
    done ;;
  "tag "*) echo "tag $2" >> "$DIR/order"; cp "$DIR/images/$(key "$2")" "$DIR/images/$(key "$3")" ;;
  "image inspect --format {{.Id}} "*) cat "$DIR/images/$(key "${*: -1}")" ;;
  "inspect --format {{.Image}} "*) cat "$DIR/running/${*: -1}" ;;
  *) echo "unexpected docker call: $*" >&2; exit 2 ;;
esac
STUB
cat > "$WORK/lib.sh" <<'LIB'
bh() { echo "bh $*" >> "$DIR/order"; }
run_phase() { echo "phase $1${3:+ $3}" >> "$DIR/order"; }
LIB
upgrade_case() {
  reset "$1"
  cp "$WORK/lib.sh" "$DIR/lib.sh"
  mkdir -p "$DIR/images" "$DIR/running" "$DIR/containers"
  : > "$DIR/order"; : > "$DIR/keep-running"
  # The previous release holds the references; the builds wait staged.
  echo "sha256:old-app"    > "$DIR/images/ghcr.io_acme_app_stable"
  echo "sha256:old-backup" > "$DIR/images/ghcr.io_acme_app-backup_stable"
  echo "sha256:new-app"    > "$DIR/images/roundtrip-staged_image-0_build"
  echo "sha256:new-backup" > "$DIR/images/roundtrip-staged_image-1_build"
  printf 'app\troundtrip-staged/image-0:build\napp-backup\troundtrip-staged/image-1:build\n' > "$DIR/staged-images.txt"
  echo '{"services": {"app": {"image": "ghcr.io/acme/app:stable"}, "worker": {"image": "ghcr.io/acme/app:stable"},
                      "app-backup": {"image": "ghcr.io/acme/app-backup:stable"}, "database": {"image": "postgres:18"}}}' > "$DIR/target-config.json"
  echo c-app > "$DIR/containers/app"; printf 'c-worker-1\nc-worker-2\n' > "$DIR/containers/worker"; echo c-backup > "$DIR/containers/app-backup"
  for C in c-app c-worker-1 c-worker-2; do echo "sha256:old-app" > "$DIR/running/$C"; done
  echo "sha256:old-backup" > "$DIR/running/c-backup"
}
run_upgrade() {
  run_step upgrade ROUNDTRIP_COMPOSE_FILE_TARGET=docker-compose.yml ROUNDTRIP_PREVIOUS_RELEASE=v1.0.0 \
    UPGRADE_SCRIPT=upgrade.sh CHECK_SCRIPT=check.sh RUN_HEALTHCHECK=true WAIT_TIMEOUT=60 "$@"
}
order() { tr '\n' '|' < "$DIR/order" | sed 's/|$//'; }

upgrade_case ok
run_upgrade ROUNDTRIP_COMPOSE_EXTRA="$DIR/s3-destination.compose.yml"; expect_rc "upgrade: step passes" $? 0
expect_eq "upgrade: hook, then the new images, up, data check and healthcheck - in that order" "$(order)" \
  "phase upgrade|tag roundtrip-staged/image-0:build|tag roundtrip-staged/image-1:build|up|phase check present|bh healthcheck"
if grep -q "^COMPOSE_FILE=docker-compose.yml:$DIR/s3-destination.compose.yml$" "$DIR/env"; then pass "upgrade: the files of this commit plus the module's override"; else fail "upgrade: the files of this commit plus the module's override" "$(cat "$DIR/env")"; fi
expect_eq "upgrade: the references are under test now" "$(sort "$DIR/built-images.txt" | tr '\n' ' ')" "ghcr.io/acme/app-backup:stable ghcr.io/acme/app:stable "
expect_log "upgrade: every container checked" "Every container of an image under test runs the build of this commit"

upgrade_case no-extra
run_upgrade; expect_rc "upgrade without an override file: step passes" $? 0
if grep -q "^COMPOSE_FILE=docker-compose.yml$" "$DIR/env"; then pass "upgrade: only the files of this commit"; else fail "upgrade: only the files of this commit" "$(cat "$DIR/env")"; fi

upgrade_case stale; echo worker > "$DIR/keep-running"
run_upgrade; expect_rc "upgrade: a container kept the previous image" $? 1
expect_log "upgrade: names the service and both images" "'worker' runs old-app after 'up -d', not the build of this commit new-app (ghcr.io/acme/app:stable)"
if grep -q "phase check" "$DIR/order"; then fail "upgrade: no data check on a half-upgraded stack" "check ran"; else pass "upgrade: no data check on a half-upgraded stack"; fi

# pull_policy: always - 'up' pulls the released image over the reference and
# recreates the containers with it. They match the reference, but not the
# build: compared with the reference after 'up', this passed.
upgrade_case pull-always; echo "ghcr.io/acme/app:stable sha256:released-app" > "$DIR/pull-over"
run_upgrade; expect_rc "upgrade: 'up' pulled the released image over the build" $? 1
expect_log "upgrade: names the replaced reference" "'up' replaced the image under test ghcr.io/acme/app:stable (new-app -> released-app)"
expect_log "upgrade: names the cause" "pull_policy: always"
expect_log "upgrade: the containers run the pulled image, not the build" "'app' runs released-app after 'up -d', not the build of this commit new-app"
if grep -q "phase check" "$DIR/order"; then fail "upgrade: no data check on the released image" "check ran"; else pass "upgrade: no data check on the released image"; fi

# Two builds on one reference: the last tag holds it, and that is the build
# the containers must run.
upgrade_case shared-reference
echo "sha256:new-worker" > "$DIR/images/roundtrip-staged_image-2_build"
printf 'worker\troundtrip-staged/image-2:build\n' >> "$DIR/staged-images.txt"
run_upgrade; expect_rc "upgrade: two builds tagged as one reference" $? 0
expect_eq "upgrade: the containers run the build tagged last" "$(cat "$DIR/running/c-app")" "sha256:new-worker"

upgrade_case no-healthcheck
run_upgrade RUN_HEALTHCHECK=false UPGRADE_SCRIPT="" CHECK_SCRIPT=""
expect_eq "upgrade: without hook, check and healthcheck only the switch" "$(order)" \
  "tag roundtrip-staged/image-0:build|tag roundtrip-staged/image-1:build|up"

upgrade_case lost-reference
echo '{"services": {"worker": {"image": "ghcr.io/acme/app:stable"}}}' > "$DIR/target-config.json"
run_upgrade; expect_rc "upgrade: a built service missing from this commit's configuration" $? 1
expect_log "upgrade: names the service" "service 'app' has no image reference in the configuration of this commit"

# === Check Previous Release =====================================================
# Same fake docker. The stack has started: every reference of the plan holds
# the previous image, and the containers run what 'up' found there.
previous_running_case() {
  reset "$1"
  mkdir -p "$DIR/images" "$DIR/running" "$DIR/containers"
  echo "sha256:old-app"    > "$DIR/images/ghcr.io_acme_app_1.0"
  echo "sha256:old-app"    > "$DIR/images/ghcr.io_acme_app_stable"
  echo "sha256:old-backup" > "$DIR/images/ghcr.io_acme_app-backup_1.0"
  echo "sha256:old-backup" > "$DIR/images/ghcr.io_acme_app-backup_stable"
  printf 'app\tghcr.io/acme/app:1.0\tghcr.io/acme/app:stable\napp-backup\tghcr.io/acme/app-backup:1.0\tghcr.io/acme/app-backup:stable\n' > "$DIR/upgrade-plan.tsv"
  echo '{"services": {"app": {"image": "ghcr.io/acme/app:stable"}, "worker": {"image": "ghcr.io/acme/app:stable"},
                      "app-backup": {"image": "ghcr.io/acme/app-backup:stable"}, "database": {"image": "postgres:18"}}}' > "$DIR/compose-config.json"
  echo c-app > "$DIR/containers/app"; printf 'c-worker-1\nc-worker-2\n' > "$DIR/containers/worker"; echo c-backup > "$DIR/containers/app-backup"
  for C in c-app c-worker-1 c-worker-2; do echo "sha256:old-app" > "$DIR/running/$C"; done
  echo "sha256:old-backup" > "$DIR/running/c-backup"
}

previous_running_case ok
run_step previous-running; expect_rc "previous running: step passes" $? 0
expect_log "previous running: every container of a shared reference counted" "3 container(s) on ghcr.io/acme/app:stable run the previous release ghcr.io/acme/app:1.0"
expect_log "previous running: the sidecar too" "1 container(s) on ghcr.io/acme/app-backup:stable run the previous release ghcr.io/acme/app-backup:1.0"

# pull_policy: always at the first 'up': the registry's image replaced the
# previous release before anything was seeded.
previous_running_case pulled-at-start
echo "sha256:released-app" > "$DIR/images/ghcr.io_acme_app_stable"
for C in c-app c-worker-1 c-worker-2; do echo "sha256:released-app" > "$DIR/running/$C"; done
run_step previous-running; expect_rc "previous running: 'up' replaced the previous release" $? 1
expect_log "previous running: names the reference and the cause" "'up' replaced ghcr.io/acme/app:stable, which held the previous release ghcr.io/acme/app:1.0 (old-app -> released-app)"

previous_running_case other-container; echo "sha256:something-else" > "$DIR/running/c-worker-2"
run_step previous-running; expect_rc "previous running: a container runs another image" $? 1
expect_log "previous running: names the service" "'worker' runs something-el, not the previous release ghcr.io/acme/app:1.0 (old-app)"

previous_running_case not-started; : > "$DIR/containers/app-backup"
run_step previous-running; expect_rc "previous running: a reference no started service uses" $? 0
expect_log "previous running: warns that its upgrade is not tested" "::warning::upgrade-from: no started service runs ghcr.io/acme/app-backup:stable"

# Two plan rows for one reference ({"app": "1.0", "worker": "0.9"} with both
# built): the image tagged last holds it.
previous_running_case shared-reference
echo "sha256:older-app" > "$DIR/images/ghcr.io_acme_app_0.9"
echo "sha256:older-app" > "$DIR/images/ghcr.io_acme_app_stable"
for C in c-app c-worker-1 c-worker-2; do echo "sha256:older-app" > "$DIR/running/$C"; done
printf 'worker\tghcr.io/acme/app:0.9\tghcr.io/acme/app:stable\n' >> "$DIR/upgrade-plan.tsv"
run_step previous-running; expect_rc "previous running: the image tagged last holds a shared reference" $? 0
expect_log "previous running: checked against it" "run the previous release ghcr.io/acme/app:0.9"

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
