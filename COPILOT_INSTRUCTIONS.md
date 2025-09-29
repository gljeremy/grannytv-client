# Copilot Instructions for GrannyTV IPTV Player Project

## Project Overview

**GrannyTV IPTV Player** is a Raspberry Pi application designed for elderly users to watch IPTV streams with zero technical knowledge required. The user simply plugs in the Pi and the stream appears on their TV.

### Core Objectives
- **Simplicity**: Plug-and-play experience for non-technical elderly users
- **Reliability**: Automatic stream selection, failover, and recovery
- **Accessibility**: Full-screen TV experience with HDMI audio
- **Maintainability**: Easy remote updates and monitoring for caregiver

## Architecture & Key Components

### Main Application
- **`iptv_smart_player.py`**: Core application with video player management
- **`working_streams.json`**: Database of tested, working IPTV streams
- **`config.json`**: Environment-specific configuration (Windows dev vs Pi production)

### Development Workflow
- **Windows Development**: Edit and test locally, push to GitHub
- **Git-based Deployment**: Automatic pull and restart on Raspberry Pi
- **Virtual Environment**: Isolated Python dependencies for reliability

### Key Directories
- **Windows Dev**: `c:\Users\fivek\source\repos\grannytv-client`
- **Pi Production**: `/home/jeremy/gtv`
- **User**: `jeremy` (Pi username)
- **GitHub**: `gljeremy/grannytv-client`

## Technical Context

### Current Challenges
1. **Video Output Issues**: Pi runs headless, needs framebuffer or X11 for video display
2. **Audio Configuration**: Must force HDMI audio output for TV speakers
3. **Player Compatibility**: VLC works best, with mplayer/mpv fallbacks
4. **Auto-start**: Service must start automatically on Pi boot

### Technology Stack
- **Python 3.x** with virtual environment (`venv/`)
- **VLC** as primary video player (framebuffer or X11 output)
- **ALSA** for audio routing to HDMI
- **Systemd** service for auto-start
- **Git workflow** for deployment

### Configuration System
- **Development Mode**: Auto-detected on Windows, uses local paths
- **Production Mode**: Auto-detected on Pi, uses `/home/jeremy/gtv` paths
- **Environment Variable**: `IPTV_ENV=development` forces dev mode

## File Structure & Key Scripts

### Core Files
```
iptv_smart_player.py     # Main application
working_streams.json     # Stream database (3000+ tested streams)
config.json             # Environment configuration
requirements.txt        # Python dependencies
```

### Deployment Scripts
```
git-deploy.ps1          # Windows: commit, push, deploy to Pi
pi-update.sh            # Pi: pull latest, update venv, restart service
pi-setup.sh             # Pi: first-time system setup
```

### Video/Audio Troubleshooting
```
setup-video.sh          # Interactive Pi video configuration
test-framebuffer.sh     # Test framebuffer video output
framebuffer-diagnostics.sh  # Comprehensive video diagnostics
fix-framebuffer.sh      # Auto-fix common video issues
test-all-players.sh     # Test VLC/MPV/MPlayer with different outputs
```

### Service Management
```
iptv-player.service     # Systemd service definition
start-iptv-x11.sh      # Start with X11 desktop
start-iptv.sh          # Simple startup script
```

## Common Development Tasks

### Local Development Workflow
```powershell
# First time setup
.\setup-venv.ps1

# Daily development
# 1. Edit code in VS Code
# 2. Test locally (optional)
.\test-windows.ps1 -TestMode -Duration 60

# 3. Deploy to Pi
.\git-deploy.ps1 -Message "Description of changes"

# 4. Monitor Pi remotely
ssh jeremy@raspberrypi.local "tail -f ~/gtv/iptv_player.log"
```

### Pi Troubleshooting Sequence
```bash
cd /home/jeremy/gtv
./pi-update.sh                    # Update from git
chmod +x *.sh                     # Ensure scripts executable
./fix-framebuffer.sh              # Fix common video issues
./framebuffer-diagnostics.sh      # Diagnose problems
./test-all-players.sh             # Test video players
sudo systemctl status iptv-player # Check service status
```

## Key Configuration Details

### Audio Setup
- **Force HDMI audio**: `sudo amixer cset numid=3 2`
- **Set volume**: `amixer set Master 90% unmute`
- **Test audio**: `speaker-test -t sine -f 1000 -l 1`

### Video Output Options
1. **X11/Desktop**: Requires `DISPLAY=:0` and running X server
2. **Framebuffer**: Direct video output, works headless
3. **Console Text**: ASCII art video with `--vout caca`

### Boot Configuration (`/boot/config.txt`)
```
gpu_mem=256                    # GPU memory for video
hdmi_force_hotplug=1          # Force HDMI detection
hdmi_drive=2                  # Enable HDMI audio
framebuffer_width=1920        # HD resolution
framebuffer_height=1080
```

## Problem-Solving Guidelines

### When Video Doesn't Work
1. **Check X11**: Is desktop running? (`pgrep Xorg`)
2. **Check Framebuffer**: Can write to `/dev/fb0`?
3. **Check Permissions**: User in `video` group?
4. **Check GPU Memory**: `vcgencmd get_mem gpu` (need 128MB+)
5. **Try Alternative Players**: MPV often works when VLC fails

### When Audio Doesn't Work
1. **List devices**: `aplay -l`
2. **Check routing**: `amixer cget numid=3`
3. **Force HDMI**: `sudo amixer cset numid=3 2`
4. **Check volume**: `amixer get Master`

### When Service Won't Start
1. **Check logs**: `sudo journalctl -u iptv-player -f`
2. **Check virtual env**: `ls -la /home/jeremy/gtv/venv/`
3. **Test manually**: `cd /home/jeremy/gtv && source venv/bin/activate && python iptv_smart_player.py`

## Development Best Practices

### Making Changes
- **Always use virtual environment** for consistent dependencies
- **Test on Windows first** when possible (faster iteration)
- **Use semantic commit messages** for git history
- **Update documentation** when adding new features or scripts

### Code Patterns
- **Environment detection**: Use `CONFIG` global for paths/settings
- **Logging**: Always log important events with emoji prefixes for readability
- **Error handling**: Graceful fallbacks for video/audio failures
- **Process management**: Clean shutdown with signal handlers

### Deployment
- **Never edit files directly on Pi** - always use git workflow
- **Test deployment scripts** on clean Pi setup periodically  
- **Keep backup streams** in case main stream database is corrupted
- **Monitor logs remotely** to catch issues early

## User Experience Goals

### For Elderly User (Jeremy's grandmother)
- **Zero interaction needed**: Pi powers on, stream starts automatically
- **Reliable playback**: Stream should run 24/7 without intervention
- **Good audio/video**: Clear picture and sound through TV HDMI
- **No technical errors**: System should handle all failures gracefully

### For Caregiver (Jeremy)
- **Remote monitoring**: Check logs and status via SSH
- **Easy updates**: Single command deployment of new features
- **Diagnostic tools**: Quick troubleshooting when issues arise
- **Minimal maintenance**: System should be self-healing where possible

## Important Notes

### SSH Access
- **Hostname**: `raspberrypi.local` or `grannytv.local`
- **User**: `jeremy`
- **Key-based auth**: Setup SSH keys for passwordless access
- **Port**: Standard 22

### Stream Database
- **Format**: JSON with stream metadata, test results, and freshness scores
- **Size**: ~3000 tested streams across multiple categories
- **Updates**: Periodically refresh with stream scanner (separate tool)
- **Backup**: Keep working streams as fallback when database unavailable

### Service Management
- **Auto-start**: Enabled via systemd service
- **Restart policy**: Always restart on failure
- **Logs**: Captured in both file and systemd journal
- **Dependencies**: Requires network and audio subsystem

This instruction file should help future Copilot sessions understand the project context, common issues, and development patterns to provide more targeted assistance.