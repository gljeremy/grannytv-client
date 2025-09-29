#!/bin/bash
# Comprehensive video player testing for Raspberry Pi
# Tests VLC, MPV, and MPlayer with different outputs

echo "🎬 Comprehensive Video Player Testing"
echo "===================================="

TEST_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
TEST_DURATION=10

# Configure audio
echo "🔊 Configuring audio..."
sudo amixer cset numid=3 2 >/dev/null 2>&1  # Force HDMI audio
amixer set Master 90% unmute >/dev/null 2>&1

# Test 1: VLC with different outputs
echo ""
echo "1. Testing VLC with different video outputs:"

vlc_outputs=("fb" "caca" "dummy")
for vout in "${vlc_outputs[@]}"; do
    echo "   Testing VLC --vout $vout..."
    
    timeout ${TEST_DURATION}s vlc \
        --intf dummy \
        --vout "$vout" \
        --aout alsa \
        --no-video-title-show \
        --no-audio-display \
        --network-caching=2000 \
        --play-and-exit \
        "$TEST_URL" >/dev/null 2>&1
    
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "   ✅ VLC $vout: SUCCESS"
    elif [ $exit_code -eq 124 ]; then
        echo "   ⏱️ VLC $vout: TIMEOUT (likely working)"
    else
        echo "   ❌ VLC $vout: FAILED (exit: $exit_code)"
    fi
done

# Test 2: MPV with different outputs
echo ""
echo "2. Testing MPV with different video outputs:"

if command -v mpv >/dev/null 2>&1; then
    mpv_outputs=("drm" "fbdev" "caca")
    for vo in "${mpv_outputs[@]}"; do
        echo "   Testing MPV --vo=$vo..."
        
        timeout ${TEST_DURATION}s mpv \
            --vo="$vo" \
            --ao=alsa \
            --no-terminal \
            --really-quiet \
            --length=5 \
            "$TEST_URL" >/dev/null 2>&1
        
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "   ✅ MPV $vo: SUCCESS"
        elif [ $exit_code -eq 124 ]; then
            echo "   ⏱️ MPV $vo: TIMEOUT (likely working)"
        else
            echo "   ❌ MPV $vo: FAILED (exit: $exit_code)"
        fi
    done
else
    echo "   ❌ MPV not installed"
fi

# Test 3: MPlayer with different outputs
echo ""
echo "3. Testing MPlayer with different video outputs:"

if command -v mplayer >/dev/null 2>&1; then
    mplayer_outputs=("fbdev" "fbdev2" "caca")
    for vo in "${mplayer_outputs[@]}"; do
        echo "   Testing MPlayer -vo $vo..."
        
        timeout ${TEST_DURATION}s mplayer \
            -vo "$vo" \
            -ao alsa \
            -really-quiet \
            -endpos 5 \
            "$TEST_URL" >/dev/null 2>&1
        
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "   ✅ MPlayer $vo: SUCCESS"
        elif [ $exit_code -eq 124 ]; then
            echo "   ⏱️ MPlayer $vo: TIMEOUT (likely working)"
        else
            echo "   ❌ MPlayer $vo: FAILED (exit: $exit_code)"
        fi
    done
else
    echo "   ❌ MPlayer not installed"
fi

# Test 4: Try with manual framebuffer switching
echo ""
echo "4. Testing with different console switching:"

# Try switching to a different virtual terminal
current_tty=$(tty)
echo "   Current TTY: $current_tty"

if [ "$current_tty" = "/dev/tty1" ]; then
    echo "   Trying VLC on tty1 (current)..."
    timeout ${TEST_DURATION}s vlc --intf dummy --vout fb --aout alsa --play-and-exit "$TEST_URL" >/dev/null 2>&1
    if [ $? -eq 0 ] || [ $? -eq 124 ]; then
        echo "   ✅ VLC framebuffer works on tty1"
    else
        echo "   ❌ VLC framebuffer failed on tty1"
    fi
fi

echo ""
echo "📋 Summary and Recommendations:"

# Check what's working
echo "🔍 System Status:"
echo "- Framebuffer devices: $(ls /dev/fb* 2>/dev/null | wc -l) found"
echo "- User in video group: $(groups | grep -q video && echo 'Yes' || echo 'No')"
echo "- X11 running: $(pgrep -x 'Xorg' >/dev/null && echo 'Yes' || echo 'No')"
echo "- Console processes: $(pgrep -f 'getty\|login' | wc -l) active"

echo ""
echo "💡 Recommendations:"
echo "1. If any test showed SUCCESS or TIMEOUT, that method should work"
echo "2. Try running as root if permission issues persist"
echo "3. Consider using desktop/X11 mode instead of framebuffer"
echo "4. Check GPU memory allocation: vcgencmd get_mem gpu"
echo ""
echo "🎯 Next steps:"
echo "- If VLC caca worked: Use --vout caca (text-based video)"
echo "- If MPV drm worked: MPV is better for headless systems"
echo "- If all failed: Use desktop mode with ./setup-video.sh"