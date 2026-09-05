#!/bin/bash
# Flutter Notepad - Web Run Script
# Starts the app in Chrome in debug mode with hot reload

set -e

PROJECT_DIR="/c/Users/TF/Desktop/notepad"
FLUTTER_BIN="$HOME/AppData/Local/Switch/flutter/bin"

export PATH="$FLUTTER_BIN:$PATH"

cd "$PROJECT_DIR"

echo "Flutter Notepad - Web Runner"
echo "============================"
echo "Starting app in Chrome..."
echo ""

flutter run -d chrome
