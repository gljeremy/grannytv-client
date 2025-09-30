# 🚀 Quick Start - Optimized TV Player

## ⚡ What's New in This Version
✅ **Ultra-low latency**: ~0.8 second delay (was 3+ seconds)  
✅ **Hardware acceleration**: Pi GPU decode, no more crashes  
✅ **Smart performance**: 3-tier fallback system automatically optimizes  
✅ **Plug & play**: Just connect to TV and it works  

---

## Step 1: Create GitHub Repository

1. Go to [GitHub.com](https://github.com) and create a new repository
2. Name it: `grannytv-client`
3. Make it public or private (your choice)
4. **Don't** initialize with README (we already have files)

## Step 2: Connect Local Repository to GitHub

```powershell
# Replace YOUR_USERNAME with your actual GitHub username
git remote add origin https://github.com/YOUR_USERNAME/grannytv-client.git
git branch -M main
git push -u origin main
```

## Step 3: Update Configuration Files

1. **Update `pi-update.sh`** - Change line 6:
   ```bash
   REPO_URL="https://github.com/YOUR_USERNAME/grannytv-client.git"
   ```

2. **Update `pi-setup.sh`** - Change the git clone command at the end

3. **Commit the changes:**
   ```powershell
   git add .
   git commit -m "Updated repository URLs"
   git push origin main
   ```

## Step 4: Set Up Raspberry Pi

**Option A: Automatic setup (if Pi has internet):**
```bash
# On Pi terminal:
curl -sSL https://raw.githubusercontent.com/gljeremy/grannytv-client/main/pi-setup.sh | bash
cd /home/jeremy/gtv
git clone https://github.com/gljeremy/grannytv-client.git .
./pi-update.sh  # This will create venv and install dependencies
```

**Option B: Manual setup:**
```bash
# Copy pi-setup.sh to Pi and run:
chmod +x pi-setup.sh
./pi-setup.sh

# Then clone repository:
cd /home/jeremy/gtv
git clone https://github.com/gljeremy/grannytv-client.git .
```

## Step 5: Enable Auto-Start Service

```bash
# On Pi:
sudo cp iptv-player.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable iptv-player
sudo systemctl start iptv-player
```

## Step 6: Test the Workflow

```powershell
# On Windows - make a small change and deploy:
.\git-deploy.ps1 -Message "Testing deployment workflow"
```

## Daily Development Commands

```powershell
# First time setup (creates virtual environment):
.\setup-venv.ps1

# Test locally:
.\test-windows.ps1 -TestMode -Duration 60

# Quick deploy after making changes:
.\git-deploy.ps1

# Deploy with custom commit message:
.\git-deploy.ps1 -Message "Added new feature"

# Just commit and push (no Pi deployment):
.\git-deploy.ps1 -PushOnly

# Just deploy to Pi (no commit/push):
.\git-deploy.ps1 -DeployOnly
```

## Troubleshooting

- **Can't connect to Pi**: Check SSH setup in `README-development.md`
- **Git push fails**: Check if repository URL is correct
- **Service won't start**: Check logs with `sudo systemctl status iptv-player`

## File Structure

```
grannytv-client/
├── iptv_smart_player.py    # Main application
├── working_streams.json    # Stream database  
├── config.json            # Environment config
├── git-deploy.ps1         # Windows deployment script
├── pi-update.sh           # Pi update script
├── pi-setup.sh            # Pi first-time setup
├── iptv-player.service    # Systemd service
└── README.md              # Project documentation
```