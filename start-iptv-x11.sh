#!/bin/bash
# Auto-start X11 and IPTV player for headless Pi
# This script starts the desktop environment and launches the IPTV player

echo "🖥️ Starting X11 and IPTV Player..."

# Set display
export DISPLAY=:0

# Check if X11 is already running
if ! pgrep -x "Xorg" > /dev/null; then
    echo "🚀 Starting X11 server..."
    
    # Start X11 in background
    sudo systemctl start lightdm 2>/dev/null || {
        # If lightdm not available, start X manually
        startx /home/jeremy/gtv/start-iptv.sh -- :0 vt1 &
        sleep 5
    }
    
    # Wait for X11 to start
    for i in {1..30}; do
        if xset q >/dev/null 2>&1; then
            echo "✅ X11 server is running"
            break
        fi
        echo "   Waiting for X11... ($i/30)"
        sleep 1
    done
    
    if ! xset q >/dev/null 2>&1; then
        echo "❌ Failed to start X11 server"
        echo "💡 Try running: sudo raspi-config"
        echo "   Go to: System Options -> Boot / Auto Login -> Desktop Autologin"
        exit 1
    fi
else
    echo "✅ X11 already running"
fi

# Configure display
echo "🔧 Configuring display..."
xsetroot -solid black 2>/dev/null || true
unclutter -idle 1 -root &

# Configure audio
echo "🔊 Configuring audio..."
sudo amixer cset numid=3 2 >/dev/null 2>&1
amixer set Master 90% unmute >/dev/null 2>&1

# Start IPTV player
echo "📺 Starting IPTV Player..."
cd /home/jeremy/gtv
python3 iptv_smart_player.py