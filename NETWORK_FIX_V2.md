# Network Setup Fix - Version 2 (Revised)

## Problems Identified

After the first fix attempt failed, deeper analysis revealed:

### 1. **Network IP Stuck at 192.168.4.1**
   - **Root Cause**: The sed command syntax was wrong
   - Previous: `/# GrannyTV.../,/nohook wpa_supplicant/d` - deletes range from start to END pattern
   - Problem: If END pattern not found, nothing gets deleted or wrong content deleted
   - **Fix**: `/# GrannyTV Setup Hotspot Configuration/,+3d` - deletes comment line + exactly 3 lines after

### 2. **Network Manager Conflicts**
   - **Root Cause**: Both NetworkManager AND dhcpcd enabled simultaneously
   - Previous fix blindly enabled NetworkManager without checking if it exists/is active
   - This creates conflicts on systems using dhcpcd (traditional Raspberry Pi)
   - **Fix**: Detect which system is running, only enable one

### 3. **Playback Service Not Starting**
   - **Root Cause**: `iptv-player.service` used `graphical-session.target`
   - This target doesn't exist on headless/server systems
   - Service would never start even if network worked
   - **Fix**: Change to `multi-user.target` (standard on all Linux systems)

## Changes Made

### 1. **setup_server.py** (finalize endpoint)

**Before:**
```python
# Complex Python file parsing that couldn't handle permissions
with open('/etc/dhcpcd.conf', 'r') as f:
    dhcpcd_lines = f.readlines()
# ... 20+ lines of parsing logic ...
with open('/tmp/dhcpcd.conf.cleaned', 'w') as f:
    f.writelines(cleaned_lines)
subprocess.run(['sudo', 'cp', '/tmp/dhcpcd.conf.cleaned', '/etc/dhcpcd.conf'])
```

**After:**
```python
# Simple, reliable sed command
subprocess.run([
    'sudo', 'sed', '-i',
    '/# GrannyTV Setup Hotspot Configuration/,+3d',
    '/etc/dhcpcd.conf'
], check=True)
```

**Network Manager Detection:**
```python
# Check which network manager is active
nm_active = subprocess.run(['systemctl', 'is-active', 'NetworkManager'], 
                          capture_output=True, text=True).returncode == 0

if nm_active:
    # Use NetworkManager (modern Raspberry Pi OS)
    subprocess.run(['sudo', 'systemctl', 'enable', 'NetworkManager'])
    subprocess.run(['sudo', 'systemctl', 'stop', 'dhcpcd'])
    subprocess.run(['sudo', 'systemctl', 'disable', 'dhcpcd'])
else:
    # Use dhcpcd (traditional Raspberry Pi)
    subprocess.run(['sudo', 'systemctl', 'enable', 'wpa_supplicant'])
    subprocess.run(['sudo', 'systemctl', 'enable', 'dhcpcd'])
```

### 2. **restore-normal-wifi.sh**

Added network manager detection:
```bash
if systemctl is-active --quiet NetworkManager; then
    echo "🔄 Using NetworkManager..."
    sudo systemctl stop dhcpcd 2>/dev/null || true
    sudo systemctl disable dhcpcd 2>/dev/null || true
    sudo systemctl restart NetworkManager 2>/dev/null || true
else
    echo "🔄 Using dhcpcd and wpa_supplicant..."
    sudo systemctl enable wpa_supplicant 2>/dev/null || true
    sudo systemctl enable dhcpcd 2>/dev/null || true
    sudo systemctl restart dhcpcd 2>/dev/null || true
fi
```

### 3. **iptv-player.service**

**Before:**
```ini
[Unit]
After=network-online.target graphical-session.target sound.target
Wants=network-online.target graphical-session.target
Requires=network-online.target

[Install]
WantedBy=graphical-session.target
```

**After:**
```ini
[Unit]
After=network-online.target sound.target
Wants=network-online.target

[Install]
WantedBy=multi-user.target
```

**Changes:**
- Removed `graphical-session.target` dependency (doesn't exist on headless)
- Removed `Requires=network-online.target` (too strict, prevents startup)
- Changed install target to `multi-user.target` (universal Linux target)

### 4. **setup-wizard.sh** (embedded restore script)

Synchronized with standalone `restore-normal-wifi.sh`:
- Same sed command fix
- Same network manager detection logic
- Consistent behavior across all cleanup paths

## Technical Details

### The sed Command Explained

**What we're removing from dhcpcd.conf:**
```
# GrannyTV Setup Hotspot Configuration    <-- Line 1 (comment)
interface wlan0                           <-- Line 2 
static ip_address=192.168.4.1/24         <-- Line 3
nohook wpa_supplicant                     <-- Line 4
```

**Sed command:** `/# GrannyTV Setup Hotspot Configuration/,+3d`
- Find line with comment: `# GrannyTV Setup Hotspot Configuration`
- Delete that line AND the next 3 lines: `,+3d`
- Result: All 4 lines removed cleanly

**Why +3d instead of range to end pattern?**
- Range patterns can fail if end pattern doesn't match exactly
- Whitespace differences, line endings, or variations break it
- Fixed count is deterministic and reliable
- We know exactly what we added (4 lines), so we delete exactly 4 lines

### Network Manager Detection Logic

**Why check which is active?**
- Different Raspberry Pi OS versions use different network managers
- Older: dhcpcd + wpa_supplicant
- Newer: NetworkManager
- Running both causes IP conflicts and network instability

**Detection method:**
```bash
systemctl is-active --quiet NetworkManager
echo $?  # Returns 0 if active, non-zero if inactive
```

This is more reliable than checking if the package exists, because it tells us what's actually running.

## Expected Behavior After Fix

### During Setup Finalization:
1. ✅ Hotspot services stopped (hostapd, dnsmasq)
2. ✅ Static IP flushed from wlan0
3. ✅ dhcpcd.conf cleaned (4 lines removed)
4. ✅ Correct network manager enabled (only one)
5. ✅ WiFi credentials applied to wpa_supplicant.conf
6. ✅ System reboots

### After Reboot:
1. ✅ dhcpcd.conf has NO hotspot configuration
2. ✅ Only one network manager is running (no conflicts)
3. ✅ wlan0 acquires DHCP IP from home router (e.g., 192.168.1.x)
4. ✅ iptv-player.service starts (multi-user.target exists)
5. ✅ Player connects to stream and begins playback
6. ✅ No manual intervention needed

## Testing Recommendations

### 1. Test dhcpcd.conf Cleanup
```bash
# Before cleanup - should show hotspot config
grep -A 3 "GrannyTV Setup Hotspot" /etc/dhcpcd.conf

# Run cleanup
sudo sed -i '/# GrannyTV Setup Hotspot Configuration/,+3d' /etc/dhcpcd.conf

# After cleanup - should show nothing
grep -A 3 "GrannyTV Setup Hotspot" /etc/dhcpcd.conf
```

### 2. Test Network Manager Detection
```bash
# Check which is running
systemctl is-active NetworkManager && echo "NetworkManager" || echo "dhcpcd"

# Verify only one is enabled after cleanup
systemctl is-enabled NetworkManager
systemctl is-enabled dhcpcd
# Only ONE should return "enabled"
```

### 3. Test Service Startup
```bash
# Check if multi-user.target exists (should always return active)
systemctl is-active multi-user.target

# Test player service
sudo systemctl enable iptv-player
sudo systemctl start iptv-player
sudo systemctl status iptv-player
# Should show "active (running)"
```

### 4. Full Integration Test
```bash
# Run setup wizard
./setup/setup-wizard.sh

# Complete setup via smartphone
# - Connect to GrannyTV-Setup
# - Configure WiFi and settings
# - Click "Complete Setup"

# After reboot, check:
ip addr show wlan0 | grep "inet "
# Should show home network IP (e.g., 192.168.1.50)
# NOT 192.168.4.1

systemctl status iptv-player
# Should show "active (running)"

# Check logs
tail -f ~/gtv/iptv_service.log
# Should show successful stream connection
```

## Rollback Plan

If this fix doesn't work, restore from backup:

```bash
# Restore dhcpcd.conf
sudo cp /etc/dhcpcd.conf.backup /etc/dhcpcd.conf

# Reset to previous commit
cd ~/gtv
git reset --hard HEAD~1

# Manually configure network
sudo nmcli dev wifi connect "YourSSID" password "YourPassword"
# OR
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
# Add your network manually
```

## Success Criteria

- [ ] dhcpcd.conf cleanup works (verified by grep showing no results)
- [ ] Correct network manager is running (only one enabled)
- [ ] IP address changes from 192.168.4.1 to home network range
- [ ] iptv-player.service starts automatically
- [ ] Playback works without manual intervention
- [ ] Full setup-to-playback flow works end-to-end

## Files Modified

1. `setup/web/setup_server.py` - Finalize endpoint and immediate cleanup script
2. `setup/restore-normal-wifi.sh` - Standalone cleanup script
3. `setup/setup-wizard.sh` - Embedded restore script template
4. `platforms/linux/iptv-player.service` - Service configuration
