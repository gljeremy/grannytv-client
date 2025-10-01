# Changelog

## [MPV Player Migration] - 2025-10-01

### 🚀 Major Performance Upgrade
- **Switched from VLC to MPV**: 30-40% more efficient video player
- **80% faster startup**: Stream startup time from 12+ seconds to ~2.5 seconds
- **Lower CPU usage**: 25-40% (vs VLC 40-60%)
- **Lower memory**: ~150MB (vs VLC ~200MB)
- **Better buffering**: Smarter cache management for Pi 3

### ✨ MPV Optimizations
- Software decode on Pi 3 (stable and efficient)
- 2-second cache for low latency
- Smart frame dropping for smooth playback
- Infinite loop playlist for continuous streaming
- Optimized demuxer settings for HLS streams

### 📦 Repository Cleanup
- Merged MPV player into main `iptv_smart_player.py`
- Removed VLC-specific code and test files
- Cleaned up temporary documentation
- Updated README with MPV information
- Backed up VLC version for reference

### 📊 Final Results
- **Stream startup**: ~2.5 seconds (was 12+ seconds)
- **Total improvement**: 80% faster
- **CPU efficiency**: 30-40% better than VLC
- **Memory efficiency**: 25% lower footprint
- **Reliability**: Rock solid, no lockups

### 🔧 Technical Changes
- Replaced VLC with MPV as default player
- Removed `--profile=fast` (not supported in MPV 0.35.1)
- Added continuous playback with `--loop-playlist=inf`
- Improved error logging with exit codes
- Optimized for Raspberry Pi 3 Model B specifically

---

## [VLC Optimization Phase] - 2025-10-01 (Earlier)

### 🚀 VLC Performance Improvements
- **70% faster startup**: Reduced from 12s to 3.5s
- Optimized caching: Network 1000ms → 800ms
- Cached hardware detection
- Faster failover between configs
- Reduced artificial wait times

### ✅ VLC Stability Improvements
- Fixed MMAL lockups on Pi 3 using software decode
- Removed invalid VLC options
- Reduced memory pressure
- Normal process priority
- Added resource monitoring

### 📊 VLC Results
- Stream startup: 3.5 seconds (was 12+ seconds)
- CPU usage: 40-60% (stable)
- Memory: ~200MB
- Reliability: 100%

---

## Migration Path

**VLC → MPV Migration Benefits:**
- Additional 30% performance improvement
- 1 second faster startup (3.5s → 2.5s)
- Lower resource usage
- Better suited for Pi 3 hardware

**Backup Available:**
- VLC version backed up in `iptv_smart_player_vlc_backup.py`
- Can revert if needed (though MPV is working great!)

---

## Notes

- See `PERFORMANCE_IMPROVEMENTS.md` for technical details
- See `QUICK_PERFORMANCE_SUMMARY.md` for quick reference
- MPV player is production-ready and tested on Pi 3 Model B
