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

    Plasma5Support.DataSource {
        id: dataSource
        engine: "executable"
        connectedSources: []
        
        function update() {
            connectSource("df -BK")
        }
        
        onNewData: function(source, data) {
            if (source === "df -BK") {
                parseDiskData(data.stdout)
            }
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
        const lines = output.split('\n').filter(line => line.trim() && !line.startsWith('Filesystem'))
        
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
                        "mountName": mount === '/' ? 'Root' :
                                     mount === '/home' ? 'Home' :
                                     mount === '/home/jmc/Storage/nvme1tb' ? 'Steam' :
                                     mount === '/home/jmc/Storage/disk3tb' ? '3 TB HD' :
                                     mount === '/home/jmc/Storage/disk8tb' ? '8 TB HD' :
                                     mount === '/home/jmc/Storage/nvme2tb' ? '2 TB NVME' :
                                     mount.split('/').pop() || mount
                    }
                }
            }
        })
        
        diskModel.clear()
        const displayedDrives = plasmoid.configuration.displayedDrives.split('\n').map(m => m.trim()).filter(m => m)
        
        displayedDrives.forEach(mount => {
            if (allDisks[mount]) {
                diskModel.append(allDisks[mount])
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

                        PlasmaComponents.Label {
                            text: model.mountName
                            color: plasmoid.configuration.textColor
                            Layout.fillWidth: true
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize - 1
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.2)
                            
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
                                color: plasmoid.configuration.textColor
                                Layout.fillWidth: true
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 1
                                elide: Text.ElideRight
                            }

                            PlasmaComponents.Label {
                                text: model.avail
                                color: plasmoid.configuration.textColor
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.2)
                            
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
