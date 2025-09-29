#!/bin/bash
# Advanced framebuffer diagnostics and testing

echo "🔍 Advanced Framebuffer Diagnostics"
echo "===================================="

# Check framebuffer devices
echo "📺 Framebuffer Devices:"
if ls /dev/fb* >/dev/null 2>&1; then
    for fb in /dev/fb*; do
        if [ -r "$fb" ]; then
            echo "✅ $fb (readable)"
            # Get framebuffer info if fbset is available
            if command -v fbset >/dev/null 2>&1; then
                echo "   Info: $(fbset -fb $fb | grep geometry | head -1)"
            fi
        else
            echo "❌ $fb (not readable)"
        fi
    done
else
    echo "❌ No framebuffer devices found"
fi

echo ""
echo "👤 User Permissions:"
echo "- Current user: $(whoami)"
echo "- User groups: $(groups)"
echo "- Video group members: $(getent group video | cut -d: -f4)"

# Check if user is in video group
if groups | grep -q video; then
    echo "✅ User is in video group"
else
    echo "❌ User NOT in video group"
    echo "💡 Add with: sudo usermod -a -G video $(whoami)"
fi

echo ""
echo "🎬 VLC Framebuffer Support:"

# Test VLC modules
echo "- Available VLC video output modules:"
if command -v vlc >/dev/null 2>&1; then
    vlc --list 2>/dev/null | grep -A 20 "Video output" | grep -E "(fb|framebuffer)" || echo "  No framebuffer module found"
else
    echo "❌ VLC not installed"
fi

echo ""
echo "🧪 Basic Framebuffer Tests:"

# Test 1: Can we write to framebuffer?
echo "1. Testing framebuffer write access..."
if [ -w /dev/fb0 ]; then
    echo "✅ Can write to /dev/fb0"
    
    # Try to clear the screen (safe test)
    if timeout 2s dd if=/dev/zero of=/dev/fb0 bs=1024 count=1 >/dev/null 2>&1; then
        echo "✅ Successfully wrote to framebuffer"
    else
        echo "❌ Failed to write to framebuffer"
    fi
else
    echo "❌ Cannot write to /dev/fb0"
fi

# Test 2: Try different VLC video outputs
echo ""
echo "2. Testing VLC video output methods..."

TEST_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

# Test different video outputs
video_outputs=("fb" "caca" "dummy")

for vout in "${video_outputs[@]}"; do
    echo "   Testing $vout output..."
    
    timeout 5s vlc \
        --intf dummy \
        --vout "$vout" \
        --aout dummy \
        --no-audio \
        --run-time 3 \
        --play-and-exit \
        "$TEST_URL" >/dev/null 2>&1
    
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "   ✅ $vout works"
    elif [ $exit_code -eq 124 ]; then
        echo "   ⏱️ $vout timeout (may work)"
    else
        echo "   ❌ $vout failed (exit: $exit_code)"
    fi
done

echo ""
echo "3. Testing alternative players..."

# Test mplayer framebuffer
if command -v mplayer >/dev/null 2>&1; then
    echo "   Testing mplayer with framebuffer..."
    timeout 5s mplayer -vo fbdev -ao alsa -endpos 3 "$TEST_URL" >/dev/null 2>&1
    if [ $? -eq 0 ] || [ $? -eq 124 ]; then
        echo "   ✅ mplayer framebuffer works"
    else
        echo "   ❌ mplayer framebuffer failed"
    fi
else
    echo "   ❌ mplayer not available"
fi

# Test mpv
if command -v mpv >/dev/null 2>&1; then
    echo "   Testing mpv with DRM output..."
    timeout 5s mpv --vo=drm --ao=alsa --length=3 "$TEST_URL" >/dev/null 2>&1
    if [ $? -eq 0 ] || [ $? -eq 124 ]; then
        echo "   ✅ mpv DRM output works"
    else
        echo "   ❌ mpv DRM output failed"
    fi
else
    echo "   ❌ mpv not available"
fi

echo ""
echo "🔧 System Configuration:"
echo "- Kernel version: $(uname -r)"
echo "- GPU memory: $(vcgencmd get_mem gpu 2>/dev/null || echo 'unknown')"
echo "- Boot config framebuffer settings:"

if [ -f /boot/config.txt ]; then
    grep -E "(framebuffer|gpu_mem|hdmi)" /boot/config.txt | grep -v "^#" || echo "  No framebuffer settings found"
else
    echo "  /boot/config.txt not found"
fi

echo ""
echo "📋 Recommendations:"

# Check if console framebuffer is being used
if pgrep -f "console" >/dev/null; then
    echo "⚠️  Console may be using framebuffer - try switching to different tty"
    echo "   sudo chvt 2  # Switch to tty2"
fi

# Check for conflicting processes
if pgrep -f "X\|wayland\|plymouth" >/dev/null; then
    echo "⚠️  GUI processes detected - may conflict with framebuffer"
    echo "   Try stopping GUI: sudo systemctl stop lightdm"
fi

echo "💡 Manual test commands to try:"
echo "1. Simple color test: sudo cat /dev/urandom > /dev/fb0"
echo "2. VLC with caca: vlc --vout caca [url]"
echo "3. mplayer: mplayer -vo fbdev [url]"
echo "4. mpv: mpv --vo=drm [url]"
echo ""
echo "🎯 If all fails, consider using X11/desktop mode instead of framebuffer"