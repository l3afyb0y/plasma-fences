import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
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

    // Icon size from configuration
    readonly property int iconSize: Plasmoid.configuration.iconSize

    // Collapsed state from configuration
    property bool isCollapsed: Plasmoid.configuration.collapsed

    // Handle bar height
    readonly property int handleHeight: 24

    // Expanded height for the container
    readonly property int expandedHeight: 250

    // Get the target folder path (without file:// prefix)
    readonly property string targetFolderPath: {
        if (Plasmoid.configuration.folderPath && Plasmoid.configuration.folderPath.length > 0) {
            return Plasmoid.configuration.folderPath
        }
        // Fall back to user's home directory via StandardLocation
        var path = Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString()
        // Remove file:// prefix if present
        if (path.startsWith("file://")) {
            path = path.substring(7)
        }
        return path
    }

    // Set preferred size for the widget
    preferredRepresentation: fullRepresentation

    // DataSource for running shell commands
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            disconnectSource(source)
        }
    }

    // Helper function to copy files
    function copyFileToFolder(sourceUrl) {
        var sourcePath = sourceUrl.toString().replace("file://", "")
        var command = 'cp -n "' + sourcePath + '" "' + targetFolderPath + '/"'
        executable.connectSource(command)
    }

    // The full representation is what shows on the desktop
    fullRepresentation: Rectangle {
        id: container

        // Track if something is being dragged over
        property bool isDragHovering: false

        // Width stays constant, height animates
        implicitWidth: 300
        implicitHeight: root.isCollapsed ? root.handleHeight : root.expandedHeight

        // Animate height changes
        Behavior on implicitHeight {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        // Dark tinted transparent background
        color: Qt.rgba(0, 0, 0, Plasmoid.configuration.backgroundOpacity * 0.7)

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

            // Use configured path, or fall back to home directory
            folder: "file://" + root.targetFolderPath

            // Show both files and folders
            showDirs: true
            showFiles: true

            // Include hidden files (starting with .)
            showHidden: false

            // Sort alphabetically, folders first
            sortField: FolderListModel.Name
            sortReversed: false
        }

        // Handle bar at the top - click to collapse/expand
        Rectangle {
            id: handleBar

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.handleHeight

            // Slightly lighter dark tint for the handle
            color: Qt.rgba(0.15, 0.15, 0.15, Plasmoid.configuration.backgroundOpacity * 0.85)

            // Match parent's corners when collapsed, top corners only when expanded
            radius: container.radius

            // Cover bottom corners when expanded (so handle blends with container)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.radius
                color: parent.color
                visible: !root.isCollapsed
            }

            // Visual indicator (small horizontal line)
            Rectangle {
                anchors.centerIn: parent
                width: 40
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
                    root.isCollapsed = !root.isCollapsed
                    // Save to configuration so it persists
                    Plasmoid.configuration.collapsed = root.isCollapsed
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
                        Plasmoid.configuration.backgroundOpacity * 0.85
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
            }

            onExited: {
                container.isDragHovering = false
            }

            onDropped: function(drop) {
                container.isDragHovering = false

                if (drop.hasUrls) {
                    for (var i = 0; i < drop.urls.length; i++) {
                        root.copyFileToFolder(drop.urls[i])
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

                // Hide when collapsed
                visible: !root.isCollapsed
                opacity: root.isCollapsed ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                // Cell size based on icon size plus padding for label
                cellWidth: root.iconSize + 16
                cellHeight: root.iconSize + 32

                // Use the folder model as data source
                model: folderModel

                // Use our custom delegate for each item
                delegate: IconDelegate {
                    iconSize: root.iconSize
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
                        // Smooth scroll by adjusting contentY directly
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
