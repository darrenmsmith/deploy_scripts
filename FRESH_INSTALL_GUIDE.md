# Field Trainer Fresh Installation Guide

**Version:** 2025.12.31
**Distribution Repository:** https://github.com/darrenmsmith/field-trainer-releases
**Target System:** Raspberry Pi 3 A+ (Coach Station)

---

## 📋 Overview

This guide walks you through building a complete Field Trainer system from a fresh Raspberry Pi OS installation using the automated USB build scripts.

**Total Time:** ~60-75 minutes (depending on internet speed and Pi 3 A+ performance)

---

## 🛠️ Prerequisites

### Hardware Required
- **Raspberry Pi 3 A+** (512MB RAM)
- **16GB+ microSD card** (Class 10 or better, 32GB recommended)
- **USB drive** with Field Trainer build scripts (`/mnt/usb/ft_usb_build/`)
- **Power supply** (official Raspberry Pi power supply - 5V 2.5A minimum)
- **Monitor, keyboard, mouse** (for initial setup)
- **Internet connection** (WiFi recommended for Pi 3 A+)
- **Optional:** USB hub if connecting multiple USB devices

### Important Notes for Pi 3 A+
- **Single USB port:** You may need a USB hub to connect keyboard/mouse/USB drive simultaneously
- **512MB RAM:** System will run efficiently but avoid running unnecessary services
- **WiFi built-in:** No Ethernet port, WiFi connection required
- **Performance:** Slightly slower than Pi 4, but fully capable for Field Trainer

### Software Required
- **Raspberry Pi Imager** (download from https://www.raspberrypi.com/software/)
- **Raspberry Pi OS Trixie (Debian 13)** - 32-bit or 64-bit (32-bit recommended for 512MB RAM)

### Before You Begin
- USB drive contains the build system at `/mnt/usb/ft_usb_build/`
- Build script is located at `/mnt/usb/ft_usb_build/ft_build.sh`
- Phase 7 configured to clone: `https://github.com/darrenmsmith/field-trainer-releases.git`

---

## 📝 Step-by-Step Installation

### Phase 0: Prepare the SD Card

**Step 1: Download Raspberry Pi Imager**
1. Go to https://www.raspberrypi.com/software/
2. Download and install Raspberry Pi Imager for your OS (Windows/Mac/Linux)

**Step 2: Flash Raspberry Pi OS**
1. Insert microSD card into your computer
2. Launch Raspberry Pi Imager
3. Click **"Choose Device"** → Select **Raspberry Pi 3**
4. Click **"Choose OS"** → **Raspberry Pi OS (other)** → **Raspberry Pi OS Lite (32-bit)** or **Raspberry Pi OS (32-bit)**
   - **Lite recommended** for 512MB RAM (no desktop environment)
   - **Full OS** works but uses more RAM
5. Click **"Choose Storage"** → Select your microSD card
6. Click **"Next"**

**Step 3: Configure OS Settings (REQUIRED for Pi 3 A+)**
When prompted "Would you like to apply OS customisation settings?":

1. Click **"Edit Settings"**
2. **General Tab:**
   - Hostname: `fieldtrainer` (or your preference)
   - Username: `pi`
   - Password: [Your secure password]
   - ✅ **Configure wireless LAN** (REQUIRED - no Ethernet on Pi 3 A+)
     - SSID: [Your WiFi network name]
     - Password: [Your WiFi password]
     - Country: [Your country code - important for WiFi regulations]
   - ✅ Set locale settings
     - Timezone: [Your timezone]
     - Keyboard layout: [Your layout]

3. **Services Tab:**
   - ✅ Enable SSH
   - Use password authentication

4. Click **"Save"**
5. Click **"Yes"** to apply customisation settings
6. Confirm **"Yes"** to erase all data on the SD card

**Step 4: Wait for Flash to Complete**
- Writing... (takes 5-10 minutes)
- Verifying... (takes 2-5 minutes)
- When complete, click **"Continue"**
- Safely eject the microSD card

---

### Phase 1: Initial Raspberry Pi Setup

**Step 5: First Boot**
1. Insert microSD card into Raspberry Pi 3 A+
2. Connect monitor, keyboard (use USB hub if needed)
3. Insert USB drive with build scripts (may need USB hub)
4. WiFi will auto-connect if configured in Step 3
5. Connect power supply (5V 2.5A minimum)
6. Raspberry Pi will boot (45-90 seconds for first boot)

**Step 6: Login**
- If using **Pi OS Lite** (no desktop):
  - You'll see text login prompt
  - Login: `pi`
  - Password: [Your password from Step 3]

- If using **Pi OS Full** (with desktop):
  - Desktop will load (may take 60-90 seconds on Pi 3 A+)
  - Login automatically or enter credentials

**Step 7: Complete Initial Setup (if desktop wizard appears)**
1. Set country, language, timezone (if not done in imager)
2. Change password (if not done in imager)
3. Connect to WiFi (if not done in imager)
4. Update software (say "Yes" - this takes 15-20 minutes on Pi 3 A+)
5. Reboot when prompted

**Step 8: Open Terminal**
- **Pi OS Lite:** You're already at terminal
- **Pi OS Full:** Click terminal icon in taskbar, or Menu → Accessories → Terminal

**Step 9: Update System (if not done automatically)**
```bash
sudo apt update
sudo apt upgrade -y
```
*Note: This takes longer on Pi 3 A+ (~15-20 minutes)*

**Step 10: Verify Internet Connection**
```bash
ping -c 3 github.com
```
You should see replies. Press Ctrl+C to stop.

If WiFi not connected:
```bash
sudo raspi-config
# Select: 1 System Options → S1 Wireless LAN
# Enter SSID and password
# Reboot
```

**Step 11: Verify Git is Installed**
```bash
git --version
```
Should show: `git version 2.x.x`

If not installed:
```bash
sudo apt install git -y
```

---

### Phase 2: Mount USB Drive and Prepare Build

**Step 12: Verify USB Drive Inserted**
- USB drive should be inserted (may need USB hub)
- Wait 5-10 seconds for auto-mount

**Step 13: Verify USB Drive Mounted**
```bash
ls -la /mnt/usb/
```

You should see the `ft_usb_build/` directory.

**If USB not mounted:**
```bash
# Find the USB device
lsblk
# Look for your USB drive (usually sda1)

# Create mount point
sudo mkdir -p /mnt/usb

# Mount manually (replace sda1 with your device)
sudo mount /dev/sda1 /mnt/usb

# Verify
ls -la /mnt/usb/
```

**Step 14: Verify Build Scripts Exist**
```bash
ls -la /mnt/usb/ft_usb_build/
```

You should see:
- `ft_build.sh` (main build script)
- `phases/` directory
- `README.md`

**Step 15: Make Build Script Executable**
```bash
sudo chmod +x /mnt/usb/ft_usb_build/ft_build.sh
sudo chmod +x /mnt/usb/ft_usb_build/phases/*.sh
```

---

### Phase 3: Run the Automated Build

**Step 16: Navigate to Build Directory**
```bash
cd /mnt/usb/ft_usb_build
```

**Step 17: Review Build Phases**
The build script runs 7 phases:
- **Phase 0**: System preparation and updates
- **Phase 1**: Install core packages (Python, build tools)
- **Phase 2**: Configure mesh networking (batman-adv)
- **Phase 3**: Install and configure dnsmasq (DNS/DHCP)
- **Phase 4**: Configure network interfaces
- **Phase 5**: Install touchscreen support (skip for Pi 3 A+)
- **Phase 6**: Create systemd services
- **Phase 7**: Clone Field Trainer application and initialize database

**Step 18: Run the Build Script**
```bash
sudo ./ft_build.sh
```

**Step 19: Follow the Build Process**

The script will:

**Phase 0 - System Preparation**
- Update package lists
- Upgrade existing packages
- Install build essentials
- **Time:** 10-15 minutes on Pi 3 A+
- **Interaction:** Minimal, may ask to continue

**Phase 1 - Core Packages**
- Install Python 3, pip, development libraries
- Install Flask, Pillow, RPi.GPIO
- **Time:** 5-8 minutes on Pi 3 A+
- **Interaction:** None

**Phase 2 - Mesh Networking**
- Install batman-adv kernel module
- Configure mesh networking
- **Time:** 3-5 minutes on Pi 3 A+
- **Interaction:** None

**Phase 3 - DNS/DHCP**
- Install dnsmasq
- Configure for field devices
- **Time:** 2-3 minutes
- **Interaction:** None

**Phase 4 - Network Configuration**
- Configure wlan0, bat0 interfaces
- Set static IPs
- **Time:** 1-2 minutes
- **Interaction:** None

**Phase 5 - Touchscreen (Optional)**
- **Can skip for Pi 3 A+ coach station**
- Install touchscreen drivers if present
- **Time:** 1-2 minutes
- **Interaction:** May ask if you want to skip

**Phase 6 - Systemd Services**
- Create field-trainer.service
- Create mesh-network.service
- Enable auto-start on boot
- **Time:** 1 minute
- **Interaction:** None

**Phase 7 - Field Trainer Application** ⭐ **CRITICAL PHASE**

This phase will:

1. **Clone Repository**
   - URL: `https://github.com/darrenmsmith/field-trainer-releases.git`
   - Destination: `/opt`
   - **Time:** 2-4 minutes on Pi 3 A+ (WiFi dependent)
   - **Interaction:** Will prompt for repository URL (press Enter for default)

2. **Create Data Directory**
   - Creates `/opt/data/`

3. **Initialize Database** ✨ **NEW**
   - Runs `/opt/scripts/init_clean_database.py`
   - Creates clean database with:
     - 14 built-in courses
     - AI Team
     - Empty athlete/session data
   - **Interaction:** If database exists, will ask to reinitialize (choose 'y' for fresh install)

4. **Install Python Dependencies**
   - From `/opt/requirements.txt`
   - Flask, Pillow, and other packages
   - **Time:** 3-5 minutes on Pi 3 A+

5. **Create Systemd Service**
   - Installs `/etc/systemd/system/field-trainer.service`
   - Configures auto-start

6. **Verify Database**
   - Checks for 14 courses
   - Verifies AI Team exists
   - Validates database before starting

7. **Start Services**
   - Starts field-trainer.service
   - Enables auto-start on boot

**IMPORTANT PROMPTS in Phase 7:**

**Prompt 1: Repository URL**
```
Default repository: https://github.com/darrenmsmith/field-trainer-releases.git
Enter repository URL (or press Enter for default):
```
**Action:** Press **Enter** to use default

**Prompt 1b: Version Selection** ✨ **NEW**
```
Fetching available releases from GitHub...
Latest release: v2025.12.31

Version options:
  1. v2025.12.31 (latest release - RECOMMENDED)
  2. main (bleeding edge - latest development)
  3. Custom version/branch

Select option (1/2/3, default: 1):
```
**Action:** Press **Enter** for latest stable release (recommended)
- Option 1: Latest release (v2025.12.31) - **RECOMMENDED**
- Option 2: Development version (main branch)
- Option 3: Specific older version (if needed)

**Prompt 2: Database Initialization (if database exists)**
```
Database already exists at /opt/data/field_trainer.db
Reinitialize database? This will backup existing and create clean database. (y/n):
```
**Action for Fresh Install:** Type **y** and press Enter

**Prompt 3: Verification**
```
Database initialized successfully!
Built-in courses: 14
AI Team: 1
Athletes: 0
```
**Action:** Verify numbers are correct, press Enter to continue

---

### Phase 4: Verify Installation

**Step 20: Check Build Completion**
After all phases complete, you should see:
```
================================================================================
Field Trainer Installation Complete!
================================================================================

All phases completed successfully.

Next Steps:
1. Reboot the system: sudo reboot
2. Access web interface: http://localhost:5000 (or http://fieldtrainer.local:5000)
3. Check service status: sudo systemctl status field-trainer
```

**Step 21: Verify Files Installed**
```bash
ls -la /opt/
```

You should see:
- `field_trainer/` directory
- `services/` directory
- `routes/` directory
- `scripts/` directory
- `templates/` directory
- `static/` directory
- `data/` directory
- `field_trainer_main.py`
- `coach_interface.py`
- `field_client_connection.py`
- `README.md`

**Step 22: Verify Database Created**
```bash
ls -lh /opt/data/field_trainer.db
```

Should show: ~204 KB database file

**Step 23: Verify Database Contents**
```bash
sqlite3 /opt/data/field_trainer.db "SELECT COUNT(*) FROM courses;"
```

Should return: `14`

```bash
sqlite3 /opt/data/field_trainer.db "SELECT COUNT(*) FROM teams;"
```

Should return: `1` (AI Team)

**Step 24: Check Service Status**
```bash
sudo systemctl status field-trainer
```

Should show:
- `Active: active (running)` in green
- No error messages

If not running:
```bash
sudo systemctl start field-trainer
sudo systemctl enable field-trainer
```

**Step 25: Verify Service Logs**
```bash
sudo journalctl -u field-trainer -n 50 --no-pager
```

Look for:
- `Flask application starting`
- `Running on http://0.0.0.0:5000`
- `Database manager initialized`
- `Loaded 14 courses from database`
- No error messages

---

### Phase 5: First Access

**Step 26: Reboot System**
```bash
sudo reboot
```

System will reboot in 10-20 seconds.

**Step 27: Access Web Interface**

After reboot, open a web browser:

**On the Raspberry Pi 3 A+ (if using full OS with desktop):**
```
http://localhost:5000
```

**From another computer on the same WiFi network:**
```
http://fieldtrainer.local:5000
```
or
```
http://[IP-ADDRESS]:5000
```

**To find IP address:**
```bash
hostname -I
```

**Step 28: Verify Web Interface Loads**

You should see:
- Field Trainer Coach Interface
- Navigation menu
- Course selection dropdown showing 14 courses
- Session management options

*Note: Initial page load may take 5-10 seconds on Pi 3 A+ with 512MB RAM*

**Step 29: Verify Built-in Courses**

In the web interface, check the course dropdown shows:

**Speed:**
- 40 Yard Dash
- 60 Yard Dash
- 100m Sprint

**Agility:**
- Pro Agility (5-10-5)
- 3-Cone Drill
- T-Test

**Conditioning:**
- Beep Test (20m)
- Beep Test (15m)
- Suicide Sprint

**Reaction:**
- Simon Says (Random)
- Simon Says (4 Colors)

**Warmup:**
- Warmup: Round 1
- Warmup: Round 2
- Warmup: Round 3

**Step 30: Verify AI Team Exists**

In the web interface:
1. Navigate to Teams section
2. Verify "AI Team" appears in the team list

---

## ✅ Installation Complete!

Your Field Trainer system is now:
- ✅ Fully installed and configured on Raspberry Pi 3 A+
- ✅ Database initialized with 14 built-in courses
- ✅ AI Team ready for testing
- ✅ Web interface accessible
- ✅ Services auto-start on boot
- ✅ Ready to add athletes and run sessions

---

## 🧪 Testing the System

### Test 1: Create Test Athlete
1. Navigate to Athletes section
2. Click "Add Athlete"
3. Enter test data
4. Verify athlete appears in list

### Test 2: Create Test Session
1. Navigate to Sessions
2. Select a course (e.g., "Simon Says Random")
3. Select AI Team
4. Click "Create Session"
5. Verify session created

### Test 3: Check Field Device Registry
```bash
# View connected field devices
cat /opt/data/network-status.json
```

Initially should show no devices (empty or minimal).

### Test 4: Check Mesh Network
```bash
# Check mesh interface
sudo batctl if
```

Should show wlan0 as mesh interface.

---

## 🔧 Troubleshooting

### Problem: Build Script Fails During Phase 7

**Symptom:** Error cloning repository

**Solution:**
```bash
# Check internet connection
ping -c 3 github.com

# Check WiFi connection
iwconfig wlan0

# Clone manually
sudo git clone https://github.com/darrenmsmith/field-trainer-releases.git /opt

# Run phase 7 manually
cd /mnt/usb/ft_usb_build/phases
sudo ./phase7_fieldtrainer.sh
```

### Problem: Database Not Initialized

**Symptom:** Database file doesn't exist or is empty

**Solution:**
```bash
# Run initialization script manually
cd /opt
sudo python3 scripts/init_clean_database.py /opt/data/field_trainer.db

# Verify
sqlite3 /opt/data/field_trainer.db "SELECT COUNT(*) FROM courses;"
```

### Problem: Service Won't Start

**Symptom:** `sudo systemctl status field-trainer` shows failed/inactive

**Solution:**
```bash
# Check logs for errors
sudo journalctl -u field-trainer -n 100 --no-pager

# Common issues:
# 1. Missing dependencies
sudo pip3 install -r /opt/requirements.txt

# 2. Database missing
sudo python3 /opt/scripts/init_clean_database.py /opt/data/field_trainer.db

# 3. Port already in use
sudo netstat -tlnp | grep 5000

# Restart service
sudo systemctl restart field-trainer
```

### Problem: Web Interface Slow or Unresponsive

**Symptom:** Pages take long time to load on Pi 3 A+ (512MB RAM)

**Solution:**
```bash
# 1. Check memory usage
free -h

# 2. Reduce memory usage - disable desktop (if using full OS)
sudo raspi-config
# Select: 1 System Options → S5 Boot / Auto Login → B1 Console

# 3. Close unnecessary applications

# 4. Consider using Pi OS Lite instead of full OS
```

### Problem: WiFi Connection Issues

**Symptom:** Cannot connect to WiFi

**Solution:**
```bash
# 1. Check WiFi status
iwconfig wlan0

# 2. Reconfigure WiFi
sudo raspi-config
# Select: 1 System Options → S1 Wireless LAN

# 3. Check WiFi country code is set
sudo raspi-config
# Select: 5 Localisation Options → L4 WLAN Country

# 4. Restart networking
sudo systemctl restart networking

# 5. Check WiFi networks
sudo iwlist wlan0 scan | grep ESSID
```

### Problem: USB Drive Not Mounting

**Symptom:** `/mnt/usb/` doesn't exist or is empty

**Solution:**
```bash
# 1. Create mount point
sudo mkdir -p /mnt/usb

# 2. Find USB device
lsblk
# Look for your USB drive (usually /dev/sda1)

# 3. Mount manually
sudo mount /dev/sda1 /mnt/usb

# 4. Verify
ls -la /mnt/usb/ft_usb_build/

# 5. If using USB hub, try different ports
```

### Problem: Web Interface Not Accessible from Other Devices

**Symptom:** Can access on Pi but not from other computers

**Solution:**
```bash
# 1. Find Pi's IP address
hostname -I

# 2. Verify service is listening on all interfaces
sudo netstat -tlnp | grep 5000
# Should show 0.0.0.0:5000 not 127.0.0.1:5000

# 3. Try accessing from another device:
# http://[PI-IP-ADDRESS]:5000

# 4. Check firewall (if enabled)
sudo ufw status
sudo ufw allow 5000/tcp
```

---

## 📖 Post-Installation

### Accessing the System Remotely

**Via SSH:**
```bash
ssh pi@fieldtrainer.local
# or
ssh pi@[IP-ADDRESS]
```

**Via Web Browser (from another device on same WiFi):**
```
http://fieldtrainer.local:5000
# or
http://[IP-ADDRESS]:5000
```

### Managing the Service

**Check status:**
```bash
sudo systemctl status field-trainer
```

**Start/Stop/Restart:**
```bash
sudo systemctl start field-trainer
sudo systemctl stop field-trainer
sudo systemctl restart field-trainer
```

**View logs:**
```bash
# Last 50 lines
sudo journalctl -u field-trainer -n 50

# Follow logs in real-time
sudo journalctl -u field-trainer -f
```

**Disable auto-start:**
```bash
sudo systemctl disable field-trainer
```

**Enable auto-start:**
```bash
sudo systemctl enable field-trainer
```

### Updating the System

**Update OS:**
```bash
sudo apt update
sudo apt upgrade -y
```

**Update Field Trainer (to new release):**
```bash
cd /opt
sudo git pull origin main

# Restart service
sudo systemctl restart field-trainer
```

### Backup the Database

**Create backup:**
```bash
sudo cp /opt/data/field_trainer.db /opt/data/field_trainer.db.backup_$(date +%Y%m%d_%H%M%S)
```

**Restore backup:**
```bash
sudo cp /opt/data/field_trainer.db.backup_YYYYMMDD_HHMMSS /opt/data/field_trainer.db
sudo systemctl restart field-trainer
```

---

## 🎯 Pi 3 A+ Specific Considerations

### Memory Management (512MB RAM)
- System runs efficiently but avoid unnecessary services
- Use Pi OS Lite for best performance
- Monitor memory usage: `free -h`
- Close unused applications

### Single USB Port
- Use a powered USB hub for multiple devices
- Or alternate between keyboard/mouse and USB drive
- Consider SSH access to avoid needing keyboard/mouse

### WiFi Only (No Ethernet)
- Ensure WiFi country code is set correctly
- Strong WiFi signal recommended
- 2.4GHz WiFi works best for mesh networking
- Consider WiFi extender if signal is weak

### Performance Optimization
```bash
# Reduce GPU memory (if using headless/Lite)
sudo raspi-config
# Select: 4 Performance Options → P2 GPU Memory → Set to 16MB

# Disable Bluetooth if not needed
sudo systemctl disable bluetooth

# Reduce swap file if using SD card (extends SD card life)
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# Change CONF_SWAPSIZE=100 to CONF_SWAPSIZE=256
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

### Recommended Configuration for Pi 3 A+
- **OS:** Raspberry Pi OS Lite (32-bit) - Best performance
- **Boot:** Console auto-login (no desktop)
- **Access:** SSH from another computer
- **GPU Memory:** 16MB (headless)
- **Swap:** 256MB
- **Bluetooth:** Disabled (if not needed)

---

## 📞 Support & Documentation

### Documentation Locations
- **Technical Overview:** `/opt/FIELD_TRAINER_TECHNICAL_OVERVIEW.md`
- **README:** `/opt/README.md`
- **This Guide:** `/mnt/usb/FRESH_INSTALL_GUIDE.md`

### Useful Commands Reference

**System Information:**
```bash
# OS version
cat /etc/os-release

# Raspberry Pi model
cat /proc/device-tree/model

# IP addresses
hostname -I

# Disk usage
df -h

# Memory usage
free -h

# CPU temperature
vcgencmd measure_temp
```

**Field Trainer Specific:**
```bash
# Check database size
ls -lh /opt/data/field_trainer.db

# Count courses
sqlite3 /opt/data/field_trainer.db "SELECT COUNT(*) FROM courses;"

# List all courses
sqlite3 /opt/data/field_trainer.db "SELECT name FROM courses;"

# Count athletes
sqlite3 /opt/data/field_trainer.db "SELECT COUNT(*) FROM athletes;"

# Count sessions
sqlite3 /opt/data/field_trainer.db "SELECT COUNT(*) FROM sessions;"

# View field devices
cat /opt/data/network-status.json
```

**Network & Services:**
```bash
# Check all services
sudo systemctl status field-trainer mesh-network dnsmasq

# Check listening ports
sudo netstat -tlnp

# Check mesh network
sudo batctl if
sudo batctl o

# Check WiFi status
iwconfig wlan0
```

---

## ✨ What You Get

After following this guide, you will have:

### Software Stack
- ✅ Raspberry Pi OS Trixie (Debian 13) - Optimized for 512MB RAM
- ✅ Python 3.11+ with Flask web framework
- ✅ SQLite database with 14 built-in courses
- ✅ BATMAN-adv mesh networking
- ✅ dnsmasq for DNS/DHCP
- ✅ systemd services for auto-start

### Field Trainer Application
- ✅ Web-based coach interface (port 5000)
- ✅ Field device connection handler (port 5001)
- ✅ Session management system
- ✅ Athlete and team tracking
- ✅ 14 pre-configured training courses
- ✅ AI Team for testing
- ✅ Database initialization system
- ✅ Device registry and heartbeat monitoring

### Training Capabilities
- ✅ Speed drills (40yd, 60yd, 100m)
- ✅ Agility drills (Pro Agility, 3-Cone, T-Test)
- ✅ Conditioning drills (Beep Test, Suicide Sprint)
- ✅ Reaction training (Simon Says variants)
- ✅ Warmup routines (3 progressive rounds)
- ✅ Multi-athlete support (sequential and pattern modes)

### System Features
- ✅ Auto-start on boot
- ✅ Mesh networking for field devices
- ✅ LED control and patterns
- ✅ Audio playback and cues
- ✅ Touch-activated field devices
- ✅ Session history and results tracking

---

## 🎯 Quick Start After Installation

1. **Access web interface:** http://fieldtrainer.local:5000
2. **Create your first team**
3. **Add athletes to the team**
4. **Select a built-in course** (try "Simon Says Random")
5. **Create and run a session**
6. **View results and history**

---

## 📊 Installation Checklist

Use this checklist to track your progress:

### Pre-Installation
- [ ] Raspberry Pi 3 A+ with power supply (5V 2.5A min)
- [ ] 16GB+ microSD card (32GB recommended)
- [ ] USB drive with build scripts
- [ ] USB hub (recommended for Pi 3 A+)
- [ ] Monitor, keyboard, mouse (or plan for SSH)
- [ ] WiFi network credentials

### OS Installation
- [ ] Downloaded Raspberry Pi Imager
- [ ] Flashed Pi OS (Lite or Full) to SD card
- [ ] Configured WiFi credentials in imager
- [ ] Configured SSH in imager
- [ ] First boot successful
- [ ] WiFi connected
- [ ] System updated

### Build Process
- [ ] USB drive mounted at /mnt/usb
- [ ] Build scripts verified
- [ ] Build script made executable
- [ ] Phase 0 complete (system prep) ~10-15 min
- [ ] Phase 1 complete (core packages) ~5-8 min
- [ ] Phase 2 complete (mesh networking) ~3-5 min
- [ ] Phase 3 complete (DNS/DHCP) ~2-3 min
- [ ] Phase 4 complete (network config) ~1-2 min
- [ ] Phase 5 complete/skipped (touchscreen)
- [ ] Phase 6 complete (systemd services) ~1 min
- [ ] Phase 7 complete (Field Trainer app) ~5-10 min
- [ ] Repository cloned successfully
- [ ] Database initialized (14 courses)
- [ ] AI Team created
- [ ] Service started

### Verification
- [ ] Web interface accessible
- [ ] 14 built-in courses visible
- [ ] AI Team appears in team list
- [ ] Service auto-starts on boot
- [ ] No errors in service logs
- [ ] Can create test athlete
- [ ] Can create test session

### Optional
- [ ] SSH access tested
- [ ] Memory optimizations applied
- [ ] GPU memory reduced to 16MB
- [ ] Bluetooth disabled (if not needed)
- [ ] Database backup created

---

**Installation Guide Version:** v2025.12.31
**Target Hardware:** Raspberry Pi 3 A+ (512MB RAM)
**Distribution Repository:** https://github.com/darrenmsmith/field-trainer-releases
**Last Updated:** 2025-12-31

**Status:** ✅ Ready for Production Use on Pi 3 A+
