import QtQuick

// ============================================================
// MediaButton.qml — extraido do SystemPanelPopup.qml, sem nenhuma
// mudanca de comportamento (nao faz parte do sistema de modulos —
// o item 13 do pedido diz explicitamente pra nao mexer nisso).
// ============================================================
Rectangle {
    id: root
    property string iconText: ""

    signal clicked()

    // Levemente maior e totalmente redondo (Circle/Pill)
    implicitWidth: 32
    implicitHeight: 32

    color: mouseArea.pressed
        ? Colors.surface
        : (mouseArea.containsMouse ? Colors.bg : "transparent")

    // Mesmo efeito de mola dos botoes principais
    radius: mouseArea.pressed ? 12 : (mouseArea.containsMouse ? 20 : 0)

    Behavior on radius {
        NumberAnimation { duration: 250; easing.type: Easing.OutBack }
    }

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Text {
        anchors.centerIn: parent
        text: root.iconText
        color: mouseArea.containsMouse ? Colors.blue : Colors.fg
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()
    }
}
