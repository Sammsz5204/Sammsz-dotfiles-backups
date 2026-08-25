pragma Singleton
import QtQuick

// ============================================================
// SystemPanelModules.qml — registro central dos modulos do painel.
//
// Essa e' a camada de DADOS (item 12/15 do pedido): so' descreve O QUE
// existe (icone, label, cor, comando). NUNCA guarda estado (visivel,
// ordem) — isso mora em SystemPanelState.qml. Os 16 comandos abaixo
// sao EXATAMENTE os que ja estavam no SystemPanelPopup.qml antes dessa
// mudanca — nenhum foi reescrito, nenhum foi inventado (item 2/16).
// ============================================================
QtObject {
    id: root

    readonly property var all: [
        { id: "poweroff",      label: "Desligar",     icon: "󰐥", iconColor: Colors.brightRed,   cmd: "systemctl poweroff" },
        { id: "reboot",        label: "Reiniciar",    icon: "󰜉", iconColor: Colors.yellow,      cmd: "systemctl reboot" },
        { id: "logout",        label: "Sair",         icon: "󰍃", iconColor: Colors.yellow,      cmd: "hyprctl dispatch exit" },
        { id: "lock",          label: "Bloquear",     icon: "󰌾", iconColor: Colors.yellow,      cmd: "quickshell -p ~/.config/quickshell/ ipc call lock engage" },
        { id: "suspend",       label: "Suspender",    icon: "󰒲", iconColor: Colors.blue,        cmd: "systemctl suspend" },
        { id: "terminal",      label: "Terminal",     icon: "󰆍", iconColor: Colors.green,       cmd: "kitty &" },
        { id: "files",         label: "Arquivos",     icon: "󰉋", iconColor: Colors.green,       cmd: "nautilus &" },
        { id: "settings",      label: "Configs",      icon: "󰒓", iconColor: Colors.brightBlue,  cmd: "kitty -e nvim ~/.config/hypr/hyprland.lua &" },
        { id: "network",       label: "Rede",         icon: "󰖩", iconColor: Colors.blue,        cmd: "nm-connection-editor &" },
        { id: "monitor",       label: "Monitor",      icon: "󰍛", iconColor: Colors.brightBlue,  cmd: "kitty -e btop --force-utf &" },
        { id: "notifications", label: "Notificações", icon: "󰂚", iconColor: Colors.yellow,      cmd: "swaync-client -t &" },
        { id: "close",         label: "Fechar",       icon: "󰅖", iconColor: Colors.brightRed,   cmd: "__CLOSE__" },
        { id: "wall_random",   label: "Wall (Aleat)", icon: "󰸉", iconColor: Colors.brightGreen, cmd: "~/.config/scripts/random_wallpaper.sh &" },
        { id: "wall_menu",     label: "Wall (Menu)",  icon: "󰄄", iconColor: Colors.brightBlue,  cmd: "lua5.1 /home/sam/.config/scripts/wallchanger.lua &" },
        { id: "reload_qs",     label: "Reload QS",    icon: "󰑐", iconColor: Colors.muted,       cmd: "killall quickshell && quickshell" },
        { id: "reload_hypr",   label: "Reload Hypr",  icon: "󰑐", iconColor: Colors.muted,       cmd: "hyprctl reload" },
    ]

    readonly property var defaultOrder: all.map(m => m.id)

    function byId(id) {
        for (let i = 0; i < root.all.length; i++) {
            if (root.all[i].id === id) return root.all[i];
        }
        return null;
    }
}
