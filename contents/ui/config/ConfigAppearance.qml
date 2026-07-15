import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    id: root

    property alias cfg_bgOpacity: opacitySlider.value
    property string cfg_textColor: plasmoid.configuration.textColor
    property alias cfg_showTitle: showTitleCheckbox.checked
    property alias cfg_fontWeight: fontWeightCombo.currentIndex
    property string cfg_driveColors: plasmoid.configuration.driveColors
    property string cfg_driveLabels: plasmoid.configuration.driveLabels
    property string cfg_displayedDrives: plasmoid.configuration.displayedDrives
    property string cfg_driveOrder: plasmoid.configuration.driveOrder

    property var addedDrives: ({})
    property var displayedMap: ({})
    property var colorsMap: ({})
    property var labelsMap: ({})

    ListModel {
        id: drivesModel
    }

    function getDefaultFriendlyName(mount) {
        if (mount === '/') return i18n("Root");
        if (mount === '/home') return i18n("Home");
        if (mount === '/home/jmc/Storage/nvme1tb') return i18n("Steam");
        if (mount === '/home/jmc/Storage/disk3tb') return i18n("3 TB HD");
        if (mount === '/home/jmc/Storage/disk8tb') return i18n("8 TB HD");
        if (mount === '/home/jmc/Storage/nvme2tb') return i18n("2 TB NVME");
        return mount.split('/').pop() || mount;
    }

    function loadSettings() {
        drivesModel.clear();

        var displayedMap = {};
        var displayedDrives = root.cfg_displayedDrives.split('\n').map(function(m) { return m.trim(); }).filter(function(m) { return m; });
        displayedDrives.forEach(function(mount) {
            displayedMap[mount] = true;
        });

        var colorsMap = {};
        var colorLines = root.cfg_driveColors.split('\n').filter(function(line) { return line.trim(); });
        colorLines.forEach(function(line) {
            var parts = line.split(':');
            if (parts.length === 2) {
                var mount = parts[0].trim();
                var color = parts[1].trim();
                if (color.match(/^#[0-9A-Fa-f]{6}$/)) {
                    colorsMap[mount] = color;
                }
            }
        });

        var labelsMap = {};
        var labelLines = root.cfg_driveLabels.split('\n').filter(function(line) { return line.trim(); });
        labelLines.forEach(function(line) {
            var parts = line.split(':');
            if (parts.length === 2) {
                var mount = parts[0].trim();
                var label = parts[1].trim();
                labelsMap[mount] = label;
            }
        });

        var added = {};
        displayedDrives.forEach(function(mount) {
            if (!added[mount]) {
                drivesModel.append({
                    mountPoint: mount,
                    displayed: true,
                    color: colorsMap[mount] || "#ffffff",
                    customLabel: labelsMap[mount] || ""
                });
                added[mount] = true;
            }
        });

        for (var mount in colorsMap) {
            if (!added[mount]) {
                drivesModel.append({
                    mountPoint: mount,
                    displayed: false,
                    color: colorsMap[mount],
                    customLabel: labelsMap[mount] || ""
                });
                added[mount] = true;
            }
        }

        for (var mount in labelsMap) {
            if (!added[mount]) {
                drivesModel.append({
                    mountPoint: mount,
                    displayed: false,
                    color: colorsMap[mount] || "#ffffff",
                    customLabel: labelsMap[mount]
                });
                added[mount] = true;
            }
        }
        
        root.addedDrives = added;
        root.displayedMap = displayedMap;
        root.colorsMap = colorsMap;
        root.labelsMap = labelsMap;
    }

    function saveSettings() {
        var displayed = [];
        var colors = [];
        var labels = [];
        for (var i = 0; i < drivesModel.count; i++) {
            var item = drivesModel.get(i);
            if (item.displayed) {
                displayed.push(item.mountPoint);
            }
            colors.push(item.mountPoint + ":  " + item.color);
            if (item.customLabel && item.customLabel.trim().length > 0) {
                labels.push(item.mountPoint + ":  " + item.customLabel.trim());
            }
        }
        root.cfg_displayedDrives = displayed.join("\n");
        root.cfg_driveOrder = root.cfg_displayedDrives;
        root.cfg_driveColors = colors.join("\n");
        root.cfg_driveLabels = labels.join("\n");
    }

    function parseDfOutput(stdout) {
        if (!stdout) return;
        var lines = stdout.split('\n').filter(function(line) { return line.trim() && !line.startsWith('Filesystem'); });
        lines.forEach(function(line) {
            var parts = line.trim().split(/\s+/);
            if (parts.length >= 5) {
                var mount = parts[parts.length - 1];
                if (mount.startsWith('/') && !mount.startsWith('/sys') && !mount.startsWith('/proc') && !mount.startsWith('/run') && !mount.startsWith('/dev')) {
                    if (!root.addedDrives[mount]) {
                        drivesModel.append({
                            mountPoint: mount,
                            displayed: false,
                            color: root.colorsMap[mount] || "#ffffff",
                            customLabel: root.labelsMap[mount] || ""
                        });
                        root.addedDrives[mount] = true;
                    }
                }
            }
        });
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var stdout = data["stdout"]
            if (stdout) {
                root.parseDfOutput(stdout)
            }
            disconnectSource(sourceName)
        }
        function exec(cmd) {
            connectSource(cmd)
        }
    }

    Component.onCompleted: {
        root.loadSettings()
        executable.exec("timeout 5 df -BK")
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        // --- General Appearance ---
        Kirigami.Separator { Kirigami.FormData.label: i18n("General Settings"); Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showTitleCheckbox
            Kirigami.FormData.label: i18n("Show widget title:")
            text: i18n("Show Title")
        }

        QQC2.ComboBox {
            id: fontWeightCombo
            Kirigami.FormData.label: i18n("Font weight:")
            model: [
                i18n("Normal"),
                i18n("Medium"),
                i18n("Demi-Bold"),
                i18n("Bold")
            ]
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Background opacity:")
            QQC2.Slider {
                id: opacitySlider
                from: 0.0
                to: 1.0
                stepSize: 0.05
            }
            QQC2.Label {
                text: Math.round(opacitySlider.value * 100) + "%"
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Text color:")
            Rectangle {
                id: textColorPreview
                width: Kirigami.Units.gridUnit * 1.6
                height: Kirigami.Units.gridUnit * 1.6
                color: root.cfg_textColor
                border.color: Kirigami.Theme.textColor
                border.width: 1
                radius: 4
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: textColorDialog.open()
                }
            }
            QQC2.Button {
                text: i18n("Choose…")
                onClicked: textColorDialog.open()
            }
            ColorDialog {
                id: textColorDialog
                selectedColor: root.cfg_textColor
                onAccepted: root.cfg_textColor = selectedColor
            }
        }

        // --- Drives Configuration ---
        Kirigami.Separator { Kirigami.FormData.label: i18n("Drive Space & Colors"); Kirigami.FormData.isSection: true }

        ColumnLayout {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 32
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: drivesModel
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    QQC2.CheckBox {
                        checked: model.displayed
                        onToggled: {
                            drivesModel.setProperty(index, "displayed", checked);
                            root.saveSettings();
                        }
                    }

                    Rectangle {
                        width: Kirigami.Units.gridUnit * 1.6
                        height: Kirigami.Units.gridUnit * 1.6
                        color: model.color
                        border.color: Kirigami.Theme.textColor
                        border.width: 1
                        radius: 4
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: driveColorDialog.open()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        QQC2.TextField {
                            text: model.customLabel
                            font.bold: model.displayed
                            Layout.fillWidth: true
                            placeholderText: root.getDefaultFriendlyName(model.mountPoint)
                            onTextChanged: {
                                drivesModel.setProperty(index, "customLabel", text);
                                root.saveSettings();
                            }
                        }

                        QQC2.Label {
                            text: model.mountPoint
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize - 2
                            color: Kirigami.Theme.textColor
                            opacity: 0.7
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        spacing: 2
                        QQC2.ToolButton {
                            icon.name: "go-up"
                            display: QQC2.AbstractButton.IconOnly
                            enabled: index > 0
                            implicitWidth: Kirigami.Units.gridUnit * 1.8
                            implicitHeight: Kirigami.Units.gridUnit * 1.8
                            onClicked: {
                                drivesModel.move(index, index - 1, 1);
                                root.saveSettings();
                            }
                        }
                        QQC2.ToolButton {
                            icon.name: "go-down"
                            display: QQC2.AbstractButton.IconOnly
                            enabled: index < drivesModel.count - 1
                            implicitWidth: Kirigami.Units.gridUnit * 1.8
                            implicitHeight: Kirigami.Units.gridUnit * 1.8
                            onClicked: {
                                drivesModel.move(index, index + 1, 1);
                                root.saveSettings();
                            }
                        }
                    }

                    ColorDialog {
                        id: driveColorDialog
                        selectedColor: model.color
                        onAccepted: {
                            drivesModel.setProperty(index, "color", driveColorDialog.selectedColor.toString());
                            root.saveSettings();
                        }
                    }
                }
            }
        }
    }
}
