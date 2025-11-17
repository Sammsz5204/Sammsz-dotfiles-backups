import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Quickshell 
import Quickshell.Wayland 

ShellRoot {
    WlSessionLock {
        id: lock
        locked: true
        
        WlSessionLockSurface {
            // Gruvbox Dark Colors
            readonly property color bg0: "#282828"
            readonly property color bg1: "#3c3836"
            readonly property color bg2: "#504945"
            readonly property color fg: "#ebdbb2"
            readonly property color red: "#cc241d"
            readonly property color green: "#98971a"
            readonly property color yellow: "#d79921"
            readonly property color blue: "#458588"
            readonly property color purple: "#b16286"
            readonly property color aqua: "#689d6a"
            readonly property color orange: "#d65d0e"
            
            color: bg0
            
            // Time and Date
            Column {
                anchors.centerIn: parent
                spacing: 20
                
                // Clock
                Text {
                    id: timeText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font.pixelSize: 120
                    font.bold: true
                    font.family: "JetBrains Mono"
                    color: fg
                    
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: timeText.text = Qt.formatTime(new Date(), "hh:mm")
                    }
                }
                
                // Date
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(new Date(), "dddd, MMMM dd")
                    font.pixelSize: 24
                    font.family: "JetBrains Mono"
                    color: aqua
                    opacity: 0.9
                }
                
                // Password Field Container
                Rectangle {
                    width: 400
                    height: 60
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: bg1
                    radius: 12
                    border.width: 2
                    border.color: passwordField.activeFocus ? yellow : bg2
                    
                    Behavior on border.color {
                        ColorAnimation { duration: 200 }
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15
                        
                        // Lock Icon
                        Text {
                            text: "🔒"
                            font.pixelSize: 24
                            color: fg
                        }
                        
                        // Password Input
                        TextField {
                            id: passwordField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            
                            echoMode: TextInput.Password
                            placeholderText: "Enter password..."
                            placeholderTextColor: bg2
                            color: fg
                            font.pixelSize: 16
                            font.family: "JetBrains Mono"
                            
                            background: Rectangle {
                                color: "transparent"
                            }
                            
                            Keys.onReturnPressed: {
                                if (text.length > 0) {
                                    attemptUnlock(text)
                                }
                            }
                            
                            Component.onCompleted: forceActiveFocus()
                        }
                    }
                }
                
                // Error message
                Text {
                    id: errorText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ""
                    font.pixelSize: 14
                    font.family: "JetBrains Mono"
                    color: red
                    opacity: 0
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }
                
                // Instructions
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Press Enter to unlock"
                    font.pixelSize: 14
                    font.family: "JetBrains Mono"
                    color: bg2
                    opacity: 0.7
                }
            }
            
            // User Avatar (optional)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: 200
                width: 100
                height: 100
                radius: 50
                color: bg1
                border.width: 3
                border.color: yellow
                
                Text {
                    anchors.centerIn: parent
                    text: "👤"
                    font.pixelSize: 50
                }
            }
            
            // Bottom info bar
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 50
                color: bg1
                opacity: 0.95
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    
                    // Battery indicator
                    Row {
                        spacing: 8
                        Text {
                            text: "🔋"
                            font.pixelSize: 18
                            color: green
                        }
                        Text {
                            text: "85%"
                            font.pixelSize: 14
                            font.family: "JetBrains Mono"
                            color: fg
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Network indicator
                    Row {
                        spacing: 8
                        Text {
                            text: "📶"
                            font.pixelSize: 18
                            color: aqua
                        }
                        Text {
                            text: "Connected"
                            font.pixelSize: 14
                            font.family: "JetBrains Mono"
                            color: fg
                        }
                    }
                }
            }
            
            // Unlock function
            function attemptUnlock(password) {
                // Aqui você integraria com PAM ou seu sistema de autenticação
                // Por exemplo, usando um processo externo
                
                if (password === "test") {
                    lock.locked = false
                } else {
                    errorText.text = "Incorrect password"
                    errorText.opacity = 1
                    passwordField.text = ""
                    
                    // Shake animation
                    shakeAnimation.start()
                    
                    // Hide error after 2 seconds
                    hideErrorTimer.start()
                }
            }
            
            // Shake animation for wrong password
            SequentialAnimation {
                id: shakeAnimation
                NumberAnimation {
                    target: passwordField.parent
                    property: "anchors.horizontalCenterOffset"
                    to: -10
                    duration: 50
                }
                NumberAnimation {
                    target: passwordField.parent
                    property: "anchors.horizontalCenterOffset"
                    to: 10
                    duration: 50
                }
                NumberAnimation {
                    target: passwordField.parent
                    property: "anchors.horizontalCenterOffset"
                    to: -10
                    duration: 50
                }
                NumberAnimation {
                    target: passwordField.parent
                    property: "anchors.horizontalCenterOffset"
                    to: 0
                    duration: 50
                }
            }
            
            Timer {
                id: hideErrorTimer
                interval: 2000
                onTriggered: errorText.opacity = 0
            }
        }
    }
}
