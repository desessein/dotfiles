#!/usr/bin/env bash
# Polybar Toggl Track v9 — rich output:
#  [HH:MM:SS] ■ Project • Desc #tags @Client 💲 @HH:MM
# Απαιτεί: curl, jq (jq>=1.6 για fromdateiso8601)

set -o pipefail

TOKEN_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/polybar/toggl_token"

# ---------- Helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }

esc() { sed -e 's/%/%%/g'; }   # escape για polybar formatting (%)
ellipsize() {                  # κοφτή περιγραφή/ονόματα για καθαρή μπάρα
  local max="${1:-40}" s
  IFS= read -r s
  local len=${#s}
  (( len <= max )) && { printf "%s" "$s"; return; }
  printf "%s…" "${s:0:max-1}"
}

fmt_dur() { # secs -> "H:MM:SS" ή "M:SS"
  local s="$1" h=$((s/3600)) m=$(( (s%3600)/60 )) sec=$(( s%60 ))
  if (( h > 0 )); then printf "%d:%02d:%02d" "$h" "$m" "$sec"
  else                 printf "%d:%02d"       "$m" "$sec"
  fi
}

# ---------- Pre-flight ----------
if ! have curl || ! have jq; then
  echo " dipendenze mancanti (curl/jq)"
  exit 0
fi
if [ ! -r "$TOKEN_FILE" ]; then
  echo " token Toggl mancante"
  exit 0
fi

API_TOKEN=$(tr -d '[:space:]' < "$TOKEN_FILE")
[ -z "$API_TOKEN" ] && { echo " token Toggl vuoto"; exit 0; }

CURL=(curl -sfS --connect-timeout 5 --max-time 10
      -u "${API_TOKEN}:api_token"
      -H 'Content-Type: application/json')

# ---------- Current time entry ----------
CURRENT_JSON="$("${CURL[@]}" "https://api.track.toggl.com/api/v9/me/time_entries/current" 2>/dev/null || echo "")"
[ -z "$CURRENT_JSON" ] || [ "$CURRENT_JSON" = "null" ] && { echo " Nessun timer in esecuzione"; exit 0; }

# Πεδία
DESCRIPTION=$(jq -r '.description // ""' <<<"$CURRENT_JSON")
WORKSPACE_ID=$(jq -r '.workspace_id // empty' <<<"$CURRENT_JSON")
PROJECT_ID=$(jq -r '.project_id // empty' <<<"$CURRENT_JSON")
BILLABLE=$(jq -r '.billable // false' <<<"$CURRENT_JSON")
TAGS=$(jq -r '[.tags[]? | "#" + tostring] | join(" ")' <<<"$CURRENT_JSON")

# ---------- Reliable duration via jq ----------
START_EPOCH=$(jq -r 'try (.start | fromdateiso8601) catch empty' <<<"$CURRENT_JSON")
NOW_EPOCH=$(jq -nr 'now|floor')

if [ -n "$START_EPOCH" ] && [ -n "$NOW_EPOCH" ]; then
  ELAPSED=$(( NOW_EPOCH - START_EPOCH ))
  (( ELAPSED < 0 )) && ELAPSED=0
  DUR_STR=$(fmt_dur "$ELAPSED")
  START_HM=$(date -d @"$START_EPOCH" +%H:%M 2>/dev/null || jq -nr --argjson t "$START_EPOCH" '$t | todate')
else
  DUR_STR=".."
fi

# ---------- Project / Client (με μικρό caching 5')
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/polybar/toggl"
mkdir -p "$CACHE_DIR"

PROJECT_NAME=""
CLIENT_NAME=""
COLOR="#8ABEB7"  # fallback theme color

if [ -n "$WORKSPACE_ID" ] && [ -n "$PROJECT_ID" ]; then
  PKEY="${WORKSPACE_ID}_${PROJECT_ID}"
  PCACHE="$CACHE_DIR/project_${PKEY}.json"
  if [ -s "$PCACHE" ] && find "$PCACHE" -mmin -5 >/dev/null 2>&1; then
    PROJECT_JSON=$(cat "$PCACHE")
  else
    PROJECT_JSON="$("${CURL[@]}" "https://api.track.toggl.com/api/v9/workspaces/${WORKSPACE_ID}/projects/${PROJECT_ID}" 2>/dev/null || echo "")"
    [ -n "$PROJECT_JSON" ] && printf "%s" "$PROJECT_JSON" > "$PCACHE"
  fi

  if [ -n "$PROJECT_JSON" ]; then
    PROJECT_NAME=$(jq -r '.name // empty' <<<"$PROJECT_JSON")
    COLOR_VAL=$(jq -r '.color // empty' <<<"$PROJECT_JSON")
    CLIENT_ID=$(jq -r '.client_id // empty' <<<"$PROJECT_JSON")
    [[ "$COLOR_VAL" =~ ^#[0-9a-fA-F]{6}$ ]] && COLOR="$COLOR_VAL"

    if [ -n "$CLIENT_ID" ]; then
      CKEY="${WORKSPACE_ID}_${CLIENT_ID}"
      CCACHE="$CACHE_DIR/client_${CKEY}.json"
      if [ -s "$CCACHE" ] && find "$CCACHE" -mmin -60 >/dev/null 2>&1; then
        CLIENT_JSON=$(cat "$CCACHE")
      else
        CLIENT_JSON="$("${CURL[@]}" "https://api.track.toggl.com/api/v9/workspaces/${WORKSPACE_ID}/clients/${CLIENT_ID}" 2>/dev/null || echo "")"
        [ -n "$CLIENT_JSON" ] && printf "%s" "$CLIENT_JSON" > "$CCACHE"
      fi
      [ -n "$CLIENT_JSON" ] && CLIENT_NAME=$(jq -r '.name // empty' <<<"$CLIENT_JSON")
    fi
  fi
fi

# ---------- Compose pretty line ----------
ICON_CLOCK=""
SQUARE="%{F$COLOR}■%{F-}"  # πιο “καθαρό” από bullet
BILL=$( [ "$BILLABLE" = "true" ] && echo " 💲" )
WHEN=$( [ -n "$START_HM" ] && echo " @${START_HM}" )

# Escape & trim για καθαρή εμφάνιση
PROJECT_SAFE=$(printf "%s" "$PROJECT_NAME" | esc | ellipsize 24)
DESCRIPTION_SAFE=$(printf "%s" "$DESCRIPTION" | esc | ellipsize 42)
CLIENT_SAFE=$(printf "%s" "$CLIENT_NAME" | esc | ellipsize 20)
TAGS_SAFE=$(printf "%s" "$TAGS" | esc | ellipsize 32)

OUT="%{T4}$ICON_CLOCK%{T-} [${DUR_STR}] $SQUARE"
[ -n "$PROJECT_SAFE" ]    && OUT+=" $PROJECT_SAFE"
[ -n "$DESCRIPTION_SAFE" ] && { [ -n "$PROJECT_SAFE" ] && OUT+=" •"; OUT+=" $DESCRIPTION_SAFE"; }
[ -n "$TAGS_SAFE" ]       && OUT+=" $TAGS_SAFE"
[ -n "$CLIENT_SAFE" ]     && OUT+=" @$CLIENT_SAFE"
OUT+="$BILL$WHEN"

echo "$OUT"

