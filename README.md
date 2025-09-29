# IPTV Smart Player for Raspberry Pi

An IPTV player designed for elderly users - just plug in the Raspberry Pi and watch TV!

## Features

- 🎥 Automatically plays working IPTV streams
- 🔄 Smart stream selection and failover
- 🏠 Designed for non-technical users
- 📺 Full-screen TV experience
- 🔧 Development workflow for Windows to Pi deployment

## Quick Setup for Raspberry Pi

1. Clone this repository:
```bash
git clone https://github.com/gljeremy/grannytv-client.git
cd grannytv-client
```

2. Install dependencies and setup virtual environment:
```bash
sudo apt update
sudo apt install python3-pip python3-venv vlc
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

3. Set up auto-deployment:
```bash
chmod +x pi-update.sh
./pi-update.sh
```

4. Enable auto-start service:
```bash
sudo cp iptv-player.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable iptv-player
sudo systemctl start iptv-player
```

## Development Workflow

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed development setup.

### Quick Deploy from Windows:
```powershell
git add .
git commit -m "Update streams"
git push origin main

# Then on Pi:
./pi-update.sh
```

## Documentation

📖 **[Copilot Instructions](COPILOT_INSTRUCTIONS.md)** - Comprehensive project context for AI assistants  
⚡ **[Quick Reference](QUICK_REFERENCE.md)** - Common commands and quick fixes  
🔧 **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Step-by-step problem solving  
🚀 **[Development Workflow](DEVELOPMENT.md)** - Git-based development process  
📋 **[Quick Start Guide](QUICKSTART.md)** - First-time setup instructions  

## Key Files

- `iptv_smart_player.py` - Main application
- `working_streams.json` - Database of working streams (3000+ tested)
- `config.json` - Environment configuration
- `pi-update.sh` - Auto-update script for Pi
- `iptv-player.service` - Systemd service for auto-start
- `git-deploy.ps1` - Windows deployment script

## Project Goals

🎯 **For Elderly Users**: Plug-and-play TV experience, zero technical knowledge required  
🔧 **For Caregivers**: Remote monitoring, easy updates, reliable 24/7 operation  
🖥️ **System Design**: Raspberry Pi → HDMI TV, auto-start on boot, graceful failure handling  

## License

MIT License - Feel free to use and modify!