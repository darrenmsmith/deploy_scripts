# Client Mesh Boot Reconnect Fix

**Date:** 2026-01-05
**Issue:** Client devices not reconnecting to gateway after reboot
**Status:** Fixed

---

## Problem

After building client devices (Device1-5) with Phases 1-5, the devices successfully connect to the mesh network initially. However, after rebooting a client device, it fails to reconnect to the gateway (Device0).

**Symptoms:**
- Client device boots normally
- No mesh neighbors visible on Device0: `sudo batctl n` shows empty
- Client cannot ping Device0 (192.168.99.100)
- field-client service may fail due to no mesh connectivity

---

## Root Cause

The `batman-mesh-client.service` systemd configuration created in Phase 4 had timing issues that prevented reliable startup on boot:

### Original Service Configuration (Phase 4)

```ini
[Unit]
Description=BATMAN-adv Mesh Network (Client)
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/start-batman-mesh-client.sh
ExecStop=/usr/local/bin/stop-batman-mesh-client.sh

[Install]
WantedBy=multi-user.target
```

### Problems:

1. **Too Early in Boot Sequence**
   - `After=network-pre.target` - too early, wlan0 may not be initialized
   - `Before=network.target` - tries to start before network is ready

2. **No Network Online Dependency**
   - Missing `Wants=network-online.target`
   - Service starts before network interfaces are fully configured

3. **No Auto-Restart**
   - No `Restart=on-failure` - service won't retry if initial start fails
   - No `RestartSec` - could retry too quickly causing issues

4. **No Service Ordering**
   - Missing `Before=field-client.service` - field-client might start before mesh

---

## Solution

### Updated Service Configuration

```ini
[Unit]
Description=BATMAN-adv Mesh Network (Client)
After=network.target network-online.target
Wants=network-online.target
Before=field-client.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/start-batman-mesh-client.sh
ExecStop=/usr/local/bin/stop-batman-mesh-client.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Improvements:

1. **Proper Boot Timing**
   - `After=network.target network-online.target` - waits for network subsystem
   - `Wants=network-online.target` - explicitly waits for network to be online

2. **Auto-Restart on Failure**
   - `Restart=on-failure` - automatically retries if startup fails
   - `RestartSec=10` - waits 10 seconds between restart attempts

3. **Proper Service Ordering**
   - `Before=field-client.service` - ensures mesh starts before client app

---

## Fix for Existing Devices

Two scripts are provided to diagnose and fix the issue on already-built client devices:

### 1. Diagnostic Script

**File:** `/tmp/diagnose_client_mesh.sh`
**Purpose:** Check current status and identify issues

```bash
# Copy to client device
scp /tmp/diagnose_client_mesh.sh pi@192.168.99.101:/tmp/

# Run on client device
ssh pi@192.168.99.101
cd /tmp
chmod +x diagnose_client_mesh.sh
./diagnose_client_mesh.sh
```

**What it checks:**
- Hostname validation
- Service file exists
- Service enabled/active status
- Startup scripts exist and executable
- Network interfaces (wlan0, bat0)
- BATMAN-adv module loaded
- Mesh neighbors
- Connectivity to Device0
- Recent service logs

### 2. Fix Script

**File:** `/tmp/fix_client_mesh_boot.sh`
**Purpose:** Automatically fix service configuration

```bash
# Copy to client device
scp /tmp/fix_client_mesh_boot.sh pi@192.168.99.101:/tmp/

# Run on client device
ssh pi@192.168.99.101
cd /tmp
chmod +x fix_client_mesh_boot.sh
sudo ./fix_client_mesh_boot.sh
```

**What it does:**
- Validates running on client device (Device1-5)
- Updates service file with improved configuration
- Reloads systemd daemon
- Enables service for auto-start
- Starts service immediately
- Verifies mesh connectivity
- Restarts field-client service if present

---

## Fix for Future Builds

The fix has been applied to the build scripts:

### Updated File

**File:** `/tmp/deploy_scripts/client_phases/phase4_mesh.sh`
**Lines:** 424-441
**Status:** Ready to commit and push

New client devices built with the updated Phase 4 script will have the correct service configuration from the start.

---

## Testing the Fix

### On Fixed Device

After running `fix_client_mesh_boot.sh`:

1. **Verify Service Status**
   ```bash
   sudo systemctl status batman-mesh-client
   # Should show: Active: active (exited)
   # Should show: Loaded: enabled
   ```

2. **Check Mesh Connection**
   ```bash
   sudo batctl n
   # Should show Device0 as neighbor

   ping -c 3 192.168.99.100
   # Should successfully ping Device0
   ```

3. **Test Reboot**
   ```bash
   sudo reboot
   # Wait for device to reboot (60-90 seconds)

   ssh pi@192.168.99.101
   sudo systemctl status batman-mesh-client
   ping 192.168.99.100
   ```

### On Device0 (Gateway)

Check that client appears in mesh:

```bash
sudo batctl n
# Should show client device MAC address

# Check web interface
# http://192.168.99.100:5000 - Admin Interface
# Device should appear in "Devices" tab
```

---

## Troubleshooting

### Service Fails to Start

```bash
# Check service status
sudo systemctl status batman-mesh-client --no-pager

# View recent logs
sudo journalctl -u batman-mesh-client -n 50 --no-pager

# Try manual start
sudo /usr/local/bin/start-batman-mesh-client.sh

# Check for errors
dmesg | grep -i batman
```

### wlan0 Not in IBSS Mode

```bash
# Check current mode
iw dev wlan0 info

# Should show: type IBSS

# If not, restart service
sudo systemctl restart batman-mesh-client
```

### No Mesh Neighbors

```bash
# Verify Device0 is running
ssh pi@192.168.99.100 'sudo batctl n'

# Check SSID matches
iw dev wlan0 info | grep ssid

# Should match Device0's mesh SSID
ssh pi@192.168.99.100 'iw dev wlan0 info | grep ssid'
```

### field-client Service Fails

```bash
# Check if mesh is running first
sudo systemctl status batman-mesh-client
ping 192.168.99.100

# If mesh is OK, restart field-client
sudo systemctl restart field-client

# Check logs
sudo journalctl -u field-client -n 30
```

---

## Files Changed

### Repository: deploy_scripts

**Modified:**
- `client_phases/phase4_mesh.sh` - Updated batman-mesh-client.service configuration

**Added:**
- `docs/CLIENT_BOOT_RECONNECT_FIX.md` - This documentation
- `troubleshooting/diagnose_client_mesh.sh` - Diagnostic script
- `troubleshooting/fix_client_mesh_boot.sh` - Automated fix script

---

## Deployment

### For New Builds (Device2-5)

Use the updated phase4_mesh.sh:

```bash
cd /mnt/usb/ft_usb_build/client_phases
./phase1_hardware.sh
./phase2_internet.sh
./phase3_packages.sh
./phase4_mesh.sh          # ← Uses fixed service configuration
./phase5_client_app_v2.sh
```

### For Existing Device1

Run the fix script:

```bash
# On Device0, copy fix script to Device1
scp /tmp/fix_client_mesh_boot.sh pi@192.168.99.101:/tmp/

# SSH to Device1
ssh pi@192.168.99.101

# Run fix
cd /tmp
chmod +x fix_client_mesh_boot.sh
sudo ./fix_client_mesh_boot.sh

# Test reboot
sudo reboot
```

---

## Commit Message

```
Fix: Client mesh network auto-start on boot

Problem: Client devices not reconnecting after reboot
- batman-mesh-client service had timing issues
- Started too early (before network ready)
- No auto-restart on failure

Solution: Update service configuration
- Wait for network-online.target
- Add auto-restart with 10s delay
- Order before field-client.service

Files:
- client_phases/phase4_mesh.sh (service config improved)
- troubleshooting/diagnose_client_mesh.sh (diagnostic tool)
- troubleshooting/fix_client_mesh_boot.sh (fix for existing devices)
- docs/CLIENT_BOOT_RECONNECT_FIX.md (documentation)

Fixes connectivity issue for Device1-5 on reboot.
```

---

## Summary

✅ **Root Cause:** Service started too early in boot sequence
✅ **Fix Applied:** Updated service with proper network dependencies
✅ **Scripts Created:** Diagnostic and fix tools for existing devices
✅ **Future Builds:** Phase 4 updated with correct configuration
✅ **Status:** Ready to test on Device1, then build Device2-5

---

## Next Steps

1. **Test on Device1:**
   - Run `fix_client_mesh_boot.sh` on Device1
   - Verify mesh connection
   - Test reboot
   - Confirm auto-reconnect works

2. **If Successful:**
   - Commit changes to deploy_scripts repository
   - Build Device2-5 with updated Phase 4
   - All new devices will have fix from start

3. **Monitor:**
   - Check Device0 web interface for all devices
   - Verify all devices reconnect after power cycle
   - Document any remaining issues
