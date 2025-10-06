# Quick Reference - OOM Fix Monitoring

## Check Current Status

### Memory Usage
```bash
# Overall memory
free -h

# MPV process
ps aux | grep mpv | grep -v grep

# Quick summary
ps aux | grep mpv | grep -v grep | awk '{print "MPV: " $6 " (" $4 "%)"}'
```

### Video Output
```bash
# HDMI status
cat /sys/class/drm/card0-HDMI-A-1/status
cat /sys/class/drm/card0-HDMI-A-1/enabled

# Check MPV is using DRM
ps aux | grep drm
```

### Service Status
```bash
# Service status
sudo systemctl status iptv-player

# Recent logs
tail -f /home/jeremy/gtv/iptv_player_mpv.log

# Check for crashes
journalctl -u iptv-player --no-pager -n 50
```

## Check for OOM Events

```bash
# Recent OOM events
dmesg | grep -i oom | tail -20

# Monitor for new OOM events
dmesg -w | grep -i oom
```

## Restart Service

```bash
# Restart player
sudo systemctl restart iptv-player

# Check startup
sleep 15 && sudo systemctl status iptv-player
```

## Memory Targets

| Metric | Safe Range | Current |
|--------|-----------|---------|
| MPV Memory | < 200MB | ~136MB ✅ |
| MPV % | < 25% | ~18% ✅ |
| Available | > 200MB | ~271MB ✅ |

## Warning Signs

⚠️ **Watch for:**
- MPV memory > 300MB
- Available memory < 150MB
- OOM messages in dmesg
- Exit code -9 in logs

## If Issues Occur

### Switch to Ultra-Minimal Config
The system will automatically try Config 2 (ultra-minimal) if Config 1 fails.

Config 2 settings:
- Cache: 1 second (vs 2 seconds)
- Buffer: 5MB (vs 10MB)

### Manual Test
```bash
# Stop service
sudo systemctl stop iptv-player

# Test with ultra-minimal settings
mpv --vo=drm --drm-connector=HDMI-A-1 \
    --cache=yes --cache-secs=1 \
    --demuxer-max-bytes=5M \
    --framedrop=vo --really-quiet \
    <stream-url>
```

## Long-term Monitoring

### Set up periodic checks
```bash
# Add to crontab (every hour)
0 * * * * free -h >> /home/jeremy/gtv/memory_log.txt

# Monitor script
watch -n 300 'date >> /home/jeremy/gtv/monitor.log; free -h >> /home/jeremy/gtv/monitor.log'
```

## Success Indicators

✅ **Healthy System:**
- MPV runs for hours without OOM
- Memory usage stable
- No exit code -9
- Video displays correctly
- HDMI connected and enabled

## Configuration Files

- Player code: `/home/jeremy/gtv/iptv_smart_player.py`
- Service file: `/etc/systemd/system/iptv-player.service`
- Logs: `/home/jeremy/gtv/iptv_player_mpv.log`

## Documentation

- `MEMORY_FIX.md` - Technical details of the fix
- `OOM_FIX_SUMMARY.md` - Complete analysis and results
- `DRM_VIDEO_FIX.md` - Original DRM configuration details
