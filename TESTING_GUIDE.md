# Quick Start - Testing the Buffering Fix

## What Was Fixed
Your IPTV player was experiencing crashes every ~60 seconds due to insufficient buffering for HLS streams (like Pluto TV). The fix increases buffer sizes and adds automatic reconnection support.

## Testing the Fix

### Option 1: Quick Test (Recommended)
Run the automated test script for 5 minutes:
```bash
cd /home/jeremy/gtv
./test_buffering_fix.sh
```

This will:
- Start the player
- Monitor for crashes every 30 seconds
- Report memory usage and crash count
- Run for 5 minutes automatically

### Option 2: Manual Test
Start the player normally:
```bash
cd /home/jeremy/gtv
python3 iptv_smart_player.py
```

Then in another terminal, monitor the logs:
```bash
# Watch for crashes
tail -f /home/jeremy/gtv/iptv_player_mpv.log | grep -E "exit code|crash|Playing"

# Count crashes
grep -c "exit code" /home/jeremy/gtv/iptv_player_mpv.log
```

### Option 3: Systemd Service
If you have the service installed:
```bash
systemctl --user restart iptv-player.service
systemctl --user status iptv-player.service
journalctl --user -u iptv-player.service -f
```

## What to Look For

### ✓ Success Indicators
- Player runs for 5+ minutes without crashes
- No "exit code 2" errors in logs
- Steady "Status: Playing" messages every 60 seconds
- Smooth playback without pauses

### ⚠️ Problem Indicators
- "exit code 2" or "exit code 3" messages
- Player crashes before 5 minutes
- Frequent restarts
- Playback pauses/freezes

## Expected Memory Usage
- Before: ~40-60MB for MPV
- After: ~70-90MB for MPV
- This is normal and acceptable on Raspberry Pi 3

## Monitoring Commands

### Real-time crash monitoring
```bash
tail -f /home/jeremy/gtv/iptv_player_mpv.log | grep --line-buffered "exit code"
```

### Check uptime pattern
```bash
grep "Status: Playing" /home/jeremy/gtv/iptv_player_mpv.log | tail -20
```

### Memory check
```bash
ps aux | grep mpv | grep -v grep
```

## Troubleshooting

### If crashes still occur after fix:
1. Check available memory:
   ```bash
   free -h
   ```

2. Verify network is stable:
   ```bash
   ping -c 10 8.8.8.8
   ```

3. Check buffer settings were applied:
   ```bash
   ps aux | grep mpv
   # Look for --cache-secs=10 and --demuxer-max-bytes=50M
   ```

4. Review error details:
   ```bash
   grep -B5 -A5 "exit code" /home/jeremy/gtv/iptv_player_mpv.log | tail -30
   ```

## Changes Summary
- **Cache increased**: 2s → 10s (5x larger buffer)
- **Demuxer buffer**: 20MB → 50MB (2.5x larger)
- **Readahead**: 2s → 10s (better prediction)
- **Added**: HLS reconnection support
- **Added**: HLS bitrate optimization

## Files Modified
- `iptv_smart_player.py` - Main player with updated buffer settings

## Documentation
- `BUFFERING_FIX.md` - Detailed diagnosis and fix explanation
- `test_buffering_fix.sh` - Automated test script

## Quick Health Check
Run this one-liner to see current status:
```bash
echo "=== IPTV Health Check ===" && \
echo "Player running: $(pgrep -f iptv_smart_player.py > /dev/null && echo 'YES' || echo 'NO')" && \
echo "MPV running: $(pgrep mpv > /dev/null && echo 'YES' || echo 'NO')" && \
echo "Recent crashes: $(grep -c 'exit code' /home/jeremy/gtv/iptv_player_mpv.log 2>/dev/null || echo 0)" && \
echo "Last status: $(grep 'Status: Playing' /home/jeremy/gtv/iptv_player_mpv.log 2>/dev/null | tail -1)"
```
