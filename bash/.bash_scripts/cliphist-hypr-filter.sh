#!/usr/bin/env bash

# Name deines "special workspace" – bitte anpassen!
SPECIAL_WS="special:magic"

while true; do
  # Warte auf neues Clipboard-Event
  text=$(wl-paste --type text) || { sleep 0.2; continue; }

  # Abfrage: welches Fenster ist aktiv?
  active_ws=$(hyprctl activewindow -j | jq -r '.workspace.name')

  # Prüfen, ob wir im Passwortmanager-Workspace sind
  if [[ "$active_ws" == "$SPECIAL_WS" ]]; then
    echo "$(date -Iseconds) SKIPPED (active ws=$active_ws)" \
      >> ~/.cache/cliphist.log
    continue
  fi

  # Wenn nicht im Passwort-Workspace → speichern
  cliphist store <<<"$text"
done
