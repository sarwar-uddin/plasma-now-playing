import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "media-playback-start"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Scrobbling")
        icon: "view-history"
        source: "configScrobbling.qml"
    }
}
