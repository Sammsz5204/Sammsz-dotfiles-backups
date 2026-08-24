import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PopupWindow {
    id: root

    implicitWidth: 380
    implicitHeight: 600

    color: "transparent"
    visible: false


    property real cpuPct: 0
    property real ramPct: 0
    property real diskPct: 0

    property string songTitle: "Nenhuma música"
    property string songArtist: "Desconhecido"
    property string songStatus: "Stopped"

    property string uptimeStr: "--"
    property string clockNow: Qt.formatDateTime(sysClock.date, "hh:mm")

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    // ---------- stats reais (mesmos comandos ja provados no Bar/eww antigo) ----------
    Process {
        id: cpuProc
        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseFloat(this.text.trim());
                if (!isNaN(n)) root.cpuPct = n / 100;
            }
        }
    }

    Process {
        id: ramProc
        command: ["bash", "-c", "free | grep Mem | awk '{printf \"%.0f\", $3/$2 * 100}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseFloat(this.text.trim());
                if (!isNaN(n)) root.ramPct = n / 100;
            }
        }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -h / | awk 'NR==2 {print $5}' | sed 's/%//'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseFloat(this.text.trim());
                if (!isNaN(n)) root.diskPct = n / 100;
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.uptimeStr = this.text.trim()
        }
    }

    // cpu/ram sobem rapido, disco/uptime quase nao mudam — intervalos
    // diferentes pra nao ficar chamando shell a toa
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { cpuProc.running = true; ramProc.running = true; }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { diskProc.running = true; uptimeProc.running = true; }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        border.color: Colors.surface
        border.width: 2
        radius: 19

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: Colors.surface
                radius: 18

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 15

                    StatRing {
                        icon: "󰻠"
                        value: root.cpuPct
                        label: "CPU"
                        ringColor: Colors.blue
                        Layout.fillWidth: true
                    }

                    StatRing {
                        icon: "󰍛"
                        value: root.ramPct
                        label: "RAM"
                        ringColor: Colors.green
                        Layout.fillWidth: true
                    }

                    StatRing {
                        icon: "󰋊"
                        value: root.diskPct
                        label: "DISK"
                        ringColor: Colors.yellow
                        Layout.fillWidth: true
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
            }


            Text {
                text: "AÇÕES RÁPIDAS"
                color: Colors.muted
                font.pixelSize: 11
                font.bold: true
                Layout.leftMargin: 4
            }

            GridLayout {
                columns: 4
                columnSpacing: 10
                rowSpacing: 10
                Layout.fillWidth: true

                ActionBtn {
                    icon: "󰐥"
                    label: "Desligar"
                    iconColor: Colors.brightRed
                    cmd: "systemctl poweroff"
                }

                ActionBtn {
                    icon: "󰜉"
                    label: "Reiniciar"
                    iconColor: Colors.yellow
                    cmd: "systemctl reboot"
                }

                ActionBtn {
                    icon: "󰍃"
                    label: "Sair"
                    iconColor: Colors.yellow
                    cmd: "hyprctl dispatch exit"
                }

                ActionBtn {
                    icon: "󰌾"
                    label: "Bloquear"
                    iconColor: Colors.yellow
                    cmd: "quickshell -p ~/.config/quickshell/ ipc call lock engage"
                }

                ActionBtn {
                    icon: "󰒲"
                    label: "Suspender"
                    iconColor: Colors.blue
                    cmd: "systemctl suspend"
                }

                ActionBtn {
                    icon: "󰆍"
                    label: "Terminal"
                    iconColor: Colors.green
                    cmd: "kitty &"
                }

                ActionBtn {
                    icon: "󰉋"
                    label: "Arquivos"
                    iconColor: Colors.green
                    cmd: "nautilus &"
                }

                ActionBtn {
                    icon: "󰒓"
                    label: "Configs"
                    iconColor: Colors.brightBlue
                    cmd: "kitty -e nvim ~/.config/hypr/hyprland.lua &"
                }

                ActionBtn {
                    icon: "󰖩"
                    label: "Rede"
                    iconColor: Colors.blue
                    cmd: "nm-connection-editor &"
                }

                ActionBtn {
                    icon: "󰍛"
                    label: "Monitor"
                    iconColor: Colors.brightBlue
                    cmd: "kitty -e btop --force-utf &"
                }

                ActionBtn {
                    icon: "󰂚"
                    label: "Notificações"
                    iconColor: Colors.yellow
                    cmd: "swaync-client -t &"
                }

                ActionBtn {
                    icon: "󰅖"
                    label: "Fechar"
                    iconColor: Colors.brightRed
                    cmd: "__CLOSE__"
                }

                ActionBtn {
                    icon: "󰸉"
                    label: "Wall (Aleat)"
                    iconColor: Colors.brightGreen
                    cmd: "~/.config/scripts/random_wallpaper.sh &"
                }

                ActionBtn {
                    icon: "󰄄"
                    label: "Wall (Menu)"
                    iconColor: Colors.brightBlue
                    cmd: "lua5.1 /home/sam/.config/scripts/wallchanger.lua &"
                }

                ActionBtn {
                    icon: "󰑐"
                    label: "Reload QS"
                    iconColor: Colors.muted
                    cmd: "killall quickshell && quickshell"
                }

                ActionBtn {
                    icon: "󰑐"
                    label: "Reload Hypr"
                    iconColor: Colors.muted
                    cmd: "hyprctl reload"
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                color: Colors.surface
                radius: 18

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 0

                    RowLayout {
                        spacing: 3

                        Text {
                            text: "󰔚"
                            color: Colors.yellow
                            font.pixelSize: 19
                        }

                        Text {
                            text: root.uptimeStr
                            color: Colors.muted
                            font.pixelSize: 12
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 3

                        Text {
                            text: "󰥔"
                            color: Colors.yellow
                            font.pixelSize: 19
                        }

                        Text {
                            text: root.clockNow
                            color: Colors.muted
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }

component ActionBtn: Rectangle {
        property string icon: ""
        property string label: ""
        property color iconColor: Colors.fg
        property string cmd: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 65

        // Fundo tonal liso, sem borda. Clareia no hover e escurece no press.
        color: mArea.pressed 
            ? Colors.surface
            : (mArea.containsMouse ? Qt.lighter(Colors.surface, 1.9) : Colors.surface)

        

        // Efeito Squish (esmaga no clique) e Float (cresce no hover)
        radius: mArea.pressed ? 10 : (mArea.containsMouse ? 20 : 15 )
        
        Behavior on radius {
            NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: parent.parent.icon
                color: parent.parent.iconColor
                font.pixelSize: 20
                Layout.alignment: Qt.AlignHCenter
                
                // O ícone dá um pulinho extra descolado do botão
                scale: mArea.containsMouse ? 1.15 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 3.0 }
                }
            }

            Text {
                text: parent.parent.label
                color: Colors.fg
                font.pixelSize: 10
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            id: mArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor // Mãozinha pra dar aquele feedback de clique

            onClicked: {
                if (parent.cmd === "__CLOSE__") {
                    root.visible = false
                    return
                }

                if (parent.cmd !== "") {
                    Quickshell.execDetached([
                        "bash",
                        "-c",
                        parent.cmd
                    ])

                    root.visible = false
                }
            }
        }
    }

    component MediaButton: Rectangle {
        property string iconText: ""

        // Deixei levemente maior e totalmente redondo (Circle/Pill)
        implicitWidth: 32
        implicitHeight: 32

         

        color: mouseArea.pressed
            ? Colors.surface
            : (mouseArea.containsMouse ? Colors.bg : "transparent")

        // Mesmo efeito de mola dos botões principais
        radius: mouseArea.pressed ? 12 : (mouseArea.containsMouse ? 20 : 0)

        Behavior on radius {
            NumberAnimation { duration: 250; easing.type: Easing.OutBack}
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: parent.parent.iconText
            color: mouseArea.containsMouse ? Colors.blue : Colors.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: parent.parent.clicked()
        }

        signal clicked()
    }
}
