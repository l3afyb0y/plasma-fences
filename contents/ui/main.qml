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
    
    // Mouse tracking for auto-hiding
    property bool mouseInside: false
    
    // Auto-hiding configuration
    property bool autoHideEnabled: Plasmoid.configuration.autoHideEnabled || false
    property bool hideOnFullscreen: Plasmoid.configuration.hideOnFullscreen || true

    // Current page state (legacy and advanced)
    property int currentPage: Plasmoid.configuration.currentPage || 0
    property string currentPageId: ""
    property var pagesConfig: null
    property bool usingAdvancedPages: false

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

    // Update filtered model to show only panels for the current page
    function updateFilteredModel() {
        filteredPanelModel.clear()
        
        for (var i = 0; i < allPanelsModel.count; i++) {
            var panel = allPanelsModel.get(i)
            var shouldShow = false
            
            // Check if panel should be shown based on page
            if (usingAdvancedPages) {
                // Advanced page system: check if panel is in current page
                if (pagesConfig && pagesConfig.pages) {
                    var currentPage = getCurrentPage()
                    if (currentPage && currentPage.panelIds) {
                        shouldShow = currentPage.panelIds.includes(getPanelIdForIndex(i))
                    }
                }
            } else {
                // Legacy page system
                shouldShow = panel.pageId === root.currentPage
            }
            
            if (shouldShow) {
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

    // ========== Advanced Page Management Functions ==========
    
    // Initialize advanced page system
    function initializeAdvancedPages() {
        var configVersion = Plasmoid.configuration.pageConfigVersion || 0
        
        if (configVersion === 0) {
            // Legacy system - check if we should migrate
            if (Plasmoid.configuration.pageCount > 1 || Plasmoid.configuration.panelConfigs.length > 0) {
                // Migrate from legacy to advanced format
                migrateToAdvancedPages()
            } else {
                // No existing pages, initialize with default advanced config
                initializeDefaultAdvancedPages()
            }
        } else if (configVersion === 1) {
            // Advanced system already in place
            try {
                var configJson = Plasmoid.configuration.advancedPageConfig
                if (configJson && configJson.length > 0) {
                    pagesConfig = JSON.parse(configJson)
                    usingAdvancedPages = true
                    
                    // Find current page
                    if (pagesConfig.currentPageId) {
                        currentPageId = pagesConfig.currentPageId
                    }
                }
            } catch (e) {
                console.error("Error parsing advanced page config:", e)
                // Fall back to legacy system
                usingAdvancedPages = false
            }
        }
    }

    // Migrate from legacy format to advanced format
    function migrateToAdvancedPages() {
        console.log("Migrating from legacy page format to advanced format")
        
        // Create new advanced configuration
        var newConfig = {
            version: 1,
            metadata: {
                created: new Date().toISOString(),
                modified: new Date().toISOString()
            },
            pages: [],
            currentPageId: "page-0",
            settings: {
                navigationStyle: "dots",
                showPageNames: true,
                transitionAnimation: "slide"
            }
        }
        
        // Create pages based on legacy data
        var legacyPageCount = Plasmoid.configuration.pageCount || 1
        for (var i = 0; i < legacyPageCount; i++) {
            var panelIds = []
            
            // Find all panels assigned to this legacy page
            for (var j = 0; j < allPanelsModel.count; j++) {
                var panel = allPanelsModel.get(j)
                if (panel.pageId === i) {
                    panelIds.push(getPanelIdForIndex(j))
                }
            }
            
            newConfig.pages.push({
                id: "page-" + i,
                name: "Page " + (i + 1),
                icon: "folder",
                color: getDefaultColor(i),
                hotkey: i < 9 ? "Ctrl+" + (i + 1) : null,
                panelIds: panelIds
            })
        }
        
        // Set current page
        var legacyCurrentPage = Plasmoid.configuration.currentPage || 0
        newConfig.currentPageId = "page-" + legacyCurrentPage
        
        // Save the new configuration
        pagesConfig = newConfig
        Plasmoid.configuration.advancedPageConfig = JSON.stringify(newConfig)
        Plasmoid.configuration.pageConfigVersion = 1
        usingAdvancedPages = true
        currentPageId = newConfig.currentPageId
    }

    // Initialize default advanced page configuration
    function initializeDefaultAdvancedPages() {
        var defaultConfig = {
            version: 1,
            metadata: {
                created: new Date().toISOString(),
                modified: new Date().toISOString()
            },
            pages: [
                {
                    id: "page-0",
                    name: "Main Page",
                    icon: "folder",
                    color: "#3498db",
                    hotkey: "Ctrl+1",
                    panelIds: []
                }
            ],
            currentPageId: "page-0",
            settings: {
                navigationStyle: "dots",
                showPageNames: true,
                transitionAnimation: "slide"
            }
        }
        
        pagesConfig = defaultConfig
        Plasmoid.configuration.advancedPageConfig = JSON.stringify(defaultConfig)
        Plasmoid.configuration.pageConfigVersion = 1
        usingAdvancedPages = true
        currentPageId = "page-0"
    }

    // Get panel ID for a given index
    function getPanelIdForIndex(index) {
        return "panel-" + index
    }

    // Get current page from advanced configuration
    function getCurrentPage() {
        if (!pagesConfig || !pagesConfig.pages) return null
        return pagesConfig.pages.find(function(page) {
            return page.id === currentPageId
        }) || pagesConfig.pages[0]
    }

    // Get all pages
    function getAllPages() {
        return pagesConfig && pagesConfig.pages ? pagesConfig.pages : []
    }

    // Navigate to specific page
    function navigateToPage(pageId) {
        if (!pagesConfig || !pagesConfig.pages) return false
        
        var pageExists = pagesConfig.pages.some(function(page) {
            return page.id === pageId
        })
        
        if (pageExists) {
            currentPageId = pageId
            pagesConfig.currentPageId = pageId
            pagesConfig.metadata.modified = new Date().toISOString()
            Plasmoid.configuration.advancedPageConfig = JSON.stringify(pagesConfig)
            updateFilteredModel()
            return true
        }
        return false
    }

    // Create a new page
    function createPage(name, icon, color, hotkey) {
        if (!pagesConfig) return null
        
        var newPageId = "page-" + pagesConfig.pages.length
        var newPage = {
            id: newPageId,
            name: name || "Page " + (pagesConfig.pages.length + 1),
            icon: icon || "folder",
            color: color || getDefaultColor(pagesConfig.pages.length),
            hotkey: hotkey || null,
            panelIds: []
        }
        
        pagesConfig.pages.push(newPage)
        pagesConfig.metadata.modified = new Date().toISOString()
        Plasmoid.configuration.advancedPageConfig = JSON.stringify(pagesConfig)
        
        return newPageId
    }

    // Delete a page
    function deletePage(pageId) {
        if (!pagesConfig || pagesConfig.pages.length <= 1) return false
        
        var pageIndex = -1
        for (var i = 0; i < pagesConfig.pages.length; i++) {
            if (pagesConfig.pages[i].id === pageId) {
                pageIndex = i
                break
            }
        }
        
        if (pageIndex === -1) return false
        
        // Reassign panels from deleted page to first page
        var panelsToReassign = pagesConfig.pages[pageIndex].panelIds
        if (pagesConfig.pages.length > 1 && panelsToReassign.length > 0) {
            pagesConfig.pages[0].panelIds = pagesConfig.pages[0].panelIds.concat(panelsToReassign)
        }
        
        // Remove the page
        pagesConfig.pages.splice(pageIndex, 1)
        
        // Update current page if needed
        if (currentPageId === pageId) {
            currentPageId = pagesConfig.pages[0].id
            pagesConfig.currentPageId = currentPageId
        }
        
        pagesConfig.metadata.modified = new Date().toISOString()
        Plasmoid.configuration.advancedPageConfig = JSON.stringify(pagesConfig)
        updateFilteredModel()
        
        return true
    }

    // Get default color for page index
    function getDefaultColor(index) {
        var colors = ["#3498db", "#2ecc71", "#e74c3c", "#f39c12", "#9b59b6", "#1abc9c", "#d35400", "#34495e"]
        return colors[index % colors.length]
    }

    // Handle hotkey navigation
    function handleHotkeyNavigation(hotkey) {
        if (!pagesConfig || !pagesConfig.pages) return false
        
        for (var i = 0; i < pagesConfig.pages.length; i++) {
            var page = pagesConfig.pages[i]
            if (page.hotkey === hotkey) {
                return navigateToPage(page.id)
            }
        }
        return false
    }

    // ========== Bulk Operations Tools ==========
    
    // Bulk assign panels to a specific page
    function bulkAssignPanelsToPage(panelIndices, targetPageId) {
        if (!usingAdvancedPages || !pagesConfig || !pagesConfig.pages) return false
        
        var targetPage = null
        for (var i = 0; i < pagesConfig.pages.length; i++) {
            if (pagesConfig.pages[i].id === targetPageId) {
                targetPage = pagesConfig.pages[i]
                break
            }
        }
        
        if (!targetPage) return false
        
        // Remove panels from their current pages and add to target page
        for (var i = 0; i < panelIndices.length; i++) {
            var panelIndex = panelIndices[i]
            var panelId = getPanelIdForIndex(panelIndex)
            
            // Remove from all pages first
            for (var j = 0; j < pagesConfig.pages.length; j++) {
                var page = pagesConfig.pages[j]
                if (page.panelIds) {
                    var idx = page.panelIds.indexOf(panelId)
                    if (idx !== -1) {
                        page.panelIds.splice(idx, 1)
                    }
                }
            }
            
            // Add to target page
            if (!targetPage.panelIds) targetPage.panelIds = []
            targetPage.panelIds.push(panelId)
        }
        
        // Save changes
        pagesConfig.metadata.modified = new Date().toISOString()
        Plasmoid.configuration.advancedPageConfig = JSON.stringify(pagesConfig)
        updateFilteredModel()
        
        return true
    }
    
    // Bulk move panels between pages
    function bulkMovePanels(panelIndices, sourcePageId, targetPageId) {
        return bulkAssignPanelsToPage(panelIndices, targetPageId)
    }
    
    // Bulk delete panels
    function bulkDeletePanels(panelIndices) {
        if (panelIndices.length === 0) return 0
        
        // Sort indices in descending order to avoid index shifting issues
        panelIndices.sort(function(a, b) { return b - a })
        
        var deletedCount = 0
        for (var i = 0; i < panelIndices.length; i++) {
            var panelIndex = panelIndices[i]
            if (panelIndex >= 0 && panelIndex < allPanelsModel.count) {
                
                // Remove from any pages it belongs to
                if (usingAdvancedPages && pagesConfig && pagesConfig.pages) {
                    var panelId = getPanelIdForIndex(panelIndex)
                    for (var j = 0; j < pagesConfig.pages.length; j++) {
                        var page = pagesConfig.pages[j]
                        if (page.panelIds) {
                            var idx = page.panelIds.indexOf(panelId)
                            if (idx !== -1) {
                                page.panelIds.splice(idx, 1)
                            }
                        }
                    }
                }
                
                // Remove from model
                allPanelsModel.remove(panelIndex)
                deletedCount++
            }
        }
        
        // Save changes
        savePanelConfigs()
        if (usingAdvancedPages) {
            pagesConfig.metadata.modified = new Date().toISOString()
            Plasmoid.configuration.advancedPageConfig = JSON.stringify(pagesConfig)
        }
        updateFilteredModel()
        
        return deletedCount
    }
    
    // Bulk update panel properties
    function bulkUpdatePanelProperties(panelIndices, properties) {
        if (!properties || Object.keys(properties).length === 0) return 0
        
        var updatedCount = 0
        for (var i = 0; i < panelIndices.length; i++) {
            var panelIndex = panelIndices[i]
            if (panelIndex >= 0 && panelIndex < allPanelsModel.count) {
                var panel = allPanelsModel.get(panelIndex)
                
                for (var prop in properties) {
                    if (properties.hasOwnProperty(prop)) {
                        // Sanitize values
                        var value = properties[prop]
                        if (prop === "panelOpacity") {
                            value = Math.min(1.0, Math.max(0.1, parseFloat(value) || defaultOpacity))
                        } else if (prop === "iconSize") {
                            value = Math.min(128, Math.max(24, parseInt(value) || defaultIconSize))
                        } else if (prop === "expandedHeight") {
                            value = Math.min(800, Math.max(100, parseInt(value) || defaultExpandedHeight))
                        } else if (prop === "collapsed") {
                            value = !!value
                        }
                        
                        allPanelsModel.setProperty(panelIndex, prop, value)
                    }
                }
                updatedCount++
            }
        }
        
        savePanelConfigs()
        updateFilteredModel()
        
        return updatedCount
    }
    
    // Bulk create panels from templates
    function bulkCreatePanelsFromTemplates(templates) {
        if (!templates || templates.length === 0) return 0
        
        var createdCount = 0
        for (var i = 0; i < templates.length; i++) {
            var template = templates[i]
            
            // Create new panel
            allPanelsModel.append(sanitizePanelConfig({
                folderPath: template.folderPath || homePath(),
                collapsed: template.collapsed || false,
                panelOpacity: template.panelOpacity || defaultOpacity,
                iconSize: template.iconSize || defaultIconSize,
                expandedHeight: template.expandedHeight || defaultExpandedHeight,
                sortRules: template.sortRules || "",
                pageId: template.pageId || 0
            }))
            createdCount++
        }
        
        savePanelConfigs()
        updateFilteredModel()
        
        return createdCount
    }
    
    // Export panel configuration
    function exportPanelConfiguration() {
        var exportData = {
            version: 1,
            timestamp: new Date().toISOString(),
            panels: [],
            pages: usingAdvancedPages ? pagesConfig : null
        }
        
        // Export all panels
        for (var i = 0; i < allPanelsModel.count; i++) {
            var panel = allPanelsModel.get(i)
            exportData.panels.push({
                folderPath: panel.folderPath,
                collapsed: panel.collapsed,
                panelOpacity: panel.panelOpacity,
                iconSize: panel.iconSize,
                expandedHeight: panel.expandedHeight,
                sortRules: panel.sortRules,
                pageId: panel.pageId
            })
        }
        
        return JSON.stringify(exportData, null, 2)
    }
    
    // Import panel configuration
    function importPanelConfiguration(configJson) {
        try {
            var importData = JSON.parse(configJson)
            if (!importData || !importData.panels) return 0
            
            var importedCount = 0
            for (var i = 0; i < importData.panels.length; i++) {
                var panelData = importData.panels[i]
                
                // Check if panel already exists
                var exists = false
                for (var j = 0; j < allPanelsModel.count; j++) {
                    var existingPanel = allPanelsModel.get(j)
                    if (existingPanel.folderPath === panelData.folderPath) {
                        exists = true
                        break
                    }
                }
                
                if (!exists) {
                    allPanelsModel.append(sanitizePanelConfig(panelData))
                    importedCount++
                }
            }
            
            savePanelConfigs()
            updateFilteredModel()
            
            return importedCount
        } catch (e) {
            console.error("Error importing panel configuration:", e)
            return 0
        }
    }

    // Page transition animation types
    readonly property var transitionAnimations: {
        "none": "No Animation",
        "slide": "Slide",
        "fade": "Fade",
        "zoom": "Zoom",
        "flip": "Flip"
    }
    
    // Get current transition animation setting
    function getCurrentTransitionAnimation() {
        if (usingAdvancedPages && pagesConfig && pagesConfig.settings) {
            return pagesConfig.settings.transitionAnimation || "slide"
        }
        return "slide"
    }
    
    // Set transition animation
    function setTransitionAnimation(animationType) {
        if (!usingAdvancedPages) return false
        
        if (!pagesConfig.settings) pagesConfig.settings = {}
        pagesConfig.settings.transitionAnimation = animationType
        pagesConfig.metadata.modified = new Date().toISOString()
        Plasmoid.configuration.advancedPageConfig = JSON.stringify(pagesConfig)
        
        return true
    }
    
    // Animation settings
    function getAnimationSettings() {
        if (usingAdvancedPages && pagesConfig && pagesConfig.settings) {
            return {
                transitionAnimation: pagesConfig.settings.transitionAnimation || "slide",
                animationDuration: pagesConfig.settings.animationDuration || 300,
                enableAnimations: pagesConfig.settings.enableAnimations !== false
            }
        }
        
        return {
            transitionAnimation: "slide",
            animationDuration: 300,
            enableAnimations: true
        }
    }
    
    // Set animation settings
    function setAnimationSettings(settings) {
        if (!usingAdvancedPages) return false
        
        if (!pagesConfig.settings) pagesConfig.settings = {}
        
        if (settings.transitionAnimation) {
            pagesConfig.settings.transitionAnimation = settings.transitionAnimation
        }
        
        if (settings.animationDuration) {
            pagesConfig.settings.animationDuration = Math.max(100, Math.min(1000, settings.animationDuration))
        }
        
        if (settings.enableAnimations !== undefined) {
            pagesConfig.settings.enableAnimations = !!settings.enableAnimations
        }
        
        pagesConfig.metadata.modified = new Date().toISOString()
        Plasmoid.configuration.advancedPageConfig = JSON.stringify(pagesConfig)
        
        return true
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

    Component.onCompleted: {
        parsePanelConfigs()
        initializeAdvancedPages()
    }

    Connections {
        target: Plasmoid.configuration
        function onPanelConfigsChanged() { parsePanelConfigs() }
        function onAutoSortEnabledChanged() { sortTimer.running = Plasmoid.configuration.autoSortEnabled }
        function onCurrentPageChanged() {
            if (!usingAdvancedPages) {
                root.currentPage = Plasmoid.configuration.currentPage
                updateFilteredModel()
            }
        }
        function onAdvancedPageConfigChanged() {
            if (usingAdvancedPages) {
                try {
                    pagesConfig = JSON.parse(Plasmoid.configuration.advancedPageConfig)
                    if (pagesConfig.currentPageId) {
                        currentPageId = pagesConfig.currentPageId
                    }
                    updateFilteredModel()
                } catch (e) {
                    console.error("Error parsing updated advanced page config:", e)
                }
            }
        }
        function onPageConfigVersionChanged() {
            // Re-initialize when config version changes
            initializeAdvancedPages()
            updateFilteredModel()
        }
        function onAutoHideEnabledChanged() {
            root.autoHideEnabled = Plasmoid.configuration.autoHideEnabled
        }
        function onHideOnFullscreenChanged() {
            root.hideOnFullscreen = Plasmoid.configuration.hideOnFullscreen
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
        // Add space for navigation UI
        if (usingAdvancedPages ? getAllPages().length > 1 : Plasmoid.configuration.pageCount > 1) {
            total += usingAdvancedPages ? 48 : 24
        }
        return Math.max(total, handleHeight)
    }

    fullRepresentation: Item {
        id: container
        implicitWidth: root.useGridLayout ? 300 * root.effectiveGridColumns + root.gridSpacing * (root.effectiveGridColumns - 1) : 300
        implicitHeight: calculateTotalHeight()
        
        // Enable GPU acceleration for the entire container
        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: container.width
                height: container.height
            }
        }

        MouseArea {
            id: mainMouseArea
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            
            // Improved auto-hiding behavior
            onEntered: {
                root.mouseInside = true
                // Show when mouse enters, but only if we're currently hidden
                if (root.isHidden) {
                    root.isHidden = false
                }
            }
            
            onExited: {
                root.mouseInside = false
                // Auto-hide when mouse leaves, but with a delay to prevent flickering
                // Only if auto-hiding is enabled
                if (root.autoHideEnabled) {
                    hideTimer.start()
                }
            }
            
            onDoubleClicked: root.isHidden = !root.isHidden
        }
        
        // Timer for delayed auto-hiding
        Timer {
            id: hideTimer
            interval: 1000  // 1 second delay before hiding
            repeat: false
            onTriggered: {
                // Only hide if mouse is still outside
                // We'll use a property to track mouse state
                if (!root.mouseInside) {
                    root.isHidden = true
                }
            }
        }

        opacity: root.isHidden ? 0.0 : 1.0
        Behavior on opacity {
            NumberAnimation {
                duration: 150  // Optimized for high refresh rates
                easing.type: Easing.InOutQuad
                alwaysRunToEnd: true
            }
        }

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

            // Advanced Navigation UI
            Column {
                id: pageNavigation
                width: parent.width
                height: usingAdvancedPages ? 48 : 24
                visible: (usingAdvancedPages ? getAllPages().length > 1 : Plasmoid.configuration.pageCount > 1)
                
                // Enhanced navigation bar for advanced pages
                Rectangle {
                    id: advancedNavBar
                    width: parent.width
                    height: 48
                    color: Qt.rgba(0, 0, 0, 0.8)
                    visible: usingAdvancedPages && getAllPages().length > 1
                    radius: 8
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    
                    Row {
                        id: advancedNavContent
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12
                        
                        // Navigation buttons for each page
                        Repeater {
                            model: getAllPages().length
                            delegate: Column {
                                width: 120
                                height: 32
                                spacing: 4
                                
                                // Page button
                                Rectangle {
                                    width: parent.width
                                    height: 32
                                    color: getAllPages()[index].id === currentPageId 
                                        ? Kirigami.Theme.highlightColor 
                                        : Qt.rgba(1, 1, 1, 0.2)
                                    radius: 16
                                    border.width: 1
                                    border.color: getAllPages()[index].id === currentPageId 
                                        ? Kirigami.Theme.highlightColor 
                                        : Qt.rgba(1, 1, 1, 0.1)
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        
                                        onEntered: parent.border.width = 2
                                        onExited: parent.border.width = 1
                                        onClicked: navigateToPage(getAllPages()[index].id)
                                    }
                                    
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        
                                        // Page icon
                                        Kirigami.Icon {
                                            source: getAllPages()[index].icon || "folder"
                                            width: 16
                                            height: 16
                                            color: getAllPages()[index].id === currentPageId ? "white" : Kirigami.Theme.textColor
                                        }
                                        
                                        // Page name
                                        Label {
                                            text: getAllPages()[index].name || "Page " + (index + 1)
                                            color: getAllPages()[index].id === currentPageId ? "white" : Kirigami.Theme.textColor
                                            font.bold: getAllPages()[index].id === currentPageId
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                                
                                // Hotkey indicator (if assigned)
                                Label {
                                    visible: getAllPages()[index].hotkey && getAllPages()[index].hotkey.length > 0
                                    text: getAllPages()[index].hotkey
                                    font.pixelSize: 10
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        
                        // Add page button
                        Kirigami.IconButton {
                            icon.name: "list-add"
                            tooltip: "Add Page"
                            onClicked: {
                                var newPageId = createPage("New Page", "folder", "", "")
                                if (newPageId) {
                                    navigateToPage(newPageId)
                                }
                            }
                        }
                    }
                }
                
                // Legacy dot navigation (fallback)
                Row {
                    id: legacyPageDots
                    height: 24
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: !usingAdvancedPages && Plasmoid.configuration.pageCount > 1
                    
                    Repeater {
                        model: Plasmoid.configuration.pageCount
                        delegate: Rectangle {
                            width: 8; height: 8; radius: 4
                            color: index === root.currentPage ? Kirigami.Theme.highlightColor : Qt.rgba(1, 1, 1, 0.3)
                            MouseArea { 
                                anchors.fill: parent; 
                                cursorShape: Qt.PointingHandCursor; 
                                onClicked: {
                                    Plasmoid.configuration.currentPage = index
                                    root.currentPage = index
                                    updateFilteredModel()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}