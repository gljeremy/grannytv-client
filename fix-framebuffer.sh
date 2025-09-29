#!/bin/bash
# Quick fixes for framebuffer video issues

echo "🔧 Applying Quick Framebuffer Fixes"
echo "==================================="

# 1. Check and fix permissions
echo "1. Checking framebuffer permissions..."
if [ -e /dev/fb0 ]; then
    current_perms=$(ls -l /dev/fb0 | cut -d' ' -f1)
    echo "   /dev/fb0 permissions: $current_perms"
    
    if [ ! -w /dev/fb0 ]; then
        echo "   📝 Adding write permissions..."
        sudo chmod 666 /dev/fb0
    fi
    
    # Add user to video group if not already
    if ! groups | grep -q video; then
        echo "   👤 Adding user to video group..."
        sudo usermod -a -G video $USER
        echo "   ⚠️  You need to log out and back in for group changes to take effect"
    fi
else
    echo "   ❌ /dev/fb0 not found"
fi

# 2. Stop conflicting services
echo ""
echo "2. Stopping conflicting processes..."

# Stop display manager if running
if pgrep -x lightdm >/dev/null; then
    echo "   🛑 Stopping lightdm..."
    sudo systemctl stop lightdm
fi

if pgrep -x gdm3 >/dev/null; then
    echo "   🛑 Stopping gdm3..."
    sudo systemctl stop gdm3
fi

# Kill X11 processes
if pgrep -x Xorg >/dev/null; then
    echo "   🛑 Stopping X11..."
    sudo pkill -f Xorg
fi

# 3. Switch to text console
echo ""
echo "3. Switching to text console..."
sudo chvt 1

# 4. Configure boot settings
echo ""
echo "4. Checking boot configuration..."

boot_config_changed=false

# Ensure adequate GPU memory
gpu_mem=$(vcgencmd get_mem gpu | cut -d'=' -f2 | cut -d'M' -f1)
echo "   Current GPU memory: ${gpu_mem}MB"

if [ "$gpu_mem" -lt 128 ]; then
    echo "   📝 Setting GPU memory to 128MB..."
    if ! grep -q "gpu_mem=128" /boot/config.txt; then
        echo "gpu_mem=128" | sudo tee -a /boot/config.txt
        boot_config_changed=true
    fi
fi

# Ensure framebuffer is enabled
if ! grep -q "framebuffer_width" /boot/config.txt; then
    echo "   📝 Adding framebuffer configuration..."
    cat >> /tmp/fb_config << 'EOF'

# Framebuffer configuration for IPTV
framebuffer_width=1920
framebuffer_height=1080
framebuffer_depth=32
EOF
    sudo tee -a /boot/config.txt < /tmp/fb_config
    rm /tmp/fb_config
    boot_config_changed=true
fi

# 5. Test basic framebuffer access
echo ""
echo "5. Testing basic framebuffer access..."

if [ -w /dev/fb0 ]; then
    echo "   Testing framebuffer write..."
    # Create a simple color pattern (safe test)
    if timeout 2s dd if=/dev/zero of=/dev/fb0 bs=1024 count=1 >/dev/null 2>&1; then
        echo "   ✅ Framebuffer write test successful"
    else
        echo "   ❌ Framebuffer write test failed"
    fi
else
    echo "   ❌ Cannot write to framebuffer"
fi

# 6. Install missing packages
echo ""
echo "6. Ensuring required packages are installed..."

packages_needed=()

if ! command -v vlc >/dev/null 2>&1; then
    packages_needed+=("vlc")
fi

if ! command -v fbset >/dev/null 2>&1; then
    packages_needed+=("fbset")
fi

if [ ${#packages_needed[@]} -gt 0 ]; then
    echo "   📦 Installing: ${packages_needed[*]}"
    sudo apt update
    sudo apt install -y "${packages_needed[@]}"
fi

echo ""
echo "✅ Quick fixes applied!"
echo ""

if [ "$boot_config_changed" = true ]; then
    echo "⚠️  REBOOT REQUIRED for boot configuration changes"
    echo "   sudo reboot"
    echo ""
fi

echo "🧪 Test commands to try now:"
echo "1. Basic VLC test: vlc --intf dummy --vout caca [url]"
echo "2. Framebuffer test: ./test-all-players.sh"
echo "3. Advanced diagnostics: ./framebuffer-diagnostics.sh"
echo ""
echo "🎯 If framebuffer still doesn't work:"
echo "- Try desktop mode: ./setup-video.sh (choose option 1)"
echo "- Use SSH with X forwarding: ssh -X jeremy@pi-ip"
echo "- Consider using VNC for remote desktop access"