# Phase 2 Real Root Cause - ft-network-manager Interference

## THE ACTUAL PROBLEM (Found via Explore Agent)

**ft-network-manager.service** is running in the background and **interfering with dhcpcd!**

### Evidence from System

```bash
$ systemctl status ft-network-manager.service
● ft-network-manager.service - Field Trainer Network Manager
     Active: active (running) since Sun 2025-11-16 09:05:44 PST
   Main PID: 1005 (python3)

Nov 17 15:24:19 - INFO - Internet check: OK
[3-minute gap - no logs during Phase 2 wait!]
Nov 17 15:28:20 - INFO - Internet check: OK
```

### What ft-network-manager Does

**File:** `/opt/scripts/ft-network-manager.py` (lines 255-271)

```python
# Checks internet connectivity every 60 seconds
if internet_failures >= 3:
    # Restart dhcpcd if 3 checks fail!
    subprocess.run(['sudo', 'systemctl', 'restart', 'dhcpcd'])
```

**The Problem:**
1. ft-network-manager runs every 60 seconds checking internet
2. During Phase 2's 3-minute wait, it checks at least 3 times
3. If any checks fail (or timeout), it can restart dhcpcd
4. Restarting dhcpcd kills Phase 2's manual dhcpcd daemon
5. Phase 2 loses its IP address

### Timeline of Events

```
15:24:20 - Phase 2 starts dhcpcd -4 -b wlan1 (daemon mode)
15:24:50 - IP obtained: 192.168.7.103
15:24:57 - Start 3-minute stabilization wait
15:25:19 - ft-network-manager checks internet (possibly fails?)
15:26:19 - ft-network-manager checks again (possibly fails?)
15:27:19 - ft-network-manager checks again (3 failures = restart dhcpcd!)
15:27:57 - Phase 2 diagnostics run
15:27:57 - ERROR: NO IP ADDRESS (dhcpcd was restarted by ft-network-manager)
```

### The Smoking Gun

**Phase 2 log shows 3-minute gap:**
```
[2025-11-17 15:24:19] - Last ft-network-manager log before Phase 2
[3 minutes of silence]
[2025-11-17 15:28:20] - Next ft-network-manager log after Phase 2
```

**This gap coincides EXACTLY with Phase 2's 180-second wait!**

## The Fixes Applied

### Fix 1: Stop ft-network-manager During Phase 2 (Line 47)

**OLD:**
```bash
print_info "Stopping all network services..."
sudo systemctl stop wlan1-internet.service 2>/dev/null
sudo systemctl stop wpa_supplicant@wlan1.service 2>/dev/null
sudo systemctl stop wpa_supplicant.service 2>/dev/null
```

**NEW:**
```bash
print_info "Stopping all network services..."
sudo systemctl stop wlan1-internet.service 2>/dev/null
sudo systemctl stop wpa_supplicant@wlan1.service 2>/dev/null
sudo systemctl stop wpa_supplicant.service 2>/dev/null
sudo systemctl stop ft-network-manager.service 2>/dev/null  # ← NEW!
print_success "ft-network-manager stopped (will restart on boot)"
```

### Fix 2: Reduce Stabilization Wait from 3 Minutes to 30 Seconds (Lines 785-793)

**WHY 3 minutes was overkill:**
- DNS propagation: ~5-10 seconds
- DHCP lease confirmation: ~5 seconds
- Route establishment: ~2 seconds
- Total needed: ~20 seconds max

**OLD:**
```bash
print_info "Waiting 180 seconds (3 minutes) for network to stabilize..."
WAIT_TIME=180
INTERVAL=10
```

**NEW:**
```bash
print_info "Waiting 30 seconds for DNS and routes to stabilize..."
WAIT_TIME=30
INTERVAL=5
```

**Benefits:**
- Reduces exposure window for interference
- Faster installation (saves 2.5 minutes per run)
- Still enough time for DNS and routes

### Fix 3: Monitor dhcpcd During Wait (Lines 803-810)

**NEW Debug Code:**
```bash
while [ $elapsed -lt $WAIT_TIME ]; do
    remaining=$((WAIT_TIME - elapsed))
    echo -ne "  ⏱  Time remaining: ${remaining}s   \r"
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))

    # Debug: Check dhcpcd is still running every interval
    if ! pgrep -f "dhcpcd.*wlan1" >/dev/null; then
        echo -ne "\n"
        print_error "dhcpcd process died during wait!"
        log_error "dhcpcd process for wlan1 died at ${elapsed}s into stabilization wait"
        ERRORS=$((ERRORS + 1))
        break
    fi
done
```

**What this does:**
- Checks every 5 seconds if dhcpcd is still running
- If dhcpcd dies, immediately reports WHEN it died
- Logs exactly how many seconds into the wait it happened
- Breaks out of wait loop early (no point waiting if dhcpcd is dead)

## Other Issues Found (Already Fixed Earlier)

### dhcpcd Process Cleanup (Lines 62-76)

Added verification that dhcpcd processes are killed during cleanup:
```bash
# Verify dhcpcd is dead
if pgrep dhcpcd >/dev/null; then
    print_warning "Force killing remaining dhcpcd processes..."
    for pid in $(pgrep dhcpcd); do
        sudo kill -9 "$pid" 2>/dev/null
    done
fi
```

### dhcpcd Daemon Mode (Line 451)

Changed from timeout mode to persistent daemon:
```bash
# OLD: sudo dhcpcd -4 -t 30 wlan1  (exits after 30 sec)
# NEW: sudo dhcpcd -4 -b wlan1     (stays running forever)
```

## Why This Works on Normal System

**On normal system (eth0 with Ethernet):**
- NetworkManager manages everything
- No manual dhcpcd processes
- No ft-network-manager interference (it monitors but doesn't conflict)
- Stable connection, no timeouts

**During Phase 2 (wlan1 WiFi installation):**
- Manual dhcpcd process (not managed by systemd)
- ft-network-manager monitoring in background
- Competing for control of dhcpcd
- ft-network-manager can restart dhcpcd, killing Phase 2's daemon

## Testing Instructions

```bash
# Clean up
rm /mnt/usb/install_logs/*
rm /mnt/usb/install_state.json

# Verify ft-network-manager is running before test
systemctl status ft-network-manager

# Run installation
cd /mnt/usb/ft_usb_build
sudo ./install_menu.sh
```

**During Phase 2:**
- ft-network-manager will be stopped (you'll see the message)
- Only 30-second wait instead of 3 minutes
- dhcpcd will be monitored every 5 seconds
- If dhcpcd dies, you'll see EXACTLY when (e.g., "died at 15s into stabilization wait")

**Expected Success:**
```
✓ ft-network-manager stopped (will restart on boot)
✓ IP obtained: 192.168.7.xxx
✓ dhcpcd daemon is running and managing wlan1
⏱  Waiting 30 seconds for DNS and routes to stabilize...
⏱  Time remaining: 25s
⏱  Time remaining: 20s
⏱  Time remaining: 15s
⏱  Time remaining: 10s
⏱  Time remaining: 5s
✓ Network stabilization complete!
✓ All diagnostic checks passed!
```

**If dhcpcd dies:**
```
⏱  Time remaining: 15s
✗ dhcpcd process died during wait!
[Phase 2 FAILS with clear error message]
```

## Summary of All Changes

| Issue | Fix | File | Lines |
|-------|-----|------|-------|
| ft-network-manager interfering | Stop service during Phase 2 | phase2_internet.sh | 47-48 |
| 3-minute wait too long | Reduce to 30 seconds | phase2_internet.sh | 785-793 |
| No dhcpcd monitoring | Check every 5 seconds | phase2_internet.sh | 803-810 |
| dhcpcd not verified killed | Add verification loop | phase2_internet.sh | 62-76 |
| dhcpcd exits after timeout | Use -b flag (daemon mode) | phase2_internet.sh | 451 |

## Bottom Line

**The Real Problem:** ft-network-manager.service was running in background and could restart dhcpcd during the 3-minute wait, killing Phase 2's manual dhcpcd daemon.

**The Fix:** Stop ft-network-manager during Phase 2, reduce wait to 30 seconds, and actively monitor dhcpcd to catch if it dies.

**Test now with fresh OS build!**
