import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    id: root

    // ===== ЦВЕТА (readonly для оптимизации) =====
    readonly property color colorBgPrimary: "#151515"
    readonly property color colorBgSecondary: "transparent"
    readonly property color colorBgWorkspaceActive: "#fff0f5"
    readonly property color colorBgWorkspaceHover: Qt.rgba(0, 0, 0, 0.2)
    readonly property color colorTextPrimary: "#ffffff"
    readonly property color colorTextSecondary: "#dcd7ba"
    readonly property color colorTextWorkspaceActive: "#000000"
    
    // Кэшированные цвета для частого использования
    readonly property color colorCardBg: Qt.rgba(0.863, 0.843, 0.729, 0.05)
    readonly property color colorCardBgHover: Qt.rgba(0.863, 0.843, 0.729, 0.08)
    readonly property color colorButtonBg: Qt.rgba(0.863, 0.843, 0.729, 0.1)
    readonly property color colorButtonBgHover: Qt.rgba(0.863, 0.843, 0.729, 0.2)
    readonly property color colorSliderBg: Qt.rgba(0.863, 0.843, 0.729, 0.2)
    readonly property color colorConnected: "#4ade80"

    // ===== СИСТЕМНЫЕ ДАННЫЕ =====
    property int cpuUsage: 0
    property int memoryUsage: 0
    property int volume: 50
    property int micVolume: 80
    property int brightness: 50
    property int batteryLevel: 100
    property bool batteryCharging: false
    property string networkStatus: "wifi"
    property string networkSSID: ""
    property string currentLanguage: "EN"

    // ===== DYNAMIC ISLAND =====
    property bool showDynamicIsland: false
    property bool isMouseOverIsland: false
    property int currentTab: 0
    
    // Анимация Island - простой progress от 0 до 1
    property real islandProgress: 0.0

    // ===== MUSIC PLAYER =====
    property string musicTitle: "No Track Playing"
    property string musicArtist: "Unknown Artist"
    property string musicArtUrl: ""
    property bool musicPlaying: false
    property string activePlayer: ""
    property var availablePlayers: []
    property int currentPlayerIndex: 0

    // ===== WALLPAPERS =====
    property var wallpaperList: []
    property int currentWallpaperIndex: 0
    property string wallpaperBuffer: ""
    property real animProgress: 0
    property bool isAnimating: false
    property int slideDirection: 0

    // ===== NOTIFICATIONS =====
    property var notifications: [
        { id: 1, title: "System Update", body: "New updates available", time: "5m ago" },
        { id: 2, title: "Battery Low", body: "15% remaining", time: "10m ago" }
    ]

    // ===== NETWORK =====
    property int currentNetworkTab: 0
    property var wifiNetworks: []
    property var bluetoothDevices: []
    property bool wifiScanning: false
    property bool btScanning: false
    property string wifiBuffer: ""
    property string btBuffer: ""

    // ===== USER INPUT FLAGS =====
    property bool brightnessUserChanging: false
    property bool volumeUserChanging: false
    property bool micUserChanging: false

    // ===== ФУНКЦИИ УПРАВЛЕНИЯ ISLAND =====
    function openIsland() {
        hideIslandTimer.stop()
        showDynamicIsland = true
    }

    function closeIsland() {
        showDynamicIsland = false
    }

    // ===== ФУНКЦИИ ПЛЕЕРА =====
    function switchToPlayer(index) {
        if (index >= 0 && index < availablePlayers.length) {
            currentPlayerIndex = index
            activePlayer = availablePlayers[index]
            playerMetadataProcess.running = true
            playerStatusProcess.running = true
        }
    }

    function nextPlayer() {
        if (availablePlayers.length > 1)
            switchToPlayer((currentPlayerIndex + 1) % availablePlayers.length)
    }

    function prevPlayer() {
        if (availablePlayers.length > 1)
            switchToPlayer((currentPlayerIndex - 1 + availablePlayers.length) % availablePlayers.length)
    }

    // ===== ФУНКЦИИ КАРУСЕЛИ =====
    function goToPrevWallpaper() {
        if (isAnimating || wallpaperList.length <= 1) return
        isAnimating = true
        slideDirection = -1
        animProgress = 0
        carouselAnimation.restart()
    }

    function goToNextWallpaper() {
        if (isAnimating || wallpaperList.length <= 1) return
        isAnimating = true
        slideDirection = 1
        animProgress = 0
        carouselAnimation.restart()
    }

    // ===== ФУНКЦИИ СЕТИ =====
    function scanWifi() {
        if (wifiScanning) return
        wifiScanning = true
        wifiBuffer = ""
        wifiScanProcess.running = true
    }

    function scanBluetooth() {
        if (btScanning) return
        btScanning = true
        btBuffer = ""
        btScanProcess.running = true
    }

    // ===== ТАЙМЕРЫ =====
    Timer {
        id: hideIslandTimer
        interval: 300
        onTriggered: if (!isMouseOverIsland) closeIsland()
    }

    // Быстрый таймер (300ms) - аудио, яркость
    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            if (!volumeUserChanging && !micUserChanging) audioProcess.running = true
            if (!brightnessUserChanging) brightnessProcess.running = true
        }
    }

    // Средний таймер (1.5s) - CPU, RAM, плеер, язык
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            systemStatsProcess.running = true
            playerListProcess.running = true
            langProcess.running = true
        }
    }

    // Медленный таймер (4s) - сеть, батарея
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: {
            batteryProcess.running = true
            networkProcess.running = true
        }
    }

    // Таймер для сканирования сетей (только когда Island открыт)
    Timer {
        interval: 5000
        running: showDynamicIsland && currentTab === 2
        repeat: true
        onTriggered: {
            if (currentNetworkTab === 0) scanWifi()
            else scanBluetooth()
        }
    }

    // Таймер обоев
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wallpaperBuffer = ""
            wallpaperScanProcess.running = true
        }
    }

    // Анимация карусели
    NumberAnimation {
        id: carouselAnimation
        target: root
        property: "animProgress"
        from: 0; to: 1
        duration: 350
        easing.type: Easing.OutCubic
        onFinished: {
            currentWallpaperIndex = slideDirection === 1 
                ? (currentWallpaperIndex + 1) % wallpaperList.length
                : (currentWallpaperIndex - 1 + wallpaperList.length) % wallpaperList.length
            isAnimating = false
            animProgress = 0
            slideDirection = 0
        }
    }

    // ===== ПРОЦЕССЫ =====
    
    // Язык
    Process {
        id: langProcess
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap'"]
        stdout: SplitParser {
            onRead: data => {
                let l = data.trim().toLowerCase()
                currentLanguage = l.includes("russian") || l.includes("ru") ? "RU" :
                                  l.includes("english") || l.includes("us") || l.includes("en") ? "EN" :
                                  l && l !== "null" ? l.substring(0, 2).toUpperCase() : "EN"
            }
        }
    }

    // CPU + RAM объединены
    Process {
        id: systemStatsProcess
        command: ["sh", "-c", "echo $(grep 'cpu ' /proc/stat | awk '{printf \"%.0f\", ($2+$4)*100/($2+$4+$5)}') $(free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}')"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(' ')
                if (parts.length >= 2) {
                    cpuUsage = parseInt(parts[0]) || 0
                    memoryUsage = parseInt(parts[1]) || 0
                }
            }
        }
    }

    // Батарея
    Process {
        id: batteryProcess
        command: ["sh", "-c", "echo $(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1 || echo '100') $(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1 || echo 'Full')"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(' ')
                batteryLevel = parseInt(parts[0]) || 100
                batteryCharging = parts[1] === "Charging"
            }
        }
    }

    // Яркость
    Process {
        id: brightnessProcess
        command: ["sh", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => { if (!brightnessUserChanging) brightness = parseInt(data.trim()) || 50 }
        }
    }

    Process {
        id: brightnessChangeProcess
        property int targetBrightness: 50
        command: ["brightnessctl", "set", targetBrightness + "%"]
    }

    // Громкость + Микрофон объединены
    Process {
        id: audioProcess
        command: ["sh", "-c", "echo $(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}') $(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print int($2*100)}')"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(' ')
                if (parts.length >= 2) {
                    if (!volumeUserChanging) volume = parseInt(parts[0]) || 0
                    if (!micUserChanging) micVolume = parseInt(parts[1]) || 0
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

    // Сеть
    Process {
        id: networkProcess
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device | grep connected | head -1"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(':')
                if (parts.length >= 3) {
                    networkStatus = parts[0] === "wifi" ? "wifi" : parts[0] === "ethernet" ? "ethernet" : "disconnected"
                    networkSSID = parts[2]
                } else {
                    networkStatus = "disconnected"
                    networkSSID = ""
                }
            }
        }
    }

    // ===== ПЛЕЕР =====
    Process {
        id: playerListProcess
        command: ["playerctl", "-l"]
        stdout: SplitParser {
            onRead: data => {
                let players = data.trim().split('\n').filter(p => p.length > 0)
                availablePlayers = players
                
                if (players.length > 0) {
                    if (currentPlayerIndex >= players.length) currentPlayerIndex = 0
                    if (activePlayer && players.includes(activePlayer)) {
                        currentPlayerIndex = players.indexOf(activePlayer)
                    } else {
                        activePlayer = players[currentPlayerIndex]
                    }
                    playerMetadataProcess.running = true
                    playerStatusProcess.running = true
                } else {
                    activePlayer = ""
                    currentPlayerIndex = 0
                    musicTitle = "No Track Playing"
                    musicArtist = "Unknown Artist"
                    musicPlaying = false
                }
            }
        }
    }

    Process {
        id: playerMetadataProcess
        command: ["sh", "-c", activePlayer ? 
            "playerctl -p '" + activePlayer + "' metadata --format '{{title}}|||{{artist}}|||{{mpris:artUrl}}' 2>/dev/null" : "echo ''"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split('|||')
                if (parts.length >= 1 && parts[0]) {
                    musicTitle = parts[0] || "No Track Playing"
                    musicArtist = parts[1] || "Unknown Artist"
                    musicArtUrl = parts[2] || ""
                }
            }
        }
    }

    Process {
        id: playerStatusProcess
        command: ["sh", "-c", activePlayer ? "playerctl -p '" + activePlayer + "' status 2>/dev/null" : "echo 'Stopped'"]
        stdout: SplitParser {
            onRead: data => { musicPlaying = data.trim() === "Playing" }
        }
    }

    Process {
        id: playerPlayPauseProcess
        command: ["sh", "-c", activePlayer ? "playerctl -p '" + activePlayer + "' play-pause" : "playerctl play-pause"]
    }

    Process {
        id: playerNextProcess
        command: ["sh", "-c", activePlayer ? "playerctl -p '" + activePlayer + "' next" : "playerctl next"]
    }

    Process {
        id: playerPreviousProcess
        command: ["sh", "-c", activePlayer ? "playerctl -p '" + activePlayer + "' previous" : "playerctl previous"]
    }

    // ===== ОБОИ =====
    Process {
        id: wallpaperScanProcess
        command: ["sh", "-c", "find $HOME/Pictures/Wallpapers -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \\) 2>/dev/null | sort | head -100"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data.trim()) wallpaperBuffer += data.trim() + "\n" }
        }
        onRunningChanged: {
            if (!running && wallpaperBuffer.length > 0) {
                let lines = wallpaperBuffer.trim().split('\n').filter(x => x.trim())
                if (lines.length > 0) wallpaperList = lines
                wallpaperBuffer = ""
            }
        }
    }

    Process {
        id: swwwSetWallpaperProcess
        property string wallpaperPath: ""
        command: ["swww", "img", wallpaperPath, "--transition-type", "fade", "--transition-duration", "2"]
    }

    // ===== WiFi =====
    Process {
        id: wifiScanProcess
        command: ["sh", "-c", "nmcli -t -f SSID,SIGNAL,SECURITY,ACTIVE device wifi list 2>/dev/null | head -20"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data.trim()) wifiBuffer += data.trim() + "\n" }
        }
        onRunningChanged: {
            if (!running) {
                let networks = []
                wifiBuffer.trim().split('\n').filter(x => x.trim()).forEach(line => {
                    let parts = line.split(':')
                    if (parts.length >= 3 && parts[0]) {
                        networks.push({
                            ssid: parts[0],
                            signal: parseInt(parts[1]) || 0,
                            secured: parts[2] !== "" && parts[2] !== "--",
                            connected: parts[3] === "yes"
                        })
                    }
                })
                wifiNetworks = networks
                wifiBuffer = ""
                wifiScanning = false
            }
        }
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

    // ===== Bluetooth =====
    Process {
        id: btScanProcess
        command: ["sh", "-c", "bluetoothctl devices | while read -r line; do mac=$(echo $line | awk '{print $2}'); name=$(echo $line | cut -d' ' -f3-); info=$(bluetoothctl info $mac 2>/dev/null); connected=$(echo \"$info\" | grep -q 'Connected: yes' && echo 'yes' || echo 'no'); icon=$(echo \"$info\" | grep 'Icon:' | awk '{print $2}'); echo \"$name|$mac|$connected|$icon\"; done 2>/dev/null | head -15"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data.trim()) btBuffer += data.trim() + "\n" }
        }
        onRunningChanged: {
            if (!running) {
                let devices = []
                btBuffer.trim().split('\n').filter(x => x.trim()).forEach(line => {
                    let parts = line.split('|')
                    if (parts.length >= 3 && parts[0]) {
                        let t = parts[3] || ""
                        devices.push({
                            name: parts[0],
                            mac: parts[1],
                            connected: parts[2] === "yes",
                            type: t.includes("audio") || t.includes("headset") ? "audio" :
                                  t.includes("input") || t.includes("mouse") ? "input" :
                                  t.includes("phone") ? "phone" : "other"
                        })
                    }
                })
                bluetoothDevices = devices
                btBuffer = ""
                btScanning = false
            }
        }
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

    // ===== КОМПОНЕНТЫ =====
    
    // Универсальная кнопка
    component IconButton: Rectangle {
        id: iconBtn
        property string icon: ""
        property real iconSize: 14
        property bool circular: true
        signal clicked()
        
        radius: circular ? width/2 : 6
        color: iconBtnMouse.containsMouse ? colorButtonBgHover : colorButtonBg
        Behavior on color { ColorAnimation { duration: 150 } }
        
        Text {
            anchors.centerIn: parent
            text: iconBtn.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: iconBtn.iconSize
            color: colorTextSecondary
        }
        
        MouseArea {
            id: iconBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconBtn.clicked()
        }
    }

    // Универсальный слайдер
    component CustomSlider: Row {
        id: sliderRow
        property string icon: ""
        property real sliderValue: 50
        property bool userChanging: false
        signal sliderMoved(real newValue)
        
        spacing: 15
        height: 30
        
        Text {
            text: sliderRow.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: colorTextSecondary
            anchors.verticalCenter: parent.verticalCenter
            width: 20
        }
        
        Item {
            width: sliderRow.width - 85
            height: 30
            anchors.verticalCenter: parent.verticalCenter
            
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 6
                color: colorSliderBg
                radius: 3
                
                Rectangle {
                    width: (sliderRow.sliderValue / 100) * parent.width
                    height: parent.height
                    color: colorBgWorkspaceActive
                    radius: 3
                }
            }
            
            Rectangle {
                x: (sliderRow.sliderValue / 100) * (parent.width - width)
                y: (parent.height - height) / 2
                width: 18; height: 18; radius: 9
                color: colorBgWorkspaceActive
                Behavior on x { enabled: !sliderMouse.pressed; NumberAnimation { duration: 100 } }
            }
            
            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                function updateValue(mouseX) {
                    let val = Math.max(0, Math.min(100, (mouseX / width) * 100))
                    sliderRow.sliderMoved(Math.round(val))
                }
                
                onPressed: updateValue(mouse.x)
                onPositionChanged: if (pressed) updateValue(mouse.x)
            }
        }
        
        Text {
            text: Math.round(sliderRow.sliderValue) + "%"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: colorTextSecondary
            width: 45
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
        }
    }

    // Карточка статистики
    component StatCard: Rectangle {
        property string icon: ""
        property string label: ""
        property string value: ""
        
        width: (parent.width - 20) / 3
        height: 60
        color: colorCardBg
        radius: 10
        
        Column {
            anchors.centerIn: parent
            spacing: 5
            
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Text {
                    text: icon
                    color: colorTextSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                }
                Text {
                    text: label
                    color: colorTextSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: value
                color: colorTextSecondary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                font.weight: Font.Bold
            }
        }
    }

    // Элемент списка сети
    component NetworkItem: Rectangle {
        id: netItem
        property string icon: ""
        property string name: ""
        property string subtitle: ""
        property bool isConnected: false
        signal connectClicked()
        
        width: parent.width
        height: 50
        color: netItemMouse.containsMouse ? colorCardBgHover : colorCardBg
        radius: 8
        Behavior on color { ColorAnimation { duration: 150 } }
        
        MouseArea { id: netItemMouse; anchors.fill: parent; hoverEnabled: true }
        
        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            
            Text {
                text: netItem.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: netItem.isConnected ? colorConnected : colorTextSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Column {
                width: parent.width - 150
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: netItem.name
                    color: colorTextSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: netItem.isConnected ? Font.Bold : Font.Medium
                    elide: Text.ElideRight
                    width: parent.width
                }
                
                Text {
                    text: netItem.subtitle
                    color: netItem.isConnected ? colorConnected : colorTextSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    opacity: netItem.isConnected ? 1.0 : 0.6
                }
            }
            
            Rectangle {
                width: 85; height: 28; radius: 6
                color: netItem.isConnected ? colorConnected : 
                       netConnectMouse.containsMouse ? colorButtonBgHover : colorButtonBg
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Text {
                    anchors.centerIn: parent
                    text: netItem.isConnected ? "Disconnect" : "Connect"
                    color: netItem.isConnected ? "#000000" : colorTextSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
                
                MouseArea {
                    id: netConnectMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: netItem.connectClicked()
                }
            }
        }
    }

    Component.onCompleted: {
        networkProcess.running = true
        batteryProcess.running = true
        systemStatsProcess.running = true
        scanWifi()
        scanBluetooth()
    }

    // ===== ЭКРАНЫ =====
    Variants {
        model: Quickshell.screens
        
        delegate: Component {
            Item {
                property var modelData

                // ===== DYNAMIC ISLAND =====
                PanelWindow {
                    id: dynamicIsland
                    screen: modelData
                    visible: showDynamicIsland && modelData.name === "DP-1"
                    
                    anchors { top: true; left: true }
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
                        Keys.onEscapePressed: closeIsland()
                    }
                    
                    // Контейнер с анимацией масштаба
                    Item {
                        id: islandScaleContainer
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: parent.width
                        height: parent.height
                        
                        // Трансформация от верхнего центра
                        transformOrigin: Item.Top
                        
                        // Плавная анимация scale
                        scale: islandProgress
                        opacity: islandProgress
                        
                        Behavior on scale {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Rectangle {
                            id: islandContainer
                            anchors.fill: parent
                            color: colorBgPrimary
                            radius: 15
                            clip: true
                            
                            HoverHandler {
                                onHoveredChanged: {
                                    isMouseOverIsland = hovered
                                    if (hovered) hideIslandTimer.stop()
                                    else hideIslandTimer.restart()
                                }
                            }
                            
                            Column {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 15
                                
                                // Табы
                                Row {
                                    id: tabRow
                                    width: parent.width; height: 40; spacing: 10
                                    
                                    Repeater {
                                        model: ["Dashboard", "Wallpapers", "Network"]
                                        
                                        Rectangle {
                                            width: (tabRow.width - 20) / 3; height: 40; radius: 8
                                            color: currentTab === index ? colorBgWorkspaceActive : 
                                                   tabMouse.containsMouse ? colorButtonBgHover : colorButtonBg
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: currentTab === index ? colorTextWorkspaceActive : colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                            }
                                            
                                            MouseArea {
                                                id: tabMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: currentTab = index
                                            }
                                        }
                                    }
                                }
                                
                                // Контент
                                Item {
                                    width: parent.width
                                    height: parent.height - 55
                                    
                                    // ===== DASHBOARD =====
                                    Loader {
                                        anchors.fill: parent
                                        active: currentTab === 0
                                        sourceComponent: Column {
                                            spacing: 15
                                            
                                            // Плеер
                                            Rectangle {
                                                width: parent.width; height: 100
                                                color: colorCardBg; radius: 10
                                                
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.margins: 12
                                                    spacing: 12
                                                    
                                                    // Обложка
                                                    Rectangle {
                                                        width: 76; height: 76; radius: 8
                                                        color: colorButtonBg
                                                        clip: true
                                                        
                                                        Image {
                                                            anchors.fill: parent
                                                            source: musicArtUrl
                                                            fillMode: Image.PreserveAspectCrop
                                                            asynchronous: true
                                                            cache: true
                                                            visible: status === Image.Ready
                                                        }
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf001"
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 30
                                                            color: colorTextSecondary
                                                            opacity: 0.3
                                                            visible: musicArtUrl === "" || parent.children[0].status !== Image.Ready
                                                        }
                                                    }
                                                    
                                                    // Инфо + Контролы
                                                    Column {
                                                        width: parent.width - 88
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 8
                                                        
                                                        // Название и исполнитель
                                                        Column {
                                                            width: parent.width
                                                            spacing: 2
                                                            
                                                            Text {
                                                                text: musicTitle
                                                                color: colorTextSecondary
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 15
                                                                font.weight: Font.Bold
                                                                elide: Text.ElideRight
                                                                width: parent.width
                                                            }
                                                            
                                                            Text {
                                                                text: musicArtist
                                                                color: colorTextSecondary
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 12
                                                                opacity: 0.7
                                                                elide: Text.ElideRight
                                                                width: parent.width
                                                            }
                                                        }
                                                        
                                                        // Контролы плеера
                                                        Row {
                                                            spacing: 8
                                                            
                                                            IconButton {
                                                                width: 36; height: 36
                                                                icon: "\uf048"
                                                                onClicked: playerPreviousProcess.running = true
                                                            }
                                                            
                                                            Rectangle {
                                                                width: 44; height: 44; radius: 22
                                                                color: playMouse.containsMouse ? Qt.lighter(colorBgWorkspaceActive, 1.1) : colorBgWorkspaceActive
                                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                                
                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: musicPlaying ? "\uf04c" : "\uf04b"
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 16
                                                                    color: colorTextWorkspaceActive
                                                                }
                                                                
                                                                MouseArea {
                                                                    id: playMouse
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: playerPlayPauseProcess.running = true
                                                                }
                                                            }
                                                            
                                                            IconButton {
                                                                width: 36; height: 36
                                                                icon: "\uf051"
                                                                onClicked: playerNextProcess.running = true
                                                            }
                                                            
                                                            Item { width: 15; height: 1 }
                                                            
                                                            // Переключатель плееров
                                                            Row {
                                                                spacing: 6
                                                                visible: availablePlayers.length > 1
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                
                                                                IconButton {
                                                                    width: 24; height: 24; iconSize: 10
                                                                    icon: "\uf053"
                                                                    onClicked: prevPlayer()
                                                                }
                                                                
                                                                Row {
                                                                    spacing: 5
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    
                                                                    Repeater {
                                                                        model: availablePlayers
                                                                        Rectangle {
                                                                            width: dotMouse.containsMouse ? 10 : 8
                                                                            height: width; radius: width/2
                                                                            color: index === currentPlayerIndex ? colorBgWorkspaceActive : colorSliderBg
                                                                            Behavior on width { NumberAnimation { duration: 100 } }
                                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                                            
                                                                            MouseArea {
                                                                                id: dotMouse
                                                                                anchors.fill: parent
                                                                                anchors.margins: -4
                                                                                hoverEnabled: true
                                                                                cursorShape: Qt.PointingHandCursor
                                                                                onClicked: switchToPlayer(index)
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                                
                                                                IconButton {
                                                                    width: 24; height: 24; iconSize: 10
                                                                    icon: "\uf054"
                                                                    onClicked: nextPlayer()
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // Статистика
                                            Row {
                                                width: parent.width; height: 60; spacing: 10
                                                StatCard { icon: "\uf2db"; label: "CPU"; value: cpuUsage + "%" }
                                                StatCard { icon: "\uefc5"; label: "RAM"; value: memoryUsage + "%" }
                                                StatCard { 
                                                    icon: batteryCharging ? "\uf0e7" : 
                                                          batteryLevel > 80 ? "\uf240" : batteryLevel > 60 ? "\uf241" : 
                                                          batteryLevel > 40 ? "\uf242" : batteryLevel > 20 ? "\uf243" : "\uf244"
                                                    label: "Battery"
                                                    value: batteryLevel + "%"
                                                }
                                            }
                                            
                                            // Слайдеры
                                            Column {
                                                width: parent.width; spacing: 12
                                                
                                                CustomSlider {
                                                    width: parent.width
                                                    icon: "\uf185"
                                                    sliderValue: brightness
                                                    onSliderMoved: newValue => {
                                                        brightnessUserChanging = true
                                                        brightness = newValue
                                                        brightnessChangeProcess.targetBrightness = newValue
                                                        brightnessChangeProcess.running = true
                                                        Qt.callLater(() => brightnessUserChanging = false)
                                                    }
                                                }
                                                
                                                CustomSlider {
                                                    width: parent.width
                                                    icon: "\uf028"
                                                    sliderValue: volume
                                                    onSliderMoved: newValue => {
                                                        volumeUserChanging = true
                                                        volume = newValue
                                                        volumeChangeProcess.targetVolume = newValue
                                                        volumeChangeProcess.running = true
                                                        Qt.callLater(() => volumeUserChanging = false)
                                                    }
                                                }
                                                
                                                CustomSlider {
                                                    width: parent.width
                                                    icon: "\uf130"
                                                    sliderValue: micVolume
                                                    onSliderMoved: newValue => {
                                                        micUserChanging = true
                                                        micVolume = newValue
                                                        micChangeProcess.targetVolume = newValue
                                                        micChangeProcess.running = true
                                                        Qt.callLater(() => micUserChanging = false)
                                                    }
                                                }
                                            }
                                            
                                            // Уведомления
                                            Rectangle {
                                                width: parent.width; height: 155
                                                color: colorCardBg; radius: 10
                                                
                                                Column {
                                                    anchors.fill: parent
                                                    anchors.margins: 12
                                                    spacing: 8
                                                    
                                                    Row {
                                                        width: parent.width
                                                        
                                                        Text {
                                                            text: "Notifications"
                                                            color: colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 14
                                                            font.weight: Font.Bold
                                                            width: parent.width - 90
                                                        }
                                                        
                                                        Rectangle {
                                                            width: 80; height: 24; radius: 5
                                                            color: clearMouse.containsMouse ? colorButtonBgHover : colorButtonBg
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                            
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "Clear All"
                                                                color: colorTextSecondary
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 11
                                                            }
                                                            
                                                            MouseArea {
                                                                id: clearMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: notifications = []
                                                            }
                                                        }
                                                    }
                                                    
                                                    Column {
                                                        width: parent.width; spacing: 6
                                                        
                                                        Repeater {
                                                            model: notifications.slice(0, 2)
                                                            
                                                            Rectangle {
                                                                width: parent.width; height: 45
                                                                color: colorCardBg; radius: 6
                                                                
                                                                Row {
                                                                    anchors.fill: parent
                                                                    anchors.margins: 8
                                                                    spacing: 8
                                                                    
                                                                    Column {
                                                                        width: parent.width - 30; spacing: 2
                                                                        Text {
                                                                            text: modelData.title
                                                                            color: colorTextSecondary
                                                                            font.family: "JetBrainsMono Nerd Font"
                                                                            font.pixelSize: 12
                                                                            font.weight: Font.Medium
                                                                            elide: Text.ElideRight; width: parent.width
                                                                        }
                                                                        Text {
                                                                            text: modelData.body
                                                                            color: colorTextSecondary
                                                                            font.family: "JetBrainsMono Nerd Font"
                                                                            font.pixelSize: 10
                                                                            opacity: 0.6
                                                                            elide: Text.ElideRight; width: parent.width
                                                                        }
                                                                    }
                                                                    
                                                                    Text {
                                                                        text: "\uf00d"
                                                                        color: colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 12
                                                                        opacity: 0.5
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        
                                                                        MouseArea {
                                                                            anchors.fill: parent
                                                                            anchors.margins: -5
                                                                            cursorShape: Qt.PointingHandCursor
                                                                            onClicked: notifications = notifications.filter(n => n.id !== modelData.id)
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
                                    
                                    // ===== WALLPAPERS =====
                                    Loader {
                                        anchors.fill: parent
                                        active: currentTab === 1
                                        sourceComponent: Column {
                                            spacing: 15
                                            
                                            Item {
                                                id: carouselContainer
                                                width: parent.width
                                                height: 340
                                                clip: true
                                                
                                                property real centerX: width / 2
                                                property real centerY: height / 2
                                                property real bigW: 500
                                                property real bigH: 300
                                                property real smallW: 150
                                                property real smallH: 100
                                                property real sideOffset: 30
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    z: -1
                                                    onWheel: wheel => wheel.angleDelta.y > 0 ? goToPrevWallpaper() : goToNextWallpaper()
                                                }
                                                
                                                // Левое превью
                                                Rectangle {
                                                    id: leftPreview
                                                    
                                                    property real targetW: root.isAnimating && root.slideDirection === -1 ? 
                                                        carouselContainer.smallW + (carouselContainer.bigW - carouselContainer.smallW) * root.animProgress : 
                                                        carouselContainer.smallW
                                                    property real targetH: root.isAnimating && root.slideDirection === -1 ? 
                                                        carouselContainer.smallH + (carouselContainer.bigH - carouselContainer.smallH) * root.animProgress : 
                                                        carouselContainer.smallH
                                                    property real targetX: root.isAnimating && root.slideDirection === -1 ? 
                                                        carouselContainer.sideOffset + (carouselContainer.centerX - carouselContainer.bigW/2 - carouselContainer.sideOffset) * root.animProgress : 
                                                        carouselContainer.sideOffset
                                                    
                                                    width: targetW
                                                    height: targetH
                                                    x: targetX
                                                    y: carouselContainer.centerY - height/2
                                                    color: colorCardBg
                                                    radius: root.isAnimating && root.slideDirection === -1 ? 8 + 4 * root.animProgress : 8
                                                    clip: true
                                                    visible: root.wallpaperList.length > 1
                                                    z: root.isAnimating && root.slideDirection === -1 ? 10 : 1
                                                    opacity: leftMouse.containsMouse ? 1.0 : (root.isAnimating && root.slideDirection === -1 ? 0.6 + 0.4 * root.animProgress : 0.6)
                                                    scale: leftMouse.containsMouse && !root.isAnimating ? 1.05 : 1.0
                                                    
                                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                                    Behavior on scale { NumberAnimation { duration: 150 } }
                                                    
                                                    Image {
                                                        anchors.fill: parent
                                                        source: root.wallpaperList.length > 1 ? 
                                                            "file://" + root.wallpaperList[(root.currentWallpaperIndex - 1 + root.wallpaperList.length) % root.wallpaperList.length] : ""
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
                                                
                                                // Центральное изображение
                                                Rectangle {
                                                    id: centerWallpaper
                                                    
                                                    property real targetW: root.isAnimating ? 
                                                        carouselContainer.bigW - (carouselContainer.bigW - carouselContainer.smallW) * root.animProgress : 
                                                        carouselContainer.bigW
                                                    property real targetH: root.isAnimating ? 
                                                        carouselContainer.bigH - (carouselContainer.bigH - carouselContainer.smallH) * root.animProgress : 
                                                        carouselContainer.bigH
                                                    property real targetX: {
                                                        if (!root.isAnimating) return carouselContainer.centerX - carouselContainer.bigW/2
                                                        if (root.slideDirection === 1) {
                                                            return carouselContainer.centerX - carouselContainer.bigW/2 + 
                                                                (carouselContainer.sideOffset - carouselContainer.centerX + carouselContainer.bigW/2) * root.animProgress
                                                        } else {
                                                            return carouselContainer.centerX - carouselContainer.bigW/2 + 
                                                                (carouselContainer.width - carouselContainer.sideOffset - carouselContainer.smallW - carouselContainer.centerX + carouselContainer.bigW/2) * root.animProgress
                                                        }
                                                    }
                                                    
                                                    width: targetW
                                                    height: targetH
                                                    x: targetX
                                                    y: carouselContainer.centerY - height/2
                                                    color: colorCardBg
                                                    radius: root.isAnimating ? 12 - 4 * root.animProgress : 12
                                                    clip: true
                                                    z: root.isAnimating ? 1 : 10
                                                    opacity: root.isAnimating ? 1.0 - 0.4 * root.animProgress : 1.0
                                                    
                                                    Image {
                                                        anchors.fill: parent
                                                        source: root.wallpaperList.length > 0 ? 
                                                            "file://" + root.wallpaperList[root.currentWallpaperIndex] : ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        cache: true
                                                    }
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "No wallpapers found\n\nAdd images to:\n~/Pictures/Wallpapers"
                                                        color: colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 14
                                                        opacity: 0.5
                                                        horizontalAlignment: Text.AlignHCenter
                                                        visible: root.wallpaperList.length === 0 && !root.isAnimating
                                                    }
                                                }
                                                
                                                // Правое превью
                                                Rectangle {
                                                    id: rightPreview
                                                    
                                                    property real targetW: root.isAnimating && root.slideDirection === 1 ? 
                                                        carouselContainer.smallW + (carouselContainer.bigW - carouselContainer.smallW) * root.animProgress : 
                                                        carouselContainer.smallW
                                                    property real targetH: root.isAnimating && root.slideDirection === 1 ? 
                                                        carouselContainer.smallH + (carouselContainer.bigH - carouselContainer.smallH) * root.animProgress : 
                                                        carouselContainer.smallH
                                                    property real targetX: root.isAnimating && root.slideDirection === 1 ? 
                                                        (carouselContainer.width - carouselContainer.sideOffset - carouselContainer.smallW - 
                                                        (carouselContainer.width - carouselContainer.sideOffset - carouselContainer.smallW - carouselContainer.centerX + carouselContainer.bigW/2) * root.animProgress) : 
                                                        carouselContainer.width - carouselContainer.sideOffset - carouselContainer.smallW
                                                    
                                                    width: targetW
                                                    height: targetH
                                                    x: targetX
                                                    y: carouselContainer.centerY - height/2
                                                    color: colorCardBg
                                                    radius: root.isAnimating && root.slideDirection === 1 ? 8 + 4 * root.animProgress : 8
                                                    clip: true
                                                    visible: root.wallpaperList.length > 1
                                                    z: root.isAnimating && root.slideDirection === 1 ? 10 : 1
                                                    opacity: rightMouse.containsMouse ? 1.0 : (root.isAnimating && root.slideDirection === 1 ? 0.6 + 0.4 * root.animProgress : 0.6)
                                                    scale: rightMouse.containsMouse && !root.isAnimating ? 1.05 : 1.0
                                                    
                                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                                    Behavior on scale { NumberAnimation { duration: 150 } }
                                                    
                                                    Image {
                                                        anchors.fill: parent
                                                        source: root.wallpaperList.length > 1 ? 
                                                            "file://" + root.wallpaperList[(root.currentWallpaperIndex + 1) % root.wallpaperList.length] : ""
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
                                                
                                                // Левая стрелка
                                                IconButton {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 190
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 40
                                                    height: 40
                                                    icon: "\uf053"
                                                    iconSize: 16
                                                    visible: root.wallpaperList.length > 1
                                                    z: 20
                                                    onClicked: root.goToPrevWallpaper()
                                                }
                                                
                                                // Правая стрелка
                                                IconButton {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 190
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 40
                                                    height: 40
                                                    icon: "\uf054"
                                                    iconSize: 16
                                                    visible: root.wallpaperList.length > 1
                                                    z: 20
                                                    onClicked: root.goToNextWallpaper()
                                                }
                                            }
                                            
                                            // Счётчик и кнопка
                                            Column {
                                                width: parent.width
                                                spacing: 12
                                                
                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: root.wallpaperList.length > 0 ? 
                                                        (root.currentWallpaperIndex + 1) + " / " + root.wallpaperList.length : "0 / 0"
                                                    color: colorTextSecondary
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 14
                                                    opacity: 0.7
                                                }
                                                
                                                Rectangle {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: 200
                                                    height: 45
                                                    radius: 10
                                                    color: setWpMouse.containsMouse ? Qt.lighter(colorBgWorkspaceActive, 1.1) : colorBgWorkspaceActive
                                                    
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "Set as Wallpaper"
                                                        color: colorTextWorkspaceActive
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 14
                                                        font.weight: Font.Bold
                                                    }
                                                    
                                                    MouseArea {
                                                        id: setWpMouse
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
                                    
                                    // ===== NETWORK =====
                                    Loader {
                                        anchors.fill: parent
                                        active: currentTab === 2
                                        sourceComponent: Column {
                                            spacing: 15
                                            
                                            Row {
                                                width: parent.width; height: 35; spacing: 10
                                                
                                                Repeater {
                                                    model: ["WiFi", "Bluetooth"]
                                                    
                                                    Rectangle {
                                                        width: (parent.width - 10) / 2; height: 35; radius: 8
                                                        color: currentNetworkTab === index ? colorBgWorkspaceActive : 
                                                               ntMouse.containsMouse ? colorButtonBgHover : colorButtonBg
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            color: currentNetworkTab === index ? colorTextWorkspaceActive : colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                            font.weight: Font.Bold
                                                        }
                                                        
                                                        MouseArea {
                                                            id: ntMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: currentNetworkTab = index
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // WiFi
                                            Item {
                                                width: parent.width
                                                height: parent.height - 50
                                                visible: currentNetworkTab === 0
                                                
                                                Column {
                                                    anchors.fill: parent; spacing: 10
                                                    
                                                    Row {
                                                        width: parent.width; spacing: 10
                                                        
                                                        Text {
                                                            text: "WiFi Networks"
                                                            color: colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 14
                                                            font.weight: Font.Bold
                                                            width: parent.width - 110
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        
                                                        Rectangle {
                                                            width: 100; height: 30; radius: 6
                                                            color: wifiScanMouse.containsMouse ? colorButtonBgHover : colorButtonBg
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                            
                                                            Row {
                                                                anchors.centerIn: parent; spacing: 6
                                                                Text {
                                                                    text: wifiScanning ? "\uf110" : "\uf021"
                                                                    color: colorTextSecondary
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 12
                                                                    RotationAnimation on rotation {
                                                                        running: wifiScanning
                                                                        from: 0; to: 360; duration: 1000
                                                                        loops: Animation.Infinite
                                                                    }
                                                                }
                                                                Text {
                                                                    text: wifiScanning ? "Scanning" : "Scan"
                                                                    color: colorTextSecondary
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 12
                                                                }
                                                            }
                                                            
                                                            MouseArea {
                                                                id: wifiScanMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: scanWifi()
                                                            }
                                                        }
                                                    }
                                                    
                                                    Flickable {
                                                        width: parent.width
                                                        height: parent.height - 50
                                                        contentHeight: wifiCol.height
                                                        clip: true
                                                        
                                                        Column {
                                                            id: wifiCol
                                                            width: parent.width; spacing: 8
                                                            
                                                            Text {
                                                                text: wifiNetworks.length === 0 ? "No networks found. Click Scan." : ""
                                                                color: colorTextSecondary
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 13
                                                                opacity: 0.5
                                                                visible: wifiNetworks.length === 0
                                                                width: parent.width
                                                                horizontalAlignment: Text.AlignHCenter
                                                                topPadding: 20
                                                            }
                                                            
                                                            Repeater {
                                                                model: wifiNetworks
                                                                NetworkItem {
                                                                    icon: "\uf1eb"
                                                                    name: modelData.ssid || "<Hidden>"
                                                                    subtitle: modelData.signal + "% " + (modelData.secured ? "\uf023 Secured" : "\uf09c Open")
                                                                    isConnected: modelData.connected
                                                                    onConnectClicked: {
                                                                        if (modelData.connected) {
                                                                            wifiDisconnectProcess.running = true
                                                                        } else {
                                                                            wifiConnectProcess.ssid = modelData.ssid
                                                                            wifiConnectProcess.running = true
                                                                        }
                                                                        Qt.callLater(scanWifi)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // Bluetooth
                                            Item {
                                                width: parent.width
                                                height: parent.height - 50
                                                visible: currentNetworkTab === 1
                                                
                                                Column {
                                                    anchors.fill: parent; spacing: 10
                                                    
                                                    Row {
                                                        width: parent.width; spacing: 10
                                                        
                                                        Text {
                                                            text: "Bluetooth Devices"
                                                            color: colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 14
                                                            font.weight: Font.Bold
                                                            width: parent.width - 110
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        
                                                        Rectangle {
                                                            width: 100; height: 30; radius: 6
                                                            color: btScanMouse.containsMouse ? colorButtonBgHover : colorButtonBg
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                            
                                                            Row {
                                                                anchors.centerIn: parent; spacing: 6
                                                                Text {
                                                                    text: btScanning ? "\uf110" : "\uf021"
                                                                    color: colorTextSecondary
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 12
                                                                    RotationAnimation on rotation {
                                                                        running: btScanning
                                                                        from: 0; to: 360; duration: 1000
                                                                        loops: Animation.Infinite
                                                                    }
                                                                }
                                                                Text {
                                                                    text: btScanning ? "Scanning" : "Scan"
                                                                    color: colorTextSecondary
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 12
                                                                }
                                                            }
                                                            
                                                            MouseArea {
                                                                id: btScanMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: scanBluetooth()
                                                            }
                                                        }
                                                    }
                                                    
                                                    Flickable {
                                                        width: parent.width
                                                        height: parent.height - 50
                                                        contentHeight: btCol.height
                                                        clip: true
                                                        
                                                        Column {
                                                            id: btCol
                                                            width: parent.width; spacing: 8
                                                            
                                                            Text {
                                                                text: bluetoothDevices.length === 0 ? "No paired devices.\nUse bluetoothctl to pair." : ""
                                                                color: colorTextSecondary
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 13
                                                                opacity: 0.5
                                                                visible: bluetoothDevices.length === 0
                                                                width: parent.width
                                                                horizontalAlignment: Text.AlignHCenter
                                                                topPadding: 20
                                                            }
                                                            
                                                            Repeater {
                                                                model: bluetoothDevices
                                                                NetworkItem {
                                                                    icon: modelData.type === "audio" ? "\uf025" : 
                                                                          modelData.type === "input" ? "\uf11b" : 
                                                                          modelData.type === "phone" ? "\uf10b" : "\uf294"
                                                                    name: modelData.name
                                                                    subtitle: modelData.connected ? "Connected" : "Paired"
                                                                    isConnected: modelData.connected
                                                                    onConnectClicked: {
                                                                        if (modelData.connected) {
                                                                            btDisconnectProcess.mac = modelData.mac
                                                                            btDisconnectProcess.running = true
                                                                        } else {
                                                                            btConnectProcess.mac = modelData.mac
                                                                            btConnectProcess.running = true
                                                                        }
                                                                        Qt.callLater(scanBluetooth)
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
                    
                    // Обновляем progress при изменении showDynamicIsland
                    onVisibleChanged: {
                        if (visible) {
                            islandProgress = 1.0
                        }
                    }
                }
                
                // Сбрасываем progress при закрытии
                Connections {
                    target: root
                    function onShowDynamicIslandChanged() {
                        if (!showDynamicIsland) {
                            islandProgress = 0.0
                        } else {
                            islandProgress = 1.0
                        }
                    }
                }

                // ===== MAIN BAR =====
                PanelWindow {
                    id: bar
                    screen: modelData
                    visible: modelData.name === "DP-1"
                    
                    anchors { top: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Auto
                    exclusiveZone: 36
                    height: 36
                    focusable: false
                    color: colorBgSecondary

                    Item {
                        anchors.fill: parent
                        anchors.margins: 3
                        anchors.leftMargin: 7
                        anchors.rightMargin: 7

                        // LEFT - Workspaces
                        RowLayout {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                color: colorBgPrimary; radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: wsRow.width + 18

                                RowLayout {
                                    id: wsRow
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Repeater {
                                        model: 6

                                        Rectangle {
                                            id: wsBtn
                                            property int wsNum: index + 1
                                            property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === wsNum
                                            property bool hasWindows: {
                                                for (let i = 0; i < Hyprland.workspaces.values.length; i++)
                                                    if (Hyprland.workspaces.values[i].id === wsNum) return true
                                                return false
                                            }

                                            width: 24; height: 24; radius: 5
                                            color: isActive ? colorBgWorkspaceActive : 
                                                   wsMouse.containsMouse ? colorBgWorkspaceHover : "transparent"
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: wsBtn.wsNum
                                                color: wsBtn.isActive ? colorTextWorkspaceActive : colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                                opacity: wsBtn.hasWindows || wsBtn.isActive ? 1.0 : 0.5
                                            }

                                            MouseArea {
                                                id: wsMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Hyprland.dispatch("workspace " + wsBtn.wsNum)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // CENTER - Clock (триггер для Island)
                        Rectangle {
                            id: centerClock
                            anchors.centerIn: parent
                            color: colorBgPrimary; radius: 5
                            height: 30; width: clockRow.implicitWidth + 18

                            Row {
                                id: clockRow
                                anchors.centerIn: parent
                                spacing: 6
                                
                                Text {
                                    id: clockDate
                                    text: Qt.formatDateTime(new Date(), "ddd dd MMM yyyy")
                                    color: colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: "\uf017"
                                    color: colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                Text {
                                    id: clockTime
                                    text: Qt.formatDateTime(new Date(), "HH:mm")
                                    color: colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                            }

                            Timer {
                                interval: 1000; running: true; repeat: true
                                onTriggered: {
                                    let now = new Date()
                                    clockDate.text = Qt.formatDateTime(now, "ddd dd MMM yyyy")
                                    clockTime.text = Qt.formatDateTime(now, "HH:mm")
                                }
                            }

                            HoverHandler {
                                onHoveredChanged: {
                                    isMouseOverIsland = hovered
                                    if (hovered) openIsland()
                                    else hideIslandTimer.restart()
                                }
                            }
                            
                            TapHandler {
                                onTapped: {
                                    if (showDynamicIsland) closeIsland()
                                    else openIsland()
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
                                color: colorBgPrimary; radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: langRow.implicitWidth + 18

                                Row {
                                    id: langRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "\uf11c"; color: colorTextSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    Text { text: currentLanguage; color: colorTextSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                }
                            }

                            // Audio
                            Rectangle {
                                color: colorBgPrimary; radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: audioRow.implicitWidth + 18

                                Process { id: pavuProcess; command: ["pavucontrol"] }

                                Row {
                                    id: audioRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Item {
                                        width: volRow.width; height: 30
                                        Row {
                                            id: volRow
                                            spacing: 4
                                            anchors.centerIn: parent
                                            Text {
                                                text: volume === 0 ? "\uf6a9" : volume > 66 ? "\uf028" : volume > 33 ? "\uf027" : "\uf026"
                                                color: colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }
                                            Text { text: volume + "%"; color: colorTextSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            onClicked: pavuProcess.running = true
                                            onWheel: wheel => {
                                                let nv = Math.max(0, Math.min(100, volume + (wheel.angleDelta.y > 0 ? 5 : -5)))
                                                volumeChangeProcess.targetVolume = nv
                                                volumeChangeProcess.running = true
                                            }
                                        }
                                    }

                                    Item {
                                        width: micRow.width; height: 30
                                        Row {
                                            id: micRow
                                            spacing: 4
                                            anchors.centerIn: parent
                                            Text {
                                                text: micVolume === 0 ? "\uf131" : "\uf130"
                                                color: colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                text: micVolume > 0 ? micVolume + "%" : ""
                                                color: colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                                visible: micVolume > 0
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            onClicked: pavuProcess.running = true
                                            onWheel: wheel => {
                                                let nv = Math.max(0, Math.min(100, micVolume + (wheel.angleDelta.y > 0 ? 5 : -5)))
                                                micChangeProcess.targetVolume = nv
                                                micChangeProcess.running = true
                                            }
                                        }
                                    }
                                }
                            }

                            // Hardware
                            Rectangle {
                                color: colorBgPrimary; radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: hwRow.implicitWidth + 18

                                Row {
                                    id: hwRow
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Row {
                                        spacing: 4
                                        Text { text: cpuUsage + "%"; color: colorTextSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                        Text { text: "\uf2db"; color: colorTextSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                    }
                                    Row {
                                        spacing: 4
                                        Text { text: memoryUsage + "%"; color: colorTextSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                        Text { text: "\uefc5"; color: colorTextSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                    }
                                }
                            }

                            // Network
                            Rectangle {
                                color: colorBgPrimary; radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: netText.implicitWidth + 18

                                Process { id: nmProcess; command: ["nm-connection-editor"] }

                                MouseArea {
                                    id: netMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: nmProcess.running = true
                                }

                                Text {
                                    id: netText
                                    anchors.centerIn: parent
                                    text: networkStatus === "wifi" ? "\uf1eb" : networkStatus === "ethernet" ? "\uf796" : "\uf06a"
                                    color: colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                }

                                Rectangle {
                                    visible: netMouse.containsMouse && networkSSID !== ""
                                    color: colorBgPrimary; radius: 5
                                    width: ttText.implicitWidth + 16
                                    height: ttText.implicitHeight + 8
                                    z: 1000
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 5
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Text {
                                        id: ttText
                                        anchors.centerIn: parent
                                        text: "SSID: " + networkSSID
                                        color: colorTextSecondary
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
