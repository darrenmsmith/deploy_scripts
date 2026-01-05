# Phase 3 dhcpcd Keepalive Monitor - Solution

## Problem
During Phase 3 (package installation), the internet connection via wlan1 drops because dhcpcd dies. This causes DNS resolution failures and package installation errors.

## Root Cause Analysis

### Dev System vs Build System
**Dev System (what you're testing from)**:
- Has Ethernet (eth0) providing stable internet
- wlan1 is configured but not critical (eth0 is primary)
- ft-network-manager.service monitors and manages connectivity
- dhcpcd can die on wlan1 without affecting anything

**Build System (RPi 3 A+ being built)**:
- NO Ethernet port (RPi 3 A+ hardware limitation)
- ONLY wlan1 (USB WiFi) for internet
- ft-network-manager NOT installed until Phase 7
- If dhcpcd dies, entire internet connection lost

### The Gap
- Phase 2 starts dhcpcd manually to get internet working
- Phase 3 runs for ~5 minutes installing packages
- During this time, dhcpcd can die (USB power management, driver issues, etc.)
- No monitoring until ft-network-manager is installed in Phase 7
- Watchdog only checks every 5 minutes (too slow)

## Solution Implemented

Added a **background dhcpcd keepalive monitor** to Phase 3:

```bash
# Runs in background during Phase 3
start_dhcpcd_monitor() {
    while true; do
        sleep 10  # Check every 10 seconds

        if ! pgrep -f "dhcpcd.*wlan1" >/dev/null; then
            # dhcpcd died - restart it immediately
            logger "Phase 3 dhcpcd monitor: dhcpcd died, restarting"
            sudo dhcpcd -4 wlan1
        fi
    done
}

start_dhcpcd_monitor &
MONITOR_PID=$!

# Kill monitor when Phase 3 exits
trap "kill $MONITOR_PID" EXIT INT TERM
```

### How It Works
1. Monitor starts at beginning of Phase 3
2. Checks every 10 seconds if dhcpcd is running
3. If dhcpcd dies, immediately restarts it
4. Logs all actions to syslog and `/tmp/dhcpcd_monitor_$$.log`
5. Automatically stops when Phase 3 completes/exits

### Benefits
- **Fast recovery**: 10-second check interval (vs 5-minute watchdog)
- **Automatic**: No user intervention needed
- **Temporary**: Only runs during Phase 3, then exits
- **Logged**: All actions recorded for debugging
- **Clean**: Proper cleanup via trap handlers

## Comparison to Dev System

This mimics what **ft-network-manager.service** does on the dev system:
- Monitors internet connectivity every 60 seconds
- Handles connection failures automatically
- Keeps internet working reliably

But since ft-network-manager isn't installed until Phase 7, we need this temporary solution for Phase 3.

## Testing

To verify the fix works:

1. Run Phase 2 (get internet connection)
2. Run Phase 3 (with new monitor)
3. Monitor the dhcpcd process:
   ```bash
   watch -n 1 'pgrep -fa dhcpcd'
   ```
4. Check monitor log after Phase 3:
   ```bash
   cat /tmp/dhcpcd_monitor_*.log
   grep "dhcpcd monitor" /var/log/syslog
   ```
5. Verify packages installed successfully

For stress testing:
- Run network stress test from menu (option 6)
- Manually kill dhcpcd during Phase 3: `sudo pkill dhcpcd`
- Verify monitor restarts it within 10 seconds

## Related Changes

Also created:
- `scripts/network_stress_test.sh` - Comprehensive connection monitoring tool
- `WLAN1_CONNECTION_STABILITY_ANALYSIS.md` - Detailed problem analysis
- Menu option 6 - "Network Stress Test" for testing connection stability

## Files Modified

- `/mnt/usb/ft_usb_build/phases/phase3_packages.sh` (lines 42-85)
  - Added dhcpcd keepalive monitor
  - Starts automatically at beginning of phase
  - Cleans up automatically on exit

## Why This Approach

**Alternative considered**: Start wlan1-internet.service in Phase 2
- Would work, but service is `Type=oneshot`
- systemd doesn't monitor oneshot services
- Would need to change service type to `forking` or `simple`
- More complex, more changes required

**This approach**:
- Minimal changes (only Phase 3)
- Temporary solution until ft-network-manager takes over
- Easy to debug and test
- Proven pattern (same as ft-network-manager)

## Success Criteria

✅ Phase 3 completes without internet loss
✅ No DNS resolution errors during apt operations
✅ All packages install successfully
✅ dhcpcd stays running throughout Phase 3
✅ Monitor starts and stops cleanly
✅ No orphaned processes after Phase 3
