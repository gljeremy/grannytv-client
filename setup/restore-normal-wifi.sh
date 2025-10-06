#!/bin/bash
# Restore normal WiFi operation after setup

echo "🔄 Restoring normal WiFi operation..."

# Remove setup mode flag
sudo rm -f /var/lib/grannytv-setup-mode

# Stop any running web servers
sudo pkill -f "python3.*setup_server.py" 2>/dev/null || true

# Disable setup services
sudo systemctl disable grannytv-prepare 2>/dev/null || true
sudo systemctl stop grannytv-prepare 2>/dev/null || true
sudo systemctl disable grannytv-setup 2>/dev/null || true
sudo systemctl stop grannytv-setup 2>/dev/null || true
sudo systemctl disable hostapd 2>/dev/null || true
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true

# Clear WiFi interface
sudo ip addr flush dev wlan0 2>/dev/null || true

# Remove iptables rules
sudo iptables -t nat -F PREROUTING 2>/dev/null || true

# Restore original dhcpcd.conf
if [ -f /etc/dhcpcd.conf.backup ]; then
    sudo cp /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
fi

# Re-enable normal WiFi services
sudo systemctl enable NetworkManager 2>/dev/null || true
sudo systemctl start NetworkManager 2>/dev/null || true
sudo systemctl enable wpa_supplicant 2>/dev/null || true

# Clean up persistent setup files automatically when run non-interactively
if [ -t 0 ]; then
    # Interactive mode - ask user
    read -p "Remove setup files from /opt/grannytv-setup? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -rf /opt/grannytv-setup
        echo "   Setup files removed"
    fi
else
    # Non-interactive mode - remove automatically
    sudo rm -rf /opt/grannytv-setup
    echo "   Setup files removed automatically"
fi

echo "✅ Normal WiFi operation restored"
echo "🔄 Rebooting to apply changes..."
sudo reboot
