#!/bin/bash
# Test script to verify the WiFi switching fix
# This simulates a complete setup process

echo "🧪 Testing GrannyTV WiFi Setup Fix"
echo "=================================="

# Start fresh container
echo "1. Starting Pi simulator..."
docker-compose up -d pi-simulator

# Wait for container to be ready
echo "2. Waiting for container to start..."
sleep 10

# Test health endpoint
echo "3. Testing health endpoint..."
curl -f http://localhost:9080/health || { echo "❌ Health check failed"; exit 1; }

# Run setup wizard
echo "4. Running setup wizard..."
curl -X POST -H "Content-Type: application/json" \
  -d '{"command": "sudo -u jeremy ./setup/setup-wizard.sh", "user": "root", "timeout": 120}' \
  http://localhost:9080/execute

# Check if setup mode flag exists
echo "5. Checking setup mode flag..."
SETUP_FLAG=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"command": "ls -la /var/lib/grannytv-setup-mode", "user": "root"}' \
  http://localhost:9080/execute | jq -r '.success')

if [ "$SETUP_FLAG" = "true" ]; then
    echo "✅ Setup mode flag exists"
else
    echo "❌ Setup mode flag missing"
fi

# Start the web server
echo "6. Starting web server..."
curl -X POST -H "Content-Type: application/json" \
  -d '{"command": "nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &", "user": "jeremy", "timeout": 5}' \
  http://localhost:9080/execute

sleep 3

# Test web server is running
echo "7. Testing web server..."
curl -f http://localhost:8080/ > /dev/null || { echo "❌ Web server not responding"; exit 1; }
echo "✅ Web server is running"

# Simulate configuration submission
echo "8. Simulating configuration submission..."
curl -X POST -H "Content-Type: application/json" \
  -d '{"wifi_ssid": "TestNetwork", "wifi_password": "testpass123", "username": "jeremy", "install_path": "/home/jeremy/gtv", "stream_source": ""}' \
  http://localhost:8080/configure

# Simulate finalization
echo "9. Simulating finalization..."
curl -X POST http://localhost:8080/finalize

# Wait for cleanup to run
echo "10. Waiting for cleanup to complete..."
sleep 15

# Check if setup mode flag was removed
echo "11. Checking if setup mode flag was removed..."
SETUP_FLAG_AFTER=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"command": "ls -la /var/lib/grannytv-setup-mode", "user": "root"}' \
  http://localhost:9080/execute | jq -r '.success')

if [ "$SETUP_FLAG_AFTER" = "false" ]; then
    echo "✅ Setup mode flag properly removed"
else
    echo "❌ Setup mode flag still exists"
fi

# Check if web server was stopped
echo "12. Checking if web server was stopped..."
WEB_SERVER_RUNNING=$(curl -s http://localhost:8080/ > /dev/null 2>&1 && echo "true" || echo "false")

if [ "$WEB_SERVER_RUNNING" = "false" ]; then
    echo "✅ Web server properly stopped"
else
    echo "⚠️  Web server still running (may be normal during transition)"
fi

echo ""
echo "🎯 Test Summary:"
echo "==============="
echo "Setup Mode Flag Removed: $([ "$SETUP_FLAG_AFTER" = "false" ] && echo "✅ YES" || echo "❌ NO")"
echo "Web Server Stopped: $([ "$WEB_SERVER_RUNNING" = "false" ] && echo "✅ YES" || echo "⚠️  Still Running")"

echo ""
echo "🔧 Additional Debugging Info:"
echo "============================="

# Check what processes are running
echo "Running processes:"
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"command": "ps aux | grep -E \"(hostapd|dnsmasq|setup_server)\"", "user": "root"}' \
  http://localhost:9080/execute | jq -r '.stdout'

# Check network interface
echo "Network interface status:"
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"command": "ip addr show wlan0", "user": "root"}' \
  http://localhost:9080/execute | jq -r '.stdout'

# Check if cleanup script was created
echo "Cleanup script exists:"
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"command": "ls -la /tmp/immediate-cleanup.sh", "user": "root"}' \
  http://localhost:9080/execute | jq -r '.stdout'

echo ""
echo "🧪 Test completed!"