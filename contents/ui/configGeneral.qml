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
    property bool cfg_autoSortEnabled: false
    property var cfg_snapshots: []

    // Snapshot logic
    function saveSnapshot() {
        var now = new Date().toLocaleString()
        var currentConfig = cfg_panelConfigs.join("!!")
        var snapshot = now + "||" + currentConfig
        var newSnapshots = []
        for (var i=0; i<cfg_snapshots.length; i++) newSnapshots.push(cfg_snapshots[i])
        newSnapshots.push(snapshot)
        cfg_snapshots = newSnapshots
    }

    function restoreSnapshot(index) {
        if (index >= 0 && index < cfg_snapshots.length) {
            var parts = cfg_snapshots[index].split("||")
            if (parts.length >= 2) {
                cfg_panelConfigs = parts[1].split("!!")
            }
        }
    }

    function deleteSnapshot(index) {
        if (index >= 0 && index < cfg_snapshots.length) {
            var newSnapshots = []
            for (var i=0; i<cfg_snapshots.length; i++) {
                if (i !== index) newSnapshots.push(cfg_snapshots[i])
            }
            cfg_snapshots = newSnapshots
        }
    }

    // Default values for new panels
    readonly property real defaultOpacity: 0.7
    readonly property int defaultIconSize: 48
    readonly property int defaultExpandedHeight: 250
    readonly property string defaultSortRules: ""
    readonly property int defaultPageId: 0

    // Resolve the user's home path
    function homePath() {
        var home = Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString()
        return home.startsWith("file://") ? home.substring(7) : home
    }

    // Clamp and sanitize panel values
    function sanitizePanel(panel) {
        panel = panel || {}
        var safeFolder = panel.folderPath && panel.folderPath.length > 0 ? panel.folderPath : homePath()
        var safeOpacity = Math.min(1.0, Math.max(0.1, parseFloat(panel.panelOpacity) || defaultOpacity))
        var safeIconSize = Math.min(128, Math.max(24, parseInt(panel.iconSize) || defaultIconSize))
        var safeHeight = Math.min(800, Math.max(100, parseInt(panel.expandedHeight) || defaultExpandedHeight))

        return {
            folderPath: safeFolder,
            collapsed: !!panel.collapsed,
            panelOpacity: safeOpacity,
            iconSize: safeIconSize,
            expandedHeight: safeHeight,
            sortRules: panel.sortRules || defaultSortRules,
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

    function refreshPanels() {
        panelList = panelList.map(function(panel) { return sanitizePanel(panel) })
        panelListChanged()
        panelRepeater.model = panelList.length
    }

    Component.onCompleted: parsePanelConfigs()
    onCfg_panelConfigsChanged: parsePanelConfigs()

    function parsePanelConfigs() {
        panelList = []
        var configs = cfg_panelConfigs
        if (!configs || configs.length === 0) {
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
                        panelOpacity: parts[2],
                        iconSize: parts[3],
                        expandedHeight: parts[4],
                        sortRules: parts[5] || "",
                        pageId: parts[6] || 0
                    }))
                }
            }
        }
        if (panelList.length === 0) panelList.push(sanitizePanel({}))
        refreshPanels()
    }

    function savePanelConfigs() {
        var configs = []
        for (var i = 0; i < panelList.length; i++) {
            var panel = sanitizePanel(panelList[i])
            configs.push(
                panel.folderPath + "|" +
                panel.collapsed + "|" +
                panel.panelOpacity + "|" +
                panel.iconSize + "|" +
                panel.expandedHeight + "|" +
                panel.sortRules + "|" +
                panel.pageId
            )
        }
        cfg_panelConfigs = configs
    }

    function addPanel() {
        panelList.push(sanitizePanel({}))
        refreshPanels()
        savePanelConfigs()
    }

    function removePanel(index) {
        if (panelList.length <= 1) return
        panelList.splice(index, 1)
        refreshPanels()
        savePanelConfigs()
    }

    function updatePanel(index, property, value) {
        if (index >= 0 && index < panelList.length) {
            panelList[index][property] = value
            refreshPanels()
            savePanelConfigs()
        }
    }

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

        Kirigami.Heading { text: "Global Settings"; level: 2 }

        Kirigami.FormLayout {
            CheckBox {
                Kirigami.FormData.label: "Automatic Sorting:"
                text: "Move files from Desktop matching rules"
                checked: cfg_autoSortEnabled
                onToggled: cfg_autoSortEnabled = checked
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading { text: "Snapshots"; level: 2 }
            Item { Layout.fillWidth: true }
            Button {
                icon.name: "document-save"
                text: "Take Snapshot"
                onClicked: saveSnapshot()
            }
        }

        Label {
            text: "Snapshots save the current layout and panel configurations so you can restore them later."
            opacity: 0.6; Layout.fillWidth: true; wrapMode: Text.WordWrap
        }

        Repeater {
            model: cfg_snapshots.length
            delegate: RowLayout {
                Layout.fillWidth: true; spacing: Kirigami.Units.smallSpacing
                Label { text: cfg_snapshots[index].split("||")[0]; Layout.fillWidth: true }
                Button { icon.name: "document-revert"; text: "Restore"; onClicked: restoreSnapshot(index) }
                Button { icon.name: "edit-delete"; onClicked: deleteSnapshot(index) }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading { text: "Fence Panels"; level: 2 }
            Item { Layout.fillWidth: true }
            Button { icon.name: "list-add"; text: "Add Panel"; onClicked: addPanel() }
        }

        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                width: parent.width; spacing: Kirigami.Units.largeSpacing
                Repeater {
                    id: panelRepeater
                    model: panelList.length
                    delegate: Kirigami.Card {
                        Layout.fillWidth: true
                        property int panelIndex: index
                        property var panelData: panelList[index] || {}
                        header: RowLayout {
                            Kirigami.Heading { text: "Panel " + (panelIndex + 1); level: 3 }
                            Item { Layout.fillWidth: true }
                            Button {
                                icon.name: "edit-delete"; text: "Remove"
                                enabled: panelList.length > 1; onClicked: removePanel(panelIndex)
                            }
                        }
                        contentItem: Kirigami.FormLayout {
                            RowLayout {
                                Kirigami.FormData.label: "Folder:"
                                TextField {
                                    Layout.fillWidth: true; text: panelData.folderPath || ""
                                    onTextEdited: updatePanel(panelIndex, "folderPath", text)
                                }
                                Button {
                                    icon.name: "folder-open"
                                    onClicked: {
                                        folderDialog.targetPanelIndex = panelIndex
                                        folderDialog.currentFolder = panelData.folderPath ? "file://" + panelData.folderPath : Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation)
                                        folderDialog.open()
                                    }
                                }
                            }
                            TextField {
                                Kirigami.FormData.label: "Sort Rules (extensions):"
                                Layout.fillWidth: true; text: panelData.sortRules || ""
                                placeholderText: "e.g. jpg, png, pdf"
                                onTextEdited: updatePanel(panelIndex, "sortRules", text)
                            }
                            RowLayout {
                                Kirigami.FormData.label: "Desktop Page:"
                                ComboBox {
                                    id: pageCombo
                                    Layout.fillWidth: true
                                    
                                    // Determine available pages based on system
                                    property var pageOptions: []
                                    
                                    Component.onCompleted: {
                                        // Check if we have advanced page config
                                        var configVersion = plasmoid ? (plasmoid.configuration.pageConfigVersion || 0) : 0
                                        
                                        if (configVersion === 1 && plasmoid.configuration.advancedPageConfig) {
                                            try {
                                                var pageConfig = JSON.parse(plasmoid.configuration.advancedPageConfig)
                                                pageOptions = pageConfig.pages || []
                                            } catch (e) {
                                                console.error("Error parsing page config:", e)
                                                // Fall back to legacy
                                                for (var i = 1; i <= 5; i++) {
                                                    pageOptions.push({id: "page-" + (i-1), name: "Page " + i})
                                                }
                                            }
                                        } else {
                                            // Legacy system - use page count
                                            var pageCount = plasmoid ? plasmoid.configuration.pageCount : 1
                                            for (var i = 1; i <= pageCount; i++) {
                                                pageOptions.push({id: "page-" + (i-1), name: "Page " + i})
                                            }
                                        }
                                        
                                        // Set current value
                                        var currentPageId = "page-" + (panelData.pageId || 0)
                                        for (var j = 0; j < pageOptions.length; j++) {
                                            if (pageOptions[j].id === currentPageId) {
                                                currentIndex = j
                                                break
                                            }
                                        }
                                    }
                                    
                                    textRole: "name"
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0 && currentIndex < pageOptions.length) {
                                            // Find the page ID (e.g., "page-0", "page-1")
                                            var selectedPageId = pageOptions[currentIndex].id
                                            var pageId = parseInt(selectedPageId.split("-")[1])
                                            updatePanel(panelIndex, "pageId", pageId)
                                        }
                                    }
                                }
                                Label { text: "Page" }
                            }
                            RowLayout {
                                Kirigami.FormData.label: "Opacity:"
                                Slider {
                                    id: opSlider; Layout.fillWidth: true; from: 0.1; to: 1.0; stepSize: 0.05
                                    value: panelData.panelOpacity || 0.7; onMoved: updatePanel(panelIndex, "panelOpacity", value)
                                }
                                Label { text: Math.round(opSlider.value * 100) + "%"; Layout.preferredWidth: 45 }
                            }
                            RowLayout {
                                Kirigami.FormData.label: "Icon size:"
                                SpinBox {
                                    from: 24; to: 128; stepSize: 8; value: panelData.iconSize || 48
                                    onValueModified: updatePanel(panelIndex, "iconSize", value)
                                }
                                Label { text: "pixels" }
                            }
                            RowLayout {
                                Kirigami.FormData.label: "Panel height:"
                                SpinBox {
                                    from: 100; to: 800; stepSize: 25; value: panelData.expandedHeight || 250
                                    onValueModified: updatePanel(panelIndex, "expandedHeight", value)
                                }
                                Label { text: "pixels" }
                            }
                        }
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }
        Kirigami.Heading { text: "Tips"; level: 4 }
        Label { text: "• Double-click a panel's handle bar to rollup/unroll"; opacity: 0.7 }
        Label { text: "• Hover over a rolled-up panel to peek at its contents"; opacity: 0.7 }
        Label { text: "• Double-click the widget background to hide/show all fences"; opacity: 0.7 }
        Label { text: "• Drag the bottom of an expanded panel to resize it"; opacity: 0.7 }
    }
}