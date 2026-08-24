// ============================================================
// LockSurface.qml
// (relogio grande de 2 tons, data, campo de senha
// em pilula, mensagem de estado)
// ============================================================
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import M3Shapes

Rectangle {
    id: root
    
    required property LockContext context
    signal closed()

    // Foco garantido mesmo se o mouse nao passar por cima primeiro
    focus: true
    Component.onCompleted: {
        forceActiveFocus();
        enterAnim.start();
    }

    // Recaptura o foco caso alguma outra janela roube (bug comum
    // de foco em compositores wlroots com telas de lock)
    HoverHandler {
        onHoveredChanged: if (hovered) root.forceActiveFocus()
    }

    Keys.onPressed: event => {
        if (context.unlockInProgress)
            return;

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            context.tryUnlock();
        } else if (event.key === Qt.Key_Backspace) {
            context.currentText = event.modifiers & Qt.ControlModifier
                ? ""
                : context.currentText.slice(0, -1);
        } else if (event.text && /^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            context.currentText += event.text;
        }
    }

    // Leve "shake" quando a senha erra — feedback sem precisar de texto
    SequentialAnimation {
        id: shake
        loops: 1
        NumberAnimation { target: centerColumn; property: "x"; to: centerColumn.baseX - 10; duration: 60 }
        NumberAnimation { target: centerColumn; property: "x"; to: centerColumn.baseX + 10; duration: 60 }
        NumberAnimation { target: centerColumn; property: "x"; to: centerColumn.baseX - 6; duration: 60 }
        NumberAnimation { target: centerColumn; property: "x"; to: centerColumn.baseX; duration: 60 }
    }

    // Entrada: conteudo nasce um pouco menor/transparente e "assenta".
    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: centerColumn; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: centerColumn; property: "scale"; from: 0.92; to: 1; duration: 280; easing.type: Easing.OutCubic }
    }

    // Saida: toca DEPOIS que a senha ja foi validada com sucesso
    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation { target: centerColumn; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InCubic }
            NumberAnimation { target: centerColumn; property: "scale"; to: 0.92; duration: 500; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.closed() }
    }

    Connections {
        target: root.context
        function onFailed() { shake.start() }
        function onUnlocked() { exitAnim.start() }
    }

    // ---------------- dot de senha (usado pelo dotsRow mais abaixo) ----
    Component {
        id: passwordDotComponent

        Item {
            id: dotItem
            implicitWidth: 20
            implicitHeight: 20

            MaterialShape {
                id: dotShape
                anchors.centerIn: parent
                width: 17
                height: 17
                scale: 0
                opacity: 0
                color: Colors.fg
                
                animationDuration: 240
                animationEasing.type: Easing.InOutCubic
            }

            ListView.onAdd: {
                const randomShapes = [
                    MaterialShape.Triangle,
                    MaterialShape.Square,
                    MaterialShape.Pentagon,
                    MaterialShape.Sunny,
                    MaterialShape.Diamond,
                    MaterialShape.Ghostish
                ];
                dotShape.shape = randomShapes[Math.floor(Math.random() * randomShapes.length)];
                popInAnim.start();
            }

            ListView.onRemove: {
                dotItem.ListView.delayRemove = true;
                
                const randomShapes = [
                    MaterialShape.Burst,
                    MaterialShape.Ghostish,
                    MaterialShape.Slanted
                ];
                dotShape.shape = randomShapes[Math.floor(Math.random() * randomShapes.length)];
                removeAnim.start();
            }

            SequentialAnimation {
                id: popInAnim
                ParallelAnimation {
                    NumberAnimation { target: dotShape; property: "scale"; from: 0; to: 1.5; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                    NumberAnimation { target: dotShape; property: "opacity"; from: 0; to: 1; duration: 120 }
                }
                PauseAnimation { duration: 80 }
                
                ScriptAction { script: dotShape.shape = MaterialShape.Circle }
                
                ParallelAnimation {
                    NumberAnimation { target: dotShape; property: "scale"; to: 1; duration: 240; easing.type: Easing.OutCubic }
                }
            }

            SequentialAnimation {
                id: removeAnim
                ParallelAnimation {
                    NumberAnimation { target: dotShape; property: "scale"; to: 1.4; duration: 120; easing.type: Easing.OutCubic }
                }
                ParallelAnimation {
                    NumberAnimation { target: dotShape; property: "opacity"; to: 0; duration: 150 }
                    NumberAnimation { target: dotShape; property: "scale"; to: 0; duration: 150; easing.type: Easing.InCubic }
                }
                PropertyAction { target: dotItem; property: "ListView.delayRemove"; value: false }
            }
        }
    }

    Image {
        id: bgReal
        anchors.fill: parent
        source: root.context.bgSource
        visible: false 
        fillMode: Image.PreserveAspectCrop
    }

    MultiEffect {
        anchors.fill: bgReal
        source: bgReal
        blurEnabled: true
        blur: 1.0       
        blurMax: 48     
    }

    ColumnLayout {
        id: centerColumn
        property real baseX: (root.width - width) / 2

        x: baseX
        y: (root.height - height) / 2
        width: 360
        spacing: 28
        opacity: 0
        scale: 0.92
        transformOrigin: Item.Center

        // ---------------- relogio ----------------
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Text {
                    text: Qt.formatDateTime(clock.date, "hh")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 96
                    font.weight: Font.DemiBold
                    color: Colors.accent
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "mm")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 96
                    font.weight: Font.Light
                    color: Colors.fg
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toUpperCase()
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.letterSpacing: 1.5
                color: Colors.muted
            }
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Item {
                id: morphingIcon
                Layout.alignment: Qt.AlignHCenter
                width: 30
                height: 30
                
                SequentialAnimation {
                    id: bumpAnim
                    NumberAnimation { target: blob; property: "scale"; to: 1.14; duration: 150; easing.type: Easing.OutCubic }
                    NumberAnimation { target: blob; property: "scale"; to: 1; duration: 150; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
                } 

                SequentialAnimation {
                    id: burstAnim
                    NumberAnimation { target: blob; property: "burstRot"; to: 75; duration: 880; easing.type: Easing.OutCubic }
                    NumberAnimation { target: blob; property: "burstRot"; to: 75; duration: 520; easing.type: Easing.InOutCubic }
                }
                
                // halo suave atras, fixo (nao morfa)
                Rectangle {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    radius: 20
                    color: Colors.accent
                    opacity: 0.15
                }

                MaterialShape {
                    id: blob
                    anchors.fill: parent
                    color: Colors.accent
                    
                    animationDuration: 150 
                    animationEasing.type: Easing.OutCubic

                    property real creepRot: 0
                    property real burstRot: 0
                    rotation: creepRot + burstRot

                    NumberAnimation on creepRot {
                        from: 0
                        to: 360
                        duration: root.context.unlockInProgress ? 700 : 1400
                        loops: Animation.Infinite
                        running: true
                    }
                }
            }

            Timer {
                interval: root.context.unlockInProgress ? 800 : 1100
                running: true
                repeat: true

                property int idx: 0
                readonly property var presets: [
                    MaterialShape.Cookie9Sided,
                    MaterialShape.Sunny,
                    MaterialShape.Cookie6Sided,
                    MaterialShape.Burst,
                    MaterialShape.SoftBoom,
                    MaterialShape.Flower
                ]

                onTriggered: {
                    idx = (idx + 1) % presets.length;
                    blob.shape = presets[idx]; 
                    bumpAnim.start();
                    burstAnim.start();
                }
            }
        }

        // ---------------- campo de senha (pilula) ----------------
        Rectangle {
            id: inputPill
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            implicitHeight: 52
            radius: height / 2
            color: Colors.surface
            border.width: 2
            border.color: root.context.showFailure ? Colors.red : (root.activeFocus ? Colors.muted : "transparent")

            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 8
                spacing: 10

                Text {
                    text: root.context.unlockInProgress ? "󰔟" : "󰌾"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: Colors.muted
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 20

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.context.currentText.length === 0
                        text: "Digite sua senha"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: Colors.muted
                    }

                    ListView {
                        id: dotsRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        width: Math.min(contentWidth, parent.width)
                        height: 20
                        orientation: ListView.Horizontal
                        interactive: false
                        spacing: 8
                        layoutDirection: Qt.RightToLeft

                        model: ListModel { id: dotsModel }
                        delegate: passwordDotComponent

                        remove: Transition {}
                    }

                    Connections {
                        target: root.context
                        function onCurrentTextChanged() {
                            const len = root.context.currentText.length;
                            while (dotsModel.count < len) dotsModel.append({});
                            while (dotsModel.count > len) dotsModel.remove(dotsModel.count - 1);
                        }
                    }
                }

                Rectangle {
                    id: sendBtn
                    implicitHeight: 36
                    implicitWidth: root.context.currentText.length > 0 ? 36 : 0
                    radius: 18
                    color: sendMouse.pressed ? Colors.accent : Colors.accent
                    opacity: root.context.currentText.length > 0 ? 1 : 0
                    clip: true

                    Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰁔"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color: Colors.fg
                    }

                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.context.tryUnlock()
                    }
                }
            }
        }

        // ---------------- mensagem de estado ----------------
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.context.showFailure ? "Senha incorreta" : " "
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Colors.red
            opacity: root.context.showFailure ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }
}
