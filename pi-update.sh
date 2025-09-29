#!/bin/bash
# Auto-deployment script for Raspberry Pi
# Run this script on your Pi to pull latest changes from GitHub

PI_PATH="/home/jeremy/pi"
REPO_URL="https://github.com/YOUR_USERNAME/grannytv-client.git"  # ⚠️  UPDATE THIS!
SERVICE_NAME="iptv-player"
BRANCH="main"

echo "🔄 Updating IPTV Player from GitHub..."

# Create directory if it doesn't exist
mkdir -p "$PI_PATH"
cd "$PI_PATH" || exit 1

# Check if this is a git repository
if [ ! -d ".git" ]; then
    echo "📥 Cloning repository for the first time..."
    git clone "$REPO_URL" .
    if [ $? -ne 0 ]; then
        echo "❌ Failed to clone repository. Check the REPO_URL in this script."
        echo "Current URL: $REPO_URL"
        exit 1
    fi
else
    echo "📥 Pulling latest changes..."
    git fetch origin
    git reset --hard origin/$BRANCH
fi

# Install/update dependencies if needed
if [ -f "requirements.txt" ]; then
    echo "📦 Installing Python dependencies..."
    pip3 install --user -r requirements.txt
fi

# Make scripts executable
chmod +x iptv_smart_player.py
chmod +x pi-update.sh

# Backup current log if it exists
if [ -f "iptv_player.log" ]; then
    mv iptv_player.log "iptv_player.log.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Stop current service/process
echo "� Stopping current player..."
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sudo pkill -f iptv_smart_player.py 2>/dev/null || true
sleep 3

# Start service if systemd service exists, otherwise start manually
if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    echo "🚀 Starting systemd service..."
    sudo systemctl start "$SERVICE_NAME"
    sleep 2
    sudo systemctl status "$SERVICE_NAME" --no-pager -l
else
    echo "🚀 Starting player manually..."
    echo "💡 To install as service: sudo cp iptv-player.service /etc/systemd/system/ && sudo systemctl enable iptv-player"
    nohup python3 iptv_smart_player.py > iptv_player.log 2>&1 &
    echo "Process started in background. Check iptv_player.log for output."
fi

echo ""
echo "✅ Update complete!"
echo "📊 Check logs: tail -f iptv_player.log"
echo "📺 Service status: sudo systemctl status $SERVICE_NAME"