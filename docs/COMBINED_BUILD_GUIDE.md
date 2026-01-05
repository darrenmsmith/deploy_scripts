# Field Trainer - Combined Build System Guide

**Updated:** 2026-01-02
**Version:** 2.0 - Unified Gateway + Client Build System

---

## Overview

The Field Trainer build system now supports building both:
- **Device0 (Gateway)** - Raspberry Pi 3 A+ or Pi 4
- **Device1-5 (Field Devices/Cones)** - Raspberry Pi Zero W

**The same USB drive and ft_build.sh script builds both types automatically!**

---

## System Architecture

### Device0 (Gateway)
- **Hardware:** Raspberry Pi 3 A+ (or Pi 4)
- **OS:** Raspberry Pi OS Lite (32-bit) Trixie
- **IP:** 192.168.99.100
- **Functions:**
  - BATMAN-adv mesh network coordinator
  - Internet gateway (NAT/firewall)
  - DNS/DHCP server
  - Web interface (ports 5000/5001)
  - Field device server (port 6000)

### Device1-5 (Field Devices)
- **Hardware:** Raspberry Pi Zero W
- **OS:** Raspberry Pi OS Lite (32-bit) Trixie
- **IPs:** 192.168.99.101-105
- **Functions:**
  - BATMAN-adv mesh network client
  - WS2812B LED strip (15 LEDs on GPIO12)
  - MPU6050 touch sensor (I2C)
  - Audio feedback (speaker)

---

## Hardware Requirements

### For Device0 (Gateway)
- Raspberry Pi 3 A+ (512MB RAM) or Pi 4
- MicroSD card (16GB+ recommended)
- **2x WiFi adapters:**
  - Onboard WiFi (wlan0) → Mesh network
  - USB WiFi adapter (wlan1) → Internet connection
- Power supply
- USB thumb drive (this build system)

### For Each Field Device (Device1-5)
- Raspberry Pi Zero W
- MicroSD card (8GB+ minimum)
- **USB hub** (for Pi Zero W's single micro USB port)
- **USB WiFi adapter** (temporary, for installation only)
- **Hardware components:**
  - WS2812B LED strip (15 LEDs)
  - MPU6050 accelerometer (touch sensor)
  - Speaker for audio feedback
- Power supply
- USB thumb drive (this build system)

---

## Raspberry Pi Imager Settings

### Device0 (Gateway)
```
OS: Raspberry Pi OS Lite (32-bit)
Hostname: Device0
Username: pi
Password: (your choice)
WiFi: DO NOT CONFIGURE
SSH: Enable (password authentication)
Locale: (your settings)
```

### Field Devices (Device1-5)
```
OS: Raspberry Pi OS Lite (32-bit)
Hostname: Device1 (or Device2, Device3, Device4, Device5)
Username: pi
Password: (same as Device0)
WiFi: DO NOT CONFIGURE
SSH: Enable (password authentication)
Locale: (your settings)
```

**CRITICAL:** Do NOT configure WiFi in Raspberry Pi Imager! The build scripts will handle WiFi configuration.

---

## Build Process

### Device0 (Gateway) - 7 Phases

**Total Time:** ~60-75 minutes

1. **Boot Device0 with fresh OS**
2. **Connect USB thumb drive** (this build system)
3. **Run build script:**
   ```bash
   cd /mnt/usb/ft_usb_build
   sudo ./ft_build.sh
   ```
4. **Script auto-detects Device0** from hostname
5. **Follow phases 1-7:**
   - Phase 1: Hardware verification + udev rules (creates persistent WiFi names)
   - Phase 2: Internet connection via wlan1
   - Phase 3: Package installation
   - Phase 4: BATMAN-adv mesh network on wlan0
   - Phase 5: DNS/DHCP server
   - Phase 6: NAT/Firewall
   - Phase 7: Field Trainer application (auto-selects latest release)

6. **Verify Device0:**
   ```bash
   # Check services
   sudo systemctl status field-trainer
   sudo systemctl status batman-mesh

   # Access web interface
   http://192.168.99.100:5000
   ```

---

### Device1-5 (Field Devices) - 5 Phases

**Total Time:** ~45-60 minutes per device
**Build one at a time, then verify before building next**

#### Prerequisites
- Device0 fully built and running ✓
- Device0 mesh network active ✓
- Hardware (LED, touch sensor) connected to Pi Zero W ✓
- USB hub + USB WiFi adapter available ✓

#### Build Process

1. **Flash SD card** with Pi OS Lite, hostname Device1-5, SSH enabled
2. **Connect hardware to Pi Zero W:**
   - LED strip to GPIO12
   - Touch sensor to I2C pins
   - Speaker to audio out
3. **Boot device with USB hub:**
   - Port 1: USB WiFi adapter (for internet during install)
   - Port 2: Keyboard (optional if using SSH)
4. **Mount USB thumb drive** (same one used for Device0)
5. **Run build script:**
   ```bash
   cd /mnt/usb/ft_usb_build
   sudo ./ft_build.sh
   ```

6. **Script auto-detects device number** from hostname (Device1-5)
7. **Follow phases 1-5:**

   **Phase 1: Hardware Verification**
   - Verifies Pi Zero W (512MB RAM)
   - Enables I2C for touch sensor
   - Enables SPI for LED strip
   - Tests for MPU6050 touch sensor on I2C
   - Records MAC address to `/mnt/usb/ft_usb_build/device_macs.txt`
   - **Prompts for reboot** (recommended)

   **Phase 2: Internet Connection (Temporary)**
   - **Prompts for WiFi credentials:**
     ```
     Enter WiFi SSID: smithhome
     Enter WiFi password: ********
     ```
   - Connects wlan1 (USB WiFi) to your home network
   - Tests internet connectivity
   - This connection is temporary (only for package download)

   **Phase 3: Package Installation**
   - Installs BATMAN-adv, batctl, wireless tools
   - Installs Python 3 and development tools
   - Installs LED library (rpi_ws281x)
   - Installs touch sensor library (MPU6050)
   - Installs audio libraries (pygame, sox)
   - **Disconnects USB WiFi** (no longer needed)
   - **You can now remove USB WiFi adapter**

   **Phase 4: Mesh Network Join**
   - **Prompts for mesh configuration:**
     ```
     Enter mesh SSID (default: ft_mesh): ft_mesh2
     Enter mesh channel (default: 1): 1
     ```
   - Configures wlan0 for IBSS ad-hoc mode
   - Joins BATMAN-adv mesh network
   - Assigns static IP (Device1=.101, Device2=.102, etc.)
   - Tests connection to Device0 (192.168.99.100)
   - Creates systemd service for mesh persistence

   **Phase 5: Client Application**
   - **Prompts for Device0 SSH password** (for file download)
   - Downloads client software from Device0 via SCP:
     - `field_client_connection.py`
     - `ft_touch.py`, `ft_led.py`, `ft_audio.py`
     - Audio files (male + female voices, ~6 MB)
   - Creates systemd service `field-client.service`
   - Starts client service
   - Client connects to Device0 on port 6000

8. **Verify device:**
   ```bash
   # Check client service
   sudo systemctl status field-client

   # View client logs
   sudo journalctl -u field-client -f

   # Test Device0 connection
   ping 192.168.99.100

   # Check mesh neighbors
   sudo batctl n
   ```

9. **Register device on Device0:**
   - Go to http://192.168.99.100:5000/settings
   - Find "Device Whitelisting" section
   - Add MAC address from `/mnt/usb/ft_usb_build/device_macs.txt`

10. **Repeat for Device2, Device3, Device4, Device5**

---

## Verification

### After All Devices Built

Run verification script from Device0:

```bash
cd /mnt/usb/ft_usb_build
sudo ./verify_all_devices.sh
```

**This script checks:**
- ✓ Device0 services (mesh, DNS, app)
- ✓ Mesh neighbors visible
- ✓ All field devices pingable
- ✓ Client services running
- ✓ MAC addresses
- ✓ Uptime

### Manual Tests

1. **Web Interface:** http://192.168.99.100:5000
2. **Deploy Test Course:**
   - Go to Coach Interface
   - Select a course
   - Deploy to field devices
3. **Verify LED States:**
   - Orange: Mesh connected
   - Blue: Course deployed
   - Green: Course active
   - Red: Error
4. **Test Touch Sensors:**
   - During active course, touch each device
   - Verify detection on web interface
   - Verify audio plays
5. **Check Logs:**
   ```bash
   sudo journalctl -u field-trainer -f
   sudo journalctl -u field-client -f
   ```

---

## Troubleshooting

### Device0 Issues

**Problem:** Phase 3 fails - wlan1 has no IP
**Solution:**
- Verify USB WiFi adapter connected
- Run Phase 2 again to configure internet
- Check: `ip addr show wlan1`

**Problem:** Phase 4 mesh network fails
**Solution:**
- Verify wlan0 is onboard WiFi (not USB)
- Check udev rules: `cat /etc/udev/rules.d/70-persistent-net.rules`
- Reboot and retry Phase 4

**Problem:** Web interface not accessible
**Solution:**
```bash
sudo systemctl status field-trainer
sudo journalctl -u field-trainer -n 50
# Restart service
sudo systemctl restart field-trainer
```

### Field Device Issues

**Problem:** Phase 1 - Touch sensor not detected
**Solution:**
- Verify MPU6050 connected to I2C pins
- Check I2C address: `sudo i2cdetect -y 1`
- Touch sensor can be installed later, Phase 1 will continue anyway

**Problem:** Phase 2 - WiFi connection fails
**Solution:**
- Verify USB WiFi adapter connected via hub
- Check SSID/password entered correctly
- Verify WiFi network in range
- Try: `sudo iw dev wlan1 scan`

**Problem:** Phase 4 - Cannot join mesh
**Solution:**
- Verify Device0 mesh is active: `ssh pi@192.168.99.100 'sudo batctl n'`
- Check mesh SSID matches Device0
- Verify wlan0 is free (no connection)
- Restart: `sudo systemctl restart batman-mesh-client`

**Problem:** Phase 5 - Cannot download from Device0
**Solution:**
- Test connection: `ping 192.168.99.100`
- Test SSH: `ssh pi@192.168.99.100`
- Verify mesh network: `sudo batctl n`
- Check Device0 services running

**Problem:** Client service won't start
**Solution:**
```bash
# Check logs
sudo journalctl -u field-client -n 50

# Common issues:
# - Missing files: Check /opt/field_client_connection.py exists
# - Python errors: Verify Python libraries installed
# - Connection errors: Check mesh network active

# Restart service
sudo systemctl restart field-client
```

### Mesh Network Issues

**Problem:** Devices can't see each other
**Solution:**
```bash
# On each device, check:
sudo batctl n                    # Should show neighbors
sudo batctl if                   # Should show wlan0 active
iw dev wlan0 info                # Should show IBSS mode
ip addr show bat0                # Should show IP address

# Verify mesh SSID matches on all devices
# Check /usr/local/bin/start-batman-mesh*.sh

# Restart mesh
sudo systemctl restart batman-mesh
```

---

## File Structure on USB

```
/mnt/usb/ft_usb_build/
├── ft_build.sh                      # Main build script (auto-detects device type)
├── gateway_phases/                  # Device0 phases
│   ├── phase1_hardware.sh           # Hardware + udev rules
│   ├── phase2_internet.sh           # Internet (wlan1)
│   ├── phase3_packages.sh           # Packages
│   ├── phase4_mesh.sh               # Mesh network (wlan0)
│   ├── phase5_dns.sh                # DNS/DHCP
│   ├── phase6_nat.sh                # NAT/Firewall
│   ├── phase7_fieldtrainer.sh       # Application
│   └── logging_functions.sh         # Shared utilities
├── client_phases/                   # Device1-5 phases
│   ├── phase1_hardware.sh           # Hardware verification
│   ├── phase2_internet.sh           # USB WiFi (temporary)
│   ├── phase3_packages.sh           # Packages
│   ├── phase4_mesh.sh               # Mesh join
│   ├── phase5_client_app.sh         # Client deployment
│   └── logging_functions.sh         # Shared utilities
├── verify_all_devices.sh            # Verification script (run from Device0)
├── device_macs.txt                  # MAC addresses (auto-generated)
├── .build_state_gateway             # Gateway build state
├── .build_state_client1             # Client 1 build state
├── .build_state_client2             # Client 2 build state
└── ...
```

---

## Build State Tracking

The build system tracks progress separately for each device:
- Gateway: `.build_state_gateway`
- Client1: `.build_state_client1`
- Client2: `.build_state_client2`
- etc.

This allows:
- Resuming failed builds
- Jumping to specific phases
- Re-running phases
- Building multiple devices without losing progress

---

## Best Practices

### Building Multiple Clients

1. ✅ **Build one device at a time**
2. ✅ **Verify each device before building next**
3. ✅ **Use verify_all_devices.sh between builds**
4. ✅ **Register MAC addresses as you go**
5. ✅ **Test LED/touch/audio on each device**

### WiFi Configuration

1. ✅ **DO NOT configure WiFi in Raspberry Pi Imager**
2. ✅ **Let Phase 1 create udev rules** (gateway only)
3. ✅ **Reboot after Phase 1** when prompted
4. ✅ **Use same WiFi SSID/password** for all clients (Phase 2)
5. ✅ **Use same mesh SSID** for all devices (Phase 4)

### Mesh Network

1. ✅ **Build Device0 first** and verify mesh active
2. ✅ **Use consistent mesh SSID** (e.g., ft_mesh2)
3. ✅ **Keep mesh channel the same** (usually channel 1)
4. ✅ **Verify neighbors** after each client build: `sudo batctl n`
5. ✅ **Test ping** before proceeding to Phase 5

---

## Quick Reference Commands

### Device0 (Gateway)
```bash
# Check all services
sudo systemctl status field-trainer
sudo systemctl status batman-mesh
sudo systemctl status dnsmasq

# View mesh neighbors
sudo batctl n

# Check WiFi interfaces
ip addr show wlan0  # Mesh
ip addr show wlan1  # Internet

# View logs
sudo journalctl -u field-trainer -f
```

### Field Devices (Device1-5)
```bash
# Check client service
sudo systemctl status field-client

# View client logs
sudo journalctl -u field-client -f

# Test Device0 connection
ping 192.168.99.100

# Check mesh
sudo batctl n
iw dev wlan0 info
ip addr show bat0

# Restart services
sudo systemctl restart batman-mesh-client
sudo systemctl restart field-client
```

---

## Summary

**Device0 Build:** 7 phases, ~60-75 minutes
**Client Build:** 5 phases, ~45-60 minutes per device
**Total System:** 1 gateway + 5 clients = ~5-6 hours total

**Automation Features:**
- ✓ Auto-detects device type from hostname
- ✓ Separate phase directories (gateway vs client)
- ✓ Per-device build state tracking
- ✓ WiFi credential prompts (clients)
- ✓ Mesh SSID configuration prompts
- ✓ MAC address auto-recording
- ✓ Automatic file download from Device0
- ✓ Systemd services auto-created
- ✓ Verification script included
- ✓ Log cleanup on exit

**One USB drive builds everything!**

---

## Build Script Menu Options

When running `ft_build.sh`, you'll see these menu options:

1. **Run Next Phase** - Execute the next phase in sequence
2. **Run All Remaining Phases** - Automatically run all remaining phases
3. **Jump to Specific Phase** - Skip ahead or go back to a specific phase
4. **Re-run Current/Previous Phase** - Useful for troubleshooting failures
5. **View Build Status** - See progress without running anything
6. **Reset Build (Start Over)** - Clear build state and restart from Phase 1
7. **Exit** - Exit without cleanup
8. **Clean Logs and Exit** - Remove all log files from USB and exit

**Tip:** Use option 8 before removing the USB drive to keep it clean!

---

## Support

For issues:
1. Check troubleshooting section above
2. Review logs: `sudo journalctl -u <service-name> -n 100`
3. Run verification script: `./verify_all_devices.sh`
4. Check phase output for errors

---

**Version:** 2.0
**Last Updated:** 2026-01-02
**Tested On:** Raspberry Pi OS Trixie (Debian 13) 32-bit
