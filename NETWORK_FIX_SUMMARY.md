# Network Fix Summary - NetworkManager Issue After Setup Reboot

## Problem

After completing the GrannyTV setup wizard and rebooting, the network device (wlan0) had an IP address of 192.168.4.1 (the hotspot IP) instead of connecting to the home WiFi network. This required manually starting NetworkManager before streaming would work.

## Root Cause

The issue occurred because:

1. **NetworkManager wasn't being enabled/started** during the setup finalization process
2. The `dhcpcd.conf` file still contained the static IP configuration (192.168.4.1) from the hotspot setup
3. On reboot, if NetworkManager wasn't running, dhcpcd would activate and apply the static IP 192.168.4.1
4. This prevented the system from connecting to the home WiFi network

## Solution

Updated `/home/jeremy/gtv/setup/web/setup_server.py` to ensure NetworkManager is properly enabled and started during the cleanup process. The fix was applied in two locations:

### 1. In the `finalize()` function (line ~423)

Added explicit NetworkManager enable/start commands after restoring dhcpcd.conf:

```python
# Enable and start NetworkManager (modern Raspberry Pi OS uses this)
subprocess.run(['sudo', 'systemctl', 'enable', 'NetworkManager'], check=False)
subprocess.run(['sudo', 'systemctl', 'start', 'NetworkManager'], check=False)
```

### 2. In the immediate cleanup script (line ~529)

Added dhcpcd.conf restoration and NetworkManager enable/start to the cleanup script that runs before reboot:

```bash
# Restore original dhcpcd.conf if backup exists
if [ -f /etc/dhcpcd.conf.backup ]; then
    sudo cp /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
fi

# Enable and start NetworkManager (modern Raspberry Pi OS uses this)
sudo systemctl enable NetworkManager 2>/dev/null || true
sudo systemctl start NetworkManager 2>/dev/null || true
```

## Why This Works

Modern Raspberry Pi OS uses NetworkManager as the primary network management service. By ensuring NetworkManager is:

1. **Enabled** - It will start automatically on boot
2. **Started** - It will take over network management immediately

NetworkManager will:
- Override any static IP configuration in dhcpcd.conf
- Manage wlan0 using the WiFi configuration from wpa_supplicant.conf
- Connect to the home WiFi network automatically
- Handle DHCP and network connectivity properly

This ensures that after the setup wizard completes and the system reboots, NetworkManager will be running and the Pi will connect to the home WiFi network without manual intervention.

## Files Modified

- `setup/web/setup_server.py` - Added NetworkManager enable/start commands in two locations

## Testing

The fix ensures:
- ✅ NetworkManager is enabled before reboot
- ✅ NetworkManager is started during cleanup
- ✅ dhcpcd.conf is restored from backup
- ✅ System connects to home WiFi automatically after reboot
- ✅ No manual intervention required

## Additional Notes

The `restore-normal-wifi.sh` script already had the NetworkManager enable/start commands, so it's consistent with the automated cleanup process.
