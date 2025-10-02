#!/bin/bash

brightness=$(brightnessctl get intel_backlight)

if [[ $brightness  -lt 160 ]]; then
    brightnessctl s 100%
else
    brightnessctl s 1%
fi