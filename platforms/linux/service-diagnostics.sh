#!/bin/bash
# GrannyTV Service Troubleshooting Script
# Quick diagnostics and fixes for auto-start issues

echo "🔍 GrannyTV Service Diagnostics"
echo "==============================="

SERVICE_NAME="iptv-player"
PI_PATH="/home/jeremy/gtv"

# Check if service exists
echo "📋 Service Status:"
if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    echo "✅ Service is installed"
    sudo systemctl status "$SERVICE_NAME" --no-pager
else
    echo "❌ Service not installed"
    echo "💡 Run: sudo cp platforms/linux/iptv-player.service /etc/systemd/system/"
    echo "💡 Then: sudo systemctl enable iptv-player"
fi

echo ""
echo "📊 System Information:"
echo "   Pi Model: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
echo "   OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
echo "   Python: $(python3 --version 2>/dev/null || echo 'Not found')"
echo "   MPV: $(mpv --version 2>/dev/null | head -1 || echo 'Not installed')"

echo ""
echo "🌐 Network Status:"
if ping -c1 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet connection working"
else
    echo "❌ No internet connection"
fi

echo ""
echo "🖥️ Display Status:"
if [ -n "$DISPLAY" ]; then
    echo "✅ DISPLAY variable set: $DISPLAY"
    if xset q >/dev/null 2>&1; then
        echo "✅ X11 display working"
    else
        echo "❌ X11 display not responding"
    fi
else
    echo "❌ No DISPLAY variable set"
fi

echo ""
echo "🔊 Audio Status:"
if aplay -l | grep -q HDMI; then
    echo "✅ HDMI audio device found"
else
    echo "❌ No HDMI audio device"
fi

echo ""
echo "📁 File System:"
if [ -d "$PI_PATH" ]; then
    echo "✅ Project directory exists: $PI_PATH"
    cd "$PI_PATH"
    
    if [ -f "iptv_smart_player.py" ]; then
        echo "✅ Main script found"
    else
        echo "❌ Main script missing"
    fi
    
    if [ -d "venv" ]; then
        echo "✅ Virtual environment exists"
        if [ -f "venv/bin/python" ]; then
            echo "✅ Python in venv working"
        else
            echo "❌ Python in venv broken"
        fi
    else
        echo "❌ Virtual environment missing"
    fi
else
    echo "❌ Project directory missing: $PI_PATH"
fi

echo ""
echo "📋 Recent Service Logs (last 20 lines):"
journalctl -u "$SERVICE_NAME" -n 20 --no-pager 2>/dev/null || echo "No service logs available"

echo ""
echo "🔧 Quick Fixes:"
echo ""
echo "🚀 Restart service:"
echo "   sudo systemctl restart iptv-player"
echo ""
echo "📊 Watch live logs:"
echo "   journalctl -u iptv-player -f"
echo ""
echo "🛠️ Manual start (for testing):"
echo "   cd $PI_PATH && source venv/bin/activate && python3 iptv_smart_player.py"
echo ""
echo "🔄 Reinstall service:"
echo "   sudo cp platforms/linux/iptv-player.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable iptv-player"
echo ""
echo "🔧 If network issues:"
echo "   sudo systemctl restart networking"
echo "   sudo dhclient -r && sudo dhclient"