# MPV Installation Script for Windows Development
# Run this script to install MPV for GrannyTV development

Write-Host "🎬 Installing MPV for GrannyTV Development" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check if Chocolatey is available
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "📦 Installing MPV via Chocolatey..." -ForegroundColor Green
    choco install mpv -y
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ MPV installed successfully via Chocolatey!" -ForegroundColor Green
        Write-Host "🎯 Testing MPV installation..." -ForegroundColor Yellow
        mpv --version
        exit 0
    }
}

# Check if Scoop is available
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "📦 Installing MPV via Scoop..." -ForegroundColor Green
    scoop install mpv
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ MPV installed successfully via Scoop!" -ForegroundColor Green
        Write-Host "🎯 Testing MPV installation..." -ForegroundColor Yellow
        mpv --version
        exit 0
    }
}

# Manual installation instructions
Write-Host "📋 Manual Installation Required" -ForegroundColor Yellow
Write-Host "==============================" -ForegroundColor Yellow
Write-Host ""
Write-Host "No package manager found. Please install MPV manually:" -ForegroundColor White
Write-Host ""
Write-Host "1. Visit: https://sourceforge.net/projects/mpv-player-windows/files/" -ForegroundColor Cyan
Write-Host "2. Download the latest mpv-x86_64-YYYYMMDD-git-XXXXXXX.7z file" -ForegroundColor Cyan
Write-Host "3. Extract to C:\Program Files\mpv\" -ForegroundColor Cyan
Write-Host "4. Add C:\Program Files\mpv\ to your PATH environment variable" -ForegroundColor Cyan
Write-Host ""
Write-Host "Alternative package managers:" -ForegroundColor White
Write-Host "  • Install Chocolatey: https://chocolatey.org/install" -ForegroundColor Gray
Write-Host "  • Install Scoop: https://scoop.sh/" -ForegroundColor Gray
Write-Host ""
Write-Host "After installation, run: mpv --version" -ForegroundColor Green