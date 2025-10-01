# GrannyTV Project - Copilot Instructions

## 🎯 Project Overview

**GrannyTV** is an optimized IPTV player designed for elderly users on Raspberry Pi using **MPV media player**. The system is plug-and-play: connect Pi to TV via HDMI and it automatically starts playing live television streams with ultra-low latency and 30-50% better performance than VLC.

## 📁 Project Structure & Organization Preferences

### **Folder Organization (IMPORTANT)**

```
grannytv-client/
├── iptv_smart_player.py      # Main application
├── working_streams.json      # Stream database (196 tested streams)
├── config.json              # Environment detection
├── requirements.txt         # Python dependencies
├── README.md               # Main documentation
├── platforms/              # Platform-specific files
│   ├── windows/           # Windows development tools
│   │   ├── setup-venv.ps1 # Virtual environment setup  
│   │   └── test-windows.ps1 # Local testing
│   └── linux/             # Raspberry Pi deployment
│       ├── pi-setup.sh    # Initial Pi setup
│       ├── pi-update.sh   # Git-based updates
│       └── iptv-player.service # Systemd service
├── tools/                 # Diagnostic & development utilities
│   ├── iptv_protocol_optimizer.py    # Stream protocol optimization
│   ├── stream_performance_analyzer.py # Stream latency testing
│   └── vlc-setup.sh      # Legacy VLC diagnostics (deprecated)
└── docs/                  # Documentation & optimization guides
    └── raspberry-pi-optimizations.md # Pi hardware optimization guide
```

### **File Organization Rules**

✅ **Platform-specific files** → `platforms/windows/` or `platforms/linux/`  
✅ **Tools & diagnostics** → `tools/`  
✅ **Documentation** → `docs/` (future expansion)  
✅ **Core application files** → Root directory  

### **When adding new files:**

- **Windows PowerShell scripts** → `platforms/windows/`
- **Linux shell scripts** → `platforms/linux/`  
- **Diagnostic/testing tools** → `tools/`
- **User documentation** → Currently root (move to `docs/` when it grows)
- **Configuration/data files** → Root directory

## 🚀 Current System State (PRODUCTION READY)

### **Performance Achievements**
- ✅ **MPV-based architecture**: 30-50% more efficient than VLC on Pi hardware
- ✅ **Ultra-fast startup**: ~2.5 seconds (vs 5-7s with VLC)
- ✅ **Platform-optimized configurations**: Windows, Pi, and Linux specific settings
- ✅ **Conservative Pi caching**: 2000ms network cache prevents stuttering
- ✅ **Hardware-aware decode**: Auto MMAL detection based on GPU memory split

### **Architecture Status**
- ✅ **MPV-focused**: Transitioned from VLC to MPV for superior Pi performance
- ✅ **Multi-tier configs**: Performance → Lighter → Minimal fallback configurations  
- ✅ **Platform detection**: Auto-detects Pi hardware, Windows, Linux optimizations
- ✅ **Crash prevention**: Comprehensive MPV error handling, quick restarts
- ✅ **Service integration**: Systemd auto-start working perfectly

## 🔧 Development Workflow & Preferences

### **Testing Approach**
- **Windows development**: Use `platforms/windows/test-windows.ps1` (requires MPV installation)
- **Pi deployment**: Use `platforms/linux/pi-update.sh` for updates  
- **Stream analysis**: Use `tools/stream_performance_analyzer.py` for latency testing
- **Protocol optimization**: Use `tools/iptv_protocol_optimizer.py` for stream tuning

### **Code Style Preferences**
- **Simple & readable**: Code for elderly user context (reliability over complexity)
- **Conservative approach**: Stability over aggressive optimization
- **Clear logging**: Performance metrics, error details, Pi hardware info
- **Path references**: Always use the new folder structure in scripts

### **Performance Philosophy**
- **Graduated optimization**: Start conservative, add optimizations incrementally
- **Hardware-aware**: Detect Pi model, GPU memory, adapt settings accordingly
- **Graceful degradation**: Multiple fallback configurations, never completely fail

## 🎬 MPV Optimization Details (Core System)

### **Current MPV Configuration Strategy**

**Config 1 (Performance)**: 2-second cache, GPU output, smart frame dropping  
**Config 2 (Lighter)**: 1-second cache, minimal options for stability  
**Config 3 (Minimal)**: Basic GPU output, essential options only  

### **Pi-Specific Optimizations**
```bash
--hwdec=no                  # Software decode (stable on Pi 3)
--vo=gpu                    # GPU output (efficient)
--cache-secs=2              # Conservative 2-second buffer
--demuxer-max-bytes=20M     # Reasonable buffer size
--framedrop=vo              # Smart frame dropping
--no-osc                    # No on-screen controls
--loop-playlist=inf         # Continuous playback
```

### **Platform-Specific Configurations**
- **Windows**: Hardware decode enabled (`--hwdec=auto`), 3-second cache
- **Raspberry Pi**: Software decode, conservative 2-second cache, thread limits
- **Desktop Linux**: Hardware decode enabled, standard configurations

### **Performance Monitoring**
- GPU memory detection (`vcgencmd get_mem gpu`)
- Pi model identification (`/proc/cpuinfo`)  
- MPV process monitoring with error capture
- Stream quality analysis with performance ranking

## 👵 User Context & Design Goals

### **Target Users**
- **Elderly users**: Zero technical knowledge required
- **Care facilities**: Set-and-forget operation
- **Family caregivers**: Remote monitoring, easy updates

### **Core Requirements**
- **Plug & play**: Connect Pi to TV, it works immediately
- **Reliable**: Never completely fail, always show something
- **Simple**: No remote controls, menus, or user interaction
- **Optimized**: Minimal latency for responsive experience

## 🔄 Update Workflow

### **Making Changes**
1. **Develop on Windows**: Use `platforms/windows/test-windows.ps1`
2. **Commit changes**: Standard Git workflow
3. **Deploy to Pi**: SSH and run `./platforms/linux/pi-update.sh`
4. **Monitor performance**: Check logs for optimization metrics

### **Path Updates Required**
When moving files or updating scripts, ensure all references use the new folder structure:
- ✅ `platforms/linux/pi-update.sh` (not `pi-update.sh`)
- ✅ `platforms/linux/iptv-player.service` (not `iptv-player.service`)
- ✅ `tools/vlc-setup.sh` (not `vlc-setup.sh`)

## 🎯 Current Focus Areas

### **Completed & Stable**
- MPV performance optimization ✅
- Platform-specific configurations (Windows/Pi/Linux) ✅  
- Hardware-aware acceleration ✅
- Stream performance analysis (84 streams tested) ✅
- Auto-start service ✅
- Documentation organization ✅

### **Future Enhancement Areas**
- Stream database refresh automation (low priority)
- Additional MPV codec optimizations (low priority)
- More diagnostic tools in `tools/` folder (as needed)

## 💡 AI Assistant Guidelines

### **When suggesting changes:**
- **Respect folder structure**: Use `platforms/` and `tools/` organization
- **Maintain stability**: Conservative approach, test gradualism
- **Consider elderly users**: Simplicity and reliability over features
- **Preserve MPV optimizations**: Don't break current platform-specific configurations
- **Update paths**: Ensure all scripts reference new folder locations

### **Common tasks:**
- **Performance tuning**: Adjust MPV parameters gradually, test on all platforms
- **Troubleshooting**: Add tools to `tools/` folder (stream analysis, protocol optimization)
- **Platform support**: Add scripts to respective `platforms/` folders
- **Documentation**: Keep it simple and practical, focus on MPV setup

This project has evolved from experimental VLC-based system to a production-ready **MPV-powered solution**. The current state represents an optimized, stable system that successfully delivers on its core promise: plug-and-play television for elderly users with professional-grade performance and superior efficiency on Raspberry Pi hardware.

## 📋 MPV Installation Requirements

### **Windows Development:**
- Install MPV: https://sourceforge.net/projects/mpv-player-windows/files/
- Or use package managers: `choco install mpv` or `scoop install mpv`

### **Raspberry Pi:**
- MPV pre-installed on most Pi OS distributions
- If needed: `sudo apt install mpv`

### **Key MPV Advantages:**
- **30-50% more CPU efficient** than VLC on Raspberry Pi
- **Faster startup** (~2.5s vs 5-7s with VLC)
- **Better hardware integration** with Pi GPU
- **More stable** streaming with fewer crashes
- **Cross-platform consistency** (Windows/Pi/Linux)