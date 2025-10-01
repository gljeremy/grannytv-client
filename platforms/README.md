# Platform-Specific Files

This folder contains platform-specific scripts and configurations for the MPV-based IPTV player.

## 📁 Structure

- **`windows/`** - Windows development tools, MPV installation, and testing scripts
- **`linux/`** - Raspberry Pi/Linux deployment, MPV setup, and service files

## 🔄 Cross-Platform Development

The main application (`iptv_smart_player.py`) automatically detects the platform and applies MPV optimizations:
- **Windows**: Hardware decode enabled, 3-second cache
- **Raspberry Pi**: Conservative settings, 2-second cache, software decode
- **Linux**: Standard MPV configurations

All platforms use the same MPV-based architecture for consistent performance.