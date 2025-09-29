# Windows test script
param(
    [switch]$TestMode,
    [int]$Duration = 30
)

Write-Host "🧪 Testing IPTV Player on Windows..." -ForegroundColor Green

# Set environment for development
$env:IPTV_ENV = "development"

if ($TestMode) {
    Write-Host "⏱️ Running in test mode for $Duration seconds..." -ForegroundColor Yellow
    
    # Start the player in background
    $job = Start-Job -ScriptBlock {
        param($scriptPath)
        python $scriptPath
    } -ArgumentList "$PWD\iptv_smart_player.py"
    
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