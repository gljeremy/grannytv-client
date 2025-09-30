#!/bin/bash
# Network optimization script for IPTV streaming
# This script optimizes network settings for minimum latency

echo "🌐 Network Optimization for IPTV Streaming"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root for network optimizations"
    echo "   Usage: sudo ./network-optimize.sh"
    exit 1
fi

# Backup current settings
echo "📋 Backing up current network settings..."
sysctl -a | grep -E "(net\.core|net\.ipv4)" > /tmp/network_backup_$(date +%Y%m%d_%H%M%S).txt

# TCP optimizations for streaming
echo "🔧 Applying TCP optimizations..."

# Increase network buffer sizes for high-throughput streaming
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.wmem_max=134217728
sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144

# TCP buffer auto-tuning
sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728"
sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"

# Reduce TCP latency
sysctl -w net.ipv4.tcp_low_latency=1
sysctl -w net.ipv4.tcp_no_delay_ack=1

# Optimize congestion control for streaming
sysctl -w net.ipv4.tcp_congestion_control=bbr

# Reduce network timeouts
sysctl -w net.ipv4.tcp_keepalive_time=600
sysctl -w net.ipv4.tcp_keepalive_intvl=60
sysctl -w net.ipv4.tcp_keepalive_probes=3

# Optimize network queue
sysctl -w net.core.netdev_max_backlog=5000

echo "✅ Network optimizations applied"
echo "   Note: These settings are temporary. To make permanent,"
echo "   add them to /etc/sysctl.conf"

# Test network performance
echo "🧪 Testing network performance..."
if command -v iperf3 >/dev/null 2>&1; then
    echo "   iperf3 available for network testing"
else
    echo "   Install iperf3 for network performance testing:"
    echo "   sudo apt install iperf3"
fi

echo "🏁 Network optimization complete!"