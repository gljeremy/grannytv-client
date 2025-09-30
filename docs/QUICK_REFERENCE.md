# GrannyTV Quick Reference - OPTIMIZED VERSION

## 🚀 Common Commands

### Testing & Development
```powershell
# Windows testing
.\test-windows.ps1                   # Test the optimized player

# Pi testing  
python iptv_smart_player.py --test  # Test with performance monitoring
```

### Pi Management
```bash
cd /home/jeremy/gtv
./pi-update.sh                      # Update from GitHub
sudo systemctl restart iptv-player  # Restart optimized service
tail -f iptv_player.log             # View performance logs
```

### Performance Monitoring
```bash
# Check VLC performance
grep "VLC.*started" iptv_player.log     # See successful configs
grep "GPU Memory" iptv_player.log       # Check GPU allocation
grep "Pi Model" iptv_player.log         # Verify Pi detection
```

## 🔧 Troubleshooting (Optimized Version)

| Problem | Solution |
|---------|----------|
| **Video laggy** | Already optimized! (~0.8s latency) ✅ |
| **VLC crashes** | Fixed with stable configs ✅ |
| **No audio** | `sudo amixer cset numid=3 2 && amixer set Master 90% unmute` |
| **Poor performance** | Check GPU memory: `vcgencmd get_mem gpu` (should be ≥64MB) |
| **Service issues** | `sudo systemctl status iptv-player` then `sudo journalctl -u iptv-player` |
| **Stream failures** | Check network: `ping 8.8.8.8` and view logs for stream errors |

## ⚡ Performance Features

✅ **Ultra-low latency**: 800ms network caching  
✅ **Hardware decode**: MMAL acceleration on Pi  
✅ **Smart frame management**: Drops late frames automatically  
✅ **GPU acceleration**: OpenGL rendering when available  
✅ **Progressive fallback**: 3 performance tiers try automatically

## 📁 Key Files

- **`iptv_smart_player.py`** - Main application
- **`working_streams.json`** - Stream database (3000+ streams)
- **`config.json`** - Environment settings
- **`iptv-player.service`** - Auto-start service
- **`git-deploy.ps1`** - Windows deployment script
- **`pi-update.sh`** - Pi update script

## 🎯 Project Goals

- **For Grandma**: Plug-and-play TV experience, zero tech knowledge needed
- **For Jeremy**: Remote maintenance, easy updates, reliable 24/7 operation
- **System**: Raspberry Pi → HDMI TV, auto-start on boot, handle failures gracefully

## 🌐 Remote Access

```bash
ssh jeremy@raspberrypi.local        # SSH to Pi
ssh jeremy@raspberrypi.local "tail -f ~/gtv/iptv_player.log"  # Quick log check
```

## 📊 Diagnostics

```bash
./framebuffer-diagnostics.sh        # Comprehensive video diagnosis
./test-all-players.sh               # Test VLC/MPV/MPlayer
./pi-diagnostics.sh                 # General system check
vcgencmd get_mem gpu                 # Check GPU memory
```