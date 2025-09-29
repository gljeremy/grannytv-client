# Windows virtual environment setup script
param(
    [switch]$Reset
)

Write-Host "🐍 Setting up Python Virtual Environment" -ForegroundColor Green

if ($Reset -and (Test-Path "venv")) {
    Write-Host "🔄 Removing existing virtual environment..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "venv"
}

# Check if Python is available
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✅ Python found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python not found! Please install Python 3.8+" -ForegroundColor Red
    Write-Host "Download from: https://python.org" -ForegroundColor Yellow
    exit 1
}

# Create virtual environment if it doesn't exist
if (-not (Test-Path "venv")) {
    Write-Host "📦 Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create virtual environment" -ForegroundColor Red
        exit 1
    }
}

# Activate virtual environment
Write-Host "🔧 Activating virtual environment..." -ForegroundColor Yellow
& "venv\Scripts\Activate.ps1"

# Upgrade pip
Write-Host "📦 Upgrading pip..." -ForegroundColor Yellow
python -m pip install --upgrade pip

# Install requirements
if (Test-Path "requirements.txt") {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Dependencies installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Some dependencies may have failed to install" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ No requirements.txt found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Virtual environment setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Usage:" -ForegroundColor Cyan
Write-Host "- Activate: venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host "- Deactivate: deactivate" -ForegroundColor White
Write-Host "- Test locally: python iptv_smart_player.py" -ForegroundColor White
Write-Host "- Deploy to Pi: .\git-deploy.ps1" -ForegroundColor White
Write-Host ""
Write-Host "📝 The virtual environment is now active in this session." -ForegroundColor Green