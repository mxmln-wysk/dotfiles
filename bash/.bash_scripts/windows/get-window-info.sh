#!/bin/bash

PID_FILE="/tmp/$(basename "$0").pid"
DB_DIR="$HOME/.window_time"
LOG_FILE="$DB_DIR/debug.log"
mkdir -p "$DB_DIR"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

current_date=$(date +'%Y-%m-%d')
DB_FILE="$DB_DIR/$current_date.db"
declare -A window_counts

check_and_stop_other_process() {
    if [ -f "$PID_FILE" ]; then
        old_pid=$(cat "$PID_FILE")
        if ps -p "$old_pid" > /dev/null 2>&1; then
            log "Alte Instanz läuft (PID: $old_pid). Sende SIGUSR1..."
            kill -USR1 "$old_pid"
            sleep 1
            # prüfen ob die alte Instanz wirklich beendet wurde
            if ps -p "$old_pid" > /dev/null 2>&1; then
                log "Alte Instanz lebt noch – töte hart."
                kill -TERM "$old_pid"
                sleep 1
            fi
        fi
    fi
    echo $$ > "$PID_FILE"
    log "Neue Instanz gestartet mit PID $$"
}

cleanup() {
    log "Beende Script (PID $$)..."
    save_data
    rm -f "$PID_FILE"
    log "PID-File entfernt"
    hyprctl notify -1 2000 0 "Script beendet und PID-File entfernt"
    exit
}

check_and_stop_other_process

# Werte aus Datei laden (falls vorhanden)
if [ -f "$DB_FILE" ]; then
    while IFS='=' read -r key value; do
        window_counts["$key"]=$value
    done < "$DB_FILE"
    log "Daten aus $DB_FILE geladen"
else
    touch "$DB_FILE"
    log "Neue Datenbankdatei erstellt: $DB_FILE"
fi

timerCount=1

save_data() {
    log "Speichere Daten in $DB_FILE..."
    > "$DB_FILE"
    for key in "${!window_counts[@]}"; do
        echo "$key=${window_counts[$key]}" >> "$DB_FILE"
    done
    hyprctl notify -1 2000 0 "Daten gespeichert"

    # Nach dem Speichern prüfen, ob der Tag gewechselt hat
    local new_date=$(date +'%Y-%m-%d')
    if [ "$new_date" != "$current_date" ]; then
        log "Neuer Tag erkannt: $new_date (alter: $current_date)"
        current_date="$new_date"
        DB_FILE="$DB_DIR/$current_date.db"

        # Neue Datei anlegen & Zähler zurücksetzen
        unset window_counts
        declare -A window_counts
        touch "$DB_FILE"
        log "Neue Datei für $new_date erstellt: $DB_FILE"
    fi
}

trap "cleanup" SIGINT SIGTERM SIGUSR1

BLOCKED_SITES=("lichess.org" "de.crazygames.com" "www.twitch.tv" "www.youtube.com" "www.jetpunk.com")

handle_brave_url() {
    local json=$(curl -s "http://localhost:9222/json")
    local tabs_count=$(echo "$json" | jq 'length')

    for ((i = 0; i < tabs_count; i++)); do
        local url=$(echo "$json" | jq -r ".[$i].url")
        local id=$(echo "$json" | jq -r ".[$i].id")

        for blocked in "${BLOCKED_SITES[@]}"; do
            if [[ "$url" == *"$blocked"* ]]; then
                # Spezialfall YouTube → erlauben wenn embed drin vorkommt
                if [[ "$blocked" == "www.youtube.com" && "$url" == *"/embed/"* ]]; then
                    log "YouTube-Embed erkannt: $url – erlaubt"
                    continue
                fi

                log "Blockierte Seite entdeckt: $url – Tab wird geschlossen."
                hyprctl notify -1 3000 1 "Blockierte Seite '$blocked' geschlossen!"

                # Tab schließen
                curl -s "http://localhost:9222/json/close/$id" > /dev/null

                sleep 1  # Kurze Pause, damit Tab wirklich schließt

                # Brave komplett beenden, wenn keine brauchbaren Tabs mehr offen sind
                json=$(curl -s "http://localhost:9222/json")
                local remaining_tabs=$(echo "$json" | jq 'length')
                if (( remaining_tabs == 0 )); then
                    log "Keine weiteren Tabs mehr – Brave wird beendet."
                    pkill brave-browser
                fi

                return 1
            fi
        done
    done

    # Kein blockierter Tab → ersten Tab verwenden
    window=$(echo "$json" | jq -r '.[0].url' | awk -F/ '{print $3}')
    log "Aktiver Brave-Tab: $window"
    return 0
}

# Direkt nach Start einmal speichern, um Verluste zu vermeiden
save_data

while true; do
    window=$(hyprctl activewindow | grep initialClass | awk '{print $2}')
    [ -z "$window" ] && sleep 1 && continue

    if [ "$window" == "brave-browser" ]; then
        if ! handle_brave_url; then
            sleep 2
            continue
        fi
    fi

    ((window_counts["$window"]++))
    current_window="${window_counts[$window]}"
    log "Window: $window → Zeit: ${window_counts[$window]}s"

    if [ "$timerCount" == "120" ]; then
        save_data
        timerCount=0
    fi

    sleep 1
    timerCount=$((timerCount + 1))
done
