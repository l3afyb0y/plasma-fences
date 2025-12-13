import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configPage

    // Bind to plasmoid configuration
    property alias cfg_folderPath: folderPathField.text
    property alias cfg_backgroundOpacity: opacitySlider.value
    property alias cfg_iconSize: iconSizeSpinBox.value

    Kirigami.FormLayout {
        anchors.fill: parent

        // Folder path selection
        RowLayout {
            Kirigami.FormData.label: "Folder:"
            spacing: Kirigami.Units.smallSpacing

            TextField {
                id: folderPathField
                Layout.fillWidth: true
                placeholderText: "Select a folder to display..."
            }

            Button {
                icon.name: "folder-open"
                text: "Browse"
                onClicked: folderDialog.open()
            }
        }

        // Folder picker dialog
        FolderDialog {
            id: folderDialog
            title: "Select Folder"
            currentFolder: folderPathField.text
                ? "file://" + folderPathField.text
                : "file://" + Qt.resolvedUrl("~").toString().replace("file://", "")

            onAccepted: {
                // Remove file:// prefix and set the path
                var path = selectedFolder.toString().replace("file://", "")
                folderPathField.text = path
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
                value: 0.7
            }

            Label {
                text: Math.round(opacitySlider.value * 100) + "%"
                Layout.preferredWidth: 45
            }
        }

        // Icon size spinner
        RowLayout {
            Kirigami.FormData.label: "Icon size:"
            spacing: Kirigami.Units.smallSpacing

            SpinBox {
                id: iconSizeSpinBox
                from: 24
                to: 128
                stepSize: 8
                value: 48
            }

            Label {
                text: "pixels"
            }
        }

        // Info text
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Tips"
        }

        Label {
            text: "• Click the handle bar to collapse/expand the widget"
            opacity: 0.7
        }

        Label {
            text: "• Drag files onto the widget to copy them to the folder"
            opacity: 0.7
        }

        Label {
            text: "• Scroll with mouse wheel when content overflows"
            opacity: 0.7
        }
    }
}
