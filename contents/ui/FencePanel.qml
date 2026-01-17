import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Qt.labs.platform as Platform
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

// FencePanel - A single collapsible fence container
// Used by main.qml in a Column/Repeater for stacking multiple panels
Item {
    id: fencePanel

    // Panel configuration properties (set by parent)
    property string folderPath: ""
    property real panelOpacity: 0.7
    property int iconSize: 48
    property bool isCollapsed: false
    property int expandedHeight: 250
    property int panelIndex: 0

    // Handle bar height (constant)
    readonly property int handleHeight: 24

    // Signal emitted when collapse state changes (parent persists this)
    signal collapsedChanged(int index, bool collapsed)

    // Computed target folder path
    readonly property string targetFolderPath: {
        if (folderPath && folderPath.length > 0) {
            return folderPath
        }
        // Fall back to user's home directory
        var path = Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString()
        if (path.startsWith("file://")) {
            path = path.substring(7)
        }
        return path
    }

    // Panel height: collapsed shows only handle, expanded shows full content
    width: parent ? parent.width : 300
    height: isCollapsed && !isPeeking ? handleHeight : expandedHeight

    // State for "Peeking" (hovering over collapsed fence)
    property bool isPeeking: false

    // Timer for auto-rollup when mouse leaves peek area
    Timer {
        id: rollupTimer
        interval: 500
        onTriggered: fencePanel.isPeeking = false
    }

    // Animate height changes for smooth collapse/expand
    Behavior on height {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    // DataSource for running shell commands (file copy)
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            disconnectSource(source)
        }
    }

    // Helper function to copy files to this panel's folder
    function copyFileToFolder(sourceUrl) {
        var sourcePath = sourceUrl.toString().replace("file://", "")
        var command = 'cp -n "' + sourcePath + '" "' + targetFolderPath + '/"'
        executable.connectSource(command)
    }

    // Main container rectangle
    Rectangle {
        id: container

        anchors.fill: parent

        // Track if something is being dragged over
        property bool isDragHovering: false

        // Dark tinted transparent background
        color: Qt.rgba(0, 0, 0, fencePanel.panelOpacity * 0.7)

        // Rounded corners for a polished look
        radius: 8

        // Border only shows when dragging over
        border.width: isDragHovering ? 2 : 0
        border.color: Kirigami.Theme.highlightColor

        Behavior on border.width {
            NumberAnimation { duration: 150 }
        }

        // FolderListModel reads the contents of a directory
        FolderListModel {
            id: folderModel

            folder: "file://" + fencePanel.targetFolderPath

            showDirs: true
            showFiles: true
            showHidden: false

            sortField: FolderListModel.Name
            sortReversed: false
        }

        // Handle bar at the top - click to collapse/expand
        Rectangle {
            id: handleBar

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: fencePanel.handleHeight

            // Slightly lighter dark tint for the handle
            color: Qt.rgba(0.15, 0.15, 0.15, fencePanel.panelOpacity * 0.85)

            // Match parent's corners when collapsed, top corners only when expanded
            radius: container.radius

            // Cover bottom corners when expanded (so handle blends with container)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.radius
                color: parent.color
                visible: !fencePanel.isCollapsed || fencePanel.isPeeking
            }

            // Title label
            Label {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var parts = targetFolderPath.split("/")
                    return parts[parts.length - 1] || "Fence"
                }
                color: "white"
                font.bold: true
                font.pointSize: 9
                elide: Text.ElideRight
                width: parent.width - 60
            }

            // Visual indicator (small horizontal line)
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 3
                radius: 1.5
                color: "white"
                opacity: 0.5
            }

            // Click area for toggling
            MouseArea {
                id: handleMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: {
                    fencePanel.isCollapsed = !fencePanel.isCollapsed
                    fencePanel.isPeeking = false
                    // Emit signal so parent can persist the state
                    fencePanel.collapsedChanged(fencePanel.panelIndex, fencePanel.isCollapsed)
                }

                onDoubleClicked: {
                    // Double click to toggle rollup (Stardock style)
                    fencePanel.isCollapsed = !fencePanel.isCollapsed
                    fencePanel.isPeeking = false
                    fencePanel.collapsedChanged(fencePanel.panelIndex, fencePanel.isCollapsed)
                }

                onEntered: {
                    if (fencePanel.isCollapsed) {
                        rollupTimer.stop()
                        fencePanel.isPeeking = true
                    }
                }

                onExited: {
                    if (fencePanel.isPeeking) {
                        rollupTimer.start()
                    }
                }
            }

            // Hover effect
            states: State {
                when: handleMouseArea.containsMouse
                PropertyChanges {
                    target: handleBar
                    color: Qt.rgba(
                        Kirigami.Theme.highlightColor.r,
                        Kirigami.Theme.highlightColor.g,
                        Kirigami.Theme.highlightColor.b,
                        fencePanel.panelOpacity * 0.85
                    )
                }
            }

            transitions: Transition {
                ColorAnimation { duration: 150 }
            }
        }

        // Drop area wrapping the grid for receiving files
        DropArea {
            id: dropArea

            anchors.top: handleBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            onEntered: function(drag) {
                container.isDragHovering = true
                if (fencePanel.isCollapsed) {
                    rollupTimer.stop()
                    fencePanel.isPeeking = true
                }
            }

            onExited: {
                container.isDragHovering = false
                if (fencePanel.isPeeking) {
                    rollupTimer.start()
                }
            }

            onDropped: function(drop) {
                container.isDragHovering = false

                if (drop.hasUrls) {
                    for (var i = 0; i < drop.urls.length; i++) {
                        fencePanel.copyFileToFolder(drop.urls[i])
                    }
                    drop.accepted = true
                }
            }

            // Grid of icons inside the drop area
            GridView {
                id: iconGrid

                anchors.fill: parent
                anchors.margins: 8
                anchors.topMargin: 4

                // Hide when collapsed and not peeking
                visible: !fencePanel.isCollapsed || fencePanel.isPeeking
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                // MouseArea for keeping peek alive
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onEntered: {
                        if (fencePanel.isPeeking) rollupTimer.stop()
                    }
                    onExited: {
                        if (fencePanel.isPeeking) rollupTimer.start()
                    }
                    onClicked: (mouse) => mouse.accepted = false
                    onPressed: (mouse) => mouse.accepted = false
                }

                // Cell size based on icon size plus padding for label
                cellWidth: fencePanel.iconSize + 16
                cellHeight: fencePanel.iconSize + 32

                // Use the folder model as data source
                model: folderModel

                // Use our custom delegate for each item
                delegate: IconDelegate {
                    iconSize: fencePanel.iconSize
                }

                // Clip content that overflows
                clip: true

                // Scrolling behavior
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 1500
                maximumFlickVelocity: 2000
                pixelAligned: true

                // Smooth scrolling for mouse wheel
                WheelHandler {
                    id: wheelHandler
                    target: iconGrid
                    orientation: Qt.Vertical
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                    onWheel: function(event) {
                        var delta = event.angleDelta.y
                        var newY = iconGrid.contentY - delta

                        // Clamp to bounds
                        newY = Math.max(0, Math.min(newY, iconGrid.contentHeight - iconGrid.height))
                        iconGrid.contentY = newY
                    }
                }

                // Animate contentY changes for smoothness
                Behavior on contentY {
                    SmoothedAnimation {
                        duration: 150
                        velocity: -1
                    }
                }

                // Hide the scrollbar completely
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }
            }
        }
    }
}
