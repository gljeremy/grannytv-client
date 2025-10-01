#!/bin/bash
# GrannyTV Setup Verification and Recovery Script

echo "🔧 GrannyTV Setup Verification"
echo "=============================="

WORK_DIR="/opt/grannytv-setup"
PROJECT_LOCATIONS=(
    "/home/jeremy/gtv/setup"
    "/home/jeremy/grannytv-client/setup"
    "/home/$USER/gtv/setup"
    "/home/$USER/grannytv-client/setup"
)

# Function to find and copy setup files
ensure_setup_files() {
    if [ -d "$WORK_DIR/web" ] && [ -f "$WORK_DIR/web/setup_server.py" ]; then
        echo "✅ Setup files already exist at $WORK_DIR"
        return 0
    fi
    
    echo "📁 Setup files missing, searching for source..."
    
    for location in "${PROJECT_LOCATIONS[@]}"; do
        if [ -d "$location" ]; then
            echo "   Found setup files at: $location"
            echo "   Copying to: $WORK_DIR"
            
            sudo mkdir -p "$WORK_DIR"
            sudo cp -r "$location"/* "$WORK_DIR/"
            sudo chown -R root:root "$WORK_DIR"
            sudo chmod +x "$WORK_DIR"/*.sh "$WORK_DIR/web/setup_server.py" 2>/dev/null || true
            
            if [ -f "$WORK_DIR/web/setup_server.py" ]; then
                echo "✅ Setup files copied successfully"
                return 0
            fi
        fi
    done
    
    echo "❌ Could not find setup files in any of these locations:"
    printf "   %s\n" "${PROJECT_LOCATIONS[@]}"
    return 1
}

# Function to check and fix WiFi interface
check_wifi_interface() {
    echo "📡 Checking WiFi interface..."
    
    if ip addr show wlan0 | grep -q "192.168.4.1"; then
        echo "✅ WiFi interface configured correctly"
        return 0
    else
        echo "⚠️  WiFi interface not configured, fixing..."
        sudo ip link set wlan0 up
        sudo ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || true
        
        if ip addr show wlan0 | grep -q "192.168.4.1"; then
            echo "✅ WiFi interface fixed"
            return 0
        else
            echo "❌ Could not configure WiFi interface"
            return 1
        fi
    fi
}

# Function to check services
check_services() {
    echo "🔧 Checking services..."
    
    services=("hostapd" "dnsmasq")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo "✅ $service is running"
        else
            echo "⚠️  $service is not running, starting..."
            sudo systemctl start "$service"
            
            if systemctl is-active --quiet "$service"; then
                echo "✅ $service started successfully"
            else
                echo "❌ Failed to start $service"
            fi
        fi
    done
}

# Function to check web server
check_web_server() {
    echo "🌐 Checking web server..."
    
    if sudo netstat -tlnp | grep -q ":8080"; then
        echo "✅ Web server is running on port 8080"
        return 0
    else
        echo "⚠️  Web server not running, starting..."
        
        if [ ! -f "$WORK_DIR/web/setup_server.py" ]; then
            echo "❌ Web server files missing"
            return 1
        fi
        
        cd "$WORK_DIR/web"
        sudo python3 setup_server.py &
        sleep 3
        
        if sudo netstat -tlnp | grep -q ":8080"; then
            echo "✅ Web server started successfully"
            return 0
        else
            echo "❌ Failed to start web server"
            return 1
        fi
    fi
}

# Function to add port redirection
setup_port_redirect() {
    echo "🔀 Setting up port redirection..."
    
    if sudo iptables -t nat -L PREROUTING | grep -q "REDIRECT.*8080"; then
        echo "✅ Port redirection already configured"
    else
        sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j REDIRECT --to-port 8080
        echo "✅ Port redirection configured (80 → 8080)"
    fi
}

# Main execution
main() {
    echo ""
    ensure_setup_files || exit 1
    echo ""
    check_wifi_interface || exit 1
    echo ""
    check_services
    echo ""
    check_web_server || exit 1
    echo ""
    setup_port_redirect
    echo ""
    echo "🎉 GrannyTV Setup System Ready!"
    echo "📱 Connect to: GrannyTV-Setup (password: SetupMe123)"
    echo "🌐 Browse to: http://192.168.4.1"
    echo ""
}

# Run main function
main "$@"