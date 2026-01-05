# Field Trainer Installation - Quick Start Guide

**For users unfamiliar with setup - Follow these steps exactly!**

---

## What You Need

- ✅ Raspberry Pi (RPi 3 A+ or RPi 5)
- ✅ Fresh Debian Trixie OS installed
- ✅ USB WiFi adapter plugged in (for RPi 3 A+)
- ✅ This USB drive
- ✅ Keyboard and monitor OR SSH access
- ✅ Your home WiFi name and password

---

## Installation Steps

### Step 1: Mount the USB Drive

```bash
# Plug in the USB drive, then:
sudo mkdir -p /mnt/usb
sudo mount /dev/sda1 /mnt/usb
```

**Verify it worked:**
```bash
ls /mnt/usb/ft_usb_build/
```
You should see `install_menu.sh` and a `phases/` directory.

---

### Step 2: Start the Installation Menu

```bash
cd /mnt/usb/ft_usb_build
sudo ./install_menu.sh
```

You'll see a menu like this:

```
=========================================
  Field Trainer Installation System
=========================================

Installation Progress:

  ○ Phase 1: Hardware Setup (SSH, I2C, SPI) [PENDING]
  ○ Phase 2: Internet Connection (WiFi) [PENDING]
  ○ Phase 3: Package Installation (apt, pip) [PENDING]
  ○ Phase 4: Mesh Network (batman-adv) [PENDING]
  ○ Phase 5: DNS/DHCP Server (dnsmasq) [PENDING]
  ○ Phase 6: NAT/Firewall (iptables) [PENDING]
  ○ Phase 7: Field Trainer Application [PENDING]

Options:

  1) Run Next Phase (Phase 1: Hardware Setup)
  2) Run Specific Phase (manual selection)
  3) View Phase Logs
  4) Reset Installation State
  5) Run Diagnostics
  6) View Help Documentation
  7) Exit
```

---

### Step 3: Run Each Phase in Order

**Just keep selecting Option 1 "Run Next Phase"** and let the system guide you!

#### Phase 1: Hardware Setup
- Press `1` to start
- Enables SSH, I2C, and SPI
- **May require reboot** - if prompted, reboot then run menu again
- Takes: ~2 minutes

#### Phase 2: Internet Connection
- Press `1` to continue
- You'll be asked for:
  - **WiFi SSID** (your WiFi network name)
  - **WiFi Password** (your WiFi password)
- Script will:
  - Connect to your WiFi
  - **Wait 3 minutes for network to stabilize** (countdown timer)
  - Run diagnostic checks
- Takes: ~5-6 minutes (includes 3-minute wait)
- **This is normal!** The wait ensures everything works properly.

#### Phase 3: Package Installation
- Press `1` to continue
- Installs all required software (git, Python packages, etc.)
- **Requires internet from Phase 2**
- Takes: ~5-10 minutes (depends on internet speed)
- If it fails:
  - Check Phase 2 completed successfully
  - Run Option 5 (Diagnostics) to check network
  - Retry Phase 3

#### Phase 4: Mesh Network
- Press `1` to continue
- Sets up batman-adv mesh network
- Takes: ~2 minutes

#### Phase 5: DNS/DHCP Server
- Press `1` to continue
- Configures DNS and DHCP for mesh network
- Takes: ~2 minutes

#### Phase 6: NAT/Firewall
- Press `1` to continue
- Enables internet sharing to mesh network
- **Important:** Your SSH connection will stay active
- Takes: ~3 minutes

#### Phase 7: Field Trainer Application
- Press `1` to continue
- Clones and installs Field Trainer
- You'll be asked:
  - **Repository URL** (press Enter for default)
  - **Branch name** (press Enter for "main")
- Takes: ~5 minutes

---

### Step 4: Installation Complete!

When all phases show ✓ COMPLETED, your Field Trainer is ready!

Access it at:
- **Web Interface:** http://[device-ip]:5000
- **Coach Interface:** http://[device-ip]:5001

Find your IP with:
```bash
ip addr show wlan1 | grep "inet "
```

---

## If Something Goes Wrong

### Phase Failed?

The menu will offer to retry (up to 3 times). It will also show troubleshooting tips.

### View Logs

From the menu:
- Select Option 3 "View Phase Logs"
- Logs are in: `/mnt/usb/install_logs/`

To view a specific log:
```bash
cat /mnt/usb/install_logs/phase2_internet_latest.log
```

To find errors:
```bash
grep ERROR /mnt/usb/install_logs/*.log
```

### Run Diagnostics

From the menu:
- Select Option 5 "Run Diagnostics"
- This checks your network connectivity

### Common Issues

**Phase 2 Failed - WiFi Not Connecting:**
- Check WiFi password is correct
- Make sure WiFi router is on
- Check USB WiFi adapter is plugged in
- Try Option 2 to manually re-run Phase 2

**Phase 3 Failed - Packages Not Installing:**
- Make sure Phase 2 completed successfully
- Run Option 5 (Diagnostics) - all checks should be green
- Check: `ping -c 3 8.8.8.8` (should work)
- Check: `cat /etc/resolv.conf` (should have nameservers)
- Try again after waiting 1-2 more minutes

**Lost Internet After Phase 6:**
- Run emergency script:
  ```bash
  sudo /mnt/usb/ft_usb_build/phases/EMERGENCY_RESTORE_CONNECTIVITY.sh
  ```

### Reset and Start Over

From the menu:
- Select Option 4 "Reset Installation State"
- This marks all phases as PENDING
- You can start from Phase 1 again

---

## Important Notes

### Phase 2 Wait Time

**The 3-minute wait after Phase 2 is REQUIRED!**

This wait ensures:
- Network is fully stable
- DNS is configured
- Package repositories are reachable
- Phase 3 will succeed

**Do not skip this** - it happens automatically.

### Phase Numbers Changed

**Old documentation may show different numbers!**

- Old Phase 0 = New Phase 1 (Hardware)
- Old Phase 2 = Still Phase 2 (Internet)
- Old Phase 1 = New Phase 3 (Packages)
- Old Phase 3 = New Phase 4 (Mesh)
- Old Phase 4 = New Phase 5 (DNS)
- Old Phase 5 = New Phase 6 (NAT)
- Old Phase 6 = New Phase 7 (Application)

### Manual Installation (Without Menu)

If you prefer to run phases manually:

```bash
cd /mnt/usb/ft_usb_build/phases
sudo ./phase1_hardware.sh
sudo ./phase2_internet.sh
sudo ./phase3_packages.sh
sudo ./phase4_mesh.sh
sudo ./phase5_dns.sh
sudo ./phase6_nat.sh
sudo ./phase7_fieldtrainer.sh
```

**But we recommend using the menu!** It tracks progress and handles errors.

---

## Timeline

**Total installation time: 20-35 minutes**

- Phase 1: 2 min
- Phase 2: 6 min (includes 3-min wait)
- Phase 3: 5-10 min
- Phase 4: 2 min
- Phase 5: 2 min
- Phase 6: 3 min
- Phase 7: 5 min

---

## Getting Help

### Check Logs
```bash
# View all logs
ls -lh /mnt/usb/install_logs/

# View latest Phase 2 log
cat /mnt/usb/install_logs/phase2_internet_latest.log

# Find all errors
grep -i error /mnt/usb/install_logs/*.log

# View last 20 lines of Phase 3
tail -20 /mnt/usb/install_logs/phase3_packages_latest.log
```

### Check System Status
```bash
# Check internet
ping -c 3 8.8.8.8

# Check WiFi
ip addr show wlan1

# Check DNS
cat /etc/resolv.conf

# Check Field Trainer service
sudo systemctl status field-trainer
```

### Documentation

More detailed docs on the USB drive:
- `/mnt/usb/ft_usb_build/CRITICAL_INSTALLATION_ORDER.md`
- `/mnt/usb/ft_usb_build/PHASE_ORDER_AND_UPDATES.md`
- `/mnt/usb/ft_usb_build/PHASE5_PHASE6_FIXES.md`

---

## Success!

When installation is complete, you'll see all phases with ✓ green checkmarks.

Your Field Trainer is now ready to use!

```
Installation Progress:

  ✓ Phase 1: Hardware Setup (SSH, I2C, SPI) [COMPLETED]
  ✓ Phase 2: Internet Connection (WiFi) [COMPLETED]
  ✓ Phase 3: Package Installation (apt, pip) [COMPLETED]
  ✓ Phase 4: Mesh Network (batman-adv) [COMPLETED]
  ✓ Phase 5: DNS/DHCP Server (dnsmasq) [COMPLETED]
  ✓ Phase 6: NAT/Firewall (iptables) [COMPLETED]
  ✓ Phase 7: Field Trainer Application [COMPLETED]
```

Enjoy your Field Trainer system!
