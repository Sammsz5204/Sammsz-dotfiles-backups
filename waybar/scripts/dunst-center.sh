#!/bin/bash

# Verifica se dunst está rodando
if ! pgrep -x dunst > /dev/null; then
    notify-send "Dunst" "Serviço de notificações não está rodando"
    exit 1
fi

# Pega notificações do histórico
NOTIF_COUNT=$(dunstctl count history)
NOTIF_WAITING=$(dunstctl count waiting)

# Monta mensagem
MESSAGE="<span font='JetBrainsMono Nerd Font 11'>"
MESSAGE+="<b><span foreground='#fabd2f'>󰂚 Notificações</span></b>\n\n"
MESSAGE+="<span foreground='#83a598'>Aguardando:</span> <b>$NOTIF_WAITING</b>\n"
MESSAGE+="<span foreground='#d3869b'>Histórico:</span> <b>$NOTIF_COUNT</b>"
MESSAGE+="</span>"

# Opções
OPTIONS="󰂛 Pausar notificações
󰂚 Retomar notificações
󰎟 Limpar histórico
󰁪 Fechar última notificação
 Ver histórico completo"

# Mostra rofi
CHOICE=$(echo -e "$OPTIONS" | rofi \
    -dmenu \
    -i \
    -p "Notificações" \
    -mesg "$MESSAGE" \
    -theme ~/.config/rofi/system-panel.rasi \
    -markup-rows \
    -no-custom)

# Processa escolha
case "$CHOICE" in
    *"Pausar"*)
        dunstctl set-paused true
        notify-send "Notificações pausadas"
        ;;
    *"Retomar"*)
        dunstctl set-paused false
        notify-send "As notificações foram retomadas:)"
        ;;
    *"Limpar"*)
        dunstctl history-clear
        notify-send "Histórico limpo"
        ;;
    *"Fechar"*)
        dunstctl close
        ;;
    *"Ver histórico"*)
        dunstctl history
        ;;
esac