# GrannyTV Quick Reference

## 🚀 Daily Commands

### Windows Development
```powershell
.\setup-venv.ps1                    # First time: setup virtual environment
.\test-windows.ps1 -TestMode        # Test locally
.\git-deploy.ps1 -Message "Fix XYZ" # Deploy to Pi
```

### Pi Troubleshooting
```bash
cd /home/jeremy/gtv
./pi-update.sh                      # Update from GitHub
sudo systemctl status iptv-player   # Check service status
sudo systemctl restart iptv-player  # Restart service
tail -f iptv_player.log             # View live logs
```

## 🔧 Common Issues & Fixes

| Problem | Quick Fix |
|---------|-----------|
| No video display | `./fix-framebuffer.sh` then `./test-all-players.sh` |
| No audio | `sudo amixer cset numid=3 2` and `amixer set Master 90% unmute` |
| Service won't start | Check logs: `sudo journalctl -u iptv-player -f` |
| Streams not working | Update streams database or check internet connection |
| Virtual env issues | `rm -rf venv && ./pi-update.sh` to recreate |

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