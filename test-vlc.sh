#!/bin/bash
# Simple VLC test script for Raspberry Pi
# Run this to test if VLC can play video/audio

echo "🎬 Testing VLC video playback on Raspberry Pi..."

# Test URL - known working video
TEST_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

echo "🔧 Setting up environment..."
export DISPLAY=:0

echo "🔊 Configuring audio..."
sudo amixer cset numid=3 2 >/dev/null 2>&1  # Force HDMI audio
amixer set Master 90% unmute >/dev/null 2>&1

echo "📺 Testing VLC with Big Buck Bunny (will play for 30 seconds)..."
echo "   - You should see video on your TV/monitor"
echo "   - You should hear audio through HDMI"
echo "   - Press Ctrl+C to stop early"

timeout 30s vlc \
    --intf dummy \
    --fullscreen \
    --no-video-title-show \
    --video-on-top \
    --no-audio-display \
    --network-caching=2000 \
    "$TEST_URL" 2>/dev/null

exit_code=$?

echo ""
if [ $exit_code -eq 124 ]; then
    echo "✅ Test completed successfully!"
    echo "   If you saw video and heard audio, VLC is working correctly."
elif [ $exit_code -eq 0 ]; then
    echo "✅ VLC finished playing the test video."
else
    echo "❌ VLC test failed (exit code: $exit_code)"
    echo ""
    echo "🔍 Troubleshooting steps:"
    echo "1. Check if VLC is installed: vlc --version"
    echo "2. Check HDMI connection and TV input"
    echo "3. Run diagnostics: ./pi-diagnostics.sh"
    echo "4. Try manual command:"
    echo "   vlc --fullscreen $TEST_URL"
fi

echo ""
echo "🎯 Next steps:"
echo "- If this worked, your IPTV player should work too"
echo "- If not, run: ./pi-diagnostics.sh for detailed troubleshooting"