import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: pagesConfig

    // Configuration properties
    property var cfg_advancedPageConfig: ""
    property int cfg_pageConfigVersion: 0
    property int cfg_legacyPageCount: 1
    property bool cfg_autoSortEnabled: false

    // Internal state
    property var pagesList: []
    property string currentPageId: ""
    property bool usingAdvancedPages: false
    property var pagesConfigData: null

    // Available icons for pages
    readonly property var availableIcons: [
        "folder", "folder-work", "folder-personal", "folder-favorites", 
        "folder-download", "folder-documents", "folder-pictures", 
        "folder-music", "folder-videos", "folder-games", "folder-project"
    ]

    // Available colors for pages
    readonly property var availableColors: [
        "#3498db", "#2ecc71", "#e74c3c", "#f39c12", "#9b59b6", 
        "#1abc9c", "#d35400", "#34495e", "#95a5a6", "#f1c40f"
    ]

    // Initialize page configuration
    Component.onCompleted: {
        initializePageConfiguration()
    }

    onCfg_advancedPageConfigChanged: initializePageConfiguration()
    onCfg_pageConfigVersionChanged: initializePageConfiguration()

    function initializePageConfiguration() {
        var configVersion = cfg_pageConfigVersion || 0
        
        if (configVersion === 1 && cfg_advancedPageConfig.length > 0) {
            // Advanced page system
            try {
                pagesConfigData = JSON.parse(cfg_advancedPageConfig)
                usingAdvancedPages = true
                pagesList = pagesConfigData.pages || []
                currentPageId = pagesConfigData.currentPageId || (pagesList.length > 0 ? pagesList[0].id : "")
            } catch (e) {
                console.error("Error parsing advanced page config:", e)
                // Fall back to legacy system
                usingAdvancedPages = false
                initializeLegacyPages()
            }
        } else {
            // Legacy system
            usingAdvancedPages = false
            initializeLegacyPages()
        }
    }

    function initializeLegacyPages() {
        pagesList = []
        var pageCount = cfg_legacyPageCount || 1
        
        for (var i = 0; i < pageCount; i++) {
            pagesList.push({
                id: "page-" + i,
                name: "Page " + (i + 1),
                icon: "folder",
                color: getDefaultColor(i),
                hotkey: i < 9 ? "Ctrl+" + (i + 1) : null,
                panelIds: []
            })
        }
        currentPageId = pagesList.length > 0 ? pagesList[0].id : ""
    }

    function getDefaultColor(index) {
        var colors = ["#3498db", "#2ecc71", "#e74c3c", "#f39c12", "#9b59b6", "#1abc9c", "#d35400", "#34495e"]
        return colors[index % colors.length]
    }

    // Save the current configuration
    function savePageConfiguration() {
        if (!usingAdvancedPages) return
        
        var updatedConfig = {
            version: 1,
            metadata: pagesConfigData.metadata || {
                created: new Date().toISOString(),
                modified: new Date().toISOString()
            },
            pages: pagesList,
            currentPageId: currentPageId,
            settings: pagesConfigData.settings || {
                navigationStyle: "dots",
                showPageNames: true,
                transitionAnimation: "slide"
            }
        }
        
        updatedConfig.metadata.modified = new Date().toISOString()
        cfg_advancedPageConfig = JSON.stringify(updatedConfig)
        cfg_pageConfigVersion = 1
    }

    // Page management functions
    function addPage() {
        var newPageId = "page-" + pagesList.length
        pagesList.push({
            id: newPageId,
            name: "New Page",
            icon: "folder",
            color: getDefaultColor(pagesList.length),
            hotkey: null,
            panelIds: []
        })
        savePageConfiguration()
    }

    function removePage(pageIndex) {
        if (pagesList.length <= 1) return
        
        // Reassign panels from deleted page to first page
        var panelsToReassign = pagesList[pageIndex].panelIds
        if (pagesList.length > 1 && panelsToReassign.length > 0) {
            pagesList[0].panelIds = pagesList[0].panelIds.concat(panelsToReassign)
        }
        
        // Remove the page
        pagesList.splice(pageIndex, 1)
        
        // Update current page if needed
        if (currentPageId === pagesList[pageIndex].id) {
            currentPageId = pagesList[0].id
        }
        
        savePageConfiguration()
    }

    function updatePageProperty(pageIndex, property, value) {
        if (pageIndex >= 0 && pageIndex < pagesList.length) {
            pagesList[pageIndex][property] = value
            savePageConfiguration()
        }
    }

    function setCurrentPage(pageIndex) {
        if (pageIndex >= 0 && pageIndex < pagesList.length) {
            currentPageId = pagesList[pageIndex].id
            savePageConfiguration()
        }
    }

    function movePageUp(pageIndex) {
        if (pageIndex > 0) {
            var page = pagesList[pageIndex]
            pagesList.splice(pageIndex, 1)
            pagesList.splice(pageIndex - 1, 0, page)
            savePageConfiguration()
        }
    }

    function movePageDown(pageIndex) {
        if (pageIndex < pagesList.length - 1) {
            var page = pagesList[pageIndex]
            pagesList.splice(pageIndex, 1)
            pagesList.splice(pageIndex + 1, 0, page)
            savePageConfiguration()
        }
    }

    // UI Components
    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // Header
        Kirigami.Heading { 
            text: "Desktop Pages Management"
            level: 2
        }

        Label {
            text: usingAdvancedPages 
                ? "Manage your desktop pages with custom names, icons, colors, and hotkeys." 
                : "Legacy page system detected. Upgrade to advanced pages for full customization."
            wrapMode: Text.WordWrap
            opacity: 0.7
            Layout.fillWidth: true
        }

        // Upgrade button for legacy systems
        Button {
            visible: !usingAdvancedPages
            text: "Upgrade to Advanced Page System"
            icon.name: "go-next"
            onClicked: {
                // This would trigger migration - for now just show info
                upgradeInfoDialog.open()
            }
        }

        // Page list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: usingAdvancedPages

            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.smallSpacing

                // Add page button
                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Heading { text: "Your Pages"; level: 3 }
                    Item { Layout.fillWidth: true }
                    Button {
                        icon.name: "list-add"
                        text: "Add Page"
                        onClicked: addPage()
                    }
                }

                // Page items
                Repeater {
                    model: pagesList.length
                    delegate: Kirigami.Card {
                        Layout.fillWidth: true
                        property int pageIndex: index
                        property var pageData: pagesList[index]
                        
                        header: RowLayout {
                            Kirigami.Heading { 
                                text: pageData.name || "Untitled Page"
                                level: 3 
                            }
                            Item { Layout.fillWidth: true }
                            
                            // Current page indicator
                            Label {
                                visible: pageData.id === currentPageId
                                text: "(Current)"
                                color: Kirigami.Theme.highlightColor
                                font.bold: true
                            }
                            
                            // Action buttons
                            Button {
                                icon.name: "go-up"
                                tooltip: "Move Up"
                                enabled: pageIndex > 0
                                onClicked: movePageUp(pageIndex)
                            }
                            Button {
                                icon.name: "go-down"
                                tooltip: "Move Down"
                                enabled: pageIndex < pagesList.length - 1
                                onClicked: movePageDown(pageIndex)
                            }
                            Button {
                                icon.name: "edit-delete"
                                tooltip: "Remove Page"
                                enabled: pagesList.length > 1
                                onClicked: removePage(pageIndex)
                            }
                        }
                        
                        contentItem: Kirigami.FormLayout {
                            // Page name
                            TextField {
                                Kirigami.FormData.label: "Page Name:"
                                Layout.fillWidth: true
                                text: pageData.name || ""
                                placeholderText: "Enter page name"
                                onTextEdited: updatePageProperty(pageIndex, "name", text)
                            }

                            // Page icon
                            RowLayout {
                                Kirigami.FormData.label: "Icon:"
                                ComboBox {
                                    id: iconCombo
                                    Layout.fillWidth: true
                                    model: availableIcons
                                    currentIndex: availableIcons.indexOf(pageData.icon || "folder")
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0) {
                                            updatePageProperty(pageIndex, "icon", availableIcons[currentIndex])
                                        }
                                    }
                                }
                                Kirigami.Icon {
                                    source: pageData.icon || "folder"
                                    width: 24
                                    height: 24
                                }
                            }

                            // Page color
                            RowLayout {
                                Kirigami.FormData.label: "Color:"
                                ComboBox {
                                    id: colorCombo
                                    Layout.fillWidth: true
                                    model: availableColors
                                    textRole: "name"
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0) {
                                            updatePageProperty(pageIndex, "color", availableColors[currentIndex])
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 24
                                    height: 24
                                    color: pageData.color || "#3498db"
                                    radius: 4
                                    border.width: 1
                                    border.color: Qt.rgba(0, 0, 0, 0.2)
                                }
                            }

                            // Hotkey assignment
                            RowLayout {
                                Kirigami.FormData.label: "Hotkey:"
                                TextField {
                                    Layout.fillWidth: true
                                    text: pageData.hotkey || ""
                                    placeholderText: "e.g. Ctrl+1, Ctrl+2"
                                    onTextEdited: updatePageProperty(pageIndex, "hotkey", text)
                                }
                                Button {
                                    text: "Clear"
                                    onClicked: updatePageProperty(pageIndex, "hotkey", "")
                                }
                            }

                            // Set as current page
                            Button {
                                Kirigami.FormData.label: "Actions:"
                                text: pageData.id === currentPageId ? "Current Page" : "Set as Current"
                                enabled: pageData.id !== currentPageId
                                onClicked: setCurrentPage(pageIndex)
                            }
                        }
                    }
                }
            }
        }

        // Info for non-advanced users
        Kirigami.InformationMessage {
            visible: !usingAdvancedPages
            text: "You are using the legacy page system. The advanced page system provides custom names, icons, colors, and hotkeys for each page."
            Layout.fillWidth: true
        }
    }

    // Dialog for upgrade information
    Dialog {
        id: upgradeInfoDialog
        title: "Upgrade to Advanced Pages"
        standardButtons: Dialog.Ok
        
        ColumnLayout {
            Label {
                text: "The advanced page system provides:"
                font.bold: true
            }
            Label { text: "• Custom page names" }
            Label { text: "• Unique icons for each page" }
            Label { text: "• Color customization" }
            Label { text: "• Hotkey navigation" }
            Label { text: "• Better visual organization" }
            
            Label {
                text: "\nYour existing configuration will be automatically migrated."
                opacity: 0.7
            }
        }
    }
}