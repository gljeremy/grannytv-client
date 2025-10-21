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
sudo ip link set wlan0 down 2>/dev/null || true

# Remove iptables rules
sudo iptables -t nat -F PREROUTING 2>/dev/null || true

# Clean up dhcpcd.conf to remove static IP configuration
# This prevents 192.168.4.1 from being set on reboot
if [ -f /etc/dhcpcd.conf ]; then
    echo "🧹 Cleaning dhcpcd.conf..."
    
    # Remove GrannyTV hotspot configuration section (comment line + 3 config lines)
    sudo sed -i '/# GrannyTV Setup Hotspot Configuration/,+3d' /etc/dhcpcd.conf
    echo "   Removed hotspot configuration"
fi

# Decide which network manager to use
if systemctl is-active --quiet NetworkManager; then
    echo "🔄 Using NetworkManager..."
    # Remove hotspot NetworkManager connection profile
    sudo nmcli con delete GrannyTV-Hotspot 2>/dev/null || true
    
    # Stop and disable dhcpcd to avoid conflicts
    sudo systemctl stop dhcpcd 2>/dev/null || true
    sudo systemctl disable dhcpcd 2>/dev/null || true
    
    # Enable NetworkManager
    sudo systemctl enable NetworkManager 2>/dev/null || true
    sudo systemctl restart NetworkManager 2>/dev/null || true
    
    # Bring interface back up and let NetworkManager manage it
    sudo ip link set wlan0 up 2>/dev/null || true
    sudo nmcli device set wlan0 managed yes 2>/dev/null || true
else
    echo "🔄 Using dhcpcd and wpa_supplicant..."
    # Traditional Raspberry Pi network setup
    sudo systemctl enable wpa_supplicant 2>/dev/null || true
    sudo systemctl restart wpa_supplicant 2>/dev/null || true
    sudo systemctl enable dhcpcd 2>/dev/null || true
    sudo systemctl restart dhcpcd 2>/dev/null || true
fi

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
