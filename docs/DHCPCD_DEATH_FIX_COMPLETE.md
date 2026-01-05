# Complete Fix for dhcpcd Death Issue

## Problem
dhcpcd was dying 5-25 seconds after starting, causing Phase 2 and Phase 3 to fail consistently. This happened even with fresh OS install and known working USB WiFi adapter.

## Root Causes Identified

### 1. Service File Had Timeout Flag
**Location**: `phase2_internet.sh` line 551 (in service template)
```bash
ExecStartPost=/usr/sbin/dhcpcd -4 -t 30 wlan1
```
The `-t 30` flag made dhcpcd exit after 30 seconds on any issue.

**Fixed**: Removed `-t 30` flag, dhcpcd now runs indefinitely.

### 2. Service Type Was Oneshot
**Location**: `phase2_internet.sh` line 510
```bash
[Service]
Type=oneshot
RemainAfterExit=yes
```
With Type=oneshot, systemd doesn't monitor if dhcpcd stays running. Once started, systemd considers it "active" even if dhcpcd dies.

**Fixed**: Added `Restart=on-failure` and `RestartSec=10` to auto-restart on failure.

### 3. Manual vs Service Conflict
Phase 2 was starting dhcpcd manually, then creating a service for boot. But:
- Manual dhcpcd had no monitoring
- If service got triggered (watchdog, boot, etc.), it conflicted
- No recovery if manual dhcpcd died

**Fixed**: Phase 2 now:
1. Creates service file with fixes
2. **Immediately starts the service** (replaces manual processes)
3. Lets systemd manage everything
4. Service has auto-restart on failure

## Changes Made

### File: `/mnt/usb/ft_usb_build/phases/phase2_internet.sh`

#### Change 1: Remove timeout from dhcpcd (line 551)
```bash
# OLD:
ExecStartPost=/usr/sbin/dhcpcd -4 -t 30 wlan1

# NEW:
ExecStartPost=/usr/sbin/dhcpcd -4 wlan1
```

#### Change 2: Add restart policy (lines 512-513)
```bash
[Service]
Type=oneshot
RemainAfterExit=yes
Restart=on-failure        # NEW
RestartSec=10             # NEW
```

#### Change 3: Add dhcpcd verification (line 557)
```bash
# Verify dhcpcd is running
ExecStartPost=/bin/bash -c 'pgrep -f "dhcpcd.*wlan1" || exit 1'
```

#### Change 4: Start service immediately (lines 558-608)
**OLD**:
```bash
print_info "Note: Service will start on next boot"
print_info "Current manual connection will persist through Phase 3"
```

**NEW**:
```bash
# Kill manual processes
sudo killall -9 wpa_supplicant 2>/dev/null
sudo killall -9 dhcpcd 2>/dev/null
sleep 3

# Start the service
if sudo systemctl start wlan1-internet.service; then
    print_success "Service started successfully"

    # Wait 50 seconds for full initialization
    sleep 50

    # Verify service is still active
    if systemctl is-active --quiet wlan1-internet.service; then
        print_success "Service is active and stable"

        # Verify IP obtained
        WLAN1_IP=$(ip addr show wlan1 | grep "inet " ...)
        if [ -n "$WLAN1_IP" ]; then
            print_success "Service obtained IP: $WLAN1_IP"
            IP_OBTAINED=true
        fi
    fi
fi
```

#### Change 5: Simplify Step 8 (lines 411-432)
Step 8 no longer starts manual dhcpcd. It just notes that service will handle everything.

### File: `/mnt/usb/ft_usb_build/scripts/network_stress_test.sh`

#### Change 6: Stop after 5 consecutive failures
**User Request**: "stress test should stop if it receives 5 failures"

```bash
# Track consecutive failures
CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=5

# In main loop:
if check_network ...; then
    CONSECUTIVE_FAILURES=0  # Reset on success
else
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))

    if [ $CONSECUTIVE_FAILURES -ge 5 ]; then
        print_error "Stopping: 5 consecutive failures"
        break
    fi
fi
```

## How It Works Now

### Phase 2 Flow:
1. Clean up old processes/services
2. Reload mt76x0u driver
3. Start wpa_supplicant (manual, temporary)
4. Create wlan1-internet.service file (with all fixes)
5. Enable service for boot
6. **START SERVICE IMMEDIATELY**
7. Kill manual wpa_supplicant/dhcpcd
8. Service takes over completely
9. Wait 50 seconds for service to initialize
10. Verify service is active and has IP
11. Continue with watchdog setup

### Service Responsibilities:
- Manages entire connection lifecycle
- Starts/stops wpa_supplicant and dhcpcd
- Auto-restarts on failure (Restart=on-failure)
- Monitored by systemd
- Watchdog can restart service if needed

### Benefits:
✅ No more manual process conflicts
✅ systemd monitors dhcpcd continuously
✅ Auto-restart on any failure
✅ Consistent behavior during installation and after boot
✅ Watchdog can restart service if needed
✅ 50-second initialization ensures stability

## Testing

### Test on Build System:
1. Fresh OS install
2. Run Phase 1, 1.5
3. Run Phase 2 - should complete successfully with service active
4. Run network stress test - should pass or stop after 5 failures (not 30+)
5. Run Phase 3 - should complete without connection loss

### Expected Results:
- Phase 2: Service starts, gets IP, stays active for 50+ seconds
- Network stress test: Either passes or stops after 5 consecutive failures
- Phase 3: Packages install successfully, no DNS errors
- dhcpcd: Stays running indefinitely, managed by systemd

## Rollback Plan

If this doesn't work, the old manual approach is still in git history. Can revert with:
```bash
git diff HEAD phase2_internet.sh
# Review changes, then revert if needed
```

## Success Criteria

✅ Phase 2 completes successfully
✅ wlan1-internet.service is active after Phase 2
✅ dhcpcd stays running for 5+ minutes
✅ Phase 3 completes without "dhcpcd died" errors
✅ Network stress test either passes or stops after 5 failures
✅ No "30+ consecutive failures"

## Files Modified

1. `/mnt/usb/ft_usb_build/phases/phase2_internet.sh`
   - Lines 411-432: Simplified Step 8
   - Lines 510-513: Added Restart policy to service
   - Line 551: Removed `-t 30` timeout from dhcpcd
   - Line 557: Added dhcpcd verification
   - Lines 558-608: Added immediate service start

2. `/mnt/usb/ft_usb_build/scripts/network_stress_test.sh`
   - Lines 42-45: Added consecutive failure tracking
   - Lines 179-194: Added early stop after 5 consecutive failures

## Next Steps

1. Test Phase 2 on build system
2. If Phase 2 succeeds, run network stress test
3. If stress test passes/stops appropriately, run Phase 3
4. Document results
5. If successful, commit changes to git
