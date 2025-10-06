# Network Setup Fix - Version 3 (Critical Bug Fix)

## Problem Discovered

After manual network fix, further investigation revealed the **root cause** of why the network cleanup never worked:

### The Bug
The immediate cleanup script (`/tmp/immediate-cleanup.sh`) was **created but never executed**.

**In `setup/web/setup_server.py` finalize endpoint (lines 614-639):**
```python
# Script was created
with open('/tmp/immediate-cleanup.sh', 'w') as f:
    f.write(immediate_cleanup)

os.chmod('/tmp/immediate-cleanup.sh', 0o755)

# BUT THEN: Instead of executing it, code created a reboot service
subprocess.run(['sudo', 'systemctl', 'start', 'grannytv-reboot'], check=True)
```

This meant:
- ✅ Cleanup script was written to disk
- ❌ Cleanup script was never executed
- ❌ Setup services kept running
- ❌ Setup mode flag (`/var/lib/grannytv-setup-mode`) was never removed
- ❌ dhcpcd.conf hotspot config was never cleaned
- ❌ System just rebooted immediately
- ❌ On reboot, setup mode flag still existed → services started again

### Why This Caused Network Issues

**The Cascade of Failures:**
1. Finalize endpoint triggered → script written but not run → system rebooted
2. On reboot, `/var/lib/grannytv-setup-mode` still exists
3. `grannytv-prepare.service` runs (checks flag, finds it, proceeds)
4. Stops NetworkManager, stops wpa_supplicant, stops dhcpcd
5. `grannytv-setup.service` starts
6. Configures wlan0 with static IP 192.168.4.1 (from dhcpcd.conf)
7. Starts hostapd and dnsmasq for hotspot
8. **Result**: System stuck in setup mode, IP = 192.168.4.1, no internet

**Manual Fix Applied:**
- User manually configured WiFi in wpa_supplicant.conf
- NetworkManager was manually started
- NetworkManager connected to home WiFi successfully
- But setup services still running (hostapd, dnsmasq, grannytv-setup)
- Setup mode flag still exists

## The Fix

### Change in `setup/web/setup_server.py`

**Before (BROKEN):**
```python
with open('/tmp/immediate-cleanup.sh', 'w') as f:
    f.write(immediate_cleanup)

os.chmod('/tmp/immediate-cleanup.sh', 0o755)

# Create systemd service for reboot (more reliable than sudo from web server)
reboot_service = """[Unit]
Description=GrannyTV Setup Reboot
...
"""

with open('/tmp/grannytv-reboot.service', 'w') as f:
    f.write(reboot_service)

subprocess.run(['sudo', 'cp', '/tmp/grannytv-reboot.service', 
               '/etc/systemd/system/'], check=True)
subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
subprocess.run(['sudo', 'systemctl', 'start', 'grannytv-reboot'], check=True)
```

**After (FIXED):**
```python
with open('/tmp/immediate-cleanup.sh', 'w') as f:
    f.write(immediate_cleanup)

os.chmod('/tmp/immediate-cleanup.sh', 0o755)

# Execute the cleanup script in background
# This will clean up services, remove flags, and reboot after 15 seconds
with open('/tmp/immediate-cleanup.log', 'w') as log_file:
    subprocess.Popen(['bash', '/tmp/immediate-cleanup.sh'], 
                    stdout=log_file, 
                    stderr=subprocess.STDOUT,
                    start_new_session=True)

print("Immediate cleanup and reboot scheduled in background")
```

### What This Changes

**Now the cleanup script actually runs and performs:**

1. **Remove setup mode flag** (line 544):
   ```bash
   sudo rm -f /var/lib/grannytv-setup-mode
   ```
   → Prevents setup services from starting on reboot

2. **Stop and disable hotspot services** (lines 547-550):
   ```bash
   sudo systemctl stop hostapd
   sudo systemctl stop dnsmasq
   sudo systemctl disable hostapd
   sudo systemctl disable dnsmasq
   ```

3. **Clean dhcpcd.conf** (line 565):
   ```bash
   sudo sed -i '/# GrannyTV Setup Hotspot Configuration/,+3d' /etc/dhcpcd.conf
   ```
   → Removes static IP 192.168.4.1 configuration

4. **Configure network manager** (lines 570-593):
   - Detect if NetworkManager or dhcpcd is active
   - Enable the correct one, disable the other
   - Restart network services with home WiFi config

5. **Stop setup services** (lines 599-602):
   ```bash
   sudo systemctl disable grannytv-setup
   sudo systemctl stop grannytv-setup
   sudo systemctl disable grannytv-prepare
   sudo systemctl stop grannytv-prepare
   ```

6. **Reboot** (line 609):
   ```bash
   sudo reboot
   ```

### Why subprocess.Popen Works

- `subprocess.Popen` launches the script as a **background process**
- `start_new_session=True` detaches it from the web server process
- Script continues running even after web server returns response to browser
- Output is logged to `/tmp/immediate-cleanup.log` for debugging
- The script itself handles the reboot at the end (after 15 second delay)

## Expected Behavior After Fix

### During Finalization:
1. ✅ User clicks "Complete Setup" in web interface
2. ✅ WiFi credentials saved to wpa_supplicant.conf
3. ✅ Cleanup script created
4. ✅ **Cleanup script EXECUTED in background**
5. ✅ Web response sent to browser
6. ✅ Cleanup script runs:
   - Removes `/var/lib/grannytv-setup-mode` flag
   - Stops hostapd, dnsmasq
   - Cleans dhcpcd.conf (removes 192.168.4.1)
   - Configures network manager
   - Stops setup services
   - Waits 15 seconds (for web response to complete)
   - Reboots system

### After Reboot:
1. ✅ Setup mode flag doesn't exist
2. ✅ grannytv-prepare.service exits early (no flag found)
3. ✅ grannytv-setup.service doesn't start (depends on prepare)
4. ✅ hostapd and dnsmasq disabled (don't start)
5. ✅ dhcpcd.conf has NO hotspot configuration
6. ✅ NetworkManager (or dhcpcd) starts normally
7. ✅ wlan0 connects to home WiFi using wpa_supplicant.conf
8. ✅ IP acquired via DHCP from home router (e.g., 192.168.1.50)
9. ✅ iptv-player.service starts automatically
10. ✅ Video playback begins

## How to Test the Fix

### 1. Clean Up Current Stuck State
Since the system is currently stuck in setup mode after manual network fix:

```bash
# Run the cleanup manually to test it
sudo /home/jeremy/gtv/setup/restore-normal-wifi.sh

# Or step by step:
sudo rm -f /var/lib/grannytv-setup-mode
sudo systemctl stop grannytv-setup
sudo systemctl stop grannytv-prepare
sudo systemctl disable grannytv-setup
sudo systemctl disable grannytv-prepare
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo systemctl disable hostapd
sudo systemctl disable dnsmasq
```

### 2. Test Full Setup Flow
```bash
# Start fresh setup
cd ~/gtv
./setup/setup-wizard.sh

# Complete setup via smartphone:
# 1. Connect to GrannyTV-Setup WiFi
# 2. Browse to http://192.168.4.1:8080
# 3. Configure WiFi and settings
# 4. Click "Complete Setup"

# After reboot, verify:
ip addr show wlan0 | grep "inet "
# Should show home network IP (NOT 192.168.4.1)

systemctl status iptv-player
# Should show "active (running)"

ls -la /var/lib/grannytv-setup-mode
# Should return "No such file or directory"

systemctl list-units | grep -E "(grannytv|hostapd|dnsmasq)"
# Should show all inactive/disabled
```

### 3. Check Cleanup Logs
```bash
# View cleanup execution log
cat /tmp/immediate-cleanup.log

# Should show:
# - Starting immediate WiFi switch...
# - Cleaning dhcpcd.conf...
# - Removed hotspot configuration from dhcpcd.conf
# - Using NetworkManager... (or dhcpcd)
# - Rebooting system to complete setup...
```

## Files Modified

- `setup/web/setup_server.py` - Fixed finalize endpoint to actually execute cleanup script

## Verification Checklist

After fix is applied and tested:

- [ ] Cleanup script is executed (check /tmp/immediate-cleanup.log exists and has content)
- [ ] Setup mode flag is removed (no /var/lib/grannytv-setup-mode)
- [ ] dhcpcd.conf is cleaned (no GrannyTV hotspot config)
- [ ] Hostapd and dnsmasq are stopped and disabled
- [ ] Setup services (grannytv-setup, grannytv-prepare) are stopped and disabled
- [ ] Network connects to home WiFi automatically
- [ ] IP address is from home network range (not 192.168.4.1)
- [ ] iptv-player service starts and plays video
- [ ] No manual intervention required

## Root Cause Summary

**The bug was simple but critical:** The finalization code wrote a cleanup script to disk but never executed it. Instead, it just triggered a reboot. This left all setup artifacts in place (flag, services, configs), causing the system to boot back into setup mode with the hotspot IP, preventing normal operation.

**The fix is equally simple:** Execute the cleanup script using `subprocess.Popen` so it actually runs before the reboot.

## Impact

This fix ensures the complete setup-to-production transition works automatically:
- ✅ One-time setup wizard completes successfully
- ✅ System transitions from hotspot to home WiFi seamlessly
- ✅ All setup artifacts are cleaned up
- ✅ Video playback starts automatically after reboot
- ✅ No manual intervention or debugging required
