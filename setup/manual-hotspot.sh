#!/bin/bash
# Manual GrannyTV Hotspot Activation
# Use this if the automatic setup isn't working

echo "🔧 Manual Hotspot Activation"
echo "============================"

# Unmask and stop services
echo "📡 Preparing services..."
sudo systemctl unmask hostapd
sudo systemctl stop hostapd dnsmasq wpa_supplicant NetworkManager

# Start hostapd manually
echo "🚀 Starting hotspot..."
if [ -f /etc/hostapd/hostapd.conf ]; then
    sudo hostapd /etc/hostapd/hostapd.conf &
    HOSTAPD_PID=$!
    echo "   hostapd started with PID: $HOSTAPD_PID"
else
    echo "❌ hostapd config not found"
    exit 1
fi

# Configure interface manually
echo "🔌 Configuring interface..."
sudo ip addr add 192.168.4.1/24 dev wlan0
sudo ip link set wlan0 up

# Start dnsmasq
echo "🌐 Starting DHCP..."
if [ -f /etc/dnsmasq.conf ]; then
    sudo dnsmasq
    echo "   dnsmasq started"
else
    echo "❌ dnsmasq config not found"
fi

# Start Flask server
echo "🖥️ Starting web server..."
cd /tmp/grannytv-setup/web
python3 setup_server.py &
FLASK_PID=$!
echo "   Flask server started with PID: $FLASK_PID"

echo ""
echo "✅ Manual hotspot activated!"
echo "📱 Connect to: GrannyTV-Setup (password: SetupMe123)"
echo "🌐 Browse to: http://192.168.4.1"
echo ""
echo "🛑 To stop:"
echo "   kill $HOSTAPD_PID $FLASK_PID"
echo "   sudo pkill dnsmasq"
echo "   sudo systemctl start NetworkManager"