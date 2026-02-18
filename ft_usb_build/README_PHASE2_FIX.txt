================================================================================
PHASE 2 FIX FOR RASPBERRY PI 3 A+ - wlan1 Connection Issues
================================================================================

DATE: November 15, 2025
ISSUE: wlan1 (USB WiFi) won't stay connected on RPi 3 A+
ROOT CAUSE: Multiple issues (power mgmt, roaming, timing, memory)

================================================================================
PROBLEM IDENTIFIED
================================================================================

From dmesg logs, wlan1 was:
  ✅ Authenticating successfully
  ✅ Associating with Access Point
  ❌ DISCONNECTING every 10-15 seconds
  ❌ Roaming between multiple APs constantly
  ❌ Never stable enough to get IP address

Log pattern:
  "wlan1: disconnect from AP ...66 for new auth to ...65"
  "wlan1: disconnect from AP ...65 for new auth to ...66"

================================================================================
ROOT CAUSES (5 ISSUES FOUND)
================================================================================

1. USB POWER MANAGEMENT (CRITICAL!)
   - RPi 3 A+ has limited power (512MB, single core stressed)
   - USB WiFi adapter gets powered down by autosuspend
   - Solution: Disable USB autosuspend globally + per-device

2. EXCESSIVE ROAMING
   - wpa_supplicant sees multiple APs with same SSID (mesh router)
   - Keeps switching between APs
   - Solution: Disable background scanning, set priority

3. MEMORY CONSTRAINTS
   - Only 512MB RAM total
   - Very little free memory for network operations
   - Solution: Free memory before starting, use conservative timeouts

4. TIMING ISSUES
   - Original script doesn't wait long enough
   - Driver, firmware, connection, DHCP all need more time
   - Solution: Extended waits (3→5s, 15→20s, 10→15s)

5. DRIVER/FIRMWARE
   - MediaTek MT7610U needs specific firmware
   - Driver not cleanly reloaded
   - Solution: Clean rmmod→modprobe cycle, verify firmware

================================================================================
SOLUTION: NEW ROBUST SCRIPT
================================================================================

File: /mnt/usb/ft_usb_build/phases/phase2_internet_ROBUST.sh (23KB)

KEY FEATURES:

✅ Power Management Lockdown
   - Disables USB autosuspend system-wide
   - Creates persistent power management scripts
   - Runs on every boot via systemd
   - Double-checks after DHCP

✅ Roaming Prevention
   - Disables background scanning (bgscan="")
   - Sets high priority (priority=100)
   - Optional: Lock to specific BSSID

✅ Extended Retry Logic
   - 5 retries (was 3)
   - Longer waits between retries
   - Better error reporting

✅ Connection Watchdog
   - Cron job runs every 5 minutes
   - Checks: IP, wpa_state, gateway ping
   - Auto-restarts if any check fails
   - Logs to syslog

✅ Robust Systemd Service
   - Cleans driver (rmmod then modprobe)
   - Flushes IP before starting
   - Longer waits at every step
   - Multi-layer power management disable

✅ Better Diagnostics
   - Shows available memory
   - Lists USB devices if wlan1 missing
   - Displays firmware locations
   - Real-time connection progress

================================================================================
HOW TO USE
================================================================================

OPTION 1: Replace Original Script (Recommended)
------------------------------------------------

cd /mnt/usb/ft_usb_build/phases

# Backup original
cp phase2_internet.sh phase2_internet.sh.backup

# Replace with robust version
cp phase2_internet_ROBUST.sh phase2_internet.sh

# Run build script
cd ..
./ft_build.sh

# Choose: 3 (Jump to Specific Phase)
# Enter: 2 (Phase 2: Internet Connection)


OPTION 2: Run Robust Script Directly
-------------------------------------

cd /mnt/usb/ft_usb_build/phases
sudo ./phase2_internet_ROBUST.sh


OPTION 3: Keep Both (Test ROBUST First)
----------------------------------------

cd /mnt/usb/ft_usb_build/phases
sudo ./phase2_internet_ROBUST.sh

# If it works, then replace original:
mv phase2_internet.sh phase2_internet.sh.old
mv phase2_internet_ROBUST.sh phase2_internet.sh

================================================================================
WHAT GETS INSTALLED
================================================================================

Files Created:
  /etc/modprobe.d/usb-power-save.conf
  /etc/NetworkManager/conf.d/unmanaged-wlan1.conf
  /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
  /etc/systemd/system/wlan1-internet.service
  /etc/udev/rules.d/70-persistent-net.rules
  /usr/local/bin/disable-wifi-pm.sh
  /usr/local/bin/wlan1-watchdog.sh

Services Created:
  wlan1-internet.service (systemd - auto-start on boot)
  wlan1-watchdog.sh (cron - runs every 5 minutes)

================================================================================
VERIFICATION AFTER RUNNING
================================================================================

1. Check service status:
   sudo systemctl status wlan1-internet.service
   # Should show: active (exited)

2. Check WiFi connected:
   sudo wpa_cli -i wlan1 status | grep wpa_state
   # Should show: wpa_state=COMPLETED

3. Check IP address:
   ip addr show wlan1 | grep "inet "
   # Should have real IP (NOT 169.254.x.x)

4. Check power management disabled:
   cat /sys/class/net/wlan1/device/power/control
   # Should show: on

   iwconfig wlan1 | grep "Power Management"
   # Should show: off

5. Test internet:
   ping -c 5 -I wlan1 8.8.8.8
   # Should get 5 replies

6. Check stability (wait 5 minutes):
   watch -n 1 'wpa_cli -i wlan1 status | grep wpa_state'
   # Should stay: wpa_state=COMPLETED (not disconnect!)

7. Test SSH (from another computer on same network):
   ssh pi@<wlan1_ip>
   # Should connect

================================================================================
TROUBLESHOOTING
================================================================================

If script still fails, see: PHASE2_TROUBLESHOOTING.md

Quick checks:

1. USB WiFi detected?
   lsusb | grep MediaTek
   # Should show: ID 0e8d:7610 MediaTek Inc. WiFi

2. Driver loaded?
   lsmod | grep mt76
   # Should show: mt76x0u, mt76_usb, mt76

3. Firmware exists?
   ls -l /lib/firmware/mediatek/
   ls -l /lib/firmware/mt7610*

4. Interface exists?
   ip link show wlan1

5. Not blocked?
   sudo rfkill list
   # All should show: Soft blocked: no

6. Recent logs?
   sudo journalctl -u wlan1-internet --since "5 minutes ago"
   dmesg | grep wlan1 | tail -20

================================================================================
COMPARISON: ORIGINAL vs ROBUST
================================================================================

Feature                | Original  | ROBUST
-----------------------|-----------|------------------
USB power mgmt         | ❌ No     | ✅ Disabled
Roaming prevention     | ❌ No     | ✅ Yes (bgscan="")
Retries                | 3         | ✅ 5
Wait times             | Short     | ✅ Extended
Driver reload          | Once      | ✅ Clean cycle
Watchdog               | ❌ No     | ✅ Cron every 5min
Memory optimization    | ❌ No     | ✅ drop_caches
DHCP timeout           | Default   | ✅ 30 seconds
Diagnostics            | Basic     | ✅ Extensive
Service robustness     | Basic     | ✅ Multi-layer

================================================================================
SUCCESS CRITERIA
================================================================================

You know it's working when:

1. Service shows "active" and stays active
2. wpa_state stays "COMPLETED" for >5 minutes
3. IP address is assigned and persists
4. Can ping 8.8.8.8 consistently
5. SSH works from remote machine
6. After reboot, wlan1 auto-connects
7. No disconnect messages in logs

================================================================================
ADDITIONAL DOCUMENTATION
================================================================================

Files on USB:
  /mnt/usb/ft_usb_build/phases/phase2_internet_ROBUST.sh
  /mnt/usb/ft_usb_build/PHASE2_TROUBLESHOOTING.md (detailed guide)
  /mnt/usb/ft_usb_build/README_PHASE2_FIX.txt (this file)

Read PHASE2_TROUBLESHOOTING.md for:
  - Manual troubleshooting steps
  - Common errors and solutions
  - Advanced tuning for Pi 3 A+
  - Performance optimization
  - Full diagnostic commands

================================================================================
NOTES FOR RPI 3 A+ SPECIFICALLY
================================================================================

The Raspberry Pi 3 A+ (512MB) has unique challenges:

1. Limited RAM
   - Less memory for buffers
   - Needs memory optimization
   - Can't handle heavy network + other tasks

2. Single USB Bus
   - All USB shares bandwidth and power
   - WiFi competes with other USB devices
   - Power management more aggressive

3. Lower Power Budget
   - Designed for battery use
   - More aggressive power saving
   - USB ports get less power

4. Older Hardware
   - Slower processor than Pi 4/5
   - More susceptible to timing issues
   - Needs longer waits

The ROBUST script accounts for ALL these limitations!

================================================================================
RECOMMENDED NEXT STEPS
================================================================================

1. Run the ROBUST script on your Pi 3 A+

2. Verify it stays connected for at least 5 minutes

3. Reboot and verify auto-start works

4. If successful, replace original in build script

5. Test SSH access from another machine

6. Continue with Phase 1 (now has internet!)

================================================================================

Questions? Check PHASE2_TROUBLESHOOTING.md for detailed help!
