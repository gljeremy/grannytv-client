#!/bin/bash
# Quick fix script for common IPTV playback issues on Raspberry Pi

echo "🔧 IPTV Player Quick Fix for Raspberry Pi"
echo "========================================"

# Update package list
echo "📦 Updating package list..."
sudo apt update

# Install essential packages
echo "📦 Installing/updating essential packages..."
sudo apt install -y vlc alsa-utils xserver-xorg xinit

# Configure GPU memory (needs reboot to take effect)
echo "🎨 Checking GPU memory split..."
current_gpu=$(vcgencmd get_mem gpu | cut -d'=' -f2 | cut -d'M' -f1)
if [ "$current_gpu" -lt 128 ]; then
    echo "⚠️  GPU memory too low ($current_gpu MB), setting to 128MB..."
    echo "gpu_mem=128" | sudo tee -a /boot/config.txt
    echo "📋 Reboot required for GPU memory change to take effect"
    needs_reboot=true
fi

# Force HDMI audio
echo "🔊 Configuring audio for HDMI..."
sudo amixer cset numid=3 2 >/dev/null 2>&1
amixer set Master 90% unmute >/dev/null 2>&1

# Enable HDMI in config if needed
echo "📺 Checking HDMI configuration..."
if ! grep -q "hdmi_force_hotplug=1" /boot/config.txt; then
    echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt
    echo "📋 Added HDMI hotplug to config"
    needs_reboot=true
fi

if ! grep -q "hdmi_drive=2" /boot/config.txt; then
    echo "hdmi_drive=2" | sudo tee -a /boot/config.txt
    echo "📋 Added HDMI audio to config"
    needs_reboot=true
fi

# Set display variable
echo "🖥️ Setting up display..."
export DISPLAY=:0
echo "export DISPLAY=:0" >> ~/.bashrc

# Test VLC
echo "🧪 Testing VLC installation..."
if command -v vlc >/dev/null 2>&1; then
    echo "✅ VLC is installed: $(vlc --version | head -1)"
else
    echo "❌ VLC installation failed!"
    exit 1
fi

echo ""
echo "✅ Quick fix complete!"
echo ""

if [ "$needs_reboot" = true ]; then
    echo "⚠️  REBOOT REQUIRED for changes to take effect:"
    echo "   sudo reboot"
    echo ""
fi

echo "🧪 Test commands to run:"
echo "1. Test VLC: ./test-vlc.sh"
echo "2. Run diagnostics: ./pi-diagnostics.sh"
echo "3. Start IPTV player: python3 iptv_smart_player.py"
echo ""
echo "🎯 If you still have issues:"
echo "- Make sure your TV/monitor is on the correct HDMI input"
echo "- Try a different HDMI cable"
echo "- Check if audio works: speaker-test -t sine -f 1000 -l 1"