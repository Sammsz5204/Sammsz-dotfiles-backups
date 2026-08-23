import Quickshell
import Quickshell.Wayland
import QtQuick

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
                NumberAnimation { target: blob; property: "burstRot"; to: 75; duration: 680; easing.type: Easing.OutCubic }
                NumberAnimation { target: blob; property: "burstRot"; to: 75; duration: 480; easing.type: Easing.InOutCubic }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 160
                height: 160
                radius: 80
                color: Colors.accent
                opacity: 0.15
            }

            Canvas {
                id: blob
                anchors.fill: parent

                property real lobes: 8
                property real amplitude: 0.15

                Behavior on lobes { NumberAnimation { duration: 50; easing.type: Easing.InOutCubic } }
                Behavior on amplitude { NumberAnimation { duration: 50; easing.type: Easing.InOutCubic } }

                onLobesChanged: requestPaint()
                onAmplitudeChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const cx = width / 2, cy = height / 2;
                    const baseR = Math.min(width, height) / 2 - 6;
                    const steps = 1024;
                    ctx.beginPath();
                    for (let i = 0; i <= steps; i++) {
                        const t = (i / steps) * Math.PI * 2;
                        const r = baseR * (1 + amplitude * Math.cos(lobes * t));
                        const x = cx + r * Math.cos(t);
                        const y = cy + r * Math.sin(t);
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    ctx.closePath();
                    ctx.fillStyle = Colors.accent;
                    ctx.fill();
                }

                property real creepRot: 0
                property real burstRot: 0
                rotation: creepRot + burstRot

                NumberAnimation on creepRot {
                    from: 0
                    to: 360
                    duration: 1500
                    loops: Animation.Infinite
                    running: true
                }
            }

            Timer {
                interval: 780
                running: true
                repeat: true
                property int idx: 0
                readonly property var presets: [
                    { lobes: 9,  amp: 0.04 },
                    { lobes: 10, amp: 0.15 },
                    { lobes: 5,  amp: 0.05 },
                    { lobes: 2,  amp: 0.1 },
                    { lobes: 8,  amp: 0.14 },
                    { lobes: 4,  amp: 0.2 }
                ]
                onTriggered: {
                    idx = (idx + 1) % presets.length;
                    blob.lobes = presets[idx].lobes;
                    blob.amplitude = presets[idx].amp;
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
