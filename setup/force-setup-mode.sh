#!/bin/bash
# Force GrannyTV Setup Mode
# Run this to force the Pi into setup mode immediately

echo "🚨 FORCING GRANNYTV SETUP MODE"
echo "============================="

# Create setup mode flag
echo "🏷️ Creating setup mode flag..."
sudo touch /tmp/grannytv-setup-mode

# Stop all WiFi services immediately
echo "🛑 Stopping all WiFi services..."
sudo systemctl stop NetworkManager 2>/dev/null || true
sudo systemctl stop wpa_supplicant 2>/dev/null || true
sudo systemctl stop dhcpcd 2>/dev/null || true

# Kill any WiFi processes
sudo pkill wpa_supplicant 2>/dev/null || true
sudo pkill dhcpcd 2>/dev/null || true
sudo pkill NetworkManager 2>/dev/null || true

# Clear interface
echo "🔌 Clearing WiFi interface..."
sudo ip addr flush dev wlan0 2>/dev/null || true
sudo ip link set wlan0 down 2>/dev/null || true
sleep 2
sudo ip link set wlan0 up 2>/dev/null || true

# Configure hotspot IP
echo "📡 Setting hotspot IP..."
sudo ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || true

# Start hostapd and dnsmasq
echo "🚀 Starting hotspot services..."
sudo systemctl start hostapd
sleep 3
sudo systemctl start dnsmasq
sleep 2

# Start web server
echo "🌐 Starting setup web server..."
cd /tmp/grannytv-setup/web
sudo python3 setup_server.py &

echo ""
echo "🎉 SETUP MODE FORCED!"
echo "📱 Connect to: GrannyTV-Setup (password: SetupMe123)"
echo "🌐 Browse to: http://192.168.4.1"
echo ""
echo "🛑 To stop: sudo pkill python3 && sudo systemctl stop hostapd dnsmasq"