#!/usr/bin/env bash
# Polybar Toggl Track v9 — compact:  [HH:MM → HH:MM] ■ Project • Desc
# Απαιτεί: curl, jq (ιδανικά jq>=1.6, αλλά έχουμε και fallbacks)

set -o pipefail

TOKEN_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/polybar/toggl_token"

have(){ command -v "$1" >/dev/null 2>&1; }
esc(){ sed -e 's/%/%%/g'; }
ellipsize(){ local m="${1:-40}" s; IFS= read -r s; (( ${#s}<=m )) && { printf "%s" "$s"; } || printf "%s…" "${s:0:m-1}"; }

# --- Preflight
if ! have curl || ! have jq; then echo " dipendenze mancanti (curl/jq)"; exit 0; fi
[ -r "$TOKEN_FILE" ] || { echo " token Toggl mancante"; exit 0; }
API_TOKEN=$(tr -d '[:space:]' < "$TOKEN_FILE"); [ -n "$API_TOKEN" ] || { echo " token Toggl vuoto"; exit 0; }

CURL=(curl -sfS --connect-timeout 5 --max-time 10 -u "${API_TOKEN}:api_token" -H 'Content-Type: application/json')

# --- Current entry
CURRENT_JSON="$("${CURL[@]}" "https://api.track.toggl.com/api/v9/me/time_entries/current" 2>/dev/null || echo "")"
[ -z "$CURRENT_JSON" ] || [ "$CURRENT_JSON" = "null" ] && { echo " Nessun timer in esecuzione"; exit 0; }

DESCRIPTION=$(jq -r '.description // ""' <<<"$CURRENT_JSON")
WORKSPACE_ID=$(jq -r '.workspace_id // empty' <<<"$CURRENT_JSON")
PROJECT_ID=$(jq -r '.project_id // empty' <<<"$CURRENT_JSON")
BILLABLE=$(jq -r '.billable // false' <<<"$CURRENT_JSON")

# --- Parse start epoch (3 βήματα: jq → date ISO → date normalized)
START_EPOCH=$(jq -r 'try (.start | fromdateiso8601) catch empty' <<<"$CURRENT_JSON")
if [ -z "$START_EPOCH" ]; then
  START_ISO=$(jq -r '.start // empty' <<<"$CURRENT_JSON")
  if [ -n "$START_ISO" ]; then
    # 2a: προσπάθησε κατευθείαν
    START_EPOCH=$(date -u -d "$START_ISO" +%s 2>/dev/null || echo "")
    # 2b: αν δεν πιάσει, κάνε normalize (κόψε fractional sec, Z→+00:00)
    if [ -z "$START_EPOCH" ]; then
      NORM=$(printf "%s" "$START_ISO" | sed -E 's/\.[0-9]+//; s/Z$/+00:00/')
      START_EPOCH=$(date -u -d "$NORM" +%s 2>/dev/null || echo "")
    fi
  fi
fi

if [ -n "$START_EPOCH" ]; then
  START_HM=$(date -d @"$START_EPOCH" +%H:%M 2>/dev/null || echo "--:--")
else
  START_HM="--:--"
fi
NOW_HM=$(date +%H:%M)

# --- Project (name & color)
PROJECT_NAME=""
COLOR="#8ABEB7"
if [ -n "$WORKSPACE_ID" ] && [ -n "$PROJECT_ID" ]; then
  PROJECT_JSON="$("${CURL[@]}" "https://api.track.toggl.com/api/v9/workspaces/${WORKSPACE_ID}/projects/${PROJECT_ID}" 2>/dev/null || echo "")"
  if [ -n "$PROJECT_JSON" ]; then
    PROJECT_NAME=$(jq -r '.name // empty' <<<"$PROJECT_JSON")
    COLOR_VAL=$(jq -r '.color // empty' <<<"$PROJECT_JSON")
    [[ "$COLOR_VAL" =~ ^#[0-9a-fA-F]{6}$ ]] && COLOR="$COLOR_VAL"
  fi
fi

# --- Compose line (χωρίς client/tags)
ICON_CLOCK=""
MARK="%{F$COLOR}●%{F-} "
BILL=$( [ "$BILLABLE" = "true" ] && echo " 💲" )

PROJECT_SAFE=$(printf "%s" "$PROJECT_NAME" | esc | ellipsize 24)
DESCRIPTION_SAFE=$(printf "%s" "$DESCRIPTION"   | esc | ellipsize 42)

# OUT="%{T0}$ICON_CLOCK%{T5} [${START_HM} → ${NOW_HM}] $MARK"
# OUT="%{T4}%{F$COLOR}$ICON_CLOCK%{F-}%{T5} %{B#262a33} %{F#cbd1d8}${START_HM}%{F-} → %{F#ffffff}${NOW_HM}%{F-} %{B-} $MARK"
# OUT="%{T4}$ICON_CLOCK%{T5} %{u#444}%{+u}[%{F#9AA0A6}${START_HM}%{F-} → %{F#FFFFFF}${NOW_HM}%{F-}]%{-u} $MARK"
# OUT="%{T4}%{F$COLOR}$ICON_CLOCK%{F-}%{T5} [%{F#9AA0A6}${START_HM}%{F-} → %{F$COLOR}${NOW_HM}%{F-}] $MARK"
OUT="%{T4}%{F$COLOR}$ICON_CLOCK%{F-}%{T5} %{u$COLOR}%{+u}%{F#9AA0A6}${START_HM}%{F-} → %{F#FFFFFF}${NOW_HM}%{F-}%{-u}      $MARK"




[ -n "$PROJECT_SAFE" ]     && OUT+=" $PROJECT_SAFE"
[ -n "$DESCRIPTION_SAFE" ] && { [ -n "$PROJECT_SAFE" ] && OUT+=" •"; OUT+=" $DESCRIPTION_SAFE"; }
OUT+="$BILL"

echo "$OUT"

