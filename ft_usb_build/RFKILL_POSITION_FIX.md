# RF-Kill Position Fix - Root Cause Analysis

## The Problem

**Symptoms:**
- Device4: Works after `systemctl restart` but fails after reboot
- Device5: Works after reboot
- Both devices have identical startup scripts

## Investigation Results

Compared diagnostic logs from Device4 (broken) vs Device5 (working):

### Device4 After Reboot (BROKEN):
```
phy0: Wireless LAN
    Soft blocked: YES    ← RF-kill STILL BLOCKING!

wlan0: state DOWN
wlan0: type managed     ← Should be IBSS!
batman-adv: wlan0: inactive
batman-adv: Interface deactivated: wlan0
```

### Device5 After Reboot (WORKING):
```
phy0: Wireless LAN
    Soft blocked: NO     ← RF-kill successfully unblocked

wlan0: state UP
wlan0: type IBSS         ← Correct!
batman-adv: wlan0: active
```

## Root Cause

The first `fix_client_rfkill.sh` placed `rfkill unblock wifi` in the WRONG position:

### WRONG Order (First Fix Attempt):
```bash
# Load batman-adv module
modprobe batman-adv

# Bring down interface
ip link set ${MESH_IFACE} down

# Set interface to IBSS (Ad-hoc) mode
# Unblock RF-kill if blocked
rfkill unblock wifi      ← TOO LATE! Interface already down

iw dev ${MESH_IFACE} set type ibss
```

**Problem:** When you run `rfkill unblock wifi` AFTER bringing the interface down, the RF-kill block can persist because the interface isn't active to respond to the unblock command.

### CORRECT Order (Gateway Script):
```bash
# Load batman-adv module
modprobe batman-adv

# Unblock WiFi (RF-kill fix)
rfkill unblock wifi      ← FIRST, before touching interface!

# Bring down interface
ip link set ${MESH_IFACE} down

# Set interface to IBSS (Ad-hoc) mode
iw dev ${MESH_IFACE} set type ibss
```

**Why this works:** RF-kill is unblocked while the WiFi subsystem is fully initialized and can respond to the unblock command.

## Why Device5 Worked But Device4 Didn't

Looking at Device5's boot logs revealed it ALSO failed on first attempt:

```
Jan 07 01:04:35 Device5: RTNETLINK answers: Operation not possible due to RF-kill
Jan 07 01:04:35 Device5: command failed: Network is down (-100)
Jan 07 01:04:36 Device5: BATMAN mesh started on wlan0
```

But then the service was RESTARTED:

```
Jan 07 01:29:44 Device5 systemd[1]: Stopped batman-mesh-client.service
Jan 07 01:29:44 Device5 systemd[1]: Starting batman-mesh-client.service...
Jan 07 01:29:44 Device5 rfkill[861]: unblock set for type wifi
Jan 07 01:29:45 Device5: BATMAN mesh started on wlan0
```

**Device5:** Service failed, got restarted (manually or by systemd), worked on second try
**Device4:** Service failed once, never retried, stayed broken

## The Fix

### For Existing Devices (Device1-5)

Run the CORRECTED fix script:

```bash
# Move USB to client device
sudo /mnt/usb/ft_usb_build/fix_client_rfkill.sh
```

This script:
1. Removes any existing (incorrectly positioned) `rfkill unblock` lines
2. Adds `rfkill unblock wifi` in the CORRECT position (after modprobe, before ip link down)
3. Verifies the fix
4. Provides instructions for testing

### For Future Builds

The build script `/tmp/deploy_scripts/client_phases/phase4_mesh.sh` has been updated (commit 0d325ce) to generate startup scripts with the correct order matching the gateway script.

## Verification Steps

### On Device4 (After Running Fix):

1. **Apply the fix:**
   ```bash
   sudo /mnt/usb/ft_usb_build/fix_client_rfkill.sh
   ```

2. **Test with restart:**
   ```bash
   sudo systemctl restart batman-mesh-client.service
   sudo batctl n              # Should show Device0
   ping 192.168.99.100        # Should work
   ```

3. **Test with reboot (THE CRITICAL TEST):**
   ```bash
   sudo reboot
   ```

4. **After reboot, verify:**
   ```bash
   rfkill list                # phy0 should show "Soft blocked: no"
   iw dev wlan0 info          # Should show "type IBSS"
   ip link show wlan0         # Should show "state UP"
   sudo batctl if             # Should show "wlan0: active"
   sudo batctl n              # Should show Device0 as neighbor
   ping 192.168.99.100        # Should succeed
   ```

## Expected Startup Script After Fix

```bash
#!/bin/bash

# Field Trainer - Client Mesh Startup Script
# Device4 - IP: 192.168.99.104

MESH_IFACE="wlan0"
MESH_SSID="ft_mesh2"
MESH_FREQ="2412"
MESH_BSSID="b8:27:eb:3e:4a:99"
DEVICE_IP="192.168.99.104"

# Load batman-adv module
modprobe batman-adv

# Unblock WiFi (RF-kill fix)
rfkill unblock wifi

# Bring down interface
ip link set ${MESH_IFACE} down

# Set interface to IBSS (Ad-hoc) mode
iw dev ${MESH_IFACE} set type ibss

# Bring interface up
ip link set ${MESH_IFACE} up

# Join IBSS network
iw dev ${MESH_IFACE} ibss join ${MESH_SSID} ${MESH_FREQ} fixed-freq ${MESH_BSSID}

# Add interface to batman-adv
batctl if add ${MESH_IFACE}

# Bring up bat0 interface
ip link set bat0 up

# Assign IP to bat0
ip addr add ${DEVICE_IP}/24 dev bat0

echo "BATMAN mesh started on ${MESH_IFACE}"
echo "Device IP: ${DEVICE_IP}"
```

## Why Restart Worked But Reboot Failed

**Service Restart:**
- System fully booted, all subsystems initialized
- WiFi driver loaded and ready
- RF-kill subsystem responsive
- Even with wrong order, RF-kill unblock might work because timing is different

**Reboot:**
- Services start in parallel during boot
- Precise timing matters
- If RF-kill unblock runs while interface is down, it may not take effect
- No retry, service reports success even though mesh is broken

## Lessons Learned

1. **Order matters:** System initialization commands must run in the right sequence
2. **Test boot behavior:** Always test with full reboot, not just service restart
3. **Compare working vs broken:** Device5 logs revealed it also had issues but recovered
4. **Match working patterns:** Gateway script had the correct order all along
5. **Verify at multiple levels:** Check RF-kill status, interface state, batman-adv status, AND connectivity

## Files Updated

- `/mnt/usb/ft_usb_build/fix_client_rfkill.sh` - Corrected fix script
- `/tmp/deploy_scripts/client_phases/phase4_mesh.sh` - Build script (commit 0d325ce)

## Status

- ✅ Root cause identified (wrong command order)
- ✅ Build script corrected for future builds
- ✅ Fix script corrected for existing devices
- ⏳ Device4 needs corrected fix applied and tested with reboot
- ⏳ Device1, Device2, Device3 need same fix
- ✅ Device5 already working (likely due to timing or manual restart)
