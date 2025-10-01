# Linux/Raspberry Pi Files

Scripts and service files for MPV-based IPTV player deployment on Raspberry Pi.

## 📄 Files

### Setup Scripts
- **Setup has moved to `/setup/` folder** - See main setup system in `/setup/README.md`
- **`pi-update.sh`** - Updates code from Git and manages virtual environment

### Service Files  
- **`iptv-player.service`** - Enhanced systemd service for reliable auto-start on boot
- **`service-diagnostics.sh`** - Troubleshooting script for service issues

## 🚀 Usage

### **Complete Setup (Smartphone-Based)**
```bash
# NEW: Smartphone setup wizard (recommended)
chmod +x setup/*.sh
./setup/setup-wizard.sh
sudo reboot

# Then use your smartphone to configure via WiFi hotspot
# Pi installs everything automatically after configuration
```

### **Traditional Setup (Without Smartphone)**
```bash
# Traditional one-script setup
chmod +x setup/*.sh
./setup/pi-setup.sh
sudo reboot
```

### **Updates & Maintenance**
```bash
# Update code from Git (automatically restarts service)
./platforms/linux/pi-update.sh

# Troubleshoot service issues
./platforms/linux/service-diagnostics.sh

# Manual service management
sudo systemctl start/stop/restart iptv-player
sudo systemctl status iptv-player
journalctl -u iptv-player -f
```

## 🔧 Requirements

- Raspberry Pi OS (Debian-based)
- Python 3.8+
- **MPV Media Player** (installed automatically by setup script)

## 📝 Notes

- **MPV Performance**: 30-50% better performance than VLC on Pi hardware
- **Auto-Start**: Complete plug-and-play experience - just connect Pi to TV and power on
- **Reliability**: Enhanced service with network wait, display detection, and failsafe startup
- **User Experience**: No keyboard, mouse, or technical knowledge required for end users
- **Maintenance**: Remote updates via Git, comprehensive diagnostics, and service management

## 🎯 End User Experience

**Goal**: Grandma plugs Pi into TV → TV starts playing automatically

1. **Power On**: Pi boots and auto-logs in
2. **Network Wait**: Service waits for internet connection  
3. **Display Ready**: Ensures HDMI output is working
4. **Auto-Start**: IPTV player launches automatically
5. **TV Playing**: Live television starts within 30 seconds of boot

**Zero technical knowledge required for end users!**
- VLC media player
- Git