#!/bin/bash
################################################################################
# MPV Configuration Benchmark Script
# 
# This script systematically tests different MPV configurations found in the
# git history from the past week and measures their performance.
#
# IMPORTANT: DO NOT RUN THIS WHILE COPILOT IS ACTIVE
# Copilot's memory usage will invalidate the memory measurements.
#
# Usage:
#   ./benchmark_mpv_configs.sh [stream_url] [duration_seconds]
#
# Examples:
#   ./benchmark_mpv_configs.sh                              # Interactive stream selection
#   ./benchmark_mpv_configs.sh "http://example.com/stream.m3u8" 60
#
# The script includes 4 pre-selected high-performance streams for testing:
#   1. Pluto TV Action (HLS, Pluto CDN, 51ms latency)
#   2. Paramount Movie Channel (HLS, Pluto CDN, 54ms latency)
#   3. Kino Barrandov (Non-HLS Direct stream, 248ms latency)
#   4. Action 24 (HLS, Akamai CDN, 297ms latency)
#
# Output:
#   - Results logged to mpv_benchmark_results.log
#   - Best configuration saved to mpv_best_config.txt
#   - Detailed metrics for each config
################################################################################

set -e

# Configuration
STREAM_URL="${1:-}"
TEST_DURATION="${2:-60}"  # Default 60 seconds per config
RESULTS_LOG="mpv_benchmark_results.log"
BEST_CONFIG_FILE="mpv_best_config.txt"
TEMP_LOG="/tmp/mpv_test_$$.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Predefined high-performance test streams
declare -A TEST_STREAMS
TEST_STREAMS[1]="http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5f8ed1ff5c39700007e2204a/master.m3u8?appName=web&appVersion=unknown&clientTime=0&deviceDNT=0&deviceId=8e055171-1f2c-11ef-86d8-5d587df108c6&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false&sid=c3b67254-4628-4f0e-8164-5a50e8969a42|Pluto TV Action (HLS, Pluto CDN, 51ms)|hls"
TEST_STREAMS[2]="http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5cb0cae7a461406ffe3f5213/master.m3u8?appName=web&appVersion=unknown&clientTime=0&deviceDNT=0&deviceId=6c2a7819-30d3-11ef-9cf5-e9ddff8ff496&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false&sid=8a4a0712-cb24-4d05-b429-1b98c1f73f74|Paramount Movie Channel (HLS, Pluto CDN, 54ms)|hls"
TEST_STREAMS[3]="http://83.167.253.107/hdmi1_ext|Kino Barrandov (Non-HLS, Direct, 248ms)|direct"
TEST_STREAMS[4]="http://actionlive.siliconweb.com/actionabr/actiontv/playlist.m3u8|Action 24 (HLS, Akamai CDN, 297ms)|hls"

################################################################################
# Utility Functions
################################################################################

log_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

select_stream() {
    if [ -n "$STREAM_URL" ]; then
        # Stream URL provided as argument, use it
        return
    fi
    
    log_header "Select Test Stream"
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
        log_error "Invalid selection. Please choose 1-4."
        exit 1
    fi
    
    IFS='|' read -r STREAM_URL STREAM_NAME STREAM_TYPE <<< "${TEST_STREAMS[$selection]}"
    log_info "Selected: $STREAM_NAME"
    log_info "Type: $STREAM_TYPE"
    echo ""
}

check_requirements() {
    log_header "Checking Requirements"
    
    # Check if mpv is installed
    if ! command -v mpv &> /dev/null; then
        log_error "mpv is not installed"
        exit 1
    fi
    
    # Check if running on Raspberry Pi
    if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        IS_RPI=1
        log_info "Running on Raspberry Pi"
    else
        IS_RPI=0
        log_info "Running on Desktop/Generic system"
    fi
    
    # Warn about Copilot
    log_warn "Make sure GitHub Copilot and other heavy processes are NOT running!"
    log_warn "Press Ctrl+C within 5 seconds to abort..."
    sleep 5
}

get_process_stats() {
    local pid=$1
    local stats_file=$2
    
    # Get CPU and memory stats
    if [ -f "/proc/$pid/status" ]; then
        local vmrss=$(grep VmRSS /proc/$pid/status | awk '{print $2}')
        local vmpeak=$(grep VmPeak /proc/$pid/status | awk '{print $2}')
        
        # Get CPU usage using ps
        local cpu=$(ps -p $pid -o %cpu | tail -1 | tr -d ' ')
        
        echo "Memory_RSS_KB=$vmrss" >> "$stats_file"
        echo "Memory_Peak_KB=$vmpeak" >> "$stats_file"
        echo "CPU_Percent=$cpu" >> "$stats_file"
    fi
}

monitor_mpv() {
    local mpv_pid=$1
    local duration=$2
    local stats_file=$3
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local sample_count=0
    local total_cpu=0
    local total_mem=0
    local max_mem=0
    local frame_drops=0
    
    log_info "Monitoring MPV (PID: $mpv_pid) for ${duration}s..."
    
    while [ $(date +%s) -lt $end_time ]; do
        if ! kill -0 $mpv_pid 2>/dev/null; then
            log_error "MPV process died prematurely!"
            echo "Status=CRASHED" >> "$stats_file"
            return 1
        fi
        
        # Sample every second
        if [ -f "/proc/$mpv_pid/status" ]; then
            local mem=$(grep VmRSS /proc/$mpv_pid/status | awk '{print $2}')
            local cpu=$(ps -p $mpv_pid -o %cpu | tail -1 | tr -d ' ')
            
            total_mem=$((total_mem + mem))
            total_cpu=$(echo "$total_cpu + $cpu" | bc)
            sample_count=$((sample_count + 1))
            
            if [ $mem -gt $max_mem ]; then
                max_mem=$mem
            fi
        fi
        
        sleep 1
    done
    
    # Calculate averages
    local avg_mem=$((total_mem / sample_count))
    local avg_cpu=$(echo "scale=2; $total_cpu / $sample_count" | bc)
    
    echo "Status=COMPLETED" >> "$stats_file"
    echo "Avg_Memory_KB=$avg_mem" >> "$stats_file"
    echo "Max_Memory_KB=$max_mem" >> "$stats_file"
    echo "Avg_CPU_Percent=$avg_cpu" >> "$stats_file"
    echo "Test_Duration=$duration" >> "$stats_file"
    
    log_info "Average Memory: ${avg_mem} KB ($(echo "scale=2; $avg_mem / 1024" | bc) MB)"
    log_info "Max Memory: ${max_mem} KB ($(echo "scale=2; $max_mem / 1024" | bc) MB)"
    log_info "Average CPU: ${avg_cpu}%"
    
    return 0
}

test_config() {
    local config_num=$1
    local config_name=$2
    shift 2
    local mpv_args=("$@")
    
    log_header "Testing Config $config_num: $config_name"
    
    local stats_file="${RESULTS_LOG}.config${config_num}"
    echo "Config_Number=$config_num" > "$stats_file"
    echo "Config_Name=$config_name" >> "$stats_file"
    echo "Command=mpv ${mpv_args[*]}" >> "$stats_file"
    echo "Test_Time=$(date '+%Y-%m-%d %H:%M:%S')" >> "$stats_file"
    
    # Start MPV in background
    mpv "${mpv_args[@]}" > "$TEMP_LOG" 2>&1 &
    local mpv_pid=$!
    
    # Give MPV a moment to start
    sleep 3
    
    # Check if MPV is still running
    if ! kill -0 $mpv_pid 2>/dev/null; then
        log_error "MPV failed to start"
        echo "Status=FAILED_TO_START" >> "$stats_file"
        cat "$TEMP_LOG"
        return 1
    fi
    
    # Monitor the process
    if monitor_mpv $mpv_pid $TEST_DURATION "$stats_file"; then
        log_info "Test completed successfully"
        # Kill MPV gracefully
        kill $mpv_pid 2>/dev/null || true
        sleep 2
        kill -9 $mpv_pid 2>/dev/null || true
        return 0
    else
        log_error "Test failed"
        kill -9 $mpv_pid 2>/dev/null || true
        return 1
    fi
}

################################################################################
# MPV Configurations from Git History (Past Week)
################################################################################

run_all_tests() {
    log_header "Starting MPV Configuration Benchmark"
    log_info "Stream URL: $STREAM_URL"
    if [ -n "$STREAM_NAME" ]; then
        log_info "Stream: $STREAM_NAME"
    fi
    log_info "Test duration per config: ${TEST_DURATION}s"
    
    # Initialize results log
    echo "MPV Configuration Benchmark Results" > "$RESULTS_LOG"
    echo "Date: $(date)" >> "$RESULTS_LOG"
    echo "Stream: $STREAM_URL" >> "$RESULTS_LOG"
    if [ -n "$STREAM_NAME" ]; then
        echo "Stream Name: $STREAM_NAME" >> "$RESULTS_LOG"
    fi
    echo "Test Duration: ${TEST_DURATION}s" >> "$RESULTS_LOG"
    echo "========================================" >> "$RESULTS_LOG"
    echo "" >> "$RESULTS_LOG"
    
    if [ $IS_RPI -eq 1 ]; then
        # Raspberry Pi configurations
        
        # Config 1: EXTREME MINIMAL (Current - No Cache)
        test_config 1 "DRM_NO_CACHE" \
            --vo=drm \
            --drm-connector=HDMI-A-1 \
            --drm-mode=0 \
            --hwdec=no \
            --cache=no \
            --demuxer-max-bytes=2M \
            --demuxer-readahead-secs=0.5 \
            --demuxer-max-back-bytes=1M \
            --video-latency-hacks=yes \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
            --framedrop=vo \
            --no-osc \
            --no-input-default-bindings \
            --really-quiet \
            --loop-playlist=inf \
            --user-agent="Mozilla/5.0 (Smart-IPTV-Player)" \
            "$STREAM_URL"
        
        # Config 2: ULTRA MINIMAL (Current - 1s cache)
        test_config 2 "DRM_ULTRA_MINIMAL" \
            --vo=drm \
            --drm-connector=HDMI-A-1 \
            --drm-mode=0 \
            --hwdec=no \
            --cache=yes \
            --cache-secs=1 \
            --demuxer-max-bytes=3M \
            --demuxer-readahead-secs=1 \
            --demuxer-max-back-bytes=2M \
            --video-latency-hacks=yes \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,reconnect_delay_max=5 \
            --framedrop=vo \
            --no-osc \
            --no-input-default-bindings \
            --really-quiet \
            --loop-playlist=inf \
            --user-agent="Mozilla/5.0 (Smart-IPTV-Player)" \
            "$STREAM_URL"
        
        # Config 3: GPU MINIMAL (Current fallback)
        test_config 3 "GPU_MINIMAL" \
            --vo=gpu \
            --hwdec=no \
            --cache=yes \
            --cache-secs=1 \
            --demuxer-max-bytes=3M \
            --demuxer-max-back-bytes=2M \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
            --framedrop=vo \
            --no-osc \
            --really-quiet \
            --fullscreen \
            --loop-playlist=inf \
            "$STREAM_URL"
        
        # Config 4: DRM MINIMAL (OOM Fix - 2s cache, 10M buffer)
        test_config 4 "DRM_MINIMAL_OOM_FIX" \
            --vo=drm \
            --drm-connector=HDMI-A-1 \
            --drm-mode=0 \
            --hwdec=no \
            --cache=yes \
            --cache-secs=2 \
            --demuxer-max-bytes=10M \
            --demuxer-readahead-secs=2 \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,reconnect_delay_max=5 \
            --framedrop=vo \
            --no-osc \
            --no-input-default-bindings \
            --really-quiet \
            --loop-playlist=inf \
            --user-agent="Mozilla/5.0 (Smart-IPTV-Player)" \
            "$STREAM_URL"
        
        # Config 5: DRM ULTRA MINIMAL (OOM Fix fallback - 1s cache, 5M buffer)
        test_config 5 "DRM_ULTRA_MINIMAL_OOM_FIX" \
            --vo=drm \
            --drm-connector=HDMI-A-1 \
            --hwdec=no \
            --cache=yes \
            --cache-secs=1 \
            --demuxer-max-bytes=5M \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
            --framedrop=vo \
            --no-osc \
            --really-quiet \
            --loop-playlist=inf \
            "$STREAM_URL"
        
        # Config 6: GPU PERFORMANCE (Pre-OOM - 10s cache, 50M buffer)
        test_config 6 "GPU_PERFORMANCE_HLS" \
            --hwdec=no \
            --vo=gpu \
            --cache=yes \
            --cache-secs=10 \
            --demuxer-max-bytes=50M \
            --demuxer-readahead-secs=10 \
            --hls-bitrate=max \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,reconnect_delay_max=5 \
            --framedrop=vo \
            --no-osc \
            --no-input-default-bindings \
            --really-quiet \
            --fullscreen \
            --loop-playlist=inf \
            --user-agent="Mozilla/5.0 (Smart-IPTV-Player)" \
            "$STREAM_URL"
        
        # Config 7: GPU LIGHTER (Pre-OOM - 5s cache, 30M buffer)
        test_config 7 "GPU_LIGHTER_HLS" \
            --hwdec=no \
            --vo=gpu \
            --cache=yes \
            --cache-secs=5 \
            --demuxer-max-bytes=30M \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1 \
            --no-osc \
            --really-quiet \
            --fullscreen \
            --loop-playlist=inf \
            "$STREAM_URL"
        
        # Config 8: ORIGINAL MPV (Initial switch - 2s cache, 20M buffer)
        test_config 8 "GPU_ORIGINAL" \
            --hwdec=no \
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
            --loop-playlist=inf \
            --user-agent="Mozilla/5.0 (Smart-IPTV-Player)" \
            "$STREAM_URL"
        
        # Config 9: ORIGINAL LIGHTER (Initial switch fallback - 1s cache)
        test_config 9 "GPU_ORIGINAL_LIGHT" \
            --hwdec=no \
            --vo=gpu \
            --cache=yes \
            --cache-secs=1 \
            --no-osc \
            --really-quiet \
            --fullscreen \
            --loop-playlist=inf \
            "$STREAM_URL"
        
    else
        # Desktop configurations
        
        # Config 1: Desktop standard
        test_config 1 "DESKTOP_STANDARD" \
            --hwdec=auto \
            --vo=gpu \
            --cache=yes \
            --cache-secs=10 \
            --demuxer-max-bytes=50M \
            --stream-lavf-o=reconnect=1,reconnect_at_eof=1,reconnect_streamed=1 \
            --no-osc \
            --fullscreen \
            "$STREAM_URL"
        
        # Config 2: Desktop minimal
        test_config 2 "DESKTOP_MINIMAL" \
            --hwdec=auto \
            --vo=gpu \
            --cache=yes \
            --cache-secs=3 \
            --no-osc \
            --fullscreen \
            "$STREAM_URL"
    fi
}

analyze_results() {
    log_header "Analyzing Results"
    
    # Collect all successful configs
    local best_score=999999
    local best_config=""
    local best_config_num=""
    
    for config_file in ${RESULTS_LOG}.config*; do
        if [ ! -f "$config_file" ]; then
            continue
        fi
        
        local status=$(grep "^Status=" "$config_file" | cut -d= -f2)
        
        if [ "$status" != "COMPLETED" ]; then
            log_warn "Config $(basename $config_file) did not complete successfully"
            continue
        fi
        
        local config_num=$(grep "^Config_Number=" "$config_file" | cut -d= -f2)
        local config_name=$(grep "^Config_Name=" "$config_file" | cut -d= -f2)
        local avg_mem=$(grep "^Avg_Memory_KB=" "$config_file" | cut -d= -f2)
        local max_mem=$(grep "^Max_Memory_KB=" "$config_file" | cut -d= -f2)
        local avg_cpu=$(grep "^Avg_CPU_Percent=" "$config_file" | cut -d= -f2)
        
        # Calculate performance score (lower is better)
        # Score = (avg_mem_MB * 10) + (avg_cpu * 5)
        # This weights memory more heavily than CPU
        local avg_mem_mb=$(echo "scale=2; $avg_mem / 1024" | bc)
        local score=$(echo "scale=2; ($avg_mem_mb * 10) + ($avg_cpu * 5)" | bc)
        
        log_info "Config $config_num ($config_name): Score=$score (Mem=${avg_mem_mb}MB, CPU=${avg_cpu}%)"
        
        # Track best config
        if [ $(echo "$score < $best_score" | bc) -eq 1 ]; then
            best_score=$score
            best_config=$config_name
            best_config_num=$config_num
        fi
        
        # Append to summary
        {
            echo "Config $config_num: $config_name"
            echo "  Avg Memory: $avg_mem_mb MB"
            echo "  Max Memory: $(echo "scale=2; $max_mem / 1024" | bc) MB"
            echo "  Avg CPU: $avg_cpu%"
            echo "  Score: $score"
            echo ""
        } >> "$RESULTS_LOG"
    done
    
    if [ -n "$best_config" ]; then
        log_header "Best Configuration"
        log_info "Config #$best_config_num: $best_config (Score: $best_score)"
        
        # Save best config
        echo "Best MPV Configuration" > "$BEST_CONFIG_FILE"
        echo "Config: $best_config" >> "$BEST_CONFIG_FILE"
        echo "Score: $best_score" >> "$BEST_CONFIG_FILE"
        echo "" >> "$BEST_CONFIG_FILE"
        cat "${RESULTS_LOG}.config${best_config_num}" >> "$BEST_CONFIG_FILE"
        
        log_info "Best configuration saved to: $BEST_CONFIG_FILE"
    else
        log_error "No configurations completed successfully!"
    fi
    
    log_info "Full results saved to: $RESULTS_LOG"
}

cleanup() {
    rm -f "$TEMP_LOG"
    # Kill any remaining MPV processes from this script
    pkill -P $$ mpv 2>/dev/null || true
}

################################################################################
# Main Execution
################################################################################

trap cleanup EXIT

select_stream
check_requirements
run_all_tests
analyze_results

log_header "Benchmark Complete"
log_info "Review results in: $RESULTS_LOG"
log_info "Best configuration in: $BEST_CONFIG_FILE"

exit 0
