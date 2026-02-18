# RF-Kill Issue Analysis and Fix

## Discovery

**Date:** 2026-01-06
**Discovered During:** Manual mesh connection testing on Device4

## The Problem

When running manual mesh test on Device4, the following error occurred:

```
RTNETLINK answers: Operation not possible due to RF-kill
command failed: Network is down (-100)
✗ IBSS join command FAILED
```

This prevented Device4 from joining the mesh network on boot.

## Root Cause Analysis

### What is RF-kill?

RF-kill is a Linux subsystem that can enable/disable wireless transmitters in the system. It's designed to meet regulatory requirements and save power. RF-kill can be:
- **Soft-blocked:** Software-controlled (can be unblocked with `rfkill unblock`)
- **Hard-blocked:** Hardware switch (cannot be unblocked via software)

### Why Did This Happen?

Investigation revealed an **inconsistency in the build scripts**:

#### Gateway Script (Device0) - **HAD THE FIX**
**File:** `/tmp/deploy_scripts/gateway_phases/phase4_mesh.sh`

```bash
# Load batman-adv module
modprobe batman-adv

# Unblock WiFi (RF-kill fix)  ← FIX WAS HERE
rfkill unblock wifi

# Bring down interface
ip link set ${MESH_IFACE} down
```

#### Client Script (Device1-5) - **MISSING THE FIX**
**File:** `/tmp/deploy_scripts/client_phases/phase4_mesh.sh`

```bash
# Load batman-adv module
modprobe batman-adv

# Bring down interface           ← NO RF-KILL UNBLOCK!
ip link set ${MESH_IFACE} down
```

### Why the Inconsistency?

The gateway script was updated at some point to handle RF-kill blocking, but **this fix was never propagated to the client script**. This is a common oversight when:
- Fixes are applied to one script but not similar code
- Different developers/sessions work on related scripts
- Testing is only done on one device type (gateway worked, clients not tested after fix)

## Impact

### Devices Affected
- Device1-5 (all client devices)
- Specifically affects devices where RF-kill soft-block is enabled

### Symptoms
- Client devices cannot join mesh network on boot
- Manual mesh setup fails with "Operation not possible due to RF-kill"
- IBSS join command fails with "Network is down (-100)"
- Systemd service shows active but mesh doesn't form

### Why It Wasn't Caught Earlier
1. Device0 (gateway) had the fix, so it worked fine
2. Not all Raspberry Pi devices have RF-kill enabled by default
3. RF-kill state can vary based on:
   - Kernel version
   - Hardware revision
   - Previous system configuration
   - Power management settings

## The Fix

### Build Script Fix (Permanent)
**Commit:** 0d325ce
**File:** `/tmp/deploy_scripts/client_phases/phase4_mesh.sh`

**Added lines 466-467:**
```bash
# Unblock WiFi (RF-kill fix)
rfkill unblock wifi
```

This ensures all **future** client builds will include the RF-kill unblock.

### Existing Device Fix (Manual)
**Script:** `/mnt/usb/ft_usb_build/fix_client_rfkill.sh`

For devices already built, run this script to update their startup scripts:

```bash
# On each client device (Device1-5)
sudo /mnt/usb/ft_usb_build/fix_client_rfkill.sh
sudo systemctl restart batman-mesh-client.service
```

## Verification

### Before Fix
```bash
$ sudo systemctl status batman-mesh-client.service
● batman-mesh-client.service - BATMAN-adv Mesh Network
   Active: active (exited) but mesh not working

$ sudo batctl n
[No neighbors found]

$ dmesg | grep -i rf-kill
[ 1234.567] wlan0: Operation not possible due to RF-kill
```

### After Fix
```bash
$ sudo systemctl status batman-mesh-client.service
● batman-mesh-client.service - BATMAN-adv Mesh Network
   Active: active (exited)

$ sudo batctl n
[B.A.T.M.A.N. adv 2024.2, MainIF/MAC: wlan0/xx:xx:xx:xx:xx:xx]
IF             Neighbor              last-seen
wlan0          b8:27:eb:3e:4a:99    0.390s

$ ping -c 3 192.168.99.100
3 packets transmitted, 3 received, 0% packet loss
```

## Lessons Learned

### For Build Scripts
1. **Consistency checks:** When fixing one script, search for similar code in other scripts
2. **Cross-device testing:** Test on both gateway AND client devices after fixes
3. **Code review:** Review similar scripts together to catch inconsistencies
4. **Documentation:** Document platform-specific issues (like RF-kill) in comments

### For Troubleshooting
1. **Manual testing is valuable:** Running step-by-step manual tests revealed the exact failure point
2. **Log everything:** Capturing detailed logs helped identify the root cause
3. **Compare working vs non-working:** Gateway worked, client didn't - comparison revealed the difference
4. **System-level understanding:** Understanding RF-kill subsystem helped identify the solution

## Related Files

### Build Scripts
- `/tmp/deploy_scripts/gateway_phases/phase4_mesh.sh` - Gateway build (had fix)
- `/tmp/deploy_scripts/client_phases/phase4_mesh.sh` - Client build (now fixed)

### Startup Scripts (Created by Build)
- `/usr/local/bin/start-batman-mesh.sh` - Device0 gateway startup
- `/usr/local/bin/start-batman-mesh-client.sh` - Client device startup

### Fix Scripts
- `/mnt/usb/ft_usb_build/fix_client_rfkill.sh` - Updates existing client startup scripts

### Test Scripts
- `/mnt/usb/ft_usb_build/manual_mesh_test_device0_logged.sh` - Device0 manual test
- `/mnt/usb/ft_usb_build/manual_mesh_test_client_logged.sh` - Client manual test

### Log Files
- `/mnt/usb/ft_usb_build/device0_manual_test_20260106_164228.log` - Device0 test (success, 1 neighbor)
- `/mnt/usb/ft_usb_build/client_manual_test_Device4_20260106_163856.log` - Device4 test (failed, RF-kill)
- `/mnt/usb/ft_usb_build/client_manual_test_Device4_20260106_164657.log` - Device4 test (success after fix)

## References

### RF-kill Documentation
- `man rfkill` - RF-kill command documentation
- `/sys/class/rfkill/` - RF-kill kernel interface
- `rfkill list` - Show all RF-kill devices and their state

### BATMAN-adv
- `batctl n` - Show mesh neighbors
- `batctl if` - Show batman-adv interfaces
- `iw dev wlan0 info` - Show wireless interface info (includes IBSS mode)

## Status

- ✅ Root cause identified (RF-kill blocking)
- ✅ Build script fixed (client_phases/phase4_mesh.sh)
- ✅ Fix script created for existing devices
- ✅ Device4 tested and confirmed working
- ⏳ Remaining: Apply fix to Device1, Device2, Device3, Device5
