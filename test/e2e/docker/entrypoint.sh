#!/bin/bash
# Container entrypoint for Pi simulator

set -e

echo "🐳 Starting GrannyTV Pi Simulator..."

# Initialize systemd if needed
if [ "$1" = "systemd" ]; then
    echo "   Starting systemd..."
    exec /sbin/init
fi

# Set up test environment
setup_test_environment() {
    echo "🔧 Setting up test environment..."
    
    # Create mock network interface (if possible in container)
    ip link add wlan0 type dummy 2>/dev/null || echo "Could not create wlan0 (expected in test environment)"
    ip link set wlan0 up 2>/dev/null || echo "Could not bring up wlan0 (expected in test environment)"
    
    # Set permissions
    chown -R jeremy:jeremy /home/jeremy/gtv 2>/dev/null || true
    
    # Create necessary directories
    mkdir -p /var/run/dbus
    mkdir -p /var/lib
    mkdir -p /opt/grannytv-setup
    
    echo "   Test environment ready"
}

# Start dbus (required for systemd services)
start_dbus() {
    echo "🚌 Starting D-Bus..."
    dbus-daemon --system --fork 2>/dev/null || true
}

# If running tests, set up environment
if [ "$1" != "systemd" ]; then
    setup_test_environment
    start_dbus
fi

# Start health check server in background
python3 /usr/local/bin/health_server.py &

# Execute the command
exec "$@"