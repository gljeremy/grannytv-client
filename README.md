# GrannyTV - Simple IPTV Player for Raspberry Pi

**Jus## 🚀 Quick Commands

```bash
# Windows development
.\platforms\windows\setup-venv.ps1    # Setup environment
.\platforms\windows\test-windows.ps1  # Test locally

# Pi deployment  
./platforms/linux/pi-update.sh        # Update from Git
./tools/setup-ultra-performance.sh    # Apply all optimizations (NEW!)
./tools/vlc-setup.sh                  # Diagnose VLC issues

# Performance monitoring
python3 tools/performance-monitor.py  # Monitor system performance (NEW!)

# Testing
python iptv_smart_player.py --test    # Test with performance monitoring
```it in and watch TV!** 📺

Designed for elderly users who want zero-hassle television. The Raspberry Pi automatically finds and plays live TV streams with optimized performance and reliability.

## What It Does

✅ **Plug & Play** - Starts automatically when powered on  
✅ **Smart Stream Selection** - Finds working TV channels automatically  
✅ **Ultra-Fast Performance** - MPV player optimized for Raspberry Pi 3  
✅ **Reliable** - Self-healing with automatic failovers  
✅ **Simple** - No remote controls or complicated menus  
✅ **Efficient** - 30-40% more efficient than VLC

## Setup (One-Time)

**For the person setting up the Pi:**

1. **Install on Raspberry Pi:**
```bash
# Get the code
git clone https://github.com/gljeremy/grannytv-client.git
cd grannytv-client

# Install everything (including MPV)
sudo apt update && sudo apt install python3-pip python3-venv mpv -y
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Set up auto-start
sudo cp platforms/linux/iptv-player.service /etc/systemd/system/
sudo systemctl enable iptv-player
sudo systemctl start iptv-player
```

2. **That's it!** The Pi will automatically start playing TV when powered on.

## Performance Optimized ⚡

- **Lightning-fast startup**: ~2.5 seconds to video (was 12+ seconds - 80% faster!)
- **Ultra-efficient**: MPV uses 30-40% less CPU than VLC
- **Lower memory**: ~150MB footprint (vs 200MB+ for VLC)
- **Smart caching**: Optimized buffering for Pi 3 hardware
- **Auto-optimization**: Detects Pi model and adjusts settings
- **Rock solid**: Stable playback with no lockups

## For Developers 🔧

**Quick updates from Windows:**
```powershell
git add . && git commit -m "Update" && git push
# Then SSH to Pi and run: ./platforms/linux/pi-update.sh
```

**Testing:** `python iptv_smart_player.py --test`  
**Logs:** Check `/home/jeremy/gtv/iptv_player.log`

## Documentation (Simple & Updated)

� **[Quick Start](QUICKSTART.md)** - Get TV working in 5 minutes  
⚡ **[Quick Reference](QUICK_REFERENCE.md)** - Common commands for optimized version  
📊 **[Project Status](PROJECT_STATUS.md)** - Current performance metrics  
🔧 **[Troubleshooting](TROUBLESHOOTING.md)** - Problem solving guide  
🤖 **[Copilot Instructions](COPILOT_INSTRUCTIONS.md)** - For AI development assistance  

## ⚡ Ultra Performance Mode (NEW!)

**Maximum streaming performance with <1 second latency:**

```bash
# One-command ultra optimization
./tools/setup-ultra-performance.sh

# Individual optimizations
sudo ./tools/network-optimize.sh      # Network tuning
sudo ./tools/gpu-optimize.sh          # GPU acceleration  
python3 tools/performance-monitor.py  # Real-time monitoring
```

**Performance Results:**
- 🚀 **Stream startup:** ~2.5 seconds (was 12+ seconds - 80% faster!)
- ⚡ **CPU usage:** 25-40% during streaming (30-40% less than VLC)
- 💾 **Memory usage:** ~150MB (25% less than VLC)
- 🎯 **MPV player:** Optimized for Raspberry Pi hardware
- 📊 **Smart buffering:** 2-second cache for low latency
- 🔒 **Stability:** Rock solid, no lockups

## 📁 Project Structure

```
grannytv-client/
├── iptv_smart_player.py      # Main application (MPV-optimized)
├── working_streams.json      # 84+ tested TV streams  
├── config.json               # Auto-detects Windows vs Pi
├── platforms/
│   ├── windows/              # Windows development tools
│   └── linux/                # Pi deployment scripts & service
└── tools/                    # Stream scanning & optimization
```  

## Perfect For

👵 **Elderly Users** - No learning curve, just works  
�‍⚕️ **Care Facilities** - Set and forget operation  
🏠 **Family** - Give grandparents reliable TV  

## License

MIT License - Feel free to use and modify!