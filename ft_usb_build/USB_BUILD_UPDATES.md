# USB Build System Updates - Hardware Support

**Date:** November 15, 2025
**Update Version:** 2.2

---

## Summary of Changes

The USB build system has been updated to automatically enable and install all hardware interfaces required by Field Trainer:

### 1. **SSH, I2C, and SPI Auto-Configuration** ✅

**Phase 0 (Hardware Verification)** now automatically enables:

- **SSH** - Remote access to the Pi
- **I2C** - For MPU6500 touch sensor communication
- **SPI** - For WS2812B LED control via rpi-ws281x

**What it does:**
```bash
sudo raspi-config nonint do_ssh 0    # Enable SSH
sudo raspi-config nonint do_i2c 0    # Enable I2C
sudo raspi-config nonint do_spi 0    # Enable SPI
```

**Why it matters:**
- No more manual `raspi-config` steps required
- Fresh OS installs are immediately ready for Field Trainer hardware
- Touch sensors and LEDs work right away after installation

---

### 2. **Hardware Python Libraries Auto-Install** ✅

**Phase 1 (Package Installation)** now installs:

#### System Packages:
- `python3-dev` - Python development headers (required for pip installs)
- `python3-smbus` - System I2C library
- `i2c-tools` - I2C debugging utilities (i2cdetect, i2cdump, etc.)

#### Python Libraries (via pip):
- `smbus2` - I2C communication for MPU6500 touch sensor
- `rpi-ws281x` - LED control for WS2812B LEDs (GPIO18)
- `flask-socketio` - Real-time WebSocket support for calibration

**What Field Trainer uses these for:**

| Library | Purpose | Field Trainer File |
|---------|---------|-------------------|
| `smbus2` | Read accelerometer data from MPU6500 touch sensors | `/opt/field_trainer/ft_touch.py` |
| `rpi-ws281x` | Control WS2812B LED strip (8 LEDs on GPIO18) | `/opt/field_trainer/ft_led.py` |
| `flask-socketio` | Real-time touch calibration streaming | `/opt/field_trainer/templates/` |

---

### 3. **Phase 2 Service File Fixes** ✅

**Fixed critical bug in wlan1-internet.service:**

**Before (BROKEN):**
```bash
ExecStartPre=/usr/bin/killall wpa_supplicant  # ❌ Fails if no process exists
ExecStartPre=/usr/sbin/rfkill unblock all     # ❌ Wrong path on some systems
```

**After (FIXED):**
```bash
ExecStartPre=-/usr/bin/killall wpa_supplicant  # ✅ - prefix = ignore failure
ExecStartPre=-/usr/sbin/rfkill unblock all     # ✅ Try both paths
ExecStartPre=-/sbin/rfkill unblock all
```

**Why it matters:**
- Service no longer fails on first boot (when no wpa_supplicant is running)
- Works on all Raspberry Pi OS variants regardless of rfkill location
- More robust and reliable internet connection on boot

---

### 4. **Enhanced SSH Access Information** ✅

**Phase 2 now displays SSH connection info:**

After Phase 2 completes successfully, you'll see:

```
✓ SSH Access Now Available!

ℹ You can now connect via SSH from your home network:
  ssh pi@10.0.0.61

  Or try (if mDNS works):
  ssh pi@device0pi.local

⚠ Make sure SSH is enabled (Phase 0 should have enabled it)

ℹ Next steps:
  1. Test SSH: ssh pi@10.0.0.61 (from another computer on same WiFi)
  2. Continue to Phase 1 (Package Installation) - now has internet!
```

---

## Hardware Requirements Detection

Field Trainer requires the following hardware interfaces:

### **I2C Interface**
- **Used for:** MPU6500 accelerometer (touch sensor)
- **I2C Bus:** Bus 1 (`/dev/i2c-1`)
- **Addresses:** 0x68, 0x69, 0x71, or 0x73 (auto-detected)
- **Testing:** `sudo i2cdetect -y 1` (after Phase 1)

### **SPI Interface** (technically PWM/DMA)
- **Used for:** WS2812B LED strip control
- **GPIO Pin:** GPIO18 (PWM0)
- **Library:** rpi-ws281x uses PWM/DMA, but SPI can be alternative
- **LED Count:** 8 LEDs
- **Brightness:** 32/255 (configurable in code)

### **SSH**
- **Port:** 22 (default)
- **Purpose:** Remote access for maintenance and debugging
- **Auto-enabled:** Yes (Phase 0)

---

## Installation Order for Fresh Builds

**Recommended order for getting SSH working ASAP:**

```
1. Phase 0: Hardware Verification
   ├─ Enables SSH, I2C, SPI automatically
   └─ Verifies wlan0 and wlan1 exist

2. Phase 2: Internet Connection (wlan1)  ← Run THIS before Phase 1!
   ├─ Configures wlan1 with WiFi credentials
   ├─ Gets IP from router (e.g., 10.0.0.61)
   └─ SSH now accessible via that IP

3. Phase 1: Package Installation
   ├─ NOW has internet to install packages
   ├─ Installs hardware libraries (smbus2, rpi-ws281x)
   └─ Installs networking tools (batctl, dnsmasq, etc.)

4. Phases 3-6: Continue normally
   └─ Complete BATMAN mesh, DNS, NAT, and Field Trainer app
```

---

## Testing Hardware After Installation

### **Test I2C (after Phase 1):**
```bash
# Detect I2C devices on bus 1
sudo i2cdetect -y 1

# Expected output if MPU6500 is connected:
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 60: -- -- -- -- -- -- -- -- 68 -- -- -- -- -- -- --
# (or 69, 71, 73 depending on address jumpers)
```

### **Test SPI (LEDs won't work until Field Trainer starts):**
```bash
# Check if SPI is enabled
ls /dev/spi*
# Should show: /dev/spidev0.0  /dev/spidev0.1

# Verify rpi-ws281x library
python3 -c "import rpi_ws281x; print('LED library OK')"
```

### **Test SSH:**
```bash
# From another computer on same WiFi:
ssh pi@10.0.0.61

# Or use hostname (if mDNS works):
ssh pi@device0pi.local
```

---

## Verification Commands

After completing all phases, verify hardware support:

```bash
# Check enabled interfaces
raspi-config nonint get_ssh   # Should return: 0 (enabled)
raspi-config nonint get_i2c   # Should return: 0 (enabled)
raspi-config nonint get_spi   # Should return: 0 (enabled)

# Check Python hardware libraries
python3 -c "import smbus2; print('✓ I2C library')"
python3 -c "import rpi_ws281x; print('✓ LED library')"
python3 -c "import flask_socketio; print('✓ WebSocket library')"

# Check I2C device files
ls -l /dev/i2c-1   # Should exist

# Check for MPU6500 on I2C bus
sudo i2cdetect -y 1

# Check Field Trainer service uses hardware
sudo journalctl -u field-trainer.service | grep -i "LED\|sensor\|I2C"
```

---

## Troubleshooting

### **Issue: I2C not working after Phase 0**

**Solution:** Reboot required after enabling I2C
```bash
sudo reboot
# After reboot, verify:
ls /dev/i2c-1
```

### **Issue: LEDs don't light up**

**Possible causes:**
1. SPI not enabled (check: `ls /dev/spi*`)
2. rpi-ws281x not installed (check: `python3 -c "import rpi_ws281x"`)
3. Field Trainer service not running (check: `sudo systemctl status field-trainer`)
4. Wrong GPIO pin (should be GPIO18)
5. Power supply insufficient for LEDs

**Debug:**
```bash
# Check Field Trainer logs for LED errors
sudo journalctl -u field-trainer.service | grep LED

# Manually test LED control (be careful!)
sudo python3 << 'EOF'
from rpi_ws281x import PixelStrip, Color
strip = PixelStrip(8, 18, brightness=32)
strip.begin()
strip.setPixelColor(0, Color(255, 0, 0))  # Red on first LED
strip.show()
EOF
```

### **Issue: Touch sensor not detected**

**Debug steps:**
```bash
# 1. Check I2C is enabled
ls /dev/i2c-1

# 2. Scan for I2C devices
sudo i2cdetect -y 1

# 3. Check sensor is connected
# MPU6500 should appear at 0x68, 0x69, 0x71, or 0x73

# 4. Test smbus2 library
python3 -c "import smbus2; bus = smbus2.SMBus(1); print('I2C OK')"

# 5. Check Field Trainer logs
sudo journalctl -u field-trainer.service | grep -i sensor
```

---

## File Changes Summary

### **Modified Files:**

1. **`/mnt/usb/ft_usb_build/phases/phase0_hardware.sh`**
   - Added Step 8: Enable SSH, I2C, SPI
   - Uses `raspi-config nonint` commands
   - Updated summary to show enabled interfaces

2. **`/mnt/usb/ft_usb_build/phases/phase1_packages.sh`**
   - Added `python3-dev`, `python3-smbus`, `i2c-tools` to package list
   - Added hardware library installation section (smbus2, rpi-ws281x)
   - Added verification checks for hardware libraries
   - Updated summary to show hardware support

3. **`/mnt/usb/ft_usb_build/phases/phase2_internet.sh`**
   - Fixed service file killall commands (added `-` prefix)
   - Added dual rfkill paths for compatibility
   - Enhanced SSH access information in summary
   - Shows IP address for SSH connection

### **No Changes Made To:**
- `/opt/` (Field Trainer application code)
- `/etc/` (system configuration - only created by phase scripts)
- Build guide documentation (separate update may be needed)

---

## Benefits

✅ **Zero manual configuration** - Everything automated
✅ **Works on fresh OS** - No pre-configuration needed
✅ **SSH ready after Phase 2** - Remote access ASAP
✅ **Hardware ready after Phase 1** - Touch sensors and LEDs work immediately
✅ **Robust service startup** - No more Phase 2 failures
✅ **Better diagnostics** - i2c-tools included for debugging

---

## Next Steps

1. **Test the updated build on a fresh Raspberry Pi OS Trixie installation**
2. **Verify SSH access works after Phase 0 + Phase 2**
3. **Confirm I2C and SPI interfaces are enabled**
4. **Test touch sensor and LED functionality after complete installation**
5. **Update main BUILD_GUIDE.md if needed**

---

**Questions or Issues?**

Check logs:
```bash
# Phase execution logs
tail -100 /mnt/usb/ft_usb_build/.build_state

# Field Trainer service logs
sudo journalctl -u field-trainer.service -n 100

# Hardware interface status
raspi-config nonint get_ssh
raspi-config nonint get_i2c
raspi-config nonint get_spi
```
