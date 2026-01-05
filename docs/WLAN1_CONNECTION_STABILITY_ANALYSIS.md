# wlan1 Connection Stability Analysis

## Problem Statement

The wlan1 internet connection (USB WiFi adapter) is unstable during installation:
- Phase 2 completes successfully with working internet connection
- During Phase 3 (package installation, ~5 minutes), the connection drops
- dhcpcd process dies, wlan1 loses IPv4 address
- Causes apt/pip operations to fail with DNS resolution errors

## Evidence from Logs

### Phase 2 Success (20251118_071918)
- Connection attempt 1 FAILED (timeout)
- Connection attempt 2 SUCCEEDED
- Got IP: 10.0.0.136/24
- Internet ping working
- dhcpcd daemon running
- All diagnostics PASSED

### Phase 3 Failure (20251118_071250)
- Started with working internet (10.0.0.136/24)
- Initial apt update succeeded
- DNS tests FAILED mid-phase
- Multiple package installations failed
- Connection lost during ~5 minute execution

### Phase 2 Success #2 (20251118_072959)
- Connection attempt 1 SUCCEEDED
- Got IP: 192.168.7.104/24
- Internet ping working
- All diagnostics PASSED

### Current State (Nov 18 07:45)
- wlan1 connected to WiFi (smithhome at 5GHz)
- wlan1 has NO IPv4 address (only IPv6)
- dhcpcd is NOT running
- Dev system using eth0 for internet instead

## Root Causes Identified

### 1. dhcpcd Process Dies
**Problem**: dhcpcd started manually in Phase 2 but not persistent
**Why**: No systemd service running to monitor and restart it
**Evidence**:
- `pgrep dhcpcd` returns nothing
- Last dhcpcd logs from Nov 16 (2 days ago)
- wlan1 has WiFi association but no IP

### 2. Watchdog Runs Too Infrequently
**Problem**: Watchdog checks every 5 minutes (cron job)
**Why**: Phase 3 only takes ~5 minutes, watchdog may not run in time
**Location**: `/usr/local/bin/wlan1-watchdog.sh`
**Cron**: `*/5 * * * * /usr/local/bin/wlan1-watchdog.sh`

### 3. Watchdog Restarts Wrong Thing
**Problem**: Watchdog restarts wlan1-internet.service
**Why**: During Phases 2-3, we're using MANUAL processes, not the service
**Conflict**: Manual wpa_supplicant + dhcpcd vs systemd service

### 4. Service vs Manual Connection
**During Installation (Phases 2-3)**:
- Phase 2 manually starts: wpa_supplicant + dhcpcd
- These are NOT managed by systemd
- If they die, nothing restarts them
- wlan1-internet.service is ENABLED but NOT STARTED

**After Installation (normal operation)**:
- wlan1-internet.service should run on boot
- Service starts wpa_supplicant + dhcpcd
- Watchdog can restart the service if it fails

**The Gap**: Between Phase 2 and reboot, manual processes have no monitoring

### 5. USB WiFi Power Management
**Problem**: mt76x0u USB WiFi adapter may enter power save mode
**Evidence**:
- Using mt76x0u driver (known to be unstable)
- USB power management settings exist in Phase 2
- `/etc/rc.local` disables USB autosuspend
- But may not be effective immediately

### 6. WiFi Signal Quality
**Evidence from testing**:
- Signal: -56 dBm (good)
- Connection: 5GHz (good bandwidth)
- Bitrate: 6.0 MBit/s (LOW - should be much higher)
- 47% packet loss observed by user
- Connection works initially then degrades

## Proposed Solutions

### Solution 1: Start Service Immediately (RECOMMENDED)
**Change Phase 2 to start the systemd service instead of manual processes**

Advantages:
- Watchdog works correctly (restarts service)
- Consistent with post-installation behavior
- systemd handles process management
- Connection persists through Phase 3

Implementation:
```bash
# Phase 2: Instead of manual start
sudo systemctl start wlan1-internet.service
# Then verify it's working
```

Disadvantages:
- Less visibility during installation (systemd logs vs direct output)
- Harder to debug if service fails

### Solution 2: Add Manual dhcpcd Monitoring
**Create a background process that monitors manual dhcpcd during Phases 2-3**

Advantages:
- Keeps current manual approach
- Immediate restart if dhcpcd dies
- More visible during installation

Implementation:
```bash
# Background monitor script
while true; do
    if ! pgrep -f "dhcpcd.*wlan1" >/dev/null; then
        logger "Phase 2/3 Monitor: dhcpcd died, restarting"
        sudo dhcpcd -4 wlan1
    fi
    sleep 10
done &
MONITOR_PID=$!
# Kill monitor after Phase 3 completes
```

Disadvantages:
- More complex
- Need to clean up monitor process
- Another process to debug

### Solution 3: Reduce Watchdog Interval
**Change cron from every 5 minutes to every 1 minute**

Advantages:
- Simple change
- Faster recovery

Disadvantages:
- Doesn't fix the service vs manual issue
- Still has lag (up to 1 minute)
- More frequent checks = more load

### Solution 4: Fix USB Power Management
**Ensure USB WiFi adapter never goes to sleep**

Current settings in Phase 2:
```bash
# USB autosuspend disabled via rc.local
# WiFi power management disabled
```

Additional measures:
```bash
# Disable autosuspend for specific device
echo -1 > /sys/bus/usb/devices/.../power/autosuspend_delay_ms
# Keep interface active
iw dev wlan1 set power_save off
```

### Solution 5: Improve WiFi Connection Quality
**Force 2.4GHz instead of 5GHz for better stability**

Current: Connecting to 5GHz (5580 MHz)
Better: Force 2.4GHz for reliability

wpa_supplicant.conf:
```
network={
    ssid="smithhome"
    psk="password"
    freq_list=2412 2437 2462  # 2.4GHz channels 1, 6, 11
}
```

## Recommended Action Plan

### Immediate (Phase 2/3 Fix):
1. **START**: Use Solution 1 - Start systemd service in Phase 2
   - Modify Phase 2 to `systemctl start wlan1-internet.service`
   - Remove manual wpa_supplicant + dhcpcd commands
   - Watchdog will now work correctly during Phase 3

2. **BACKUP**: Implement Solution 4 - Enhanced USB power management
   - Add device-specific power settings
   - Verify power_save is off

3. **TEST**: Use network stress test tool
   - Run 15-minute test after Phase 2
   - Monitor for dhcpcd deaths and connection drops
   - Check logs for patterns

### Long-term (Post-installation):
1. **OPTIMIZE**: Implement Solution 5 - WiFi frequency optimization
   - Test 2.4GHz vs 5GHz stability
   - Allow user to choose based on environment

2. **MONITOR**: Reduce watchdog interval to 1 minute
   - Faster recovery from transient failures
   - Better for field deployment

3. **DOCUMENT**: Add troubleshooting guide
   - Common WiFi adapter issues
   - How to check connection quality
   - Manual recovery procedures

## Testing Checklist

- [ ] Phase 2 starts wlan1-internet.service successfully
- [ ] Service remains running through Phase 3
- [ ] dhcpcd daemon stays alive for 15+ minutes
- [ ] No IPv4 address loss during package installation
- [ ] apt update/install succeed without DNS errors
- [ ] Network stress test passes (0% failures over 15 min)
- [ ] Watchdog correctly restarts service if killed manually
- [ ] System survives reboot with working connection

## Files to Modify

1. `/mnt/usb/ft_usb_build/phases/phase2_internet.sh`
   - Change from manual start to `systemctl start`
   - Add service verification
   - Remove manual dhcpcd command

2. `/mnt/usb/ft_usb_build/phases/phase2_internet.sh` (power mgmt)
   - Add device-specific USB power settings
   - Add iw power_save off command

3. `/usr/local/bin/wlan1-watchdog.sh`
   - Reduce interval from 5 min to 1 min (cron change)

4. `/mnt/usb/ft_usb_build/install_menu.sh`
   - ✅ DONE: Added network stress test option

5. `/mnt/usb/ft_usb_build/scripts/network_stress_test.sh`
   - ✅ DONE: Created comprehensive monitoring tool

## Next Steps

1. Review this analysis with user
2. Get approval for Solution 1 (systemd service approach)
3. Implement Phase 2 modifications
4. Test full installation on clean OS
5. Run network stress test to verify stability
