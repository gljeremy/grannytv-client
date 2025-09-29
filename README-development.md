# VS Code Remote Development Setup

## Option 1: Remote - SSH Extension

1. Install the "Remote - SSH" extension in VS Code
2. Connect to your Raspberry Pi:
   - Press `Ctrl+Shift+P`
   - Type "Remote-SSH: Connect to Host"
   - Enter: `jeremy@raspberrypi.local` (or your Pi's IP)

3. Benefits:
   - Edit files directly on the Pi
   - Run/debug directly in Pi environment
   - Use Pi's file system and environment
   - No deployment step needed

## Option 2: Live Share (for testing)

1. Install "Live Share" extension
2. Start a session and share with yourself
3. Edit on Windows, test on Pi simultaneously

## Setup SSH Key Authentication

On Windows PowerShell:
```powershell
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096

# Copy public key to Pi
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh jeremy@raspberrypi.local "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

On Pi:
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```