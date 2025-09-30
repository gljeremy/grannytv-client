#!/bin/bash
# GPU optimization script for Raspberry Pi IPTV streaming
# Optimizes GPU memory split and video acceleration settings

echo "🎮 GPU Optimization for IPTV Streaming"
echo "======================================"

# Check if running on Raspberry Pi
if ! command -v vcgencmd >/dev/null 2>&1; then
    echo "❌ This script is designed for Raspberry Pi systems"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root for GPU optimizations"
    echo "   Usage: sudo ./gpu-optimize.sh"
    exit 1
fi

# Backup current config
echo "📋 Backing up current config..."
cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)

# Get current GPU memory
CURRENT_GPU_MEM=$(vcgencmd get_mem gpu | cut -d= -f2 | cut -dM -f1)
echo "   Current GPU memory: ${CURRENT_GPU_MEM}MB"

# Determine optimal GPU memory based on Pi model
PI_MODEL=$(cat /proc/device-tree/model | tr -d '\0')
echo "   Pi Model: $PI_MODEL"

if [[ "$PI_MODEL" == *"Pi 4"* ]]; then
    OPTIMAL_GPU_MEM=256
    echo "   Pi 4 detected - recommending 256MB GPU memory"
elif [[ "$PI_MODEL" == *"Pi 3"* ]]; then
    OPTIMAL_GPU_MEM=128
    echo "   Pi 3 detected - recommending 128MB GPU memory"
else
    OPTIMAL_GPU_MEM=64
    echo "   Older Pi detected - recommending 64MB GPU memory"
fi

# Update GPU memory if needed
if [ "$CURRENT_GPU_MEM" -ne "$OPTIMAL_GPU_MEM" ]; then
    echo "🔧 Updating GPU memory split..."
    
    # Remove existing gpu_mem line
    sed -i '/^gpu_mem=/d' /boot/config.txt
    
    # Add optimized GPU memory
    echo "gpu_mem=$OPTIMAL_GPU_MEM" >> /boot/config.txt
    
    echo "✅ GPU memory updated to ${OPTIMAL_GPU_MEM}MB"
    REBOOT_REQUIRED=true
else
    echo "✅ GPU memory already optimal"
fi

# Add video acceleration optimizations
echo "🔧 Configuring video acceleration..."

# Remove existing video settings
sed -i '/^dtoverlay=vc4-fkms-v3d/d' /boot/config.txt
sed -i '/^dtoverlay=vc4-kms-v3d/d' /boot/config.txt
sed -i '/^gpu_freq=/d' /boot/config.txt
sed -i '/^over_voltage=/d' /boot/config.txt

# Add optimized video settings
cat >> /boot/config.txt << 'EOF'

# Video acceleration optimizations for IPTV streaming
dtoverlay=vc4-fkms-v3d
gpu_freq=500
over_voltage=2

# HDMI optimizations for better video output
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16
config_hdmi_boost=4
EOF

echo "✅ Video acceleration configured"

# Check current temperature and suggest cooling
TEMP=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
echo "📊 Current temperature: ${TEMP}°C"

if (( $(echo "$TEMP > 70" | bc -l) )); then
    echo "⚠️  High temperature detected! Consider:"
    echo "   - Adding heatsinks or fan"
    echo "   - Improving ventilation"
    echo "   - Reducing overclocking"
fi

if [ "$REBOOT_REQUIRED" = true ]; then
    echo ""
    echo "🔄 REBOOT REQUIRED to apply GPU memory changes"
    echo "   Run: sudo reboot"
else
    echo "✅ GPU optimizations complete (no reboot needed)"
fi

echo ""
echo "📈 Performance monitoring commands:"
echo "   vcgencmd measure_temp     # Check temperature"
echo "   vcgencmd get_mem gpu      # Check GPU memory"
echo "   vcgencmd measure_clock gpu # Check GPU frequency"