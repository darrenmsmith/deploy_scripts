# Field Trainer Troubleshooting Scripts Index

**Last Updated:** 2026-01-05

This directory contains various troubleshooting and fix scripts for the Field Trainer system. Use this index to find the right script for your issue.

---

## Client Device Issues (Device1-5)

### 🔴 CRITICAL: Client Can't Connect to Device0 Mesh (BSSID Mismatch)

**Problem:** Clients never connect to Device0, no neighbors visible on either side

**Root Cause:** Device0 startup script has placeholder BSSID `00:11:22:33:44:55` but Device0 is actually using `b8:27:eb:3e:4a:99`. Clients try to join the wrong BSSID!

**Fix Script:**
```bash
# Copy to client
scp /mnt/usb/ft_usb_build/fix_client_bssid.sh pi@192.168.99.101:/tmp/

# Run on client
ssh pi@192.168.99.101
cd /tmp
sudo ./fix_client_bssid.sh
```

**What it does:**
- Updates client BSSID from `00:11:22:33:44:55` to `b8:27:eb:3e:4a:99`
- Updates SSID to `ft_mesh2`
- Updates frequency to `2412`
- Restarts service and verifies connection

**Documentation:** `DEVICE0_BSSID_MISMATCH.md`

**MUST RUN THIS ON ALL CLIENTS (Device1-5) before they can connect!**

---

### ⚠️ Client Not Reconnecting After Reboot

**Problem:** Client device connected initially but won't reconnect after reboot

**Diagnostic Script:**
```bash
./diagnose_client_mesh.sh
```
- Checks service status
- Verifies network configuration
- Shows mesh neighbors
- Tests connectivity to Device0

**Fix Script:**
```bash
sudo ./fix_client_mesh_boot.sh
```
- Updates systemd service configuration
- Fixes boot timing issues
- Enables auto-restart on failure
- **Run this on the client device (Device1-5)**

**Documentation:** `CLIENT_BOOT_RECONNECT_FIX.md`

---

### Phase 5 Issues (Client Application)

**Problem:** Phase 5 fails or asks for sudo password multiple times

**Diagnostic Script:**
```bash
./check_phase5_error.sh
```

**Fix Script:**
```bash
./fix_phase5_dnsmasq.sh
```

**Documentation:** `PHASE5_SUDO_FIX.md`, `PHASE5_FIX_README.md`

**Updated Script:** Use `client_phases/phase5_client_app_v2.sh` (only 3 sudo prompts)

---

## Gateway Issues (Device0)

### Device0 Mesh Network Not Starting

**Problem:** Device0 mesh network won't start after boot

**Diagnostic Script:**
```bash
./diagnose_device0_mesh.sh
```
- Checks batman-mesh service
- Verifies wlan0 configuration
- Shows mesh status

**Fix Script:**
```bash
sudo ./fix_device0_mesh.sh
```
- Fixes batman-mesh startup script
- Updates service configuration
- Resolves rfkill issues

**Documentation:** `DEVICE0_MESH_FIX_README.md`, `RFKILL_FIX_README.md`

---

### Port 5001 Coach Interface Not Working

**Problem:** Can access Admin (port 5000) but not Coach interface (port 5001)

**Diagnostic Script:**
```bash
./diagnose_port5001_failure.sh
```

**Fix Scripts:**
```bash
./fix_coach_interface_port5001.sh    # Fix service startup
./fix_coach_interface_file.sh        # Replace broken file
```

**Documentation:** `COACH_INTERFACE_FIX_SUMMARY.md`, `PORT_5001_FIX_README.md`

---

## Build Process Scripts

### Complete Build Scripts

**Gateway Build:**
```bash
cd gateway_phases
./phase1_gateway_base.sh      # Base system setup
./phase2_gateway_network.sh   # Network configuration
./phase3_gateway_mesh.sh      # Mesh network
./phase4_gateway_app.sh       # Field Trainer application
```

**Client Build:**
```bash
cd client_phases
./phase1_hardware.sh           # Hardware setup
./phase2_internet.sh           # Internet connection
./phase3_packages.sh           # Install packages
./phase4_mesh.sh               # Mesh network (UPDATED 2026-01-05)
./phase5_client_app_v2.sh      # Client application (v2 recommended)
```

---

## Diagnostic and Verification Scripts

### General System Verification

```bash
./verify_all_devices.sh         # Check all devices in system
./verify_fix_status.sh          # Verify fixes have been applied
./check_field_trainer_app.sh    # Check field trainer app status
```

### Network and Mesh Debugging

```bash
./debug_batman_service.sh       # Debug batman-adv service
./capture_batman_error.sh       # Capture batman error logs
```

---

## Recent Fixes (2026-01-05)

### ✅ Client Boot Reconnect Fix
- **Issue:** Clients not reconnecting after reboot
- **Scripts:** `fix_client_mesh_boot.sh`, `diagnose_client_mesh.sh`
- **Status:** Fixed in `client_phases/phase4_mesh.sh`
- **Documentation:** `CLIENT_BOOT_RECONNECT_FIX.md`

### ✅ Phase 5 Sudo Password Fix
- **Issue:** Multiple sudo password prompts
- **Script:** `client_phases/phase5_client_app_v2.sh`
- **Status:** v2 uses heredoc approach (3 prompts max)
- **Documentation:** `PHASE5_SUDO_FIX.md`

### ✅ Coach Interface Port 5001 Fix
- **Issue:** Port 5001 not accessible
- **Scripts:** Multiple fix scripts
- **Status:** Fixed in v2026.01.04 release
- **Documentation:** `COACH_INTERFACE_FIX_SUMMARY.md`

---

## How to Use These Scripts

### On Client Devices (Device1-5)

**From USB Drive:**
```bash
# Copy to client device
scp /mnt/usb/ft_usb_build/fix_client_mesh_boot.sh pi@192.168.99.101:/tmp/

# Run on client device
ssh pi@192.168.99.101
cd /tmp
chmod +x fix_client_mesh_boot.sh
sudo ./fix_client_mesh_boot.sh
```

**Direct on Device:**
```bash
# Mount USB drive on client
sudo mount /dev/sda1 /mnt/usb

# Run script
cd /mnt/usb/ft_usb_build
sudo ./fix_client_mesh_boot.sh
```

### On Gateway (Device0)

Most Device0 scripts can be run directly:
```bash
cd /mnt/usb/ft_usb_build
sudo ./fix_device0_mesh.sh
```

---

## Complete Build Guides

- `COMBINED_BUILD_GUIDE.md` - Complete step-by-step build process
- `DEVICE2-5_BUILD_CHECKLIST.md` - Checklist for building client devices
- `FRESH_INSTALL_GUIDE.md` - Fresh installation from scratch
- `QUICK_START_GUIDE.md` - Quick reference guide

---

## Support Documentation

### Network and WiFi Fixes
- `WIFI_INTERFACE_FIX_SUMMARY.md`
- `DHCPCD_DEATH_FIX_COMPLETE.md`
- `WLAN1_CONNECTION_STABILITY_ANALYSIS.md`
- `NETWORKMANAGER_REMOVED.md`

### Phase-Specific Troubleshooting
- `PHASE1.5_DEPENDENCY_FIX.md`
- `PHASE2_FIXES_APPLIED.md`
- `PHASE3_DHCPCD_KEEPALIVE_FIX.md`
- `PHASE5_PHASE6_FIXES.md`

### Release Information
- `RELEASE_v2026.01.04_SUMMARY.md` - Latest release notes
- `DEPLOY_SCRIPTS_PUSH_SUMMARY.md` - Deployment information
- `RELEASE_PREPARATION.md` - Release preparation guide

---

## Quick Problem Finder

**Problem** → **Script to Run**

| Problem | Diagnostic Script | Fix Script | Documentation |
|---------|------------------|------------|---------------|
| Client can't connect - BSSID mismatch | `get_device0_mesh_config.sh` | `fix_client_bssid.sh` | `DEVICE0_BSSID_MISMATCH.md` |
| Client won't reconnect after reboot | `diagnose_client_mesh.sh` | `fix_client_mesh_boot.sh` | `CLIENT_BOOT_RECONNECT_FIX.md` |
| Device0 mesh won't start | `diagnose_device0_mesh.sh` | `fix_device0_mesh.sh` | `DEVICE0_MESH_FIX_README.md` |
| Port 5001 not working | `diagnose_port5001_failure.sh` | `fix_coach_interface_port5001.sh` | `COACH_INTERFACE_FIX_SUMMARY.md` |
| Phase 5 multiple passwords | N/A | Use `phase5_client_app_v2.sh` | `PHASE5_SUDO_FIX.md` |
| WiFi not persistent | N/A | Documented fix | `WIFI_PERSISTENCE_FIX.md` |
| dhcpcd keeps dying | N/A | `fix_phase5_dnsmasq.sh` | `DHCPCD_DEATH_FIX_COMPLETE.md` |

---

## Getting Help

1. **Identify the problem** - Use diagnostic scripts first
2. **Check documentation** - Read relevant .md files
3. **Run fix script** - Apply the fix for your issue
4. **Verify the fix** - Test that the issue is resolved
5. **Check logs** - Review logs if problems persist:
   - `sudo journalctl -u batman-mesh-client -n 50`
   - `sudo journalctl -u field-client -n 50`
   - `sudo journalctl -u field-trainer-server -n 50`

---

**Note:** All scripts are on the USB drive and can be copied to devices as needed. Always run diagnostic scripts before applying fixes to understand what's wrong.
