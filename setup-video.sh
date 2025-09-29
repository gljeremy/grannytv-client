#!/bin/bash
# Configure Raspberry Pi for IPTV video playback
# This script sets up the Pi to display video properly

echo "🔧 Configuring Raspberry Pi for Video Playbook"
echo "=============================================="

# Check current boot behavior
current_boot=$(sudo raspi-config nonint get_boot_behaviour)
echo "📋 Current boot behavior: $current_boot"

echo ""
echo "Choose setup option:"
echo "1) GUI Desktop Auto-login (recommended for TV use)"
echo "2) Console with X11 available (manual startx)"
echo "3) Framebuffer only (no desktop, direct video)"
echo "4) Just fix current setup"
echo ""
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo "🖥️ Setting up Desktop Auto-login..."
        sudo raspi-config nonint do_boot_behaviour B4
        
        # Install desktop if not present
        if ! dpkg -l | grep -q "raspberrypi-ui-mods"; then
            echo "📦 Installing desktop environment..."
            sudo apt update
            sudo apt install -y raspberrypi-ui-mods lightdm
        fi
        
        # Create autostart entry
        mkdir -p ~/.config/autostart
        cat > ~/.config/autostart/iptv-player.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=IPTV Player
Exec=/home/jeremy/gtv/start-iptv-x11.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
        
        echo "✅ Desktop auto-login configured"
        echo "📺 IPTV player will start automatically after reboot"
        ;;
        
    2)
        echo "🖥️ Setting up Console with X11..."
        sudo raspi-config nonint do_boot_behaviour B2
        
        # Install X11 essentials
        sudo apt update
        sudo apt install -y xserver-xorg xinit
        
        # Create .xinitrc
        cat > ~/.xinitrc << 'EOF'
#!/bin/bash
export DISPLAY=:0
unclutter -idle 1 -root &
xsetroot -solid black
cd /home/jeremy/gtv
source venv/bin/activate
exec python iptv_smart_player.py
EOF
        chmod +x ~/.xinitrc
        
        echo "✅ Console with X11 configured"
        echo "💡 Run 'startx' to start the IPTV player"
        ;;
        
    3)
        echo "🖥️ Setting up Framebuffer mode..."
        sudo raspi-config nonint do_boot_behaviour B1
        
        # Configure for framebuffer video
        echo "📺 Configuring framebuffer..."
        
        # Add to .bashrc to auto-start
        if ! grep -q "iptv_smart_player.py" ~/.bashrc; then
            cat >> ~/.bashrc << 'EOF'

# Auto-start IPTV Player (framebuffer mode)
if [ -t 1 ] && [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ]; then
    cd /home/jeremy/gtv
    source venv/bin/activate
    python iptv_smart_player.py
fi
EOF
        fi
        
        echo "✅ Framebuffer mode configured"
        echo "📺 IPTV player will start automatically on tty1"
        ;;
        
    4)
        echo "🔧 Just fixing current setup..."
        ;;
esac

# Common fixes for all modes
echo ""
echo "🔧 Applying common video/audio fixes..."

# Update packages
sudo apt update
sudo apt install -y vlc alsa-utils

# Configure boot config for better video
echo "📺 Updating boot configuration..."

# Backup config
sudo cp /boot/config.txt /boot/config.txt.backup

# Add video optimizations if not present
config_changes=false

if ! grep -q "hdmi_force_hotplug=1" /boot/config.txt; then
    echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt
    config_changes=true
fi

if ! grep -q "hdmi_drive=2" /boot/config.txt; then
    echo "hdmi_drive=2" | sudo tee -a /boot/config.txt
    config_changes=true
fi

if ! grep -q "gpu_mem=256" /boot/config.txt; then
    echo "gpu_mem=256" | sudo tee -a /boot/config.txt
    config_changes=true
fi

# Audio configuration
echo "🔊 Configuring audio..."
sudo amixer cset numid=3 2  # Force HDMI audio
amixer set Master 90% unmute

# Make scripts executable
echo "🔧 Setting up scripts..."
cd /home/jeremy/gtv
chmod +x *.sh

echo ""
echo "✅ Configuration complete!"
echo ""

if [ "$config_changes" = true ]; then
    echo "⚠️  REBOOT REQUIRED for video changes to take effect"
    echo "   sudo reboot"
    echo ""
fi

echo "🧪 Test commands:"
echo "- Test VLC framebuffer: vlc --vout fb --intf dummy [video-url]"
echo "- Test with X11: startx (if option 2)"
echo "- Run diagnostics: ./pi-diagnostics.sh"
echo ""

echo "📺 After reboot:"
case $choice in
    1) echo "- Desktop will start automatically with IPTV player" ;;
    2) echo "- Login and run: startx" ;;
    3) echo "- IPTV player will start automatically on console" ;;
    4) echo "- Try running: ./start-iptv-x11.sh" ;;
esac