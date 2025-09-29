# PowerShell deployment script for Windows to Raspberry Pi
param(
    [string]$PiHost = "raspberrypi.local",  # or use IP address
    [string]$PiUser = "jeremy",
    [string]$PiPath = "/home/jeremy/gtv"
)

Write-Host "🚀 Deploying IPTV Player to Raspberry Pi..." -ForegroundColor Green

# Create remote directory if it doesn't exist
ssh "${PiUser}@${PiHost}" "mkdir -p ${PiPath}"

# Copy files to Pi
Write-Host "📁 Copying files..." -ForegroundColor Yellow
scp iptv_smart_player.py "${PiUser}@${PiHost}:${PiPath}/"
scp working_streams.json "${PiUser}@${PiHost}:${PiPath}/"

# Make script executable
ssh "${PiUser}@${PiHost}" "chmod +x ${PiPath}/iptv_smart_player.py"

# Optional: Restart the service if it's running
Write-Host "🔄 Restarting service..." -ForegroundColor Yellow
ssh "${PiUser}@${PiHost}" "sudo pkill -f iptv_smart_player.py; sleep 2"

Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host "🎯 To test: ssh ${PiUser}@${PiHost} 'cd ${PiPath} && python3 iptv_smart_player.py'" -ForegroundColor Cyan