# I2C Setup Guide - Touch Sensor Configuration

## Date: 2026-01-08

## Overview

The Field Trainer system uses I2C to communicate with the MPU6050 touch sensor on both Device0 (gateway) and client devices (Device1-5).

## What Was Fixed

### Problem
- User reported: `sudo i2cdetect -y 1` command not found
- Sensor couldn't be detected in Phase 1

### Root Causes Found

1. **i2c-tools not in Phase 3 (Client)** - FIXED ✅
   - Phase 3 installed Python libraries but NOT i2c-tools
   - Phase 1 tried to install i2c-tools dynamically, but unreliable

2. **Gateway Phase 3 HAS i2c-tools** - Already included ✅
   - Line 356: `"i2c-tools"` is in the package array
   - If command not found on Device0, Phase 3 wasn't run or failed

3. **I2C requires reboot** - Documentation needed ℹ️
   - Phase 1 enables I2C in `/boot/firmware/config.txt`
   - Changes only take effect after reboot
   - Sensor detection should happen AFTER reboot

## Complete I2C Setup Sequence

### For Client Devices (Device1-5)

**Phase 1: Hardware Verification**
```bash
sudo /mnt/usb/ft_usb_build/client_phases/phase1_hardware.sh
```

What Phase 1 does:
1. ✅ Enables I2C in `/boot/firmware/config.txt`
   ```bash
   dtparam=i2c_arm=on
   ```

2. ✅ Loads I2C kernel module
   ```bash
   sudo modprobe i2c-dev
   echo "i2c-dev" >> /etc/modules
   ```

3. ⚠️ Tries to detect sensor (may fail before reboot)
   - Installs i2c-tools if missing (lines 124-129)
   - Runs `i2cdetect -y 1`
   - Warns if sensor not found (expected before reboot)

4. **REBOOT REQUIRED**
   ```bash
   sudo reboot
   ```

**Phase 2: Internet Configuration**
```bash
sudo /mnt/usb/ft_usb_build/client_phases/phase2_internet.sh
```
(Configures USB WiFi for internet access)

**Phase 3: Package Installation** (UPDATED ✅)
```bash
sudo /mnt/usb/ft_usb_build/client_phases/phase3_packages.sh
```

What Phase 3 does NOW:
1. ✅ Installs BATMAN-adv and networking tools
2. ✅ **Installs i2c-tools** (NEW - Step 3.5)
   ```bash
   sudo apt-get install -y i2c-tools
   ```
3. ✅ Installs Python and development tools
4. ✅ Installs Python I2C library (smbus2 for MPU6050/MPU6500/MPU9250)
5. ✅ Installs LED and audio libraries

**After Phase 3 - Verify I2C**
```bash
# Check i2cdetect installed
which i2cdetect
# Should show: /usr/sbin/i2cdetect

# Check I2C devices exist
ls -la /dev/i2c*
# Should show: /dev/i2c-1

# Detect sensor
sudo i2cdetect -y 1
# Should show sensor at 0x68 or 0x69
```

### For Gateway (Device0)

**Phase 1: Hardware Verification**
```bash
sudo /mnt/usb/ft_usb_build/gateway_phases/phase1_hardware.sh
```

What Gateway Phase 1 does:
- Verifies OS version (Trixie 64-bit)
- Verifies kernel version (>= 6.1)
- Verifies WiFi interfaces (wlan0, wlan1)
- **Does NOT enable I2C** - must be done manually

**Manual I2C Enable on Gateway:**
```bash
# Check if I2C enabled
grep "dtparam=i2c_arm" /boot/firmware/config.txt

# If not found, enable it:
echo "dtparam=i2c_arm=on" | sudo tee -a /boot/firmware/config.txt

# Load I2C module
sudo modprobe i2c-dev
echo "i2c-dev" | sudo tee -a /etc/modules

# REBOOT REQUIRED
sudo reboot
```

**Phase 2: Internet Configuration**
```bash
sudo /mnt/usb/ft_usb_build/gateway_phases/phase2_internet.sh
```

**Phase 3: Package Installation** (Already includes i2c-tools ✅)
```bash
sudo /mnt/usb/ft_usb_build/gateway_phases/phase3_packages.sh
```

What Gateway Phase 3 does:
1. ✅ **Installs i2c-tools** (line 356 - already in package list)
2. ✅ Installs batctl, dnsmasq, iptables
3. ✅ Installs Python 3 and Flask
4. ✅ Installs Python I2C library (smbus2)
5. ✅ Installs LED library (rpi-ws281x)

**After Phase 3 - Verify I2C**
```bash
# Check i2cdetect installed
which i2cdetect
# Should show: /usr/sbin/i2cdetect

# Check I2C devices
ls -la /dev/i2c*
# Should show: /dev/i2c-1 (and possibly i2c-13, i2c-14)

# Detect sensor
sudo i2cdetect -y 1
# Should show sensor at 0x68
```

## I2C Hardware Details

### MPU6050 Touch Sensor

**I2C Address:**
- Primary: `0x68` (AD0 pin LOW or floating)
- Alternate: `0x69` (AD0 pin HIGH)

**I2C Bus:**
- Bus 1: `/dev/i2c-1` (GPIO 2=SDA, GPIO 3=SCL)
- Bus 13: `/dev/i2c-13` (Pi 5 only - additional buses)
- Bus 14: `/dev/i2c-14` (Pi 5 only - additional buses)

**Wiring:**
```
MPU6050    Raspberry Pi
--------   -------------
VCC    --> 3.3V (Pin 1 or 17)
GND    --> GND (Pin 6, 9, 14, 20, etc.)
SDA    --> GPIO 2 (Pin 3)
SCL    --> GPIO 3 (Pin 5)
```

### I2C Speed

Default: 100 kHz (standard mode)

To change speed (optional):
```bash
# In /boot/firmware/config.txt
dtparam=i2c_arm=on,i2c_arm_baudrate=400000  # 400 kHz (fast mode)
```

## Troubleshooting

### Command Not Found: i2cdetect

**Cause:** i2c-tools not installed

**Fix:**
```bash
# Install manually
sudo apt-get update
sudo apt-get install -y i2c-tools

# Verify
which i2cdetect
```

### No I2C Device: /dev/i2c-1 not found

**Cause:** I2C not enabled in config.txt or no reboot after enabling

**Fix:**
```bash
# Check if enabled
grep "dtparam=i2c_arm" /boot/firmware/config.txt

# If not found:
echo "dtparam=i2c_arm=on" | sudo tee -a /boot/firmware/config.txt
sudo reboot

# After reboot, verify:
ls -la /dev/i2c*
```

### Sensor Not Detected (no 0x68 or 0x69)

**Possible causes:**

1. **Sensor not connected**
   - Check physical connections
   - Ensure VCC, GND, SDA, SCL properly wired

2. **Wrong I2C bus**
   - Try: `sudo i2cdetect -y 0` (bus 0)
   - Try: `sudo i2cdetect -y 13` (Pi 5 - bus 13)
   - Try: `sudo i2cdetect -y 14` (Pi 5 - bus 14)

3. **Sensor address conflict**
   - Check if multiple I2C devices on same bus
   - Verify AD0 pin configuration on MPU6050

4. **Pull-up resistors missing**
   - I2C requires 4.7kΩ pull-up resistors on SDA and SCL
   - Most Pi HATs include these
   - Breadboard circuits may need external resistors

5. **Sensor damaged or incompatible**
   - Try with known-good sensor
   - Verify it's MPU6050 (not MPU6000 or MPU9250)

### Permission Denied

**Cause:** User not in `i2c` group

**Fix:**
```bash
# Add user to i2c group
sudo usermod -a -G i2c pi

# Logout and login for changes to take effect
# Or use newgrp:
newgrp i2c

# Verify
groups
# Should show: pi adm dialout cdrom sudo audio video plugdev games users input netdev i2c
```

### I2C Works in Phase 1, Fails Later

**Cause:** SystemManager or other service taking control of I2C

**Fix:**
```bash
# Check for conflicts
dmesg | grep i2c
journalctl -xe | grep i2c

# Reload I2C module
sudo modprobe -r i2c_dev
sudo modprobe i2c-dev
```

## Verification Commands

### Check I2C Enabled
```bash
# Method 1: Config file
grep -i "i2c" /boot/firmware/config.txt
# Should show: dtparam=i2c_arm=on

# Method 2: Device tree
ls /proc/device-tree/soc/i2c@*/status 2>/dev/null
# Should show status files

# Method 3: Devices
ls -la /dev/i2c*
# Should show: /dev/i2c-1
```

### Check I2C Module Loaded
```bash
lsmod | grep i2c
# Should show:
# i2c_dev                20480  0
# i2c_bcm2835            16384  0
# i2c_brcmstb            20480  0
```

### Scan All I2C Buses
```bash
# Detect all I2C buses
i2cdetect -l
# Should show:
# i2c-1   i2c             bcm2835 (i2c@7e804000)                  I2C adapter

# Scan bus 1
sudo i2cdetect -y 1
```

### Read Sensor Data
```bash
# Read WHO_AM_I register (0x75) of MPU sensor at address 0x68
sudo i2cget -y 1 0x68 0x75
# Should return: 0x68 (MPU6050), 0x70 (MPU6500), or 0x71 (MPU9250)
```

### Python Test
```bash
# Test Python I2C library (works with MPU6050/MPU6500/MPU9250)
python3 << 'EOF'
import smbus2
import struct
import time

bus = smbus2.SMBus(1)
ADDR = 0x68

# Wake up sensor
bus.write_byte_data(ADDR, 0x6B, 0x00)
time.sleep(0.1)

# Read accelerometer
accel_data = bus.read_i2c_block_data(ADDR, 0x3B, 6)
accel_x = struct.unpack('>h', bytes(accel_data[0:2]))[0] / 16384.0
accel_y = struct.unpack('>h', bytes(accel_data[2:4]))[0] / 16384.0
accel_z = struct.unpack('>h', bytes(accel_data[4:6]))[0] / 16384.0

# Read gyroscope
gyro_data = bus.read_i2c_block_data(ADDR, 0x43, 6)
gyro_x = struct.unpack('>h', bytes(gyro_data[0:2]))[0] / 131.0
gyro_y = struct.unpack('>h', bytes(gyro_data[2:4]))[0] / 131.0
gyro_z = struct.unpack('>h', bytes(gyro_data[4:6]))[0] / 131.0

# Read temperature
temp_data = bus.read_i2c_block_data(ADDR, 0x41, 2)
temp_raw = struct.unpack('>h', bytes(temp_data))[0]
temp_c = (temp_raw / 340.0) + 36.53

print(f"Acceleration: X={accel_x:.2f}g, Y={accel_y:.2f}g, Z={accel_z:.2f}g")
print(f"Gyroscope: X={gyro_x:.2f}°/s, Y={gyro_y:.2f}°/s, Z={gyro_z:.2f}°/s")
print(f"Temperature: {temp_c:.2f}°C")

bus.close()
EOF
```

## Summary of Changes

### Client Phase 3 (`client_phases/phase3_packages.sh`) - UPDATED ✅

**Added Step 3.5:**
```bash
log_step "Installing I2C tools for touch sensor"
sudo apt-get install -y i2c-tools
```

**Updated Summary:**
- Added: "✓ I2C tools (i2cdetect, i2cget, i2cset)"

### Gateway Phase 3 (`gateway_phases/phase3_packages.sh`) - Already Has It ✅

**Line 356:**
```bash
PYTHON_PACKAGES=(
    ...
    "i2c-tools"
    ...
)
```

No changes needed - already includes i2c-tools.

## Phase Execution Checklist

### Client Device Deployment

- [ ] **Phase 1:** Hardware verification
  - [ ] Enables I2C in config.txt
  - [ ] Loads I2C kernel module
  - [ ] Warns if sensor not detected (OK before reboot)

- [ ] **REBOOT** ← Critical!

- [ ] **Phase 2:** Internet configuration via USB WiFi

- [ ] **Phase 3:** Package installation
  - [ ] Installs i2c-tools (NEW)
  - [ ] Installs Python I2C libraries

- [ ] **Verify I2C:** `sudo i2cdetect -y 1`
  - [ ] Should show sensor at 0x68 or 0x69

- [ ] **Phase 4:** Mesh network join
- [ ] **Phase 5:** Client application deployment

### Gateway Device Deployment

- [ ] **Phase 1:** Hardware verification
  - [ ] Does NOT enable I2C automatically

- [ ] **Manual I2C Enable:**
  ```bash
  echo "dtparam=i2c_arm=on" | sudo tee -a /boot/firmware/config.txt
  sudo modprobe i2c-dev
  echo "i2c-dev" | sudo tee -a /etc/modules
  ```

- [ ] **REBOOT** ← Critical!

- [ ] **Phase 2:** Internet configuration

- [ ] **Phase 3:** Package installation
  - [ ] Installs i2c-tools (already included)
  - [ ] Installs Python I2C libraries (smbus2)

- [ ] **Verify I2C:** `sudo i2cdetect -y 1`
  - [ ] Should show sensor at 0x68

- [ ] **Phase 4:** Mesh network setup
- [ ] **Phase 5:** DNS/DHCP setup
- [ ] **Phase 6:** NAT/firewall setup
- [ ] **Phase 7:** Field Trainer application deployment

## Quick Reference

| Command | Purpose |
|---------|---------|
| `which i2cdetect` | Check if i2c-tools installed |
| `ls /dev/i2c*` | List I2C devices |
| `sudo i2cdetect -y 1` | Scan I2C bus 1 for devices |
| `sudo i2cget -y 1 0x68 0x75` | Read WHO_AM_I register |
| `lsmod \| grep i2c` | Check I2C modules loaded |
| `grep i2c /boot/firmware/config.txt` | Check I2C enabled |
| `groups` | Check if user in i2c group |

## Documentation

- Client Phase 3: `/mnt/usb/ft_usb_build/client_phases/phase3_packages.sh`
- Gateway Phase 3: `/mnt/usb/ft_usb_build/gateway_phases/phase3_packages.sh`
- This guide: `/mnt/usb/ft_usb_build/I2C_SETUP_GUIDE.md`

---

**I2C setup is now automated in Phase 3 for both client and gateway devices.**
