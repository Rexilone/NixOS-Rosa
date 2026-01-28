import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    id: root

    // Цвета
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
    property int brightness: 50
    property int batteryLevel: 0
    property bool batteryCharging: false
    property string networkStatus: "wifi"
    property string networkSSID: ""
    property string currentLanguage: "EN"

    // Dynamic Island
    property bool showDynamicIsland: false
    property bool isMouseOverIsland: false

    // Music Player
    property string musicTitle: "No Track Playing"
    property string musicArtist: "Unknown Artist"
    property string musicAlbum: ""
    property string musicArtUrl: ""
    property bool musicPlaying: false
    property string activePlayer: ""
    property string lockedPlayer: ""  // Запоминаем выбранный плеер
    property var availablePlayers: []

    // Wallpapers
    property var wallpaperList: []
    property int currentWallpaperIndex: 0
    property string wallpaperBuffer: ""
    
    // Carousel animation
    property real carouselPosition: 0
    property bool isAnimating: false
    property int slideDirection: 0  // -1 = prev, 1 = next

    // Notifications
    property var notifications: [
        { id: 1, title: "System Update", body: "New updates available", time: "5m ago" },
        { id: 2, title: "Battery Low", body: "15% remaining", time: "10m ago" }
    ]

    // Network
    property int currentNetworkTab: 0
    property var wifiNetworks: []
    property var bluetoothDevices: []
    property bool wifiScanning: false
    property bool btScanning: false
    property string wifiBuffer: ""
    property string btBuffer: ""

    // User changing flags
    property bool brightnessUserChanging: false
    property bool volumeUserChanging: false
    property bool micUserChanging: false

    // Управление Island
    function openIsland() {
        hideIslandTimer.stop()
        root.showDynamicIsland = true
    }

    function closeIsland() {
        root.showDynamicIsland = false
    }

    Timer {
        id: hideIslandTimer
        interval: 200
        onTriggered: {
            if (!root.isMouseOverIsland) {
                root.showDynamicIsland = false
            }
        }
    }

    // Анимация карусели - плавный переход
    property real animProgress: 0  // 0 = начало, 1 = конец анимации
    
    NumberAnimation {
        id: carouselAnimation
        target: root
        property: "animProgress"
        from: 0
        to: 1
        duration: 350
        easing.type: Easing.OutCubic
        onFinished: {
            root.currentWallpaperIndex = root.slideDirection === 1 
                ? (root.currentWallpaperIndex + 1) % root.wallpaperList.length
                : (root.currentWallpaperIndex - 1 + root.wallpaperList.length) % root.wallpaperList.length
            root.isAnimating = false
            root.animProgress = 0
            root.slideDirection = 0
        }
    }

    function goToPrevWallpaper() {
        if (root.isAnimating || root.wallpaperList.length <= 1) return
        root.isAnimating = true
        root.slideDirection = -1
        root.animProgress = 0
        carouselAnimation.restart()
    }

    function goToNextWallpaper() {
        if (root.isAnimating || root.wallpaperList.length <= 1) return
        root.isAnimating = true
        root.slideDirection = 1
        root.animProgress = 0
        carouselAnimation.restart()
    }

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

    // ===== CPU монитор =====
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: cpuProcess.running = true
    }

    Process {
        id: cpuProcess
        command: ["sh", "-c", "grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf \"%.0f\", usage}'"]
        stdout: SplitParser {
            onRead: data => root.cpuUsage = parseInt(data.trim()) || 0
        }
    }

    // ===== Memory монитор =====
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: memProcess.running = true
    }

    Process {
        id: memProcess
        command: ["sh", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'"]
        stdout: SplitParser {
            onRead: data => root.memoryUsage = parseInt(data.trim()) || 0
        }
    }

    // ===== Battery монитор =====
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            batteryLevelProcess.running = true
            batteryStatusProcess.running = true
        }
    }

    Process {
        id: batteryLevelProcess
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1 || echo '100'"]
        stdout: SplitParser {
            onRead: data => root.batteryLevel = parseInt(data.trim()) || 100
        }
    }

    Process {
        id: batteryStatusProcess
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1 || echo 'Full'"]
        stdout: SplitParser {
            onRead: data => root.batteryCharging = data.trim() === "Charging"
        }
    }

    // ===== Brightness монитор =====
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (!root.brightnessUserChanging) {
                brightnessProcess.running = true
            }
        }
    }

    Process {
        id: brightnessProcess
        command: ["sh", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.brightnessUserChanging) {
                    root.brightness = parseInt(data.trim()) || 50
                }
            }
        }
    }

    Process {
        id: brightnessChangeProcess
        property int targetBrightness: 50
        command: ["brightnessctl", "set", targetBrightness + "%"]
    }

    // ===== Volume монитор =====
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            if (!root.volumeUserChanging) volumeProcess.running = true
            if (!root.micUserChanging) micProcess.running = true
        }
    }

    Process {
        id: volumeProcess
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}'"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.volumeUserChanging) {
                    root.volume = parseInt(data.trim()) || 0
                }
            }
        }
    }

    Process {
        id: micProcess
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print int($2*100)}'"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.micUserChanging) {
                    root.micVolume = parseInt(data.trim()) || 0
                }
            }
        }
    }

    Process {
        id: volumeChangeProcess
        property int targetVolume: 50
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (targetVolume / 100).toFixed(2)]
    }

    Process {
        id: micChangeProcess
        property int targetVolume: 50
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", (targetVolume / 100).toFixed(2)]
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
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device | grep connected | head -1"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(':')
                if (parts.length >= 3) {
                    if (parts[0] === "wifi") {
                        root.networkStatus = "wifi"
                        root.networkSSID = parts[2]
                    } else if (parts[0] === "ethernet") {
                        root.networkStatus = "ethernet"
                        root.networkSSID = parts[2]
                    }
                } else {
                    root.networkStatus = "disconnected"
                    root.networkSSID = ""
                }
            }
        }
    }

    // ===== Music Player Monitor =====
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            playerListProcess.running = true
        }
    }

    Process {
        id: playerListProcess
        command: ["playerctl", "-l"]
        stdout: SplitParser {
            onRead: data => {
                let players = data.trim().split('\n').filter(p => p.length > 0)
                root.availablePlayers = players
                
                if (players.length > 0) {
                    // Если есть заблокированный плеер и он ещё доступен - используе�� его
                    if (root.lockedPlayer && players.includes(root.lockedPlayer)) {
                        root.activePlayer = root.lockedPlayer
                    } else {
                        // Ищем активно играющий плеер
                        playerFindActiveProcess.running = true
                        return
                    }
                    playerMetadataProcess.running = true
                    playerStatusProcess.running = true
                } else {
                    root.activePlayer = ""
                    root.lockedPlayer = ""
                    root.musicTitle = "No Track Playing"
                    root.musicArtist = "Unknown Artist"
                    root.musicPlaying = false
                }
            }
        }
    }

    // Находим активно играющий плеер
    Process {
        id: playerFindActiveProcess
        command: ["sh", "-c", "playerctl -a status 2>/dev/null | paste - <(playerctl -l 2>/dev/null) | grep Playing | head -1 | awk '{print $2}'"]
        stdout: SplitParser {
            onRead: data => {
                let playingPlayer = data.trim()
                if (playingPlayer && root.availablePlayers.includes(playingPlayer)) {
                    root.activePlayer = playingPlayer
                    root.lockedPlayer = playingPlayer  // Запоминаем играющий плеер
                } else if (root.availablePlayers.length > 0) {
                    // Приоритет браузерным плеерам
                    let browserPlayer = root.availablePlayers.find(p => 
                        p.includes("firefox") || 
                        p.includes("chromium") || 
                        p.includes("chrome") ||
                        p.includes("yandex") ||
                        p.includes("brave") ||
                        p.includes("opera") ||
                        p.includes("vivaldi") ||
                        p.includes("edge")
                    )
                    root.activePlayer = browserPlayer || root.availablePlayers[0]
                    if (!root.lockedPlayer) {
                        root.lockedPlayer = root.activePlayer
                    }
                }
                playerMetadataProcess.running = true
                playerStatusProcess.running = true
            }
        }
    }

    Process {
        id: playerMetadataProcess
        command: ["sh", "-c", root.activePlayer ? 
            "playerctl -p '" + root.activePlayer + "' metadata --format '{{title}}|||{{artist}}|||{{album}}|||{{mpris:artUrl}}' 2>/dev/null" : 
            "echo ''"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split('|||')
                if (parts.length >= 1 && parts[0]) {
                    root.musicTitle = parts[0] || "No Track Playing"
                    root.musicArtist = parts[1] || "Unknown Artist"
                    root.musicAlbum = parts[2] || ""
                    root.musicArtUrl = parts[3] || ""
                }
            }
        }
    }

    Process {
        id: playerStatusProcess
        command: ["sh", "-c", root.activePlayer ? 
            "playerctl -p '" + root.activePlayer + "' status 2>/dev/null" : 
            "echo 'Stopped'"]
        stdout: SplitParser {
            onRead: data => {
                let status = data.trim()
                root.musicPlaying = (status === "Playing")
                
                // Если текущий плеер остановлен, ищем другой играющий
                if (status === "Stopped" && root.availablePlayers.length > 1) {
                    root.lockedPlayer = ""  // Сбрасываем блокировку
                }
            }
        }
    }

    Process {
        id: playerPlayPauseProcess
        command: ["sh", "-c", root.activePlayer ? 
            "playerctl -p '" + root.activePlayer + "' play-pause" : 
            "playerctl play-pause"]
    }

    Process {
        id: playerNextProcess
        command: ["sh", "-c", root.activePlayer ? 
            "playerctl -p '" + root.activePlayer + "' next" : 
            "playerctl next"]
    }

    Process {
        id: playerPreviousProcess
        command: ["sh", "-c", root.activePlayer ? 
            "playerctl -p '" + root.activePlayer + "' previous" : 
            "playerctl previous"]
    }

    // ===== Wallpaper Scanner =====
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.wallpaperBuffer = ""
            wallpaperScanProcess.running = true
        }
    }

    Process {
        id: wallpaperScanProcess
        command: ["sh", "-c", "find $HOME/Pictures/Wallpapers -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \\) 2>/dev/null | sort | head -100"]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim()) {
                    root.wallpaperBuffer += data.trim() + "\n"
                }
            }
        }
        
        onRunningChanged: {
            if (!running && wallpaperBuffer.length > 0) {
                let lines = wallpaperBuffer.trim().split('\n').filter(x => x.trim() !== '')
                if (lines.length > 0) {
                    root.wallpaperList = lines
                }
                root.wallpaperBuffer = ""
            }
        }
    }

    Process {
        id: swwwSetWallpaperProcess
        property string wallpaperPath: ""
        command: ["swww", "img", wallpaperPath, "--transition-type", "fade", "--transition-duration", "1"]
    }

    // ===== WiFi Scanner =====
    Process {
        id: wifiScanProcess
        command: ["sh", "-c", "nmcli -t -f SSID,SIGNAL,SECURITY,ACTIVE device wifi list 2>/dev/null | head -20"]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim()) {
                    root.wifiBuffer += data.trim() + "\n"
                }
            }
        }
        
        onRunningChanged: {
            if (!running) {
                let lines = root.wifiBuffer.trim().split('\n').filter(x => x.trim() !== '')
                let networks = []
                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].split(':')
                    if (parts.length >= 3 && parts[0]) {
                        networks.push({
                            ssid: parts[0],
                            signal: parseInt(parts[1]) || 0,
                            secured: parts[2] !== "" && parts[2] !== "--",
                            connected: parts[3] === "yes"
                        })
                    }
                }
                root.wifiNetworks = networks
                root.wifiBuffer = ""
                root.wifiScanning = false
            }
        }
    }

    function scanWifi() {
        if (root.wifiScanning) return
        root.wifiScanning = true
        root.wifiBuffer = ""
        wifiScanProcess.running = true
    }

    Process {
        id: wifiConnectProcess
        property string ssid: ""
        command: ["nmcli", "device", "wifi", "connect", ssid]
    }

    Process {
        id: wifiDisconnectProcess
        command: ["nmcli", "device", "disconnect", "wlan0"]
    }

    // ===== Bluetooth Scanner =====
    Process {
        id: btScanProcess
        command: ["sh", "-c", "bluetoothctl devices | while read -r line; do mac=$(echo $line | awk '{print $2}'); name=$(echo $line | cut -d' ' -f3-); info=$(bluetoothctl info $mac 2>/dev/null); connected=$(echo \"$info\" | grep -q 'Connected: yes' && echo 'yes' || echo 'no'); icon=$(echo \"$info\" | grep 'Icon:' | awk '{print $2}'); echo \"$name|$mac|$connected|$icon\"; done 2>/dev/null | head -15"]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim()) {
                    root.btBuffer += data.trim() + "\n"
                }
            }
        }
        
        onRunningChanged: {
            if (!running) {
                let lines = root.btBuffer.trim().split('\n').filter(x => x.trim() !== '')
                let devices = []
                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].split('|')
                    if (parts.length >= 3 && parts[0]) {
                        let deviceType = "other"
                        if (parts[3]) {
                            if (parts[3].includes("audio") || parts[3].includes("headset") || parts[3].includes("headphone")) {
                                deviceType = "audio"
                            } else if (parts[3].includes("input") || parts[3].includes("mouse") || parts[3].includes("keyboard")) {
                                deviceType = "input"
                            } else if (parts[3].includes("phone")) {
                                deviceType = "phone"
                            }
                        }
                        devices.push({
                            name: parts[0],
                            mac: parts[1],
                            connected: parts[2] === "yes",
                            type: deviceType
                        })
                    }
                }
                root.bluetoothDevices = devices
                root.btBuffer = ""
                root.btScanning = false
            }
        }
    }

    function scanBluetooth() {
        if (root.btScanning) return
        root.btScanning = true
        root.btBuffer = ""
        btScanProcess.running = true
    }

    Process {
        id: btConnectProcess
        property string mac: ""
        command: ["bluetoothctl", "connect", mac]
    }

    Process {
        id: btDisconnectProcess
        property string mac: ""
        command: ["bluetoothctl", "disconnect", mac]
    }

    // Initial network scan timer
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.showDynamicIsland && root.currentNetworkTab === 0) {
                root.scanWifi()
            } else if (root.showDynamicIsland && root.currentNetworkTab === 1) {
                root.scanBluetooth()
            }
        }
    }

    Component.onCompleted: {
        networkProcess.running = true
        langProcess.running = true
        batteryLevelProcess.running = true
        batteryStatusProcess.running = true
        brightnessProcess.running = true
        wallpaperScanProcess.running = true
        playerListProcess.running = true
        scanWifi()
        scanBluetooth()
    }

    Variants {
        model: Quickshell.screens
        
        delegate: Component {
            Item {
                property var modelData

                // ===== DYNAMIC ISLAND WINDOW =====
                PanelWindow {
                    id: dynamicIsland
                    screen: modelData
                    visible: root.showDynamicIsland && modelData.name === "DP-1"
                    
                    anchors {
                        top: true
                        left: true
                    }
                    
                    margins {
                        top: 3
                        left: (modelData.width - 940) / 2
                    }
                    
                    width: 940
                    height: 550
                    
                    color: "transparent"
                    focusable: true
                    exclusionMode: ExclusionMode.Ignore
                    
                    Item {
                        anchors.fill: parent
                        focus: true
                        Keys.onEscapePressed: root.closeIsland()
                    }
                    
                    Rectangle {
                        id: islandBackground
                        anchors.fill: parent
                        color: root.colorBgPrimary
                        radius: 15
                        
                        // Hover tracking
                        HoverHandler {
                            id: islandHoverHandler
                            onHoveredChanged: {
                                if (hovered) {
                                    root.isMouseOverIsland = true
                                    hideIslandTimer.stop()
                                } else {
                                    root.isMouseOverIsland = false
                                    hideIslandTimer.restart()
                                }
                            }
                        }
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 15
                            
                            // Tab selector
                            Row {
                                id: tabRow
                                width: parent.width
                                height: 40
                                spacing: 10
                                
                                property int currentTab: 0
                                
                                Repeater {
                                    model: ["Dashboard", "Wallpapers", "Network"]
                                    
                                    Rectangle {
                                        width: (tabRow.width - 20) / 3
                                        height: 40
                                        radius: 8
                                        color: tabRow.currentTab === index ? root.colorBgWorkspaceActive : 
                                               tabMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.15) : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                        
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: tabRow.currentTab === index ? root.colorTextWorkspaceActive : root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                        }
                                        
                                        MouseArea {
                                            id: tabMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: tabRow.currentTab = index
                                        }
                                    }
                                }
                            }
                            
                            // Content area
                            Item {
                                width: parent.width
                                height: parent.height - 55
                                
                                // ===== DASHBOARD TAB =====
                                Item {
                                    anchors.fill: parent
                                    visible: tabRow.currentTab === 0
                                    
                                    Column {
                                        anchors.fill: parent
                                        spacing: 15
                                        
                                        // Music Player
                                        Rectangle {
                                            width: parent.width
                                            height: 100
                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                            radius: 10
                                            
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 15
                                                spacing: 15
                                                
                                                // Album Art
                                                Rectangle {
                                                    width: 70
                                                    height: 70
                                                    radius: 8
                                                    color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                    clip: true
                                                    
                                                    Image {
                                                        anchors.fill: parent
                                                        source: root.musicArtUrl
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        visible: status === Image.Ready
                                                    }
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf001"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 30
                                                        color: root.colorTextSecondary
                                                        opacity: 0.3
                                                        visible: root.musicArtUrl === "" || parent.children[0].status !== Image.Ready
                                                    }
                                                }
                                                
                                                // Track Info + Controls
                                                Item {
                                                    width: parent.width - 85
                                                    height: 70
                                                    
                                                    // Track Info (слева)
                                                    Column {
                                                        anchors.left: parent.left
                                                        anchors.right: controlsRow.left
                                                        anchors.rightMargin: 15
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 4
                                                        
                                                        Text {
                                                            text: root.musicTitle
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 16
                                                            font.weight: Font.Bold
                                                            elide: Text.ElideRight
                                                            width: parent.width
                                                        }
                                                        
                                                        Text {
                                                            text: root.musicArtist
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                            opacity: 0.7
                                                            elide: Text.ElideRight
                                                            width: parent.width
                                                        }
                                                        
                                                        Text {
                                                            text: root.activePlayer ? "♪ " + root.activePlayer : ""
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 10
                                                            opacity: 0.5
                                                            elide: Text.ElideRight
                                                            width: parent.width
                                                        }
                                                    }
                                                    
                                                    // Controls (по центру справа)
                                                    Row {
                                                        id: controlsRow
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 8
                                                        
                                                        // Previous
                                                        Rectangle {
                                                            width: 38
                                                            height: 38
                                                            radius: 19
                                                            color: prevMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.2) : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                            
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                            
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "\uf048"
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 14
                                                                color: root.colorTextSecondary
                                                            }
                                                            
                                                            MouseArea {
                                                                id: prevMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: playerPreviousProcess.running = true
                                                            }
                                                        }
                                                        
                                                        // Play/Pause
                                                        Rectangle {
                                                            width: 46
                                                            height: 46
                                                            radius: 23
                                                            color: playPauseMouse.containsMouse ? Qt.lighter(root.colorBgWorkspaceActive, 1.1) : root.colorBgWorkspaceActive
                                                            
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                            
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: root.musicPlaying ? "\uf04c" : "\uf04b"
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 18
                                                                color: root.colorTextWorkspaceActive
                                                            }
                                                            
                                                            MouseArea {
                                                                id: playPauseMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: playerPlayPauseProcess.running = true
                                                            }
                                                        }
                                                        
                                                        // Next
                                                        Rectangle {
                                                            width: 38
                                                            height: 38
                                                            radius: 19
                                                            color: nextMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.2) : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                            
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                            
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "\uf051"
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 14
                                                                color: root.colorTextSecondary
                                                            }
                                                            
                                                            MouseArea {
                                                                id: nextMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: playerNextProcess.running = true
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Stats Row
                                        Row {
                                            width: parent.width
                                            height: 60
                                            spacing: 10
                                            
                                            // CPU
                                            Rectangle {
                                                width: (parent.width - 20) / 3
                                                height: 60
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: 10
                                                
                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 5
                                                    
                                                    Row {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        spacing: 6
                                                        
                                                        Text {
                                                            text: "\uf2db"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 14
                                                        }
                                                        Text {
                                                            text: "CPU"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: root.cpuUsage + "%"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }
                                            
                                            // RAM
                                            Rectangle {
                                                width: (parent.width - 20) / 3
                                                height: 60
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: 10
                                                
                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 5
                                                    
                                                    Row {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        spacing: 6
                                                        
                                                        Text {
                                                            text: "\uefc5"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 15
                                                        }
                                                        Text {
                                                            text: "RAM"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: root.memoryUsage + "%"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }
                                            
                                            // Battery
                                            Rectangle {
                                                width: (parent.width - 20) / 3
                                                height: 60
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: 10
                                                
                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 5
                                                    
                                                    Row {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        spacing: 6
                                                        
                                                        Text {
                                                            text: root.batteryCharging ? "\uf0e7" : (root.batteryLevel > 80 ? "\uf240" : root.batteryLevel > 60 ? "\uf241" : root.batteryLevel > 40 ? "\uf242" : root.batteryLevel > 20 ? "\uf243" : "\uf244")
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 14
                                                        }
                                                        Text {
                                                            text: "Battery"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: root.batteryLevel + "%"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Sliders
                                        Column {
                                            width: parent.width
                                            spacing: 12
                                            
                                            // Brightness Slider
                                            Row {
                                                width: parent.width
                                                spacing: 15
                                                height: 30
                                                
                                                Text {
                                                    text: "\uf185"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    color: root.colorTextSecondary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 20
                                                }
                                                
                                                Item {
                                                    width: parent.width - 85
                                                    height: 30
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: parent.width
                                                        height: 6
                                                        color: Qt.rgba(220/255, 215/255, 186/255, 0.2)
                                                        radius: 3
                                                        
                                                        Rectangle {
                                                            width: (root.brightness / 100) * parent.width
                                                            height: parent.height
                                                            color: root.colorBgWorkspaceActive
                                                            radius: 3
                                                        }
                                                    }
                                                    
                                                    Rectangle {
                                                        id: brightnessHandle
                                                        x: (root.brightness / 100) * (parent.width - width)
                                                        y: (parent.height - height) / 2
                                                        width: 18
                                                        height: 18
                                                        radius: 9
                                                        color: root.colorBgWorkspaceActive
                                                        
                                                        Behavior on x { 
                                                            enabled: !brightnessMouseArea.pressed
                                                            NumberAnimation { duration: 100 } 
                                                        }
                                                    }
                                                    
                                                    MouseArea {
                                                        id: brightnessMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        
                                                        onPressed: {
                                                            root.brightnessUserChanging = true
                                                            updateBrightness(mouse.x)
                                                        }
                                                        onPositionChanged: {
                                                            if (pressed) updateBrightness(mouse.x)
                                                        }
                                                        onReleased: {
                                                            root.brightnessUserChanging = false
                                                        }
                                                        
                                                        function updateBrightness(mouseX) {
                                                            let val = Math.max(0, Math.min(100, (mouseX / width) * 100))
                                                            root.brightness = Math.round(val)
                                                            brightnessChangeProcess.targetBrightness = root.brightness
                                                            brightnessChangeProcess.running = true
                                                        }
                                                    }
                                                }
                                                
                                                Text {
                                                    text: root.brightness + "%"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 13
                                                    color: root.colorTextSecondary
                                                    width: 45
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                            
                                            // Volume Slider
                                            Row {
                                                width: parent.width
                                                spacing: 15
                                                height: 30
                                                
                                                Text {
                                                    text: "\uf028"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    color: root.colorTextSecondary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 20
                                                }
                                                
                                                Item {
                                                    width: parent.width - 85
                                                    height: 30
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: parent.width
                                                        height: 6
                                                        color: Qt.rgba(220/255, 215/255, 186/255, 0.2)
                                                        radius: 3
                                                        
                                                        Rectangle {
                                                            width: (root.volume / 100) * parent.width
                                                            height: parent.height
                                                            color: root.colorBgWorkspaceActive
                                                            radius: 3
                                                        }
                                                    }
                                                    
                                                    Rectangle {
                                                        x: (root.volume / 100) * (parent.width - width)
                                                        y: (parent.height - height) / 2
                                                        width: 18
                                                        height: 18
                                                        radius: 9
                                                        color: root.colorBgWorkspaceActive
                                                        
                                                        Behavior on x { 
                                                            enabled: !volumeMouseArea.pressed
                                                            NumberAnimation { duration: 100 } 
                                                        }
                                                    }
                                                    
                                                    MouseArea {
                                                        id: volumeMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        
                                                        onPressed: {
                                                            root.volumeUserChanging = true
                                                            updateVolume(mouse.x)
                                                        }
                                                        onPositionChanged: {
                                                            if (pressed) updateVolume(mouse.x)
                                                        }
                                                        onReleased: {
                                                            root.volumeUserChanging = false
                                                        }
                                                        
                                                        function updateVolume(mouseX) {
                                                            let val = Math.max(0, Math.min(100, (mouseX / width) * 100))
                                                            root.volume = Math.round(val)
                                                            volumeChangeProcess.targetVolume = root.volume
                                                            volumeChangeProcess.running = true
                                                        }
                                                    }
                                                }
                                                
                                                Text {
                                                    text: root.volume + "%"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 13
                                                    color: root.colorTextSecondary
                                                    width: 45
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                            
                                            // Mic Slider
                                            Row {
                                                width: parent.width
                                                spacing: 15
                                                height: 30
                                                
                                                Text {
                                                    text: "\uf130"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    color: root.colorTextSecondary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 20
                                                }
                                                
                                                Item {
                                                    width: parent.width - 85
                                                    height: 30
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: parent.width
                                                        height: 6
                                                        color: Qt.rgba(220/255, 215/255, 186/255, 0.2)
                                                        radius: 3
                                                        
                                                        Rectangle {
                                                            width: (root.micVolume / 100) * parent.width
                                                            height: parent.height
                                                            color: root.colorBgWorkspaceActive
                                                            radius: 3
                                                        }
                                                    }
                                                    
                                                    Rectangle {
                                                        x: (root.micVolume / 100) * (parent.width - width)
                                                        y: (parent.height - height) / 2
                                                        width: 18
                                                        height: 18
                                                        radius: 9
                                                        color: root.colorBgWorkspaceActive
                                                        
                                                        Behavior on x { 
                                                            enabled: !micMouseArea.pressed
                                                            NumberAnimation { duration: 100 } 
                                                        }
                                                    }
                                                    
                                                    MouseArea {
                                                        id: micMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        
                                                        onPressed: {
                                                            root.micUserChanging = true
                                                            updateMic(mouse.x)
                                                        }
                                                        onPositionChanged: {
                                                            if (pressed) updateMic(mouse.x)
                                                        }
                                                        onReleased: {
                                                            root.micUserChanging = false
                                                        }
                                                        
                                                        function updateMic(mouseX) {
                                                            let val = Math.max(0, Math.min(100, (mouseX / width) * 100))
                                                            root.micVolume = Math.round(val)
                                                            micChangeProcess.targetVolume = root.micVolume
                                                            micChangeProcess.running = true
                                                        }
                                                    }
                                                }
                                                
                                                Text {
                                                    text: root.micVolume + "%"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 13
                                                    color: root.colorTextSecondary
                                                    width: 45
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                        }
                                        
                                        // Notifications
                                        Rectangle {
                                            width: parent.width
                                            height: 140
                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                            radius: 10
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 8
                                                
                                                Row {
                                                    width: parent.width
                                                    
                                                    Text {
                                                        text: "Notifications"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 14
                                                        font.weight: Font.Bold
                                                        width: parent.width - 90
                                                    }
                                                    
                                                    Rectangle {
                                                        width: 80
                                                        height: 24
                                                        radius: 5
                                                        color: clearAllMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.2) : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                        
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "Clear All"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 11
                                                        }
                                                        
                                                        MouseArea {
                                                            id: clearAllMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.notifications = []
                                                        }
                                                    }
                                                }
                                                
                                                Column {
                                                    width: parent.width
                                                    spacing: 6
                                                    
                                                    Repeater {
                                                        model: root.notifications.slice(0, 2)
                                                        
                                                        Rectangle {
                                                            width: parent.width
                                                            height: 40
                                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                            radius: 6
                                                            
                                                            Row {
                                                                anchors.fill: parent
                                                                anchors.margins: 8
                                                                spacing: 8
                                                                
                                                                Column {
                                                                    width: parent.width - 30
                                                                    spacing: 2
                                                                    
                                                                    Text {
                                                                        text: modelData.title
                                                                        color: root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 12
                                                                        font.weight: Font.Medium
                                                                        elide: Text.ElideRight
                                                                        width: parent.width
                                                                    }
                                                                    
                                                                    Text {
                                                                        text: modelData.body
                                                                        color: root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 10
                                                                        opacity: 0.6
                                                                        elide: Text.ElideRight
                                                                        width: parent.width
                                                                    }
                                                                }
                                                                
                                                                Text {
                                                                    text: "\uf00d"
                                                                    color: root.colorTextSecondary
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 12
                                                                    opacity: 0.5
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    
                                                                    MouseArea {
                                                                        anchors.fill: parent
                                                                        anchors.margins: -5
                                                                        hoverEnabled: true
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: {
                                                                            let newNotifs = []
                                                                            for (let i = 0; i < root.notifications.length; i++) {
                                                                                if (root.notifications[i].id !== modelData.id) {
                                                                                    newNotifs.push(root.notifications[i])
                                                                                }
                                                                            }
                                                                            root.notifications = newNotifs
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
                                }
                                
                                // ===== WALLPAPERS TAB =====
                                Item {
                                    anchors.fill: parent
                                    visible: tabRow.currentTab === 1
                                    
                                    Column {
                                        anchors.fill: parent
                                        spacing: 15
                                        
                                        // Carousel Container
                                        Item {
                                            id: carouselContainer
                                            width: parent.width
                                            height: 340
                                            clip: true
                                            
                                            property real centerX: width / 2
                                            property real centerY: height / 2
                                            
                                            // Размеры
                                            property real bigW: 500
                                            property real bigH: 300
                                            property real smallW: 150
                                            property real smallH: 100
                                            property real sideOffset: 30
                                            
                                            // Scroll на всём контейнере
                                            MouseArea {
                                                anchors.fill: parent
                                                z: -1
                                                onWheel: wheel => {
                                                    if (wheel.angleDelta.y > 0) {
                                                        root.goToPrevWallpaper()
                                                    } else {
                                                        root.goToNextWallpaper()
                                                    }
                                                }
                                            }
                                            
                                            // ===== ЛЕВОЕ ПРЕВЬЮ =====
                                            Rectangle {
                                                id: leftPreview
                                                
                                                property real targetW: root.isAnimating && root.slideDirection === -1 
                                                    ? (carouselContainer.smallW + (carouselContainer.bigW - carouselContainer.smallW) * root.animProgress)
                                                    : carouselContainer.smallW
                                                property real targetH: root.isAnimating && root.slideDirection === -1 
                                                    ? (carouselContainer.smallH + (carouselContainer.bigH - carouselContainer.smallH) * root.animProgress)
                                                    : carouselContainer.smallH
                                                property real targetX: root.isAnimating && root.slideDirection === -1 
                                                    ? (carouselContainer.sideOffset + (carouselContainer.centerX - carouselContainer.bigW/2 - carouselContainer.sideOffset) * root.animProgress)
                                                    : carouselContainer.sideOffset
                                                
                                                width: targetW
                                                height: targetH
                                                x: targetX
                                                y: carouselContainer.centerY - height/2
                                                
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: root.isAnimating && root.slideDirection === -1 ? (8 + 4 * root.animProgress) : 8
                                                clip: true
                                                visible: root.wallpaperList.length > 1
                                                z: root.isAnimating && root.slideDirection === -1 ? 10 : 1
                                                
                                                opacity: leftMouse.containsMouse ? 1.0 : 
                                                    (root.isAnimating && root.slideDirection === -1 ? (0.6 + 0.4 * root.animProgress) : 0.6)
                                                scale: leftMouse.containsMouse && !root.isAnimating ? 1.05 : 1.0
                                                
                                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                                Behavior on scale { NumberAnimation { duration: 150 } }
                                                
                                                Image {
                                                    anchors.fill: parent
                                                    source: {
                                                        if (root.wallpaperList.length <= 1) return ""
                                                        let idx = (root.currentWallpaperIndex - 1 + root.wallpaperList.length) % root.wallpaperList.length
                                                        return "file://" + root.wallpaperList[idx]
                                                    }
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: true
                                                }
                                                
                                                MouseArea {
                                                    id: leftMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.goToPrevWallpaper()
                                                }
                                            }
                                            
                                            // ===== ЦЕНТРАЛЬНОЕ ИЗОБРАЖЕНИЕ =====
                                            Rectangle {
                                                id: centerWallpaper
                                                
                                                property real targetW: root.isAnimating 
                                                    ? (carouselContainer.bigW - (carouselContainer.bigW - carouselContainer.smallW) * root.animProgress)
                                                    : carouselContainer.bigW
                                                property real targetH: root.isAnimating 
                                                    ? (carouselContainer.bigH - (carouselContainer.bigH - carouselContainer.smallH) * root.animProgress)
                                                    : carouselContainer.bigH
                                                property real targetX: root.isAnimating 
                                                    ? (root.slideDirection === 1 
                                                        ? (carouselContainer.centerX - carouselContainer.bigW/2 + (carouselContainer.sideOffset - carouselContainer.centerX + carouselContainer.bigW/2) * root.animProgress)
                                                        : (carouselContainer.centerX - carouselContainer.bigW/2 + (carouselContainer.width - carouselContainer.sideOffset - carouselContainer.smallW - carouselContainer.centerX + carouselContainer.bigW/2) * root.animProgress))
                                                    : (carouselContainer.centerX - carouselContainer.bigW/2)
                                                
                                                width: targetW
                                                height: targetH
                                                x: targetX
                                                y: carouselContainer.centerY - height/2
                                                
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: root.isAnimating ? (12 - 4 * root.animProgress) : 12
                                                clip: true
                                                z: root.isAnimating ? 1 : 10
                                                
                                                opacity: root.isAnimating ? (1.0 - 0.4 * root.animProgress) : 1.0
                                                
                                                Image {
                                                    anchors.fill: parent
                                                    source: root.wallpaperList.length > 0 ? ("file://" + root.wallpaperList[root.currentWallpaperIndex]) : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: true
                                                }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "No wallpapers found\n\nAdd images to:\n~/Pictures/Wallpapers"
                                                    color: root.colorTextSecondary
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 14
                                                    opacity: 0.5
                                                    horizontalAlignment: Text.AlignHCenter
                                                    visible: root.wallpaperList.length === 0 && !root.isAnimating
                                                }
                                            }
                                            
                                            // ===== ПРАВОЕ ПРЕВЬЮ =====
                                            Rectangle {
                                                id: rightPreview
                                                
                                                property real targetW: root.isAnimating && root.slideDirection === 1 
                                                    ? (carouselContainer.smallW + (carouselContainer.bigW - carouselContainer.smallW) * root.animProgress)
                                                    : carouselContainer.smallW
                                                property real targetH: root.isAnimating && root.slideDirection === 1 
                                                    ? (carouselContainer.smallH + (carouselContainer.bigH - carouselContainer.smallH) * root.animProgress)
                                                    : carouselContainer.smallH
                                                property real targetX: root.isAnimating && root.slideDirection === 1 
                                                    ? (carouselContainer.width - carouselContainer.sideOffset - carouselContainer.smallW - (carouselContainer.width - carouselContainer.sideOffset - carouselContainer.smallW - carouselContainer.centerX + carouselContainer.bigW/2) * root.animProgress)
                                                    : (carouselContainer.width - carouselContainer.sideOffset - carouselContainer.smallW)
                                                
                                                width: targetW
                                                height: targetH
                                                x: targetX
                                                y: carouselContainer.centerY - height/2
                                                
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: root.isAnimating && root.slideDirection === 1 ? (8 + 4 * root.animProgress) : 8
                                                clip: true
                                                visible: root.wallpaperList.length > 1
                                                z: root.isAnimating && root.slideDirection === 1 ? 10 : 1
                                                
                                                opacity: rightMouse.containsMouse ? 1.0 : 
                                                    (root.isAnimating && root.slideDirection === 1 ? (0.6 + 0.4 * root.animProgress) : 0.6)
                                                scale: rightMouse.containsMouse && !root.isAnimating ? 1.05 : 1.0
                                                
                                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                                Behavior on scale { NumberAnimation { duration: 150 } }
                                                
                                                Image {
                                                    anchors.fill: parent
                                                    source: {
                                                        if (root.wallpaperList.length <= 1) return ""
                                                        let idx = (root.currentWallpaperIndex + 1) % root.wallpaperList.length
                                                        return "file://" + root.wallpaperList[idx]
                                                    }
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: true
                                                }
                                                
                                                MouseArea {
                                                    id: rightMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.goToNextWallpaper()
                                                }
                                            }
                                            
                                            // ===== ЛЕВАЯ СТРЕЛКА =====
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 190
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 40
                                                height: 40
                                                radius: 20
                                                color: leftArrowMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(220/255, 215/255, 186/255, 0.15)
                                                visible: root.wallpaperList.length > 1
                                                z: 20
                                                
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf053"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    color: root.colorTextSecondary
                                                }
                                                
                                                MouseArea {
                                                    id: leftArrowMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.goToPrevWallpaper()
                                                }
                                            }
                                            
                                            // ===== ПРАВАЯ СТРЕЛКА =====
                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 190
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 40
                                                height: 40
                                                radius: 20
                                                color: rightArrowMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(220/255, 215/255, 186/255, 0.15)
                                                visible: root.wallpaperList.length > 1
                                                z: 20
                                                
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf054"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    color: root.colorTextSecondary
                                                }
                                                
                                                MouseArea {
                                                    id: rightArrowMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.goToNextWallpaper()
                                                }
                                            }
                                        }
                                        
                                        // Counter and Button
                                        Column {
                                            width: parent.width
                                            spacing: 12
                                            
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: root.wallpaperList.length > 0 ? ((root.currentWallpaperIndex + 1) + " / " + root.wallpaperList.length) : "0 / 0"
                                                color: root.colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 14
                                                opacity: 0.7
                                            }
                                            
                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 200
                                                height: 45
                                                radius: 10
                                                color: setWallpaperMouse.containsMouse ? Qt.lighter(root.colorBgWorkspaceActive, 1.1) : root.colorBgWorkspaceActive
                                                
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Set as Wallpaper"
                                                    color: root.colorTextWorkspaceActive
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                }
                                                
                                                MouseArea {
                                                    id: setWallpaperMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.wallpaperList.length > 0) {
                                                            swwwSetWallpaperProcess.wallpaperPath = root.wallpaperList[root.currentWallpaperIndex]
                                                            swwwSetWallpaperProcess.running = true
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // ===== NETWORK TAB =====
                                Item {
                                    anchors.fill: parent
                                    visible: tabRow.currentTab === 2
                                    
                                    Column {
                                        anchors.fill: parent
                                        spacing: 15
                                        
                                        // WiFi / Bluetooth selector
                                        Row {
                                            width: parent.width
                                            height: 35
                                            spacing: 10
                                            
                                            Repeater {
                                                model: ["WiFi", "Bluetooth"]
                                                
                                                Rectangle {
                                                    width: (parent.width - 10) / 2
                                                    height: 35
                                                    radius: 8
                                                    color: root.currentNetworkTab === index ? root.colorBgWorkspaceActive : 
                                                           netTabMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.15) : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                    
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        color: root.currentNetworkTab === index ? root.colorTextWorkspaceActive : root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 13
                                                        font.weight: Font.Bold
                                                    }
                                                    
                                                    MouseArea {
                                                        id: netTabMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.currentNetworkTab = index
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // WiFi Panel
                                        Item {
                                            width: parent.width
                                            height: parent.height - 50
                                            visible: root.currentNetworkTab === 0
                                            
                                            Column {
                                                anchors.fill: parent
                                                spacing: 10
                                                
                                                Row {
                                                    width: parent.width
                                                    spacing: 10
                                                    
                                                    Text {
                                                        text: "WiFi Networks"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 14
                                                        font.weight: Font.Bold
                                                        width: parent.width - 110
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    
                                                    Rectangle {
                                                        width: 100
                                                        height: 30
                                                        radius: 6
                                                        color: wifiScanMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.2) : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                        
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        
                                                        Row {
                                                            anchors.centerIn: parent
                                                            spacing: 6
                                                            
                                                            Text {
                                                                text: root.wifiScanning ? "\uf110" : "\uf021"
                                                                color: root.colorTextSecondary
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 12
                                                                
                                                                RotationAnimation on rotation {
                                                                    running: root.wifiScanning
                                                                    from: 0
                                                                    to: 360
                                                                    duration: 1000
                                                                    loops: Animation.Infinite
                                                                }
                                                            }
                                                            
                                                            Text {
                                                                text: root.wifiScanning ? "Scanning" : "Scan"
                                                                color: root.colorTextSecondary
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 12
                                                            }
                                                        }
                                                        
                                                        MouseArea {
                                                            id: wifiScanMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.scanWifi()
                                                        }
                                                    }
                                                }
                                                
                                                // WiFi list with scroll
                                                Flickable {
                                                    width: parent.width
                                                    height: parent.height - 50
                                                    contentHeight: wifiColumn.height
                                                    clip: true
                                                    
                                                    Column {
                                                        id: wifiColumn
                                                        width: parent.width
                                                        spacing: 8
                                                        
                                                        Text {
                                                            text: root.wifiNetworks.length === 0 ? "No networks found. Click Scan to search." : ""
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                            opacity: 0.5
                                                            visible: root.wifiNetworks.length === 0
                                                            width: parent.width
                                                            horizontalAlignment: Text.AlignHCenter
                                                            topPadding: 20
                                                        }
                                                        
                                                        Repeater {
                                                            model: root.wifiNetworks
                                                            
                                                            Rectangle {
                                                                width: parent.width
                                                                height: 50
                                                                color: wifiItemMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.08) : Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                                radius: 8
                                                                
                                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                                
                                                                MouseArea {
                                                                    id: wifiItemMouse
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                }
                                                                
                                                                Row {
                                                                    anchors.fill: parent
                                                                    anchors.margins: 12
                                                                    spacing: 12
                                                                    
                                                                    Text {
                                                                        text: {
                                                                            if (modelData.signal >= 80) return "\uf1eb"
                                                                            if (modelData.signal >= 60) return "\uf1eb"
                                                                            if (modelData.signal >= 40) return "\uf1eb"
                                                                            return "\uf1eb"
                                                                        }
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 18
                                                                        color: modelData.connected ? "#4ade80" : root.colorTextSecondary
                                                                        opacity: modelData.signal >= 60 ? 1.0 : (modelData.signal >= 30 ? 0.7 : 0.4)
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                    }
                                                                    
                                                                    Column {
                                                                        width: parent.width - 150
                                                                        spacing: 3
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        
                                                                        Text {
                                                                            text: modelData.ssid || "<Hidden Network>"
                                                                            color: root.colorTextSecondary
                                                                            font.family: "JetBrainsMono Nerd Font"
                                                                            font.pixelSize: 13
                                                                            font.weight: modelData.connected ? Font.Bold : Font.Medium
                                                                            elide: Text.ElideRight
                                                                            width: parent.width
                                                                        }
                                                                        
                                                                        Row {
                                                                            spacing: 8
                                                                            
                                                                            Text {
                                                                                text: modelData.signal + "%"
                                                                                color: root.colorTextSecondary
                                                                                font.family: "JetBrainsMono Nerd Font"
                                                                                font.pixelSize: 10
                                                                                opacity: 0.6
                                                                            }
                                                                            
                                                                            Text {
                                                                                text: modelData.secured ? "\uf023 Secured" : "\uf09c Open"
                                                                                color: root.colorTextSecondary
                                                                                font.family: "JetBrainsMono Nerd Font"
                                                                                font.pixelSize: 10
                                                                                opacity: 0.6
                                                                            }
                                                                        }
                                                                    }
                                                                    
                                                                    Rectangle {
                                                                        width: 85
                                                                        height: 28
                                                                        radius: 6
                                                                        color: modelData.connected ? "#4ade80" : 
                                                                               wifiConnectMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.2) : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        
                                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                                        
                                                                        Text {
                                                                            anchors.centerIn: parent
                                                                            text: modelData.connected ? "Disconnect" : "Connect"
                                                                            color: modelData.connected ? "#000000" : root.colorTextSecondary
                                                                            font.family: "JetBrainsMono Nerd Font"
                                                                            font.pixelSize: 11
                                                                            font.weight: Font.Medium
                                                                        }
                                                                        
                                                                        MouseArea {
                                                                            id: wifiConnectMouse
                                                                            anchors.fill: parent
                                                                            hoverEnabled: true
                                                                            cursorShape: Qt.PointingHandCursor
                                                                            onClicked: {
                                                                                if (modelData.connected) {
                                                                                    wifiDisconnectProcess.running = true
                                                                                } else {
                                                                                    wifiConnectProcess.ssid = modelData.ssid
                                                                                    wifiConnectProcess.running = true
                                                                                }
                                                                                // Refresh after connection attempt
                                                                                Qt.callLater(function() {
                                                                                    root.scanWifi()
                                                                                })
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
                                        
                                        // Bluetooth Panel
                                        Item {
                                            width: parent.width
                                            height: parent.height - 50
                                            visible: root.currentNetworkTab === 1
                                            
                                            Column {
                                                anchors.fill: parent
                                                spacing: 10
                                                
                                                Row {
                                                    width: parent.width
                                                    spacing: 10
                                                    
                                                    Text {
                                                        text: "Bluetooth Devices"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 14
                                                        font.weight: Font.Bold
                                                        width: parent.width - 110
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    
                                                    Rectangle {
                                                        width: 100
                                                        height: 30
                                                        radius: 6
                                                        color: btScanMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.2) : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                        
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        
                                                        Row {
                                                            anchors.centerIn: parent
                                                            spacing: 6
                                                            
                                                            Text {
                                                                text: root.btScanning ? "\uf110" : "\uf021"
                                                                color: root.colorTextSecondary
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 12
                                                                
                                                                RotationAnimation on rotation {
                                                                    running: root.btScanning
                                                                    from: 0
                                                                    to: 360
                                                                    duration: 1000
                                                                    loops: Animation.Infinite
                                                                }
                                                            }
                                                            
                                                            Text {
                                                                text: root.btScanning ? "Scanning" : "Scan"
                                                                color: root.colorTextSecondary
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 12
                                                            }
                                                        }
                                                        
                                                        MouseArea {
                                                            id: btScanMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.scanBluetooth()
                                                        }
                                                    }
                                                }
                                                
                                                // Bluetooth list with scroll
                                                Flickable {
                                                    width: parent.width
                                                    height: parent.height - 50
                                                    contentHeight: btColumn.height
                                                    clip: true
                                                    
                                                    Column {
                                                        id: btColumn
                                                        width: parent.width
                                                        spacing: 8
                                                        
                                                        Text {
                                                            text: root.bluetoothDevices.length === 0 ? "No paired devices found.\nPair devices via bluetoothctl first." : ""
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                            opacity: 0.5
                                                            visible: root.bluetoothDevices.length === 0
                                                            width: parent.width
                                                            horizontalAlignment: Text.AlignHCenter
                                                            topPadding: 20
                                                        }
                                                        
                                                        Repeater {
                                                            model: root.bluetoothDevices
                                                            
                                                            Rectangle {
                                                                width: parent.width
                                                                height: 50
                                                                color: btItemMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.08) : Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                                radius: 8
                                                                
                                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                                
                                                                MouseArea {
                                                                    id: btItemMouse
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                }
                                                                
                                                                Row {
                                                                    anchors.fill: parent
                                                                    anchors.margins: 12
                                                                    spacing: 12
                                                                    
                                                                    Text {
                                                                        text: {
                                                                            if (modelData.type === "audio") return "\uf025"
                                                                            if (modelData.type === "input") return "\uf11b"
                                                                            if (modelData.type === "phone") return "\uf10b"
                                                                            return "\uf294"  // Bluetooth icon
                                                                        }
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 18
                                                                        color: modelData.connected ? "#4ade80" : root.colorTextSecondary
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                    }
                                                                    
                                                                    Column {
                                                                        width: parent.width - 150
                                                                        spacing: 3
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        
                                                                        Text {
                                                                            text: modelData.name
                                                                            color: root.colorTextSecondary
                                                                            font.family: "JetBrainsMono Nerd Font"
                                                                            font.pixelSize: 13
                                                                            font.weight: modelData.connected ? Font.Bold : Font.Medium
                                                                            elide: Text.ElideRight
                                                                            width: parent.width
                                                                        }
                                                                        
                                                                        Text {
                                                                            text: modelData.connected ? "Connected" : "Paired"
                                                                            color: modelData.connected ? "#4ade80" : root.colorTextSecondary
                                                                            font.family: "JetBrainsMono Nerd Font"
                                                                            font.pixelSize: 10
                                                                            opacity: modelData.connected ? 1.0 : 0.6
                                                                        }
                                                                    }
                                                                    
                                                                    Rectangle {
                                                                        width: 85
                                                                        height: 28
                                                                        radius: 6
                                                                        color: modelData.connected ? "#4ade80" : 
                                                                               btConnectMouse.containsMouse ? Qt.rgba(220/255, 215/255, 186/255, 0.2) : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        
                                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                                        
                                                                        Text {
                                                                            anchors.centerIn: parent
                                                                            text: modelData.connected ? "Disconnect" : "Connect"
                                                                            color: modelData.connected ? "#000000" : root.colorTextSecondary
                                                                            font.family: "JetBrainsMono Nerd Font"
                                                                            font.pixelSize: 11
                                                                            font.weight: Font.Medium
                                                                        }
                                                                        
                                                                        MouseArea {
                                                                            id: btConnectMouse
                                                                            anchors.fill: parent
                                                                            hoverEnabled: true
                                                                            cursorShape: Qt.PointingHandCursor
                                                                            onClicked: {
                                                                                if (modelData.connected) {
                                                                                    btDisconnectProcess.mac = modelData.mac
                                                                                    btDisconnectProcess.running = true
                                                                                } else {
                                                                                    btConnectProcess.mac = modelData.mac
                                                                                    btConnectProcess.running = true
                                                                                }
                                                                                // Refresh after connection attempt
                                                                                Qt.callLater(function() {
                                                                                    root.scanBluetooth()
                                                                                })
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
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== MAIN BAR WINDOW =====
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
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Hyprland.dispatch("workspace " + wsButton.wsNumber)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // CENTER - часы (ИСПРАВЛЕН ЦВЕТ)
                        Rectangle {
                            id: centerClock
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
                                    color: root.colorTextSecondary  // Правильный цвет
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                
                                Text {
                                    text: "\uf017"
                                    color: root.colorTextSecondary  // Правильный цвет
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                
                                Text {
                                    id: clockTime
                                    text: Qt.formatDateTime(new Date(), "HH:mm")
                                    color: root.colorTextSecondary  // Правильный цвет
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

                            HoverHandler {
                                id: clockHoverHandler
                                onHoveredChanged: {
                                    if (hovered) {
                                        root.isMouseOverIsland = true
                                        root.openIsland()
                                    } else {
                                        root.isMouseOverIsland = false
                                        hideIslandTimer.restart()
                                    }
                                }
                            }
                            
                            TapHandler {
                                onTapped: {
                                    if (root.showDynamicIsland) {
                                        root.closeIsland()
                                    }
                                }
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
                                    cursorShape: Qt.PointingHandCursor
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
                                        if (root.networkStatus === "ethernet") return "\uf796"
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
