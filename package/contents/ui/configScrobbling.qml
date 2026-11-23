import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_listenBrainz: lbBox.checked
    property alias cfg_listenBrainzToken: tokenField.text
    property alias cfg_localOnlyPlayers: localField.text
    property alias cfg_ignoredPlayers: ignoreField.text
    property string cfg_listenBrainzApi

    property string checkResult: ""

    function checkToken() {
        checkResult = i18n("Checking…")
        const xhr = new XMLHttpRequest()
        xhr.open("GET", cfg_listenBrainzApi + "/1/validate-token")
        xhr.setRequestHeader("Authorization", "Token " + tokenField.text.trim())
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 0) { checkResult = i18n("Couldn't reach ListenBrainz"); return }
            try {
                const r = JSON.parse(xhr.responseText)
                checkResult = r.valid ? i18n("Valid — logged in as %1", r.user_name) : i18n("Token not valid")
            } catch (e) {
                checkResult = i18n("Unexpected reply (HTTP %1)", xhr.status)
            }
        }
        xhr.send()
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.isSection: false
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.8
            text: i18n("Every track you play for half its length (or 4 minutes) is saved to a local history on this computer. Uploading is optional.")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("ListenBrainz") }

        QQC2.CheckBox {
            id: lbBox
            Kirigami.FormData.label: i18n("Upload:")
            text: i18n("Send listens to ListenBrainz")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("User token:")
            enabled: lbBox.checked
            QQC2.TextField {
                id: tokenField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                echoMode: TextInput.Password
                placeholderText: i18n("Paste your token")
                onTextChanged: checkResult = ""
            }
            QQC2.Button {
                text: i18n("Check")
                enabled: tokenField.text.trim().length > 0
                onClicked: checkToken()
            }
        }
        QQC2.Label {
            visible: checkResult.length > 0
            text: checkResult
        }
        Kirigami.UrlButton {
            url: "https://listenbrainz.org/settings/"
            text: i18n("Find your token at listenbrainz.org/settings")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Players") }

        QQC2.TextField {
            id: localField
            Kirigami.FormData.label: i18n("Don't upload from:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            placeholderText: i18n("e.g. strawberry, spotify")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: i18n("For players that already scrobble by themselves, so nothing is counted twice. Their listens still appear in your local history.")
        }
        QQC2.TextField {
            id: ignoreField
            Kirigami.FormData.label: i18n("Never record:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            placeholderText: i18n("e.g. firefox, kdeconnect")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: i18n("Comma separated. Matched against the player's name, ignoring case.")
        }
    }
}
