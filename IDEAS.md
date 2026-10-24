# Ideas

Suggestions for the desktop that haven't been picked yet, kept for later. Each has a note on how
it would fit into the current setup. Delete an entry once it's built or no longer wanted.

## Session

- **Lock screen and idle timeout** — dim after a few idle minutes, lock a little later, suspend
  later still, without extra packages: Quickshell's `WlSessionLock` (Quickshell.Wayland) draws a
  lock screen in the bar's style, and its idle notifier (ext-idle-notify) does the timing. Adds a
  Lock icon to the power page (`bar/controls/PowerPage.qml`); nothing locks the screen today
  (`hyprlock` and `hypridle` aren't installed).
- **Keep-awake tile** — a tile in the right panel that holds off the idle timeout and sleep while
  on (Quickshell's `IdleInhibitor`), for watching something. Pairs with the lock screen.
- **Night light** — a tile that warms the screen's colours in the evening. Needs `hyprsunset`.

## Notifications

- **Silence in gaming mode** — banners off while the gaming submap (`hypr/_bindings.conf`) is on,
  back on when it ends: enter/leave the submap with `qs ipc call notifications …`, or watch
  Hyprland's `submap` event in `services/Notifs.qml`.
- **Reply from the banner** — Telegram and Discord offer inline replies; Quickshell exposes
  `hasInlineReply` and `sendInlineReply()` on a notification, so the card in
  `notifications/Popups.qml` (and the history entry) would need a text field.

## Bar and panels

- **Bluetooth device battery** — the battery level of connected headphones next to the Bluetooth
  icon in the bar (`bar/modules/Bluetooth.qml`); the Bluetooth page already reads it per device.

## Launcher and clipboard

- **Emoji picker** — `:` then a name (`:fire`) lists matching emoji in the launcher
  (`launcher/Launcher.qml`), Enter copies one. Needs an emoji name list shipped with the shell
  (or read from a package such as `unicode-emoji`).
- **Clipboard pins** — pin entries so they stay at the top of the clipboard picker
  (`launcher/Clipboard.qml`) and never expire, and a "clear all". clipvault has no pins, so they'd
  be the shell's own list (ids, or a copy of the content for ones that age out).

## Windows

- **Picture-in-picture rule** — Opera's video pop-out floats, stays on top and on every
  workspace (`pin`), in a corner at a fixed size: a window rule in `hypr/_rules.conf` matched by
  its title ("Picture in picture").

## Tools

- **Screenshot tool** — replaces Flameshot on Print: pick an area (or a window, or the screen)
  over a dimmed screen in the shell's style, then copy, save or annotate from a small toolbar.
  `grim` and `slurp` are installed; the overlay would be a layer like `launcher/Overlay.qml`.

## Housekeeping

- **Commit** — the shell and Hyprland changes on `hyprland-config` aren't committed yet. A few
  commits grouped by feature would make each easy to roll back.
