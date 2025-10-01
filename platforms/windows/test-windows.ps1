# Windows test script for MPV-based IPTV Player
param(
    [switch]$TestMode,
    [int]$Duration = 30
)

Write-Host "🧪 Testing MPV-based IPTV Player on Windows..." -ForegroundColor Green

# Check if MPV is installed
try {
    $mpvVersion = & mpv --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ MPV found: $($mpvVersion.Split("`n")[0])" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ MPV not found!" -ForegroundColor Red
    Write-Host "💡 Run: .\install-mpv.ps1" -ForegroundColor Yellow
    exit 1
}

# Check if virtual environment exists
if (-not (Test-Path "venv\Scripts\python.exe")) {
    Write-Host "❌ Virtual environment not found!" -ForegroundColor Red
    Write-Host "💡 Run: .\setup-venv.ps1" -ForegroundColor Yellow
    exit 1
}

# Activate virtual environment
Write-Host "🐍 Activating virtual environment..." -ForegroundColor Yellow
& "venv\Scripts\Activate.ps1"

# Set environment for development
$env:IPTV_ENV = "development"

if ($TestMode) {
    Write-Host "⏱️ Running in test mode for $Duration seconds..." -ForegroundColor Yellow
    
    # Start the player in background
    $job = Start-Job -ScriptBlock {
        param($scriptPath, $venvPath)
        & "$venvPath\Scripts\python.exe" $scriptPath
    } -ArgumentList "$PWD\iptv_smart_player.py", "$PWD\venv"
    
    # Wait for specified duration
    Start-Sleep -Seconds $Duration
    
    # Stop the player
    Stop-Job $job
    Remove-Job $job
    
    Write-Host "✅ Test completed!" -ForegroundColor Green
} else {
    # Run normally
    python iptv_smart_player.py
}

Write-Host "📊 Check iptv_player.log for results" -ForegroundColor Cyan