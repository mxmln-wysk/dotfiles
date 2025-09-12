#!/bin/bash
BG="/home/mwysk/Bilder/wallpaper/linux/redlinux.jpg"
wal -i  $BG
pywalfox update #some times it helps pywalfox start
bash ~/.bash_scripts/generate-theme.sh
#bash  ~/.config/waybar/scripts/reloadWaybar.sh
hyprctl hyprpaper reload ,$BG

