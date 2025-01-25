wal -i $1
pywalfox update
bash /home/mwysk/bash_scripts/pywal/generate-theme.sh
pkill hyprpaper
hyprpaper &
