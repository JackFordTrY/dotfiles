//@ pragma Env QT_SCALE_FACTOR_ROUNDING_POLICY=Ceil

// Quickshell entry point (~/.config/quickshell/shell.qml).
// The bar is a pixel-for-pixel port of Waybar (waybar/config + waybar/style.css), autostarted
// by Hyprland (`exec-once = qs` in hypr/hyprland.conf). Edits hot-reload on save.
// GTK3 Waybar renders at 2x and Hyprland scales it to the 1.25x display, so the Env pragma
// makes Qt do the same instead of rendering at 1.25x directly.
import Quickshell
import qs.bar

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
