#!/bin/bash
# Flutter Notepad - Static File Server
# Serves the built web app on http://localhost:8080

set -e

PROJECT_DIR="/c/Users/TF/Desktop/notepad"
PORT="${1:-8080}"

echo "Flutter Notepad - Static Server"
echo "================================"
echo "Serving from: $PROJECT_DIR/build/web"
echo "URL:          http://localhost:$PORT"
echo "Press Ctrl+C to stop"
echo ""

cd "$PROJECT_DIR/build/web"
python3 -m http.server "$PORT"
