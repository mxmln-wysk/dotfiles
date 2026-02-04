#!/bin/bash
BG="/home/mwysk/.dotfiles/redlinux.jpg"
wal -i  $BG #-f random_dark
pywalfox update #some times it helps pywalfox start
bash ~/.bash_scripts/generate-theme.sh
#bash  ~/.config/waybar/scripts/reloadWaybar.sh
hyprctl hyprpaper reload ,$BG

