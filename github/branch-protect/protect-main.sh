#!/usr/bin/env bash

# protect-main.sh
# Voraussetzungen: gh CLI (gh auth login), Org- oder Repo-Admin-Rechte

set -euo pipefail

# Farben (falls Terminal unterstützt)
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  _GREEN="$(tput setaf 2)"; _YELLOW="$(tput setaf 3)"; _RED="$(tput setaf 1)"; _CYAN="$(tput setaf 6)"; _RESET="$(tput sgr0)"
else
  _GREEN=""; _YELLOW=""; _RED=""; _CYAN=""; _RESET=""
fi

log() { printf '%b\n' "${_CYAN}[info]${_RESET} $*"; }
warn() { printf '%b\n' "${_YELLOW}[warn]${_RESET} $*"; }
err()  { printf '%b\n' "${_RED}[error]${_RESET} $*" >&2; }
succ() { printf '%b\n' "${_GREEN}[ok]${_RESET} $*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Benötigtes Kommando '$1' nicht gefunden"; exit 1; }
}

require_cmd gh

if ! gh auth status >/dev/null 2>&1; then
  err "Nicht bei GitHub angemeldet. Bitte 'gh auth login' ausführen."; exit 1
fi

# ==== KONFIG ====
# ENTWEDER ORG setzen (alle Repos einer Organisation) ODER REPO_LIST (Whitespace/Zeilen separierte owner/repo Namen)
# Wenn beides gesetzt ist, hat ORG Priorität.
ORG="${ORG:-}"                              # Organisation (leer lassen falls REPO_LIST genutzt wird)
BRANCH="${BRANCH:-main}"                   # Zu schützender Branch
REVIEWS="${REVIEWS:-2}"                    # Anzahl benötigter Reviews
INCLUDE_ADMINS="${INCLUDE_ADMINS:-true}"   # Admins einbeziehen (true/false)
LINEAR_HISTORY="${LINEAR_HISTORY:-true}"   # required_linear_history
ALLOW_FORCE_PUSHES="${ALLOW_FORCE_PUSHES:-false}"
ALLOW_DELETIONS="${ALLOW_DELETIONS:-false}"
REQUIRE_CONVERSATION_RESOLUTION="${REQUIRE_CONVERSATION_RESOLUTION:-true}"
STRICT_UPTODATE="${STRICT_UPTODATE:-true}" # "Require branches to be up to date before merging"

# Optional: Status-Checks (Kontextnamen deiner CI). Beispiel: "ci/test" "lint" "build"
STATUS_CHECKS=(${STATUS_CHECKS:-})   # per ENV setzen: STATUS_CHECKS="ci/test lint build"
# Optional: Push-Restrictions (nur diese Teams/Users dürfen pushen/bypassen)
RESTRICT_TEAMS=(${RESTRICT_TEAMS:-}) # z.B. RESTRICT_TEAMS="maintainers release-managers"
RESTRICT_USERS=(${RESTRICT_USERS:-}) # z.B. RESTRICT_USERS="karlspace"

# ==== REPO-LISTE HOLEN / VALIDIEREN ====
usage() {
  cat <<USAGE
Usage: (Variablen setzen und Script ausführen)

  Mit Organisation:
    export ORG="mein-org"; bash protect-main.sh

  Mit expliziter Repo-Liste:
    export REPO_LIST="owner1/repoA owner2/repoB"; bash protect-main.sh
    # oder multiline:
    export REPO_LIST=$'owner1/repoA\nowner2/repoB'

Erforderlich: Entweder ORG ODER REPO_LIST. Falls beides gesetzt, wird ORG verwendet.
Weitere Optionen: BRANCH, STATUS_CHECKS, REVIEWS, REQUIRE_SIGNED_COMMITS, usw.
USAGE
}

RAW_REPO_LIST="${REPO_LIST:-}"
declare -a REPO_LIST_ARR=()
if [[ -n "${ORG}" ]]; then
  log "Hole Repos der Organisation '${ORG}'"
  if ! mapfile -t REPO_LIST_ARR < <(gh repo list "$ORG" --limit 1000 --json name -q '.[].name'); then
    err "Konnte Repos der Organisation nicht laden"; exit 1
  fi
elif [[ -n "${RAW_REPO_LIST}" ]]; then
  while IFS=$' \t' read -r token; do
    [[ -z "$token" ]] && continue
    REPO_LIST_ARR+=("$token")
  done < <(printf '%s\n' "$RAW_REPO_LIST")
else
  err "Weder ORG noch REPO_LIST gesetzt."
  usage
  exit 1
fi

log "Finde ${#REPO_LIST_ARR[@]} Repositories…"

# ==== HILFSFUNKTION: JSON-Array aus Bash-Array bauen ====
json_array() {
  local arr=("$@")
  if ((${#arr[@]}==0)); then
    printf '[]'
    return 0
  fi
  local out="" first=1
  for elem in "${arr[@]}"; do
    # JSON-escape nur doppelte Anführungszeichen
    elem=${elem//"/\\"}
    if (( first )); then
      out="\"$elem\""; first=0
    else
      out+=" ,\"$elem\""
    fi
  done
  printf '[%s]' "$out"
}

STATUS_JSON=$(json_array "${STATUS_CHECKS[@]}")
TEAMS_JSON=$(json_array "${RESTRICT_TEAMS[@]}")
USERS_JSON=$(json_array "${RESTRICT_USERS[@]}")

# ==== HAUPTSCHLEIFE ====
for NAME in "${REPO_LIST_ARR[@]}"; do
  # Name ggf. zu ORG/NAME zusammensetzen
  if [[ "$NAME" != */* ]] && [[ -n "${ORG}" ]]; then
    FULL="${ORG}/${NAME}"
  else
    FULL="${NAME}"
  fi

  log "Schütze ${FULL}@${BRANCH}"

  # Branch-Protection setzen
  if ! gh api \
    -X PUT \
    -H "Accept: application/vnd.github+json" \
    "repos/${FULL}/branches/${BRANCH}/protection" \
    --input - <<EOF >/dev/null; then
{
  "required_status_checks": {
    "strict": ${STRICT_UPTODATE},
    "contexts": ${STATUS_JSON}
  },
  "enforce_admins": ${INCLUDE_ADMINS},
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": ${REVIEWS}
  },
  "restrictions": $( if [[ ${#RESTRICT_TEAMS[@]} -gt 0 || ${#RESTRICT_USERS[@]} -gt 0 ]]; then
      printf '{"users": %s, "teams": %s, "apps": []}' "${USERS_JSON}" "${TEAMS_JSON}";
    else
      printf 'null';
    fi),
  "required_linear_history": ${LINEAR_HISTORY},
  "allow_force_pushes": ${ALLOW_FORCE_PUSHES},
  "allow_deletions": ${ALLOW_DELETIONS},
  "required_conversation_resolution": ${REQUIRE_CONVERSATION_RESOLUTION}
}
EOF
    warn "Setzen der Protection fehlgeschlagen für ${FULL} (Branch existiert?)"
    continue
  fi

  # (Optional, wenn du signierte Commits erzwingen willst)
  if [[ "${REQUIRE_SIGNED_COMMITS:-false}" == "true" ]]; then
    if gh api -X POST -H "Accept: application/vnd.github+json" \
      "repos/${FULL}/branches/${BRANCH}/protection/required_signatures" >/dev/null 2>&1; then
      succ "Signaturen erzwungen"
    else
      warn "Konnte Signatur-Erzwingung nicht aktivieren (bereits aktiv oder fehlende Rechte)"
    fi
  fi
  succ "Protection gesetzt"
done
succ "Fertig."
