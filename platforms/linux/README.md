# Linux/Raspberry Pi Files

Scripts and service files for MPV-based IPTV player deployment on Raspberry Pi.

## 📄 Files

- **`pi-setup.sh`** - Initial setup script for fresh Pi installation (installs MPV)
- **`pi-update.sh`** - Updates code from Git and manages virtual environment
- **`iptv-player.service`** - Systemd service for auto-start MPV player on boot

## 🚀 Usage

```bash
# Initial setup (run once)
chmod +x platforms/linux/pi-setup.sh
./platforms/linux/pi-setup.sh

# Updates (run after code changes)  
./platforms/linux/pi-update.sh

# Install service for auto-start
sudo cp platforms/linux/iptv-player.service /etc/systemd/system/
sudo systemctl enable iptv-player
sudo systemctl start iptv-player
```

## 🔧 Requirements

- Raspberry Pi OS (Debian-based)
- Python 3.8+
- **MPV Media Player** (installed automatically by setup script)

## 📝 Notes

- MPV provides 30-50% better performance than VLC on Pi hardware
- Setup script automatically configures Pi-specific MPV optimizations
- Service runs with conservative settings optimized for Pi 3/4
- VLC media player
- Git