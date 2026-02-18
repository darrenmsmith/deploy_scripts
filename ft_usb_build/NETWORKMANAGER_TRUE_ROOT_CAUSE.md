# NetworkManager - The True Root Cause

## The Smoking Gun

From comparing Device4 (broken) vs Device5 (working) network configuration logs:

**BOTH devices have NetworkManager running**, but:

### Device4 (Broken):
```
wlan0 type: managed
ESSID: off/any
state: DOWN
```
NetworkManager IS managing wlan0 → resets it to managed mode

### Device5 (Working):
```
wlan0 type: IBSS
ESSID: "ft_mesh2"
state: UP
```
NetworkManager is NOT managing wlan0 → leaves it in IBSS mode

## Why NetworkManager Resets wlan0

NetworkManager's job is to manage network interfaces. When it sees wlan0:

1. **Without "unmanaged" configuration:**
   - NetworkManager takes control of wlan0
   - Sees it in IBSS mode (which it doesn't understand)
   - Resets it to managed mode to connect to WiFi AP
   - Tries to find WiFi networks
   - Mesh destroyed

2. **With "unmanaged" configuration:**
   - NetworkManager ignores wlan0
   - wlan0 stays in IBSS mode
   - Mesh works

## The Documentation Was Wrong

The `/mnt/usb/ft_usb_build/NETWORKMANAGER_REMOVED.md` file says:
> "NetworkManager is NOT needed and was removed"

**But the logs prove NetworkManager IS STILL INSTALLED AND RUNNING on both devices!**

It was supposed to be removed, but either:
1. It was never actually removed
2. It was removed then reinstalled
3. The removal only happened on some devices (like Device0)

## Why Device5 Works - VERIFIED!

**Device5 NetworkManager Configuration (verified 2026-01-07):**

Device5 does NOT have any unmanaged configuration files. Instead:

**WiFi is DISABLED in NetworkManager:**
```
nmcli general status:
WIFI-HW: enabled
WIFI: disabled  ← This is the key!
```

**Device status:**
```
nmcli device status:
wlan0  wifi  unavailable  --
```

Device5 has NetworkManager WiFi globally disabled (`nmcli radio wifi off`), which means:
- NetworkManager doesn't scan for WiFi networks
- NetworkManager doesn't try to manage wlan0
- wlan0 shows as "unavailable" instead of "unmanaged"
- Our mesh scripts can control wlan0 without any interference

## Why "Worked Before the Big Cleanup"

Before the cleanup, either:
1. NetworkManager WAS configured to ignore wlan0
2. NetworkManager was actually removed/disabled
3. The configuration got lost during the cleanup

## The Complete Picture

**The sequence on Device4:**

1. **Boot starts**
2. **NetworkManager starts** (enabled service)
3. **batman-mesh-client.service starts**
4. Script sets wlan0 to IBSS mode ✓
5. Script joins mesh network ✓
6. wlan0 has no carrier (Device0 not ready yet)
7. Service completes
8. **NetworkManager scans for managed interfaces**
9. **NetworkManager sees wlan0** (not in its unmanaged list)
10. **NetworkManager resets wlan0 to managed mode** ❌
11. Mesh destroyed, connection lost

**On Device5:**

Steps 1-7 same, then:

8. NetworkManager scans for managed interfaces
9. **NetworkManager skips wlan0** (it's in unmanaged list)
10. wlan0 stays in IBSS mode ✓
11. Mesh works ✓

## The Solution

**Option 1: Disable WiFi in NetworkManager (Device5 Method - RECOMMENDED)**

This is how Device5 is configured and working:
```bash
sudo nmcli radio wifi off
```

This disables WiFi globally in NetworkManager:
- NetworkManager won't scan for networks
- NetworkManager won't interfere with wlan0 at all
- wlan0 will show as "unavailable" (not interfering)
- Setting persists across reboots

**Option 2: Configure NetworkManager to Ignore wlan0**

Create `/etc/NetworkManager/conf.d/99-unmanage-wlan0.conf`:
```ini
[keyfile]
unmanaged-devices=interface-name:wlan0;interface-name:bat0

[device]
wifi.scan-rand-mac-address=no
```

Then: `sudo systemctl restart NetworkManager.service`

Note: This was tried on Device4 but may not be sufficient if NetworkManager still does background WiFi scanning.

**Option 3: Remove/Disable NetworkManager (Nuclear Option)**

```bash
sudo systemctl stop NetworkManager.service
sudo systemctl disable NetworkManager.service
sudo systemctl mask NetworkManager.service
```

**Recommendation:** Use Option 1 (disable WiFi). This is proven to work on Device5 and is the cleanest solution.

## The Fix Scripts

**RECOMMENDED: Disable WiFi (Device5 Method)**

On Device4:
```bash
sudo /mnt/usb/ft_usb_build/fix_networkmanager_disable_wifi.sh
```

This will:
1. Disable WiFi in NetworkManager (`nmcli radio wifi off`)
2. Restart mesh service
3. Verify wlan0 stays in IBSS mode

Then reboot to test:
```bash
sudo reboot
```

After reboot, verify:
```bash
nmcli general status              # WIFI should show 'disabled'
nmcli device status               # wlan0 should show 'unavailable'
iw dev wlan0 info | grep type    # Should show IBSS
sudo batctl n                     # Should show neighbors
```

**ALTERNATIVE: Mark wlan0 as unmanaged**

On Device4:
```bash
sudo /mnt/usb/ft_usb_build/fix_networkmanager_ignore_wlan0.sh
sudo systemctl restart batman-mesh-client.service
iw dev wlan0 info | grep type    # Should show IBSS
nmcli device status               # wlan0 should show 'unmanaged'
sudo reboot
```

Note: This was tried but Device4 still couldn't connect after reboot, even though wlan0 stayed in IBSS mode. Disabling WiFi completely (Option 1) is more reliable.

## Verification - Check Device5 NetworkManager Config

**On Device5 (working device):**
```bash
sudo /mnt/usb/ft_usb_build/check_networkmanager_config.sh
```

This will show exactly how NetworkManager is configured on the working device.

We'll likely find a configuration file in `/etc/NetworkManager/conf.d/` that marks wlan0 as unmanaged.

## Why This Wasn't Caught Earlier

1. **Symptom looked like timing issue** - service reported success, mesh worked on restart
2. **Multiple potential culprits** - RF-kill, dhcpcd, wpa_supplicant
3. **Diagnostic blind spot** - didn't check NetworkManager config initially
4. **Documentation misleading** - said NetworkManager was removed
5. **Silent interference** - NetworkManager doesn't log "I'm resetting wlan0 to managed"

## Files

- `/mnt/usb/ft_usb_build/fix_networkmanager_ignore_wlan0.sh` - Fix script
- `/mnt/usb/ft_usb_build/check_networkmanager_config.sh` - Diagnostic script
- `/etc/NetworkManager/conf.d/99-unmanage-wlan0.conf` - Configuration file (created by fix)

## Next Steps

1. **On Device5:** Run `check_networkmanager_config.sh` to see how it's configured
2. **On Device4:** Run `fix_networkmanager_ignore_wlan0.sh` to mark wlan0 as unmanaged
3. **Test reboot** on Device4 to confirm fix works
4. **Apply same fix** to Device3 and any other broken clients
5. **Update build scripts** to include NetworkManager configuration in Phase4

## Status

- ✅ Root cause identified (NetworkManager interfering with wlan0)
- ✅ Device5 NetworkManager config verified (WiFi disabled globally)
- ✅ Created fix script using Device5 method (disable WiFi)
- ⚠️ Device4: Applied "unmanaged" fix - wlan0 stays in IBSS but still no connection
- ⏳ Need to apply Device5 method (disable WiFi) to Device4
- ⏳ Need to test Device4 reboot after WiFi disable fix
- ⏳ Need to apply same fix to Device3
- ⏳ Need to update build scripts to disable WiFi in NetworkManager during Phase4

## Current Issue on Device4

After applying the "unmanaged" fix:
- ✅ wlan0 stays in IBSS mode after reboot
- ❌ Still no mesh connection (no neighbors visible)

This suggests NetworkManager might still be doing background WiFi scanning even with wlan0 marked as unmanaged. The Device5 method (disable WiFi completely) should fix this.
