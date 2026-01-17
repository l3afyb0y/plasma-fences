# Plasma Fences Uninstall Guide

This guide explains how to safely uninstall Plasma Fences and what happens to your data.

## What Gets Removed vs. What Gets Preserved

### ✅ **SAFE - These are NOT removed:**
- **Your actual fence panels** on the desktop remain visible
- **Your files and folders** stay exactly where they are
- **Your folder organization** is preserved
- **Your configuration** is backed up automatically

### ❌ **REMOVED - These are cleaned up:**
- The plasmoid code (the widget software itself)
- Temporary cache files
- Installation directory

## How to Uninstall

### Method 1: Using the uninstall script (recommended)
```bash
chmod +x uninstall.sh
./uninstall.sh
```

### Method 2: Manual uninstall
```bash
# Remove via kpackagetool
kpackagetool6 --type Plasma/Applet --remove org.kde.plasma.fences

# Remove installation directory
rm -rf ~/.local/share/plasma/plasmoids/org.kde.plasma.fences

# Clean cache
rm -rf ~/.cache/plasma_plasmashell_*org.kde.plasma.fences*
```

## What Happens During Uninstall

1. **Configuration Backup**: The script automatically creates a backup of your fences configuration
   - Backup file name: `plasma-fences-config-backup-YYYYMMDD-HHMMSS.txt`
   - Location: Your home directory
   - Contains: Panel layouts, sort rules, settings

2. **Plasmoid Removal**: The widget code is removed from your system

3. **Cache Cleanup**: Temporary files are cleaned up

## After Uninstalling

### Your Desktop Will:
- ✅ Still show your fence panels (they're just KDE widget instances)
- ✅ Keep all your files and folders organized
- ✅ Maintain your layout and settings

### What Changes:
- ❌ You won't be able to add NEW fences
- ❌ Configuration changes won't be saved
- ❌ Auto-sorting won't work

## Reinstalling

To reinstall after uninstalling:
```bash
./install.sh
```

Your existing fences will continue to work, and you'll be able to add new ones again.

## Troubleshooting

### "Plugin not installed" error
This is normal! It means the plugin wasn't registered in kpackagetool6's database, but the uninstall still worked.

### My fences disappeared!
Don't worry! They're still there. Try:
1. Right-click desktop → "Add Widgets" → Search for "Fences"
2. Your old configuration should still be available

### I want to completely reset everything
If you want to start fresh:
```bash
# Remove configuration (this will reset your fences)
rm -f ~/.config/plasma-org.kde.plasma.desktop-appletsrc
# Then restart Plasma: kquitapp6 plasmashell && kstart6 plasmashell
```

## Technical Details

### Where Configuration is Stored
- Main config: `~/.config/plasma-org.kde.plasma.desktop-appletsrc`
- Widget files: `~/.local/share/plasma/plasmoids/org.kde.plasma.fences/`
- Cache: `~/.cache/plasma_plasmashell_*org.kde.plasma.fences*`

### What the Backup Contains
The backup file contains your:
- Panel configurations (folder paths, sizes, opacity)
- Sort rules and auto-sorting settings
- Layout preferences (grid/stack mode)
- Page configurations (if using multiple pages)

## Safety Guarantee

**Your files are always safe!** Uninstalling Plasma Fences only removes the widget software, not your actual files, folders, or desktop organization. You can always reinstall and your fences will work exactly as before.