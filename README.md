# DeskPortals

Fences-style folder portals for macOS. Each panel is a dark, translucent, rounded window
pinned to the desktop layer (above the wallpaper and desktop icons, below every normal window)
that shows the live contents of one folder.

- Icon grid or list view, with Finder's own file icons
- Live updates via FSEvents: files appear and disappear as the folder changes
- Double-click to open; right-click for Open, Show in Finder, Copy Path
- Drag files out to Finder or other apps; drop files onto a panel to **copy** them into its folder
- Title bar with collapse arrow, item count, lock (blocks moving and resizing) and a menu
  (view mode, rename, change folder, show in Finder, remove panel)
- Remembers each panel's folder, position, size, collapsed/locked state and view mode
- Visible on all Spaces, stays put during Mission Control
- Menu-bar app (no Dock icon): Add Panel…, Settings…, Launch at Login, Quit

Panels only display folders. DeskPortals never moves, renames or deletes your files; the only
write it ever makes is copying files you drop onto a panel (name clashes get a " 2" suffix).

## Requirements

macOS 14 or later, Apple Silicon, Xcode command-line tools.

## Build and run

```bash
./build.sh            # → build/DeskPortals.app (ad-hoc signed)
./build.sh install    # also copies it to ~/Applications
open ~/Applications/DeskPortals.app
```

Click the grid icon in the menu bar → **Add Panel…** and pick one or more folders.
Drag a panel by its title bar; resize it from the bottom-right corner.

## Permissions

None are needed for folders in your home directory outside the protected ones. The first
time a panel shows **Desktop**, **Documents**, **Downloads** or a removable/network volume,
macOS asks whether DeskPortals may access that folder; allow it or the panel shows
"Folder not found". **Launch at Login** appears under System Settings → General → Login Items.

## Debugging

`DeskPortals --snapshot <dir> [seconds]` waits, writes each panel as `panel-N.png` to `<dir>`,
and quits.

## Layout

| File | Role |
| --- | --- |
| `AppDelegate.swift` | Menu-bar item, panel lifecycle, settings window, login item |
| `PanelController.swift` | One panel: window, folder listing, collapse/lock/rename, copy-on-drop |
| `DesktopPanel.swift` | Desktop-level `NSPanel`, drag area, resize grip, blur background |
| `PanelView.swift` | SwiftUI header, icon grid and list |
| `FolderContents.swift` | Folder listing and icon cache |
| `FolderWatcher.swift` | FSEvents wrapper |
| `PanelStore.swift` | Panel configs and app settings (UserDefaults) |
