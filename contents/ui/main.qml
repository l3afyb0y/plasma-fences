import QtQuick
import QtQuick.Controls
import Qt.labs.platform as Platform
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

// PlasmoidItem is the root type for all Plasma 6 widgets
PlasmoidItem {
    id: root

    // Disable Plasma's default background frame
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Default values for new panels
    readonly property int defaultIconSize: 48
    readonly property real defaultOpacity: 0.7
    readonly property int defaultExpandedHeight: 250
    readonly property string defaultSortRules: ""
    readonly property int defaultPageId: 0

    // Handle bar height
    readonly property int handleHeight: 24

    // Quick-hide state
    property bool isHidden: false

    // Current page state
    property int currentPage: Plasmoid.configuration.currentPage || 0

    // Resolve the user's home path
    function homePath() {
        var home = Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString()
        return home.startsWith("file://") ? home.substring(7) : home
    }

    // Clamp and sanitize a panel configuration object
    function sanitizePanelConfig(panel) {
        panel = panel || {}
        var safeFolder = panel.folderPath && panel.folderPath.length > 0 ? panel.folderPath : homePath()
        var safeOpacity = panel.panelOpacity
        if (isNaN(safeOpacity)) safeOpacity = defaultOpacity
        safeOpacity = Math.min(1.0, Math.max(0.1, safeOpacity))

        var safeIconSize = parseInt(panel.iconSize)
        if (isNaN(safeIconSize)) safeIconSize = defaultIconSize
        safeIconSize = Math.min(128, Math.max(24, safeIconSize))

        var safeHeight = parseInt(panel.expandedHeight)
        if (isNaN(safeHeight)) safeHeight = defaultExpandedHeight
        safeHeight = Math.min(800, Math.max(100, safeHeight))

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

    // Migrate legacy single-panel config
    function migrateLegacyPanel() {
        return sanitizePanelConfig({
            folderPath: Plasmoid.configuration.folderPath,
            collapsed: Plasmoid.configuration.collapsed,
            panelOpacity: Plasmoid.configuration.backgroundOpacity,
            iconSize: Plasmoid.configuration.iconSize,
            expandedHeight: defaultExpandedHeight,
            sortRules: "",
            pageId: 0
        })
    }

    // ListModels
    ListModel { id: allPanelsModel }
    ListModel { id: filteredPanelModel }

    function updateFilteredModel() {
        filteredPanelModel.clear()
        for (var i = 0; i < allPanelsModel.count; i++) {
            var panel = allPanelsModel.get(i)
            if (panel.pageId === root.currentPage) {
                var item = {}
                for (var key in panel) item[key] = panel[key]
                item.originalIndex = i
                filteredPanelModel.append(item)
            }
        }
    }

    function parsePanelConfigs() {
        allPanelsModel.clear()
        var configs = Plasmoid.configuration.panelConfigs
        if (!configs || configs.length === 0) {
            allPanelsModel.append(migrateLegacyPanel())
            savePanelConfigs()
            return
        }

        for (var i = 0; i < configs.length; i++) {
            var parts = configs[i].split("|")
            if (parts.length >= 5) {
                allPanelsModel.append(sanitizePanelConfig({
                    folderPath: parts[0],
                    collapsed: parts[1] === "true",
                    panelOpacity: parseFloat(parts[2]) || defaultOpacity,
                    iconSize: parseInt(parts[3]) || defaultIconSize,
                    expandedHeight: parseInt(parts[4]) || defaultExpandedHeight,
                    sortRules: parts[5] || "",
                    pageId: parseInt(parts[6]) || 0
                }))
            }
        }
        updateFilteredModel()
    }

    function savePanelConfigs() {
        var configs = []
        for (var i = 0; i < allPanelsModel.count; i++) {
            var panel = sanitizePanelConfig(allPanelsModel.get(i))
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
        Plasmoid.configuration.panelConfigs = configs
    }

    // Auto-sort
    Timer {
        id: sortTimer
        interval: 10000
        running: Plasmoid.configuration.autoSortEnabled
        repeat: true
        onTriggered: runAutoSort()
    }

    Plasma5Support.DataSource {
        id: sortExecutable
        engine: "executable"
        connectedSources: []
    }

    function runAutoSort() {
        var desktopPath = homePath() + "/Desktop"
        for (var i = 0; i < allPanelsModel.count; i++) {
            var panel = allPanelsModel.get(i)
            if (panel.sortRules) {
                var extensions = panel.sortRules.split(",")
                for (var j = 0; j < extensions.length; j++) {
                    var ext = extensions[j].trim()
                    if (ext.length > 0) {
                        var cmd = 'find "' + desktopPath + '" -maxdepth 1 -iname "*.' + ext + '" -exec mv -n {} "' + panel.folderPath + '/" \;'
                        sortExecutable.connectSource(cmd)
                    }
                }
            }
        }
    }

    function onPanelCollapsedChanged(indexInFiltered, collapsed) {
        if (indexInFiltered >= 0 && indexInFiltered < filteredPanelModel.count) {
            var originalIndex = filteredPanelModel.get(indexInFiltered).originalIndex
            allPanelsModel.setProperty(originalIndex, "collapsed", collapsed)
            savePanelConfigs()
            updateFilteredModel()
        }
    }

    function onPanelResize(indexInFiltered, delta) {
        if (indexInFiltered < 0 || indexInFiltered >= filteredPanelModel.count) return
        var originalIndex = filteredPanelModel.get(indexInFiltered).originalIndex
        var panel = allPanelsModel.get(originalIndex)
        if (panel.collapsed) return
        var newHeight = Math.max(100, Math.min(800, panel.expandedHeight + delta))
        if (newHeight !== panel.expandedHeight) {
            allPanelsModel.setProperty(originalIndex, "expandedHeight", newHeight)
            savePanelConfigs()
            updateFilteredModel()
        }
    }

    Component.onCompleted: parsePanelConfigs()

    Connections {
        target: Plasmoid.configuration
        function onPanelConfigsChanged() { parsePanelConfigs() }
        function onAutoSortEnabledChanged() { sortTimer.running = Plasmoid.configuration.autoSortEnabled }
        function onCurrentPageChanged() {
            root.currentPage = Plasmoid.configuration.currentPage
            updateFilteredModel()
        }
    }

    readonly property string layoutMode: Plasmoid.configuration.layoutMode || "auto"
    readonly property int gridColumns: Plasmoid.configuration.gridColumns || 2
    readonly property bool useGridLayout: layoutMode === "stack" ? false : (layoutMode === "grid" ? true : filteredPanelModel.count >= 3)
    readonly property int effectiveGridColumns: Math.min(gridColumns, filteredPanelModel.count)
    readonly property int gridSpacing: 4
    readonly property int resizeHandleHeight: 6

    function calculateTotalHeight() {
        var total = 0
        if (useGridLayout) {
            var rows = Math.ceil(filteredPanelModel.count / Math.max(1, effectiveGridColumns))
            var rowHeights = []
            for (var r=0; r<rows; r++) rowHeights.push(0)
            for (var i=0; i<filteredPanelModel.count; i++) {
                var p = filteredPanelModel.get(i)
                var row = Math.floor(i / effectiveGridColumns)
                rowHeights[row] = Math.max(rowHeights[row], p.collapsed ? handleHeight : p.expandedHeight)
            }
            for (var h of rowHeights) total += h
            total += (rows - 1) * gridSpacing
        } else {
            for (var i=0; i<filteredPanelModel.count; i++) {
                var p = filteredPanelModel.get(i)
                total += p.collapsed ? handleHeight : p.expandedHeight
                if (!p.collapsed && i < filteredPanelModel.count - 1) total += resizeHandleHeight
            }
        }
        if (Plasmoid.configuration.pageCount > 1) total += 24
        return Math.max(total, handleHeight)
    }

    fullRepresentation: Item {
        id: container
        implicitWidth: root.useGridLayout ? 300 * root.effectiveGridColumns + root.gridSpacing * (root.effectiveGridColumns - 1) : 300
        implicitHeight: calculateTotalHeight()

        MouseArea {
            anchors.fill: parent
            z: -1
            onDoubleClicked: root.isHidden = !root.isHidden
        }

        opacity: root.isHidden ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: parent.height - (pageDots.visible ? pageDots.height : 0)

                Column {
                    id: fenceStack
                    anchors.fill: parent
                    spacing: 0
                    visible: !root.useGridLayout

                    Repeater {
                        model: root.useGridLayout ? null : filteredPanelModel
                        delegate: Column {
                            width: fenceStack.width
                            spacing: 0
                            property int delegateIndex: index
                            FencePanel {
                                width: parent.width
                                folderPath: model.folderPath
                                panelOpacity: model.panelOpacity
                                iconSize: model.iconSize
                                isCollapsed: model.collapsed
                                expandedHeight: model.expandedHeight
                                panelIndex: delegateIndex
                                onCollapsedChanged: (idx, collapsed) => root.onPanelCollapsedChanged(idx, collapsed)
                            }
                            Rectangle {
                                width: parent.width; height: root.resizeHandleHeight; color: "transparent"
                                visible: !model.collapsed
                                Rectangle {
                                    anchors.centerIn: parent; width: 50; height: 4; radius: 2
                                    color: stackResizeArea.containsMouse || stackResizeArea.pressed ? Kirigami.Theme.highlightColor : Qt.rgba(1, 1, 1, 0.3)
                                }
                                MouseArea {
                                    id: stackResizeArea
                                    anchors.fill: parent; cursorShape: Qt.SplitVCursor; hoverEnabled: true
                                    property real lastY: 0
                                    onPressed: (mouse) => lastY = mouse.y
                                    onPositionChanged: (mouse) => { if (pressed) { root.onPanelResize(delegateIndex, mouse.y - lastY); } }
                                    onReleased: root.savePanelConfigs()
                                }
                            }
                        }
                    }
                }

                Grid {
                    id: fenceGrid
                    anchors.fill: parent
                    columns: root.effectiveGridColumns
                    spacing: root.gridSpacing
                    visible: root.useGridLayout

                    Repeater {
                        model: root.useGridLayout ? filteredPanelModel : null
                        delegate: FencePanel {
                            property int cellWidth: (container.width - root.gridSpacing * (root.effectiveGridColumns - 1)) / root.effectiveGridColumns
                            width: cellWidth
                            folderPath: model.folderPath
                            panelOpacity: model.panelOpacity
                            iconSize: model.iconSize
                            isCollapsed: model.collapsed
                            expandedHeight: model.expandedHeight
                            panelIndex: index
                            onCollapsedChanged: (idx, collapsed) => root.onPanelCollapsedChanged(idx, collapsed)
                        }
                    }
                }
            }

            Row {
                id: pageDots
                height: 24
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                visible: Plasmoid.configuration.pageCount > 1
                Repeater {
                    model: Plasmoid.configuration.pageCount
                    delegate: Rectangle {
                        width: 8; height: 8; radius: 4
                        color: index === root.currentPage ? Kirigami.Theme.highlightColor : Qt.rgba(1, 1, 1, 0.3)
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Plasmoid.configuration.currentPage = index }
                    }
                }
            }
        }
    }
}