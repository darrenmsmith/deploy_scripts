# Device0 Mesh Network Fix - README

**Date:** 2026-01-03
**Issue:** Device0 Prod mesh network not working correctly

---

## Problems Found (from diagnostic log)

### 1. wlan0 stuck in "managed" mode instead of "IBSS"
- **Symptom:** wlan0 type is "managed", should be "IBSS" for mesh
- **Cause:** NetworkManager/wpa_supplicant resetting wlan0 after batman-mesh service runs
- **Impact:** Device1 cannot join mesh network

### 2. wlan1 (USB WiFi) is DOWN and not connected
- **Symptom:** wlan1 has no IP address, not connected to home WiFi
- **Cause:** wlan1-wpa/wlan1-dhcp services not starting properly
- **Impact:** No SSH access, no internet

### 3. Interfaces are DOWN
- wlan0: DOWN (should be UP for mesh)
- bat0: DOWN (should be UP with IP 192.168.99.100)

---

## What Was Fixed

### Fix 1: Created `fix_device0_mesh.sh` Script
**Location:** `/mnt/usb/ft_usb_build/fix_device0_mesh.sh`

This script fixes the current Device0 Prod installation:
1. Disables NetworkManager (prevents interference)
2. Masks wpa_supplicant@wlan0 (prevents reset to managed mode)
3. Restarts batman-mesh service
4. Restarts wlan1 services (for SSH/internet)
5. Verifies everything is working

### Fix 2: Updated `gateway_phases/phase4_mesh.sh`
**What changed:** Added new Step 4 that prevents NetworkManager interference

**New Step 4:**
- Stops and disables NetworkManager
- Masks wpa_supplicant@wlan0
- Ensures wlan0 stays in IBSS mode
- wlan1 remains available for internet/SSH

**Result:** Future Device0 builds won't have this problem

---

## How to Fix Device0 Prod NOW

### Option A: Run the Fix Script (Recommended - Quick)

1. **On Device0 Prod:**
   ```bash
   cd /mnt/usb/ft_usb_build
   sudo ./fix_device0_mesh.sh
   ```

2. **Review output:**
   - wlan0 should be in IBSS mode
   - bat0 should be UP with IP 192.168.99.100
   - wlan1 should have IP and internet

3. **If successful:**
   - Device0 is ready for Device1 to join
   - Note the mesh SSID (should be "ft_mesh2")

### Option B: Re-run Phase 4 (Fresh)

If the fix script doesn't work, you can re-run Phase 4:

1. **On Device0 Prod:**
   ```bash
   cd /mnt/usb/ft_usb_build
   sudo ./ft_build.sh
   ```

2. **Choose option 4:** Re-run Current/Previous Phase

3. **Enter phase 4** when prompted

4. **Phase 4 will now:**
   - Disable NetworkManager (new step)
   - Set up mesh properly
   - Keep wlan0 in IBSS mode

### Option C: Fresh Build (Nuclear Option)

If neither works, start completely fresh:
1. Flash new SD card for Device0
2. Use updated scripts from USB
3. Run all phases 1-7

---

## Verification After Fix

Run the diagnostic script to verify:

```bash
cd /mnt/usb/ft_usb_build
sudo ./diagnose_device0_mesh.sh
```

**Look for:**
- ✓ wlan0 type: IBSS
- ✓ wlan0 SSID: ft_mesh2 (or your chosen SSID)
- ✓ bat0 is UP
- ✓ bat0 IP: 192.168.99.100/24
- ✓ wlan1 has IP address
- ✓ Internet working

---

## Why This Happened

**Root Cause:** The original Phase 4 script didn't prevent NetworkManager and wpa_supplicant from managing wlan0.

**What happened:**
1. Phase 4 set wlan0 to IBSS mode ✓
2. batman-mesh service started ✓
3. bat0 created with IP ✓
4. **But then:** NetworkManager/wpa_supplicant reset wlan0 back to "managed" mode ✗
5. Mesh network broken ✗

**The fix:**
- Phase 4 now disables NetworkManager
- Phase 4 now masks wpa_supplicant@wlan0
- wlan0 stays in IBSS mode permanently
- wlan1 remains available for internet

---

## Next Steps After Fix

### 1. Verify Device0 is working:
```bash
sudo ./diagnose_device0_mesh.sh
```

### 2. Start building Device1:
- Flash SD card with hostname "Device1"
- Boot Device1 with USB hub + USB WiFi
- Run ft_build.sh phases 1-5
- Device1 will join Device0's mesh network

### 3. Verify Device1 joined:
On Device0:
```bash
sudo batctl n
```
Should show Device1 as a neighbor

---

## Technical Details

### What NetworkManager/wpa_supplicant Do

**NetworkManager:**
- Automatically manages network interfaces
- Tries to connect WiFi to saved networks
- Resets interfaces to "managed" mode
- **Conflicts with manual IBSS configuration**

**wpa_supplicant:**
- Handles WiFi authentication (WPA/WPA2)
- Also prefers "managed" mode
- **Not needed for IBSS (no authentication)**

### Why wlan0 Must Be Reserved

**wlan0 (onboard WiFi):**
- Must stay in IBSS (ad-hoc) mode
- Used exclusively for BATMAN mesh
- No NetworkManager, no wpa_supplicant
- Managed manually by batman-mesh service

**wlan1 (USB WiFi):**
- Can use "managed" mode (normal WiFi)
- Has wpa_supplicant (for home network auth)
- Used for internet and SSH access
- Managed by wlan1-wpa and wlan1-dhcp services

---

## Files Modified

### New Files:
1. `/mnt/usb/ft_usb_build/fix_device0_mesh.sh`
   - Fix script for Device0 Prod

### Updated Files:
1. `/mnt/usb/ft_usb_build/gateway_phases/phase4_mesh.sh`
   - Added Step 4: Prevent NetworkManager interference
   - Renumbered subsequent steps (now 8 steps total)

### No Changes Needed:
- Phase 2 (wlan1 internet) - already correct
- Other gateway phases - no issues
- Client phases - no issues

---

## Summary

**Problem:** NetworkManager interfering with wlan0 mesh network
**Fix:** Disable NetworkManager, mask wpa_supplicant@wlan0
**Script:** `fix_device0_mesh.sh` fixes current installation
**Phase 4:** Updated to prevent this in future builds

**Status:** Ready to build Device1 after running fix script

---

## Support Commands

### Check Service Status:
```bash
sudo systemctl status batman-mesh
sudo systemctl status wlan1-wpa
sudo systemctl status wlan1-dhcp
```

### Check Interfaces:
```bash
ip addr show wlan0
ip addr show wlan1
ip addr show bat0
iw dev wlan0 info
iw dev wlan1 info
```

### Check Mesh:
```bash
sudo batctl n              # Show neighbors
sudo batctl if             # Show interfaces
ping 192.168.99.100        # Test Device0
```

### Logs:
```bash
sudo journalctl -u batman-mesh -n 50
sudo journalctl -u wlan1-wpa -n 50
sudo journalctl -u wlan1-dhcp -n 50
```

---

**Ready to fix Device0 Prod! Run fix_device0_mesh.sh first.**
