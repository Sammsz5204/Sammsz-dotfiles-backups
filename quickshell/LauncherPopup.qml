// ============================================================
// LauncherPopup.qml — Material 3 Expressive (Lightweight)
// ============================================================
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PopupWindow {
    id: root

    implicitWidth: 420
    implicitHeight: 520

    color: "transparent"
    visible: false

    property var allApps: []
    property var filteredApps: []

    function updateFilter() {
        if (!allApps) return;
        var q = searchInput.text.toLowerCase().trim();
        if (q === "") {
            filteredApps = allApps;
        } else {
            filteredApps = allApps.filter(app => 
                (app.name && app.name.toLowerCase().includes(q)) ||
                (app.comment && app.comment.toLowerCase().includes(q))
            );
        }
    }

    // Leitura dos apps via Python (incluindo Flatpaks e rotas XDG)
    Process {
        id: appScanner
        command: [
            "python3", "-c",
            "import os, glob, configparser, json\n" +
            "apps = []\n" +
            "paths = [\n" +
            "    '/usr/share/applications/*.desktop',\n" +
            "    '/usr/local/share/applications/*.desktop',\n" +
            "    os.path.expanduser('~/.local/share/applications/*.desktop'),\n" +
            "    '/var/lib/flatpak/exports/share/applications/*.desktop',\n" +
            "    os.path.expanduser('~/.local/share/flatpak/exports/share/applications/*.desktop')\n" +
            "]\n" +
            "xdg = os.environ.get('XDG_DATA_DIRS', '')\n" +
            "for d in xdg.split(':'):\n" +
            "    if d: paths.append(os.path.join(d, 'applications', '*.desktop'))\n" +
            "seen = set()\n" +
            "for p in paths:\n" +
            "    for f in glob.glob(p):\n" +
            "        try:\n" +
            "            cfg = configparser.ConfigParser(interpolation=None, strict=False)\n" +
            "            cfg.read(f, encoding='utf-8')\n" +
            "            if 'Desktop Entry' in cfg:\n" +
            "                e = cfg['Desktop Entry']\n" +
            "                if e.get('NoDisplay', 'false').lower() == 'true' or e.get('Type', 'Application') != 'Application': continue\n" +
            "                name = e.get('Name', '')\n" +
            "                if not name or name in seen: continue\n" +
            "                seen.add(name)\n" +
            "                exec_cmd = e.get('Exec', '').split('%')[0].strip()\n" +
            "                if not exec_cmd: continue\n" +
            "                comment = e.get('Comment', 'Aplicativo do sistema')\n" +
            "                apps.append({'name': name, 'icon': e.get('Icon', ''), 'exec': exec_cmd, 'comment': comment})\n" +
            "        except Exception:\n" +
            "            pass\n" +
            "apps.sort(key=lambda x: x['name'].lower())\n" +
            "print(json.dumps(apps))"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.allApps = JSON.parse(this.text);
                    root.updateFilter();
                } catch(e) {}
            }
        }
    }

    Rectangle {
        id: cardContainer
        anchors.fill: parent
        color: Colors.bg
        border.color: Qt.alpha(Colors.surface, 0.8)
        border.width: 1
        radius: 19
        clip: true

        // --- ANIMAÇÃO DE EXPANSÃO DO VÍDEO (M3E DROPDOWN) ---
        transformOrigin: Item.TopLeft

        scale: root.visible ? 1.0 : 0.82
        opacity: root.visible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.4 // Mola idêntica ao vídeo do M3E
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Campo de busca Pill (estilo M3 Settings print)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52

                color: searchInput.activeFocus ? Colors.surface : Qt.lighter(Colors.bg, 1.15)
                border.color: searchInput.activeFocus ? Colors.accent : "transparent"
                border.width: 2
                radius: 13

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    Text {
                        text: "󰍉"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: searchInput.activeFocus ? Colors.accent : Colors.muted

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextField {
                        id: searchInput

                        Layout.fillWidth: true
                        placeholderText: "Pesquisar aplicativos..."
                        placeholderTextColor: Colors.muted
                        color: Colors.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        background: null

                        Keys.onEscapePressed: root.visible = false

                        onTextChanged: root.updateFilter()

                        onAccepted: {
                            if (root.filteredApps.length > 0) {
                                var firstApp = root.filteredApps[0];
                                Quickshell.execDetached(["bash", "-c", firstApp.exec + " &"]);
                                root.visible = false;
                            }
                        }
                    }

                    Text {
                        visible: searchInput.text.length > 0
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: Colors.muted

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = ""
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // Lista de Apps estilo M3 Cards
            ListView {
                id: appListView

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8

                model: root.filteredApps

                delegate: Rectangle {
                    id: appCard

                    width: appListView.width
                    height: 64
                    radius: 20 // Bordas M3 bem arredondadas
                    property var appData: modelData

                    // Estilo M3: Card individual com fundo elevado + feedback ativo
                    color: itemMouse.pressed 
                        ? Colors.accent
                        : (itemMouse.containsMouse ? Qt.lighter(Colors.surface, 1.2) : Colors.surface)

                    scale: itemMouse.pressed ? 0.93 : (itemMouse.containsMouse ? 1 : 0.99)

                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        spacing: 14

                        // Badge Circular pro Ícone Placeholder
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 21 // Círculo perfeito estilo print
                            color: itemMouse.pressed 
                                ? Qt.rgba(1, 1, 1, 0.25) 
                                : (itemMouse.containsMouse ? Colors.bg : Qt.lighter(Colors.bg, 1.1))

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰵆"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                                color: itemMouse.pressed ? Colors.bg : Colors.accent

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: appCard.appData.name || ""
                                color: itemMouse.pressed ? Colors.bg : Colors.fg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                text: appCard.appData.comment || "Aplicativo do sistema"
                                color: itemMouse.pressed ? Qt.rgba(0, 0, 0, 0.6) : Colors.muted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", appCard.appData.exec + " &"]);
                            root.visible = false;
                        }
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""
            searchInput.forceActiveFocus()
        }
    }
}
