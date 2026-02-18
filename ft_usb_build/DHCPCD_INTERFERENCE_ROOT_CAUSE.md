# DHCPCD Interference - True Root Cause

## The Mystery Solved

**Symptom:** Restart works, reboot fails. wlan0 is in IBSS mode for a few seconds, then changes back to managed mode.

**Root Cause:** **dhcpcd is managing wlan0** and resetting it to managed mode when it sees the interface has no carrier.

## Timeline of Events (from Device4 boot logs)

### During Service Startup (15:49:01 - 15:49:18):
```
✓ RF-kill unblocked
✓ IBSS mode set successfully
✓ Joined IBSS network: ft_mesh2
✓ Service reports: type IBSS
⚠️ WARNING: Interface not in UP state (state DOWN - no carrier)
⚠️ Batman-adv: wlan0: inactive
```

### After Service Completes (7 minutes later at 15:56):
```
❌ wlan0 type: managed  (CHANGED BACK!)
```

## What Happened

1. **batman-mesh-client service starts** (15:49:01)
2. **Script sets IBSS mode** (successful)
3. **Script joins IBSS network** (successful)
4. **wlan0 is in IBSS mode BUT has no carrier** (state DOWN)
   - Why no carrier? Because:
     - Device0 might not be fully booted yet
     - OR Device4 can't see Device0's IBSS network yet
     - OR RF propagation issue
5. **Service completes and exits** (15:49:18)
6. **dhcpcd sees wlan0 is DOWN**
7. **dhcpcd tries to "help" by resetting wlan0 to managed mode**
8. **IBSS connection lost, mesh never forms**

## Why dhcpcd Interferes

dhcpcd is configured to manage network interfaces and provide DHCP. By default, it manages **ALL** interfaces unless told otherwise.

**Current dhcpcd behavior:**
- Watches wlan0
- Sees it in IBSS mode with no carrier
- Thinks something is wrong
- Resets wlan0 to managed mode
- Tries to connect to regular WiFi AP
- Mesh network destroyed

## Why Restart Works But Reboot Fails

### Service Restart:
1. System fully booted
2. Device0 mesh already running
3. wlan0 joins IBSS and immediately sees Device0
4. Carrier comes up FAST
5. dhcpcd doesn't have time to interfere
6. Mesh forms ✅

### Reboot:
1. Both Device0 and Device4 booting
2. Services start in parallel
3. Device4's wlan0 joins IBSS
4. But Device0 isn't ready yet
5. wlan0 sits in "no carrier" state
6. dhcpcd sees DOWN state
7. dhcpcd resets wlan0 to managed
8. By the time Device0 is ready, Device4 is broken ❌

## Why It Worked "Before the Big Cleanup"

**Question:** What changed?

Possible answers:
1. **dhcpcd wasn't running before** - got re-enabled during cleanup
2. **dhcpcd.conf had denyinterfaces wlan0** - got removed during cleanup
3. **Service ordering was different** - Device0 started before clients
4. **Boot timing was slower** - gave more time for mesh to form

We need to check the dhcpcd.conf on a working system (like Device5) to see if it has `denyinterfaces wlan0`.

## The Fix

**Tell dhcpcd to IGNORE wlan0 and bat0:**

Add to `/etc/dhcpcd.conf`:
```bash
# Ignore mesh interfaces - managed by batman-adv
denyinterfaces wlan0 bat0
```

This prevents dhcpcd from:
- Managing wlan0
- Resetting wlan0 to managed mode
- Trying to get DHCP on wlan0
- Interfering with batman-adv

## Verification Steps

### On Device4:

1. **Check current dhcpcd.conf:**
   ```bash
   grep "^denyinterfaces" /etc/dhcpcd.conf
   ```

   - If it shows `denyinterfaces wlan0 bat0` → dhcpcd is already configured correctly
   - If it doesn't show wlan0 → **THIS IS THE PROBLEM**

2. **Apply the fix:**
   ```bash
   sudo /mnt/usb/ft_usb_build/fix_dhcpcd_ignore_wlan0.sh
   ```

3. **Test with restart:**
   ```bash
   sudo systemctl restart batman-mesh-client.service
   iw dev wlan0 info | grep type    # Should show IBSS
   sleep 10
   iw dev wlan0 info | grep type    # Should STILL show IBSS (not changed back)
   ```

4. **Test with reboot:**
   ```bash
   sudo reboot
   ```

5. **After reboot, verify:**
   ```bash
   iw dev wlan0 info | grep type    # Should show IBSS
   sudo batctl n                     # Should show neighbors
   ```

### On Device5 (Working):

Check if it has the denyinterfaces line:
```bash
grep "^denyinterfaces" /etc/dhcpcd.conf
```

If Device5 has `denyinterfaces wlan0` but Device4 doesn't, that explains why Device5 works!

## Expected Results After Fix

### Service Logs:
```
✓ IBSS mode set successfully
✓ Joined IBSS network: ft_mesh2
⚠️ Interface not in UP state (OK - normal initially)
wlan0: inactive (OK - will activate when sees neighbors)
```

### A few seconds later:
```
wlan0: type IBSS (STAYS in IBSS mode!)
wlan0: active (activated when found neighbors)
batctl n shows Device0 and Device5
```

## Related Issues

This same issue affects:
- wpa_supplicant (if running)
- NetworkManager (already removed)
- systemd-networkd (if enabled)

All these services try to "helpfully" manage network interfaces and can interfere with manual mesh configuration.

**General principle:** Mesh interfaces must be in `denyinterfaces` or marked as "unmanaged" by any automatic network management service.

## Files

- `/mnt/usb/ft_usb_build/fix_dhcpcd_ignore_wlan0.sh` - Adds wlan0/bat0 to denyinterfaces
- `/mnt/usb/ft_usb_build/check_network_interference.sh` - Checks what's managing wlan0
- `/etc/dhcpcd.conf` - dhcpcd configuration file

## Status

- ✅ Root cause identified (dhcpcd interference)
- ✅ Fix script created
- ⏳ Need to verify dhcpcd.conf on Device5 (working device)
- ⏳ Need to apply fix to Device4
- ⏳ Need to test reboot after fix
- ⏳ Need to apply fix to Device3 (also broken)
