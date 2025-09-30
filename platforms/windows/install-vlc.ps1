# VLC Installation Script for Windows
# Run this in PowerShell as Administrator

Write-Host "=================================================="
Write-Host "     VLC Media Player Installation for GrannyTV"
Write-Host "=================================================="

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "[INFO] Checking for existing VLC installation..."

# Check if VLC is already installed
$vlcPaths = @(
    "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe",
    "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe"
)

$vlcFound = $false
foreach ($path in $vlcPaths) {
    if (Test-Path $path) {
        Write-Host "[SUCCESS] VLC found at: $path" -ForegroundColor Green
        
        # Test VLC version
        try {
            $version = & "$path" --version 2>&1 | Select-String "VLC version" | Select-Object -First 1
            Write-Host "[INFO] $version" -ForegroundColor Cyan
            $vlcFound = $true
            break
        } catch {
            Write-Host "[WARNING] VLC found but not working properly" -ForegroundColor Yellow
        }
    }
}

if ($vlcFound) {
    Write-Host "[INFO] VLC is already installed and working!" -ForegroundColor Green
    Write-Host "[INFO] You can now run: python iptv_smart_player.py" -ForegroundColor Cyan
    pause
    exit 0
}

Write-Host "[INFO] VLC not found. Installing VLC Media Player..." -ForegroundColor Yellow

# Download VLC installer
$vlcUrl = "https://get.videolan.org/vlc/3.0.18/win64/vlc-3.0.18-win64.exe"
$installerPath = "$env:TEMP\vlc-installer.exe"

Write-Host "[DOWNLOAD] Downloading VLC installer..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $vlcUrl -OutFile $installerPath -UseBasicParsing
    Write-Host "[SUCCESS] Download completed" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to download VLC installer: $($_.Exception.Message)" -ForegroundColor Red
    
    # Fallback: Manual installation instructions
    Write-Host ""
    Write-Host "Manual Installation Instructions:"
    Write-Host "1. Go to https://www.videolan.org/vlc/"
    Write-Host "2. Download VLC for Windows"
    Write-Host "3. Run the installer with default settings"
    Write-Host "4. Then run: python iptv_smart_player.py"
    pause
    exit 1
}

# Install VLC silently
Write-Host "[INSTALL] Installing VLC Media Player..." -ForegroundColor Cyan
try {
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
    Write-Host "[SUCCESS] VLC installation completed" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    pause
    exit 1
}

# Clean up installer
Remove-Item $installerPath -ErrorAction SilentlyContinue

# Verify installation
Write-Host "[VERIFY] Checking VLC installation..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

$vlcInstalled = $false
foreach ($path in $vlcPaths) {
    if (Test-Path $path) {
        Write-Host "[SUCCESS] VLC successfully installed at: $path" -ForegroundColor Green
        
        # Test VLC
        try {
            $version = & "$path" --version 2>&1 | Select-String "VLC version" | Select-Object -First 1
            Write-Host "[INFO] $version" -ForegroundColor Cyan
            $vlcInstalled = $true
            break
        } catch {
            Write-Host "[WARNING] VLC installed but may need system restart" -ForegroundColor Yellow
        }
    }
}

if ($vlcInstalled) {
    Write-Host ""
    Write-Host "=================================================="
    Write-Host "        VLC Installation Complete!" -ForegroundColor Green
    Write-Host "=================================================="
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Open a new PowerShell/Command Prompt"
    Write-Host "2. Navigate to your GrannyTV directory"
    Write-Host "3. Run: python iptv_smart_player.py"
    Write-Host ""
    Write-Host "Your optimized stream database with 84 streams is ready!" -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] VLC installation verification failed" -ForegroundColor Red
    Write-Host "Please restart your computer and try again" -ForegroundColor Yellow
}

pause