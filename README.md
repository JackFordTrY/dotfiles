# Config Overview

This workspace contains personal Linux desktop configuration, mainly centered around Hyprland.

## Packages

- hyprland
- waybar
- rofi
- hyprshutdows
- wl-clipboard + clipvault
- flameshot
- wtype
- bluez + bluez-utils
- discord + xdg-desktop-portal-hyprland
- ark + dolphin + kio + kio-extras + kservice
- archlinux-xdg-menu
- 7zip + unzip + unrar

## Fonts

- ttf-jetbrains-mono

## Commands to run

xdg-mime default org.kde.dolphin.desktop inode/directory

## Archive support with Ark

To open archive files from `dolphin` under Hyprland, install the KDE file integration and archive tools:

`sudo pacman -S ark dolphin kio kio-extras kservice archlinux-xdg-menu 7zip unzip unrar`

### KDE menu/cache fix

Hyprland often needs the KDE app menu cache rebuilt manually:

`XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental`

### Persistent Hyprland environment

Add these environment variables to the Hyprland config so KDE menu integration keeps working:

- `env = XDG_MENU_PREFIX,arch-`
- `env = XDG_CURRENT_DESKTOP,Hyprland`

### Default archive associations

Set `ark` as the default app for common archive MIME types:

- `xdg-mime default org.kde.ark.desktop application/zip`
- `xdg-mime default org.kde.ark.desktop application/x-7z-compressed`
- `xdg-mime default org.kde.ark.desktop application/x-rar`

## Hyprland variables

### App shortcuts

- `$terminal` = `kitty`
- `$fileManager` = `dolphin`
- `$menu` = `rofi -show run -show-icons -matching fuzzy`
- `$mainMod` = `SUPER`

## Color palette

The active theme is the **Purple Night** palette.

### Background colors

| Variable | Value |
| --- | --- |
| `$bg0` | `#0d0b14` |
| `$bg1` | `#141225` |
| `$bg2` | `#1b1733` |

### Foreground colors

| Variable | Value |
| --- | --- |
| `$fg0` | `#e6e1ff` |
| `$fg1` | `#b9b4d6` |
| `$fg2` | `#8f8aa8` |

### Accent colors

| Variable | Value |
| --- | --- |
| `$purple0` | `#6c63ff` |
| `$purple1` | `#857bff` |
| `$purple2` | `#a599ff` |
| `$purpleMuted` | `#3a3561` |
| `$pink` | `#ff79c6` |
| `$cyan` | `#7afcff` |
| `$blue` | `#4da6ff` |
| `$green` | `#4dffb5` |
| `$yellow` | `#f1fa8c` |
| `$red` | `#ff5555` |

### Common UI assignments

| Purpose | Variable |
| --- | --- |
| Active border | `$border_active = $purple0` |
| Inactive border | `$border_inactive = $purpleMuted` |
| Urgent border | `$border_urgent = $red` |
| Shadow | `$shadow = rgba(6c63ff90)` |

## Key bindings

### Window and layout controls

| Shortcut | Action |
| --- | --- |
| `SUPER + F` | Toggle fullscreen |
| `F1` | Swap with master |
| `SUPER + F2` | Toggle floating |
| `SUPER + C` | Kill active window |
| `SUPER + P` | Toggle pseudotile |
| `SUPER + J` | Toggle split |
| `ALT + TAB` | Cycle to next window |

### Launchers and utilities

| Shortcut | Action |
| --- | --- |
| `F4` | Launch terminal (`kitty`) |
| `SUPER + E` | Launch file manager (`dolphin`) |
| `SUPER + R` | Launch app menu (`rofi`) |
| `Print` | Open Flameshot GUI with `QT_SCALE_FACTOR="0.75"` |
| `SUPER + V` | Open clipboard menu through `rofi_script.sh` |
| `SUPER + M` | Exit via `hyprshutdown` fallback to `hyprctl dispatch exit` |
| `SUPER + SHIFT + CONTROL + M` | Same shutdown/exit action |

### Special workspaces

| Shortcut | Action |
| --- | --- |
| `CONTROL + Q` | Toggle special workspace `kitty` |
| `SUPER + SHIFT + T` | Toggle special workspace `trash` |
| `CONTROL + SHIFT + Y` | Toggle special workspace `ytmusic` |
| `SUPER + T` | Move active window to special workspace `trash` |

### Focus and window movement

| Shortcut | Action |
| --- | --- |
| `SUPER + Left` | Move focus left |
| `SUPER + Right` | Move focus right |
| `SUPER + Up` | Move focus up |
| `SUPER + Down` | Move focus down |
| `SUPER + Left Mouse` | Drag window |
| `SUPER + Right Mouse` | Resize window |

### Active window resize

| Shortcut | Action |
| --- | --- |
| `SUPER + CTRL + Right` | Resize active window by `50 0` |
| `SUPER + CTRL + Left` | Resize active window by `-50 0` |
| `SUPER + CTRL + Up` | Resize active window by `0 -50` |
| `SUPER + CTRL + Down` | Resize active window by `0 50` |

### Workspaces

| Shortcut | Action |
| --- | --- |
| `SUPER + 1..0` | Switch to workspace `1..10` |
| `SUPER + SHIFT + 1..0` | Move active window to workspace `1..10` |
| `SUPER + Mouse Wheel Down` | Next workspace |
| `SUPER + Mouse Wheel Up` | Previous workspace |

### Audio and brightness

| Shortcut | Action |
| --- | --- |
| `XF86AudioRaiseVolume` | Increase volume by `5%` |
| `XF86AudioLowerVolume` | Decrease volume by `5%` |
| `XF86AudioMute` | Toggle output mute |
| `XF86AudioMicMute` | Toggle microphone mute |
| `XF86MonBrightnessUp` | Increase brightness by `5%` |
| `XF86MonBrightnessDown` | Decrease brightness by `5%` |

### Media controls

| Shortcut | Action |
| --- | --- |
| `XF86AudioNext` | Next track |
| `XF86AudioPause` | Play/pause |
| `XF86AudioPlay` | Play/pause |
| `XF86AudioPrev` | Previous track |
