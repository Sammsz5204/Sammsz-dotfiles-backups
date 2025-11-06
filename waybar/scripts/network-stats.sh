#!/bin/bash

# Informações de rede
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
IP_LOCAL=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
IP_PUBLIC=$(curl -s ifconfig.me || echo "N/A")
GATEWAY=$(ip route | grep default | awk '{print $3}')

# WiFi info (se aplicável)
if command -v iwgetid &> /dev/null; then
    SSID=$(iwgetid -r)
    SIGNAL=$(grep $INTERFACE /proc/net/wireless | awk '{print int($3 * 100 / 70)}')
else
    SSID="N/A"
    SIGNAL="N/A"
fi

MESSAGE="<span font='JetBrainsMono Nerd Font 11'>"
MESSAGE+="<b><span foreground='#fabd2f'>󰈀 Rede</span></b>\n\n"
MESSAGE+="<span foreground='#83a598'>Interface:</span> $INTERFACE\n"
MESSAGE+="<span foreground='#d3869b'>IP Local:</span> $IP_LOCAL\n"
MESSAGE+="<span foreground='#b8bb26'>IP Público:</span> $IP_PUBLIC\n"
MESSAGE+="<span foreground='#fe8019'>Gateway:</span> $GATEWAY\n\n"

if [ "$SSID" != "N/A" ]; then
    MESSAGE+="<span foreground='#83a598'>SSID:</span> $SSID\n"
    MESSAGE+="<span foreground='#d3869b'>Sinal:</span> ${SIGNAL}%"
fi
MESSAGE+="</span>"

echo -e " OK" | rofi \
    -dmenu \
    -p "Informações de Rede" \
    -mesg "$MESSAGE" \
    -theme ~/.config/rofi/system-panel.rasi \
    -markup-rows