import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    
    property string searchText: ""
    property int selectedIndex: 0
    property var filteredApps: []
    property var allApps: []
    
    Process {
        id: appsLoader
        command: ["bash", "-c", String.raw`
            find \
                /run/current-system/sw/share/applications \
                ~/.nix-profile/share/applications \
                /etc/profiles/per-user/$USER/share/applications \
                ~/.local/share/applications \
                /usr/share/applications \
                -name '*.desktop' 2>/dev/null | while read -r f; do
                [ -f "$f" ] || continue
                grep -q '^NoDisplay=true' "$f" 2>/dev/null && continue
                grep -q '^Hidden=true' "$f" 2>/dev/null && continue
                name=""
                exec=""
                icon=""
                while IFS='=' read -r key value; do
                    case "$key" in
                        Name) [ -z "$name" ] && name="$value" ;;
                        Exec) [ -z "$exec" ] && exec="$value" ;;
                        Icon) [ -z "$icon" ] && icon="$value" ;;
                    esac
                done < "$f"
                exec=$(echo "$exec" | sed 's/ %[a-zA-Z]//g')
                [ -n "$name" ] && [ -n "$exec" ] && echo "$name|$exec|$icon"
            done | sort -t'|' -k1 -u
        `]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("|")
                if (parts.length >= 2 && parts[0].trim() !== "") {
                    root.allApps.push({
                        name: parts[0],
                        exec: parts[1],
                        icon: parts[2] || ""
                    })
                    root.allApps = root.allApps.slice()
                    root.filterApps()
                }
            }
        }
    }
    
    function filterApps() {
        if (searchText === "") {
            filteredApps = allApps.slice()
        } else {
            filteredApps = allApps.filter(app => 
                app.name.toLowerCase().includes(searchText.toLowerCase())
            )
        }
        selectedIndex = Math.min(selectedIndex, Math.max(0, filteredApps.length - 1))
    }
    
    function launchApp(exec) {
        let cleanExec = exec
            .replace(/%[fFuUdDnNickvm]/g, '')
            .replace(/\s+/g, ' ')
            .trim()
        
        launcher.command = ["bash", "-c", "setsid " + cleanExec + " >/dev/null 2>&1 &"]
        launcher.running = true
    }
    
    Process {
        id: launcher
        running: false
        onRunningChanged: {
            if (!running) {
                Qt.quit()
            }
        }
    }
    
    PanelWindow {
        id: launcherWindow
        
        screen: Quickshell.screens.find(s => s.name === "DP-1") ?? Quickshell.screens[0]
        
        visible: true
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        
        color: "transparent"
        
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }
        
        Rectangle {
            id: mainContainer
            width: 500
            height: 400
            anchors.centerIn: parent
            color: "#151515"
            radius: 12
            border.color: "#FFFBFB"
            border.width: 2
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    color: "#1e1e1e"
                    radius: 8
                    border.color: "#FFFBFB"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        
                        Text {
                            text: ">"
                            color: "#FFFBFB"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        
                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: "#FFFBFB"
                            font.pixelSize: 16
                            clip: true
                            focus: true
                            
                            Component.onCompleted: forceActiveFocus()
                            
                            Text {
                                anchors.fill: parent
                                text: "Поиск приложений..."
                                color: "#666666"
                                font.pixelSize: 16
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                            
                            onTextChanged: {
                                root.searchText = text
                                root.filterApps()
                            }
                            
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    Qt.quit()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Down) {
                                    root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredApps.length - 1)
                                    appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up) {
                                    root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                                    appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (root.filteredApps.length > 0) {
                                        root.launchApp(root.filteredApps[root.selectedIndex].exec)
                                    }
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    clip: true
                    
                    ListView {
                        id: appList
                        anchors.fill: parent
                        model: root.filteredApps
                        spacing: 4
                        
                        flickDeceleration: 5000
                        maximumFlickVelocity: 8000
                        
                        // Целевая позиция для плавного скролла
                        property real targetY: contentY
                        
                        // Плавная анимация скролла
                        Behavior on contentY {
                            SmoothedAnimation {
                                duration: 120
                                velocity: 1500
                            }
                        }
                        
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: "#FFFBFB"
                                opacity: 0.5
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            
                            onWheel: wheel => {
                                // Кол-во элементов для скролла за один тик
                                let itemsToScroll = 4
                                let scrollAmount = (48 + appList.spacing) * itemsToScroll
                                
                                let maxY = Math.max(0, appList.contentHeight - appList.height)
                                
                                if (wheel.angleDelta.y > 0) {
                                    // Скролл вверх
                                    appList.contentY = Math.max(0, appList.contentY - scrollAmount)
                                } else {
                                    // Скролл вниз
                                    appList.contentY = Math.min(maxY, appList.contentY + scrollAmount)
                                }
                            }
                        }
                        
                        delegate: Rectangle {
                            id: appItem
                            width: appList.width - 10
                            height: 48
                            radius: 8
                            color: index === root.selectedIndex ? "#2a2a2a" : "transparent"
                            border.color: index === root.selectedIndex ? "#FFFBFB" : "transparent"
                            border.width: 1
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12
                                
                                Item {
                                    width: 28
                                    height: 28
                                    
                                    Image {
                                        id: appIcon
                                        anchors.fill: parent
                                        source: modelData.icon ? "image://icon/" + modelData.icon : ""
                                        sourceSize: Qt.size(28, 28)
                                        visible: status === Image.Ready
                                        smooth: true
                                    }
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: "#3a3a3a"
                                        visible: appIcon.status !== Image.Ready
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.name.charAt(0).toUpperCase()
                                            color: "#FFFBFB"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }
                                }
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: "#FFFBFB"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                
                                onEntered: {
                                    root.selectedIndex = index
                                }
                                
                                onClicked: {
                                    root.launchApp(modelData.exec)
                                }
                            }
                        }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.allApps.length === 0 ? "Загрузка..." : "Ничего не найдено"
                        color: "#666666"
                        font.pixelSize: 14
                        visible: root.filteredApps.length === 0
                    }
                }
            }
        }
    }
}
