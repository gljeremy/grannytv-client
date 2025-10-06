#!/bin/bash
# GrannyTV Hotspot Diagnostic Script

echo "🔍 GrannyTV Hotspot Diagnostics"
echo "==============================="
echo ""

echo "📡 WiFi Interface Status:"
ip link show wlan0 || echo "❌ wlan0 interface not found"
echo ""

echo "🔧 Service Status:"
echo "- hostapd:"
sudo systemctl is-active hostapd || echo "  Not active"
sudo systemctl is-enabled hostapd || echo "  Not enabled"

echo "- dnsmasq:"
sudo systemctl is-active dnsmasq || echo "  Not active"
sudo systemctl is-enabled dnsmasq || echo "  Not enabled"

echo "- grannytv-setup:"
sudo systemctl is-active grannytv-setup || echo "  Not active"
sudo systemctl is-enabled grannytv-setup || echo "  Not enabled"
echo ""

echo "📝 Configuration Files:"
echo "- hostapd config:"
if [ -f /etc/hostapd/hostapd.conf ]; then
    echo "  ✅ /etc/hostapd/hostapd.conf exists"
    echo "  SSID: $(grep '^ssid=' /etc/hostapd/hostapd.conf | cut -d'=' -f2)"
else
    echo "  ❌ /etc/hostapd/hostapd.conf missing"
fi

echo "- dnsmasq config:"
if [ -f /etc/dnsmasq.conf ]; then
    echo "  ✅ /etc/dnsmasq.conf exists"
else
    echo "  ❌ /etc/dnsmasq.conf missing"
fi
echo ""

echo "🌐 Network Configuration:"
echo "- IP address on wlan0:"
ip addr show wlan0 | grep "inet " || echo "  No IP assigned"

echo "- NetworkManager status:"
if command -v nmcli >/dev/null 2>&1; then
    echo "  NetworkManager available"
    nmcli con show | grep -i grannytv || echo "  No GrannyTV connection found"
else
    echo "  NetworkManager not available"
fi

echo "- dhcpcd status:"
if [ -f /etc/dhcpcd.conf ]; then
    echo "  ✅ dhcpcd.conf exists"
else
    echo "  ❌ dhcpcd.conf missing (using NetworkManager)"
fi
echo ""

echo "📋 Service Logs (last 10 lines):"
echo "- hostapd logs:"
sudo journalctl -u hostapd --lines=5 --no-pager || echo "  No logs available"

echo "- dnsmasq logs:"
sudo journalctl -u dnsmasq --lines=5 --no-pager || echo "  No logs available"

echo "- grannytv-setup logs:"
sudo journalctl -u grannytv-setup --lines=5 --no-pager || echo "  No logs available"
echo ""

echo "🔧 Quick Fixes:"
echo "To manually start the hotspot:"
echo "  sudo systemctl start grannytv-setup"
echo ""
echo "To check detailed service logs:"
echo "  sudo journalctl -u hostapd -f"
echo "  sudo journalctl -u dnsmasq -f"
echo "  sudo journalctl -u grannytv-setup -f"