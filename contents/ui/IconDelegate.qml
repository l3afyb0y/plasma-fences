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

        // Common file type mappings
        var iconMap = {
            // Documents
            "pdf": "application-pdf",
            "doc": "application-msword",
            "docx": "application-msword",
            "odt": "application-vnd.oasis.opendocument.text",
            "txt": "text-plain",
            "md": "text-markdown",
            // Spreadsheets
            "xls": "application-vnd.ms-excel",
            "xlsx": "application-vnd.ms-excel",
            "ods": "application-vnd.oasis.opendocument.spreadsheet",
            "csv": "text-csv",
            // Presentations
            "ppt": "application-vnd.ms-powerpoint",
            "pptx": "application-vnd.ms-powerpoint",
            "odp": "application-vnd.oasis.opendocument.presentation",
            // Archives
            "zip": "application-zip",
            "tar": "application-x-tar",
            "gz": "application-gzip",
            "7z": "application-x-7z-compressed",
            "rar": "application-x-rar",
            // Code
            "js": "application-javascript",
            "json": "application-json",
            "py": "text-x-python",
            "sh": "application-x-shellscript",
            "html": "text-html",
            "css": "text-css",
            "cpp": "text-x-c++src",
            "c": "text-x-csrc",
            "h": "text-x-chdr",
            "rs": "text-rust",
            "go": "text-x-go",
            // Media
            "mp3": "audio-mpeg",
            "wav": "audio-x-wav",
            "flac": "audio-flac",
            "ogg": "audio-ogg",
            "mp4": "video-mp4",
            "mkv": "video-x-matroska",
            "avi": "video-x-msvideo",
            "webm": "video-webm",
            // Images (fallback if thumbnail fails)
            "png": "image-png",
            "jpg": "image-jpeg",
            "jpeg": "image-jpeg",
            "gif": "image-gif",
            "webp": "image-webp",
            "svg": "image-svg+xml",
            "bmp": "image-bmp",
            // Apps
            "desktop": "application-x-desktop",
            "appimage": "application-x-executable",
            // Other
            "iso": "application-x-cd-image"
        }

        return iconMap[extension] || "text-x-generic"
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
            color: Kirigami.Theme.textColor

            // Truncate long names with ellipsis
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter

            font.pixelSize: 11
            maximumLineCount: 2
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
    }
}
