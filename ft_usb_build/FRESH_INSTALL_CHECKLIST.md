# Fresh OS Install - Checklist

**Date**: 2025-11-18
**Network**: smithhome (confirmed working DHCP)

---

## Pre-Installation Checklist

### Hardware
- [ ] Raspberry Pi 3 A+ (512MB RAM)
- [ ] USB WiFi adapter (wlan1) inserted
- [ ] USB drive mounted at /mnt/usb
- [ ] Fresh Raspberry Pi OS installed

### Network Information
- **WiFi Network**: smithhome
- **Password**: (have ready)
- **DHCP**: Confirmed working ✅
- **Expected IP Range**: 192.168.7.x
- **Gateway**: 192.168.7.1

### Pre-Flight Checks on Fresh OS

Before starting installation:

```bash
# 1. Verify USB drive mounted
ls /mnt/usb/ft_usb_build/

# 2. Check wlan1 exists
ip link show wlan1

# 3. Check system date (should be reasonable)
date

# 4. Clear old logs (optional)
sudo rm -f /mnt/usb/install_logs/*.log
```

---

## Installation Steps

### Step 1: Navigate to USB Build Directory
```bash
cd /mnt/usb/ft_usb_build
```

### Step 2: Launch Installation Menu
```bash
sudo ./install_menu.sh
```

### Step 3: Select Installation Option
- **Option 1**: Run all phases (1-7) - Recommended
- **Option 2**: Run individual phase if needed

### Step 4: Phase 2 WiFi Credentials
When prompted during Phase 2:
- **SSID**: smithhome
- **Password**: [enter your smithhome password]

---

## Expected Installation Flow

### Phase 1: Basic Setup
- Hostname → Device0pi
- Updates system packages
- Installs git, python basics

### Phase 1.5: Network Prerequisites
- Installs dhcpcd5
- Installs wireless-tools
- Prepares for WiFi

### Phase 2: Internet Connection (CRITICAL)
- Creates wlan1-wpa.service
- Creates wlan1-dhcp.service
- Prompts for smithhome credentials
- Connects to WiFi
- Gets IP via DHCP (expect: 192.168.7.x)
- Verifies internet
- **Expected duration**: 1-2 minutes

### Phase 3: Package Installation
- Installs Python packages
- Installs Flask, PIL, etc.
- **Expected duration**: 5-10 minutes
- **Requires stable internet** ✅

### Phase 4: Mesh Network
- Configures batman-adv
- Sets up mesh on wlan0
- **May prompt for mesh IP** (use defaults or specify)

### Phase 5: Field Trainer Application
- Clones or copies FT code
- Sets up database
- Configures services

### Phase 6: Audio/Hardware
- Audio configuration
- GPIO setup

### Phase 7: Final Configuration
- Systemd service setup
- Final verification

---

## Monitoring During Installation

### Watch for These Success Indicators

**Phase 2 Success:**
```
✓ Created two-service architecture
✓ Services enabled
✓ WiFi configured
✓ wpa service active
✓ dhcp service active
✓ IP obtained: 192.168.7.x
✓ Internet working!
Phase 2 Complete
```

**Phase 3 Success:**
```
✓ All packages installed
✓ Python dependencies satisfied
Phase 3 Complete
```

### If Issues Occur

**Phase 2 Troubleshooting:**
```bash
# Run diagnostic
sudo /mnt/usb/ft_usb_build/scripts/diagnose_phase2.sh

# Check logs
cat /mnt/usb/install_logs/phase2_internet_latest.log
```

**Phase 3 Troubleshooting:**
```bash
# Check internet still working
ping -c 3 8.8.8.8

# Check logs
cat /mnt/usb/install_logs/phase3_packages_latest.log
```

**Network Issues:**
```bash
# Switch WiFi if needed
sudo /mnt/usb/ft_usb_build/scripts/switch_wifi.sh

# Force DHCP renewal
sudo /mnt/usb/ft_usb_build/scripts/force_dhcp_renew.sh
```

---

## Post-Installation Verification

After all phases complete:

### 1. Verify Services Running
```bash
systemctl status wlan1-wpa.service
systemctl status wlan1-dhcp.service
systemctl status field-trainer.service  # or appropriate FT service
```

### 2. Verify Network
```bash
# Check IP
ip addr show wlan1

# Check internet
ping -c 3 8.8.8.8

# Check DNS
host google.com
```

### 3. Run Network Stress Test
```bash
cd /mnt/usb/ft_usb_build
sudo ./install_menu.sh
# Select option 6: Network Stress Test
# Run for 300-600 seconds
```

### 4. Reboot Test
```bash
sudo reboot

# After reboot, verify:
systemctl status wlan1-wpa.service
systemctl status wlan1-dhcp.service
ip addr show wlan1
ping -c 3 8.8.8.8
```

---

## Success Criteria

Installation is successful when:

- ✅ All 7 phases complete without errors
- ✅ wlan1 has IP address (192.168.7.x range)
- ✅ Internet connectivity working
- ✅ Services show "active (running)"
- ✅ Network stress test maintains connection (5+ minutes)
- ✅ Services survive reboot
- ✅ Field Trainer application accessible

---

## Known Working Configuration

Based on testing:

- **Network**: smithhome ✅
- **DHCP**: Working (192.168.7.1 server)
- **Signal**: -58 dBm (good)
- **Frequency**: 5GHz supported
- **Lease Time**: 14400 seconds (4 hours)
- **Phase 2 Script**: Fixed and tested ✅

---

## Logs Location

All logs saved to: `/mnt/usb/install_logs/`

**Phase logs:**
- `phase1_basic_setup_TIMESTAMP.log`
- `phase1.5_network_prerequisites_TIMESTAMP.log`
- `phase2_internet_TIMESTAMP.log`
- `phase3_packages_TIMESTAMP.log`
- etc.

**Diagnostic logs:**
- `phase2_diagnostic_TIMESTAMP.log`
- `wifi_switch_TIMESTAMP.log`
- `network_stress_test_TIMESTAMP.log`

**Latest logs** (symlinks):
- `phase2_internet_latest.log`
- `phase2_diagnostic_latest.log`

---

## Notes

- Fresh OS means no leftover services to conflict ✅
- smithhome network is confirmed working ✅
- Phase 2 fixes are in place and tested ✅
- All diagnostic tools available if needed ✅

---

**Ready to install!** 🚀

Run: `cd /mnt/usb/ft_usb_build && sudo ./install_menu.sh`
