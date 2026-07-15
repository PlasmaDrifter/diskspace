import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    preferredRepresentation: preferredRepresentation

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // We keep track of the current command string so we can explicitly kill it
    property string currentCmd: "timeout 5 df -BK"
    property real sharedOpacity: 0.3
    readonly property var fontWeights: [400, 500, 600, 700]

    Plasma5Support.DataSource {
        id: dataSource
        engine: "executable"
        connectedSources: []

        function update() {
            // Completely disconnect the old command string first
            disconnectSource(root.currentCmd)

            const displayedDrives = plasmoid.configuration.displayedDrives.split('\n').map(function(m) { return m.trim(); }).filter(function(m) { return m; })
            if (displayedDrives.length === 0) {
                diskModel.clear()
                return
            }

            const drives = displayedDrives.map(function(m) { return '"' + m.replace(/"/g, '\\"') + '"'; }).join(" ")
            root.currentCmd = "for m in " + drives + "; do timeout 2 df -BK \"$m\" 2>/dev/null; done # " + Date.now()

            connectSource(root.currentCmd)
        }

        onNewData: function(source, data) {
            if (source === root.currentCmd) {
                parseDiskData(data.stdout)
                // Disconnect immediately after reading to free up the engine
                disconnectSource(source)
            } else if (source.indexOf("plasma-custom-opacity.txt") !== -1) {
                disconnectSource(source)
                var stdout = data["stdout"] || "";
                var val = parseFloat(stdout.trim());
                if (!isNaN(val) && val >= 0.0 && val <= 1.0) {
                    if (root.sharedOpacity !== val) {
                        root.sharedOpacity = val;
                    }
                    if (plasmoid.configuration.bgOpacity !== val) {
                        plasmoid.configuration.bgOpacity = val;
                    }
                }
            }
        }
    }

    Connections {
        target: plasmoid.configuration
        function onBgOpacityChanged() {
            var newOpacity = plasmoid.configuration.bgOpacity;
            if (Math.abs(root.sharedOpacity - newOpacity) > 0.01) {
                dataSource.connectSource("echo " + newOpacity + " > /home/jmc/.config/plasma-custom-opacity.txt");
            }
        }
        function onDisplayedDrivesChanged() {
            dataSource.update()
        }
        function onDriveColorsChanged() {
            dataSource.update()
        }
        function onDriveLabelsChanged() {
            dataSource.update()
        }
    }

    ListModel {
        id: diskModel
    }

    function getDriveColor(mount) {
        const colors = {}
        const lines = plasmoid.configuration.driveColors.split('\n').filter(line => line.trim())

        lines.forEach(line => {
            const parts = line.split(':')
            if (parts.length === 2) {
                const driveName = parts[0].trim()
                const color = parts[1].trim()
                if (color.match(/^#[0-9A-Fa-f]{6}$/)) {
                    colors[driveName] = color
                }
            }
        })

        return colors[mount] || "#FFFFFF"
    }

    function getDriveLabel(mount) {
        const labels = {}
        const lines = plasmoid.configuration.driveLabels.split('\n').filter(line => line.trim())

        lines.forEach(line => {
            const parts = line.split(':')
            if (parts.length === 2) {
                const driveName = parts[0].trim()
                const labelName = parts[1].trim()
                if (labelName.length > 0) {
                    labels[driveName] = labelName
                }
            }
        })

        if (labels[mount]) {
            return labels[mount]
        }

        if (mount === '/') return 'Root'
        if (mount === '/home') return 'Home'
        if (mount === '/home/jmc/Storage/nvme1tb') return 'Steam'
        if (mount === '/home/jmc/Storage/disk3tb') return '3 TB HD'
        if (mount === '/home/jmc/Storage/disk8tb') return '8 TB HD'
        if (mount === '/home/jmc/Storage/nvme2tb') return '2 TB NVME'
        return mount.split('/').pop() || mount
    }

    function formatSize(kb) {
        const units = ["KB", "MB", "GB", "TB"]
        let size = parseInt(kb)
        let i = 0
        while (size >= 1024 && i < units.length - 1) {
            size /= 1024
            i++
        }
        return size.toFixed(1) + " " + units[i]
    }

    function parseDiskData(output) {
        const allDisks = {}
        const lines = (output || "").split('\n').filter(line => line.trim() && !line.startsWith('Filesystem'))

        lines.forEach(line => {
            const parts = line.trim().split(/\s+/)
            if (parts.length >= 5) {
                const mount = parts[parts.length - 1]
                const usedPercent = parseInt(parts[parts.length - 2]) || 0
                const freePercent = 100 - usedPercent
                const availRaw = parts[parts.length - 3].replace('K', '')

                if (mount.startsWith('/') && !mount.startsWith('/sys') && !mount.startsWith('/proc') && !mount.startsWith('/run')) {
                    allDisks[mount] = {
                        "avail": formatSize(availRaw),
                        "usedPercent": usedPercent,
                        "freePercent": freePercent,
                        "mount": mount,
                        "color": getDriveColor(mount),
                        "isOffline": false,
                        "mountName": getDriveLabel(mount)
                    }
                }
            }
        })

        diskModel.clear()
        const displayedDrives = plasmoid.configuration.displayedDrives.split('\n').map(m => m.trim()).filter(m => m)

        displayedDrives.forEach(mount => {
            if (allDisks[mount]) {
                diskModel.append(allDisks[mount])
            } else {
                diskModel.append({
                    "avail": "Offline",
                    "usedPercent": 0,
                    "freePercent": 0,
                    "mount": mount,
                    "color": getDriveColor(mount),
                    "isOffline": true,
                    "mountName": getDriveLabel(mount)
                });
            }
        })
    }

    Component.onCompleted: {
        dataSource.update()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: dataSource.update()
    }

    Timer {
        id: sharedOpacityTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            dataSource.connectSource("cat /home/jmc/.config/plasma-custom-opacity.txt");
        }
    }

    compactRepresentation: Component {
        Item {
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
            Layout.minimumHeight: Kirigami.Units.gridUnit * 6
            clip: true

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: plasmoid.configuration.bgOpacity
                radius: 12
                z: 0
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                z: 1
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: i18n("Disk Space")
                    font.bold: true
                    color: plasmoid.configuration.textColor
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
                    visible: plasmoid.configuration.showTitle
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: diskModel
                    spacing: 15
                    clip: true

                    delegate: ColumnLayout {
                        width: parent.width
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            PlasmaComponents.Label {
                                text: model.mountName
                                color: model.isOffline ? Kirigami.Theme.disabledTextColor : plasmoid.configuration.textColor
                                Layout.fillWidth: true
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize - 1
                                font.weight: root.fontWeights[plasmoid.configuration.fontWeight] || 400
                                elide: Text.ElideRight
                            }

                            PlasmaComponents.Label {
                                text: i18n("Offline")
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize - 2
                                visible: model.isOffline
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.2)
                            opacity: model.isOffline ? 0.35 : 1.0

                            Rectangle {
                                width: parent.width * (model.freePercent / 100)
                                height: parent.height
                                radius: 2
                                color: model.color
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.expanded = !root.expanded
            }
        }
    }

    fullRepresentation: Component {
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: plasmoid.configuration.bgOpacity
                radius: 12
                z: 0
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.gridUnit
                z: 1
                spacing: Kirigami.Units.gridUnit

                PlasmaComponents.Label {
                    text: i18n("Disk Space")
                    font.bold: true
                    color: plasmoid.configuration.textColor
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 4
                    visible: plasmoid.configuration.showTitle
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: plasmoid.configuration.textColor
                    opacity: 0.3
                    visible: plasmoid.configuration.showTitle
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: diskModel
                    spacing: 15
                    clip: true

                    delegate: ColumnLayout {
                        width: parent.width
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            PlasmaComponents.Label {
                                text: model.mountName
                                color: model.isOffline ? Kirigami.Theme.disabledTextColor : plasmoid.configuration.textColor
                                Layout.fillWidth: true
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 1
                                font.weight: root.fontWeights[plasmoid.configuration.fontWeight] || 400
                                elide: Text.ElideRight
                            }

                            PlasmaComponents.Label {
                                text: model.avail
                                color: model.isOffline ? Kirigami.Theme.disabledTextColor : plasmoid.configuration.textColor
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                font.weight: root.fontWeights[plasmoid.configuration.fontWeight] || 400
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.2)
                            opacity: model.isOffline ? 0.35 : 1.0

                            Rectangle {
                                width: parent.width * (model.freePercent / 100)
                                height: parent.height
                                radius: 3
                                color: model.color
                            }
                        }
                    }
                }
            }
        }
    }
}
