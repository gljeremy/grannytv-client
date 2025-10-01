# 📱 GrannyTV Smartphone Setup System

Complete smartphone-based configuration system for Raspberry Pi IPTV players. No keyboard or mouse required!

## 🎯 Overview

This setup system creates a WiFi hotspot on the Raspberry Pi that allows users to configure the device entirely through their smartphone's web browser. Perfect for non-technical users who just want plug-and-play TV.

## 📁 File Structure

```
setup/
├── setup-wizard.sh              # Main setup wizard script
├── web/                         # Web interface files
│   ├── setup_server.py          # Flask web server
│   └── templates/
│       ├── setup.html           # Mobile-optimized setup interface
│       └── status.html          # Configuration status page
└── README.md                    # This file
```

## 🚀 How It Works

### **Setup Process:**
1. **Pi creates hotspot** → `GrannyTV-Setup` WiFi network
2. **User connects phone** → Network password: `SetupMe123`
3. **Browser auto-opens** → Mobile-friendly setup wizard
4. **User configures** → WiFi, user account, streams, etc.
5. **Pi applies settings** → Automatic installation and reboot
6. **TV starts playing** → Fully configured plug-and-play device

### **Technical Flow:**
1. Pi boots in setup mode with hostapd + dnsmasq
2. Flask web server provides configuration interface
3. Captive portal redirects all traffic to setup page
4. Configuration saved and applied via system scripts
5. Pi switches to normal WiFi mode and runs installation
6. IPTV player starts automatically on next boot

## 📱 User Experience

### **Step 1: Device Detection**
- Auto-detects Pi model, memory, GPU settings
- Shows hardware compatibility information
- Pre-fills recommended settings

### **Step 2: WiFi Configuration**
- Scans and displays available networks
- Shows signal strength and security status
- Supports manual network entry
- Country code selection for compliance

### **Step 3: User Settings**
- Configurable username and install path
- Optional custom stream source URL
- Validates all inputs

### **Step 4: Final Configuration**
- Shows configuration summary
- Applies all settings
- Handles installation and reboot
- Provides completion feedback

## 🔧 Installation & Usage

### **1. Prepare Setup Mode**
```bash
# On the Raspberry Pi
cd /path/to/grannytv-client
chmod +x setup/setup-wizard.sh
./setup/setup-wizard.sh
```

### **2. Enable Setup Mode**
```bash
# Reboot to start in setup mode
sudo reboot
```

### **3. Smartphone Configuration**
1. **Connect to WiFi:** `GrannyTV-Setup` (password: `SetupMe123`)
2. **Open browser** → Should auto-redirect to setup page
3. **Manual URL:** `http://192.168.4.1`
4. **Follow wizard** → Configure all settings
5. **Wait for completion** → Pi installs and reboots automatically

### **4. Normal Operation**
- Pi connects to home WiFi
- Installs IPTV player automatically  
- Starts playing TV on boot
- Setup mode is disabled

## ⚙️ Configuration Options

### **WiFi Settings**
- **Network Name:** Auto-scanned or manual entry
- **Password:** Secure entry with validation
- **Country Code:** Regulatory compliance
- **Security:** Automatic detection

### **User Configuration**
- **Username:** Custom user account creation
- **Install Path:** Configurable installation directory
- **Permissions:** Automatic sudo/video/audio group setup

### **Stream Configuration**
- **Default Streams:** Built-in IPTV channel list
- **Custom Sources:** Optional external stream URL
- **Protocol Support:** HLS, DASH, RTMP, UDP

### **Hardware Optimization**
- **Pi Model Detection:** Automatic performance tuning
- **GPU Memory:** Optimized allocation
- **Display Settings:** HDMI configuration
- **Audio Output:** HDMI audio setup

## 🛠️ Advanced Features

### **Network Management**
- **Captive Portal:** Auto-redirects browsers to setup
- **DHCP Server:** Automatic IP assignment for clients
- **DNS Override:** All domains redirect to setup page
- **Connection Validation:** Tests internet connectivity

### **Error Handling**
- **Input Validation:** Comprehensive form validation
- **Network Testing:** Validates WiFi credentials
- **Hardware Checking:** Ensures Pi compatibility
- **Rollback Support:** Can restore previous configuration

### **Security**
- **Temporary Hotspot:** Setup mode is one-time only
- **Secure Passwords:** WiFi credentials encrypted
- **User Isolation:** Proper Linux user management
- **Service Cleanup:** Removes setup components after use

## 🔍 Troubleshooting

### **Setup Mode Not Starting**
```bash
# Check setup service
sudo systemctl status grannytv-setup

# View logs
journalctl -u grannytv-setup -f

# Manual start
sudo systemctl start grannytv-setup
```

### **WiFi Hotspot Issues**
```bash
# Check hostapd
sudo systemctl status hostapd

# Check dnsmasq
sudo systemctl status dnsmasq

# Restart services
sudo systemctl restart hostapd dnsmasq
```

### **Can't Connect to Setup WiFi**
- **Network Name:** Look for `GrannyTV-Setup`
- **Password:** `SetupMe123` (case sensitive)
- **Range:** Stay close to Raspberry Pi
- **Interference:** Try different location

### **Setup Page Won't Load**
- **Manual URL:** Try `http://192.168.4.1`
- **Browser Cache:** Clear browser cache/data
- **Different Browser:** Try another browser app
- **Network Settings:** Forget and reconnect to WiFi

### **Configuration Fails**
- **WiFi Password:** Double-check password accuracy
- **Network Range:** Ensure Pi can reach home WiFi
- **User Permissions:** Check if username is valid
- **Disk Space:** Ensure sufficient free space

## 🔄 Restore Normal Operation

If you need to exit setup mode manually:
```bash
# Run restoration script
./setup/restore-normal-wifi.sh

# Or manually
sudo systemctl disable grannytv-setup hostapd dnsmasq
sudo systemctl enable wpa_supplicant
sudo reboot
```

## 📋 Technical Requirements

### **Raspberry Pi**
- Pi 3, 4, or 5 (Pi Zero may work but not recommended)
- Raspberry Pi OS (Debian-based)
- Internet connection for installation
- HDMI connection to TV

### **Smartphone/Device**
- Any smartphone with WiFi and web browser
- No special apps required
- Works with iOS, Android, laptops, tablets

### **Network**
- Home WiFi network (WPA/WPA2/WPA3)
- Internet access for stream downloading
- Reasonable signal strength at Pi location

## 🎬 End Result

After successful setup:
- **Plug-and-play operation** for end users
- **Automatic TV startup** within 30 seconds of power-on
- **No technical knowledge required** for daily use
- **Remote management** via SSH for updates
- **Stable, optimized streaming** with MPV player

Perfect for elderly users, care facilities, or anyone who wants zero-hassle television! 📺✨