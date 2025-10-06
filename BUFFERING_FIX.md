# Buffering Issue Diagnosis and Fix

## Problem Summary
After setup and reboot, playback starts correctly but experiences long pauses during playback.

## Root Cause Analysis

### Evidence from Logs
1. **Pattern of crashes**: MPV player crashes with exit code 2 approximately **1 minute** after successful startup
2. **Frequency**: 22 crashes detected in logs, all with exit code 2
3. **Crash timing examples**:
   - `2025-10-06 10:42:28` (started) → `10:43:28` (crashed) = **60 seconds**
   - `2025-10-03 14:08:29` (started) → `14:09:29` (crashed) = **60 seconds**
   - Pattern repeats consistently

### Root Causes Identified

1. **Insufficient HLS buffering**
   - Previous cache: 2 seconds (too small for dynamic HLS streams)
   - HLS streams like Pluto TV use time-limited segment URLs that expire
   - Small buffer couldn't handle segment refresh delays

2. **Missing HLS reconnection support**
   - No reconnection logic for temporary network issues
   - No recovery when HLS playlist segments expire or fail to load
   - FFmpeg lavf options for reconnection were not configured

3. **Limited demuxer buffer**
   - Previous buffer: 20MB (insufficient for HLS segment caching)
   - Not enough headroom for network variability

## Solution Applied

### Buffer Size Increases
**Config 1 (Primary - Raspberry Pi):**
- `cache-secs`: 2 → **10 seconds** (5x increase)
- `demuxer-max-bytes`: 20M → **50M** (2.5x increase)
- `demuxer-readahead-secs`: 2 → **10 seconds** (5x increase)

**Config 2 (Fallback - Raspberry Pi):**
- `cache-secs`: 1 → **5 seconds** (5x increase)
- `demuxer-max-bytes`: Added **30M** buffer

**Desktop/Windows Config:**
- `cache-secs`: 3 → **10 seconds** (3.3x increase)
- `demuxer-max-bytes`: Added **50M** buffer

### HLS-Specific Improvements

**New reconnection options added:**
```
--stream-lavf-o=reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,reconnect_delay_max=5
```

This provides:
- `reconnect=1`: Enable automatic reconnection
- `reconnect_at_eof=1`: Reconnect when stream ends unexpectedly
- `reconnect_streamed=1`: Reconnect for live streams
- `reconnect_delay_max=5`: Maximum 5 second delay between retries

**HLS quality optimization:**
```
--hls-bitrate=max
```
- Ensures best available quality stream is selected

## Expected Impact

### Before Fix
- ✗ Crashes every ~60 seconds with exit code 2
- ✗ Playback interruptions requiring restart
- ✗ Poor user experience with frequent pauses

### After Fix
- ✓ 10-second buffer provides stability during HLS segment transitions
- ✓ Automatic reconnection handles temporary network issues
- ✓ Larger demuxer buffer absorbs network variability
- ✓ Smooth continuous playback without interruptions

## Memory Impact

**Additional memory usage:**
- Config 1: ~30-50MB additional buffer (acceptable on Pi 3 with 1GB RAM)
- Config 2: ~15-30MB additional buffer
- Trade-off: Minimal memory increase for significantly better stability

## Testing Recommendations

1. **Monitor playback for extended period** (30+ minutes)
2. **Check logs for exit code 2 crashes**:
   ```bash
   tail -f /home/jeremy/gtv/iptv_player_mpv.log | grep "exit code"
   ```
3. **Watch for buffering messages**:
   ```bash
   grep -i "buffer\|cache\|exit code" /home/jeremy/gtv/iptv_player_mpv.log
   ```
4. **Verify memory usage stays reasonable**:
   ```bash
   ps aux | grep mpv
   ```

## Rollback Plan

If issues occur, revert buffer values to original settings:
- `cache-secs=2`
- `demuxer-max-bytes=20M`
- `demuxer-readahead-secs=2`
- Remove `--stream-lavf-o` options

## Additional Notes

- The fix addresses HLS-specific streaming issues common with services like Pluto TV
- Buffer increases are conservative and well within Pi 3 hardware capabilities
- Reconnection logic provides resilience against temporary network hiccups
- No changes to video decoding or output settings (maintains performance)
