#!/bin/bash
# VLC Option Validator
# Tests which VLC options are supported in the current installation

echo "🔍 VLC Option Validator"
echo "======================="

# Check if VLC is installed
if ! command -v vlc >/dev/null 2>&1; then
    echo "❌ VLC not found! Please install VLC first."
    exit 1
fi

# Get VLC version
VLC_VERSION=$(vlc --version 2>/dev/null | head -n1)
echo "📺 $VLC_VERSION"
echo ""

# Test problematic options that were causing errors
echo "🧪 Testing VLC options..."

# Function to test a VLC option
test_vlc_option() {
    local option="$1"
    local description="$2"
    
    # Create a minimal test command
    timeout 5 vlc --intf dummy --play-and-exit "$option" vlc://quit >/dev/null 2>&1
    
    if [ $? -eq 0 ] || [ $? -eq 124 ]; then  # 124 is timeout exit code
        echo "✅ $option - $description"
        return 0
    else
        echo "❌ $option - $description (NOT SUPPORTED)"
        return 1
    fi
}

# Test hardware decode options
echo ""
echo "🎮 Hardware Decode Options:"
test_vlc_option "--avcodec-hw=any" "Hardware acceleration (any)"
test_vlc_option "--avcodec-hw=mmal" "Hardware acceleration (MMAL/Pi)"
test_vlc_option "--avcodec-hw=none" "Disable hardware acceleration"
test_vlc_option "--no-hw-decode" "Legacy disable hardware decode"

# Test audio options
echo ""
echo "🔊 Audio Options:"
test_vlc_option "--no-audio-time-stretch" "Disable audio time stretch"
test_vlc_option "--audio-time-stretch" "Enable audio time stretch"

# Test video output options
echo ""
echo "📺 Video Output Options:"
test_vlc_option "--vout=gl" "OpenGL video output"
test_vlc_option "--vout=x11" "X11 video output"
test_vlc_option "--vout=fb" "Framebuffer video output"
test_vlc_option "--video-on-top" "Keep video on top"

# Test Pi-specific options
echo ""
echo "🍓 Raspberry Pi Specific:"
test_vlc_option "--mmal-display=hdmi-1" "MMAL HDMI display"
test_vlc_option "--intf-change-vout" "Interface change video out"

# Test performance options
echo ""
echo "⚡ Performance Options:"
test_vlc_option "--avcodec-fast" "Fast decoding"
test_vlc_option "--avcodec-skiploopfilter=all" "Skip loop filter"
test_vlc_option "--avcodec-threads=0" "Auto CPU threads"
test_vlc_option "--drop-late-frames" "Drop late frames"
test_vlc_option "--skip-frames" "Skip frames"

# Test caching options
echo ""
echo "💾 Caching Options:"
test_vlc_option "--network-caching=500" "Network caching 500ms"
test_vlc_option "--live-caching=100" "Live caching 100ms"
test_vlc_option "--file-caching=100" "File caching 100ms"
test_vlc_option "--sout-mux-caching=50" "Stream output caching"
test_vlc_option "--prefetch-buffer-size=1024" "Prefetch buffer size"

# Test misc options
echo ""
echo "🔧 Miscellaneous Options:"
test_vlc_option "--no-metadata-network-access" "No network metadata"
test_vlc_option "--no-stats" "Disable statistics"
test_vlc_option "--no-sub-autodetect-file" "No subtitle autodetect"

echo ""
echo "✅ VLC option validation complete!"
echo ""
echo "💡 Recommendations:"
echo "• Remove any options marked as 'NOT SUPPORTED'"
echo "• Use --avcodec-hw=none instead of --no-hw-decode"
echo "• Avoid Pi-specific options if they're not supported"