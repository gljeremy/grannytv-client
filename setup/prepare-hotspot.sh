#!/bin/bash
# GrannyTV WiFi Hotspot Pre-Setup
# Disables regular WiFi before other services start

echo "🔧 GrannyTV: Preparing hotspot mode..."

# Check if we should be in setup mode
if [ ! -f /tmp/grannytv-setup-mode ]; then
    echo "   Not in setup mode, skipping..."
    exit 0
fi

echo "📡 Disabling regular WiFi services..."

# Stop and disable WiFi services that might interfere
systemctl stop wpa_supplicant 2>/dev/null || true
systemctl stop NetworkManager 2>/dev/null || true
systemctl stop dhcpcd 2>/dev/null || true

# Kill any remaining WiFi processes
pkill wpa_supplicant 2>/dev/null || true
pkill dhcpcd 2>/dev/null || true

# Remove any existing WiFi configuration from interface
ip addr flush dev wlan0 2>/dev/null || true
ip link set wlan0 down 2>/dev/null || true
ip link set wlan0 up 2>/dev/null || true

echo "✅ WiFi interface prepared for hotspot"