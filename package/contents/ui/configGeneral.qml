import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_blurredBackground: blurBox.checked
    property alias cfg_volumeStep: stepSpin.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: blurBox
            Kirigami.FormData.label: i18n("Background:")
            text: i18n("Blurred album art")
        }
        QQC2.SpinBox {
            id: stepSpin
            Kirigami.FormData.label: i18n("Volume step (scroll):")
            from: 1; to: 25
            textFromValue: v => v + "%"
        }
    }
}
