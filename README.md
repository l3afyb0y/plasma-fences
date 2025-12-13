# Plasma Fences

A KDE Plasma 6 widget that provides collapsible, transparent containers for organizing desktop files and shortcuts. Inspired by Stardock Fences for Windows.

![Plasma 6](https://img.shields.io/badge/Plasma-6.0%2B-blue)
![Qt 6](https://img.shields.io/badge/Qt-6-green)
![Wayland](https://img.shields.io/badge/Wayland-compatible-brightgreen)

## Features

- **Transparent containers** - Dark tinted background that lets your wallpaper show through
- **Collapsible** - Click the handle bar to roll up/down with smooth animation
- **File thumbnails** - Image previews for photos, mimetype icons for other files
- **Drag and drop** - Drop files from Dolphin or other apps to copy them to the folder
- **Smooth scrolling** - Mouse wheel scrolling with no visible scrollbar
- **Configurable** - Choose folder, adjust opacity, change icon size

## Requirements

- KDE Plasma 6.0 or later
- Qt 6
- Wayland or X11 session

## Installation

### From source

```bash
git clone https://github.com/YOUR_USERNAME/plasma-fences.git
cd plasma-fences
kpackagetool6 -t Plasma/Applet -i .
```

### Update

```bash
kpackagetool6 -t Plasma/Applet -u .
```

### Uninstall

```bash
kpackagetool6 -t Plasma/Applet -r org.kde.plasma.fences
```

## Usage

1. Right-click your desktop and select "Add Widgets..."
2. Search for "Fences" and add it to your desktop
3. Right-click the widget and select "Configure..." to choose a folder
4. Click the handle bar at the top to collapse/expand
5. Drag files onto the widget to copy them to the configured folder
6. Scroll with your mouse wheel when content overflows

## Configuration

- **Folder** - The directory whose contents are displayed
- **Opacity** - Background transparency (10% - 100%)
- **Icon size** - Size of file icons (24px - 128px)

## Tips

- Add multiple Fences widgets to organize different folders
- Use lower opacity to better see your wallpaper
- Collapse Fences you're not actively using to save space

## Building / Development

No build step required - this is a pure QML plasmoid.

For development, use:

```bash
# Test in a window (faster iteration)
plasmawindowed org.kde.plasma.fences

# View QML errors
journalctl -f QT_CATEGORY=js QT_CATEGORY=qml
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Issues and pull requests are welcome!
