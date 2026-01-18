import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Delegate for rendering a single file/folder icon in the grid
Item {
    id: iconDelegate

    // These properties come from the GridView / FolderListModel
    required property string fileName
    required property url fileUrl
    required property bool fileIsDir

    // Size of the icon (from configuration)
    property int iconSize: 48

    // Total cell dimensions
    width: iconSize + 16
    height: iconSize + 32

    // Check if this file is an image based on extension
    readonly property bool isImageFile: {
        var extension = fileName.split('.').pop().toLowerCase()
        return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"].includes(extension)
    }

    // Get mimetype icon name based on file extension
    readonly property string mimetypeIcon: {
        if (fileIsDir) return "folder"

        var extension = fileName.split('.').pop().toLowerCase()

        // Core file type mappings
        var iconMap = {
            "pdf": "application-pdf",
            "txt": "text-plain",
            "md": "text-markdown",
            "zip": "application-zip",
            "tar": "application-x-tar",
            "gz": "application-gzip",
            "7z": "application-x-7z-compressed",
            "mp3": "audio-x-generic",
            "mp4": "video-x-generic",
            "desktop": "application-x-desktop"
        }

        // Handle images
        if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp"].includes(extension)) {
            return "image-x-generic"
        }

        return iconMap[extension] || "text-x-generic"
    }

    // Drag support - allows dragging files out of fences
    Drag.active: delegateMouseArea.drag.active
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: {
        "text/uri-list": iconDelegate.fileUrl.toString()
    }

    // Hover highlight background
    Rectangle {
        anchors.fill: parent
        radius: 4
        color: delegateMouseArea.containsMouse
            ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                      Kirigami.Theme.highlightColor.g,
                      Kirigami.Theme.highlightColor.b, 0.2)
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    // Click and drag handler
    MouseArea {
        id: delegateMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Enable drag with threshold to avoid accidental drags
        drag.target: iconDelegate
        drag.threshold: 10

        // Double-click to open file/folder with default application
        onDoubleClicked: {
            Qt.openUrlExternally(iconDelegate.fileUrl)
        }

        // Reset position after drag ends (item stays in place, only data transfers)
        onReleased: {
            iconDelegate.x = 0
            iconDelegate.y = 0
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        // Container for icon/thumbnail
        Item {
            id: iconContainer
            anchors.horizontalCenter: parent.horizontalCenter
            width: iconDelegate.iconSize
            height: iconDelegate.iconSize

            // Image thumbnail (for image files)
            Image {
                id: thumbnailImage
                anchors.fill: parent

                // Only show when it's an image file AND successfully loaded
                visible: iconDelegate.isImageFile && status === Image.Ready

                source: iconDelegate.isImageFile ? iconDelegate.fileUrl : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                cache: true
                sourceSize.width: iconDelegate.iconSize * 2
                sourceSize.height: iconDelegate.iconSize * 2
                
                // Enable GPU acceleration for image rendering
                layer.enabled: true
                layer.smooth: true
                layer.mipmap: true
                
                // Optimize loading for high refresh rates
                onStatusChanged: {
                    if (status === Image.Ready) {
                        // Force GPU upload when ready
                        forceActiveFocus()
                    }
                }
            }

            // Fallback icon (for folders, non-images, or while loading/error)
            Kirigami.Icon {
                id: fileIcon
                anchors.fill: parent

                // Show when: not an image, OR image is loading, OR image failed to load
                visible: !iconDelegate.isImageFile
                    || thumbnailImage.status === Image.Loading
                    || thumbnailImage.status === Image.Null
                    || thumbnailImage.status === Image.Error

                source: iconDelegate.mimetypeIcon
            }
        }

        // The filename label
        PlasmaComponents.Label {
            id: fileNameLabel
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width

            text: iconDelegate.fileName
            color: "white" // Force white text for classic desktop look

            // Drop shadow for readability
            style: Text.Outline
            styleColor: "black"

            // Truncate long names with ellipsis
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter

            font.pixelSize: 10
            font.bold: false
            maximumLineCount: 2
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
    }
}
