@echo off
REM Flutter Notepad - Static File Server (Windows)
REM Serves the built web app on http://localhost:8080

set PROJECT_DIR=C:\Users\TF\Desktop\notepad
set PORT=%1
if "%PORT%"=="" set PORT=8080

echo Flutter Notepad - Static Server
echo ================================
echo Serving from: %PROJECT_DIR%\build\web
echo URL:          http://localhost:%PORT%
echo Press Ctrl+C to stop
echo.

cd /d %PROJECT_DIR%\build\web
python -m http.server %PORT%
