#!/bin/bash
# Diagnostic script to verify MPV streaming stability
# Starts the player and monitors for crashes

echo "======================================"
echo "MPV Stability Test - Diagnostic Run"
echo "======================================"
echo ""

# Clear old log
LOG_FILE="/home/jeremy/gtv/iptv_player_mpv.log"
BACKUP_LOG="/home/jeremy/gtv/iptv_player_mpv.log.backup.$(date +%Y%m%d_%H%M%S)"

if [ -f "$LOG_FILE" ]; then
    echo "Backing up existing log to: $BACKUP_LOG"
    cp "$LOG_FILE" "$BACKUP_LOG"
    > "$LOG_FILE"  # Clear the log
fi

echo ""
echo "Starting IPTV player..."
echo "Monitor will check for crashes every 30 seconds"
echo "Press Ctrl+C to stop"
echo ""

# Start the player in background
cd /home/jeremy/gtv
python3 iptv_smart_player.py > /tmp/iptv_test.out 2>&1 &
PLAYER_PID=$!

echo "Player started with PID: $PLAYER_PID"
echo ""

# Monitor for 5 minutes
DURATION=300
INTERVAL=30
ELAPSED=0

while [ $ELAPSED -lt $DURATION ]; do
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    
    # Check if player is still running
    if ! kill -0 $PLAYER_PID 2>/dev/null; then
        echo "⚠️  WARNING: Player process died!"
        exit 1
    fi
    
    # Check for crashes in log
    CRASH_COUNT=$(grep -c "exit code" "$LOG_FILE" 2>/dev/null || echo 0)
    MPV_PID=$(pgrep -f "^mpv " | head -1)
    
    if [ -n "$MPV_PID" ]; then
        MPV_MEM=$(ps -p $MPV_PID -o rss= | awk '{print int($1/1024)}')
        echo "[$ELAPSED s] ✓ MPV running (PID: $MPV_PID, Memory: ${MPV_MEM}MB), Crashes: $CRASH_COUNT"
    else
        echo "[$ELAPSED s] ⚠️  No MPV process found, Crashes: $CRASH_COUNT"
    fi
    
    # Show last error if any
    LAST_ERROR=$(tail -5 "$LOG_FILE" 2>/dev/null | grep -i "error\|crash\|exit code" | tail -1)
    if [ -n "$LAST_ERROR" ]; then
        echo "         Last error: $LAST_ERROR"
    fi
done

echo ""
echo "======================================"
echo "Test completed - 5 minute run"
echo "======================================"

# Final check
FINAL_CRASHES=$(grep -c "exit code" "$LOG_FILE" 2>/dev/null || echo 0)
echo "Total crashes detected: $FINAL_CRASHES"

if [ "$FINAL_CRASHES" -eq 0 ]; then
    echo "✓ SUCCESS: No crashes detected!"
    echo "✓ The buffering fix appears to be working correctly"
else
    echo "⚠️  WARNING: $FINAL_CRASHES crash(es) detected"
    echo "Recent log entries:"
    tail -20 "$LOG_FILE"
fi

echo ""
echo "Stopping player..."
kill $PLAYER_PID 2>/dev/null
wait $PLAYER_PID 2>/dev/null

echo "Test complete. Check full log at: $LOG_FILE"
