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
    property alias cfg_pageCount: pageCountSpinBox.value
    property var cfg_panelConfigs: []

    // Internal panel list for preview
    property var panelList: []

    // Default values mirror the general config page
    readonly property real defaultOpacity: 0.7
    readonly property int defaultIconSize: 48
    readonly property int defaultExpandedHeight: 250
    readonly property int defaultPageId: 0

    // Resolve the user's home path without the file:// prefix
    function homePath() {
        var home = Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString()
        return home.startsWith("file://") ? home.substring(7) : home
    }

    // Clamp and sanitize panel data
    function sanitizePanel(panel) {
        panel = panel || {}
        var safeFolder = panel.folderPath && panel.folderPath.length > 0 ? panel.folderPath : homePath()

        var safeOpacity = panel.panelOpacity
        if (isNaN(safeOpacity)) {
            safeOpacity = defaultOpacity
        }
        safeOpacity = Math.min(1.0, Math.max(0.1, safeOpacity))

        var safeIconSize = parseInt(panel.iconSize)
        if (isNaN(safeIconSize)) {
            safeIconSize = defaultIconSize
        }
        safeIconSize = Math.min(128, Math.max(24, safeIconSize))

        var safeHeight = parseInt(panel.expandedHeight)
        if (isNaN(safeHeight)) {
            safeHeight = defaultExpandedHeight
        }
        safeHeight = Math.min(800, Math.max(100, safeHeight))

        return {
            folderPath: safeFolder,
            collapsed: !!panel.collapsed,
            panelOpacity: safeOpacity,
            iconSize: safeIconSize,
            expandedHeight: safeHeight,
            sortRules: panel.sortRules || "",
            pageId: parseInt(panel.pageId) || defaultPageId
        }
    }

    // Legacy single-panel configuration fallback
    function legacyPanelConfig() {
        var hasPlasmoidConfig = typeof plasmoid !== "undefined" && plasmoid.configuration
        return sanitizePanel({
            folderPath: hasPlasmoidConfig ? plasmoid.configuration.folderPath : "",
            collapsed: hasPlasmoidConfig ? plasmoid.configuration.collapsed : false,
            panelOpacity: hasPlasmoidConfig ? plasmoid.configuration.backgroundOpacity : defaultOpacity,
            iconSize: hasPlasmoidConfig ? plasmoid.configuration.iconSize : defaultIconSize,
            expandedHeight: defaultExpandedHeight,
            sortRules: "",
            pageId: 0
        })
    }

    function serializePanel(panel) {
        var safePanel = sanitizePanel(panel)
        return safePanel.folderPath + "|" +
                safePanel.collapsed + "|" +
                safePanel.panelOpacity + "|" +
                safePanel.iconSize + "|" +
                safePanel.expandedHeight + "|" +
                safePanel.sortRules + "|" +
                safePanel.pageId
    }

    Component.onCompleted: {
        parsePanelConfigs()
    }

    onCfg_panelConfigsChanged: parsePanelConfigs()

    function parsePanelConfigs() {
        panelList = []
        var configs = cfg_panelConfigs

        if (!configs || configs.length === 0) {
            var legacyPanel = legacyPanelConfig()
            panelList.push(legacyPanel)
            cfg_panelConfigs = [serializePanel(legacyPanel)]
        } else {
            for (var i = 0; i < configs.length; i++) {
                var parts = configs[i].split("|")
                if (parts.length >= 1) {
                    panelList.push(sanitizePanel({
                        folderPath: parts[0],
                        collapsed: parts.length >= 2 ? parts[1] === "true" : false,
                        panelOpacity: parts.length >= 3 ? parseFloat(parts[2]) : defaultOpacity,
                        iconSize: parts.length >= 4 ? parseInt(parts[3]) : defaultIconSize,
                        expandedHeight: parts.length >= 5 ? parseInt(parts[4]) : defaultExpandedHeight,
                        sortRules: parts.length >= 6 ? parts[5] : "",
                        pageId: parts.length >= 7 ? parseInt(parts[6]) : 0
                    }))
                }
            }
        }

        if (panelList.length === 0) {
            var fallbackPanel = sanitizePanel({})
            panelList.push(fallbackPanel)
            cfg_panelConfigs = [serializePanel(fallbackPanel)]
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

            SpinBox {
                id: pageCountSpinBox
                Kirigami.FormData.label: "Desktop pages:"

                from: 1
                to: 5
                value: 1
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
