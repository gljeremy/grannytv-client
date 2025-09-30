@echo off
echo ==================================================
echo      VLC Installation for GrannyTV (Simple)
echo ==================================================

echo [INFO] This will help you install VLC Media Player
echo.

:: Check if VLC exists
if exist "%ProgramFiles%\VideoLAN\VLC\vlc.exe" (
    echo [SUCCESS] VLC already installed at: %ProgramFiles%\VideoLAN\VLC\vlc.exe
    echo [INFO] You can now run: python iptv_smart_player.py
    pause
    exit /b 0
)

if exist "%ProgramFiles(x86)%\VideoLAN\VLC\vlc.exe" (
    echo [SUCCESS] VLC already installed at: %ProgramFiles(x86)%\VideoLAN\VLC\vlc.exe  
    echo [INFO] You can now run: python iptv_smart_player.py
    pause
    exit /b 0
)

echo [INFO] VLC not found. Opening VLC download page...
echo.
echo Please follow these steps:
echo 1. Download VLC from the website that will open
echo 2. Install VLC with default settings
echo 3. Then run: python iptv_smart_player.py
echo.

:: Open VLC download page
start https://www.videolan.org/vlc/download-windows.html

echo [INFO] VLC download page opened in your browser
echo [INFO] After installing VLC, run: python iptv_smart_player.py
pause