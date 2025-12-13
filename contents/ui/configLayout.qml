import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: layoutConfig

    // Configuration bindings
    property alias cfg_layoutMode: layoutModeCombo.currentValue
    property alias cfg_gridColumns: gridColumnsSpinBox.value
    property var cfg_panelConfigs: []

    // Internal panel list for preview
    property var panelList: []

    Component.onCompleted: {
        parsePanelConfigs()
    }

    function parsePanelConfigs() {
        panelList = []
        var configs = cfg_panelConfigs

        if (!configs || configs.length === 0) {
            var homePath = Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString()
            if (homePath.startsWith("file://")) {
                homePath = homePath.substring(7)
            }
            panelList.push({ folderPath: homePath })
        } else {
            for (var i = 0; i < configs.length; i++) {
                var parts = configs[i].split("|")
                if (parts.length >= 1) {
                    panelList.push({ folderPath: parts[0] })
                }
            }
        }
        panelListChanged()
    }

    // Determine effective layout based on mode and panel count
    readonly property bool previewUseGrid: {
        if (cfg_layoutMode === "stack") return false
        if (cfg_layoutMode === "grid") return true
        return panelList.length >= 3
    }

    readonly property int previewColumns: Math.min(cfg_gridColumns, panelList.length)
    readonly property int previewRows: Math.ceil(panelList.length / Math.max(1, previewColumns))

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // Layout mode selection
        Kirigami.FormLayout {
            Layout.fillWidth: true

            ComboBox {
                id: layoutModeCombo
                Kirigami.FormData.label: "Layout mode:"

                textRole: "text"
                valueRole: "value"

                model: [
                    { text: "Auto (stack for 1-2, grid for 3+)", value: "auto" },
                    { text: "Always Stack (vertical)", value: "stack" },
                    { text: "Always Grid", value: "grid" }
                ]

                Component.onCompleted: {
                    for (var i = 0; i < model.length; i++) {
                        if (model[i].value === cfg_layoutMode) {
                            currentIndex = i
                            break
                        }
                    }
                }
            }

            SpinBox {
                id: gridColumnsSpinBox
                Kirigami.FormData.label: "Grid columns:"

                from: 2
                to: 4
                value: 2

                enabled: cfg_layoutMode !== "stack"
            }
        }

        // Preview section header
        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true

            Kirigami.Heading {
                text: "Layout Preview"
                level: 3
            }

            Item { Layout.fillWidth: true }

            Label {
                text: panelList.length + " panel" + (panelList.length !== 1 ? "s" : "")
                opacity: 0.7
            }
        }

        // Visual preview area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 200

            color: Qt.rgba(0, 0, 0, 0.2)
            radius: 8
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)

            // Stack preview (vertical)
            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 4
                visible: !previewUseGrid

                Repeater {
                    model: previewUseGrid ? 0 : panelList.length

                    delegate: Rectangle {
                        width: parent.width
                        height: Math.max(40, (parent.height - (panelList.length - 1) * 4) / panelList.length)
                        color: Qt.rgba(0.3, 0.3, 0.3, 0.8)
                        radius: 4
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Panel " + (index + 1)
                                font.bold: true
                                color: "white"
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: panelList[index] ? panelList[index].folderPath.split("/").pop() : ""
                                font.pixelSize: 10
                                color: Qt.rgba(1, 1, 1, 0.6)
                                elide: Text.ElideMiddle
                                width: parent.parent.width - 16
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            // Grid preview
            Grid {
                anchors.fill: parent
                anchors.margins: 16
                columns: previewColumns
                spacing: 4
                visible: previewUseGrid

                Repeater {
                    model: previewUseGrid ? panelList.length : 0

                    delegate: Rectangle {
                        property int cellWidth: (parent.width - (previewColumns - 1) * 4) / previewColumns
                        property int cellHeight: (parent.height - (previewRows - 1) * 4) / previewRows

                        width: cellWidth
                        height: cellHeight
                        color: Qt.rgba(0.3, 0.3, 0.3, 0.8)
                        radius: 4
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Panel " + (index + 1)
                                font.bold: true
                                color: "white"
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: panelList[index] ? panelList[index].folderPath.split("/").pop() : ""
                                font.pixelSize: 10
                                color: Qt.rgba(1, 1, 1, 0.6)
                                elide: Text.ElideMiddle
                                width: parent.parent.width - 16
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            // Empty state
            Label {
                anchors.centerIn: parent
                text: "No panels configured"
                visible: panelList.length === 0
                opacity: 0.5
            }
        }

        // Help text
        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Label {
            Layout.fillWidth: true
            text: "The layout automatically adjusts based on how many panels you have. " +
                  "Add or remove panels in the 'Panels' tab."
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        Label {
            Layout.fillWidth: true
            text: previewUseGrid
                ? "Current: Grid layout (" + previewColumns + " columns x " + previewRows + " rows)"
                : "Current: Stack layout (vertical)"
            font.italic: true
            opacity: 0.7
        }
    }
}
