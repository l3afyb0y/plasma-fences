#!/bin/bash

# Plasma Fences Installation Script
# This script packages and installs the plasma-fences plasmoid.

APP_ID="org.kde.plasma.fences"
PACKAGE_NAME="plasma-fences.plasmoid"

echo "--- Plasma Fences Installer ---"

# Check if we are in the right directory
if [ ! -f "metadata.json" ]; then
    echo "Error: metadata.json not found. Please run this script from the project root."
    exit 1
fi

# Clean up old package if exists
rm -f "$PACKAGE_NAME"

echo "Packaging plasmoid..."
# Create a tar.gz of the contents and metadata.json
# Using tar instead of zip since zip may not be available
tar -czf "$PACKAGE_NAME.tar.gz" contents metadata.json > /dev/null

if [ $? -ne 0 ]; then
    echo "Error: Failed to package plasmoid."
    exit 1
fi

# Update package name to use tar.gz
PACKAGE_NAME="$PACKAGE_NAME.tar.gz"

echo "Installing plasmoid..."
# Uninstall first to ensure a clean install
# Try to remove via kpackagetool6, but also remove the directory directly if it exists
kpackagetool6 --type Plasma/Applet --remove "$APP_ID" 2>/dev/null
rm -rf "$HOME/.local/share/plasma/plasmoids/$APP_ID" 2>/dev/null

# Install the new package (tar.gz format)
kpackagetool6 --type Plasma/Applet --install "$PACKAGE_NAME"

if [ $? -eq 0 ]; then
    echo "Installation successful!"
    echo "You can now add 'Fences' to your desktop via the Plasma widgets menu."
else
    # Fallback to kpackagetool5 if kpackagetool6 is not found (for older Plasma 6 betas or naming differences)
    echo "kpackagetool6 failed, trying kpackagetool5..."
    kpackagetool5 --type Plasma/Applet --remove "$APP_ID" 2>/dev/null
    rm -rf "$HOME/.local/share/plasma/plasmoids/$APP_ID" 2>/dev/null
    kpackagetool5 --type Plasma/Applet --install "$PACKAGE_NAME"
    
    if [ $? -eq 0 ]; then
        echo "Installation successful (via kpackagetool5)!"
    else
        echo "Error: Installation failed. Make sure kpackagetool6 or kpackagetool5 is installed."
        exit 1
    fi
fi

# Clean up
rm -f "$PACKAGE_NAME"

echo "Done."
