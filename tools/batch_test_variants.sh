#!/bin/bash
################################################################################
# Batch Test Config 15 Variants
#
# This script runs multiple Config 15 variants and logs the results
# to help you find the optimal configuration quickly.
#
# Usage:
#   ./batch_test_variants.sh [duration] [variants...]
#
# Examples:
#   ./batch_test_variants.sh 30 1 2 3 4 5    # Test variants 1-5 for 30s each
#   ./batch_test_variants.sh 60 14 15 16 17  # Test combined variants for 60s each
#   ./batch_test_variants.sh 45              # Test all variants for 45s each
################################################################################

DURATION="${1:-30}"
shift

# If no variants specified, test all
if [ $# -eq 0 ]; then
    VARIANTS=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)
else
    VARIANTS=("$@")
fi

# Create results directory
RESULTS_DIR="variant_test_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "========================================="
echo "Batch Testing Config 15 Variants"
echo "========================================="
echo "Duration per test: ${DURATION}s"
echo "Testing variants: ${VARIANTS[*]}"
echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Stream selection
echo "Select test stream:"
echo "  1) Pluto TV Action"
echo "  2) Paramount Movie Channel"
echo "  3) Kino Barrandov"
echo "  4) Action 24"
read -p "Enter selection (1-4) [default: 1]: " stream_choice
stream_choice="${stream_choice:-1}"

case $stream_choice in
    1) STREAM_URL="http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5f8ed1ff5c39700007e2204a/master.m3u8?appName=web&appVersion=unknown&clientTime=0&deviceDNT=0&deviceId=8e055171-1f2c-11ef-86d8-5d587df108c6&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false&sid=c3b67254-4628-4f0e-8164-5a50e8969a42"
       STREAM_NAME="Pluto TV Action"
       ;;
    2) STREAM_URL="http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5cb0cae7a461406ffe3f5213/master.m3u8?appName=web&appVersion=unknown&clientTime=0&deviceDNT=0&deviceId=6c2a7819-30d3-11ef-9cf5-e9ddff8ff496&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false&sid=8a4a0712-cb24-4d05-b429-1b98c1f73f74"
       STREAM_NAME="Paramount Movie Channel"
       ;;
    3) STREAM_URL="http://83.167.253.107/hdmi1_ext"
       STREAM_NAME="Kino Barrandov"
       ;;
    4) STREAM_URL="http://actionlive.siliconweb.com/actionabr/actiontv/playlist.m3u8"
       STREAM_NAME="Action 24"
       ;;
    *) echo "Invalid selection"; exit 1 ;;
esac

echo ""
echo "Testing with stream: $STREAM_NAME"
echo ""

# Summary file
SUMMARY_FILE="$RESULTS_DIR/summary.txt"
echo "Config 15 Variant Test Results" > "$SUMMARY_FILE"
echo "Date: $(date)" >> "$SUMMARY_FILE"
echo "Stream: $STREAM_NAME" >> "$SUMMARY_FILE"
echo "Duration: ${DURATION}s per variant" >> "$SUMMARY_FILE"
echo "----------------------------------------" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Test each variant
PASSED=0
FAILED=0

for variant in "${VARIANTS[@]}"; do
    echo "========================================="
    echo "Testing Variant $variant"
    echo "========================================="
    
    LOG_FILE="$RESULTS_DIR/variant_${variant}.log"
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Run the test
    ./quick_test_config.sh "$variant" "$STREAM_URL" "$DURATION" > "$LOG_FILE" 2>&1
    EXIT_CODE=$?
    
    # Record end time
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    
    # Log result
    if [ $EXIT_CODE -eq 0 ]; then
        echo "✓ Variant $variant PASSED (${ELAPSED}s)" | tee -a "$SUMMARY_FILE"
        ((PASSED++))
    else
        echo "✗ Variant $variant FAILED with exit code $EXIT_CODE (${ELAPSED}s)" | tee -a "$SUMMARY_FILE"
        ((FAILED++))
    fi
    
    # Check for OOM in logs
    if grep -qi "out of memory\|oom\|killed" "$LOG_FILE"; then
        echo "  WARNING: Possible OOM detected" | tee -a "$SUMMARY_FILE"
    fi
    
    echo ""
    
    # Brief pause between tests
    sleep 2
done

# Final summary
echo "=========================================" | tee -a "$SUMMARY_FILE"
echo "Test Complete!" | tee -a "$SUMMARY_FILE"
echo "=========================================" | tee -a "$SUMMARY_FILE"
echo "Passed: $PASSED" | tee -a "$SUMMARY_FILE"
echo "Failed: $FAILED" | tee -a "$SUMMARY_FILE"
echo "Total:  $((PASSED + FAILED))" | tee -a "$SUMMARY_FILE"
echo "" | tee -a "$SUMMARY_FILE"
echo "Results saved to: $RESULTS_DIR" | tee -a "$SUMMARY_FILE"
echo "Summary: $SUMMARY_FILE" | tee -a "$SUMMARY_FILE"

# Show which variants passed
if [ $PASSED -gt 0 ]; then
    echo "" | tee -a "$SUMMARY_FILE"
    echo "Successful variants:" | tee -a "$SUMMARY_FILE"
    for variant in "${VARIANTS[@]}"; do
        LOG_FILE="$RESULTS_DIR/variant_${variant}.log"
        if grep -q "✓ Variant $variant worked successfully" "$LOG_FILE" 2>/dev/null; then
            echo "  - Variant $variant" | tee -a "$SUMMARY_FILE"
        fi
    done
fi

echo ""
echo "To view detailed logs:"
echo "  cat $SUMMARY_FILE"
echo "  ls -lh $RESULTS_DIR/"
