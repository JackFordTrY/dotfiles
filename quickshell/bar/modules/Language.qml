import QtQuick
import qs.config
import qs.components
import qs.services

// hyprland/language: the active layout's full name, unboxed.
Module {
    marginRight: 10

    Label {
        text: KeyboardLayout.layout
        baselineY: Theme.labelBaseline
    }
}
