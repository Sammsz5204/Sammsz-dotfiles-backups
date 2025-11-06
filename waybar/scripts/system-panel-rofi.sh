#!/bin/bash

# Coleta informações do sistema
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1
}

get_ram_usage() {
    free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}'
}

get_ram_info() {
    free -h | grep Mem | awk '{print $3 " / " $2}'
}

get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

get_disk_info() {
    df -h / | awk 'NR==2 {print $3 " / " $2}'
}

get_uptime() {
    uptime -p | sed 's/up //'
}

# Função para criar barra visual
create_bar() {
    local value=$1
    local width=15
    local filled=$((value * width / 100))
    local empty=$((width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo "$bar"
}

# Função para obter cor
get_color() {
    local value=$1
    if [ "$value" -gt 80 ]; then
        echo "#fb4934"
    elif [ "$value" -gt 60 ]; then
        echo "#fabd2f"
    else
        echo "#b8bb26"
    fi
}

# Coleta dados
CPU=$(get_cpu_usage)
RAM=$(get_ram_usage)
RAM_INFO=$(get_ram_info)
DISK=$(get_disk_usage)
DISK_INFO=$(get_disk_info)
UPTIME=$(get_uptime)

# Cria as barras
CPU_BAR=$(create_bar $CPU)
RAM_BAR=$(create_bar $RAM)
DISK_BAR=$(create_bar $DISK)

# Cores
CPU_COLOR=$(get_color $CPU)
RAM_COLOR=$(get_color $RAM)
DISK_COLOR=$(get_color $DISK)

# Monta mensagem com estatísticas
MESSAGE="<span font='JetBrainsMono Nerd Font Mono 11'>"
MESSAGE+="<b><span foreground='#fabd2f'>󰍉  SISTEMA</span></b>\n\n"

# CPU - alinhado
MESSAGE+="<span foreground='#83a598'><b>󰻠 CPU </b></span> "
MESSAGE+="<span foreground='$CPU_COLOR'><b>$(printf '%3s' $CPU)%</b></span> "
MESSAGE+="<span foreground='#504945'>$CPU_BAR</span>\n"

# RAM - alinhado
MESSAGE+="<span foreground='#d3869b'><b>󰍛 RAM </b></span> "
MESSAGE+="<span foreground='$RAM_COLOR'><b>$(printf '%3s' $RAM)%</b></span> "
MESSAGE+="<span foreground='#504945'>$RAM_BAR</span>\n"
MESSAGE+="<span foreground='#665c54' size='small'>        $RAM_INFO</span>\n\n"

# DISK - alinhado
MESSAGE+="<span foreground='#b8bb26'><b>󰋊 DISK</b></span> "
MESSAGE+="<span foreground='$DISK_COLOR'><b>$(printf '%3s' $DISK)%</b></span> "
MESSAGE+="<span foreground='#504945'>$DISK_BAR</span>\n"
MESSAGE+="<span foreground='#665c54' size='small'>        $DISK_INFO</span>\n\n"

MESSAGE+="<span foreground='#928374' size='small'>󰔚 Uptime: $UPTIME</span>"
MESSAGE+="</span>"

# Menu de opções com ícones (usando unicode direct)
# Font Awesome 7 códigos unicode
OPTIONS="󰐥  Desligar
󰜉  Reiniciar
󰍃  Sair
󰌾  Bloquear
󰒲  Suspender
󰤄  Hibernar
󰆍  Terminal
󰉋  Arquivos
󰒓  Configs
󰖩  Rede
󰍛  Monitor
󰂚  Notificações"

# Mostra rofi
CHOICE=$(echo -e "$OPTIONS" | rofi \
    -dmenu \
    -i \
    -p "󰍉 Sistema" \
    -mesg "$MESSAGE" \
    -theme ~/.config/rofi/system-panel.rasi \
    -markup-rows \
    -no-custom \
    -selected-row 0)

# Processa a escolha
case "$CHOICE" in
    *"Desligar"*)
        CONFIRM=$(echo -e "󰄬 Sim\n󰜺 Não" | rofi -dmenu -p "Confirma desligar?" -theme ~/.config/rofi/system-panel.rasi)
        [[ "$CONFIRM" == *"Sim"* ]] && systemctl poweroff
        ;;
    *"Reiniciar"*)
        CONFIRM=$(echo -e "󰄬 Sim\n󰜺 Não" | rofi -dmenu -p "Confirma reiniciar?" -theme ~/.config/rofi/system-panel.rasi)
        [[ "$CONFIRM" == *"Sim"* ]] && systemctl reboot
        ;;
    *"Sair"*)
        CONFIRM=$(echo -e "󰄬 Sim\n󰜺 Não" | rofi -dmenu -p "Confirma sair?" -theme ~/.config/rofi/system-panel.rasi)
        [[ "$CONFIRM" == *"Sim"* ]] && hyprctl dispatch exit
        ;;
    *"Bloquear"*)
        hyprlock &
        ;;
    *"Suspender"*)
        systemctl suspend
        ;;
    *"Hibernar"*)
        systemctl hibernate
        ;;
    *"Terminal"*)
        kitty &
        ;;
    *"Arquivos"*)
        dolphin &
        ;;
    *"Configs"*)
        kitty -e vim ~/.config/hypr/hyprland.conf &
        ;;
    *"Rede"*)
        nm-connection-editor &
        ;;
    *"Monitor"*)
        kitty -e btop &
        ;;
    *"Notificações"*)
        dunstctl history-pop
        ;;
esac