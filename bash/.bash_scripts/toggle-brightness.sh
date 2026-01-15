#!/bin/bash

brightness=$(brightnessctl get intel_backlight)
#brightnessctl -m | awk -F, '{print $4}' | tr -d '%' in prozent
if [[ $brightness  -lt 160 ]]; then
    brightnessctl s 100%
else
    brightnessctl s 0%
fi