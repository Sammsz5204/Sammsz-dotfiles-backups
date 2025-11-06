#!/bin/bash

HTML_FILE="$HOME/.config/waybar/system-panel.html"
STATS_FILE="/tmp/system-panel-stats.json"
CMD_FILE="/tmp/system-panel-cmd"
PID_FILE="/tmp/system-panel-firefox.pid"

# Função para gerar stats
generate_stats() {
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1)
    RAM=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    RAM_INFO=$(free -h | grep Mem | awk '{print $3 " / " $2}')
    DISK=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    DISK_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2}')
    UPTIME=$(uptime -p | sed 's/up //')
    TIME=$(date '+%H:%M')
    
    cat > "$STATS_FILE" << EOF
{
    "cpu": "$CPU",
    "ram": "$RAM",
    "disk": "$DISK",
    "ram_info": "$RAM_INFO",
    "disk_info": "$DISK_INFO",
    "uptime": "$UPTIME",
    "time": "$TIME"
}
EOF
}

# Verifica se já está aberto
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        # Fecha a janela
        kill $PID 2>/dev/null
        rm "$PID_FILE"
        exit 0
    fi
fi

# Gera stats inicial
generate_stats

# Abre Firefox em modo kiosk (sem barras)
firefox --new-window \
        --kiosk \
        "file://$HTML_FILE" &

FIREFOX_PID=$!
echo $FIREFOX_PID > "$PID_FILE"

# Loop para atualizar stats e processar comandos
(
    while ps -p $FIREFOX_PID > /dev/null 2>&1; do
        # Atualiza stats
        generate_stats
        
        # Processa comandos pendentes
        if [ -f "$CMD_FILE" ]; then
            CMD=$(cat "$CMD_FILE")
            rm "$CMD_FILE"
            
            if [ "$CMD" = "CLOSE_PANEL" ]; then
                kill $FIREFOX_PID 2>/dev/null
                break
            else
                eval "$CMD" &
            fi
        fi
        
        sleep 2
    done
    
    rm -f "$PID_FILE" "$STATS_FILE" "$CMD_FILE"
) &

# Aguarda e ajusta janela no Hyprland
sleep 1
WINDOW_ADDRESS=$(hyprctl clients -j | jq -r '.[] | select(.title | contains("system-panel.html")) | .address')

if [ -n "$WINDOW_ADDRESS" ]; then
    hyprctl dispatch focuswindow address:$WINDOW_ADDRESS
    hyprctl dispatch togglefloating address:$WINDOW_ADDRESS
    hyprctl dispatch resizeactive exact 400 620 address:$WINDOW_ADDRESS
    hyprctl dispatch movewindow exact 1505 40 address:$WINDOW_ADDRESS
fi
