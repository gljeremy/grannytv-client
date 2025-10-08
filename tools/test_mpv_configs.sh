#!/bin/bash
# MPV Configuration Testing Script for Raspberry Pi 3
# Tests different configurations and monitors stability

# Test stream (using a reliable one)
TEST_URL="http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5f8ed1ff5c39700007e2209a/master.m3u8?appName=web&appVersion=unknown&clientTime=0&deviceDNT=0&deviceId=unknown&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown"

# Test duration (seconds to let mpv run before checking)
TEST_DURATION=30

# Log file
LOG_FILE="/home/jeremy/gtv/mpv_test_results.log"

echo "=====================================" | tee -a $LOG_FILE
echo "MPV Configuration Test - $(date)" | tee -a $LOG_FILE
echo "=====================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Kill any existing mpv processes
pkill -9 mpv 2>/dev/null
sleep 2

# Function to test a configuration
test_config() {
    local config_name="$1"
    shift
    local mpv_args=("$@")
    
    echo "-----------------------------------" | tee -a $LOG_FILE
    echo "Testing: $config_name" | tee -a $LOG_FILE
    echo "Command: mpv ${mpv_args[*]:0:8}..." | tee -a $LOG_FILE
    echo "-----------------------------------" | tee -a $LOG_FILE
    
    # Start mpv
    mpv "${mpv_args[@]}" "$TEST_URL" &
    MPV_PID=$!
    
    echo "Started mpv (PID: $MPV_PID)" | tee -a $LOG_FILE
    
    # Wait and monitor
    sleep 5
    
    # Check if still running
    if ! kill -0 $MPV_PID 2>/dev/null; then
        echo "❌ FAILED - mpv crashed immediately" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        return 1
    fi
    
    echo "✓ Initial startup OK (5s)" | tee -a $LOG_FILE
    
    # Continue monitoring
    sleep $((TEST_DURATION - 5))
    
    if ! kill -0 $MPV_PID 2>/dev/null; then
        echo "❌ FAILED - mpv crashed during test" | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
        return 1
    fi
    
    echo "✅ SUCCESS - stable for ${TEST_DURATION}s" | tee -a $LOG_FILE
    
    # Check memory usage
    if ps -p $MPV_PID -o rss= >/dev/null 2>&1; then
        MEM_KB=$(ps -p $MPV_PID -o rss= | tr -d ' ')
        MEM_MB=$((MEM_KB / 1024))
        echo "   Memory usage: ${MEM_MB}MB" | tee -a $LOG_FILE
    fi
    
    # Kill it
    kill $MPV_PID 2>/dev/null
    wait $MPV_PID 2>/dev/null
    sleep 2
    
    echo "" | tee -a $LOG_FILE
    return 0
}

# Test Configuration 1: Minimal DRM with no cache
test_config "Config 1: DRM + No Cache" \
    --vo=drm \
    --drm-connector=HDMI-A-1 \
    --drm-mode=0 \
    --hwdec=no \
    --cache=no \
    --demuxer-max-bytes=1M \
    --demuxer-readahead-secs=0.5 \
    --demuxer-max-back-bytes=512K \
    --video-latency-hacks=yes \
    --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
    --framedrop=vo \
    --no-osc \
    --no-input-default-bindings \
    --really-quiet

# Test Configuration 2: DRM with tiny cache
test_config "Config 2: DRM + Tiny Cache (1s)" \
    --vo=drm \
    --drm-connector=HDMI-A-1 \
    --drm-mode=0 \
    --hwdec=no \
    --cache=yes \
    --cache-secs=1 \
    --demuxer-max-bytes=2M \
    --demuxer-readahead-secs=1 \
    --demuxer-max-back-bytes=1M \
    --video-latency-hacks=yes \
    --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
    --framedrop=vo \
    --no-osc \
    --really-quiet

# Test Configuration 3: DRM with slightly more cache
test_config "Config 3: DRM + Small Cache (3s)" \
    --vo=drm \
    --drm-connector=HDMI-A-1 \
    --drm-mode=0 \
    --hwdec=no \
    --cache=yes \
    --cache-secs=3 \
    --demuxer-max-bytes=5M \
    --demuxer-readahead-secs=2 \
    --demuxer-max-back-bytes=2M \
    --stream-lavf-o=reconnect=1,reconnect_at_eof=1,reconnect_streamed=1 \
    --framedrop=vo \
    --no-osc \
    --really-quiet

# Test Configuration 4: DRM with lower resolution preference
test_config "Config 4: DRM + Lower Quality Preference" \
    --vo=drm \
    --drm-connector=HDMI-A-1 \
    --drm-mode=0 \
    --hwdec=no \
    --cache=yes \
    --cache-secs=2 \
    --demuxer-max-bytes=3M \
    --ytdl-format="bestvideo[height<=480]+bestaudio/best[height<=480]" \
    --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
    --framedrop=vo \
    --no-osc \
    --really-quiet

# Test Configuration 5: Try hardware decoding (if available)
test_config "Config 5: DRM + Hardware Decode" \
    --vo=drm \
    --drm-connector=HDMI-A-1 \
    --drm-mode=0 \
    --hwdec=auto \
    --cache=yes \
    --cache-secs=2 \
    --demuxer-max-bytes=3M \
    --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
    --framedrop=vo \
    --no-osc \
    --really-quiet

# Test Configuration 6: Different video output (fbdev)
test_config "Config 6: FBDEV output" \
    --vo=fbdev \
    --hwdec=no \
    --cache=yes \
    --cache-secs=2 \
    --demuxer-max-bytes=3M \
    --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
    --framedrop=vo \
    --no-osc \
    --really-quiet

# Test Configuration 7: X11/GPU (if available)
test_config "Config 7: GPU output" \
    --vo=gpu \
    --hwdec=no \
    --cache=yes \
    --cache-secs=2 \
    --demuxer-max-bytes=3M \
    --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
    --framedrop=vo \
    --no-osc \
    --really-quiet \
    --fullscreen

# Test Configuration 8: Aggressive frame dropping
test_config "Config 8: DRM + Aggressive Frame Drop" \
    --vo=drm \
    --drm-connector=HDMI-A-1 \
    --drm-mode=0 \
    --hwdec=no \
    --cache=yes \
    --cache-secs=2 \
    --demuxer-max-bytes=3M \
    --framedrop=decoder+vo \
    --video-sync=display-resample \
    --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
    --no-osc \
    --really-quiet

echo "=====================================" | tee -a $LOG_FILE
echo "Test completed: $(date)" | tee -a $LOG_FILE
echo "Results saved to: $LOG_FILE" | tee -a $LOG_FILE
echo "=====================================" | tee -a $LOG_FILE
