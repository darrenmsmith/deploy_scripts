# Auto-Diagnostics Summary - Build Scripts

**Date:** 2026-01-04
**Purpose:** Document what fixes are in main scripts and what auto-diagnostics run on failure

---

## Question 1: Are Fixes in Main Installation Scripts?

### **YES - All fixes are in `gateway_phases/phase4_mesh.sh`**

| Fix | Location | What It Does |
|-----|----------|--------------|
| **NetworkManager disable** | Step 4 (lines 193-218) | Stops NetworkManager and masks wpa_supplicant@wlan0 to prevent interference with mesh |
| **RF-kill unblock** | Generated startup script (line 255) | Adds `rfkill unblock wifi` to ensure WiFi isn't blocked |
| **Idempotent IP assignment** | Generated startup script (lines 300-310) | Checks if IP exists before adding to prevent "already assigned" error |
| **Idempotent IBSS join** | Generated startup script (line 276) | Leaves IBSS before joining to allow safe re-runs |

**Result:** Future Device0 builds will include ALL fixes automatically - no manual intervention needed!

---

## Question 2: Do Scripts Auto-Run Diagnostics on Failure?

### **YES - Now they do!**

### **Gateway Phase 4 - Auto-Diagnostics on Failure**

**When:** If mesh startup script fails during Step 6 testing
**What happens:**
1. Automatically captures diagnostic information
2. Saves to `/tmp/phase4_mesh_failure_YYYYMMDD_HHMMSS.log`
3. Copies to USB: `/mnt/usb/ft_usb_build/phase4_failure_YYYYMMDD_HHMMSS.log`
4. Shows common troubleshooting steps

**Diagnostic info captured:**
- RF-kill status (is WiFi blocked?)
- wlan0 interface status and wireless info
- bat0 interface status
- batman-adv module and interface status
- Recent system logs related to mesh/batman/wlan0
- Full startup script contents

**User sees:**
```
✗ Mesh startup script failed
⚠ Capturing diagnostic information...
✓ Diagnostics saved to: /tmp/phase4_mesh_failure_20260104_142132.log
✓ Diagnostics copied to USB: phase4_failure_20260104_142132.log

Common issues and fixes:
  1. RF-kill blocking WiFi:
     sudo rfkill unblock wifi
  2. NetworkManager interference:
     sudo systemctl stop NetworkManager
  3. Review diagnostic log above for details
```

### **Client Phase 4 - Comprehensive Auto-Logging**

**Already built-in from enhanced version!**

**What happens:**
1. Creates log file at start: `/tmp/phase4_mesh_YYYYMMDD_HHMMSS.log`
2. ALL output (commands, errors, status) captured with `tee`
3. At end, copies to USB: `/mnt/usb/ft_usb_build/phase4_mesh_DeviceN_YYYYMMDD_HHMMSS.log`
4. Detailed error messages at each failure point
5. Troubleshooting steps shown inline

**What's logged:**
- Every command executed
- All command output (stdout and stderr)
- Status of each of 15 detailed steps
- Diagnostic information at each step
- Exact error messages with troubleshooting

**Example on error:**
```
✗ FAILED TO JOIN IBSS NETWORK

═══ ERROR DETAILS ═══
SSID: ft_mesh2
Frequency: 2412 MHz (Channel 1)
BSSID: 00:11:22:33:44:55

Current wlan0 status:
Interface wlan0
    ifindex 3
    wdev 0x1
    type IBSS
    wiphy 0

═══ TROUBLESHOOTING ═══
1. Verify Device0 mesh is active:
   ssh pi@192.168.99.100 'sudo batctl n'

2. Check Device0 mesh SSID matches:
   ssh pi@192.168.99.100 'iw dev wlan0 info'

3. Common issues:
   - SSID mismatch (must be exact)
   - Channel mismatch
   - Device0 mesh not running

Log saved to: /tmp/phase4_mesh_20260104_142132.log
Copied to USB: /mnt/usb/ft_usb_build/phase4_mesh_Device1_20260104_142132.log
```

---

## Manual Diagnostic Tools (Still Available)

These are ALSO available for manual troubleshooting:

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `diagnose_device0_mesh.sh` | Full Device0 mesh diagnostics | After Device0 Phase 4, before building clients |
| `debug_batman_service.sh` | Debug why batman-mesh service won't start | When systemd service is failing |
| `capture_batman_error.sh` | Capture detailed error info | Troubleshooting service failures |
| `fix_rfkill.sh` | Quick fix for RF-kill blocking WiFi | When RF-kill is the issue |
| `apply_final_fix.sh` | Apply idempotent startup script | Fix "IP already assigned" error |

---

## What Auto-Diagnostics DON'T Cover

**Not automated (you need to run manually):**
- Full system diagnostics after Phase 4 completes successfully
- Periodic health checks of running mesh network
- Troubleshooting after changes to configuration
- Debugging issues that occur days/weeks after installation

**For these, use the manual diagnostic scripts above.**

---

## Summary

### ✓ Fixes in Main Scripts

| Component | Status |
|-----------|--------|
| Gateway Phase 4 | ✓ All 3 fixes included |
| Client Phase 4 | ✓ Enhanced logging built-in |
| Idempotent scripts | ✓ Can run multiple times safely |
| RF-kill handled | ✓ Auto-unblock in startup script |
| NetworkManager disabled | ✓ Prevented from interfering |

### ✓ Auto-Diagnostics on Failure

| Phase | Auto-Diagnostics | Log Location |
|-------|------------------|--------------|
| Gateway Phase 4 | ✓ YES (on Step 6 failure) | `/tmp/phase4_mesh_failure_*.log` → USB |
| Client Phase 4 | ✓ YES (full logging) | `/tmp/phase4_mesh_*.log` → USB |

### ✓ Manual Tools Available

| Tool | Purpose |
|------|---------|
| `diagnose_device0_mesh.sh` | Full mesh diagnostics |
| `debug_batman_service.sh` | Service debugging |
| `capture_batman_error.sh` | Error capture |
| `fix_rfkill.sh` | RF-kill quick fix |
| `apply_final_fix.sh` | Install idempotent script |

---

## How It Works in Practice

### **Scenario 1: Gateway Phase 4 Fails**

```
User runs: sudo ./ft_build.sh
Chooses: Run Next Phase (Phase 4)

Phase 4 runs...
Step 1-5: ✓ All pass
Step 6: Mesh startup test...

✗ Mesh startup script failed
⚠ Capturing diagnostic information...

[Auto-diagnostics run - 6 checks]

✓ Diagnostics saved to: /tmp/phase4_mesh_failure_20260104_142132.log
✓ Diagnostics copied to USB: phase4_failure_20260104_142132.log

Review diagnostics at: /tmp/phase4_mesh_failure_20260104_142132.log

✗ Manual test failed. Please resolve issues before continuing.

Common issues and fixes:
  1. RF-kill blocking WiFi:
     sudo rfkill unblock wifi
  2. NetworkManager interference:
     sudo systemctl stop NetworkManager
  3. Review diagnostic log above for details
```

**User gets:**
- Clear error message
- Automatic diagnostic log
- Copy on USB to review later
- Troubleshooting steps

### **Scenario 2: Client Phase 4 Fails**

```
User runs: sudo ./ft_build.sh on Device1
Chooses: Run Next Phase (Phase 4)

Phase 4 runs with full logging...

════════════════════════════════════════════════════════════
  Client Phase 4: Mesh Network Join
  Log file: /tmp/phase4_mesh_20260104_164704.log
════════════════════════════════════════════════════════════

[Step 1] Detecting device number... ✓
[Step 2] Loading batman-adv module... ✓
[Step 3] Checking wlan0... ✓
[Step 4] Setting IBSS mode... ✓
[Step 5] Joining IBSS network...

✗ FAILED TO JOIN IBSS NETWORK

═══ ERROR DETAILS ═══
[Detailed error info]

═══ TROUBLESHOOTING ═══
[Specific steps to fix]

Log saved to: /tmp/phase4_mesh_20260104_164704.log
Copied to USB: /mnt/usb/ft_usb_build/phase4_mesh_Device1_20260104_164704.log
```

**User gets:**
- Step-by-step progress (15 steps total)
- Exact failure point
- Detailed error information
- Specific troubleshooting steps
- Complete log saved to USB

---

## Benefits

1. **No blind failures** - Always know exactly what failed and why
2. **Auto-capture** - Don't need to remember to run diagnostic scripts
3. **USB logs** - Can review on dev system without accessing failed device
4. **Troubleshooting hints** - Common fixes shown automatically
5. **Complete context** - Full system state captured at failure point

---

## For Future Development

**Potential enhancements:**
- Auto-retry with fix (e.g., auto-run `rfkill unblock wifi` and retry)
- Email/upload diagnostics to central server
- Pre-flight checks before running phase
- Success verification after phase completes
- Automated rollback on failure

---

**Current Status:** All fixes in main scripts ✓ | Auto-diagnostics on failure ✓
