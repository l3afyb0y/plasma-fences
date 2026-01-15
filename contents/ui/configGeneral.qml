import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configPage

    // Internal model for panel configurations
    property var panelList: []

    // Configuration property for saving
    property var cfg_panelConfigs: []

    // Default values for new panels
    readonly property real defaultOpacity: 0.7
    readonly property int defaultIconSize: 48
    readonly property int defaultExpandedHeight: 250

    // Resolve the user's home path without the file:// prefix
    function homePath() {
        var home = Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString()
        return home.startsWith("file://") ? home.substring(7) : home
    }

    // Clamp and sanitize panel values
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
        safeHeight = Math.min(500, Math.max(100, safeHeight))

        return {
            folderPath: safeFolder,
            collapsed: !!panel.collapsed,
            panelOpacity: safeOpacity,
            iconSize: safeIconSize,
            expandedHeight: safeHeight
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
            expandedHeight: defaultExpandedHeight
        })
    }

    // Refresh bindings and repeater after mutations
    function refreshPanels() {
        panelList = panelList.map(function(panel) { return sanitizePanel(panel) })
        panelListChanged()
        panelRepeater.model = panelList.length
    }

    // Parse configs on load
    Component.onCompleted: {
        parsePanelConfigs()
    }

    onCfg_panelConfigsChanged: parsePanelConfigs()

    // Parse StringList into internal model
    function parsePanelConfigs() {
        panelList = []
        var configs = cfg_panelConfigs

        if (!configs || configs.length === 0) {
            // Default: one panel using legacy settings when available
            panelList.push(legacyPanelConfig())
            refreshPanels()
            savePanelConfigs()
            return
        } else {
            for (var i = 0; i < configs.length; i++) {
                var parts = configs[i].split("|")
                if (parts.length >= 5) {
                    panelList.push(sanitizePanel({
                        folderPath: parts[0],
                        collapsed: parts[1] === "true",
                        panelOpacity: parseFloat(parts[2]) || defaultOpacity,
                        iconSize: parseInt(parts[3]) || defaultIconSize,
                        expandedHeight: parseInt(parts[4]) || defaultExpandedHeight
                    }))
                }
            }
        }

        if (panelList.length === 0) {
            panelList.push(sanitizePanel({}))
            savePanelConfigs()
        }

        refreshPanels()
    }

    // Serialize internal model back to StringList
    function savePanelConfigs() {
        var configs = []
        for (var i = 0; i < panelList.length; i++) {
            var panel = sanitizePanel(panelList[i])
            configs.push(
                panel.folderPath + "|" +
                panel.collapsed + "|" +
                panel.panelOpacity + "|" +
                panel.iconSize + "|" +
                panel.expandedHeight
            )
        }
        cfg_panelConfigs = configs
    }

    // Add a new panel
    function addPanel() {
        panelList.push(sanitizePanel({
            folderPath: homePath(),
            collapsed: false,
            panelOpacity: defaultOpacity,
            iconSize: defaultIconSize,
            expandedHeight: defaultExpandedHeight
        }))
        refreshPanels()
        savePanelConfigs()
    }

    // Remove a panel
    function removePanel(index) {
        if (panelList.length <= 1) {
            return  // Keep at least one panel
        }
        panelList.splice(index, 1)
        refreshPanels()
        savePanelConfigs()
    }

    // Update a panel property
    function updatePanel(index, property, value) {
        if (index >= 0 && index < panelList.length) {
            panelList[index][property] = value
            refreshPanels()
            savePanelConfigs()
        }
    }

    // Folder dialog (shared)
    FolderDialog {
        id: folderDialog
        title: "Select Folder"
        property int targetPanelIndex: -1

        onAccepted: {
            if (targetPanelIndex >= 0) {
                var path = selectedFolder.toString().replace("file://", "")
                updatePanel(targetPanelIndex, "folderPath", path)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // Header with Add button
        RowLayout {
            Layout.fillWidth: true

            Kirigami.Heading {
                text: "Fence Panels"
                level: 2
            }

            Item { Layout.fillWidth: true }

            Button {
                icon.name: "list-add"
                text: "Add Panel"
                onClicked: addPanel()
            }
        }

        // Separator
        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // Scrollable list of panels
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.largeSpacing

                Repeater {
                    id: panelRepeater
                    model: panelList.length

                    delegate: Kirigami.Card {
                        Layout.fillWidth: true

                        property int panelIndex: index
                        property var panelData: panelList[index] || {}

                        header: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Heading {
                                text: "Panel " + (panelIndex + 1)
                                level: 3
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                icon.name: "edit-delete"
                                text: "Remove"
                                enabled: panelList.length > 1
                                onClicked: removePanel(panelIndex)
                            }
                        }

                        contentItem: Kirigami.FormLayout {
                            // Folder path
                            RowLayout {
                                Kirigami.FormData.label: "Folder:"
                                spacing: Kirigami.Units.smallSpacing

                                TextField {
                                    id: folderField
                                    Layout.fillWidth: true
                                    text: panelData.folderPath || ""
                                    placeholderText: "Select a folder..."
                                    onTextEdited: updatePanel(panelIndex, "folderPath", text)
                                }

                                Button {
                                    icon.name: "folder-open"
                                    onClicked: {
                                        folderDialog.targetPanelIndex = panelIndex
                                        folderDialog.currentFolder = panelData.folderPath
                                            ? "file://" + panelData.folderPath
                                            : Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation)
                                        folderDialog.open()
                                    }
                                }
                            }

                            // Opacity slider
                            RowLayout {
                                Kirigami.FormData.label: "Opacity:"
                                spacing: Kirigami.Units.smallSpacing

                                Slider {
                                    id: opacitySlider
                                    Layout.fillWidth: true
                                    from: 0.1
                                    to: 1.0
                                    stepSize: 0.05
                                    value: panelData.panelOpacity || 0.7
                                    onMoved: updatePanel(panelIndex, "panelOpacity", value)
                                }

                                Label {
                                    text: Math.round(opacitySlider.value * 100) + "%"
                                    Layout.preferredWidth: 45
                                }
                            }

                            // Icon size
                            RowLayout {
                                Kirigami.FormData.label: "Icon size:"
                                spacing: Kirigami.Units.smallSpacing

                                SpinBox {
                                    id: iconSizeSpinBox
                                    from: 24
                                    to: 128
                                    stepSize: 8
                                    value: panelData.iconSize || 48
                                    onValueModified: updatePanel(panelIndex, "iconSize", value)
                                }

                                Label {
                                    text: "pixels"
                                }
                            }

                            // Expanded height
                            RowLayout {
                                Kirigami.FormData.label: "Panel height:"
                                spacing: Kirigami.Units.smallSpacing

                                SpinBox {
                                    id: heightSpinBox
                                    from: 100
                                    to: 500
                                    stepSize: 25
                                    value: panelData.expandedHeight || 250
                                    onValueModified: updatePanel(panelIndex, "expandedHeight", value)
                                }

                                Label {
                                    text: "pixels"
                                }
                            }
                        }
                    }
                }
            }
        }

        // Tips section
        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            text: "Tips"
            level: 4
        }

        Label {
            text: "• Click a panel's handle bar to collapse/expand it"
            opacity: 0.7
        }

        Label {
            text: "• When a panel collapses, panels below slide up automatically"
            opacity: 0.7
        }

        Label {
            text: "• Drag files onto a panel to copy them to its folder"
            opacity: 0.7
        }
    }
}
