#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_SOURCE="${1:-$HELPER_ROOT/config.json}"
BINARY_SOURCE="${2:-}"
INSTALL_DIR="$HOME/Library/Application Support/Iconia Print Helper"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LABEL="com.iconia.print-helper"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$LABEL.plist"
EXECUTABLE_PATH="$INSTALL_DIR/iconia_print_helper"
CONFIG_PATH="$INSTALL_DIR/config.json"
LOG_PATH="$INSTALL_DIR/print_helper.log"
ERROR_LOG_PATH="$INSTALL_DIR/print_helper.error.log"
USER_DOMAIN="gui/$(id -u)"

if [[ ! -f "$CONFIG_SOURCE" ]]; then
  echo "Config file not found: $CONFIG_SOURCE" >&2
  echo "Create config.json from config.example.json before installing." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$LAUNCH_AGENTS_DIR"

if [[ -n "$BINARY_SOURCE" ]]; then
  if [[ ! -f "$BINARY_SOURCE" ]]; then
    echo "Compiled helper not found: $BINARY_SOURCE" >&2
    exit 1
  fi
  cp "$BINARY_SOURCE" "$EXECUTABLE_PATH"
else
  if ! command -v dart >/dev/null 2>&1; then
    echo "Dart is required to compile locally, or provide a compiled binary." >&2
    exit 1
  fi
  (
    cd "$HELPER_ROOT"
    dart pub get
    dart compile exe bin/print_helper.dart -o "$EXECUTABLE_PATH"
  )
fi

chmod 700 "$EXECUTABLE_PATH"
cp "$CONFIG_SOURCE" "$CONFIG_PATH"
chmod 600 "$CONFIG_PATH"
touch "$LOG_PATH" "$ERROR_LOG_PATH"

cat >"$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$EXECUTABLE_PATH</string>
    <string>$CONFIG_PATH</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>StandardOutPath</key>
  <string>$LOG_PATH</string>
  <key>StandardErrorPath</key>
  <string>$ERROR_LOG_PATH</string>
</dict>
</plist>
EOF

launchctl bootout "$USER_DOMAIN" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "$USER_DOMAIN" "$PLIST_PATH"
launchctl kickstart -k "$USER_DOMAIN/$LABEL"

echo "Iconia Print Helper installed and started."
echo "Config: $CONFIG_PATH"
echo "Logs:   $LOG_PATH"
echo "Errors: $ERROR_LOG_PATH"
