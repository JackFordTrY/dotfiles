# Config Overview

Personal Linux desktop configuration centered around **Hyprland** (Wayland) on Arch
Linux. The active visual theme is the **Purple Night** palette, shared across Hyprland
and the Quickshell bar with its notifications, app launcher and clipboard picker.

Hyprland config is split into:

- `hypr/hyprland.conf` — main config (monitors, autostart, env, look & feel)
- `hypr/_variables.conf` — `$`-variables (apps, colors)
- `hypr/_bindings.conf` — all keybindings + the gaming submap
- `hypr/_rules.conf` — window rules + layer rules (file pickers float centred at 55% × 65%,
  whether the portal's window or an app's own "Open Files"-style dialog)

Ideas not built yet are kept in [IDEAS.md](IDEAS.md); what to delete when the disk fills up is in
[DISK-CLEANUP.md](DISK-CLEANUP.md).

## Packages

### Core / compositor

- `hyprland` — Wayland compositor
- `hyprpaper` — wallpaper daemon (autostarted)
- `hyprpolkitagent` — polkit authentication agent (autostarted via `systemctl --user`)
- `polkit`
- `xdg-desktop-portal-hyprland` — screenshare / portals

### Desktop shell

- `quickshell` — status bar (bottom, autostarted)
- `libnotify` — `notify-send`; Quickshell is the notification daemon (see below)
- `kitty` — terminal (`$terminal`); `kitty/kitty.conf` adds a notification when a command
  that ran 15 s or more finishes in a kitty window you're not looking at (`notify_on_cmd_finish`;
  clicking it brings the window back)
- `nwg-look` — GTK theme settings

### Utilities

- `wl-clipboard` + `clipvault` — clipboard history (autostarted), picked from with SUPER + V
- `flameshot` — screenshots (`grim` + `slurp` also available)
- `playerctl` — media key control
- `brightnessctl` — backlight control
- `pipewire` + `wireplumber` — audio (`wpctl` for volume keys)
- `bluez` + `bluez-utils` — Bluetooth
- `pavucontrol` — full audio mixer (the bar's sound page covers everyday volume)
- `hyprshutdown` — shutdown/exit helper (with `hyprctl dispatch exit` fallback)

### File management & archives

- `dolphin` (`$fileManager`) + `ark` + `kio` + `kio-extras` + `kservice`
- `archlinux-xdg-menu`
- `7zip` + `unzip` + `unrar`

## Fonts

> **Required for icons to render.** The bar's icons come from Material Symbols Sharp
> (by ligature name; without the font the names show up as plain words). The terminal uses
> Nerd Font glyphs, which live in the patched Nerd Font — **not** the plain
> `ttf-jetbrains-mono`. Without it, glyphs fall back to Noto Sans Mono and render blank.

```bash
sudo pacman -S ttf-jetbrains-mono-nerd ttf-material-symbols-variable otf-font-awesome \
               noto-fonts noto-fonts-emoji noto-fonts-cjk \
               ttf-nerd-fonts-symbols-mono
```

| Package | Role |
| --- | --- |
| `ttf-jetbrains-mono-nerd` | **Primary** — text + Nerd Font icon glyphs (`JetBrainsMono Nerd Font`) |
| `ttf-material-symbols-variable` | Bar icons (`Material Symbols Sharp`, variable fill/weight) |
| `breeze-icons` | Tray and tray-menu icons (`breeze-dark`, set by `//@ pragma IconTheme` in `shell.qml`) |
| `ttf-jetbrains-mono` | Plain JetBrains Mono (text only, no icons) |
| `otf-font-awesome` | Font Awesome fallback |
| `noto-fonts*` | Text / emoji / CJK coverage |
| `ttf-nerd-fonts-symbols-mono` | Universal icon fallback for non-Nerd fonts |

After installing: `fc-cache -f` then restart Quickshell (a hot reload doesn't pick up new
fonts). Verify with `fc-match "JetBrainsMono Nerd Font"` (must report a
JetBrainsMonoNerdFont file) and `fc-match "Material Symbols Sharp"`.

## Bar

Quickshell (`quickshell/`, autostarted with `exec-once = qs`). Edits hot-reload on save;
`qs log` shows the running bar's log.

Tabs stand straight on the bottom screen edge (44px exclusive zone), with no band behind them.
Every tab, button and panel has a flat bottom, rounded top corners and concave flares where it
meets the screen edge, so it looks grown out of the edge, and a soft purple glow around it.
Their fills are translucent and Hyprland blurs what's behind them with the same blur and noise
as windows (the `quickshell` layer rules in `hypr/_rules.conf`; tray menus and tooltips too).
The glow is cut away inside the shapes so it doesn't tint what shows through. Text and icons
carry a faint shadow a pixel below them, so they stay readable over bright windows. Icons are
Material Symbols Sharp at weight 300; active and hovered icons fill in and glow.
When the shell focuses a window (following a song or a notification, placing Resources, moving
VS Code windows) the cursor stays where it is: `services/Focus.qml` turns `cursor:no_warps` on
for just those dispatches.

Tabs along the bottom, with thin dividers between the groups inside a tab:

- **Left:** system (robot) · RAM | what's playing (title only, hidden when nothing plays) | focused app name
- **Center:** workspaces
- **Right:** Claude sessions | bell · language | Wi-Fi · bluetooth · volume | battery | power | clock (time over date)

Panels open after a 50ms hover dwell and grow in 240ms (`hoverDelay` / `openDuration` /
`closeDuration` in `config/Theme.qml`).

### System panel

Hovering the robot or the RAM grows the left tab into a panel:

- CPU, RAM and disk ring gauges with gradient arcs (hover for per-core usage / sizes)
- a two-minute CPU + RAM usage graph
- your five busiest processes (measured by `top` over a second, every couple of seconds while the
  panel is open), with CPU and memory; the cross ends one after a second click (*End?*). The
  session's own processes (Hyprland, the shell, audio) have no cross
- a chip per special workspace that's open (Hyprland drops one once its last window goes), lit
  while it's showing and with its window count past one; click to toggle it. `kitty` (the
  terminal scratchpad) and `trash` get their own icons
- Docker Desktop: whether its VM is up and the memory it holds, *Quit* (a second click confirms,
  *Quit?*) or *Start* (`systemctl --user stop|start docker-desktop`), and each compose project or
  lone container, running ones first, with a green dot when all of it runs and yellow when part
  does. Its button starts or stops it (`docker start|stop`, or `docker compose -p NAME
  start|stop` for a project); stopping takes a second click (*Stop?*). Read every 3 seconds while
  the panel is open (`bar/controls/DockerList.qml`)

Clicking the robot or a gauge opens `htop`.

### Controls panel

Hovering (or clicking) the Wi-Fi, Bluetooth or volume icon grows the right tab into a panel. Three
tiles sit on top: a tile's icon switches Wi-Fi / Bluetooth on and off or mutes the output, the
rest of the tile picks the page below. Hovering an icon in the bar picks its page too. Under the
tiles, on every page, a brightness slider for the screen (`brightnessctl`; it stops at 1% so the
screen never goes black).

- **Sound** — output and mic sliders, an output picker when there is more than one device, and a
  slider per app that is playing audio. Click a row's icon to mute it.
- **Wi-Fi** — nearby networks (current first, then saved, then by signal), scanned while the
  page is open. Click to connect or disconnect; a new secured network asks for its password in
  the panel (the bar takes the keyboard only while that field is up). Enterprise networks fall
  back to `nmtui`.
- **Bluetooth** — paired devices with battery level, plus nearby ones while **Scan** is on.
  Click to connect or disconnect; a new device is paired, trusted and connected.
- **Calendar** — hover the clock: today's weather (now, the day's range and feels-like, from
  wttr.in for where the connection is; fetched when the page opens and older than half an hour)
  over the month with today marked, weeks starting on the locale's first day. The arrows or the
  wheel page through the months (*Today* comes back); it's on the current month whenever the
  panel opens.
- **Tray** — along the bottom of every page. Tray menus keep the panel open while they're up.

Every page gets the same room, so the panel keeps one size and pages cross-fade; long lists
scroll inside it.

### Media player

The left tab shows the title of whatever MPRIS player is playing (else the one that played
last), with a bouncing equalizer; it's hidden while nothing plays. Clicking it brings up the
player: its own window where it can raise one, or for a browser (Chromium's MPRIS can't) its
window, stepping through the tabs with Ctrl+PageDown until the title shows the track if the
playing tab isn't the one showing; sleeping tabs it passes wake up. Hovering the title turns the
left tab's panel to its media page (opening and closing in 125ms): a big cover beside the
player, title, artist and album, a timeline to click or drag to seek (the track jumps on
release), shuffle / previous / play / next / repeat where the player supports them, and the
cover blurred behind it all. Players with their own volume (mpv, VLC, Spotify...) also get a
slider for it; it moves the player's volume, not its stream in the mixer. Browsers advertise one
that's fixed at 100%, so they don't get the slider. A paused title stays in the bar, dimmed, for
three minutes (so it can be resumed from the media page), and while the panel is open on it.
Scrolling on the title sets the volume 5% a notch, the equalizer showing the level meanwhile: the
player's own where it has a real one, else (browsers) its app's stream in the mixer.

### Workspaces

| # | Icon | Use |
| --- | --- | --- |
| 1 | home | General |
| 2 | globe | Browser |
| 3 | code | Code |
| 4 | terminal | Code 2 |
| 5 | handyman | Utilities |

1–5 are always shown; any other workspace shows its number. Beside it are the icons of the apps
open there (three at most, then a count; the tooltip names them). The active one widens into a
lit pill, empty ones are dimmed and urgent ones turn red. Icons and names live in `kinds` in
`bar/modules/Workspaces.qml`.

### Modules

- **Recording** — a pulsing red dot at the start of the right tab, with a mic, screen or camera
  icon, while something records the microphone (Pipewire input streams), takes video (Pipewire
  video streams) or casts the screen (Hyprland's `screencast` event; the overview's own previews
  don't count). The tooltip names the apps; a click brings up the first one.
- **Claude sessions** — Claude's logo and a chip per running Claude Code session with its
  project: a turning ring while it works, a pulsing pink hand while it waits on you (a permission
  or a question), a green check when it's done, dim once you've looked at its window since (or if
  it finished while you were looking). The tooltip says what it's doing and for how long; a click
  goes to its window (the VS Code window with that project, else a window with the project in its
  title), a right click drops a chip that stayed behind. Claude Code reports to the shell through
  the hook `quickshell/scripts/claude-status.sh`, registered in `~/.claude/settings.json` (outside
  this repo) for SessionStart, UserPromptSubmit, PostToolUse, Notification, Stop and SessionEnd;
  sessions are kept across restarts (`claude-sessions.json` in Quickshell's state folder) and one
  whose `claude` process has gone drops out within a minute. A turn you interrupt keeps showing as
  working until the next prompt, as Claude Code reports no event for it.
- **RAM** — a memory stick that fills with the load and shifts cyan → purple → pink → red, and
  the percentage. Click brings up GNOME Resources floating at 35% × 25%, centred on the current
  workspace (an open Resources window is moved there).
- **App name** — short names: the `names` map in `bar/modules/WindowTitle.qml`, else the
  desktop entry's name. The tooltip shows the full window title.
- **Language** — ENG / RU / UA (map in `services/KeyboardLayout.qml`); click cycles layouts.
- **Volume** — right-click mutes, scroll changes volume by 1%.
- **Bluetooth** — shown while the adapter is on.
- **Power** — click shrinks the right panel to four icons: suspend, log out, reboot, shut down.
  Suspend acts at once; the other three turn into a check mark that has to be clicked again
  within 3 s. (No hibernate: logind reports it unavailable with zram-only swap. No lock: no
  screen locker is installed.) **Clock** — the time over the date; hovering or clicking it shows
  the month (the calendar page below).

### Quickshell

```
quickshell/
├── shell.qml          entry point, one Bar per screen and the notification banners
├── config/Theme.qml   Purple Night palette, bar geometry, fonts, motion
├── components/        EdgeShape (edge-grown outline), Tab / TabItem, Popout (tab that grows
│                      into a panel), MaterialIcon, StyledText, StyledSlider, SectionLabel,
│                      Divider, Chip, PageSlot, CircularGauge, HistoryGraph, Equalizer,
│                      Tooltip, TrayMenu, ThemedIcon, NotificationContent, FloatingPanel,
│                      ContextMenu
├── services/          Notifs (notification daemon + history), Claude (Claude Code sessions),
│                      Audio (Pipewire sinks + app
│                      streams), Players (MPRIS), SystemStats, NetworkInfo (nl80211 scan
│                      signal), BatteryInfo (sysfs), KeyboardLayout, AudioPorts, Brightness,
│                      Privacy (what's recording), Weather (wttr.in), Focus (no-warp focusing)
├── notifications/     Popups.qml, the banners dropping from the top edge; Osd.qml, the volume
│                      and brightness level
├── launcher/          Launcher.qml (SUPER + R), Clipboard.qml (SUPER + V) and Overview.qml
│                      (SUPER + Tab), on Overlay.qml
├── rules/             FolderWorkspaces.qml, VS Code windows to their folder's workspace;
│                      BatteryWarnings.qml
├── assets/            claude.svg, the icon for Claude Code's notifications and sessions
├── scripts/           claude-status.sh, the Claude Code hook behind the bar's Claude chips
└── bar/               Bar.qml; one file per module in bar/modules/ (System and Controls are
                       the tabs with panels); the panels' pages in bar/controls/
```

`//@ pragma Env QT_SCALE_FACTOR_ROUNDING_POLICY=Ceil` in `shell.qml` makes Qt render at 2x and
lets Hyprland downscale to 1.25x, which keeps the 1px borders and flares crisp.

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

## Notifications

Quickshell is the notification daemon (`quickshell/services/Notifs.qml`); Dunst is stopped and
masked (`systemctl --user unmask dunst` to bring it back).

- **Banners** hang from the top edge in the top-right corner. A new one drips out of the edge:
  a narrow drop pushes down with a springy overshoot, then widens into the card. At most three
  at a time (the newest pushes out the oldest), each at most twice the height of a one-line
  notification, the body trimmed with an ellipsis. A burst from one conversation (the same app,
  title and urgency: a chat, a Claude project) shares a banner, showing the newest with a count
  (*Telegram · 3 new*). A line under each runs out with the time it has left. Hovering holds them (and fills the lines back up); click to follow the
  notification (the app's own action, e.g. open the chat, else focus or start the app);
  right-click or the cross hides the banner at once.
- **History**: hover the bell (next to the language) for the notifications page of the controls
  panel, grouped by app (the app with the newest first; a group shows its newest two until *Show
  all*). Entries stay for five minutes unless cleared sooner (the cross on an entry, *Clear* on an
  app's group, or *Clear all*); one still showing as a banner waits for the banner to go. They
  survive restarts (`~/.local/state/quickshell/.../notifications.json`) and can be clicked to
  follow later. The lifetime is `historyLifetime` in `quickshell/services/Notifs.qml`.
- **Claude Code**: the Claude Code Notifier extension in VS Code shows a banner here when Claude
  asks for permission, has a question (in VS Code these come as a permission for
  AskUserQuestion) or finishes (*banner* in its settings, `claudeCodeNotifier.*.level`). The shell
  plays the sounds itself, at volumes of its own and only along with the banner: a two-tone chime
  at 60% when Claude is waiting on you, the finish sound at 45% (`claudeWaitingVolume` and
  `claudeFinishVolume` in `quickshell/services/Notifs.qml`). The extension posts through plain
  `notify-send`, so the shell recognises its banners by their title ("Claude Code — project"):
  they're labelled Claude Code with Claude's logo (`quickshell/assets/claude.svg`), and clicking
  one focuses the VS Code window with that project.
- **Silence**: click the bell. It turns red and crossed out, banners stop, and notifications
  still collect in the history. A dot on the bell means something unread. Right-click it to
  silence for an hour or until 8:00 (banners come back by themselves; the tooltip says when), or
  to turn them back on. Banners also pause by themselves while the screen is shared (the bell
  turns pink), so private messages don't show up on a call.
- Keybindings can use `qs ipc call notifications toggleSilence` and `qs ipc call notifications
  clear`. The gaming-mode messages go through `notify-send`, so they look the same.
- **Battery**: a notification at 15% and an urgent one at 5% (it stays until dismissed), each
  once per discharge, with the time left (`quickshell/rules/BatteryWarnings.qml`).
- **Volume and brightness**: the keys show the level hanging from the middle of the top edge,
  shaped like the banners, for a moment after the last press (`quickshell/notifications/Osd.qml`;
  the bindings call `qs ipc call osd volume`, `mic` or `brightness` after changing it).

## Launcher

SUPER + R opens the shell's app launcher (`quickshell/launcher/Launcher.qml`, through
`qs ipc call launcher toggle`): a search field, a row of pinned apps and every app, most launched
first (the counts rofi left in `~/.cache/rofi3.druncache`, plus its own in
`~/.local/state/quickshell/.../launcher.json`).

- **Pinned:** Opera, Telegram, Discord, and VS Code on `~/work` and on `~/work_lgfg`. Left and
  Right cycle round them, wrapping at the ends; with more than five the row scrolls. Edit the
  `pinned` list at the top of `Launcher.qml` (a desktop entry id, plus `folder` and `label` for
  a VS Code folder).
- **List:** Up and Down move through it (Up from the top goes back to the pinned row), typing
  searches names (start, word starts, anywhere, then letters in order, matches in bold), then
  descriptions and keywords.
- **Windows:** open windows whose title or app holds the query come first (up to four, with
  their workspace); Enter switches to one instead of starting the app again.
- **Actions:** a right click on an app (or Shift+Enter on the selection) lists its own actions,
  e.g. Opera's *New Private Window* or VS Code's *New Empty Window*.
- **Calculator:** arithmetic (`2*21`, `(3 + 4)^2 / 7`) shows its result on top; Enter copies it.
- **Web search:** when nothing matches, the only row searches Google for the query.
- **Commands:** `> command` runs it in a new kitty window, held open to read the output.
- **Enter** launches the selection, as does a click. **Escape**, SUPER + R again or a click
  outside the panel closes it.

## Clipboard

SUPER + V opens the clipboard history (`quickshell/launcher/Clipboard.qml`, through `qs ipc call
clipboard toggle`): what `clipvault` stored, newest first, with a search field.

- **Images** show as thumbnails; the selected one grows into a full preview (fitted to the
  panel, at most 300px tall), and shrinks back as the selection moves on, both easing smoothly.
  They're written out to `~/.cache/clipvault/thumbs/` to be shown.
- **Text** shows one line; the selected entry grows the same way into its first eight lines (in
  full, fetched from `clipvault` once the selection rests).
- **Enter** or a click puts the entry back on the clipboard byte for byte (line breaks,
  indentation and order intact; images as their own type) and pastes it into the window that
  was focused: Hyprland sends it Ctrl+V, or Ctrl+Shift+V in a terminal. **Shift+Delete**
  removes an entry. Escape, SUPER + V again or a click outside closes it.
- Rich text (a browser's bold or links) isn't kept: `wl-paste --watch clipvault store` saves
  one format per copy, the plain text.

## Overview

SUPER + Tab (`quickshell/launcher/Overview.qml`, through `qs ipc call overview toggle`) shows
workspaces 1–5 and any other that's open, each over the wallpaper (read from
`hypr/hyprpaper.conf`) with live previews of its windows where they sit on the screen.

- Click a window to switch to it, or an empty spot to go to that workspace.
- Drag a window onto another workspace to move it there (without following it).
- The cross on a hovered window, or a middle click, closes it.
- The arrows or Tab step through the windows, Enter switches to the selected one and Delete
  closes it; typing dims the windows whose title or app doesn't hold it. Escape, SUPER + Tab
  again or a click outside closes the overview.

## VS Code workspaces

Every VS Code window opens on workspace 3 (the `code-window` rule). Windows on `~/work_lgfg` then
move to workspace 4 and `~/work` stays on 3, once VS Code's title names the folder: Hyprland
rules only see a new window's first title, so `quickshell/rules/FolderWorkspaces.qml` does this
(each window once, so moving one by hand sticks). Add folders to its `folders` map.

Alt+Shift switches the keyboard layout (`kb_options = grp:alt_shift_toggle`). VS Code moves
focus to its menu bar when Alt is let go, which pulled the cursor out of the editor on every
switch, so `window.customMenuBarAltFocus` is off in its settings.

## Hyprland variables

### App shortcuts (`hypr/_variables.conf`)

- `$terminal` = `kitty`
- `$fileManager` = `dolphin`
- `$menu` = `qs ipc call launcher toggle` (the shell's launcher)
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
| `SUPER + R` | Open or close the app launcher (the shell's) |
| `SUPER + Tab` | Open or close the workspace overview |
| `Print` | Flameshot GUI (`QT_SCALE_FACTOR="0.8"`) |
| `SUPER + V` | Clipboard history: pick to paste (the shell's) |
| `SUPER + M` | Exit (`hyprshutdown`, fallback `hyprctl dispatch exit`) |
| `SUPER + SHIFT + CONTROL + M` | Same shutdown/exit action |

### Special workspaces

Also reachable from the bottom of the bar's system panel (see above).

| Shortcut | Action |
| --- | --- |
| `CONTROL + Q` | Toggle special workspace `kitty` |
| `SUPER + SHIFT + T` | Toggle special workspace `trash` |
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
