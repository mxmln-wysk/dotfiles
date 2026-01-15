#!/usr/bin/env bash

FILE="$HOME/.config/hypr/monitors.conf"

if [ -z "$1" ]; then
    echo "Usage: $0 {left|up|right|mirror}"
    exit 1
fi

case "$1" in
    left)
        NEW_LINE="monitor=HDMI-A-2,1920x1080@60.0,0x1080,1.0"
        ;;
    up)
        NEW_LINE="monitor=HDMI-A-2,1920x1080@60.0,1920x0,1.0"
        ;;
    right)
        NEW_LINE="monitor=HDMI-A-2,1920x1080@60.0,3840x1080,1.0"
        ;;
    mirror)
        NEW_LINE="monitor=HDMI-A-2,1920x1080@60.0,auto,1,mirror,eDP-1"
        ;;
    *)
        echo "Unknown option '$1'. Use: left, up, right, mirror."
        exit 1
        ;;
esac

# Monitors.conf aktualisieren
sed -i "s|^monitor=HDMI-A-2.*|$NEW_LINE|" "$FILE"

# Hyprland reload
hyprctl reload
