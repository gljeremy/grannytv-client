#!/bin/bash
# GrannyTV Setup Service Startup Script
# Properly configures WiFi interface for hotspot mode

echo "🚀 Starting GrannyTV Setup Wizard..."

# Configuration
SETUP_IP="192.168.4.1"
WORK_DIR="/tmp/grannytv-setup"

# Function to check if interface has IP
has_setup_ip() {
    ip addr show wlan0 | grep -q "$SETUP_IP"
}

# Function to disconnect from regular WiFi
disconnect_wifi() {
    echo "📡 Disconnecting from regular WiFi..."
    
    # Try NetworkManager first
    if command -v nmcli >/dev/null 2>&1; then
        # Get current WiFi connection
        CURRENT_WIFI=$(nmcli -t -f ACTIVE,NAME con show | grep '^yes:' | cut -d: -f2)
        if [ ! -z "$CURRENT_WIFI" ]; then
            echo "   Disconnecting from: $CURRENT_WIFI"
            nmcli con down "$CURRENT_WIFI" 2>/dev/null || true
        fi
        
        # Stop NetworkManager to prevent interference
        systemctl stop NetworkManager 2>/dev/null || true
    fi
    
    # Stop wpa_supplicant
    systemctl stop wpa_supplicant 2>/dev/null || true
    pkill wpa_supplicant 2>/dev/null || true
    
    # Clear IP from interface
    ip addr flush dev wlan0 2>/dev/null || true
}

# Function to configure hotspot IP
configure_hotspot_ip() {
    echo "🔌 Configuring hotspot IP..."
    ip addr add $SETUP_IP/24 dev wlan0 2>/dev/null || true
    ip link set wlan0 up
}

# Function to start services
start_services() {
    echo "🔧 Starting hotspot services..."
    
    # Start hostapd
    systemctl start hostapd
    sleep 2
    
    # Start dnsmasq
    systemctl start dnsmasq
    sleep 2
    
    # Verify hostapd is running and AP is enabled
    if ! systemctl is-active --quiet hostapd; then
        echo "❌ hostapd failed to start"
        return 1
    fi
    
    # Check if AP is enabled
    if ! journalctl -u hostapd --since "30 seconds ago" | grep -q "AP-ENABLED"; then
        echo "❌ Access Point not enabled"
        return 1
    fi
    
    echo "✅ Hotspot services started"
    return 0
}

# Function to start web server
start_web_server() {
    echo "🌐 Starting web server..."
    
    # Verify web files exist
    if [ ! -f "$WORK_DIR/web/setup_server.py" ]; then
        echo "❌ Web server files not found at $WORK_DIR/web/"
        echo "💡 Copying setup files..."
        
        # Emergency file copy
        if [ -d "/home/jeremy/gtv/setup" ]; then
            cp -r /home/jeremy/gtv/setup/* "$WORK_DIR/"
            chmod +x "$WORK_DIR/web/setup_server.py"
        else
            echo "❌ Cannot find setup files to copy"
            return 1
        fi
    fi
    
    # Set up port redirection (80 -> 8080) for captive portal
    iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j REDIRECT --to-port 8080 2>/dev/null || true
    
    cd "$WORK_DIR/web"
    python3 setup_server.py &
    WEB_PID=$!
    
    # Wait a moment and check if it's still running
    sleep 3
    if kill -0 $WEB_PID 2>/dev/null; then
        echo "✅ Web server started (PID: $WEB_PID)"
        echo "$WEB_PID" > /tmp/grannytv-web.pid
        return 0
    else
        echo "❌ Web server failed to start"
        # Try to show the error
        wait $WEB_PID
        return 1
    fi
}

# Main execution
main() {
    # Check if we already have the setup IP configured
    if has_setup_ip; then
        echo "📶 Setup IP already configured"
    else
        # Disconnect from regular WiFi and configure hotspot
        disconnect_wifi
        sleep 2
        configure_hotspot_ip
        sleep 2
    fi
    
    # Start hotspot services
    if ! start_services; then
        echo "❌ Failed to start hotspot services"
        exit 1
    fi
    
    # Start web server
    if ! start_web_server; then
        echo "❌ Failed to start web server"
        exit 1
    fi
    
    echo "🎉 GrannyTV Setup Wizard is ready!"
    echo "📱 Connect to WiFi: GrannyTV-Setup (password: SetupMe123)"
    echo "🌐 Browse to: http://192.168.4.1:8080"
    
    # Keep the script running
    wait
}

# Run main function
main "$@"