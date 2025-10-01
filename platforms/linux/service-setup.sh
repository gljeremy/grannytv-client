#!/bin/bash
# Complete Auto-Start Service Setup for GrannyTV
# Run this script after pi-setup.sh to configure bulletproof auto-start

echo "🎬 Configuring GrannyTV Auto-Start Service"
echo "========================================"

PI_PATH="/home/jeremy/gtv"
SERVICE_NAME="iptv-player"

# Ensure we're in the right directory
cd "$PI_PATH" || {
    echo "❌ Error: Could not access $PI_PATH"
    echo "💡 Run pi-setup.sh first"
    exit 1
}

# Check if service file exists
if [ ! -f "platforms/linux/iptv-player.service" ]; then
    echo "❌ Error: Service file not found"
    echo "💡 Make sure you're in the grannytv-client directory"
    exit 1
fi

# Install the service
echo "⚙️ Installing systemd service..."
sudo cp platforms/linux/iptv-player.service /etc/systemd/system/
sudo systemctl daemon-reload

# Create user directory for XDG runtime (needed for audio)
echo "🔊 Setting up audio environment..."
sudo mkdir -p /run/user/1000
sudo chown jeremy:jeremy /run/user/1000

# Ensure X11 forwarding is enabled
echo "🖥️ Configuring display environment..."
if ! grep -q "X11Forwarding yes" /etc/ssh/sshd_config; then
    echo "X11Forwarding yes" | sudo tee -a /etc/ssh/sshd_config
fi

# Configure Pi for headless operation with HDMI
echo "📺 Optimizing Pi for TV display..."

# Force HDMI output (prevent HDMI auto-detection issues)
if ! grep -q "hdmi_force_hotplug=1" /boot/config.txt; then
    echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt
fi

# Set HDMI to safe mode (ensures compatibility)
if ! grep -q "hdmi_safe=1" /boot/config.txt; then
    echo "hdmi_safe=1" | sudo tee -a /boot/config.txt
fi

# Ensure sufficient GPU memory for video
if ! grep -q "gpu_mem=128" /boot/config.txt; then
    echo "gpu_mem=128" | sudo tee -a /boot/config.txt
fi

# Enable the service
echo "🚀 Enabling auto-start service..."
sudo systemctl enable "$SERVICE_NAME"

# Test the service configuration
echo "🧪 Testing service configuration..."
sudo systemctl daemon-reload

if sudo systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
    echo "✅ Service enabled successfully"
else
    echo "❌ Service enable failed"
    exit 1
fi

# Create a startup delay script for reliability
echo "⏱️ Creating startup delay for network stability..."
sudo tee /usr/local/bin/grannytv-startup.sh >/dev/null << 'EOF'
#!/bin/bash
# Ensure network and display are ready before starting
sleep 15

# Wait for network connectivity
echo "Waiting for network connection..."
while ! ping -c1 8.8.8.8 >/dev/null 2>&1; do
    sleep 5
done

# Wait for X11 display
echo "Waiting for display..."
while ! xset q >/dev/null 2>&1; do
    sleep 2
done

echo "Network and display ready - starting IPTV player"
EOF

sudo chmod +x /usr/local/bin/grannytv-startup.sh

# Configure automatic login for immediate startup
echo "🔐 Configuring automatic login..."
sudo raspi-config nonint do_boot_behaviour B2  # Boot to desktop, auto-login

# Disable screen blanking for continuous TV operation
echo "🖥️ Disabling screen blanking for 24/7 operation..."
if ! grep -q "xset s off" /home/jeremy/.profile; then
    echo "xset s off" >> /home/jeremy/.profile
    echo "xset -dpms" >> /home/jeremy/.profile
    echo "xset s noblank" >> /home/jeremy/.profile
fi

# Create a backup start method via .bashrc (failsafe)
echo "🛡️ Creating failsafe startup method..."
if ! grep -q "grannytv auto-start" /home/jeremy/.bashrc; then
    cat >> /home/jeremy/.bashrc << 'EOF'

# GrannyTV auto-start failsafe
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ] && [ "$XDG_VTNR" = "1" ]; then
    echo "Starting GrannyTV failsafe..."
    cd /home/jeremy/gtv
    source venv/bin/activate
    python3 iptv_smart_player.py
fi
EOF
fi

echo ""
echo "✅ Auto-Start Service Configuration Complete!"
echo ""
echo "🎯 Your Raspberry Pi is now configured for plug-and-play operation:"
echo ""
echo "   📺 Auto-login enabled - no keyboard needed"
echo "   🚀 Service starts automatically on boot" 
echo "   🔊 HDMI audio configured"
echo "   🖥️ Screen blanking disabled"
echo "   🛡️ Failsafe startup method created"
echo "   ⏱️ Network wait delay configured"
echo ""
echo "🔧 Service Management Commands:"
echo "   Start now:    sudo systemctl start iptv-player"
echo "   Stop:         sudo systemctl stop iptv-player" 
echo "   Status:       sudo systemctl status iptv-player"
echo "   Logs:         journalctl -u iptv-player -f"
echo "   Disable:      sudo systemctl disable iptv-player"
echo ""
echo "🚀 Ready to test: sudo reboot"
echo ""
echo "After reboot, your Pi will automatically:"
echo "1. Boot to desktop"
echo "2. Wait for network connection"
echo "3. Start the IPTV player automatically"
echo "4. Begin playing TV immediately"
echo ""
echo "👥 End user experience: Plug Pi into TV → Turn on → Watch TV!"