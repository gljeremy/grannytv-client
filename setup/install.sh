#!/bin/bash
# GrannyTV Installation Script
# Called automatically after smartphone setup completes

set -e

echo "🎬 GrannyTV Installation Starting..."
echo "===================================="

# Get configuration from setup
CONFIG_FILE="/tmp/grannytv_setup_config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ No configuration found!"
    exit 1
fi

# Parse configuration
USERNAME=$(python3 -c "import json; config=json.load(open('$CONFIG_FILE')); print(config.get('username', 'pi'))")
INSTALL_PATH=$(python3 -c "import json; config=json.load(open('$CONFIG_FILE')); print(config.get('install_path', '/home/pi/gtv'))")
STREAM_SOURCE=$(python3 -c "import json; config=json.load(open('$CONFIG_FILE')); print(config.get('stream_source', ''))")

echo "📋 Configuration:"
echo "   User: $USERNAME"
echo "   Path: $INSTALL_PATH"
echo "   Stream Source: ${STREAM_SOURCE:-'Default'}"

# Switch to target user for installation
echo "👤 Switching to user: $USERNAME"
sudo -u "$USERNAME" bash << EOF
set -e

echo "📁 Creating installation directory..."
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

echo "📥 Cloning GrannyTV repository..."
if [ ! -d ".git" ]; then
    git clone https://github.com/gljeremy/grannytv-client.git .
else
    git pull origin main
fi

echo "🔧 Running main setup script..."
chmod +x setup/pi-setup.sh

# Set environment for the setup script
export SETUP_USER="$USERNAME"
export SETUP_PATH="$INSTALL_PATH"
export SETUP_STREAM_SOURCE="$STREAM_SOURCE"

# Run the Pi setup with our configuration
./setup/pi-setup.sh

echo "✅ Installation complete!"
EOF

# Clean up setup files
echo "🧹 Cleaning up setup files..."
rm -f "$CONFIG_FILE"
sudo systemctl disable grannytv-install
rm -f /etc/systemd/system/grannytv-install.service
rm -f /tmp/grannytv-install.sh

echo ""
echo "🎉 GRANNYTV INSTALLATION COMPLETE!"
echo "=================================="
echo ""
echo "🔄 System will reboot in 10 seconds..."
echo "📺 After reboot, TV will start automatically!"

sleep 10
sudo reboot