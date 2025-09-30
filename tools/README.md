# Diagnostic & Development Tools

Utilities for troubleshooting and system diagnostics.

## 📄 Files

- **`vlc-setup.sh`** - Comprehensive VLC diagnostic and configuration tool

## 🚀 Usage

```bash
# Run VLC diagnostics
./tools/vlc-setup.sh

# Test specific VLC configurations
./tools/vlc-setup.sh --test
./tools/vlc-setup.sh --framebuffer  
./tools/vlc-setup.sh --desktop
```

## 🔧 Features

- Tests VLC installation and version
- Checks video output capabilities (X11, framebuffer)
- Verifies audio configuration (ALSA, HDMI)
- Tests sample streams with different VLC settings
- Provides performance recommendations
- Fixes common permission issues