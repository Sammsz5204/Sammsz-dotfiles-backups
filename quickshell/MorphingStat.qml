// ============================================================
// MorphingStat.qml — Status de sistema com morphing M3 Expressive
// ============================================================
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string icon: ""
    property string hoverName: "" 
    property var command: []
    property int intervalMs: 2000
    property string suffix: ""
    
    signal clicked()

    property string statValue: "..."
    property int pressToken: 0
    
    readonly property bool isExpanded: mouseArea.containsMouse
    readonly property bool isPressed: mouseArea.pressed

    // Calcula a largura dinamicamente com base nos textos exibidos
    implicitWidth: contentWrapper.width + 24
    implicitHeight: 26

    Behavior on implicitWidth {
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
    }

    Rectangle {
        anchors.fill: parent
        radius: isPressed ? 17 : (isExpanded ? 11 : 16)
        color: isExpanded || isPressed ? Colors.surface : "transparent"

        Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    Item {
        id: contentWrapper
        anchors.centerIn: parent
        height: 26
        
        width: iconText.implicitWidth + (isExpanded ? (nameText.implicitWidth + 6) : 0) + (statText.implicitWidth + 6)
        clip: true

        Behavior on width {
            NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }

        Text {
            id: iconText
            text: root.icon
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: isExpanded ? Colors.fg : Colors.muted
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            id: nameText
            text: root.hoverName
            x: iconText.width + 6
            anchors.verticalCenter: parent.verticalCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Colors.fg
            
            visible: opacity > 0
            opacity: root.isExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        }

        Text {
            id: statText
            text: root.statValue + root.suffix
            // O deslize mágico acontece aqui:
            x: iconText.width + 6 + (root.isExpanded ? nameText.width + 6 : 0)
            anchors.verticalCenter: parent.verticalCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: isExpanded ? Colors.fg : Colors.muted
            
            Behavior on x {
                NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
            }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    
    }

    SequentialAnimation {
        id: squishAnimation
        NumberAnimation { target: root; property: "scale"; to: 0.95; duration: 100; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; to: 1.03; duration: 100; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
        NumberAnimation { target: root; property: "scale"; to: 1; duration: 170; easing.type: Easing.OutCubic }
    }

    onPressTokenChanged: squishAnimation.restart()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.pressToken++
            root.clicked()
        }
    }

    // Leitura do bash script[cite: 9]
    Process {
        id: proc
        command: root.command
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.statValue = this.text.trim(); //[cite: 9]
            }
        }
    }

    Timer {
        interval: root.intervalMs
        running: root.command.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
