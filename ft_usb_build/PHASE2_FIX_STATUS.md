# Phase 2 Internet Connection Fix - Status

**Date**: 2025-11-18
**Issue**: dhcpcd service hanging during Phase 2, causing timeout failures

---

## Problem Summary

**Symptom**: `wlan1-dhcp.service` would hang indefinitely when starting, eventually timing out.

**Root Cause**: Service configuration mismatch:
- Used `Type=forking` with `dhcpcd -4 -q -b wlan1`
- The `-b` flag backgrounds dhcpcd immediately
- `Type=forking` expects parent to stay alive until fork completes
- This caused systemd to wait forever for fork signal that never came

---

## Solution Applied

Modified `/mnt/usb/ft_usb_build/phases/phase2_internet.sh` (lines 77-83):

### Before (BROKEN):
```bash
[Service]
Type=forking
PIDFile=/run/dhcpcd-wlan1.pid
ExecStart=/usr/sbin/dhcpcd -4 -q -b wlan1
```

### After (FIXED):
```bash
[Service]
Type=simple
ExecStartPre=/bin/sleep 15
ExecStart=/usr/sbin/dhcpcd -4 -w wlan1
ExecStop=/usr/bin/killall dhcpcd
Restart=always
RestartSec=10
```

### Key Changes:
1. ✅ Changed `Type=forking` → `Type=simple` (expects foreground process)
2. ✅ Removed `-b` flag (background immediately)
3. ✅ Removed `-q` flag (quiet mode)
4. ✅ Added `-w` flag (wait for IP, then stays running in foreground)
5. ✅ Removed PID file (not needed for Type=simple)
6. ✅ Kept `Restart=always` for auto-recovery

---

## Two-Service Architecture

Phase 2 creates two separate systemd services:

### Service 1: wlan1-wpa.service
- **Purpose**: Manages wpa_supplicant (WiFi connection)
- **Type**: forking (daemon with PID file)
- **Restart**: on-failure
- **Dependencies**: Runs first, before dhcp service

### Service 2: wlan1-dhcp.service
- **Purpose**: Manages dhcpcd (DHCP client)
- **Type**: simple (foreground process)
- **Restart**: always (auto-restart even on normal exit)
- **Dependencies**: Requires wlan1-wpa.service, waits 15s after wpa starts

---

## Testing Checklist

### ✅ Completed:
- [x] Fix applied to phase2_internet.sh
- [x] Network stress test added to menu (option 6)
- [x] Network stress test stops after 5 consecutive failures
- [x] Phase 3 dhcpcd keepalive monitor added

### ⏳ Ready for Testing:
- [ ] Run Phase 2 on fresh OS install
- [ ] Verify wlan1-wpa.service starts successfully
- [ ] Verify wlan1-dhcp.service starts WITHOUT hanging
- [ ] Verify IP address obtained on wlan1
- [ ] Verify internet connectivity (ping 8.8.8.8)
- [ ] Run network stress test for 5-10 minutes
- [ ] Run complete installation Phases 1-7
- [ ] Verify services survive reboot
- [ ] Test on production clone to other devices

---

## How to Test

### Fresh Install Test:
```bash
# On build system with fresh Raspberry Pi OS
cd /mnt/usb/ft_usb_build
./install_menu.sh

# Select option 2: Run Phase 2 only
# Enter WiFi credentials when prompted
# Wait for Phase 2 to complete

# Verify services running:
systemctl status wlan1-wpa.service
systemctl status wlan1-dhcp.service

# Check for dhcpcd process:
ps aux | grep dhcpcd

# Verify IP:
ip addr show wlan1

# Test internet:
ping -c 5 8.8.8.8
```

### Stress Test:
```bash
# From install menu, select option 6
# Run for 300 seconds (5 minutes)
# Should maintain connection without failures
```

### Full Installation:
```bash
# From install menu, select option 1
# Run all phases 1-7
# Monitor for connection drops during Phase 3 package installation
```

---

## Expected Outcomes

### ✅ Success Criteria:
1. Phase 2 completes without hanging
2. Both services show "active (running)" status
3. dhcpcd process stays alive (visible in `ps aux`)
4. wlan1 has valid IP address (not 169.254.x.x)
5. Internet connectivity works (ping 8.8.8.8 succeeds)
6. Network stress test maintains connection for 5+ minutes
7. Phase 3 completes package installation without connection loss
8. Services survive system reboot
9. Configuration works when cloned to other devices

### ❌ Failure Indicators:
- wlan1-dhcp.service hangs during start
- Services show "failed" or "inactive" status
- dhcpcd process not visible in process list
- No IP address on wlan1
- Ping fails to 8.8.8.8
- Connection drops during stress test
- Phase 3 package installation fails with DNS errors

---

## Rollback Plan

If the fix doesn't work, alternative scripts are available:

### Option 1: Ultra-Simple (Manual + Keepalive)
```bash
cp phase2_internet_ULTRASIMP.sh phase2_internet.sh
```
Uses manual dhcpcd with background keepalive script. No systemd service complexity.

### Option 2: Static IP (NOT RECOMMENDED)
```bash
cp phase2_internet_STATIC.sh phase2_internet.sh
```
Uses static IP during installation, DHCP after reboot. User rejected this approach.

---

## Additional Components

### Network Stress Test
**Location**: `/mnt/usb/ft_usb_build/scripts/network_stress_test.sh`
**Menu Option**: 6
**Purpose**: Tests connection stability over time
**Features**:
- Pings 8.8.8.8 every 10 seconds
- Logs all results with timestamps
- Stops after 5 consecutive failures
- Reports packet loss statistics

### Phase 3 Keepalive Monitor
**Location**: `/mnt/usb/ft_usb_build/phases/phase3_packages.sh` (lines 42-85)
**Purpose**: Monitors dhcpcd during package installation
**Function**: Restarts dhcpcd if it dies during Phase 3

---

## Next Steps

1. User tests Phase 2 on build system with fresh OS
2. If successful: Complete full Phases 1-7 installation
3. If successful: Verify reboot persistence
4. If successful: Test cloning to production device
5. If issues: Analyze logs and adjust or rollback

---

## Status: READY FOR USER TESTING

All fixes applied and ready. Awaiting test results from build system.
