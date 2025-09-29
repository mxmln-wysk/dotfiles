#!/bin/bash
while true; do
    # Alle Batterien finden
    BATTERY_PATHS=($(upower -e | grep battery))
    #LINE_POWER_PATH=$(upower -e | grep line_power)
    LINE_POWER_PATH=/org/freedesktop/UPower/devices/line_power_AC

    CABLE_PLUGGED=$(upower -i "$LINE_POWER_PATH" | grep online | awk '{ print $2 }')

    BATTERY_PERCENTAGE_COMB=0
    BAT_COUNT=0

    # alle Batterien durchgehen
    for bat in "${BATTERY_PATHS[@]}"; do
        BATTERY_PERCENT=$(upower -i "$bat" | grep 'percentage:' | awk '{ print $2 }' | sed 's/%//')
        BATTERY_PERCENTAGE_COMB=$((BATTERY_PERCENTAGE_COMB + BATTERY_PERCENT))
        BAT_COUNT=$((BAT_COUNT + 1))
    done

    # Durchschnitt berechnen
    if [[ $BAT_COUNT -gt 0 ]]; then
        BATTERY_PERCENTAGE=$((BATTERY_PERCENTAGE_COMB / BAT_COUNT))
    else
        BATTERY_PERCENTAGE=0
    fi

    if [[ $BATTERY_PERCENTAGE -lt 20 ]]; then
        if [[ $CABLE_PLUGGED == "no" ]]; then
            hyprctl notify -1 4000 3 "fontsize:20 Batterie bei $BATTERY_PERCENTAGE%!"
        fi
    fi
    sleep 300
done
