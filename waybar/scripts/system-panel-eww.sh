#!/bin/bash

# Verifica se o daemon do EWW está rodando
if ! pgrep -x eww > /dev/null; then
    eww daemon &
    sleep 1
fi

# Toggle do painel
if eww active-windows | grep -q "system-panel"; then
    eww close system-panel
else
    eww open system-panel
fi