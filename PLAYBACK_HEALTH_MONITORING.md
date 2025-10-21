# Playback Health Monitoring & Recovery

## Overview

The IPTV player now includes advanced health monitoring to detect and recover from playback pauses and stalls automatically.

## Features Added

### 1. **Playback Health Detection**
The player now actively monitors if MPV is actually playing, not just if the process exists:

- **Process State Monitoring**: Checks if MPV process is in a healthy state (not zombie, not stuck in IO wait)
- **CPU Activity Tracking**: Monitors CPU usage to detect if the player is frozen
- **Signal Responsiveness**: Verifies the process responds to signals
- **Periodic Checks**: Runs health checks every 30 seconds (configurable)

### 2. **Automatic Recovery**
When playback issues are detected:

- **3-Strike Policy**: Requires 3 consecutive failed health checks before restarting (reduces false positives)
- **Graceful Restart**: Terminates current player and restarts the stream
- **Clean Process Management**: Ensures all MPV processes are properly cleaned up
- **Automatic Retry**: Attempts to restart the same stream or move to the next one

### 3. **Network Resilience**
New MPV options prevent network-related pauses:

- `--network-timeout=15`: Stops waiting after 15 seconds of no data
- `--stream-lavf-o=reconnect=1`: Automatically reconnects on network drops
- `--stream-lavf-o=reconnect_streamed=1`: Handles reconnection for live streams
- `--stream-lavf-o=reconnect_delay_max=5`: Limits reconnection delay to 5 seconds
- `--demuxer-lavf-o=timeout=10000000`: 10-second timeout for initial connection

## How It Works

### Health Check Process

```
Every 30 seconds:
1. Check if MPV process exists and is responsive
2. Verify process is not in bad state (zombie, IO wait)
3. Compare CPU time to detect stalls
4. If unhealthy: increment counter
5. If healthy: reset counter
6. If counter reaches 3: restart playback
```

### Log Messages

**Healthy Playback:**
```
[TV] Status: Playing (PID: 1038) - Health: OK
```

**Detected Issues:**
```
[HEALTH] Playback health check failed (1/3)
[HEALTH] Playback health check failed (2/3)
[HEALTH] Playback health check failed (3/3)
[HEALTH] Multiple consecutive health check failures - restarting playback
[RESTART] Playback stalled
```

**Recovery:**
```
[RESTART] Stopping current player...
[MPV] Starting MPV player...
[OK] SUCCESS! MPV Config 1 stable (PID: 2045)
```

## Configuration

### Health Check Settings

In the `MPVIPTVPlayer.__init__()` method:

```python
self.health_check_interval = 30  # Check every 30 seconds
self.max_stall_checks = 3        # Restart after 3 failures
```

**Adjust these values if needed:**
- **Shorter interval** (15-20s): More responsive but may increase false positives
- **Longer interval** (45-60s): More tolerant of temporary issues but slower recovery
- **Higher max_stall_checks** (4-5): More tolerant before restart
- **Lower max_stall_checks** (2): More aggressive recovery

## Prevention Strategies

### Network Issues
The new MPV reconnection options handle most network hiccups automatically without requiring a full restart:

- **Temporary network drops**: MPV reconnects automatically
- **Slow servers**: 15-second timeout prevents indefinite waiting
- **Connection losses**: Reconnection with exponential backoff (max 5s)

### Stream Quality Issues
If certain streams consistently cause problems:

1. Check `iptv_player_mpv.log` for patterns
2. Use stream performance analyzer: `python3 tools/stream_performance_analyzer.py`
3. Remove problematic streams from database
4. Use protocol optimizer: `python3 tools/iptv_protocol_optimizer.py`

### Resource Constraints
On Raspberry Pi, prevent pauses due to resource exhaustion:

```bash
# Network optimization
sudo ./tools/network-optimize.sh

# GPU acceleration
sudo ./tools/gpu-optimize.sh

# Monitor system resources
python3 tools/performance-monitor.py
```

## Testing

### Manual Testing
To test health monitoring:

```bash
# Start the player
python3 iptv_smart_player.py

# In another terminal, simulate a stall by freezing the MPV process
sudo kill -STOP $(pgrep mpv)

# Watch logs - should detect stall and restart after ~90 seconds (3 checks)

# Cleanup (if needed)
sudo kill -CONT $(pgrep mpv)
```

### Expected Behavior
1. Player starts normally
2. Health checks run every 30 seconds
3. After freezing MPV, health checks fail
4. After 3 consecutive failures (~90s), player restarts
5. Playback resumes automatically

## Monitoring

### Check Logs
```bash
# Real-time monitoring
tail -f /home/jeremy/gtv/iptv_player_mpv.log

# Search for health issues
grep "HEALTH\|RESTART" /home/jeremy/gtv/iptv_player_mpv.log

# Check recent activity
tail -100 /home/jeremy/gtv/iptv_player_mpv.log
```

### Systemd Service
The player runs as a service and will automatically use health monitoring:

```bash
# Check service status
sudo systemctl status iptv-player

# View recent logs
sudo journalctl -u iptv-player -n 100 -f
```

## Troubleshooting

### False Positives
If player restarts too frequently when working fine:

1. **Increase** `health_check_interval` to 45 or 60 seconds
2. **Increase** `max_stall_checks` to 4 or 5
3. Check system load - CPU/memory exhaustion can cause false positives

### Not Detecting Real Stalls
If player doesn't restart when clearly frozen:

1. **Decrease** `health_check_interval` to 20 or 15 seconds
2. **Decrease** `max_stall_checks` to 2
3. Check if MPV process is actually frozen or just buffering

### Network Reconnection Not Working
If MPV doesn't reconnect on network drops:

1. Check your MPV version: `mpv --version` (needs 0.33+)
2. Verify network settings in `tools/network-optimize.sh`
3. Test with different streams - some may not support reconnection

## Advanced Options

### Custom Health Checks
You can extend the health monitoring by modifying `check_playback_health()`:

```python
def check_playback_health(self):
    # Add custom checks here
    # Examples:
    # - Check network activity
    # - Monitor frame rate
    # - Check audio output
    # - Verify HDMI connection
    pass
```

### Alternative Recovery Strategies
Instead of restarting the same stream, you could:

1. **Switch to backup stream**: Move to next stream immediately
2. **Reduce quality**: Try lower bitrate version
3. **Change protocol**: Switch from HLS to other protocol
4. **Notify user**: Send alert/notification

## Performance Impact

Health monitoring has minimal overhead:
- **CPU**: <0.1% average (reading /proc files)
- **Memory**: ~100 bytes for tracking variables
- **IO**: Negligible (one /proc read every 30s)

## Summary

The playback health monitoring system provides:

✅ **Automatic detection** of playback stalls and freezes  
✅ **Graceful recovery** without manual intervention  
✅ **Network resilience** with automatic reconnection  
✅ **Configurable thresholds** for different scenarios  
✅ **Detailed logging** for troubleshooting  
✅ **Minimal overhead** on system resources  

Perfect for elderly users who need reliable, hands-off TV viewing!
