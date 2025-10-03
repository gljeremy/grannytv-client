#!/bin/bash
# Simplified container entrypoint for Pi simulator

set -e

echo "🐳 Starting GrannyTV Pi Simulator (Simple Mode)..."

# Set up test environment
setup_test_environment() {
    echo "🔧 Setting up test environment..."
    
    # Create mock network interface (if possible in container)
    ip link add wlan0 type dummy 2>/dev/null || echo "Could not create wlan0 (expected in test environment)"
    ip link set wlan0 up 2>/dev/null || echo "Could not bring up wlan0 (expected in test environment)"
    
    # Set permissions
    chown -R jeremy:jeremy /home/jeremy/gtv 2>/dev/null || true
    
    # Create necessary directories
    mkdir -p /var/lib
    mkdir -p /opt/grannytv-setup
    
    echo "   Test environment ready"
}

# Start health check server in background
start_health_server() {
    echo "🏥 Starting health check server..."
    python3 /usr/local/bin/health_server.py &
    HEALTH_PID=$!
    echo "   Health server started (PID: $HEALTH_PID)"
}

# Mock systemctl command for testing
setup_mock_systemctl() {
    echo "🎭 Setting up mock systemctl..."
    
    # Create a simple mock systemctl script
    cat > /usr/local/bin/systemctl << 'EOF'
#!/bin/bash
# Mock systemctl for testing

COMMAND="$1"
SERVICE="$2"

case "$COMMAND" in
    "enable"|"disable"|"start"|"stop"|"restart")
        echo "Mock systemctl: $COMMAND $SERVICE"
        # Create service state files for better testing
        mkdir -p /tmp/systemctl-mock
        case "$COMMAND" in
            "enable")
                touch "/tmp/systemctl-mock/$SERVICE.enabled"
                ;;
            "disable")
                rm -f "/tmp/systemctl-mock/$SERVICE.enabled"
                ;;
            "start")
                touch "/tmp/systemctl-mock/$SERVICE.running"
                ;;
            "stop")
                rm -f "/tmp/systemctl-mock/$SERVICE.running"
                ;;
        esac
        exit 0
        ;;
    "is-enabled"|"is-active")
        if [ -f "/tmp/systemctl-mock/$SERVICE.enabled" ] || [ -f "/tmp/systemctl-mock/$SERVICE.running" ]; then
            echo "enabled"
            exit 0
        else
            echo "disabled"
            exit 1
        fi
        ;;
    "daemon-reload")
        echo "Mock systemctl: daemon-reload"
        exit 0
        ;;
    "status")
        echo "● $SERVICE - Mock service"
        echo "   Loaded: loaded (/etc/systemd/system/$SERVICE.service; enabled)"
        if [ -f "/tmp/systemctl-mock/$SERVICE.running" ]; then
            echo "   Active: active (running)"
        else
            echo "   Active: inactive (dead)"
        fi
        exit 0
        ;;
    "list-unit-files")
        if [[ "$*" == *"grannytv"* ]]; then
            echo "grannytv-setup.service enabled"
            echo "grannytv-prepare.service enabled"
        else
            echo "hostapd.service enabled"
            echo "dnsmasq.service enabled" 
            echo "grannytv-setup.service enabled"
            echo "grannytv-prepare.service enabled"
        fi
        exit 0
        ;;
    "show")
        # Handle systemctl show commands
        PROPERTY="$3"
        case "$PROPERTY" in
            "--property=After")
                echo "After=grannytv-prepare.service network.target"
                ;;
            "--property=Restart")
                echo "Restart=on-failure"
                ;;
            *)
                echo "Mock systemctl show: $SERVICE $PROPERTY"
                ;;
        esac
        exit 0
        ;;
    "unmask")
        echo "Mock systemctl: unmask $SERVICE"
        exit 0
        ;;
    *)
        echo "Mock systemctl: unknown command $COMMAND"
        exit 0
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/systemctl
    
    # Create mock journalctl
    cat > /usr/local/bin/journalctl << 'EOF'
#!/bin/bash
# Mock journalctl for testing
echo "Mock logs for service: $*"
echo "-- Logs begin at $(date) --"
echo "Mock log entry 1"
echo "Mock log entry 2"
exit 0
EOF
    chmod +x /usr/local/bin/journalctl
    
    echo "   Mock systemctl and journalctl ready"
}

# Main setup
setup_test_environment
setup_mock_systemctl
start_health_server

echo "✅ GrannyTV Pi Simulator ready for testing"

# Keep container running
if [ $# -eq 0 ]; then
    # No command provided, keep container alive
    echo "📋 Keeping container alive..."
    while true; do
        sleep 30
        echo "🔄 Container heartbeat - $(date)"
    done
elif [ "$1" = "bash" ]; then
    exec bash
else
    exec "$@"
fi