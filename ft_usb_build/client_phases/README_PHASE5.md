# Phase 5 Client Application Deployment

## Quick Start

**RECOMMENDED:** Use the v2 script for Device2-5 builds:

```bash
cd /mnt/usb/ft_usb_build/client_phases
./phase5_client_app_v2.sh
```

## Available Scripts

### phase5_client_app_v2.sh ✅ RECOMMENDED
- **Status:** Ready for testing
- **Sudo Prompts:** 3 total (down from 15+)
- **Method:** Single heredoc block for installation
- **Best For:** Device2-5 builds

### phase5_client_app.sh (v1)
- **Status:** Tested - didn't work reliably
- **Issue:** Password prompts still occurred multiple times
- **Method:** Background sudo refresh
- **Use Only If:** v2 has issues

## What Phase 5 Does

1. **Validates Environment:**
   - Checks hostname (Device1-5)
   - Tests connection to Device0 (192.168.99.100)
   - Verifies SSH access

2. **Downloads Files from Device0:**
   - field_client_connection.py (main application)
   - ft_touch.py (touch sensor library)
   - ft_led.py (LED control library - optional)
   - ft_audio.py (audio library - optional)
   - audio_manager.py (audio manager - optional)
   - Audio files (male and female voice prompts)

3. **Installs Files:**
   - Creates /opt/field_trainer/ directory structure
   - Copies all files to /opt/
   - Sets correct permissions

4. **Creates Systemd Service:**
   - Creates field-client.service
   - Configures to start on boot
   - Depends on batman-mesh-client.service

5. **Starts Service:**
   - Enables service
   - Starts service
   - Verifies service is running

## Expected Sudo Prompts (v2)

1. **Installation Block** - Installing all files to /opt/
2. **Service Creation** - Creating systemd service file
3. **Service Start** - Starting the field-client service

## Prerequisites

Before running Phase 5, ensure:
- [x] Device0 is powered on and accessible (192.168.99.100)
- [x] Phases 1-4 completed successfully on client device
- [x] batman-mesh-client service is running
- [x] Can ping Device0: `ping -c 3 192.168.99.100`
- [x] Know Device0 SSH password (pi@192.168.99.100)

## Troubleshooting

### Cannot reach Device0
```bash
# Check mesh is running
sudo systemctl status batman-mesh-client

# Check mesh neighbors
sudo batctl n

# Check Device0 is accessible
ping -c 3 192.168.99.100
```

### SSH password prompts
You'll need the Device0 SSH password for SCP file downloads. For future builds, consider setting up SSH keys:

```bash
# On client device, generate key (if not exists)
ssh-keygen -t rsa -b 4096

# Copy to Device0
ssh-copy-id pi@192.168.99.100
```

### Service fails to start
```bash
# Check service status
sudo systemctl status field-client

# View logs
sudo journalctl -u field-client -n 50

# Check if files were installed
ls -lh /opt/field_client_connection.py
ls -lh /opt/field_trainer/
```

## After Phase 5 Completes

1. **Verify on Device0 Web Interface:**
   - Open http://192.168.99.100:5000
   - Go to "Devices" tab
   - Look for Device1-5 in the list
   - Check "Last Seen" timestamp

2. **Register Device MAC (if using whitelist):**
   - Get MAC: `cat /sys/class/net/wlan0/address`
   - Add to Device0 settings via web interface

3. **Test LED:**
   - Deploy a course from Device0 web interface
   - Verify LED lights up on client device

4. **Test Touch Sensor:**
   - During active course, press touch sensor
   - Verify response on web interface

## Documentation

See `/mnt/usb/ft_usb_build/PHASE5_SUDO_FIX.md` for:
- Detailed explanation of sudo fix approaches
- Why v1 failed and v2 should work
- Technical details of heredoc approach
- Complete testing checklist
