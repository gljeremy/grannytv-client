# Windows Development Tools

Scripts for MPV-based IPTV player development and testing on Windows.

## 📄 Files

- **`setup-venv.ps1`** - Creates Python virtual environment on Windows
- **`install-mpv.ps1`** - Installs MPV media player (required for playback)
- **`test-windows.ps1`** - Tests the MPV-based IPTV player locally on Windows

## 🚀 Usage

```powershell
# First time setup
.\platforms\windows\setup-venv.ps1
.\platforms\windows\install-mpv.ps1

# Test the player
.\platforms\windows\test-windows.ps1
```

## 🔧 Requirements

- Windows 10/11
- PowerShell 5.1+  
- Python 3.8+
- **MPV Media Player** (install via script above)
- Git

## 📝 Notes

- MPV is 30-50% more efficient than VLC on all platforms
- The player automatically detects Windows and uses optimized MPV settings
- Hardware acceleration is enabled automatically on Windows (`--hwdec=auto`)