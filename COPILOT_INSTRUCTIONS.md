# GrannyTV Project - Copilot Instructions

## 🎯 Project Overview

**GrannyTV** is an optimized IPTV player designed for elderly users on Raspberry Pi. The system is plug-and-play: connect Pi to TV via HDMI and it automatically starts playing live television streams with ultra-low latency (~0.8 seconds).

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
│   └── vlc-setup.sh      # VLC diagnostics & troubleshooting
└── docs/                  # Future documentation (currently minimal)
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
- ✅ **Ultra-low latency**: ~0.8 second delay (from 3+ seconds)
- ✅ **VLC stability**: No more crashes or flickering
- ✅ **Hardware acceleration**: Pi GPU (MMAL) decode working
- ✅ **Smart buffering**: 3-tier performance system (800ms/1000ms/1500ms)
- ✅ **Auto-optimization**: Pi detection, GPU memory checks

### **Architecture Status**
- ✅ **VLC-focused**: Simplified from multi-player to VLC-only approach
- ✅ **Progressive fallback**: Aggressive → Moderate → Conservative settings
- ✅ **Platform detection**: Auto-detects Pi hardware, applies optimizations
- ✅ **Crash prevention**: Comprehensive error handling, restart delays
- ✅ **Service integration**: Systemd auto-start working perfectly

## 🔧 Development Workflow & Preferences

### **Testing Approach**
- **Windows development**: Use `platforms/windows/test-windows.ps1`
- **Pi deployment**: Use `platforms/linux/pi-update.sh` for updates
- **Diagnostics**: Use `tools/vlc-setup.sh` for VLC troubleshooting

### **Code Style Preferences**
- **Simple & readable**: Code for elderly user context (reliability over complexity)
- **Conservative approach**: Stability over aggressive optimization
- **Clear logging**: Performance metrics, error details, Pi hardware info
- **Path references**: Always use the new folder structure in scripts

### **Performance Philosophy**
- **Graduated optimization**: Start conservative, add optimizations incrementally
- **Hardware-aware**: Detect Pi model, GPU memory, adapt settings accordingly
- **Graceful degradation**: Multiple fallback configurations, never completely fail

## 🎬 VLC Optimization Details (Core System)

### **Current VLC Configuration Strategy**

**Tier 1 (Aggressive)**: 800ms caching, hardware decode, frame management  
**Tier 2 (Moderate)**: 1000ms caching, Pi-specific MMAL decode  
**Tier 3 (Conservative)**: 1500ms caching, basic stable settings  

### **Pi-Specific Optimizations**
```bash
--avcodec-hw=mmal           # Pi hardware decode
--mmal-display=hdmi-1       # Direct HDMI output  
--drop-late-frames          # Maintain real-time playback
--skip-frames               # Catch up if behind
--clock-jitter=0            # Reduce A/V sync issues
```

### **Performance Monitoring**
- GPU memory detection (`vcgencmd get_mem gpu`)
- Pi model identification (`/proc/device-tree/model`)  
- Network connectivity testing
- VLC startup monitoring with error capture

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
- VLC performance optimization ✅
- Hardware acceleration ✅  
- Platform detection ✅
- Auto-start service ✅
- Documentation organization ✅

### **Future Enhancement Areas**
- Stream database refresh automation (low priority)
- Additional codec support (AV1) (low priority)
- More diagnostic tools in `tools/` folder (as needed)

## 💡 AI Assistant Guidelines

### **When suggesting changes:**
- **Respect folder structure**: Use `platforms/` and `tools/` organization
- **Maintain stability**: Conservative approach, test gradualism
- **Consider elderly users**: Simplicity and reliability over features
- **Preserve optimizations**: Don't break the current performance achievements
- **Update paths**: Ensure all scripts reference new folder locations

### **Common tasks:**
- **Performance tuning**: Adjust VLC parameters gradually
- **Troubleshooting**: Add tools to `tools/` folder
- **Platform support**: Add scripts to respective `platforms/` folders
- **Documentation**: Keep it simple and practical

This project has evolved from experimental to production-ready. The current state represents an optimized, stable system that successfully delivers on its core promise: plug-and-play television for elderly users with professional-grade performance.