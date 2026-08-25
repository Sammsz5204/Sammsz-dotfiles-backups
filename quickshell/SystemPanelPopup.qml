import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ============================================================
// SystemPanelPopup.qml
//
// Arquitetura (item 15 do pedido): 3 camadas separadas.
//   DADOS  -> SystemPanelModules.qml  (o que existe: icone/cmd/cor)
//   ESTADO -> SystemPanelState.qml    (o que ta ativo, ordem, colunas,
//                                       persistido em disco)
//   UI     -> este arquivo            (so' renderiza o que o Estado
//                                       manda, olhando os Dados)
//
// A grade de acoes (que antes eram 16 ActionBtn{} copiados/colados)
// agora e' um Repeater sobre SystemPanelState.visibleModules — os
// COMANDOS continuam sendo os mesmos 16 de sempre, so' viraram dados
// em vez de blocos QML fixos (item 2/12/16).
//
// Tudo que NAO e' o grid de acoes (stats de CPU/RAM/disco, player,
// relogio, uptime) continua exatamente como estava — item 13.
// ============================================================

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

    // ---------------- drag-and-drop pra reordenar ----------------
    // O tile de verdade fica com opacity 0 (via "ghosted") enquanto o
    // "fantasma" abaixo segue o mouse. A reordenacao acontece AO VIVO
    // conforme o fantasma passa por cima de outro tile — GridLayout
    // reflui tudo sozinho (motor de layout de verdade do Qt, nao
    // posicionamento manual), o resto dos tiles "andam" pra abrir
    // espaco automaticamente.
    property string draggingId: ""
    property var draggingModule: draggingId !== "" ? SystemPanelModules.byId(draggingId) : null

    function beginDrag(moduleId, gx, gy) {
        root.draggingId = moduleId;
        updateGhostPosition(gx, gy);
    }

    function updateDrag(gx, gy) {
        if (root.draggingId === "") return;
        updateGhostPosition(gx, gy);

        for (let i = 0; i < actionsRepeater.count; i++) {
            const item = actionsRepeater.itemAt(i);
            if (!item) continue;
            const topLeft = item.mapToGlobal(0, 0);
            const inside = gx >= topLeft.x && gx <= topLeft.x + item.width
                         && gy >= topLeft.y && gy <= topLeft.y + item.height;
            if (inside) {
                if (item.moduleId !== root.draggingId) {
                    SystemPanelState.reorderTo(root.draggingId, i);
                }
                break;
            }
        }
    }

    function endDrag() {
        root.draggingId = "";
    }

    function updateGhostPosition(gx, gy) {
        const local = ghostLayer.mapFromGlobal(gx, gy);
        ghost.x = local.x - ghost.width / 2;
        ghost.y = local.y - ghost.height / 2;
    }

    property bool confirmingReset: false

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

    Timer {
        id: resetConfirmTimeout
        interval: 3000
        onTriggered: root.confirmingReset = false
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        border.color: SystemPanelState.editMode ? Colors.brightBlue : Colors.surface
        border.width: 2
        radius: 19

        Behavior on border.color { ColorAnimation { duration: 200 } }

        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 15
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: scrollView.availableWidth
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                color: Colors.surface
                radius: 18

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 26

                    Rectangle {
                        width: 38
                        height: 38
                        radius: 14
                        color: Colors.bg

                        Text {
                            anchors.centerIn: parent
                            text: "󰝚"
                            color: Colors.blue
                            font.pixelSize: 18
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: root.songTitle
                            color: Colors.fg
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.songArtist
                            color: Colors.muted
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        spacing: 12

                        MediaButton {
                            iconText: "󰒮"
                            onClicked: Quickshell.execDetached(["playerctl", "previous"])
                        }

                        MediaButton {
                            iconText: root.songStatus === "Playing" ? "󰏤" : "󰐊"
                            onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                        }

                        MediaButton {
                            iconText: "󰒭"
                            onClicked: Quickshell.execDetached(["playerctl", "next"])
                        }
                    }
                }
            }

            // ---------------- cabecalho: titulo + botao de editar ----------------
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4

                Text {
                    text: SystemPanelState.editMode ? "PERSONALIZAR" : "AÇÕES RÁPIDAS"
                    color: SystemPanelState.editMode ? Colors.brightBlue : Colors.muted
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 24
                    radius: 8
                    color: editToggleArea.containsMouse ? Colors.surface : "transparent"

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: SystemPanelState.editMode ? "󰄲" : "󰏫"
                        color: SystemPanelState.editMode ? Colors.green : Colors.muted
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: editToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SystemPanelState.toggleEditMode();
                            root.confirmingReset = false;
                        }
                    }
                }
            }

            // ---------------- grid de acoes (dirigido por dados) ----------------
            GridLayout {
                id: actionsGrid
                columns: SystemPanelState.gridColumns
                columnSpacing: 10
                rowSpacing: 10
                Layout.fillWidth: true

                Repeater {
                    id: actionsRepeater
                    model: SystemPanelState.visibleModules

                    delegate: ActionBtn {
                        required property var modelData

                        moduleId: modelData.id
                        icon: modelData.icon
                        label: modelData.label
                        iconColor: modelData.iconColor
                        cmd: modelData.cmd
                        ghosted: root.draggingId === modelData.id

                        onCloseRequested: root.visible = false
                        onDragStarted: (mid, gx, gy) => root.beginDrag(mid, gx, gy)
                        onDragMoved: (gx, gy) => root.updateDrag(gx, gy)
                        onDragEnded: root.endDrag()
                    }
                }
            }

            // ---------------- modulos disponiveis (so' no modo de edicao) ----------------
            ColumnLayout {
                visible: SystemPanelState.editMode && SystemPanelState.availableToAdd.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6

                Text {
                    text: "MÓDULOS DISPONÍVEIS"
                    color: Colors.muted
                    font.pixelSize: 10
                    font.bold: true
                    Layout.leftMargin: 4
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: SystemPanelState.availableToAdd

                        delegate: Rectangle {
                            id: chip
                            required property var modelData

                            implicitWidth: chipRow.implicitWidth + 22
                            implicitHeight: 30
                            radius: 15
                            color: chipArea.containsMouse ? Colors.bg : Colors.surface
                            border.color: Colors.muted
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "+"
                                    color: Colors.green
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: chip.modelData.icon + "  " + chip.modelData.label
                                    color: Colors.fg
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemPanelState.show(chip.modelData.id)
                            }
                        }
                    }
                }
            }

            // ---------------- colunas do grid + restaurar padrao ----------------
            ColumnLayout {
                visible: SystemPanelState.editMode
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Colunas do grid"
                        color: Colors.muted
                        font.pixelSize: 11
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: colMinusArea.containsMouse ? Colors.bg : Colors.surface
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "－"; color: Colors.fg; font.pixelSize: 12; font.bold: true }

                        MouseArea {
                            id: colMinusArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (SystemPanelState.gridColumns > 2) SystemPanelState.gridColumns -= 1
                        }
                    }

                    Text {
                        text: SystemPanelState.gridColumns
                        color: Colors.fg
                        font.pixelSize: 12
                        font.bold: true
                        Layout.preferredWidth: 16
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: colPlusArea.containsMouse ? Colors.bg : Colors.surface
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "＋"; color: Colors.fg; font.pixelSize: 12; font.bold: true }

                        MouseArea {
                            id: colPlusArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (SystemPanelState.gridColumns < 6) SystemPanelState.gridColumns += 1
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 12
                    color: root.confirmingReset ? Colors.brightRed : Colors.surface

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.confirmingReset ? "Confirmar? isso apaga sua personalização" : "Restaurar padrão"
                        color: root.confirmingReset ? Colors.bg : Colors.fg
                        font.pixelSize: 11
                        font.bold: root.confirmingReset
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.confirmingReset) {
                                SystemPanelState.resetToDefaults();
                                root.confirmingReset = false;
                                resetConfirmTimeout.stop();
                            } else {
                                root.confirmingReset = true;
                                resetConfirmTimeout.restart();
                            }
                        }
                    }
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

        // ---------------- fantasma do drag-and-drop ----------------
        // Cobre o popup inteiro, mas nao tem MouseArea nenhuma — entao
        // nunca captura clique, so' serve de "tela" pra desenhar o
        // tile flutuante em cima de tudo (z maior que o ScrollView por
        // estar declarado depois dele).
        Item {
            id: ghostLayer
            anchors.fill: parent
            visible: root.draggingId !== ""

            Rectangle {
                id: ghost
                width: 65
                height: 65
                radius: 20
                color: Colors.surface
                opacity: 0.92
                scale: 1.08
                border.width: 2
                border.color: Colors.brightBlue

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: root.draggingModule ? root.draggingModule.icon : ""
                        color: root.draggingModule ? root.draggingModule.iconColor : Colors.fg
                        font.pixelSize: 20
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: root.draggingModule ? root.draggingModule.label : ""
                        color: Colors.fg
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
