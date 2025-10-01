#!/bin/bash
# GrannyTV Smartphone Setup Wizard
# Creates WiFi hotspot for smartphone-based configuration

echo "🧙‍♂️ GrannyTV Setup Wizard - Smartphone Configuration"
echo "====================================================="

# Configuration
SETUP_SSID="GrannyTV-Setup"
SETUP_PASSWORD="SetupMe123"
SETUP_IP="192.168.4.1"
CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"              # Repository location (parent of setup/)
SETUP_DIR="$PROJECT_DIR/setup"                      # Setup wizard files
WORK_DIR="/tmp/grannytv-setup"                      # Temporary working directory

# Ensure we're running as regular user, not root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Don't run this script as root!"
    echo "💡 Run as regular user: ./setup/setup-wizard.sh"
    exit 1
fi

echo "🔧 Installing required packages..."
sudo apt update
sudo apt install -y hostapd dnsmasq python3-flask python3-pip git

# Stop conflicting services and unmask hostapd
echo "🛑 Stopping conflicting services..."
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl stop wpa_supplicant 2>/dev/null || true
sudo systemctl unmask hostapd 2>/dev/null || true

# Create temporary working directory
echo "📁 Creating working directory..."
sudo mkdir -p "$WORK_DIR"

# Copy setup files to working directory
echo "📋 Copying setup files..."
if [ -d "$SETUP_DIR" ]; then
    sudo cp -r "$SETUP_DIR"/* "$WORK_DIR/"
    echo "   Setup files copied to: $WORK_DIR"
    
    # Verify critical files were copied
    if [ ! -f "$WORK_DIR/web/setup_server.py" ]; then
        echo "❌ Critical setup files missing after copy!"
        echo "💡 Retrying with explicit permissions..."
        sudo rm -rf "$WORK_DIR"
        sudo mkdir -p "$WORK_DIR"
        sudo cp -r "$SETUP_DIR"/* "$WORK_DIR/"
    fi
    
    # Make scripts executable
    sudo chmod +x "$WORK_DIR/start-setup-wizard.sh" 2>/dev/null || true
    sudo chmod +x "$WORK_DIR/prepare-hotspot.sh" 2>/dev/null || true
    sudo chmod +x "$WORK_DIR/web/setup_server.py" 2>/dev/null || true
    
    # Set proper ownership for systemd service
    sudo chown -R root:root "$WORK_DIR"
    
    # Verify final setup
    if [ -f "$WORK_DIR/web/setup_server.py" ]; then
        echo "   ✅ Setup files verified and ready"
    else
        echo "❌ Setup files verification failed!"
        exit 1
    fi
else
    echo "❌ Setup files not found at: $SETUP_DIR"
    echo "💡 Make sure you're running from the grannytv-client directory"
    exit 1
fi

# Create hostapd configuration
echo "📡 Configuring WiFi hotspot..."
sudo tee /etc/hostapd/hostapd.conf > /dev/null << EOF
interface=wlan0
driver=nl80211
ssid=$SETUP_SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$SETUP_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# Configure dnsmasq for DHCP and captive portal
echo "🌐 Configuring DHCP and captive portal..."
sudo tee /etc/dnsmasq.conf > /dev/null << EOF
# Interface to bind to
interface=wlan0

# DHCP range
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h

# Gateway
dhcp-option=3,$SETUP_IP

# DNS
dhcp-option=6,$SETUP_IP

# Captive portal - redirect all domains to setup page
address=/#/$SETUP_IP

# Don't read /etc/hosts
no-hosts

# Log DHCP requests
log-dhcp
EOF

# Configure static IP for hotspot
echo "🔌 Configuring network interface..."

# Check if dhcpcd.conf exists, if not use NetworkManager approach
if [ -f /etc/dhcpcd.conf ]; then
    # Backup original dhcpcd.conf
    sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
    
    # Add hotspot configuration to dhcpcd.conf
    if ! grep -q "interface wlan0" /etc/dhcpcd.conf; then
        sudo tee -a /etc/dhcpcd.conf > /dev/null << EOF

# GrannyTV Setup Hotspot Configuration
interface wlan0
static ip_address=$SETUP_IP/24
nohook wpa_supplicant
EOF
    fi
else
    # Modern Raspberry Pi OS uses NetworkManager, configure via nmcli
    echo "   Using NetworkManager configuration..."
    sudo nmcli con add type wifi ifname wlan0 con-name GrannyTV-Hotspot autoconnect no ssid $SETUP_SSID 2>/dev/null || true
    sudo nmcli con modify GrannyTV-Hotspot 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method manual ipv4.addr $SETUP_IP/24 2>/dev/null || true
    sudo nmcli con modify GrannyTV-Hotspot wifi-sec.key-mgmt wpa-psk wifi-sec.psk $SETUP_PASSWORD 2>/dev/null || true
fi

# Enable hostapd daemon
echo "⚙️ Configuring hostapd daemon..."
sudo tee /etc/default/hostapd > /dev/null << EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

# Create setup service
echo "🔧 Creating setup service..."
sudo tee /etc/systemd/system/grannytv-setup.service > /dev/null << EOF
[Unit]
Description=GrannyTV Smartphone Setup Wizard
After=grannytv-prepare.service
Requires=grannytv-prepare.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/start-setup-wizard.sh
Restart=on-failure
RestartSec=15
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Install Python dependencies (Flask already installed via apt)
echo "🐍 Python dependencies already installed via apt..."

# Create WiFi preparation service (runs early)
echo "🔧 Creating WiFi preparation service..."
sudo tee /etc/systemd/system/grannytv-prepare.service > /dev/null << EOF
[Unit]
Description=GrannyTV WiFi Hotspot Preparation
DefaultDependencies=false
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=$WORK_DIR/prepare-hotspot.sh
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF

# Create setup mode flag
echo "🏷️ Creating setup mode flag..."
sudo touch /tmp/grannytv-setup-mode

# Enable and start services
echo "🚀 Enabling setup services..."
sudo systemctl daemon-reload
sudo systemctl enable grannytv-prepare
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable grannytv-setup

# Verify setup files are in place for services
echo "🔍 Verifying setup files..."
if [ ! -f "$WORK_DIR/web/setup_server.py" ]; then
    echo "⚠️  Warning: Web server files not found, copying again..."
    sudo cp -r "$SETUP_DIR"/* "$WORK_DIR/"
    sudo chown -R root:root "$WORK_DIR"
    sudo chmod +x "$WORK_DIR"/*.sh "$WORK_DIR/web/setup_server.py" 2>/dev/null || true
fi

if [ -f "$WORK_DIR/web/setup_server.py" ]; then
    echo "   ✅ Setup files verified and ready"
else
    echo "   ❌ Setup files still missing - manual copy may be needed"
fi

# Create restoration script for after setup
echo "🔄 Creating restoration script..."
tee "$SETUP_DIR/restore-normal-wifi.sh" > /dev/null << 'EOF'
#!/bin/bash
# Restore normal WiFi operation after setup

echo "🔄 Restoring normal WiFi operation..."

# Remove setup mode flag
sudo rm -f /tmp/grannytv-setup-mode

# Disable setup services
sudo systemctl disable grannytv-prepare
sudo systemctl stop grannytv-prepare
sudo systemctl disable grannytv-setup
sudo systemctl stop grannytv-setup
sudo systemctl disable hostapd
sudo systemctl stop hostapd
sudo systemctl disable dnsmasq
sudo systemctl stop dnsmasq

# Restore original dhcpcd.conf
if [ -f /etc/dhcpcd.conf.backup ]; then
    sudo cp /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
fi

# Re-enable normal WiFi services
sudo systemctl enable NetworkManager 2>/dev/null || true
sudo systemctl start NetworkManager 2>/dev/null || true
sudo systemctl enable wpa_supplicant 2>/dev/null || true

echo "✅ Normal WiFi operation restored"
echo "🔄 Rebooting to apply changes..."
sudo reboot
EOF

chmod +x "$SETUP_DIR/restore-normal-wifi.sh"

echo ""
echo "🎉 SMARTPHONE SETUP WIZARD READY!"
echo "================================="
echo ""
echo "📱 TO USE THE SETUP WIZARD:"
echo ""
echo "1. 🔌 Connect your Raspberry Pi to TV via HDMI"
echo "2. 🚀 Reboot the Pi: sudo reboot"
echo "3. 📶 On your smartphone, connect to WiFi:"
echo "   Network: '$SETUP_SSID'"
echo "   Password: '$SETUP_PASSWORD'"
echo "4. 🌐 Open web browser on phone"
echo "5. 📱 Browser should automatically redirect to setup page"
echo "6. 📝 Fill out configuration form"
echo "7. 🎬 Pi will configure itself and start playing TV!"
echo ""
echo "🔧 Manual setup URL: http://$SETUP_IP"
echo ""
echo "📋 What the setup will configure:"
echo "   • WiFi connection to your home network"
echo "   • User account and installation path"
echo "   • IPTV stream sources"
echo "   • Auto-start service"
echo "   • Display and audio settings"
echo ""
echo "🚀 Ready to start setup mode:"
echo "   sudo systemctl start grannytv-setup"
echo "   OR"
echo "   sudo reboot"
echo ""
echo "🛠️ To return to normal WiFi later:"
echo "   $SETUP_DIR/restore-normal-wifi.sh"