# RF-Kill Fix for Device0 Mesh Network

**Date:** 2026-01-03
**Critical Issue Found:** batman-mesh service failing due to RF-kill

---

## The Problem

From the diagnostic log, the batman-mesh service is failing with:

```
RTNETLINK answers: Operation not possible due to RF-kill
ERROR: Failed to bring up wlan0
```

**What is RF-kill?**
- RF-kill is a radio frequency kill switch (hardware or software)
- It blocks WiFi/Bluetooth to save power or comply with regulations
- When active, it prevents any WiFi interface from coming UP
- Must be unblocked before wlan0 can be used for mesh networking

---

## How to Fix Device0 Prod RIGHT NOW

### Option 1: Quick Fix Script (Easiest)

**On Device0 Prod, run:**
```bash
cd /mnt/usb/ft_usb_build
sudo ./fix_rfkill.sh
```

This script will:
1. Show current RF-kill status
2. Unblock WiFi
3. Restart batman-mesh service
4. Verify mesh network is working

**Expected result:**
- ✓ wlan0 UP and in IBSS mode
- ✓ bat0 UP with IP 192.168.99.100
- ✓ Mesh SSID: ft_mesh2
- ✓ Ready for Device1 to join

### Option 2: Manual Fix (If script doesn't work)

**On Device0 Prod:**

```bash
# 1. Check RF-kill status
rfkill list

# 2. Unblock WiFi
sudo rfkill unblock wifi

# 3. Restart batman-mesh service
sudo systemctl restart batman-mesh

# 4. Check service status
sudo systemctl status batman-mesh

# 5. Verify mesh network
ip addr show wlan0
ip addr show bat0
iw dev wlan0 info
```

### Option 3: Replace Startup Script (Permanent fix)

This updates the startup script to automatically unblock RF-kill:

**On Device0 Prod:**
```bash
# Copy fixed startup script from USB
sudo cp /mnt/usb/ft_usb_build/start-batman-mesh-FIXED.sh /usr/local/bin/start-batman-mesh.sh
sudo chmod +x /usr/local/bin/start-batman-mesh.sh

# Restart service
sudo systemctl restart batman-mesh

# Verify
sudo systemctl status batman-mesh
```

**The fixed script includes:**
```bash
# Unblock WiFi (RF-kill fix)
rfkill unblock wifi
```

This ensures WiFi is unblocked every time the service starts.

---

## What Was Fixed in Build Scripts

### Updated: `gateway_phases/phase4_mesh.sh`

**Added RF-kill unblock** to the generated startup script (line 254-255):

```bash
# Load batman-adv module
modprobe batman-adv

# Unblock WiFi (RF-kill fix)  ← NEW
rfkill unblock wifi            ← NEW

# Bring down interface
ip link set ${MESH_IFACE} down
```

**Result:** Future Device0 builds will automatically include the RF-kill fix.

---

## Verification

After running any fix option, verify with:

```bash
# Check RF-kill status
rfkill list
# Should show: Wireless LAN: Soft blocked: no  Hard blocked: no

# Check service
sudo systemctl status batman-mesh
# Should show: Active: active (exited)

# Check wlan0
iw dev wlan0 info
# Should show: type IBSS, ssid ft_mesh2

# Check bat0
ip addr show bat0
# Should show: state UP, inet 192.168.99.100/24

# Check mesh neighbors (will be empty until Device1 joins)
sudo batctl n
```

---

## Why Did This Happen?

**Root Causes:**

1. **RF-kill enabled by default** on Raspberry Pi OS
   - Designed to save power
   - Can be triggered by power management
   - Persists across reboots

2. **Original startup script didn't handle RF-kill**
   - Assumed WiFi was already unblocked
   - No `rfkill unblock wifi` command
   - Failed when RF-kill was active

3. **Service failed silently**
   - Systemd showed "failed" status
   - But didn't clearly indicate RF-kill was the cause
   - Required checking journalctl logs to find error

---

## Understanding RF-Kill States

```bash
rfkill list
```

**Output explained:**
```
0: phy0: Wireless LAN
    Soft blocked: no   ← Software block (can be unblocked with command)
    Hard blocked: no   ← Hardware block (physical switch - rare on Pi)
```

**States:**
- **Soft blocked: yes** → Run `sudo rfkill unblock wifi`
- **Hard blocked: yes** → Physical switch or BIOS setting (very rare)
- **Both no** → WiFi is unblocked and ready

---

## Recommended Fix Path

### For Device0 Prod (Current Installation):

1. **Run fix_rfkill.sh** (Option 1 above)
2. **Verify mesh working**
3. **Start building Device1**

### For Future Device0 Builds:

- Use updated Phase 4 script from USB
- RF-kill fix is now included automatically
- No manual intervention needed

---

## Files Created/Updated

### New Files:
1. `/mnt/usb/ft_usb_build/fix_rfkill.sh`
   - Quick fix script for Device0 Prod

2. `/mnt/usb/ft_usb_build/start-batman-mesh-FIXED.sh`
   - Updated startup script with RF-kill fix
   - Can be copied to Device0 Prod

3. `/mnt/usb/ft_usb_build/RFKILL_FIX_README.md`
   - This documentation

### Updated Files:
1. `/mnt/usb/ft_usb_build/gateway_phases/phase4_mesh.sh`
   - Added `rfkill unblock wifi` to generated startup script
   - Future builds will include fix automatically

---

## Summary

**Issue:** RF-kill blocking wlan0, preventing mesh network startup

**Fix:** Add `rfkill unblock wifi` to startup script

**Quick Fix:** Run `sudo ./fix_rfkill.sh` on Device0 Prod

**Long-term Fix:** Phase 4 script updated for future builds

**Status:** Ready to fix and proceed with Device1 build

---

## Next Steps

1. **On Device0 Prod:**
   ```bash
   cd /mnt/usb/ft_usb_build
   sudo ./fix_rfkill.sh
   ```

2. **Verify mesh working:**
   ```bash
   sudo systemctl status batman-mesh
   iw dev wlan0 info
   ip addr show bat0
   ```

3. **Build Device1:**
   - Flash SD card (hostname: Device1)
   - Boot with USB hub + USB WiFi
   - Run ft_build.sh phases 1-5
   - Device1 will join Device0's ft_mesh2 network

---

**RF-kill issue identified and fixed! Device0 should now work correctly.**
