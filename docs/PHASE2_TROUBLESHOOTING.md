# Phase 2 Troubleshooting Guide - RPi 3 A+ wlan1 Issues

**Date:** November 15, 2025
**For:** Raspberry Pi 3 A+ (512MB), Debian Trixie, MediaTek MT7610U USB WiFi

---

## Problem: wlan1 Won't Stay Up on RPi 3

### **Symptoms You're Seeing:**

From `dmesg` logs, wlan1 is:
- ✅ Authenticating successfully
- ✅ Associating with AP
- ❌ **Disconnecting repeatedly** (every 10-15 seconds)
- ❌ Roaming between multiple APs constantly
- ❌ Never stable enough to get/keep IP address

```
wlan1: disconnect from AP 30:3a:4a:6b:53:66 for new auth to 30:3a:4a:6b:53:65
wlan1: disconnect from AP 30:3a:4a:6b:53:65 for new auth to 30:3a:4a:6b:53:66
```

---

## Root Causes (Multiple Issues)

### **1. USB Power Management (BIGGEST ISSUE)**

**Problem:** RPi 3 A+ has limited power, USB WiFi gets powered down automatically

**Evidence:**
- Adapter disappears/reappears
- Disconnects happen at regular intervals
- Works briefly then fails

**Fix Applied in ROBUST Script:**
```bash
# Disable USB autosuspend globally
options usbcore autosuspend=-1

# Disable per-device power management
echo "on" > /sys/class/net/wlan1/device/power/control

# Disable WiFi power save
iwconfig wlan1 power off
```

---

### **2. Excessive Roaming**

**Problem:** wpa_supplicant sees multiple APs with same SSID (mesh router), keeps switching

**Evidence:**
```
disconnect from AP ...66 for new auth to ...65
disconnect from AP ...65 for new auth to ...66
```

**Fix Applied:**
```bash
# In wpa_supplicant config:
bgscan=""        # Disable background scanning
priority=100     # Prefer this network
```

---

### **3. Memory Constraints (512MB)**

**Problem:** RPi 3 A+ only has 512MB RAM, very little available

**Fix Applied:**
```bash
# Free memory before starting
sync
sysctl -w vm.drop_caches=3

# Use conservative DHCP timeout
dhcpcd -4 -t 30 wlan1  # 30 second timeout
```

---

### **4. Timing Issues**

**Problem:** Original script doesn't wait long enough for:
- Driver to stabilize
- Firmware to load
- WiFi to connect
- DHCP to complete

**Fixes Applied:**
```bash
# Driver load
modprobe mt76x0u
sleep 3          # Was: 2 seconds

# Interface up
ip link set wlan1 up
sleep 5          # Was: 3 seconds

# WiFi connection
sleep 20         # Was: 15 seconds

# DHCP
sleep 15         # Was: 10 seconds
```

---

### **5. Driver/Firmware Issues**

**Problem:** MediaTek MT7610U requires specific firmware

**Checks Added:**
```bash
# Verify firmware exists
/lib/firmware/mediatek/
/lib/firmware/mt7610u.bin

# Clean driver reload
modprobe -r mt76x0u  # Remove first
sleep 2
modprobe mt76x0u     # Then reload
sleep 3
```

---

## New ROBUST Script Features

### **File:** `phase2_internet_ROBUST.sh`

**Key Improvements:**

1. **Power Management Lockdown**
   - Disables USB autosuspend system-wide
   - Creates persistent power management script
   - Runs on every boot via systemd service
   - Double-checks after DHCP

2. **Roaming Prevention**
   - Disables background scanning
   - Sets high priority for target network
   - Prevents multi-AP switching

3. **Extended Retry Logic**
   - 5 retries instead of 3
   - Longer waits between retries
   - Better error messages

4. **Watchdog Monitoring**
   - Cron job runs every 5 minutes
   - Checks: IP address, wpa_supplicant state, gateway ping
   - Auto-restarts service if any check fails
   - Logs to syslog

5. **Robust Systemd Service**
   - Cleans driver (rmmod then modprobe)
   - Flushes IP before starting
   - Longer waits at each step
   - Disables power management in multiple places

6. **Better Diagnostics**
   - Shows available memory
   - Lists USB devices if wlan1 not found
   - Displays firmware locations
   - Real-time connection progress

---

## How to Use

### **Option 1: Replace Original (Recommended)**

```bash
cd /mnt/usb/ft_usb_build/phases

# Backup original
mv phase2_internet.sh phase2_internet.sh.backup

# Use robust version
mv phase2_internet_ROBUST.sh phase2_internet.sh

# Run build script
cd ..
./ft_build.sh
# Choose: Phase 2
```

### **Option 2: Run Directly**

```bash
cd /mnt/usb/ft_usb_build/phases
sudo ./phase2_internet_ROBUST.sh
```

---

## Manual Troubleshooting Steps

### **If Script Still Fails:**

#### **Step 1: Check USB WiFi is Detected**

```bash
# List USB devices
lsusb | grep -i "mediatek\|wireless\|wifi"

# Expected: MediaTek Inc. WiFi (ID 0e8d:7610)

# If not found:
# - Try different USB port
# - Check USB cable/adapter
# - Try on RPi 5 to verify adapter works
```

#### **Step 2: Check Driver and Firmware**

```bash
# Check driver loaded
lsmod | grep mt76

# Expected: mt76x0u, mt76x0_common, mt76_usb, mt76, mac80211

# If missing:
sudo modprobe mt76x0u
dmesg | tail -20  # Check for errors

# Check firmware
ls -l /lib/firmware/mediatek/
ls -l /lib/firmware/mt7610*

# If firmware missing:
sudo apt install firmware-misc-nonfree
```

#### **Step 3: Check rfkill**

```bash
# List all wireless blocks
sudo rfkill list

# Should show all "no" for blocked:
# Soft blocked: no
# Hard blocked: no

# If blocked:
sudo rfkill unblock all

# Force unblock via sysfs:
for rfkill in /sys/class/rfkill/rfkill*/soft; do
    echo 0 | sudo tee $rfkill
done
```

#### **Step 4: Manual Connection Test**

```bash
# Stop all services
sudo systemctl stop wlan1-internet
sudo killall wpa_supplicant dhcpcd

# Bring up interface
sudo ip link set wlan1 down
sudo ip link set wlan1 up
sleep 5

# Disable power management
sudo iwconfig wlan1 power off

# Check state
ip link show wlan1
iwconfig wlan1

# Start wpa_supplicant in foreground (see errors)
sudo wpa_supplicant -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant-wlan1.conf -d

# Watch for:
# - "CTRL-EVENT-CONNECTED"
# - "CTRL-EVENT-DISCONNECTED" (bad!)
# - Authentication errors
# - Association errors
```

#### **Step 5: Check Power Management**

```bash
# Check USB power control
cat /sys/class/net/wlan1/device/power/control
# Should be: on

# If "auto":
echo "on" | sudo tee /sys/class/net/wlan1/device/power/control

# Check USB autosuspend
cat /sys/module/usbcore/parameters/autosuspend
# Should be: -1

# Check iwconfig power
iwconfig wlan1 | grep "Power Management"
# Should be: off
```

#### **Step 6: Check Router/AP**

```bash
# Scan for networks
sudo iwlist wlan1 scan | grep -E "ESSID|Signal|Quality"

# Look for your SSID
# Check signal strength (should be > -70 dBm)

# If multiple APs with same SSID:
# - This causes roaming issues
# - Try setting a specific BSSID in wpa_supplicant config:
#   bssid=30:3a:4a:6b:53:66  # Lock to one AP
```

---

## Common Errors and Solutions

### **Error: "wlan1 not found"**

**Causes:**
- USB adapter not plugged in
- Bad USB port/cable
- Driver not loaded
- Insufficient power

**Solutions:**
```bash
# Check USB connection
lsusb

# Try different USB port

# Check dmesg for errors
dmesg | grep -i "usb\|wlan\|mt76"

# Check power supply voltage
vcgencmd get_throttled
# 0x0 = good, anything else = power issues
```

---

### **Error: "wpa_supplicant fails to start"**

**Causes:**
- Interface not up
- Config file errors
- Driver issues

**Solutions:**
```bash
# Check config syntax
sudo wpa_supplicant -c /etc/wpa_supplicant/wpa_supplicant-wlan1.conf -i wlan1 -d

# Check interface state
ip link show wlan1

# Verify driver
lsmod | grep mt76
```

---

### **Error: "Connected but no IP"**

**Causes:**
- DHCP server not responding
- Router firewall blocking
- Wrong subnet

**Solutions:**
```bash
# Check wpa_supplicant is connected
sudo wpa_cli -i wlan1 status
# Look for: wpa_state=COMPLETED

# Manual DHCP with debug
sudo dhcpcd -d -4 wlan1

# Check DHCP offers
sudo tcpdump -i wlan1 -n port 67 or port 68

# Try static IP
sudo ip addr add 192.168.1.100/24 dev wlan1
sudo ip route add default via 192.168.1.1 dev wlan1
```

---

### **Error: "Connects then disconnects"**

**THIS IS YOUR EXACT PROBLEM!**

**Causes:**
1. ✅ USB power management
2. ✅ Excessive roaming
3. ✅ Weak signal
4. ✅ Driver issues

**Solutions (ROBUST script handles all these):**

```bash
# 1. Disable power management permanently
sudo tee /etc/modprobe.d/usb-power-save.conf << EOF
options usbcore autosuspend=-1
EOF

# 2. Disable roaming in wpa_supplicant config
sudo nano /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
# Add inside network block:
bgscan=""
priority=100

# 3. Lock to specific AP (if multiple APs)
# Get BSSID from scan:
sudo iwlist wlan1 scan | grep Address
# Add to network block:
bssid=XX:XX:XX:XX:XX:XX

# 4. Reload driver cleanly
sudo modprobe -r mt76x0u
sleep 2
sudo modprobe mt76x0u
sleep 3

# 5. Increase connection timeout
# In systemd service:
ExecStartPost=/bin/sleep 30  # Longer wait

# 6. Monitor in real-time
sudo journalctl -u wlan1-internet -f
sudo wpa_cli -i wlan1  # Then type: status
```

---

## Verification After Fix

### **Check Everything is Working:**

```bash
# 1. Check service status
sudo systemctl status wlan1-internet.service

# 2. Check wpa_supplicant connected
sudo wpa_cli -i wlan1 status | grep wpa_state
# Should be: wpa_state=COMPLETED

# 3. Check IP address
ip addr show wlan1 | grep "inet "
# Should have IP (not 169.254.x.x)

# 4. Check power management disabled
cat /sys/class/net/wlan1/device/power/control
# Should be: on

iwconfig wlan1 | grep "Power Management"
# Should be: off

# 5. Test internet
ping -c 5 -I wlan1 8.8.8.8

# 6. Check no disconnects in logs
sudo journalctl -u wlan1-internet --since "5 minutes ago"
# Should NOT see disconnection messages

# 7. Watch for stability (5 minutes)
watch -n 1 'wpa_cli -i wlan1 status | grep wpa_state'
# Should stay: wpa_state=COMPLETED

# 8. Check watchdog is running
crontab -l | grep wlan1
# Should show: */5 * * * * /usr/local/bin/wlan1-watchdog.sh
```

---

## Performance Tuning for Pi 3 A+

### **If Connection is Slow/Unstable:**

```bash
# 1. Reduce TX power (helps with roaming)
sudo iwconfig wlan1 txpower 15  # dBm (default is usually 20)

# 2. Set channel width (avoid 40MHz on weak signals)
# In wpa_supplicant:
ht_cap=[HT40-]  # Force 20MHz

# 3. Disable 802.11n (use 802.11g only - more stable)
# In wpa_supplicant network block:
mode=0  # 0=infrastructure, use legacy rates

# 4. Increase beacon listen interval (save power, may help)
# In wpa_supplicant:
max_listen_interval=10

# 5. Monitor signal strength
watch -n 1 'iwconfig wlan1 | grep Quality'
# Should be at least 40/70, ideally > 50/70
```

---

## When to Give Up and Use Ethernet

If after all fixes wlan1 still won't stay up:

**Alternative: Use Ethernet for Phase 1**

```bash
# 1. Connect Ethernet cable to RPi
# 2. Skip Phase 2 entirely
# 3. Run Phase 1 (will use eth0 for internet)
# 4. Then try Phase 2 again after packages installed
# 5. Or use wlan1 for mesh instead (swap wlan0/wlan1 roles)
```

---

## Comparison: Original vs ROBUST Script

| Feature | Original | ROBUST |
|---------|----------|--------|
| USB power mgmt | Not handled | ✅ Disabled globally |
| Roaming prevention | No | ✅ bgscan disabled |
| Retries | 3 | ✅ 5 |
| Wait times | Short (2-3s) | ✅ Long (3-20s) |
| Driver reload | Once | ✅ Clean rmmod + modprobe |
| Watchdog | No | ✅ Cron every 5 min |
| Memory optimization | No | ✅ drop_caches |
| DHCP timeout | Default | ✅ 30 seconds |
| Diagnostics | Basic | ✅ Extensive |
| Service robustness | Basic | ✅ Multi-layer |

---

## Success Indicators

**You know it's working when:**

1. ✅ `systemctl status wlan1-internet` shows "active (exited)"
2. ✅ `wpa_cli -i wlan1 status` shows "wpa_state=COMPLETED"
3. ✅ `ip addr show wlan1` shows real IP (not 169.254.x.x)
4. ✅ `ping -I wlan1 8.8.8.8` works
5. ✅ Connection stays up for >5 minutes without disconnect
6. ✅ SSH works from remote machine
7. ✅ After reboot, wlan1 comes up automatically

---

## Files Created by ROBUST Script

```
/etc/modprobe.d/usb-power-save.conf
/etc/NetworkManager/conf.d/unmanaged-wlan1.conf
/etc/wpa_supplicant/wpa_supplicant-wlan1.conf
/etc/systemd/system/wlan1-internet.service
/etc/udev/rules.d/70-persistent-net.rules
/usr/local/bin/disable-wifi-pm.sh
/usr/local/bin/wlan1-watchdog.sh
```

---

## Support Commands

```bash
# Full diagnostic dump
echo "=== wlan1 Diagnostic ===" > /tmp/wlan1-diag.txt
lsusb | grep -i "mediatek\|wifi" >> /tmp/wlan1-diag.txt
lsmod | grep mt76 >> /tmp/wlan1-diag.txt
ip link show wlan1 >> /tmp/wlan1-diag.txt
iwconfig wlan1 >> /tmp/wlan1-diag.txt
sudo wpa_cli -i wlan1 status >> /tmp/wlan1-diag.txt
sudo rfkill list >> /tmp/wlan1-diag.txt
cat /sys/class/net/wlan1/device/power/control >> /tmp/wlan1-diag.txt
dmesg | grep -i "wlan1\|mt76" | tail -50 >> /tmp/wlan1-diag.txt
cat /tmp/wlan1-diag.txt
```

---

**Good luck! The ROBUST script should handle all these issues automatically.**
