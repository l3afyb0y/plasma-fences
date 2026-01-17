#!/bin/bash

# Plasma Fences Uninstall Script
# Safely removes the plasmoid while preserving user configuration data

APP_ID="org.kde.plasma.fences"
PACKAGE_NAME="plasma-fences.plasmoid"

echo "--- Plasma Fences Uninstaller ---"

# Function to backup configuration
backup_configuration() {
    echo "Backing up your fences configuration..."

    # Find the configuration file (KDE Plasma stores widget configs here)
    CONFIG_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    BACKUP_FILE="$HOME/plasma-fences-config-backup-$(date +%Y%m%d-%H%M%S).txt"

    if [ -f "$CONFIG_FILE" ]; then
        # Extract fences-related configuration
        grep -A 50 -B 5 "org.kde.plasma.fences" "$CONFIG_FILE" > "$BACKUP_FILE" 2>/dev/null

        if [ -s "$BACKUP_FILE" ]; then
            echo "✓ Configuration backup saved to: $BACKUP_FILE"
            echo "This backup contains your fence layouts, sort rules, and settings."
            echo "Keep this file if you want to restore your configuration later."
        else
            echo "No fences configuration found to backup."
            rm -f "$BACKUP_FILE"
        fi
    else
        echo "No Plasma configuration file found."
    fi
}

# Function to uninstall the plasmoid
uninstall_plasmoid() {
    echo "Uninstalling Plasma Fences..."

    # Try kpackagetool6 first
    kpackagetool6 --type Plasma/Applet --remove "$APP_ID" 2>/dev/null

    # Also remove the directory directly
    rm -rf "$HOME/.local/share/plasma/plasmoids/$APP_ID" 2>/dev/null

    # Remove any cached files
    rm -rf "$HOME/.cache/plasma_plasmashell_*$APP_ID*" 2>/dev/null

    echo "✓ Plasmoid removed from system"
}

# Main execution
backup_configuration
uninstall_plasmoid

echo ""
echo "--- Important Notes ---"
echo "1. Your fences configuration has been backed up (if it existed)"
echo "2. The actual fence panels on your desktop are NOT removed"
echo "3. Your files and folders remain exactly where they were"
echo "4. To reinstall, simply run: ./install.sh"
echo ""
echo "Done."