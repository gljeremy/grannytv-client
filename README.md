# GrannyTV - Simple IPTV Player for Raspberry Pi

**Just plug it in and watch TV!** 📺

Designed for elderly users who want zero-hassle television. The Raspberry Pi automatically finds and plays live TV streams with optimized performance and reliability.

## What It Does

✅ **Plug & Play** - Starts automatically when powered on  
✅ **Smart Stream Selection** - Finds working TV channels automatically  
✅ **Optimized Performance** - Low-latency streaming with hardware acceleration  
✅ **Reliable** - Self-healing with automatic failovers  
✅ **Simple** - No remote controls or complicated menus

## Setup (One-Time)

**For the person setting up the Pi:**

1. **Install on Raspberry Pi:**
```bash
# Get the code
git clone https://github.com/gljeremy/grannytv-client.git
cd grannytv-client

# Install everything
sudo apt update && sudo apt install python3-pip python3-venv vlc -y
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Set up auto-start
chmod +x pi-update.sh vlc-setup.sh
sudo cp iptv-player.service /etc/systemd/system/
sudo systemctl enable iptv-player
sudo systemctl start iptv-player
```

2. **That's it!** The Pi will automatically start playing TV when powered on.

## Performance Optimized ⚡

- **Ultra-low latency**: ~0.8 second delay (vs 3+ seconds typical)
- **Hardware acceleration**: Uses Pi's GPU for smooth video
- **Smart caching**: Minimal buffering for real-time playback  
- **Auto-optimization**: Detects Pi model and adjusts settings

## For Developers 🔧

**Quick updates from Windows:**
```powershell
git add . && git commit -m "Update" && git push
# Then SSH to Pi and run: ./pi-update.sh
```

**Testing:** `python iptv_smart_player.py --test`  
**Logs:** Check `/home/jeremy/gtv/iptv_player.log`

## Documentation (Simple & Updated)

� **[Quick Start](QUICKSTART.md)** - Get TV working in 5 minutes  
⚡ **[Quick Reference](QUICK_REFERENCE.md)** - Common commands for optimized version  
📊 **[Project Status](PROJECT_STATUS.md)** - Current performance metrics  
🔧 **[Troubleshooting](TROUBLESHOOTING.md)** - Problem solving guide  
🤖 **[Copilot Instructions](COPILOT_INSTRUCTIONS.md)** - For AI development assistance  

## How It Works

📁 **`iptv_smart_player.py`** - Main program (VLC-optimized)  
📊 **`working_streams.json`** - 196 tested TV streams  
⚙️ **`config.json`** - Auto-detects Windows vs Pi  
🔄 **`pi-update.sh`** - Easy updates  

## Perfect For

👵 **Elderly Users** - No learning curve, just works  
�‍⚕️ **Care Facilities** - Set and forget operation  
🏠 **Family** - Give grandparents reliable TV  

## License

MIT License - Feel free to use and modify!