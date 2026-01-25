import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    id: root

    // Цвета из вашего waybar
    readonly property color colorBgPrimary: "#151515"
    readonly property color colorBgSecondary: "transparent"
    readonly property color colorBgWorkspaceActive: "#fff0f5"
    readonly property color colorBgWorkspaceHover: Qt.rgba(0, 0, 0, 0.2)
    readonly property color colorTextPrimary: "#ffffff"
    readonly property color colorTextSecondary: "#dcd7ba"
    readonly property color colorTextWorkspaceActive: "#000000"

    // Данные системы
    property int cpuUsage: 0
    property int memoryUsage: 0
    property int volume: 50
    property int micVolume: 80
    property string networkStatus: "wifi"
    property string networkSSID: ""
    property string currentLanguage: "EN"

    // Детальные данные CPU
    property var cpuCores: []
    property int cpuTemp: 0
    property real cpuFreq: 0.0

    // Детальные данные памяти
    property real memTotal: 0.0
    property real memUsed: 0.0
    property real memFree: 0.0
    property real memAvailable: 0.0
    property real swapTotal: 0.0
    property real swapUsed: 0.0

    // Tooltip visibility
    property bool tooltipVisible: false

    // ===== ЯЗЫК =====
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: langProcess.running = true
    }

    Process {
        id: langProcess
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap'"]
        stdout: SplitParser {
            onRead: data => {
                let layout = data.trim()
                
                if (layout.toLowerCase().includes("russian") || layout.toLowerCase().includes("ru")) {
                    root.currentLanguage = "RU"
                } else if (layout.toLowerCase().includes("english") || layout.toLowerCase().includes("us") || layout.toLowerCase().includes("en")) {
                    root.currentLanguage = "EN"
                } else if (layout !== "" && layout !== "null") {
                    root.currentLanguage = layout.substring(0, 2).toUpperCase()
                } else {
                    root.currentLanguage = "EN"
                }
            }
        }
    }

    // ===== Socket listener для мгновенного обновления при смене раскладки =====
    Process {
        id: hyprlandSocket
        running: true
        command: ["sh", "-c", `
            socat -u UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - 2>/dev/null | while IFS= read -r line; do
                if echo "$line" | grep -q "activelayout>>"; then
                    echo "LAYOUT_CHANGED"
                fi
            done
        `]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("LAYOUT_CHANGED")) {
                    langProcess.running = true
                }
            }
        }
    }

    // ===== CPU монитор =====
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProcess.running = true
            cpuCoresProcess.running = true
            cpuTempProcess.running = true
            cpuFreqProcess.running = true
        }
    }

    Process {
        id: cpuProcess
        command: ["sh", "-c", "grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf \"%.0f\", usage}'"]
        stdout: SplitParser {
            onRead: data => root.cpuUsage = parseInt(data.trim()) || 0
        }
    }

    Process {
        id: cpuCoresProcess
        command: ["sh", "-c", "grep '^cpu[0-9]' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5); printf \"%.0f \", usage}'"]
        stdout: SplitParser {
            onRead: data => {
                let coresStr = data.trim().split(' ').filter(x => x !== '')
                let coresArray = []
                for (let i = 0; i < coresStr.length; i++) {
                    coresArray.push(parseInt(coresStr[i]) || 0)
                }
                root.cpuCores = coresArray
            }
        }
    }

    Process {
        id: cpuTempProcess
        command: ["sh", "-c", "sensors 2>/dev/null | grep -E 'Package id 0|Tdie|Tctl' | head -1 | grep -o '+[0-9.]*' | tr -d '+' | awk '{printf \"%.0f\", $1}' || (for f in /sys/class/thermal/thermal_zone*/temp; do cat $f 2>/dev/null; done | sort -nr | head -1 | awk '{printf \"%.0f\", $1/1000}') || echo 'N/A'"]
        stdout: SplitParser {
            onRead: data => {
                let temp = data.trim()
                root.cpuTemp = (temp === 'N/A' || temp === '') ? 0 : (parseInt(temp) || 0)
            }
        }
    }

    Process {
        id: cpuFreqProcess
        command: ["sh", "-c", "cat /proc/cpuinfo | grep 'MHz' | head -1 | awk '{printf \"%.1f\", $4/1000}'"]
        stdout: SplitParser {
            onRead: data => root.cpuFreq = parseFloat(data.trim()) || 0.0
        }
    }

    // ===== Memory монитор =====
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            memProcess.running = true
            memDetailProcess.running = true
        }
    }

    Process {
        id: memProcess
        command: ["sh", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'"]
        stdout: SplitParser {
            onRead: data => root.memoryUsage = parseInt(data.trim()) || 0
        }
    }

    Process {
        id: memDetailProcess
        command: ["sh", "-c", "free -m | awk 'NR==2 {printf \"%.1f %.1f %.1f %.1f\", $2/1024, $3/1024, $4/1024, $7/1024} NR==3 {printf \" %.1f %.1f\", $2/1024, $3/1024}'"]
        stdout: SplitParser {
            onRead: data => {
                let values = data.trim().split(' ')
                if (values.length >= 6) {
                    root.memTotal = parseFloat(values[0]) || 0.0
                    root.memUsed = parseFloat(values[1]) || 0.0
                    root.memFree = parseFloat(values[2]) || 0.0
                    root.memAvailable = parseFloat(values[3]) || 0.0
                    root.swapTotal = parseFloat(values[4]) || 0.0
                    root.swapUsed = parseFloat(values[5]) || 0.0
                }
            }
        }
    }

    // ===== Volume монитор =====
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            volumeProcess.running = true
            micProcess.running = true
        }
    }

    Process {
        id: volumeProcess
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{muted=($3==\"[MUTED]\")?1:0; vol=int($2*100); print vol\" \"muted}' || pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%' | awk '{print $1\" 0\"}'"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(' ')
                if (parts.length >= 2) {
                    root.volume = parseInt(parts[0]) || 0
                }
            }
        }
    }

    Process {
        id: micProcess
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{muted=($3==\"[MUTED]\")?1:0; vol=int($2*100); print vol\" \"muted}' || pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%' | awk '{print $1\" 0\"}'"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(' ')
                if (parts.length >= 2) {
                    root.micVolume = parseInt(parts[0]) || 0
                }
            }
        }
    }

    // ===== Network монитор =====
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: networkProcess.running = true
    }

    Process {
        id: networkProcess
        command: ["sh", "-c", "if ping -c 1 8.8.8.8 >/dev/null 2>&1; then if iwgetid -r 2>/dev/null; then echo 'wifi'; else echo 'ethernet'; fi; else echo 'disconnected'; fi"]
        stdout: SplitParser {
            onRead: data => {
                let status = data.trim()
                
                if (status === "wifi") {
                    root.networkStatus = "wifi"
                    ssidProcess.running = true
                } else if (status === "ethernet") {
                    root.networkStatus = "ethernet"
                    root.networkSSID = ""
                } else {
                    root.networkStatus = "disconnected"
                    root.networkSSID = ""
                }
            }
        }
    }
    
    Process {
        id: ssidProcess
        command: ["sh", "-c", "iwgetid -r 2>/dev/null || echo ''"]
        stdout: SplitParser {
            onRead: data => root.networkSSID = data.trim()
        }
    }

    // Process для изменения громкости
    Process {
        id: volumeChangeProcess
        property int targetVolume: 50
        command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + targetVolume + "% 2>/dev/null || pactl set-sink-volume @DEFAULT_SINK@ " + targetVolume + "%"]
    }

    Process {
        id: micChangeProcess
        property int targetVolume: 50
        command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + targetVolume + "% 2>/dev/null || pactl set-source-volume @DEFAULT_SOURCE@ " + targetVolume + "%"]
    }

    Component.onCompleted: {
        networkProcess.running = true
        langProcess.running = true
    }

    Variants {
        model: Quickshell.screens
        
        delegate: Component {
            Item {
                property var modelData
            
            // Tooltip Window
            PanelWindow {
                id: tooltipWindow
                screen: modelData
                visible: root.tooltipVisible && modelData.name === "DP-1"
                
                anchors {
                    top: true
                    right: true
                }
                
                margins {
                    top: 36
                    right: 10
                }
                
                width: 320
                height: 360
                
                color: "transparent"
                focusable: false
                exclusionMode: ExclusionMode.Ignore
                
                Rectangle {
                    anchors.fill: parent
                    color: root.colorBgPrimary
                    radius: 5
                    
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 12

                        // ===== CPU SECTION =====
                        Column {
                            width: parent.width
                            spacing: 8

                            // CPU Header
                            Row {
                                spacing: 6
                                Text {
                                    text: "\uf2db"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: "CPU Usage"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                            }

                            // Overall CPU
                            Item {
                                width: parent.width
                                height: 20
                                
                                Text {
                                    anchors.left: parent.left
                                    text: "Overall:"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: root.cpuUsage + "%"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                            }

                            // CPU Progress Bar
                            Rectangle {
                                width: parent.width
                                height: 6
                                color: Qt.rgba(220/255, 215/255, 186/255, 0.2)
                                radius: 3

                                Rectangle {
                                    width: parent.width * (root.cpuUsage / 100)
                                    height: parent.height
                                    radius: 3
                                    color: {
                                        if (root.cpuUsage > 80) return "#ef4444"
                                        if (root.cpuUsage > 60) return "#fbbf24"
                                        return "#4ade80"
                                    }
                                    
                                    Behavior on width { NumberAnimation { duration: 300 } }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                            }

                            // CPU Cores в 2 столбца
                            Grid {
                                width: parent.width
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 6

                                Repeater {
                                    model: root.cpuCores.length
                                    
                                    Item {
                                        width: (parent.width - parent.columnSpacing) / 2
                                        height: 16
                                        
                                        Text {
                                            anchors.left: parent.left
                                            text: "Core " + (index + 1) + ":"
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            opacity: 0.8
                                        }
                                        Text {
                                            anchors.right: parent.right
                                            text: root.cpuCores[index] + "%"
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                        }
                                    }
                                }
                            }

                            // Separator after cores
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                            }

                            // CPU Temperature & Frequency
                            Column {
                                width: parent.width
                                spacing: 6

                                Item {
                                    width: parent.width
                                    height: 16
                                    Text {
                                        anchors.left: parent.left
                                        text: "Temperature:"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        opacity: 0.8
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: root.cpuTemp > 0 ? (root.cpuTemp + "°C") : "N/A"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 16
                                    Text {
                                        anchors.left: parent.left
                                        text: "Frequency:"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        opacity: 0.8
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: root.cpuFreq.toFixed(1) + " GHz"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            // Separator
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                            }
                        }

                        // ===== MEMORY SECTION =====
                        Column {
                            width: parent.width
                            spacing: 8

                            // Memory Header
                            Row {
                                spacing: 6
                                Text {
                                    text: "\uefc5"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: "Memory Usage"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                            }

                            // Overall Memory
                            Item {
                                width: parent.width
                                height: 20
                                Text {
                                    anchors.left: parent.left
                                    text: "Overall:"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: root.memoryUsage + "%"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                            }

                            // Memory Progress Bar
                            Rectangle {
                                width: parent.width
                                height: 6
                                color: Qt.rgba(220/255, 215/255, 186/255, 0.2)
                                radius: 3

                                Rectangle {
                                    width: parent.width * (root.memoryUsage / 100)
                                    height: parent.height
                                    radius: 3
                                    color: {
                                        if (root.memoryUsage > 80) return "#ef4444"
                                        if (root.memoryUsage > 60) return "#fbbf24"
                                        return "#4ade80"
                                    }
                                    
                                    Behavior on width { NumberAnimation { duration: 300 } }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                            }

                            // Memory Details
                            Column {
                                width: parent.width
                                spacing: 6

                                Item {
                                    width: parent.width
                                    height: 16
                                    Text {
                                        anchors.left: parent.left
                                        text: "Used:"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        opacity: 0.8
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: root.memUsed.toFixed(1) + " GB"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 16
                                    Text {
                                        anchors.left: parent.left
                                        text: "Free:"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        opacity: 0.8
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: root.memFree.toFixed(1) + " GB"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 16
                                    Text {
                                        anchors.left: parent.left
                                        text: "Total:"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        opacity: 0.8
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: root.memTotal.toFixed(1) + " GB"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Main Bar Window
            PanelWindow {
                id: bar
                screen: modelData
                visible: modelData.name === "DP-1"

                anchors {
                    top: true
                    left: true
                    right: true
                }

                exclusionMode: ExclusionMode.Auto
                exclusiveZone: 36
                height: 36
                focusable: false
                
                color: root.colorBgSecondary

                Item {
                    anchors.fill: parent
                    anchors.margins: 3
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7

                    // LEFT
                    RowLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            color: root.colorBgPrimary
                            radius: 5
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: workspacesRow.width + 18

                            RowLayout {
                                id: workspacesRow
                                anchors.centerIn: parent
                                spacing: 2

                                Repeater {
                                    model: 6

                                    Rectangle {
                                        id: wsButton
                                        property int wsNumber: index + 1
                                        property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === wsNumber
                                        property bool hasWindows: {
                                            for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                                                let ws = Hyprland.workspaces.values[i]
                                                if (ws.id === wsNumber) return true
                                            }
                                            return false
                                        }

                                        width: 24
                                        height: 24
                                        radius: 5
                                        color: isActive ? root.colorBgWorkspaceActive : 
                                               wsMouseArea.containsMouse ? root.colorBgWorkspaceHover : "transparent"

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: wsNumber
                                            color: wsButton.isActive ? root.colorTextWorkspaceActive : root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                            opacity: wsButton.hasWindows || wsButton.isActive ? 1.0 : 0.5
                                        }

                                        MouseArea {
                                            id: wsMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: Hyprland.dispatch("workspace " + wsButton.wsNumber)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // CENTER
                    Rectangle {
                        anchors.centerIn: parent
                        color: root.colorBgPrimary
                        radius: 5
                        height: 30
                        width: clockRow.implicitWidth + 18

                        Row {
                            id: clockRow
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                id: clockDate
                                text: Qt.formatDateTime(new Date(), "ddd dd MMM yyyy")
                                color: root.colorTextSecondary
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }
                            
                            Text {
                                text: "\uf017"
                                color: root.colorTextSecondary
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }
                            
                            Text {
                                id: clockTime
                                text: Qt.formatDateTime(new Date(), "HH:mm")
                                color: root.colorTextSecondary
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }
                        }

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: {
                                let now = new Date()
                                clockDate.text = Qt.formatDateTime(now, "ddd dd MMM yyyy")
                                clockTime.text = Qt.formatDateTime(now, "HH:mm")
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: swancProcess.running = true
                        }

                        Process {
                            id: swancProcess
                            command: ["swaync-client", "-t", "-sw"]
                        }
                    }

                    // RIGHT
                    RowLayout {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // Language
                        Rectangle {
                            color: root.colorBgPrimary
                            radius: 5
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: langRow.implicitWidth + 18

                            Row {
                                id: langRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "\uf11c"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: root.currentLanguage
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                            }
                        }

                        // Audio
                        Rectangle {
                            color: root.colorBgPrimary
                            radius: 5
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: audioRow.implicitWidth + 18

                            Process {
                                id: pavuProcess
                                command: ["pavucontrol"]
                            }

                            Row {
                                id: audioRow
                                anchors.centerIn: parent
                                spacing: 6

                                Item {
                                    width: volumeRow.width
                                    height: 30
                                    
                                    Row {
                                        id: volumeRow
                                        spacing: 4
                                        anchors.centerIn: parent
                                        
                                        Text {
                                            text: {
                                                if (root.volume === 0) return "\uf6a9"
                                                if (root.volume > 66) return "\uf028"
                                                if (root.volume > 33) return "\uf027"
                                                return "\uf026"
                                            }
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }
                                        Text {
                                            text: root.volume + "%"
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.NoButton
                                        onClicked: pavuProcess.running = true
                                        onWheel: wheel => {
                                            let delta = wheel.angleDelta.y > 0 ? 5 : -5
                                            let newVol = Math.max(0, Math.min(100, root.volume + delta))
                                            volumeChangeProcess.targetVolume = newVol
                                            volumeChangeProcess.running = true
                                        }
                                    }
                                }

                                Item {
                                    width: micRow.width
                                    height: 30
                                    
                                    Row {
                                        id: micRow
                                        spacing: 4
                                        anchors.centerIn: parent
                                        
                                        Text {
                                            text: root.micVolume === 0 ? "\uf131" : "\uf130"
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }
                                        Text {
                                            text: root.micVolume === 0 ? "" : root.micVolume + "%"
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                            visible: root.micVolume > 0
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.NoButton
                                        onClicked: pavuProcess.running = true
                                        onWheel: wheel => {
                                            let delta = wheel.angleDelta.y > 0 ? 5 : -5
                                            let newVol = Math.max(0, Math.min(100, root.micVolume + delta))
                                            micChangeProcess.targetVolume = newVol
                                            micChangeProcess.running = true
                                        }
                                    }
                                }
                            }
                        }

                        // Hardware
                        Rectangle {
                            color: root.colorBgPrimary
                            radius: 5
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: hardwareRow.implicitWidth + 18

                            Row {
                                id: hardwareRow
                                anchors.centerIn: parent
                                spacing: 10

                                Row {
                                    spacing: 4
                                    Text {
                                        text: root.cpuUsage + "%"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        text: "\uf2db"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }
                                }

                                Row {
                                    spacing: 4
                                    Text {
                                        text: root.memoryUsage + "%"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        text: "\uefc5"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.tooltipVisible = true
                                onExited: root.tooltipVisible = false
                            }
                        }

                        // Network
                        Rectangle {
                            color: root.colorBgPrimary
                            radius: 5
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: networkText.implicitWidth + 18

                            MouseArea {
                                id: networkMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: nmProcess.running = true
                            }

                            Process {
                                id: nmProcess
                                command: ["nm-connection-editor"]
                            }

                            Text {
                                id: networkText
                                anchors.centerIn: parent
                                text: {
                                    if (root.networkStatus === "wifi") return "\uf1eb"
                                    if (root.networkStatus === "ethernet") return "\uef44"
                                    return "\uf06a"
                                }
                                color: root.colorTextSecondary
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                            }

                            Rectangle {
                                visible: networkMouseArea.containsMouse && root.networkSSID !== ""
                                color: root.colorBgPrimary
                                radius: 5
                                width: tooltipText.implicitWidth + 16
                                height: tooltipText.implicitHeight + 8
                                z: 1000
                                anchors.top: parent.bottom
                                anchors.topMargin: 5
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    id: tooltipText
                                    anchors.centerIn: parent
                                    text: "SSID: " + root.networkSSID
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
            }
        }
    }
}
