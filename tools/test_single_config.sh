#!/bin/bash
# Lightweight MPV Configuration Tester for Raspberry Pi 3
# Tests configurations one at a time with careful resource management

TEST_URL="http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5f8ed1ff5c39700007e2209a/master.m3u8?appName=web&appVersion=unknown&clientTime=0&deviceDNT=0&deviceId=unknown&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown"

LOG_FILE="/home/jeremy/gtv/mpv_test_results.log"

# Which config to test (pass as argument, default 1)
CONFIG_NUM=${1:-1}
TEST_DURATION=${2:-20}

echo "Testing Config $CONFIG_NUM for ${TEST_DURATION}s at $(date)" | tee -a $LOG_FILE

# Kill any existing mpv
pkill -9 mpv 2>/dev/null
sleep 2

# Free up memory
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1

case $CONFIG_NUM in
    1)
        echo "Config 1: DRM + No Cache (Ultra Minimal)" | tee -a $LOG_FILE
        timeout $TEST_DURATION mpv \
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
            --really-quiet \
            "$TEST_URL" &
        ;;
    2)
        echo "Config 2: DRM + Tiny Cache (1s)" | tee -a $LOG_FILE
        timeout $TEST_DURATION mpv \
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
            --really-quiet \
            "$TEST_URL" &
        ;;
    3)
        echo "Config 3: DRM + Small Cache (3s)" | tee -a $LOG_FILE
        timeout $TEST_DURATION mpv \
            --vo=drm \
            --drm-connector=HDMI-A-1 \
            --drm-mode=0 \
            --hwdec=no \
            --cache=yes \
            --cache-secs=3 \
            --demuxer-max-bytes=5M \
            --demuxer-readahead-secs=2 \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
            --framedrop=vo \
            --no-osc \
            --really-quiet \
            "$TEST_URL" &
        ;;
    4)
        echo "Config 4: DRM + HW Decode" | tee -a $LOG_FILE
        timeout $TEST_DURATION mpv \
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
            --really-quiet \
            "$TEST_URL" &
        ;;
    5)
        echo "Config 5: GPU Output" | tee -a $LOG_FILE
        timeout $TEST_DURATION mpv \
            --vo=gpu \
            --hwdec=no \
            --cache=yes \
            --cache-secs=2 \
            --demuxer-max-bytes=3M \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
            --framedrop=vo \
            --no-osc \
            --really-quiet \
            --fullscreen \
            "$TEST_URL" &
        ;;
    6)
        echo "Config 6: DRM + Aggressive Frame Drop" | tee -a $LOG_FILE
        timeout $TEST_DURATION mpv \
            --vo=drm \
            --drm-connector=HDMI-A-1 \
            --drm-mode=0 \
            --hwdec=no \
            --cache=yes \
            --cache-secs=2 \
            --demuxer-max-bytes=2M \
            --framedrop=decoder+vo \
            --video-sync=display-resample \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
            --no-osc \
            --really-quiet \
            "$TEST_URL" &
        ;;
    *)
        echo "Invalid config number" | tee -a $LOG_FILE
        exit 1
        ;;
esac

MPV_PID=$!
echo "Started mpv PID: $MPV_PID" | tee -a $LOG_FILE

# Monitor it
for i in {1..4}; do
    sleep 5
    if ! kill -0 $MPV_PID 2>/dev/null; then
        RESULT=$?
        echo "❌ FAILED - crashed at ${i}x5s (exit code: $RESULT)" | tee -a $LOG_FILE
        exit 1
    fi
    
    # Check memory
    if ps -p $MPV_PID -o rss= >/dev/null 2>&1; then
        MEM_KB=$(ps -p $MPV_PID -o rss= | tr -d ' ')
        MEM_MB=$((MEM_KB / 1024))
        echo "  ${i}x5s: Still running, using ${MEM_MB}MB" | tee -a $LOG_FILE
    fi
done

# Wait for completion
wait $MPV_PID
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
    echo "✅ SUCCESS - ran for full ${TEST_DURATION}s" | tee -a $LOG_FILE
elif [ $EXIT_CODE -eq 0 ]; then
    echo "✅ SUCCESS - completed normally" | tee -a $LOG_FILE
else
    echo "❌ FAILED - exit code: $EXIT_CODE" | tee -a $LOG_FILE
fi

# Cleanup
pkill -9 mpv 2>/dev/null

echo "---" | tee -a $LOG_FILE
