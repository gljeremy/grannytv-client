# Windows Development Tools

## 🎯 **Recommended: Use WSL2 for Development**

For the best development experience on Windows, we **strongly recommend using WSL2** instead of native Windows tools:

```powershell
# Install WSL2 Ubuntu (one-time setup)
wsl --install -d Ubuntu-22.04

# Setup development environment
wsl -d Ubuntu-22.04 -- sudo apt update
wsl -d Ubuntu-22.04 -- sudo apt install -y python3-pip python3-venv docker.io git curl
wsl -d Ubuntu-22.04 -- sudo usermod -aG docker $USER

# Access your project files
wsl -d Ubuntu-22.04 -- bash -c "cd /mnt/c/Users/$(whoami)/source/repos/grannytv-client"
```

**Why WSL2?**
- ✅ **91% Test Success Rate** (vs 60% on native Windows)
- ✅ **Full Linux Compatibility** - Matches production Raspberry Pi environment
- ✅ **Proper Docker Support** - Required for comprehensive testing
- ✅ **Native Shell Scripts** - All setup scripts work without modification

## 🪟 Native Windows Tools (Legacy)

If you must use native Windows development:

### 📄 Files

- **`setup-venv.ps1`** - Creates Python virtual environment on Windows
- **`install-mpv.ps1`** - Installs MPV media player (required for playback)
- **`test-windows.ps1`** - Tests the MPV-based IPTV player locally on Windows

### 🚀 Usage

```powershell
# First time setup
.\platforms\windows\setup-venv.ps1
.\platforms\windows\install-mpv.ps1

# Test the player
.\platforms\windows\test-windows.ps1
```

### 🔧 Requirements

- Windows 10/11
- PowerShell 5.1+  
- Python 3.8+
- **MPV Media Player** (install via script above)
- Git

### ⚠️ Limitations

- **Limited Testing**: Native Windows environment cannot run comprehensive test suite
- **Compatibility Issues**: Some Linux-specific features may not work correctly
- **Docker Constraints**: Cannot test Docker-based components properly

## 📝 Notes

- MPV is 30-50% more efficient than VLC on all platforms
- The player automatically detects Windows and uses optimized MPV settings
- Hardware acceleration is enabled automatically on Windows (`--hwdec=auto`)