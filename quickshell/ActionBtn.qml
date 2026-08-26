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

    // So liga os Behaviors abaixo DEPOIS que o layout inicial ja'
    // assentou uma vez. Sem isso, a primeira abertura do painel tambem
    // "anima" (cada tile parece crescer/deslizar do zero na hora de
    // montar) — nao e' isso que a gente quer, so' o resize de verdade
    // deve animar. Qt.callLater empurra a troca pro proximo ciclo do
    // event loop, depois que o primeiro layout sincrono ja rodou.
    property bool animReady: false
    Component.onCompleted: Qt.callLater(() => root.animReady = true)

    // O span (Layout.columnSpan/rowSpan) e' um numero inteiro — nao da
    // pra "animar" 1->2 suavemente, o Qt so' sabe pular. O que da pra
    // animar e' o width/height/x/y de VERDADE que o GridLayout calcula
    // pra esse item a cada mudanca de span — e' nisso que o Behavior
    // pega, fazendo o tile "esticar" com uma mola em vez de saltar na
    // hora. x/y entraram porque crescer o span pode empurrar o proprio
    // tile pra outra linha/coluna (o "teleporte" reportado: sem
    // Behavior nisso, a posicao pulava instantanea e so' DEPOIS o
    // tamanho animava, descolado). Ainda so' nesse tile, nao nos
    // vizinhos — nao mexi em nada do arrastar, que ja ficou perfeito.
    Behavior on width {
        enabled: root.animReady
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }
    Behavior on height {
        enabled: root.animReady
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }
    Behavior on x {
        enabled: root.animReady
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }
    Behavior on y {
        enabled: root.animReady
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

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

    // Redimensionar: alca no canto inferior-direito (igual o Android),
    // desenhada como uma quina grossa. Arrastar acumula distancia e
    // "engata" um degrau de tamanho a cada ~40px — cresce/encolhe SEM
    // voltar pro inicio ao passar do limite (testado em Python).
    Item {
        id: resizeHandle
        visible: SystemPanelState.editMode
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: -4
        width: 22
        height: 22
        z: 10

        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = Colors.brightGreen;
                ctx.lineWidth = 3;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(width * 0.4, height * 0.9);
                ctx.lineTo(width * 0.9, height * 0.9);
                ctx.lineTo(width * 0.9, height * 0.4);
                ctx.stroke();
            }
        }

        MouseArea {
            id: resizeArea
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.SizeFDiagCursor
            preventStealing: true

            property real accumDx: 0
            property real accumDy: 0
            // Coordenada GLOBAL (tela), nao local — a local se move junto
            // com a propria alca quando o tile cresce/encolhe no meio do
            // gesto, o que corrompia a distancia acumulada (o cursor
            // "descolava" do painel). Global e' um referencial fixo,
            // imune a isso, mesmo padrao ja usado no drag-and-drop.
            property real lastGlobalX: 0
            property real lastGlobalY: 0
            readonly property real stepPx: 40

            onPressed: mouse => {
                accumDx = 0;
                accumDy = 0;
                const g = mapToGlobal(mouse.x, mouse.y);
                lastGlobalX = g.x;
                lastGlobalY = g.y;
            }

            onPositionChanged: mouse => {
                const g = mapToGlobal(mouse.x, mouse.y);
                accumDx += (g.x - lastGlobalX);
                accumDy += (g.y - lastGlobalY);
                lastGlobalX = g.x;
                lastGlobalY = g.y;

                if (accumDx > stepPx || accumDy > stepPx) {
                    SystemPanelState.growSize(root.moduleId);
                    accumDx = 0;
                    accumDy = 0;
                } else if (accumDx < -stepPx || accumDy < -stepPx) {
                    SystemPanelState.shrinkSize(root.moduleId);
                    accumDx = 0;
                    accumDy = 0;
                }
            }
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
