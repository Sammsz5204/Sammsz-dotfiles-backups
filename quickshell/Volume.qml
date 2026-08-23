// ============================================================
// Volume.qml — equivalente ao modulo "wireplumber" do waybar.
// Le "wpctl get-volume", mostra icone por faixa + %, clique alterna
// mute, scroll sobe/desce 2% (igual "scroll-step": 2 do waybar).
// ============================================================
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int percent: 0
    property bool muted: false

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 26

    function iconFor(pct, isMuted) {
        if (isMuted) return "󰖁";
        if (pct < 20) return "󰕿";
        if (pct < 50) return "󰖀";
        return "󰕾";
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mouseArea.containsMouse ? Colors.surface : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.iconFor(root.percent, root.muted) + " " + root.percent + "%"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: mouseArea.containsMouse ? Colors.fg : Colors.muted
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                toggleMute.running = true;
            } else if (mouse.button === Qt.MiddleButton) {
                Quickshell.execDetached(["pavucontrol"]);
            } else if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["easyeffects"]);
            }
        }
        onWheel: wheel => {
            volumeStep.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                (wheel.angleDelta.y > 0 ? "2%+" : "2%-")];
            volumeStep.running = true;
        }
    }

    Process {
        id: pollProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // saida tipica: "Volume: 0.45" ou "Volume: 0.45 [MUTED]"
                const text = this.text.trim();
                root.muted = text.includes("[MUTED]");
                const match = text.match(/[\d.]+/);
                root.percent = match ? Math.round(parseFloat(match[0]) * 100) : 0;
            }
        }
    }

    Process {
        id: toggleMute
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        running: false
        onExited: pollProc.running = true
    }

    Process {
        id: volumeStep
        running: false
        onExited: pollProc.running = true
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pollProc.running = true
    }
}
