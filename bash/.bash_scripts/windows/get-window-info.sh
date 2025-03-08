#!/bin/bash

PID_FILE="/tmp/$(basename "$0").pid"
current_date=$(date +'%Y-%m-%d')
DB_FILE="$DB_DIR/$current_date.db"

declare -A window_counts

check_and_stop_other_process() {
    # Falls eine alte PID-Datei existiert, versuche den Prozess zu beenden
    if [ -f "$PID_FILE" ]; then
        old_pid=$(cat "$PID_FILE")

        # Überprüfen, ob der alte Prozess noch läuft
        if ps -p "$old_pid" > /dev/null 2>&1; then
            echo "Alte Instanz läuft (PID: $old_pid). Sende SIGUSR1..."
            kill -USR1 "$old_pid"
            sleep 1  # Warte kurz, damit der alte Prozess beendet wird
        fi
    fi

    # Speichere die aktuelle PID in die Datei (ersetzt die alte)
    echo $$ > "$PID_FILE"
}

# Beispielaufruf der Funktion
check_and_stop_other_process


# Sicherstellen, dass die Datei existiert
touch "$DB_FILE"

timerCount=1

# Werte aus Datei laden
while IFS='=' read -r key value; do
    window_counts["$key"]=$value
done < "$DB_FILE"

# Funktion zum Speichern der Daten
save_data() {
    DB_FILE="$HOME/.window_time/$(date +'%Y-%m-%d').db"
    echo "Speichere Daten..."
    > "$DB_FILE"
    for key in "${!window_counts[@]}"; do
        echo "$key=${window_counts[$key]}" >> "$DB_FILE"
        echo "$key=${window_counts[$key]}"
    done
    hyprctl notify -1 2000 0 "Daten gespeichert"

     # Falls sich das Datum geändert hat, erstelle eine neue Datei und lösche alte Daten
    local new_date=$(date +'%Y-%m-%d')

    if [ "$new_date" != "$current_date" ]; then
        echo "Neuer Tag erkannt: Wechsle zu $new_date"
        current_date="$new_date"
        DB_FILE="$DB_DIR/$current_date.db"
        unset window_counts
        declare -A window_counts
    fi
}

#signals
trap " hyprctl notify -1 2000 0 'Signal erhalten'; save_data; exit" SIGINT SIGTERM SIGUSR1


get_active_brave_tab() {
    # Brave's Debugging API aufrufen
    local json=$(curl -s "http://localhost:9222/json")

    # Erstes Tab-Element auslesen und URL extrahieren
    local url=$(echo "$json" | jq -r '.[0] | .url')

    # Nur die Domain extrahieren
    echo "$url" | awk -F/ '{print $3}'
}

while true; do
    # Aktuelles aktive Fenster abrufen
    window=$(hyprctl activewindow | grep initialClass | awk '{print $2}')
    
    # Falls kein Fenster erkannt wurde, nächsten Durchlauf
    [ -z "$window" ] && sleep 1 && continue

    # Falls Brave aktiv ist, den Fenstertitel als Key nutzen
    if [ "$window" == "brave-browser" ]; then
        window="$(get_active_brave_tab)"
        #window=$(hyprctl activewindow | grep title | awk '{print $2}')
    fi

    # Fensterzähler erhöhen
    ((window_counts["$window"]++))

    #echo "[$(date +'%Y-%m-%d %H:%M:%S')] $window wurde auf ${window_counts[$window]} erhöht. Timer = ${timerCount}"
    
    # save all 2 min
    if [ "$timerCount" == "120" ]; then
        save_data
        timerCount=0
    fi
    
    sleep 1

    timerCount=$((timerCount+=1))
done


