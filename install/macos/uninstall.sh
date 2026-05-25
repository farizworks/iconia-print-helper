#!/usr/bin/env bash
set -euo pipefail

LABEL="com.iconia.print-helper"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
INSTALL_DIR="$HOME/Library/Application Support/Iconia Print Helper"
USER_DOMAIN="gui/$(id -u)"

launchctl bootout "$USER_DOMAIN" "$PLIST_PATH" >/dev/null 2>&1 || true
rm -f "$PLIST_PATH"

echo "Iconia Print Helper stopped and removed from auto-start."
echo "Local files remain at: $INSTALL_DIR"
echo "Delete that directory manually if local config and logs are no longer needed."
