# Variant 14 Configuration Applied

## Update Summary
Applied the best-performing variant from batch testing (Variant 14 - Balanced optimization) to the main IPTV player.

**Date:** October 8, 2025  
**Change:** Updated MPV configuration from Config 15 baseline to Variant 14

## Configuration Changes

### Previous Settings (Config 15 Baseline):
- `--cache-secs=2`
- `--demuxer-max-bytes=20M`
- `--demuxer-readahead-secs=2`

### New Settings (Variant 14 - Balanced Optimization):
- `--cache-secs=3` *(+50% increase)*
- `--demuxer-max-bytes=25M` *(+25% increase)*
- `--demuxer-readahead-secs=3` *(+50% increase)*

## Why Variant 14?

**Balanced Optimization** provides:
1. **Increased cache duration** (3s) - Better buffering for network fluctuations
2. **Larger demuxer buffer** (25M) - More data pre-fetched for smooth playback
3. **Extended readahead** (3s) - Better anticipation of data needs
4. **Memory efficient** - Not as aggressive as Variant 15 (Performance), avoiding potential OOM issues

## Base Configuration (Unchanged)
- `--hwdec=no` - Software decode (stable on Pi 3)
- `--vo=gpu` - GPU video output
- `--cache=yes` - Enable caching
- `--framedrop=vo` - Drop frames if needed to maintain sync
- `--no-osc` - No on-screen controls
- `--no-input-default-bindings` - No keyboard bindings
- `--really-quiet` - Quiet mode
- `--fullscreen` - Fullscreen playback
- `--loop-playlist=inf` - Loop forever
- `--user-agent=Mozilla/5.0 (Smart-IPTV-Player)` - Custom user agent

## Testing Results
From batch_test_variants testing, Variant 14 showed the best balance between:
- Playback stability
- Memory usage
- Buffer management
- Network resilience

## Files Modified
- `iptv_smart_player.py` - Updated MPV configuration for both Raspberry Pi and Desktop/Windows modes

## Next Steps
1. Monitor player performance in production
2. Watch for any memory issues (though Variant 14 is more conservative than the aggressive variants)
3. If needed, can fall back to Config 15 baseline or try Variant 16 (Conservative) for lower memory usage

## Reverting (if needed)
To revert to the previous Config 15 baseline:
```bash
git checkout iptv_smart_player.py
```

Or manually change back to:
- `--cache-secs=2`
- `--demuxer-max-bytes=20M`
- `--demuxer-readahead-secs=2`
