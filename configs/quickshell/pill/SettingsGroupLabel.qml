import QtQuick
import "Singletons"

/**
 * Static section label: small, faint, bold, all-caps, letter-spaced text used
 * above a run of settings rows — standalone (Input, Animation) or as
 * SettingsGroup's own header. Promoted from Look.qml's local `GroupLabel`;
 * visuals unchanged. `s` carries scale since this lives outside any surface.
 */
Text {
    id: label

    property real s: 1

    topPadding: 16 * label.s
    bottomPadding: 6 * label.s
    color: Theme.faint
    font.family: Theme.font
    font.pixelSize: 8.5 * label.s
    font.weight: Font.Bold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1.2 * label.s
}
