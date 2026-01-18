# Plasma Fences

A desktop organization widget for KDE Plasma 6, inspired by Stardock Fences. It provides stackable, collapsible containers (fences) to group your desktop icons and folders.

![Plasma 6](https://img.shields.io/badge/Plasma-6.0%2B-blue)
![Qt 6](https://img.shields.io/badge/Qt-6-green)
![Wayland](https://img.shields.io/badge/Wayland-compatible-brightgreen)
![Version](https://img.shields.io/badge/version-0.4.0-orange)

		**IMPORTANT** 
Last I checked, this project is not working correctly anymore. I need to take some time with it and sift through for a fix, but I have other projects that need some fixes first. 
Feel free to submit pull requests if you find a solution to the issue for me, and I will merge a working version and update the repo.


## Features

- **Multi-Panel Support**: Create multiple containers within a single widget.
- **Stack & Grid Layouts**: Panels can be stacked vertically or organized in a grid.
- **Rollup (Collapse)**: Double-click a panel's title bar to collapse it.
- **Peeking**: Hover over a rolled-up panel to temporarily view its contents.
- **Desktop Pages**: Organize your fences across multiple desktop "pages" and switch between them using dots at the bottom.
- **Automatic Sorting**: Automatically move files from your Desktop into specific fences based on file extensions.
- **Quick-hide**: Double-click the desktop (widget background) to instantly hide or show all your fences.
- **Folder Portals**: Mirror any folder on your system directly onto your desktop.
- **Resizing**: Easily adjust the height of individual panels by dragging the resize handle.
- **Customization**: Adjust icon size, background opacity, and sort rules for each panel.

## Installation

### Dependencies
- KDE Plasma 6
- `kirigami`
- `plasma5support`

### Installation Script
Run the included installation script to package and install the plasmoid:
```bash
chmod +x install.sh
./install.sh
```

### Manual Installation
```bash
git clone https://github.com/l3afyb0y/plasma-fences.git
cd plasma-fences
kpackagetool6 -t Plasma/Applet -i .
```

### Updating/Reinstalling
To update or reinstall Plasma Fences, use the included scripts. Your configuration is preserved during the process.

## Uninstallation

To safely remove Plasma Fences while preserving your configuration:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

### What Happens During Uninstall
1. **Configuration Backup**: A backup of your fence layouts and settings is saved to your home directory (`plasma-fences-config-backup-YYYYMMDD-HHMMSS.txt`).
2. **Data Safety**: Your actual files and folders are **never** removed or moved. Only the widget software is uninstalled.
3. **Manual Method**:
   ```bash
   kpackagetool6 --type Plasma/Applet --remove org.kde.plasma.fences
   rm -rf ~/.local/share/plasma/plasmoids/org.kde.plasma.fences
   ```

## Usage

1. **Add the Widget**: Right-click your desktop, select "Add Widgets", and search for "Fences".
2. **Configure**: Right-click the widget and select "Fences Settings".
3. **Add Panels**: In the "Panels" tab, you can add new containers and set their source folder.
4. **Auto-Sort**: Enable "Automatic Sorting" in the General settings and define rules (e.g., `jpg, png, pdf`) for each panel.
5. **Rollup**: Double-click the title bar of any panel to collapse it. Hovering over it while collapsed will "peek" the contents.
6. **Hide**: Double-click any empty area within the widget to toggle the visibility of all fences.
7. **Pages**: Adjust the "Desktop Pages" count in the Layout tab to enable multiple pages. Switch between them using the indicator dots.

## License
MIT
