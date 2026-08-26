import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 38

    color: "transparent"

    margins {
        top: 8
        left: 10
        right: 10
    }

    exclusionMode: ExclusionMode.Auto
    WlrLayershell.layer: WlrLayer.Top

    WlrLayershell.keyboardFocus: launcherPanel.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Startup animation handler
    StartupSplash {
        screenTarget: bar.modelData
        onFinished: barEnterAnim.start()
    }

// --- NOSSO TRUQUE DE IPC INFALÍVEL ---
    // Ele fica escutando o arquivo sem gastar processamento. 
    // Quando recebe um sinal, abre o Launcher e já volta a escutar.
    Process {
        id: shortcutListener
        command: ["bash", "-c", "if [ ! -p /tmp/qs_toggle ]; then mkfifo /tmp/qs_toggle; fi; cat /tmp/qs_toggle"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                launcherPanel.visible = !launcherPanel.visible
                restartTimer.start()
            }
        }
    }

    // Um timer rápido só pro QML reiniciar o listener com segurança
    Timer {
        id: restartTimer
        interval: 20
        onTriggered: shortcutListener.running = true
    }
    // -------------------------------------

    Rectangle {
        id: background

        anchors.fill: parent
        color: Colors.bg
        radius: 19

        // Hidden initially until splash finishes
        opacity: 0
        transform: Translate { id: barTrans; y: -30 }

        ParallelAnimation {
            id: barEnterAnim
            NumberAnimation { target: background; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: barTrans; property: "y"; to: 0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        RowLayout {
            id: leftLayout

            anchors {
                left: parent.left
                leftMargin: 10
                verticalCenter: parent.verticalCenter
            }

            spacing: 6

            MorphingButton {
                  Layout.alignment: Qt.AlignVCenter
                  icon: ""
                  text: "Apps"
    
                  onClicked: launcherPanel.visible = !launcherPanel.visible
              }

            IdleInhibitor {
            }

            Volume {
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            id: centerLayout

            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }

            spacing: 10

            Workspaces {
                Layout.alignment: Qt.AlignVCenter
            }

            ClockWidget {
                Layout.alignment: Qt.AlignVCenter
            }

            Taskbar {
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            id: rightLayout

            anchors {
                right: parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }

            spacing: 6


            MorphingStat {
                Layout.alignment: Qt.AlignVCenter
                icon: "" // Ícone pro processador
                hoverName: "CPU"
                command: [
                    "bash",
                    "-c",
                    "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1"
                ] 
                suffix: "%" 
                intervalMs: 2000 

                onClicked: Quickshell.execDetached([
                    "kitty",
                    "-e",
                    "btop --force-utf"
                ]) 
            }

            MorphingStat {
                Layout.alignment: Qt.AlignVCenter
                icon: "󰘚" // Ícone pra memória
                hoverName: "RAM"
                command: [
                    "bash",
                    "-c",
                    "free -b | awk '/Mem:/ {printf \"%.1fG/%.1fG\", $3/1073741824, $2/1073741824}'"
                ] 
                intervalMs: 5000 
            }

            TrayModule {
                Layout.alignment: Qt.AlignVCenter
            }

            MorphingButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "󰎟" 
                text: "System"
                
                onClicked: {
                    systemPanel.visible = !systemPanel.visible
                }
            }
        }
    }


    LauncherPopup {
        id: launcherPanel

        anchor.window: bar
        anchor.rect.x: 10
        anchor.rect.y: bar.height + 5
    }

    SystemPanelPopup {
        id: systemPanel

        anchor.window: bar
        anchor.rect.x: bar.width - width - 10
        anchor.rect.y: bar.height + 5
    }
}
