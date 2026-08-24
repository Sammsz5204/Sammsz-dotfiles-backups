import Quickshell
import Quickshell.Wayland
import QtQuick
import M3Shapes // <-- Added this so it actually knows what a MaterialShape is fr

PanelWindow {
    id: splash
    required property var screenTarget
    screen: screenTarget

    signal finished()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        id: splashBg
        anchors.fill: parent
        color: Colors.bg
        opacity: 1

        Item {
            id: morphingIcon
            anchors.centerIn: parent
            width: 120
            height: 120

            SequentialAnimation {
                id: bumpAnim
                NumberAnimation { target: blob; property: "scale"; to: 1.15; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { target: blob; property: "scale"; to: 1; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
            }

            SequentialAnimation {
                id: burstAnim
                NumberAnimation { target: blob; property: "burstRot"; to: 150; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { target: blob; property: "burstRot"; to: 130; duration: 150; easing.type: Easing.InOutCubic }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 160
                height: 160
                radius: 80
                color: Colors.accent
                opacity: 0.15
            }

            // The new clean shape component
            MaterialShape {
                id: blob
                anchors.fill: parent
                color: Colors.accent
                
                animationDuration: 120
                animationEasing.type: Easing.OutCubic

                property real creepRot: 0
                property real burstRot: 0
                rotation: creepRot + burstRot

                NumberAnimation on creepRot {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: true
                }
            }

            Timer {
                interval: 580
                running: true
                repeat: true
                property int idx: 0
                
                // Only the softest, roundest shapes to mimic your old lobes/amplitude math
                readonly property var presets: [
                    MaterialShape.Cookie9Sided,
                    MaterialShape.Cookie6Sided,
                    MaterialShape.Pentagon,
                    MaterialShape.Pill
                ]
                
                onTriggered: {
                    idx = (idx + 1) % presets.length;
                    blob.shape = presets[idx];
                    bumpAnim.start();
                    burstAnim.start();
                }
            }
        }
    }

    SequentialAnimation {
        running: true
        PauseAnimation { duration: 3000 }
        ParallelAnimation {
            NumberAnimation { target: splashBg; property: "opacity"; to: 0; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: morphingIcon; property: "scale"; to: 0.4; duration: 280; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                splash.finished();
                splash.visible = false;
            }
        }
    }
}
