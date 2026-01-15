#!/bin/bash

PID_FILE="/tmp/$(basename "$0").pid"
DB_DIR="$HOME/.window_time"
#LOG_FILE="$DB_DIR/debug.log"
mkdir -p "$DB_DIR"

# --- DEBUG/LOGGING AUSKOMMENTIERT (auf Wunsch) ---
#log() {
#    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
#}

current_date=$(date +'%Y-%m-%d')
DB_FILE="$DB_DIR/$current_date.db"
declare -A window_counts

# safer read of old pid and kill if running; make sure to handle stale pidfiles
check_and_stop_other_process() {
    if [ -f "$PID_FILE" ]; then
        old_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$old_pid" ] && ps -p "$old_pid" > /dev/null 2>&1; then
            #log "Alte Instanz läuft (PID: $old_pid). Sende SIGUSR1..."
            kill -USR1 "$old_pid" 2>/dev/null || true
            sleep 1
            # prüfen ob die alte Instanz wirklich beendet wurde
            if ps -p "$old_pid" > /dev/null 2>&1; then
                #log "Alte Instanz lebt noch – töte hart."
                kill -TERM "$old_pid" 2>/dev/null || true
                sleep 1
                # If still alive, attempt kill -KILL
                if ps -p "$old_pid" > /dev/null 2>&1; then
                    kill -KILL "$old_pid" 2>/dev/null || true
                fi
            fi
        fi
    fi
    echo $$ > "$PID_FILE"
    #log "Neue Instanz gestartet mit PID $$"
}

# ensure save_data exists before cleanup uses it
save_data() {
    # minimal safe save; avoid heavy IO if arrays empty
    [ "${#window_counts[@]}" -gt 0 ] || return 0

    # ensure current DB_FILE path is correct for today
    DB_FILE="$DB_DIR/$current_date.db"
    #log "Speichere Daten in $DB_FILE..."
    > "$DB_FILE"
    for key in "${!window_counts[@]}"; do
        echo "$key=${window_counts[$key]}" >> "$DB_FILE"
    done
    # hyprctl notify optional
    hyprctl notify -1 2000 0 "Daten gespeichert" 2>/dev/null || true

    # check day rollover AFTER saving (do NOT reset before saving)
    local new_date
    new_date=$(date +'%Y-%m-%d')
    if [ "$new_date" != "$current_date" ]; then
        #log "Neuer Tag erkannt: $new_date (alter: $current_date)"
        current_date="$new_date"
        DB_FILE="$DB_DIR/$current_date.db"
        unset window_counts
        declare -A window_counts
        touch "$DB_FILE"
        #log "Neue Datei f�r $new_date erstellt: $DB_FILE"
    fi
}

cleanup() {
    #log "Beende Script (PID $$)..."
    save_data
    rm -f "$PID_FILE"
    #log "PID-File entfernt"
    hyprctl notify -1 2000 0 "Script beendet und PID-File entfernt" 2>/dev/null || true
    exit
}

# register cleanup for common signals
trap "cleanup" SIGINT SIGTERM SIGUSR1

check_and_stop_other_process

# Werte aus Datei laden (falls vorhanden)
if [ -f "$DB_FILE" ]; then
    while IFS='=' read -r key value; do
        # skip empty lines
        [ -z "$key" ] && continue
        window_counts["$key"]=$value
    done < "$DB_FILE"
    #log "Daten aus $DB_FILE geladen"
else
    touch "$DB_FILE"
    #log "Neue Datenbankdatei erstellt: $DB_FILE"
fi

timerCount=1

BLOCKED_SITES=("lichess.org" "de.crazygames.com" "www.twitch.tv" "www.youtube.com" "www.jetpunk.com" "www.chess.com")

# get_active_brave_tab kept for compatibility, but used only inside handle_brave_url
get_active_brave_tab() {
    local json url
    json=$(curl -s --max-time 2 "http://localhost:9222/json" 2>/dev/null) || json=""
    [ -z "$json" ] && return 1
    url=$(echo "$json" | jq -r '.[0] | .url' 2>/dev/null || echo "")
    [ -z "$url" ] && return 1
    echo "$url" | awk -F/ '{print $3}'
    return 0
}

handle_brave_url() {
    # Fetch with timeout and validate minimal JSON
    local json tabs_count i url id remaining_tabs blocked
    json=$(curl -s --max-time 2 "http://localhost:9222/json" 2>/dev/null) || json=""
    if [ -z "$json" ]; then
        # no response from Brave debugging API; skip brave handling for now
        #log "Brave debug API nicht erreichbar"
        return 0
    fi

    # safe parse length
    tabs_count=$(echo "$json" | jq 'length' 2>/dev/null || echo "0")
    if ! [[ "$tabs_count" =~ ^[0-9]+$ ]]; then
        tabs_count=0
    fi

    for ((i = 0; i < tabs_count; i++)); do
        url=$(echo "$json" | jq -r ".[$i].url // empty" 2>/dev/null || echo "")
        id=$(echo "$json" | jq -r ".[$i].id // empty" 2>/dev/null || echo "")
        [ -z "$url" ] && continue

        for blocked in "${BLOCKED_SITES[@]}"; do
            if [[ "$url" == *"$blocked"* ]]; then
                # Spezialfall YouTube → erlauben wenn embed drin vorkommt
                if [[ "$blocked" == "www.youtube.com" && "$url" == *"/embed/"* ]]; then
                    #log "YouTube-Embed erkannt: $url – erlaubt"
                    continue
                fi

                #log "Blockierte Seite entdeckt: $url – Tab wird geschlossen."
                hyprctl notify -1 3000 1 "Blockierte Seite '$blocked' geschlossen!" 2>/dev/null || true

                # Tab schließen (best effort)
                curl -s --max-time 2 "http://localhost:9222/json/close/$id" >/dev/null 2>&1 || true

                sleep 1

                # Brave komplett beenden, wenn keine brauchbaren Tabs mehr offen sind
                json=$(curl -s --max-time 2 "http://localhost:9222/json" 2>/dev/null) || json=""
                remaining_tabs=$(echo "$json" | jq '[.[] | select(.type=="page")] | length' 2>/dev/null || echo "0")
                if ! [[ "$remaining_tabs" =~ ^[0-9]+$ ]]; then
                    remaining_tabs=0
                fi
                if (( remaining_tabs == 0 )); then
                    #log "Keine weiteren Tabs mehr – Brave wird beendet."
                    pkill brave-browser 2>/dev/null || true
                fi

                return 1
            fi
        done
    done

    # Kein blockierter Tab → ersten Tab verwenden (safely)
    local first_url
    first_url=$(echo "$json" | jq -r '.[0].url // empty' 2>/dev/null || echo "")
    if [ -n "$first_url" ]; then
        window=$(echo "$first_url" | awk -F/ '{print $3}')
        #log "Aktiver Brave-Tab: $window"
    fi
    return 0
}

# Direkt nach Start einmal speichern, um Verluste zu vermeiden
save_data

# Main loop: robust polling with validations
while true; do
    # get active window info; use json output if available
    win_json=$(hyprctl -j activewindow 2>/dev/null || echo "")
    if [ -z "$win_json" ] || [ "$win_json" == "null" ]; then
        sleep 1
        continue
    fi

    # parse initialClass robustly
    window=$(echo "$win_json" | jq -r '.initialClass // empty' 2>/dev/null || echo "")
    # fallback if initialClass not present, try class or className fields
    if [ -z "$window" ]; then
        window=$(echo "$win_json" | jq -r '.class // .className // empty' 2>/dev/null || echo "")
    fi

    # if still empty, skip iteration
    if [ -z "$window" ]; then
        sleep 1
        continue
    fi

    # Brave special handling (non-blocking if API not reachable)
    if [ "$window" == "brave-browser" ]; then
        if ! handle_brave_url; then
            sleep 2
            continue
        fi
    fi

    # protect against empty key
    if [ -n "$window" ]; then
        # initialize to 0 if not exists
        if [ -z "${window_counts[$window]+x}" ]; then
            window_counts["$window"]=0
        fi
        window_counts["$window"]=$((window_counts["$window"] + 1))
        current_window="${window_counts[$window]}"
        #log "Window: $window → Zeit: ${window_counts[$window]}s"
    fi

    # save every 120s
    if [ "$timerCount" -ge 120 ]; then
        save_data
        timerCount=0
    fi

    sleep 1
    timerCount=$((timerCount + 1))
done
