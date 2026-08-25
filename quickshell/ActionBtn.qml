import QtQuick
import QtQuick.Layouts
import Quickshell

// ============================================================
// ActionBtn.qml — extraido do SystemPanelPopup.qml (estava inline,
// duplicado goal de 16 vezes). Comportamento visual identico ao
// original (hover/press/squish/OutBack) — so' adicionei a camada de
// modo de edicao (badge ✕ pra esconder, setas pra reordenar), que fica
// invisivel e sem efeito nenhum quando SystemPanelState.editMode e'
// false. Uso normal continua identico a antes.
// ============================================================
Rectangle {
    id: root

    property string moduleId: ""
    property string icon: ""
    property string label: ""
    property color iconColor: Colors.fg
    property string cmd: ""

    // Quando o proprio drag deste tile esta em andamento, a Popup pede
    // pra esconder o tile "de verdade" (o "fantasma" que segue o mouse
    // e' quem fica visivel nesse momento) — ver SystemPanelPopup.qml.
    property bool ghosted: false

    signal closeRequested()
    signal dragStarted(string moduleId, real globalX, real globalY)
    signal dragMoved(real globalX, real globalY)
    signal dragEnded()

    Layout.fillWidth: true
    Layout.preferredHeight: 65
    Layout.columnSpan: SystemPanelState.spanFor(moduleId).cols
    Layout.rowSpan: SystemPanelState.spanFor(moduleId).rows

    opacity: ghosted ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 100 } }

    // Fundo tonal liso, sem borda. Clareia no hover e escurece no press.
    color: mArea.pressed
        ? Colors.surface
        : (mArea.containsMouse ? Qt.lighter(Colors.surface, 1.9) : Colors.surface)

    border.width: SystemPanelState.editMode ? 2 : 0
    border.color: Colors.brightBlue
    Behavior on border.width { NumberAnimation { duration: 150 } }

    // Efeito Squish (esmaga no clique) e Float (cresce no hover)
    radius: mArea.pressed ? 10 : (mArea.containsMouse ? 20 : 15)

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
            text: root.icon
            color: root.iconColor
            font.pixelSize: 20
            Layout.alignment: Qt.AlignHCenter

            // O icone da um pulinho extra descolado do botao
            scale: mArea.containsMouse ? 1.15 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 3.0 }
            }
        }

        Text {
            text: root.label
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
        cursorShape: Qt.PointingHandCursor
        // No modo de edicao o clique principal nao executa nada — so'
        // os controles de edicao (✕ / setas / arrastar) respondem.
        enabled: !SystemPanelState.editMode

        onClicked: {
            if (root.cmd === "__CLOSE__") {
                root.closeRequested();
                return;
            }

            if (root.cmd !== "") {
                Quickshell.execDetached(["bash", "-c", root.cmd]);
                root.closeRequested();
            }
        }
    }

    // ---------------- arrastar pra reordenar (so' no modo de edicao) --
    // Fica ATRAS dos controles de canto (z menor), entao ✕/setas/resize
    // continuam recebendo o clique deles normalmente — essa area so'
    // pega o resto do tile. Emite sinais com coordenada GLOBAL pra quem
    // ta escutando (a Popup) poder comparar posicao entre tiles
    // diferentes sem precisar saber a hierarquia de quem emitiu.
    MouseArea {
        id: dragArea
        anchors.fill: parent
        visible: SystemPanelState.editMode
        enabled: SystemPanelState.editMode
        cursorShape: Qt.SizeAllCursor
        preventStealing: true

        onPressed: mouse => {
            const g = mapToGlobal(mouse.x, mouse.y);
            root.dragStarted(root.moduleId, g.x, g.y);
        }
        onPositionChanged: mouse => {
            const g = mapToGlobal(mouse.x, mouse.y);
            root.dragMoved(g.x, g.y);
        }
        onReleased: root.dragEnded()
        onCanceled: root.dragEnded()
    }

    // ---------------- controles do modo de edicao ----------------
    Rectangle {
        visible: SystemPanelState.editMode
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -6
        width: 20
        height: 20
        radius: 10
        color: Colors.brightRed
        z: 10

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: Colors.bg
            font.pixelSize: 10
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: SystemPanelState.hide(root.moduleId)
        }
    }

    // Redimensionar: cicla 1x1 -> 2x1 -> 2x2 -> 1x1. Canto oposto ao ✕
    // de proposito, pra nao disputar espaco/clique com ele.
    Rectangle {
        visible: SystemPanelState.editMode
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: -6
        width: 20
        height: 20
        radius: 10
        color: Colors.brightGreen
        z: 10

        Text {
            anchors.centerIn: parent
            text: "⤡"
            color: Colors.bg
            font.pixelSize: 11
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: SystemPanelState.cycleSize(root.moduleId)
        }
    }

    RowLayout {
        visible: SystemPanelState.editMode
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: -8
        spacing: 4
        z: 10

        Rectangle {
            width: 20
            height: 20
            radius: 10
            color: Colors.surface
            border.color: Colors.muted
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "‹"
                color: Colors.fg
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: SystemPanelState.moveLeft(root.moduleId)
            }
        }

        Rectangle {
            width: 20
            height: 20
            radius: 10
            color: Colors.surface
            border.color: Colors.muted
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "›"
                color: Colors.fg
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: SystemPanelState.moveRight(root.moduleId)
            }
        }
    }
}
