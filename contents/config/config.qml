import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "Panels"
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: "Layout"
        icon: "view-grid"
        source: "configLayout.qml"
    }
}
