# Config Overview

Personal Linux desktop configuration centered around **Hyprland** (Wayland) on Arch
Linux. The active visual theme is the **Purple Night** palette, shared across Hyprland,
the Quickshell bar, Rofi and Dunst.

Hyprland config is split into:

- `hypr/hyprland.conf` — main config (monitors, autostart, env, look & feel)
- `hypr/_variables.conf` — `$`-variables (apps, colors)
- `hypr/_bindings.conf` — all keybindings + the gaming submap
- `hypr/_rules.conf` — window rules + layer rules

## Packages

### Core / compositor

- `hyprland` — Wayland compositor
- `hyprpaper` — wallpaper daemon (autostarted)
- `hyprpolkitagent` — polkit authentication agent (autostarted via `systemctl --user`)
- `polkit`
- `xdg-desktop-portal-hyprland` — screenshare / portals

### Desktop shell

- `quickshell` — status bar (bottom, autostarted)
- `waybar` — previous status bar; config kept in `waybar/` as the reference (not autostarted)
- `rofi` — app launcher / clipboard / power menu
- `dunst` — notification daemon (themed + blurred, see below)
- `kitty` — terminal (`$terminal`)
- `nwg-look` — GTK theme settings

### Utilities

- `wl-clipboard` + `clipvault` — clipboard history (autostarted)
- `flameshot` — screenshots (`grim` + `slurp` also available)
- `playerctl` — media key control
- `brightnessctl` — backlight control
- `pipewire` + `wireplumber` — audio (`wpctl` for volume keys)
- `bluez` + `bluez-utils` — Bluetooth
- `pavucontrol` — audio mixer (opened from the bar)
- `hyprshutdown` — shutdown/exit helper (with `hyprctl dispatch exit` fallback)

### File management & archives

- `dolphin` (`$fileManager`) + `ark` + `kio` + `kio-extras` + `kservice`
- `archlinux-xdg-menu`
- `7zip` + `unzip` + `unrar`

## Fonts

> **Required for icons to render.** The bar, Dunst, Rofi and the terminal use Nerd Font
> glyphs (workspace icons, the special-workspaces drawer, audio/battery/network icons,
> notification icons). These live in the patched Nerd Font — **not** the plain
> `ttf-jetbrains-mono`. Without it, glyphs fall back to Noto Sans Mono and render blank.

```bash
sudo pacman -S ttf-jetbrains-mono-nerd otf-font-awesome \
               noto-fonts noto-fonts-emoji noto-fonts-cjk \
               ttf-nerd-fonts-symbols-mono
```

| Package | Role |
| --- | --- |
| `ttf-jetbrains-mono-nerd` | **Primary** — text + all icon glyphs (`JetBrainsMono Nerd Font`) |
| `ttf-jetbrains-mono` | Plain JetBrains Mono (text only, no icons) |
| `otf-font-awesome` | Font Awesome fallback |
| `noto-fonts*` | Text / emoji / CJK coverage |
| `ttf-nerd-fonts-symbols-mono` | Universal icon fallback for non-Nerd fonts |

After installing: `fc-cache -f` then restart Quickshell/Dunst. Verify with
`fc-match "JetBrainsMono Nerd Font"` (must report a JetBrainsMonoNerdFont file).

## Bar

Quickshell (`quickshell/`, autostarted with `exec-once = qs`) — a pixel-for-pixel port of the
previous Waybar bar. Waybar's config stays as the reference: `waybar/config` (loaded over
`config.jsonc`), modules in `waybar/themes/starter/modules.jsonc`, styling in
`waybar/style.css` + `waybar/theme.css`. To switch back, swap the commented `exec-once` lines
in `hypr/hyprland.conf` (or right now: `pkill -x qs; hyprctl dispatch exec waybar`).

- Position: **bottom**, with 10px left/right margins.
- **Left:** hardware drawer (system/disk/cpu/memory) · **special-workspaces drawer** · window title
- **Center:** workspaces
- **Right:** language · audio · bluetooth · battery · network · tray drawer · power menu · clock

### Special-workspaces drawer

A collapsing layer-group icon () on the left. Click it to expand and reveal
click-shortcuts to the special workspaces (mirrors the keybindings below):

| Icon | Action |
| --- | --- |
|  | Toggle special workspace `kitty` (terminal scratchpad) |
|  | Toggle special workspace `ytmusic` |
|  | Toggle special workspace `trash` |

> The legacy "Apps" launcher button and the settings cogwheel were removed.

### Quickshell

Same modules, geometry, colors, fonts, hover states, drawers, tooltips and click actions as
the Waybar config. Edits hot-reload on save; `qs log` shows the running bar's log.

```
quickshell/
├── shell.qml          entry point, one Bar per screen
├── config/Theme.qml   Purple Night palette + Waybar's measured geometry
├── components/        GTK look-alikes: BarText/Label (Pango-style text), Module (CSS box),
│                      Drawer (group drawer), Tooltip, TrayMenu (Adwaita GtkMenu)
├── services/          data with Waybar's exact formulas: SystemStats, NetworkInfo (nl80211
│                      scan signal), BatteryInfo (sysfs), KeyboardLayout, AudioPorts
└── bar/               Bar.qml + one file per Waybar module in bar/modules/
```

How it matches GTK:

- `//@ pragma Env QT_SCALE_FACTOR_ROUNDING_POLICY=Ceil` makes Qt render at 2x and let
  Hyprland downscale to 1.25x, the way GTK3 Waybar renders (it has no fractional scaling).
- Text uses Pango's hinted metrics: whole-pixel advances (10px cells for JetBrains Mono at
  16px), line boxes with ascent/descent rounded up, labels sized by advance (not ink).
- Icons are the same font glyphs Waybar draws. Codepoints the Nerd Font lacks (`E473`,
  `F5FD`, `F5E7`, `F796`, `F6A9`, `F590`) use Font Awesome 7 Free Solid, like Pango's fallback.
- Remaining difference: Qt doesn't hint glyphs at 2x, so text strokes can differ by up to
  one native pixel; tooltips/menus use 15px text because Qt can't render GTK's 14.67px.

Language server (VSCode, `theqtcompany.qt-qml` extension):

- `quickshell/.qmlls.ini` — create it **empty**; `qs` replaces it with a symlink to a
  generated config under `/run/user/$UID/quickshell/vfs/`. It is machine-specific and
  gitignored. `/run/user` is cleared on reboot, so run `qs` once after boot for qmlls.
- VSCode settings (`vscode-conf/settings.json`): `qt-qml.qmlls.useQmlImportPathEnvVar`,
  plus `qt-qml.qmlls.customExePath` pinned to the system `/usr/lib/qt6/bin/qmlls` (the
  Qt Core extension auto-detects Qt 5 from `/usr/bin/qmake`, which has no qmlls).
- `Type PanelWindow is not creatable [uncreatable-type]` is a known false positive —
  Quickshell exposes an interface type to tooling and picks the Wayland/X11 implementation
  at runtime.

## Notifications (Dunst)

Config: `dunst/dunstrc`. Themed to the Purple Night palette — purple `#6c63ff` frames,
`#141225`/`#0d0b14` backgrounds at ~90% alpha, rounded corners, red frame for critical.

Backgrounds are semi-transparent so the Hyprland **blur** shows through, matching the
general theme. The blur is enabled by a layer rule in `hypr/_rules.conf`:

```ini
layerrule {
    name = blur-notifications
    match:namespace = ^(notifications)$
    blur = true
    ignore_alpha = 0.6
}
```

> Hyprland 0.53+ requires the **block** layer-rule syntax above; the legacy
> `layerrule = blur, notifications` one-liner no longer parses.

## Hyprland variables

### App shortcuts (`hypr/_variables.conf`)

- `$terminal` = `kitty`
- `$fileManager` = `dolphin`
- `$menu` = `rofi -show drun -show-icons -matching fuzzy`
- `$mainMod` = `SUPER` (the "Windows" key)

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
| `SUPER + F` | Maximize (fullscreen mode 1, keeps bar/gaps) |
| `SUPER + SHIFT + F` | True fullscreen (mode 0) |
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
| `Print` | Flameshot GUI (`QT_SCALE_FACTOR="0.8"`) |
| `SUPER + V` | Clipboard history menu (Rofi + `rofi_script.sh`) |
| `SUPER + M` | Exit (`hyprshutdown`, fallback `hyprctl dispatch exit`) |
| `SUPER + SHIFT + CONTROL + M` | Same shutdown/exit action |

### Special workspaces

Also reachable from the bar's special-workspaces drawer (see above).

| Shortcut | Action |
| --- | --- |
| `CONTROL + Q` | Toggle special workspace `kitty` |
| `SUPER + SHIFT + T` | Toggle special workspace `trash` |
| `CONTROL + SHIFT + Y` | Toggle special workspace `ytmusic` |
| `SUPER + T` | Move active window to special workspace `trash` |

### Focus and window movement

| Shortcut | Action |
| --- | --- |
| `SUPER + Left/Right/Up/Down` | Move focus in direction |
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
| `XF86AudioPause` / `XF86AudioPlay` | Play/pause |
| `XF86AudioPrev` | Previous track |

### Gaming mode (submap)

`SUPER + ALT + G` toggles a **gaming submap**. While active, all global keybinds are
blocked so games receive every key directly — **except** the `SUPER` ($mainMod) binds,
which are re-declared inside the submap and stay live (fullscreen, workspaces, focus,
resize, kill, launchers, clipboard, special:trash, etc.). A notification confirms
ON/OFF.

| Shortcut | Action |
| --- | --- |
| `SUPER + ALT + G` | Toggle gaming mode on/off |

While in gaming mode, `Print` (Flameshot) and all `SUPER` binds remain available.

## Archive support with Ark

To open archive files from `dolphin` under Hyprland, install the KDE file integration
and archive tools:

```bash
sudo pacman -S ark dolphin kio kio-extras kservice archlinux-xdg-menu 7zip unzip unrar
```

### KDE menu/cache fix

Hyprland often needs the KDE app menu cache rebuilt manually:

```bash
XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental
```

### Persistent Hyprland environment

Already set in `hypr/hyprland.conf` so KDE menu integration keeps working:

- `env = XDG_MENU_PREFIX,arch-`
- `env = XDG_CURRENT_DESKTOP,Hyprland`

### Default file/archive associations

```bash
xdg-mime default org.kde.dolphin.desktop inode/directory
xdg-mime default org.kde.ark.desktop application/zip
xdg-mime default org.kde.ark.desktop application/x-7z-compressed
xdg-mime default org.kde.ark.desktop application/x-rar
```

## Sudo: fewer password prompts

By default sudo uses **per-terminal** tickets (`tty_tickets`), so every new
terminal/kitty window re-asks for the password, and the cache also expires quickly.
To make sudo ask **rarely** — while still keeping a password barrier for root — a
drop-in sets a single shared credential cache with a 60-minute timeout.

A version-controlled copy lives at `sudoers.d/10-timeout`:

```ini
Defaults timestamp_type=global
Defaults timestamp_timeout=60
```

- `timestamp_type=global` — one shared credential cache across all terminals, so
  authenticating in one window covers the rest (fixes the "asks every time" symptom).
- `timestamp_timeout=60` — remember credentials for 60 minutes.

### Install (safely)

Editing sudoers wrong can lock you out of `sudo`, so always validate before and
after. The repo copy is already syntax-checked; install it with correct ownership
and permissions (`root:root`, `0440`), then re-validate the whole config:

```bash
# 1. validate the drop-in's syntax in isolation
visudo -cf ~/.config/sudoers.d/10-timeout

# 2. install it as root with the required permissions
sudo install -m 0440 -o root -g root ~/.config/sudoers.d/10-timeout /etc/sudoers.d/10-timeout

# 3. validate the entire effective sudoers config
sudo visudo -c
```

Then run any `sudo` command once to seed the cache; subsequent ones (in any terminal)
won't prompt again for 60 minutes.

> **Tip:** keep a second root/sudo-capable terminal open while testing. If `sudo visudo -c`
> ever reports an error, remove the file with `sudo rm /etc/sudoers.d/10-timeout` from that
> still-authenticated session before closing it.
>
> To revert entirely: `sudo rm /etc/sudoers.d/10-timeout`.
