import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    Mpris.Mpris2Model { id: mpris }

    readonly property var player: mpris.currentPlayer
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string track: hasPlayer ? (player.track || "") : ""
    readonly property string artist: hasPlayer ? (player.artist || "") : ""
    readonly property string album: hasPlayer ? (player.album || "") : ""
    readonly property string art: hasPlayer ? (player.artUrl || "") : ""
    // row 0 of the model is the "choose automatically" multiplexer, so real players = rows - 1
    property int modelRows: 0
    readonly property int playerCount: Math.max(0, modelRows - 1)
    function refreshRows() { modelRows = mpris.rowCount() }
    Connections {
        target: mpris
        function onRowsInserted() { root.refreshRows() }
        function onRowsRemoved() { root.refreshRows() }
        function onModelReset() { root.refreshRows() }
    }
    Component.onCompleted: refreshRows()

    readonly property color crimson: "#E0203F"
    readonly property color dim: "#9A9AA2"

    function fmtTime(us) {
        let s = Math.max(0, Math.floor((us || 0) / 1e6))
        const h = Math.floor(s / 3600); s -= h * 3600
        const m = Math.floor(s / 60); s -= m * 60
        const ss = (s < 10 ? "0" : "") + s
        return h > 0 ? h + ":" + (m < 10 ? "0" : "") + m + ":" + ss : m + ":" + ss
    }

    function nextPlayer() {
        const rows = mpris.rowCount()
        if (rows > 1) mpris.currentIndex = (mpris.currentIndex + 1) % rows
    }

    // MPRIS only pushes position on seek; poll while playing.
    Timer {
        interval: 1000; repeat: true
        running: root.playing
        onTriggered: if (root.hasPlayer) root.player.updatePosition()
    }

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    switchWidth: Kirigami.Units.gridUnit * 18
    switchHeight: Kirigami.Units.gridUnit * 7

    toolTipMainText: hasPlayer && track ? track : i18n("Nothing playing")
    toolTipSubText: hasPlayer ? [artist, player.identity].filter(Boolean).join(" — ") : ""

    compactRepresentation: MouseArea {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton && root.hasPlayer) root.player.PlayPause()
            else root.expanded = !root.expanded
        }
        Kirigami.Icon {
            anchors.fill: parent
            source: root.playing ? "media-playback-start" : (root.hasPlayer ? "media-playback-pause" : "media-playback-stop")
            active: parent.containsMouse
        }
    }

    fullRepresentation: Item {
        id: card
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        Layout.preferredWidth: 620
        Layout.preferredHeight: 170
        clip: true

        // ---- blurred album art backdrop ----------------------------------
        Image {
            id: backdropSrc
            anchors.fill: parent
            source: Plasmoid.configuration.blurredBackground ? root.art : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(128, 128)
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: backdropSrc
            visible: backdropSrc.status === Image.Ready
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: -0.1
            brightness: -0.35
            opacity: 0.8
        }

        // scroll anywhere on the card for volume
        WheelHandler {
            enabled: root.hasPlayer
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const step = Plasmoid.configuration.volumeStep / 100
                const delta = event.angleDelta.y > 0 ? step : event.angleDelta.y < 0 ? -step : 0
                if (delta !== 0) root.player.changeVolume(delta, true)
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            // ---- album art ------------------------------------------------
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: height
                Layout.maximumWidth: 170
                radius: 4
                color: "#0D0D0F"
                border.color: root.playing ? Qt.rgba(224 / 255, 32 / 255, 63 / 255, 0.6) : "#2A2A2E"
                border.width: 1

                Image {
                    id: cover
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.art
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(256, 256)
                    visible: status === Image.Ready
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.5; height: width
                    visible: cover.status !== Image.Ready
                    source: root.hasPlayer && root.player.iconName ? root.player.iconName : "media-optical-audio"
                    opacity: 0.6
                }
            }

            // ---- text + controls -----------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    PC3.Label {
                        text: i18n("Now Playing")
                        opacity: 0.6
                        font: Kirigami.Theme.smallFont
                    }
                    Item { Layout.fillWidth: true }
                    // player chip: click to cycle through players
                    PC3.ToolButton {
                        visible: root.hasPlayer
                        flat: true
                        icon.name: root.hasPlayer ? (root.player.iconName || "multimedia-player") : ""
                        text: root.hasPlayer ? root.player.identity : ""
                        font: Kirigami.Theme.smallFont
                        enabled: root.playerCount > 1
                        onClicked: root.nextPlayer()
                        PC3.ToolTip.text: i18n("Switch player")
                        PC3.ToolTip.visible: hovered && enabled
                    }
                }

                PC3.Label {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? (root.track || i18n("Unknown track")) : i18n("Nothing playing")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: [root.artist, root.album].filter(Boolean).join("  ·  ")
                    color: root.dim
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Item { Layout.fillHeight: true }

                SeekBar {
                    Layout.fillWidth: true
                    visible: root.hasPlayer
                    position: root.hasPlayer ? root.player.position : 0
                    length: root.hasPlayer ? root.player.length : 0
                    seekable: root.hasPlayer && root.player.canSeek
                    onSeekRequested: target => root.player.position = target
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.hasPlayer
                    spacing: 0

                    PC3.Label {
                        text: root.hasPlayer ? root.fmtTime(root.player.position) : ""
                        color: root.dim
                        font: Kirigami.Theme.smallFont
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                    }
                    Item { Layout.fillWidth: true }

                    PC3.ToolButton {
                        icon.name: "media-playlist-shuffle"
                        checkable: true
                        checked: root.hasPlayer && root.player.shuffle === Mpris.ShuffleStatus.On
                        enabled: root.hasPlayer && root.player.canControl && root.player.shuffle !== Mpris.ShuffleStatus.Unknown
                        onClicked: root.player.shuffle = checked ? Mpris.ShuffleStatus.On : Mpris.ShuffleStatus.Off
                    }
                    PC3.ToolButton {
                        icon.name: "media-skip-backward"
                        enabled: root.hasPlayer && root.player.canGoPrevious
                        onClicked: root.player.Previous()
                    }
                    PC3.ToolButton {
                        icon.name: root.playing ? "media-playback-pause" : "media-playback-start"
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        enabled: root.hasPlayer && (root.playing ? root.player.canPause : root.player.canPlay)
                        onClicked: root.player.PlayPause()
                    }
                    PC3.ToolButton {
                        icon.name: "media-skip-forward"
                        enabled: root.hasPlayer && root.player.canGoNext
                        onClicked: root.player.Next()
                    }
                    PC3.ToolButton {
                        id: loopButton
                        readonly property int loop: root.hasPlayer ? root.player.loopStatus : Mpris.LoopStatus.Unknown
                        icon.name: "media-playlist-repeat"
                        checkable: true
                        checked: loop === Mpris.LoopStatus.Playlist || loop === Mpris.LoopStatus.Track
                        enabled: root.hasPlayer && root.player.canControl && loop !== Mpris.LoopStatus.Unknown
                        PC3.ToolTip.text: loop === Mpris.LoopStatus.Track ? i18n("Repeat track")
                                        : loop === Mpris.LoopStatus.Playlist ? i18n("Repeat playlist") : i18n("Repeat off")
                        PC3.ToolTip.visible: hovered
                        // "1" badge for repeat-one (the icon theme has no repeat-song icon)
                        PC3.Label {
                            visible: loopButton.loop === Mpris.LoopStatus.Track
                            anchors.right: parent.right; anchors.bottom: parent.bottom
                            anchors.rightMargin: 3; anchors.bottomMargin: 1
                            text: "1"
                            font.pixelSize: 9; font.weight: Font.Bold
                            color: root.crimson
                        }
                        // None -> Playlist -> Track -> None
                        onClicked: {
                            const s = root.player.loopStatus
                            root.player.loopStatus = s === Mpris.LoopStatus.None ? Mpris.LoopStatus.Playlist
                                                   : s === Mpris.LoopStatus.Playlist ? Mpris.LoopStatus.Track
                                                   : Mpris.LoopStatus.None
                        }
                    }

                    Item { Layout.fillWidth: true }
                    PC3.Label {
                        horizontalAlignment: Text.AlignRight
                        text: root.hasPlayer && root.player.length > 0 ? root.fmtTime(root.player.length) : ""
                        color: root.dim
                        font: Kirigami.Theme.smallFont
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                    }
                }
            }
        }
    }
}
