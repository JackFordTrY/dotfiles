//@ pragma Env QT_SCALE_FACTOR_ROUNDING_POLICY=Ceil
//@ pragma IconTheme breeze-dark

// Quickshell entry point (~/.config/quickshell/shell.qml).
// A bottom bar whose tabs grow out of the screen edge, in the Purple Night palette, with
// Material Symbols Sharp icons (ttf-material-symbols-variable). Autostarted by Hyprland
// (`exec-once = qs` in hypr/hyprland.conf); edits hot-reload on save.
// The Env pragma rounds the 1.25x display scale up so Qt renders at 2x and Hyprland scales
// it down, which keeps the 1px borders and flares crisp. Without a Qt platform theme Qt only
// searches hicolor, so tray icons and menus take Breeze Dark (light icons for the dark bar).
import Quickshell
import qs.bar
import qs.notifications
import qs.rules

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Banners from the top edge of the focused monitor
    Popups {}

    // VS Code windows to the workspace of their folder
    FolderWorkspaces {}
}
