# Git workflow script for Windows development
param(
    [string]$Message = "Update IPTV player",
    [string]$PiHost = "raspberrypi.local",
    [string]$PiUser = "jeremy",
    [switch]$PushOnly,
    [switch]$DeployOnly,
    [switch]$SetupRepo
)

function Write-Step {
    param([string]$Message, [string]$Color = "Green")
    Write-Host "🔧 $Message" -ForegroundColor $Color
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

if ($SetupRepo) {
    Write-Step "Setting up GitHub repository..."
    
    # Initialize git if not already done
    if (-not (Test-Path ".git")) {
        git init
        Write-Step "Git repository initialized"
    }
    
    # Add all files
    git add .
    git commit -m "Initial commit: IPTV Smart Player"
    
    Write-Host ""
    Write-Host "🌐 Next steps:" -ForegroundColor Yellow
    Write-Host "1. Create a new repository on GitHub.com"
    Write-Host "2. Copy the repository URL"
    Write-Host "3. Run these commands:" -ForegroundColor Cyan
    Write-Host "   git remote add origin https://github.com/YOUR_USERNAME/grannytv-client.git"
    Write-Host "   git branch -M main"
    Write-Host "   git push -u origin main"
    Write-Host ""
    Write-Host "4. Update the REPO_URL in pi-update.sh with your GitHub URL"
    Write-Host "5. Then run: .\git-deploy.ps1 -DeployOnly"
    
    exit 0
}

if (-not $DeployOnly) {
    Write-Step "Checking Git status..."
    
    # Check if we're in a git repository
    $gitStatus = git status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not a Git repository. Run with -SetupRepo first."
        exit 1
    }
    
    # Check for changes
    if ([string]::IsNullOrWhiteSpace($gitStatus)) {
        Write-Host "📝 No changes to commit" -ForegroundColor Yellow
    } else {
        Write-Step "Adding and committing changes..."
        git add .
        git commit -m "$Message"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Changes committed"
        } else {
            Write-Error "Failed to commit changes"
            exit 1
        }
    }
    
    if (-not $PushOnly) {
        Write-Step "Pushing to GitHub..."
        git push origin main
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Pushed to GitHub"
        } else {
            Write-Error "Failed to push to GitHub"
            exit 1
        }
    }
}

if (-not $PushOnly) {
    Write-Step "Deploying to Raspberry Pi..."
    
    # Test SSH connection
    $sshTest = ssh -o ConnectTimeout=5 -o BatchMode=yes "${PiUser}@${PiHost}" "echo 'SSH OK'" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cannot connect to Pi at ${PiUser}@${PiHost}"
        Write-Host "💡 Make sure:" -ForegroundColor Yellow
        Write-Host "   - Pi is powered on and connected to network"
        Write-Host "   - SSH is enabled on Pi"
        Write-Host "   - Correct hostname/IP address"
        Write-Host "   - SSH keys are set up (see README-development.md)"
        exit 1
    }
    
    # Run update script on Pi
    Write-Step "Running update script on Pi..."
    ssh "${PiUser}@${PiHost}" "cd /home/jeremy/pi && ./pi-update.sh"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Deployment complete!"
        Write-Host ""
        Write-Host "🎯 Useful commands:" -ForegroundColor Cyan
        Write-Host "   Check logs: ssh ${PiUser}@${PiHost} 'tail -f ~/pi/iptv_player.log'"
        Write-Host "   Check status: ssh ${PiUser}@${PiHost} 'sudo systemctl status iptv-player'"
        Write-Host "   Restart: ssh ${PiUser}@${PiHost} 'sudo systemctl restart iptv-player'"
    } else {
        Write-Error "Deployment failed"
        exit 1
    }
}

Write-Success "All done! 🚀"