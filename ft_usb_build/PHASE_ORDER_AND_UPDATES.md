# Field Trainer USB Build - Phase Order and Updates

## Recommended Installation Order

The phases should be run in this order for optimal installation:

```
Phase 0 → Phase 2 → Phase 1 → Phase 3 → Phase 4 → Phase 5 → Phase 6
```

### Why This Order?

1. **Phase 0 (Hardware)** - First
   - Enables SSH, I2C, SPI via raspi-config
   - Verifies hardware (WiFi adapters, interfaces)
   - No internet required

2. **Phase 2 (Internet Connection)** - Second
   - Brings up wlan1 (USB WiFi) for internet access
   - Configures WPA supplicant and DHCP
   - Creates watchdog service for connection reliability
   - **Requires:** wpasupplicant and dhcpcd5 (usually included in Trixie OS)

3. **Phase 1 (Packages)** - Third
   - Installs ALL required packages now that internet is available
   - Includes Phase 6 prerequisites (git, Pillow/PIL)
   - Installs hardware libraries (smbus2, rpi-ws281x)
   - **Requires:** Internet connection from Phase 2

4. **Phase 3 (Mesh Network)** - Fourth
   - Configures batman-adv mesh on wlan0
   - **Requires:** batctl from Phase 1

5. **Phase 4 (DNS)** - Fifth
   - Configures dnsmasq for mesh network
   - **Requires:** dnsmasq from Phase 1

6. **Phase 5 (NAT)** - Sixth
   - Configures NAT/routing between mesh (bat0) and internet (wlan1)
   - **Requires:** iptables from Phase 1

7. **Phase 6 (Field Trainer)** - Last
   - Clones Field Trainer repository from GitHub
   - Installs Python dependencies
   - Creates systemd service
   - **Requires:** git, Flask, Pillow (PIL), internet from previous phases

## Recent Updates to Phase 1

### Added to Package Installation

**PYTHON_PACKAGES array:**
- Added `python3-pil` (Pillow/PIL) - **CRITICAL** for Phase 6 coach interface

**Verification Section:**
Added checks for Phase 6 prerequisites:
- ✓ Pillow (PIL) verification with pip fallback if apt fails
- ✓ git verification (required for repository clone)
- ✓ Both marked as CRITICAL/REQUIRED for Phase 6

### What Phase 1 Now Installs

#### Core Networking (for Phases 2-5)
- `batctl` - BATMAN-adv mesh utilities
- `wpasupplicant` - WiFi authentication
- `wireless-tools` - WiFi configuration
- `dhcpcd5` - DHCP client
- `dnsmasq` - DNS/DHCP server
- `iptables` - Firewall/NAT
- `iptables-persistent` - Save iptables rules

#### Python & Web (for Phase 6)
- `python3` - Python interpreter
- `python3-pip` - Package installer
- `python3-venv` - Virtual environments
- `python3-flask` - Web framework
- `python3-pil` - **NEW** Pillow/PIL image library (coach interface)
- `python3-dev` - Development headers
- `python3-smbus` - I2C base library
- `sqlite3` - Database

#### Hardware Libraries (via pip)
- `smbus2` - I2C for MPU6500 touch sensor
- `rpi-ws281x` - PWM/SPI for WS2812B LEDs
- `flask-socketio` - Real-time calibration features
- `python-socketio` - SocketIO client

#### System Utilities
- `git` - **CRITICAL** for Phase 6 repository clone
- `curl` - HTTP client
- `i2c-tools` - I2C debugging (i2cdetect)

### Phase 1 Verification

Phase 1 now verifies ALL Phase 6 prerequisites at the end:

```
Verifying Installations...
--------------------------
  batman-adv module... ✓ loaded successfully
  batctl command... ✓ available (batctl 2024.0)
  dnsmasq... ✓ available (Dnsmasq version 2.90)
  iptables... ✓ available (v1.8.10)
  Python 3... ✓ available (Python 3.12.7)
  Flask... ✓ available (v3.0.0)
  Pillow (PIL)... ✓ available (v10.2.0)
  git... ✓ available (v2.45.2)
  wpasupplicant... ✓ installed
  dhcpcd5... ✓ installed
  smbus2 (I2C)... ✓ installed (v0.4.3)
  rpi-ws281x (LEDs)... ✓ installed
  i2c-tools... ✓ installed

Phase 6 prerequisites verified:
  ✓ git (for repository clone)
  ✓ Python 3 + Flask
  ✓ Pillow (PIL) - required for coach interface
  ✓ flask-socketio

Ready to proceed to Phase 3 (Mesh Network)
```

## Phase 5.5 (Deprecated)

The `phase5.5_verify_prerequisites.sh` script was created to verify Phase 6 prerequisites, but is now **deprecated** since Phase 1 includes all those checks.

You can delete this file:
```bash
rm /mnt/usb/ft_usb_build/phases/phase5.5_verify_prerequisites.sh
```

## Why Phase 6 Failed Before

Phase 6 checks for these prerequisites at the start:
1. Internet connection
2. git
3. Python 3
4. Flask
5. Pillow (PIL)

**The Problem:** If you ran Phase 0 → Phase 2 → Phase 6 (skipping Phase 1), you would get "prerequisites missing" because:
- git was not installed (Phase 1 installs it)
- Pillow (PIL) was not installed (Phase 1 now installs it)
- Other dependencies might be missing

**The Solution:** Always run Phase 1 AFTER Phase 2 (internet) and BEFORE Phase 6.

## Testing on RPi 3 A+

Tested successfully on:
- **Device:** Raspberry Pi 3 A+ (512MB RAM)
- **OS:** Debian GNU/Linux 13 (trixie)
- **WiFi:** MediaTek MT7610U USB adapter
- **Network:** Connected to "xsmithhome" WiFi
- **IP:** 10.0.0.123

Phase 2 worked perfectly with the robust internet configuration.

## Next Steps

1. Test the updated Phase 1 on RPi 3 A+:
   ```bash
   sudo /mnt/usb/ft_usb_build/phases/phase1_packages.sh
   ```

2. Verify all Phase 6 prerequisites are installed

3. Continue with Phase 3 → Phase 4 → Phase 5 → Phase 6

4. Test complete installation from fresh OS

## Files Modified

- `/mnt/usb/ft_usb_build/phases/phase1_packages.sh`
  - Added `python3-pil` to PYTHON_PACKAGES array
  - Added Pillow (PIL) verification with pip fallback
  - Added git verification
  - Updated summary to show Phase 6 prerequisites

## Files Created

- `/mnt/usb/ft_usb_build/phases/phase5.5_verify_prerequisites.sh` (can be deleted)
- `/mnt/usb/ft_usb_build/PHASE_ORDER_AND_UPDATES.md` (this file)
