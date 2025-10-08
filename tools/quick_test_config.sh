#!/bin/bash
################################################################################
# Quick Test - Config 15 Optimization Variants
# 
# This script contains variations of Config 15 (MPV Initial Config) for
# fine-tuning and optimization testing. Config 15 is the best performing
# configuration, and these variants test small adjustments to find the
# optimal settings.
#
# Base Config 15:
#   --vo=gpu --cache-secs=2 --demuxer-max-bytes=20M --demuxer-readahead-secs=2
# 
# Usage:
#   ./quick_test_config.sh [variant_number] [stream_url] [duration_seconds]
#
# Examples:
#   ./quick_test_config.sh                  # Interactive mode (default: variant 1)
#   ./quick_test_config.sh 1                # Variant 1 with stream selection
#   ./quick_test_config.sh 5 "http://..." 60  # Full manual mode
#
# Variant Categories:
#   1:     Original Config 15 (baseline)
#   2-5:   Cache duration variations (1s, 3s, 4s, 5s)
#   6-9:   Demuxer buffer size variations (10M, 15M, 25M, 30M)
#   10-13: Readahead variations (1s, 1.5s, 3s, 4s)
#   14-17: Combined optimizations
#   18-20: Alternative video output methods
################################################################################

# Predefined high-performance test streams
declare -A TEST_STREAMS
TEST_STREAMS[1]="http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5f8ed1ff5c39700007e2204a/master.m3u8?appName=web&appVersion=unknown&clientTime=0&deviceDNT=0&deviceId=8e055171-1f2c-11ef-86d8-5d587df108c6&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false&sid=c3b67254-4628-4f0e-8164-5a50e8969a42|Pluto TV Action (HLS, Pluto CDN, 51ms)|hls"
TEST_STREAMS[2]="http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5cb0cae7a461406ffe3f5213/master.m3u8?appName=web&appVersion=unknown&clientTime=0&deviceDNT=0&deviceId=6c2a7819-30d3-11ef-9cf5-e9ddff8ff496&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false&sid=8a4a0712-cb24-4d05-b429-1b98c1f73f74|Paramount Movie Channel (HLS, Pluto CDN, 54ms)|hls"
TEST_STREAMS[3]="http://83.167.253.107/hdmi1_ext|Kino Barrandov (Non-HLS, Direct, 248ms)|direct"
TEST_STREAMS[4]="http://actionlive.siliconweb.com/actionabr/actiontv/playlist.m3u8|Action 24 (HLS, Akamai CDN, 297ms)|hls"

CONFIG_NUM="${1:-}"
STREAM_URL="${2:-}"
DURATION="${3:-30}"

select_config() {
    if [ -n "$CONFIG_NUM" ]; then
        return
    fi
    
    echo "========================================="
    echo "Config 15 Optimization Variants"
    echo "========================================="
    echo ""
    echo "Select variant to test (all based on Config 15):"
    echo ""
    echo "BASELINE:"
    echo "  1  - Original Config 15 (2s cache, 20M buffer, 2s readahead) ✓ BASELINE"
    echo ""
    echo "CACHE DURATION VARIANTS:"
    echo "  2  - Shorter cache (1s cache, keep 20M buffer)"
    echo "  3  - Longer cache (3s cache, keep 20M buffer)"
    echo "  4  - Extended cache (4s cache, keep 20M buffer)"
    echo "  5  - Max cache (5s cache, keep 20M buffer)"
    echo ""
    echo "DEMUXER BUFFER VARIANTS:"
    echo "  6  - Smaller buffer (2s cache, 10M buffer)"
    echo "  7  - Medium buffer (2s cache, 15M buffer)"
    echo "  8  - Larger buffer (2s cache, 25M buffer)"
    echo "  9  - Max buffer (2s cache, 30M buffer)"
    echo ""
    echo "READAHEAD VARIANTS:"
    echo "  10 - Shorter readahead (2s cache, 20M buffer, 1s readahead)"
    echo "  11 - Medium readahead (2s cache, 20M buffer, 1.5s readahead)"
    echo "  12 - Longer readahead (2s cache, 20M buffer, 3s readahead)"
    echo "  13 - Max readahead (2s cache, 20M buffer, 4s readahead)"
    echo ""
    echo "COMBINED OPTIMIZATIONS:"
    echo "  14 - Balanced (3s cache, 25M buffer, 3s readahead)"
    echo "  15 - Performance (4s cache, 30M buffer, 3s readahead)"
    echo "  16 - Conservative (1.5s cache, 15M buffer, 1.5s readahead)"
    echo "  17 - Minimal (1s cache, 10M buffer, 1s readahead)"
    echo ""
    echo "ALTERNATIVE OUTPUT METHODS:"
    echo "  18 - DRM output (drm instead of gpu)"
    echo "  19 - Hardware decode (hwdec=auto)"
    echo "  20 - X11 output (vo=x11)"
    echo ""
    read -p "Enter variant number (1-20) [default: 1]: " CONFIG_NUM
    CONFIG_NUM="${CONFIG_NUM:-1}"
    
    if [[ ! "$CONFIG_NUM" =~ ^[1-9]$|^1[0-9]$|^20$ ]]; then
        echo "Error: Invalid variant number. Please choose 1-20."
        exit 1
    fi
    echo ""
}

select_stream() {
    if [ -n "$STREAM_URL" ]; then
        return
    fi
    
    echo "========================================="
    echo "Select Test Stream"
    echo "========================================="
    echo ""
    echo "Choose a test stream from high-performance validated streams:"
    echo ""
    
    for i in {1..4}; do
        IFS='|' read -r url name type <<< "${TEST_STREAMS[$i]}"
        echo "  $i) $name"
    done
    
    echo ""
    read -p "Enter selection (1-4): " selection
    
    if [[ ! "$selection" =~ ^[1-4]$ ]]; then
        echo "Error: Invalid selection. Please choose 1-4."
        exit 1
    fi
    
    IFS='|' read -r STREAM_URL STREAM_NAME STREAM_TYPE <<< "${TEST_STREAMS[$selection]}"
    echo "Selected: $STREAM_NAME"
    echo ""
}

select_config
select_stream

echo "========================================="
echo "Testing Variant $CONFIG_NUM for ${DURATION}s"
echo "========================================="
echo "Stream: $STREAM_URL"
if [ -n "$STREAM_NAME" ]; then
    echo "Stream Name: $STREAM_NAME"
fi
echo ""

# Base MPV options for all Config 15 variants
BASE_OPTS="--hwdec=no \
--vo=gpu \
--cache=yes \
--framedrop=vo \
--no-osc \
--no-input-default-bindings \
--really-quiet \
--fullscreen \
--user-agent=Mozilla/5.0 (Smart-IPTV-Player)"

# Build command based on variant number
case $CONFIG_NUM in
    1)
        echo "Variant 1: Original Config 15 (BASELINE)"
        echo "  cache-secs=2, demuxer-max-bytes=20M, readahead=2s"
        mpv $BASE_OPTS \
            --cache-secs=2 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=2 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    2)
        echo "Variant 2: Shorter cache (1s)"
        echo "  cache-secs=1, demuxer-max-bytes=20M, readahead=2s"
        mpv $BASE_OPTS \
            --cache-secs=1 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=2 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    3)
        echo "Variant 3: Longer cache (3s)"
        echo "  cache-secs=3, demuxer-max-bytes=20M, readahead=2s"
        mpv $BASE_OPTS \
            --cache-secs=3 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=2 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    4)
        echo "Variant 4: Extended cache (4s)"
        echo "  cache-secs=4, demuxer-max-bytes=20M, readahead=2s"
        mpv $BASE_OPTS \
            --cache-secs=4 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=2 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    5)
        echo "Variant 5: Max cache (5s)"
        echo "  cache-secs=5, demuxer-max-bytes=20M, readahead=2s"
        mpv $BASE_OPTS \
            --cache-secs=5 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=2 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    6)
        echo "Variant 6: Smaller buffer (10M)"
        echo "  cache-secs=2, demuxer-max-bytes=10M, readahead=2s"
        mpv $BASE_OPTS \
            --cache-secs=2 \
            --demuxer-max-bytes=10M \
            --demuxer-readahead-secs=2 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    7)
        echo "Variant 7: Medium buffer (15M)"
        echo "  cache-secs=2, demuxer-max-bytes=15M, readahead=2s"
        mpv $BASE_OPTS \
            --cache-secs=2 \
            --demuxer-max-bytes=15M \
            --demuxer-readahead-secs=2 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    8)
        echo "Variant 8: Larger buffer (25M)"
        echo "  cache-secs=2, demuxer-max-bytes=25M, readahead=2s"
        mpv $BASE_OPTS \
            --cache-secs=2 \
            --demuxer-max-bytes=25M \
            --demuxer-readahead-secs=2 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    9)
        echo "Variant 9: Max buffer (30M)"
        echo "  cache-secs=2, demuxer-max-bytes=30M, readahead=2s"
        mpv $BASE_OPTS \
            --cache-secs=2 \
            --demuxer-max-bytes=30M \
            --demuxer-readahead-secs=2 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    10)
        echo "Variant 10: Shorter readahead (1s)"
        echo "  cache-secs=2, demuxer-max-bytes=20M, readahead=1s"
        mpv $BASE_OPTS \
            --cache-secs=2 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=1 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    11)
        echo "Variant 11: Medium readahead (1.5s)"
        echo "  cache-secs=2, demuxer-max-bytes=20M, readahead=1.5s"
        mpv $BASE_OPTS \
            --cache-secs=2 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=1.5 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    12)
        echo "Variant 12: Longer readahead (3s)"
        echo "  cache-secs=2, demuxer-max-bytes=20M, readahead=3s"
        mpv $BASE_OPTS \
            --cache-secs=2 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=3 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    13)
        echo "Variant 13: Max readahead (4s)"
        echo "  cache-secs=2, demuxer-max-bytes=20M, readahead=4s"
        mpv $BASE_OPTS \
            --cache-secs=2 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=4 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    14)
        echo "Variant 14: Balanced optimization"
        echo "  cache-secs=3, demuxer-max-bytes=25M, readahead=3s"
        mpv $BASE_OPTS \
            --cache-secs=3 \
            --demuxer-max-bytes=25M \
            --demuxer-readahead-secs=3 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    15)
        echo "Variant 15: Performance optimization"
        echo "  cache-secs=4, demuxer-max-bytes=30M, readahead=3s"
        mpv $BASE_OPTS \
            --cache-secs=4 \
            --demuxer-max-bytes=30M \
            --demuxer-readahead-secs=3 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    16)
        echo "Variant 16: Conservative optimization"
        echo "  cache-secs=1.5, demuxer-max-bytes=15M, readahead=1.5s"
        mpv $BASE_OPTS \
            --cache-secs=1.5 \
            --demuxer-max-bytes=15M \
            --demuxer-readahead-secs=1.5 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    17)
        echo "Variant 17: Minimal optimization"
        echo "  cache-secs=1, demuxer-max-bytes=10M, readahead=1s"
        mpv $BASE_OPTS \
            --cache-secs=1 \
            --demuxer-max-bytes=10M \
            --demuxer-readahead-secs=1 \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    18)
        echo "Variant 18: DRM output (instead of GPU)"
        echo "  vo=drm, cache-secs=2, demuxer-max-bytes=20M, readahead=2s"
        mpv --hwdec=no \
            --vo=drm \
            --drm-connector=HDMI-A-1 \
            --drm-mode=0 \
            --cache=yes \
            --cache-secs=2 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=2 \
            --framedrop=vo \
            --no-osc \
            --no-input-default-bindings \
            --really-quiet \
            --user-agent="Mozilla/5.0 (Smart-IPTV-Player)" \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    19)
        echo "Variant 19: Hardware decode enabled"
        echo "  hwdec=auto, cache-secs=2, demuxer-max-bytes=20M, readahead=2s"
        mpv --hwdec=auto \
            --vo=gpu \
            --cache=yes \
            --cache-secs=2 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=2 \
            --framedrop=vo \
            --no-osc \
            --no-input-default-bindings \
            --really-quiet \
            --fullscreen \
            --user-agent="Mozilla/5.0 (Smart-IPTV-Player)" \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    20)
        echo "Variant 20: X11 output"
        echo "  vo=x11, cache-secs=2, demuxer-max-bytes=20M, readahead=2s"
        mpv --hwdec=no \
            --vo=x11 \
            --cache=yes \
            --cache-secs=2 \
            --demuxer-max-bytes=20M \
            --demuxer-readahead-secs=2 \
            --framedrop=vo \
            --no-osc \
            --no-input-default-bindings \
            --really-quiet \
            --fullscreen \
            --user-agent="Mozilla/5.0 (Smart-IPTV-Player)" \
            --length="$DURATION" \
            "$STREAM_URL"
        ;;
    *)
        echo "Invalid variant number: $CONFIG_NUM"
        echo "Use 1-20"
        exit 1
        ;;
esac

EXIT_CODE=$?
echo ""
echo "Test completed with exit code: $EXIT_CODE"

if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Variant $CONFIG_NUM worked successfully!"
else
    echo "✗ Variant $CONFIG_NUM failed (exit code $EXIT_CODE)"
    echo "Try a different variant or check logs"
fi

exit $EXIT_CODE
