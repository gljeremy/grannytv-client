#!/bin/bash
# Diagnostic script for Raspberry Pi IPTV issues
# Run this on your Pi to diagnose video/audio problems

echo "🔍 IPTV Player Diagnostics for Raspberry Pi"
echo "=========================================="

# Check system info
echo "📋 System Information:"
echo "- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "- Kernel: $(uname -r)"
echo "- Architecture: $(uname -m)"
echo ""

# Check display
echo "🖥️ Display Configuration:"
echo "- DISPLAY variable: ${DISPLAY:-'Not set'}"
echo "- X11 running: $(ps aux | grep -v grep | grep -c 'Xorg\|X ')"
echo "- Desktop session: ${XDG_CURRENT_DESKTOP:-'None'}"
echo "- Wayland: ${WAYLAND_DISPLAY:-'Not running'}"
echo ""

# Check audio
echo "🔊 Audio Configuration:"
echo "- Audio devices:"
aplay -l 2>/dev/null || echo "  No audio devices found"
echo ""
echo "- ALSA mixer settings:"
amixer get Master 2>/dev/null | grep -E "(Mono|Front)" || echo "  Master volume not available"
echo ""
echo "- Audio output routing:"
sudo amixer cget numid=3 2>/dev/null || echo "  Cannot get audio routing info"
echo ""

# Check video players
echo "🎬 Video Player Availability:"
for player in vlc mplayer mpv omxplayer; do
    if command -v $player >/dev/null 2>&1; then
        version=$($player --version 2>&1 | head -1 || echo "Version unknown")
        echo "✅ $player: $version"
    else
        echo "❌ $player: Not installed"
    fi
done
echo ""

# Check graphics
echo "🎨 Graphics Configuration:"
echo "- GPU memory split:"
vcgencmd get_mem gpu 2>/dev/null || echo "  Cannot get GPU memory info"
echo "- Video codecs:"
for codec in H264 MPG2 WVC1 MPG4 MJPG WMV9 VP6 VP8 FLAC; do
    status=$(vcgencmd codec_enabled $codec 2>/dev/null || echo "disabled")
    echo "  $codec: $status"
done
echo ""

# Check network
echo "🌐 Network Status:"
echo "- Internet connectivity:"
if ping -c 1 google.com >/dev/null 2>&1; then
    echo "✅ Internet connection working"
else
    echo "❌ No internet connection"
fi
echo ""

# Test a simple stream
echo "🧪 Stream Test:"
echo "Testing with a simple MP4 stream..."

TEST_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

# Try VLC first (most likely to work)
if command -v vlc >/dev/null 2>&1; then
    echo "🎥 Testing VLC (5 second test)..."
    timeout 5s vlc --intf dummy --play-and-exit "$TEST_URL" >/dev/null 2>&1
    if [ $? -eq 0 ] || [ $? -eq 124 ]; then  # 124 is timeout exit code
        echo "✅ VLC can play streams"
    else
        echo "❌ VLC failed to play test stream"
    fi
fi

# Hardware acceleration test
echo ""
echo "🏎️ Hardware Acceleration:"
if [ -e /dev/vchiq ]; then
    echo "✅ VideoCore GPU interface available"
else
    echo "❌ VideoCore GPU interface not found"
fi

if [ -e /opt/vc/bin/vcgencmd ]; then
    echo "✅ VideoCore tools available"
else
    echo "❌ VideoCore tools not found"
fi

echo ""
echo "📊 Recommendations:"

# Audio recommendations
if ! aplay -l >/dev/null 2>&1; then
    echo "⚠️  Install audio: sudo apt install alsa-utils pulseaudio"
fi

# Display recommendations
if [ -z "$DISPLAY" ]; then
    echo "⚠️  Set DISPLAY variable: export DISPLAY=:0"
fi

# Player recommendations
if ! command -v vlc >/dev/null 2>&1; then
    echo "⚠️  Install VLC: sudo apt install vlc"
fi

echo ""
echo "🔧 Quick Fixes to Try:"
echo "1. Force audio to HDMI: sudo amixer cset numid=3 2"
echo "2. Increase volume: amixer set Master 100%"
echo "3. Check HDMI connection and TV input"
echo "4. Try running with GUI: startx (then run the player)"
echo "5. Test VLC manually: vlc --fullscreen [stream-url]"
echo ""
echo "📋 If problems persist, share this output for further help!"