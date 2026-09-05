@echo off
REM Flutter Notepad - Web Run Script (Windows)
REM Starts the app in Chrome in debug mode with hot reload

set PROJECT_DIR=C:\Users\TF\Desktop\notepad
set FLUTTER_BIN=C:\dev\flutter\bin

set PATH=%FLUTTER_BIN%;%PATH%

cd /d %PROJECT_DIR%

echo Flutter Notepad - Web Runner
echo ============================
echo Starting app in Chrome...
echo.

flutter run -d chrome
