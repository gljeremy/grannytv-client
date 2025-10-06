# Network Setup Fix - Critical Issues Resolved

## Issues Fixed

### Issue 1: Network IP Stuck at 192.168.4.1 After Setup
**Problem:** After completing the setup wizard and rebooting, the Raspberry Pi's network IP remained at 192.168.4.1 (the hotspot IP) instead of connecting to the home WiFi network.

**Root Cause:** The setup process added hotspot configuration to `/etc/dhcpcd.conf` but failed to remove it during finalization, causing the static IP to be re-applied on every boot.

### Issue 2: Playback Not Working After Manual Network Fix
**Problem:** After manually fixing the network issues, video playback still didn't work.

**Root Causes:**
1. Setup services (hostapd, dnsmasq, grannytv-setup, grannytv-prepare) remained enabled and running
2. Setup mode flag `/var/lib/grannytv-setup-mode` was not removed
3. iptv-player.service had systemd configuration error (StartLimitIntervalSec in wrong section)

## Changes Made

### 1. setup/web/setup_server.py - `/finalize` endpoint
**Before:** Only restored dhcpcd.conf from backup (if it existed)

**After:** 
- Actively removes the GrannyTV hotspot configuration section from dhcpcd.conf
- Uses Python file parsing to surgically remove hotspot-specific lines
- Falls back to backup restoration if parsing fails
- This ensures the static IP 192.168.4.1 is not set on reboot

```python
# CRITICAL: Remove hotspot configuration from dhcpcd.conf
# This prevents the static IP 192.168.4.1 from being set on reboot
try:
    with open('/etc/dhcpcd.conf', 'r') as f:
        dhcpcd_lines = f.readlines()
    
    # Remove GrannyTV hotspot configuration section
    cleaned_lines = []
    skip_section = False
    for line in dhcpcd_lines:
        if 'GrannyTV Setup Hotspot Configuration' in line:
            skip_section = True
            continue
        if skip_section:
            # Skip hotspot config lines
            if line.strip().startswith('interface wlan0') or \
               line.strip().startswith('static ip_address=192.168.4.1') or \
               line.strip().startswith('nohook wpa_supplicant'):
                continue
            else:
                skip_section = False
        
        if not skip_section:
            cleaned_lines.append(line)
    
    # Write cleaned configuration
    with open('/tmp/dhcpcd.conf.cleaned', 'w') as f:
        f.writelines(cleaned_lines)
    
    subprocess.run(['sudo', 'cp', '/tmp/dhcpcd.conf.cleaned', '/etc/dhcpcd.conf'], check=True)
```

### 2. setup/web/setup_server.py - `immediate-cleanup.sh` script
**Added:**
- Explicit disabling of hotspot services (not just stopping)
- dhcpcd.conf cleanup using sed command
- Interface down/up cycle for clean transition

```bash
# CRITICAL: Clean up dhcpcd.conf to remove static IP configuration
if [ -f /etc/dhcpcd.conf ]; then
    sudo sed -i '/# GrannyTV Setup Hotspot Configuration/,/nohook wpa_supplicant/d' /etc/dhcpcd.conf
    if [ -f /etc/dhcpcd.conf.backup ]; then
        sudo cp /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
    fi
fi
```

### 3. setup/restore-normal-wifi.sh
**Added:**
- dhcpcd.conf cleanup step
- Interface management improvements
- Better NetworkManager integration

### 4. setup/setup-wizard.sh
**Updated:** The restoration script template to include dhcpcd.conf cleanup

### 5. platforms/linux/iptv-player.service
**Fixed:** Moved `StartLimitIntervalSec` and `StartLimitBurst` from `[Service]` to `[Unit]` section

**Before:**
```ini
[Service]
...
StartLimitBurst=5
StartLimitIntervalSec=300
```

**After:**
```ini
[Unit]
...
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
...
```

This fixes systemd warnings and allows proper service startup.

## Testing Results

### Before Fix:
- ❌ Network IP stuck at 192.168.4.1 after reboot
- ❌ Manual network fix required
- ❌ Playback not starting
- ❌ Setup services still running
- ❌ dhcpcd.conf contained hotspot configuration

### After Fix:
- ✅ dhcpcd.conf cleaned (hotspot config removed)
- ✅ Setup services disabled
- ✅ Setup mode flag removed
- ✅ Player service running and playing video successfully
- ✅ Network connected properly
- ✅ No systemd warnings for iptv-player.service

## Files Modified

1. `setup/web/setup_server.py` - Enhanced finalization logic
2. `setup/restore-normal-wifi.sh` - Added dhcpcd.conf cleanup
3. `setup/setup-wizard.sh` - Updated restoration script template
4. `platforms/linux/iptv-player.service` - Fixed systemd configuration

## Verification Steps

To verify the fix works:

1. Complete the setup wizard process
2. Wait for automatic reboot
3. Check network status: `ip addr show wlan0`
   - Should show home WiFi IP (NOT 192.168.4.1)
4. Check dhcpcd.conf: `cat /etc/dhcpcd.conf | tail -10`
   - Should NOT contain GrannyTV hotspot configuration
5. Check player service: `systemctl status iptv-player`
   - Should be active and running
6. Check setup services: `systemctl list-units | grep grannytv`
   - Should NOT be active or enabled

## Impact

This fix ensures:
- Setup completes cleanly without manual intervention
- Network connects to home WiFi automatically after setup
- Video playback starts immediately
- No orphaned setup services or configurations
- System is ready for production use after single setup run
