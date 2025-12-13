import QtQuick
import QtQuick.Controls
import Qt.labs.platform as Platform
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// PlasmoidItem is the root type for all Plasma 6 widgets
// This is now a multi-fence container that holds stacked FencePanel items
PlasmoidItem {
    id: root

    // Disable Plasma's default background frame
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Default values for new panels
    readonly property int defaultIconSize: 48
    readonly property real defaultOpacity: 0.7
    readonly property int defaultExpandedHeight: 250

    // Handle bar height (used for height calculations)
    readonly property int handleHeight: 24

    // Grid layout configuration
    readonly property string layoutMode: Plasmoid.configuration.layoutMode || "auto"
    readonly property int gridColumns: Plasmoid.configuration.gridColumns || 2

    // Determine if we should use grid layout
    readonly property bool useGridLayout: {
        if (layoutMode === "stack") return false
        if (layoutMode === "grid") return true
        // Auto mode: use grid for 3+ panels
        return panelModel.count >= 3
    }

    // Calculate grid dimensions
    readonly property int effectiveGridColumns: Math.min(gridColumns, panelModel.count)
    readonly property int gridRows: Math.ceil(panelModel.count / effectiveGridColumns)

    // Grid spacing
    readonly property int gridSpacing: 4

    // Set preferred size for the widget
    preferredRepresentation: fullRepresentation

    // ListModel to hold panel configurations
    ListModel {
        id: panelModel
    }

    // Parse panel configs from StringList configuration
    // Format: "folderPath|collapsed|opacity|iconSize|expandedHeight"
    function parsePanelConfigs() {
        panelModel.clear()

        var configs = Plasmoid.configuration.panelConfigs
        if (!configs || configs.length === 0) {
            // Default: one panel with home directory
            var homePath = Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString()
            if (homePath.startsWith("file://")) {
                homePath = homePath.substring(7)
            }
            panelModel.append({
                folderPath: homePath,
                collapsed: false,
                panelOpacity: defaultOpacity,
                iconSize: defaultIconSize,
                expandedHeight: defaultExpandedHeight
            })
            return
        }

        for (var i = 0; i < configs.length; i++) {
            var parts = configs[i].split("|")
            if (parts.length >= 5) {
                panelModel.append({
                    folderPath: parts[0],
                    collapsed: parts[1] === "true",
                    panelOpacity: parseFloat(parts[2]) || defaultOpacity,
                    iconSize: parseInt(parts[3]) || defaultIconSize,
                    expandedHeight: parseInt(parts[4]) || defaultExpandedHeight
                })
            }
        }
    }

    // Serialize panel configs back to StringList for persistence
    function savePanelConfigs() {
        var configs = []
        for (var i = 0; i < panelModel.count; i++) {
            var panel = panelModel.get(i)
            configs.push(
                panel.folderPath + "|" +
                panel.collapsed + "|" +
                panel.panelOpacity + "|" +
                panel.iconSize + "|" +
                panel.expandedHeight
            )
        }
        Plasmoid.configuration.panelConfigs = configs
    }

    // Handle collapse state change from a panel
    function onPanelCollapsedChanged(index, collapsed) {
        if (index >= 0 && index < panelModel.count) {
            panelModel.setProperty(index, "collapsed", collapsed)
            savePanelConfigs()
        }
    }

    // Initialize on component completion
    Component.onCompleted: {
        parsePanelConfigs()
    }

    // Re-parse when configuration changes externally (e.g., from config UI)
    Connections {
        target: Plasmoid.configuration
        function onPanelConfigsChanged() {
            parsePanelConfigs()
        }
    }

    // Height of resize handles between panels
    readonly property int resizeHandleHeight: 6

    // Calculate total height for stack layout (including resize handles)
    function calculateStackHeight() {
        var total = 0
        for (var i = 0; i < panelModel.count; i++) {
            var panel = panelModel.get(i)
            total += panel.collapsed ? handleHeight : panel.expandedHeight
            // Add resize handle height between panels (not after last)
            if (i < panelModel.count - 1) {
                total += resizeHandleHeight
            }
        }
        return Math.max(total, handleHeight)
    }

    // Calculate height for grid layout
    function calculateGridHeight() {
        // Find max height for each row
        var rowHeights = []
        for (var i = 0; i < gridRows; i++) {
            rowHeights.push(0)
        }

        for (var i = 0; i < panelModel.count; i++) {
            var panel = panelModel.get(i)
            var row = Math.floor(i / effectiveGridColumns)
            var panelHeight = panel.collapsed ? handleHeight : panel.expandedHeight
            rowHeights[row] = Math.max(rowHeights[row], panelHeight)
        }

        var total = 0
        for (var i = 0; i < rowHeights.length; i++) {
            total += rowHeights[i]
            if (i < rowHeights.length - 1) {
                total += gridSpacing
            }
        }
        return Math.max(total, handleHeight)
    }

    // Calculate total height based on layout mode
    function calculateTotalHeight() {
        return useGridLayout ? calculateGridHeight() : calculateStackHeight()
    }

    // Handle resize drag between panels
    function onPanelResize(index, delta) {
        if (index < 0 || index >= panelModel.count - 1) return

        var currentPanel = panelModel.get(index)
        var nextPanel = panelModel.get(index + 1)

        // Only resize expanded panels
        if (currentPanel.collapsed || nextPanel.collapsed) return

        var newCurrentHeight = Math.max(100, Math.min(500, currentPanel.expandedHeight + delta))
        var newNextHeight = Math.max(100, Math.min(500, nextPanel.expandedHeight - delta))

        // Only apply if both are within bounds
        if (newCurrentHeight >= 100 && newCurrentHeight <= 500 &&
            newNextHeight >= 100 && newNextHeight <= 500) {
            panelModel.setProperty(index, "expandedHeight", newCurrentHeight)
            panelModel.setProperty(index + 1, "expandedHeight", newNextHeight)
        }
    }

    // The full representation is what shows on the desktop
    fullRepresentation: Item {
        id: container

        implicitWidth: root.useGridLayout ? 300 * root.effectiveGridColumns + root.gridSpacing * (root.effectiveGridColumns - 1) : 300
        implicitHeight: calculateTotalHeight()

        // Re-calculate dimensions when model or layout changes
        Connections {
            target: panelModel
            function onCountChanged() {
                container.implicitHeight = Qt.binding(function() { return calculateTotalHeight() })
                container.implicitWidth = Qt.binding(function() {
                    return root.useGridLayout ? 300 * root.effectiveGridColumns + root.gridSpacing * (root.effectiveGridColumns - 1) : 300
                })
            }
            function onDataChanged() {
                container.implicitHeight = Qt.binding(function() { return calculateTotalHeight() })
            }
        }

        // Stack layout for 1-2 panels (or when forced to stack mode)
        Column {
            id: fenceStack
            anchors.fill: parent
            spacing: 0
            visible: !root.useGridLayout

            Repeater {
                id: stackRepeater
                model: root.useGridLayout ? null : panelModel

                delegate: Column {
                    width: fenceStack.width
                    spacing: 0

                    property int delegateIndex: index

                    FencePanel {
                        id: stackPanelDelegate
                        width: parent.width
                        folderPath: model.folderPath
                        panelOpacity: model.panelOpacity
                        iconSize: model.iconSize
                        isCollapsed: model.collapsed
                        expandedHeight: model.expandedHeight
                        panelIndex: delegateIndex

                        onCollapsedChanged: function(idx, collapsed) {
                            root.onPanelCollapsedChanged(idx, collapsed)
                        }
                    }

                    // Resize handle between panels
                    Rectangle {
                        width: parent.width
                        height: root.resizeHandleHeight
                        color: "transparent"
                        visible: delegateIndex < panelModel.count - 1 && panelModel.count > 1

                        Rectangle {
                            anchors.centerIn: parent
                            width: 50
                            height: 4
                            radius: 2
                            color: stackResizeArea.containsMouse || stackResizeArea.pressed
                                ? Kirigami.Theme.highlightColor
                                : Qt.rgba(1, 1, 1, 0.3)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: stackResizeArea
                            anchors.fill: parent
                            cursorShape: Qt.SplitVCursor
                            hoverEnabled: true
                            property real startY: 0

                            onPressed: function(mouse) { startY = mouse.y }
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var delta = mouse.y - startY
                                    root.onPanelResize(delegateIndex, delta)
                                    startY = mouse.y
                                }
                            }
                            onReleased: root.savePanelConfigs()
                        }
                    }
                }
            }
        }

        // Grid layout for 3+ panels (or when forced to grid mode)
        Grid {
            id: fenceGrid
            anchors.fill: parent
            columns: root.effectiveGridColumns
            spacing: root.gridSpacing
            visible: root.useGridLayout

            Repeater {
                id: gridRepeater
                model: root.useGridLayout ? panelModel : null

                delegate: FencePanel {
                    id: gridPanelDelegate

                    // Calculate cell width
                    property int cellWidth: (container.width - root.gridSpacing * (root.effectiveGridColumns - 1)) / root.effectiveGridColumns

                    width: cellWidth
                    folderPath: model.folderPath
                    panelOpacity: model.panelOpacity
                    iconSize: model.iconSize
                    isCollapsed: model.collapsed
                    expandedHeight: model.expandedHeight
                    panelIndex: index

                    onCollapsedChanged: function(idx, collapsed) {
                        root.onPanelCollapsedChanged(idx, collapsed)
                    }
                }
            }

            // Animate grid layout changes
            move: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
