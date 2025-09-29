# IPTV Player Development Workflow

## Git-Based Development (Recommended)

### Initial Setup

1. **Create GitHub Repository:**
   ```powershell
   # Initialize and push to GitHub
   .\git-deploy.ps1 -SetupRepo
   ```

2. **Set up Raspberry Pi:**
   ```bash
   # On Pi: Run first-time setup
   curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/grannytv-client/main/pi-setup.sh | bash
   
   # Then clone your repository
   cd /home/jeremy/pi
   git clone https://github.com/YOUR_USERNAME/grannytv-client.git .
   ```

### Daily Development Workflow

```powershell
# 1. Make your changes in VS Code on Windows
# 2. Test locally (optional)
.\test-windows.ps1 -TestMode -Duration 60

# 3. Deploy to Pi (commits, pushes, and deploys in one command)
.\git-deploy.ps1 -Message "Fixed stream selection bug"

# 4. Check Pi remotely
ssh jeremy@raspberrypi.local "tail -f ~/pi/iptv_player.log"
```

### Quick Commands

```powershell
# Just push to GitHub (no deploy)
.\git-deploy.ps1 -PushOnly

# Just deploy to Pi (no commit/push)
.\git-deploy.ps1 -DeployOnly

# Full workflow with custom message
.\git-deploy.ps1 -Message "Added new stream categories"
```

## Pi Setup for Auto-Start

1. Copy service file to Pi:
```bash
sudo cp iptv-player.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable iptv-player
sudo systemctl start iptv-player
```

2. Check status:
```bash
sudo systemctl status iptv-player
```

## Development Tips

1. **Always test locally first** using the Windows test script
2. **Use configuration** - the script automatically detects Windows vs Pi
3. **Check logs** - `iptv_player.log` contains all debug info
4. **Stream testing** - verify your `working_streams.json` has good streams

## Environment Variables

- Set `IPTV_ENV=development` to force development mode
- Default: auto-detects based on OS

## Files Overview

- `iptv_smart_player.py` - Main application
- `working_streams.json` - Stream database
- `config.json` - Environment configuration
- `deploy.ps1` - Windows to Pi deployment
- `test-windows.ps1` - Local testing
- `iptv-player.service` - Pi systemd service