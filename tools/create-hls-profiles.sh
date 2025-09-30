#!/bin/bash
# HLS Profile Generator for GrannyTV
# Creates optimized VLC profiles for different HLS scenarios

echo "🎬 Creating HLS-Optimized VLC Profiles"
echo "====================================="

# Create profiles directory
PROFILES_DIR="/home/jeremy/gtv/vlc-profiles"
mkdir -p "$PROFILES_DIR"

# Function to create profile
create_profile() {
    local profile_name="$1"
    local profile_args="$2"
    local description="$3"
    
    echo "Creating profile: $profile_name"
    echo "# $description" > "$PROFILES_DIR/$profile_name.conf"
    echo "$profile_args" >> "$PROFILES_DIR/$profile_name.conf"
}

# Ultra Low-Latency HLS Profile (for live streams)
create_profile "hls-ultra-low-latency" \
"--intf dummy
--network-caching=200
--live-caching=50  
--file-caching=50
--adaptive-logic=2
--adaptive-bw-up=0.8
--adaptive-bw-down=0.2
--hls-segment-threads=4
--network-timeout=3000
--http-timeout=5000
--clock-jitter=0
--clock-synchro=0
--no-audio-time-stretch
--avcodec-fast
--avcodec-skiploopfilter=all
--avcodec-threads=0
--drop-late-frames
--skip-frames
--no-stats
--no-sub-autodetect-file
--no-metadata-network-access
--no-video-title-show
--quiet
--disable-screensaver" \
"Ultra low-latency HLS streaming (50-200ms latency)"

# Balanced HLS Profile (reliability + performance)
create_profile "hls-balanced" \
"--intf dummy
--network-caching=500
--live-caching=150
--file-caching=150  
--adaptive-logic=1
--adaptive-bw-up=0.6
--adaptive-bw-down=0.4
--hls-segment-threads=2
--network-timeout=5000
--http-timeout=8000
--no-audio-time-stretch
--avcodec-fast
--avcodec-threads=0
--no-stats
--no-sub-autodetect-file
--no-video-title-show
--quiet
--disable-screensaver" \
"Balanced HLS streaming (reliability + performance)"

# High Quality HLS Profile (for stable connections)  
create_profile "hls-high-quality" \
"--intf dummy
--network-caching=1000
--live-caching=300
--file-caching=300
--adaptive-logic=0
--hls-segment-threads=1
--network-timeout=8000
--http-timeout=12000
--no-audio-time-stretch
--avcodec-threads=0
--no-stats
--no-video-title-show
--quiet
--disable-screensaver" \
"High quality HLS streaming (stable connections)"

# Fallback HLS Profile (for problematic streams)
create_profile "hls-fallback" \
"--intf dummy
--network-caching=2000
--live-caching=500
--file-caching=500
--network-timeout=15000
--http-timeout=20000
--no-video-title-show
--quiet
--disable-screensaver" \
"Fallback HLS profile for problematic streams"

# Create profile selector script
cat > "$PROFILES_DIR/select-hls-profile.sh" << 'EOF'
#!/bin/bash
# HLS Profile Selector - automatically selects best profile

URL="$1"
PROFILE_DIR="/home/jeremy/gtv/vlc-profiles"

# Test connection quality
test_connection() {
    local url="$1"
    local start_time=$(date +%s%3N)
    
    # Test HTTP response time
    if curl -s --max-time 3 -o /dev/null -w "%{http_code}" "$url" >/dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        echo $response_time
    else
        echo 9999
    fi
}

# Determine best profile based on connection
select_profile() {
    local url="$1"
    local response_time=$(test_connection "$url")
    
    if [ "$response_time" -lt 500 ]; then
        echo "hls-ultra-low-latency"
    elif [ "$response_time" -lt 1500 ]; then
        echo "hls-balanced"  
    elif [ "$response_time" -lt 3000 ]; then
        echo "hls-high-quality"
    else
        echo "hls-fallback"
    fi
}

# Get recommended profile
PROFILE=$(select_profile "$URL")
PROFILE_FILE="$PROFILE_DIR/$PROFILE.conf"

if [ -f "$PROFILE_FILE" ]; then
    echo "$PROFILE_FILE"
else
    echo "$PROFILE_DIR/hls-balanced.conf"
fi
EOF

chmod +x "$PROFILES_DIR/select-hls-profile.sh"

echo ""
echo "✅ HLS Profiles Created:"
echo "   📁 $PROFILES_DIR/"
echo "   🎯 hls-ultra-low-latency.conf - <200ms latency"
echo "   ⚖️  hls-balanced.conf - Reliability + performance"
echo "   🔍 hls-high-quality.conf - Maximum quality"
echo "   🛡️  hls-fallback.conf - Problematic streams"
echo ""
echo "🔧 Usage:"
echo "   # Auto-select profile"
echo "   PROFILE=\$(\"$PROFILES_DIR/select-hls-profile.sh\" \"<stream_url>\")"
echo "   vlc \$(cat \"\$PROFILE\") \"<stream_url>\""
echo ""
echo "   # Use specific profile"
echo "   vlc \$(cat \"$PROFILES_DIR/hls-ultra-low-latency.conf\") \"<stream_url>\""