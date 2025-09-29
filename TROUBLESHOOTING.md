# GrannyTV Troubleshooting Flowchart

## 🚨 Problem: "No video or audio playing"

```
Start Here
    ↓
Is the Pi powered on and connected to TV?
    ↓ NO → Check power cable, HDMI cable, TV input
    ↓ YES
Can you SSH to the Pi?
    ↓ NO → Check network connection, Pi boot issues
    ↓ YES
Is the IPTV service running?
    ↓ Check: sudo systemctl status iptv-player
    ↓ NO → sudo systemctl start iptv-player
    ↓ YES
Check the logs for errors
    ↓ Command: tail -f ~/gtv/iptv_player.log
    ↓
Common Log Messages & Solutions:
```

## 🎥 Video Issues

### "❌ VLC failed to play test stream"
```bash
./fix-framebuffer.sh              # Fix permissions & settings
./framebuffer-diagnostics.sh      # Detailed diagnosis
./test-all-players.sh             # Try alternative players
```

### "🖥️ No X11 detected, using framebuffer output"
```bash
# Option 1: Enable desktop mode
./setup-video.sh  # Choose option 1

# Option 2: Fix framebuffer
./fix-framebuffer.sh
sudo reboot  # If config changes were made
```

### "❌ All video players failed!"
```bash
# Last resort: Use desktop mode
./setup-video.sh
# Choose "1) GUI Desktop Auto-login"
sudo reboot
```

## 🔊 Audio Issues

### "No audio through HDMI"
```bash
# Force HDMI audio
sudo amixer cset numid=3 2

# Set volume
amixer set Master 90% unmute

# Test audio
speaker-test -t sine -f 1000 -l 1
```

### "Audio devices not found"
```bash
# Check available devices
aplay -l

# Install audio tools if missing
sudo apt install alsa-utils
```

## 🔄 Service Issues

### "Service won't start"
```bash
# Check detailed service logs
sudo journalctl -u iptv-player -f

# Common fixes:
sudo systemctl daemon-reload      # If service file changed
chmod +x ~/gtv/iptv_smart_player.py  # If permissions wrong
cd ~/gtv && source venv/bin/activate && python iptv_smart_player.py  # Test manually
```

### "Service starts but stops immediately"
```bash
# Check Python virtual environment
ls -la ~/gtv/venv/

# Recreate if corrupted
cd ~/gtv
rm -rf venv
./pi-update.sh
```

## 🌐 Network/Stream Issues

### "❌ No working streams available"
```bash
# Check internet connection
ping google.com

# Verify streams database
ls -la ~/gtv/working_streams.json
wc -l ~/gtv/working_streams.json  # Should show ~3000 lines

# Manual stream test
vlc --intf dummy [stream-url]
```

## 🔧 System Issues

### "Pi won't boot / No SSH access"
- Check power supply (need 3A+ for Pi 4)
- Check SD card (try re-flashing if corrupted)
- Check network connection
- Try connecting monitor/keyboard directly

### "High CPU usage / System slow"
```bash
# Check running processes
top
htop

# Check disk space
df -h

# Check memory usage
free -h
```

## 📋 Quick Diagnostic Commands

```bash
# System health
./pi-diagnostics.sh

# Video troubleshooting
./framebuffer-diagnostics.sh
./test-all-players.sh

# Service status
sudo systemctl status iptv-player
sudo journalctl -u iptv-player --since "10 minutes ago"

# Manual testing
cd ~/gtv && source venv/bin/activate && python iptv_smart_player.py

# Network test
ping -c 3 google.com
curl -I http://google.com
```

## 🆘 When All Else Fails

1. **Fresh deployment**:
   ```bash
   cd /home/jeremy
   rm -rf gtv
   git clone https://github.com/gljeremy/grannytv-client.git gtv
   cd gtv
   ./pi-update.sh
   ```

2. **Desktop mode** (most reliable):
   ```bash
   ./setup-video.sh  # Choose option 1
   sudo reboot
   ```

3. **Contact developer** with logs:
   ```bash
   # Collect logs
   sudo journalctl -u iptv-player > iptv-service.log
   ./framebuffer-diagnostics.sh > diagnostics.log
   # Send both files to developer
   ```