#!/bin/bash
# Test framebuffer video playback (works without X11)

echo "🧪 Testing Framebuffer Video Playback"
echo "====================================="

TEST_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

echo "🔊 Configuring audio..."
sudo amixer cset numid=3 2 >/dev/null 2>&1  # Force HDMI audio
amixer set Master 90% unmute >/dev/null 2>&1

echo "📺 Testing VLC with framebuffer output..."
echo "   This should work even without desktop/X11"
echo "   Video will play for 30 seconds"
echo "   Press Ctrl+C to stop early"
echo ""

# Clear screen
clear

timeout 30s vlc \
    --intf dummy \
    --vout fb \
    --aout alsa \
    --fullscreen \
    --no-video-title-show \
    --no-audio-display \
    --network-caching=2000 \
    "$TEST_URL" 2>/dev/null

exit_code=$?

echo ""
if [ $exit_code -eq 124 ]; then
    echo "✅ Framebuffer test completed!"
    echo "   If you saw video and heard audio, framebuffer mode works."
elif [ $exit_code -eq 0 ]; then
    echo "✅ VLC finished playing the test video."
else
    echo "❌ Framebuffer test failed (exit code: $exit_code)"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "1. Check if you have framebuffer access: ls -la /dev/fb*"
    echo "2. Try as root: sudo ./test-framebuffer.sh"
    echo "3. Check video group: groups | grep video"
    echo "4. Run full diagnostics: ./pi-diagnostics.sh"
fi

echo ""
echo "💡 If framebuffer works, your IPTV player should work in headless mode!"