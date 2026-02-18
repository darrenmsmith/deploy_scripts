# Phase 4 Script Updated - NetworkManager Fix

## Date: 2026-01-07

## Problem Identified

NetworkManager was interfering with the mesh network by:
1. Managing wlan0 interface
2. Resetting wlan0 from IBSS mode back to managed mode after boot
3. Preventing mesh network from forming correctly

## Root Cause

- NetworkManager is installed and enabled on client devices
- Without proper configuration, it tries to manage all WiFi interfaces
- Even when wlan0 is set to IBSS mode during boot, NetworkManager resets it to managed mode
- This breaks the BATMAN-adv mesh network

## Solution Implemented

Updated `/mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh` to:

### 1. New Step 4: Disable NetworkManager WiFi Interference

During Phase 4 deployment, the script now:

**A. Disables WiFi in NetworkManager globally:**
```bash
nmcli radio wifi off
```

This prevents NetworkManager from:
- Scanning for WiFi networks
- Managing wlan0 at any level
- Interfering with IBSS mode

**B. Creates backup unmanaged configuration:**
```bash
/etc/NetworkManager/conf.d/99-unmanage-wlan0.conf
```

This marks wlan0 and bat0 as unmanaged interfaces (belt-and-suspenders approach).

**C. Restarts NetworkManager to apply configuration**

### 2. Updated Mesh Startup Script

The `/usr/local/bin/start-batman-mesh-client.sh` script (created during Phase 4) now includes:

**A. NetworkManager WiFi disable on every boot:**
```bash
if command -v nmcli &>/dev/null; then
    nmcli radio wifi off 2>/dev/null || true
fi
```

**B. RF-kill unblock (also required):**
```bash
rfkill unblock all 2>/dev/null || true
rfkill unblock wifi 2>/dev/null || true
```

This ensures that even after reboot:
- NetworkManager WiFi stays disabled
- RF-kill doesn't block the WiFi hardware
- wlan0 stays in IBSS mode
- Mesh network forms correctly

### 3. Step Numbers Renumbered

All subsequent steps were renumbered:
- Old Step 4 (Load BATMAN-adv) → New Step 5
- Old Step 5 (Configure IBSS) → New Step 6
- Old Step 6 (Join IBSS) → New Step 7
- Old Step 7 (Add to BATMAN) → New Step 8
- Old Step 8 (Bring up bat0) → New Step 9
- Old Step 9 (Assign IP) → New Step 10
- Old Step 10 (Test connection) → New Step 11
- Old Step 11 (Check neighbors) → New Step 12
- Old Step 12 (Create service) → New Step 13
- Old Step 13 (Create startup script) → New Step 14
- Old Step 14 (Create shutdown script) → New Step 15
- Old Step 15 (Enable service) → New Step 16

## How This Works

### Device5 Configuration (Working)
Device5 was working because:
```
nmcli general status:
WIFI: disabled  ← NetworkManager WiFi is disabled

nmcli device status:
wlan0  wifi  unavailable  ← NetworkManager ignoring wlan0
```

### Device4 Configuration (Was Broken, Now Fixed)
Before fix:
```
nmcli general status:
WIFI: enabled  ← NetworkManager trying to manage WiFi

nmcli device status:
wlan0  wifi  disconnected  ← NetworkManager managing wlan0
```

After Phase 4 rebuild with updated script:
```
nmcli general status:
WIFI: disabled  ← Like Device5

nmcli device status:
wlan0  wifi  unavailable  ← Like Device5
```

## Testing Instructions

### Build Device4 from Scratch

1. **Wipe Device4** (optional but recommended for clean test):
   ```bash
   # Back up any important data first!
   # Then re-image SD card with base Raspberry Pi OS
   ```

2. **Run all phases with updated scripts**:
   ```bash
   # Phase 1: Hostname
   sudo /mnt/usb/ft_usb_build/client_phases/phase1_hostname.sh

   # Phase 2: Network
   sudo /mnt/usb/ft_usb_build/client_phases/phase2_network.sh

   # Phase 3: Packages
   sudo /mnt/usb/ft_usb_build/client_phases/phase3_packages.sh

   # Phase 4: Mesh (NOW INCLUDES NETWORKMANAGER FIX)
   sudo /mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh

   # Phase 5: Client Application
   sudo /mnt/usb/ft_usb_build/client_phases/phase5_client_app.sh
   ```

3. **After Phase 4 completes**, verify NetworkManager is configured:
   ```bash
   nmcli general status    # WiFi should show "disabled"
   nmcli device status     # wlan0 should show "unavailable"
   ls -l /etc/NetworkManager/conf.d/99-unmanage-wlan0.conf  # Should exist
   ```

4. **Verify mesh is working**:
   ```bash
   iw dev wlan0 info       # Should show "type IBSS", "ssid ft_mesh2"
   sudo batctl if          # Should show "wlan0: active"
   sudo batctl n           # Should show Device0 as neighbor
   ping 192.168.99.100     # Should ping Device0
   ```

5. **Test reboot persistence**:
   ```bash
   sudo reboot
   ```

6. **After reboot, verify again**:
   ```bash
   # Check NetworkManager stayed disabled
   nmcli general status    # WiFi should STILL show "disabled"

   # Check IBSS mode persisted
   iw dev wlan0 info       # Should STILL show "type IBSS"

   # Check mesh reconnected
   sudo batctl n           # Should show Device0 as neighbor
   ping 192.168.99.100     # Should STILL ping Device0
   ```

## Expected Results

After Phase 4 with updated script:
- ✅ NetworkManager WiFi disabled during deployment
- ✅ NetworkManager stays disabled after reboot
- ✅ wlan0 stays in IBSS mode after reboot
- ✅ Mesh network forms correctly on boot
- ✅ Device can see neighbors and ping Device0
- ✅ Connection persists through reboots

## Files Modified

1. `/mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh`
   - Added Step 4: NetworkManager WiFi interference prevention
   - Updated startup script template to include NetworkManager disable
   - Updated startup script template to include RF-kill unblock
   - Renumbered all subsequent steps

## Verification Commands

### Check NetworkManager Status
```bash
systemctl status NetworkManager.service
nmcli general status
nmcli device status
```

### Check NetworkManager Config Files
```bash
ls -l /etc/NetworkManager/conf.d/
cat /etc/NetworkManager/conf.d/99-unmanage-wlan0.conf
```

### Check Mesh Status
```bash
systemctl status batman-mesh-client.service
journalctl -u batman-mesh-client.service -b
iw dev wlan0 info
sudo batctl if
sudo batctl n
ping -c 3 192.168.99.100
```

### Check RF-kill Status
```bash
rfkill list
```

## Troubleshooting

### If mesh still fails after rebuild:

1. **Check NetworkManager WiFi status**:
   ```bash
   nmcli general status
   ```
   If WiFi shows "enabled", manually disable:
   ```bash
   sudo nmcli radio wifi off
   sudo systemctl restart batman-mesh-client.service
   ```

2. **Check for RF-kill blocking**:
   ```bash
   rfkill list
   ```
   If phy0 is soft-blocked:
   ```bash
   sudo rfkill unblock all
   sudo systemctl restart batman-mesh-client.service
   ```

3. **Check startup script was created correctly**:
   ```bash
   cat /usr/local/bin/start-batman-mesh-client.sh
   ```
   Should contain:
   - `nmcli radio wifi off`
   - `rfkill unblock all`
   - `rfkill unblock wifi`

4. **Check logs from deployment**:
   ```bash
   ls -lt /mnt/usb/ft_usb_build/phase4_mesh_Device4_*.log | head -1
   ```
   Review the most recent Phase 4 log to see if NetworkManager was detected and disabled.

## Why This Fix Works

1. **NetworkManager WiFi disabled globally** prevents ANY WiFi management
2. **Backup unmanaged config** ensures wlan0 is marked as unmanaged
3. **Startup script disables WiFi on every boot** ensures persistence
4. **RF-kill unblock** ensures WiFi hardware isn't blocked
5. **Matches Device5 configuration** which is proven to work

## References

- `/mnt/usb/ft_usb_build/NETWORKMANAGER_TRUE_ROOT_CAUSE.md` - Root cause analysis
- `/mnt/usb/ft_usb_build/networkmanager_config_Device5_*.log` - Working Device5 config
- `/mnt/usb/ft_usb_build/ibss_no_connection_Device4_*.log` - Diagnostic logs (if run)

## Next Steps

1. **Rebuild Device4 from scratch** with updated Phase 4 script
2. **Test reboot persistence** to verify fix works
3. **Apply to Device3** once Device4 is confirmed working
4. **Update all other broken clients** (Device1, Device2 if applicable)
5. **Document in deployment guide** that NetworkManager WiFi must be disabled

## Status

- ✅ Phase 4 script updated with NetworkManager fix
- ✅ Startup script template updated
- ✅ RF-kill unblock included
- ⏳ Need to rebuild Device4 from scratch
- ⏳ Need to test reboot persistence
- ⏳ Need to apply to other devices once confirmed

---

**This fix addresses the root cause that has been preventing mesh reconnection after reboot.**
