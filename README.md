# Plasma Fences

A desktop organizer for KDE Plasma 6, inspired by Stardock Fences for Windows. Create collapsible, transparent containers on your desktop to keep files and shortcuts organized.

![Plasma 6](https://img.shields.io/badge/Plasma-6.0%2B-blue)
![Qt 6](https://img.shields.io/badge/Qt-6-green)
![Wayland](https://img.shields.io/badge/Wayland-compatible-brightgreen)
![Version](https://img.shields.io/badge/version-0.3.0-orange)

## What it does

Plasma Fences gives you transparent containers (called "fences") that sit on your desktop. Each fence displays the contents of a folder - drop files in, double-click to open them, and collapse the fence when you need more space.

You can stack multiple fences vertically, or arrange them in a grid. When you collapse a fence, the others slide up to fill the gap automatically.

## Features

**Multiple panels** - Add as many fences as you need, each pointing to a different folder. They stack vertically for 1-2 panels, or arrange in a grid for 3+.

**Collapse/expand** - Click the handle bar to roll up a fence. Other fences slide into place automatically.

**Resizable** - Drag the dividers between fences to adjust their heights.

**File interaction** - Double-click files to open them. Drag files from Dolphin to copy them into a fence.

**Thumbnails** - Images show previews, other files show their mimetype icons.

**Configurable** - Each fence has its own folder, opacity, icon size, and height settings.

## Requirements

- KDE Plasma 6.0+
- Qt 6
- Works on both Wayland and X11

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/plasma-fences.git
cd plasma-fences
kpackagetool6 -t Plasma/Applet -i .
```

To update after pulling changes:
```bash
kpackagetool6 -t Plasma/Applet -u .
```

To uninstall:
```bash
kpackagetool6 -t Plasma/Applet -r org.kde.plasma.fences
```

## Getting started

1. Right-click your desktop → "Add Widgets..."
2. Search for "Fences" and add it
3. Right-click the widget → "Configure..." to set up your folders
4. Add more panels in the "Panels" tab
5. Adjust layout options in the "Layout" tab

## Configuration

The configuration dialog has two tabs:

**Panels** - Add/remove fences and configure each one:
- Folder path
- Background opacity (10-100%)
- Icon size (24-128px)
- Panel height (100-500px)

**Layout** - Control how fences are arranged:
- Auto (default): stacks 1-2 panels, grid for 3+
- Stack: always vertical
- Grid: always grid layout
- Grid columns (2-4)

## Development

Pure QML, no build step needed. To test changes:

```bash
plasmawindowed org.kde.plasma.fences
```

Check for errors:
```bash
journalctl -f QT_CATEGORY=js QT_CATEGORY=qml
```

## License

MIT
