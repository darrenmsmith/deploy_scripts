# Field Trainer - Client Device Installation Guide
## Raspberry Pi Zero W (Devices 1-5) - Trixie Lite 32-bit

**Document Version:** 2.0  
**Last Updated:** November 9, 2025  
**Target Hardware:** Raspberry Pi Zero W  
**Target OS:** Raspberry Pi OS Trixie Lite (32-bit)  
**Device Role:** Mesh Client Devices (1-5)

---

## Overview

This guide walks through setting up client devices (Devices 1-5) for the Field Trainer mesh network. These devices use:
- **wlan0** (onboard WiFi): BATMAN-adv mesh network
- **bat0**: BATMAN mesh interface with static IP
- No internet connection or services initially
- Just mesh connectivity to reach Device 0 (gateway)

**Device IP Assignments:**
- Device 1: 192.168.99.101
- Device 2: 192.168.99.102
- Device 3: 192.168.99.103
- Device 4: 192.168.99.104
- Device 5: 192.168.99.105
- Device 0 (Gateway): 192.168.99.100

---

## Prerequisites

- Raspberry Pi Zero W
- 16GB+ microSD card with Trixie Lite 32-bit OS
- **USB thumb drive** containing `install_client_mesh.sh`
- **USB WiFi adapter** (for temporary internet during installation)
- Monitor and keyboard for initial setup
- Hostname set to "Device1", "Device2", etc. via RPi Imager
- Device 0 (gateway) operational on mesh network
- Access to "smithhome" WiFi network

---

## Step 1: Initial Boot and USB Setup

### 1.1: Boot the Device

1. Insert SD card with Trixie Lite OS
2. Connect monitor and keyboard
3. Power on the device
4. Log in with default credentials (pi/raspberry or your configured password)

### 1.2: Insert USB Devices

1. Insert **USB thumb drive** containing `install_client_mesh.sh`
2. Insert **USB WiFi adapter** (for internet access during installation)
3. Wait a few seconds for auto-detection

**Note:** The script requires internet access to download packages. The USB WiFi adapter provides temporary internet connectivity and will be disconnected after installation completes.

### 1.3: Identify USB Drive

```bash
# List block devices
lsblk
```

**Look for:** `sda` with child `sda1` (your USB drive)

---

## Step 2: Mount the USB Drive

### 2.1: Check if Auto-Mounted

```bash
df -h | grep sda1
```

If you see a mount point like `/media/pi/something`, note that path and skip to Step 2.3.

### 2.2: Manual Mount (if needed)

```bash
# Create mount point
sudo mkdir -p /mnt/usb

# Check USB filesystem type
sudo blkid /dev/sda1
```

**If filesystem is NTFS:**
```bash
# Install NTFS support
sudo apt install -y ntfs-3g

# Mount USB drive
sudo mount -t ntfs-3g /dev/sda1 /mnt/usb
```

**If filesystem is FAT32 or exFAT:**
```bash
# Mount USB drive
sudo mount /dev/sda1 /mnt/usb
```

### 2.3: Navigate to USB

```bash
cd /mnt/usb

# Verify script is present
ls -l install_client_mesh.sh
```

---

## Step 3: Run Installation Script

### 3.1: Execute the Script

```bash
# Run the installation script
sudo bash install_client_mesh.sh
```

### 3.2: Follow Prompts

The script will automatically:

**Phase 1: Internet Setup**
1. Detect device number from hostname (e.g., "Device1" → Device 1)
2. Calculate IP address automatically (Device 1 → 192.168.99.101)
3. Show detected configuration
4. Ask for confirmation (press 'y' to continue)
5. Check for wlan1 (USB WiFi adapter)
6. Connect wlan1 to "smithhome" WiFi
7. Verify internet connectivity

**Phase 2: Package Installation**
8. Update package lists
9. Install batctl, wpasupplicant, wireless-tools
10. Load batman-adv kernel module

**Phase 3: Cleanup**
11. Disconnect wlan1
12. Prompt you to remove USB WiFi adapter

**Phase 4: Mesh Configuration**
13. Create mesh startup scripts

**Expected Output:**
```
==========================================
Field Trainer Client Mesh Installation
Version 2.0 - With Auto WiFi Setup
==========================================

Detected hostname: Device1
Device Number: 1
Assigned IP: 192.168.99.101/24

Checking for USB WiFi adapter (wlan1)...
✓ Found wlan1 (USB WiFi adapter)

Continue with installation? (y/n): y

==========================================
Phase 1: Setting Up Internet Connection
==========================================

Creating WiFi configuration for wlan1...
Bringing up wlan1...
Connecting to smithhome...
✓ Connected! wlan1 IP: 192.168.1.xxx
✓ Internet connection verified!

==========================================
Phase 2: Installing Packages
==========================================

Step 1: Updating package lists...
Step 2: Installing BATMAN-adv and networking tools...
Step 3: Loading batman-adv kernel module...
✓ batman-adv module loaded successfully

==========================================
Phase 3: Disconnecting Temporary WiFi
==========================================

✓ wlan1 disconnected

*** YOU CAN NOW REMOVE THE USB WIFI ADAPTER ***

==========================================
Phase 4: Creating Mesh Scripts
==========================================

✓ Created /usr/local/bin/start-batman-mesh.sh
✓ Created /usr/local/bin/set-mesh-ip.sh

==========================================
Installation Complete!
==========================================
```

### 3.3: Cleanup

```bash
# Remove USB WiFi adapter (if you haven't already)

# Return to home directory
cd ~

# Unmount USB thumb drive safely
sudo umount /mnt/usb

# Remove USB thumb drive
```

---

## Step 4: Start the Mesh Network

### 4.1: Start BATMAN Mesh

```bash
sudo /usr/local/bin/start-batman-mesh.sh
```

**Expected Output:**
```
BATMAN mesh started on wlan0
Waiting for bat0 interface...
Ready for IP assignment
```

### 4.2: Assign IP Address

```bash
sudo /usr/local/bin/set-mesh-ip.sh
```

**Expected Output:**
```
bat0 configured with IP 192.168.99.101/24
```

### 4.3: Verify Mesh Status

```bash
# Check bat0 interface
ip addr show bat0

# Should show something like:
# bat0: <BROADCAST,MULTICAST,UP,LOWER_UP>
#     inet 192.168.99.101/24 scope global bat0
```

---

## Step 5: Test Mesh Connectivity

### 5.1: Ping Device 0 (Gateway)

```bash
ping -c 3 192.168.99.100
```

**Expected Result:** Successful pings to Device 0

### 5.2: Check Mesh Neighbors

```bash
batctl n
```

**Expected Output:**
```
[B.A.T.M.A.N. adv 2024.x, MainIF/MAC: wlan0/xx:xx:xx:xx:xx:xx]
IF             Neighbor              last-seen
wlan0          xx:xx:xx:xx:xx:xx    0.XXXs
```

You should see Device 0 and any other active client devices.

### 5.3: Check IBSS Mode

```bash
iw dev wlan0 info
```

**Expected Output:**
```
Interface wlan0
    type IBSS
    ssid ft_mesh
    ...
```

---

## Step 6: Enable SSH from Device 0

Now that mesh is working, you can manage this device remotely from Device 0.

### 6.1: From Device 0, Test SSH

```bash
# From Device 0 gateway
ssh pi@192.168.99.101  # For Device 1
# Or pi@192.168.99.102 for Device 2, etc.
```

### 6.2: Set Up Passwordless SSH (Optional)

From Device 0:
```bash
# Copy SSH key to client device
ssh-copy-id pi@192.168.99.101
```

**From this point forward, you can manage the device remotely from Device 0!**

---

## Step 7: Create Systemd Service (Optional)

If you want the mesh to auto-start on boot, create systemd services.

### 7.1: Create Mesh Service

```bash
sudo nano /etc/systemd/system/batman-mesh.service
```

Add the following content:
```ini
[Unit]
Description=BATMAN-adv Mesh Network - Client Device
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/start-batman-mesh.sh
ExecStartPost=/bin/sleep 2
ExecStartPost=/usr/local/bin/set-mesh-ip.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Save and exit (Ctrl+X, Y, Enter)

### 7.2: Enable and Start Service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable batman-mesh.service

# Start service now
sudo systemctl start batman-mesh.service

# Check status
sudo systemctl status batman-mesh.service
```

### 7.3: Test Auto-Start

```bash
# Reboot the device
sudo reboot

# After reboot, check if mesh is up
ip addr show bat0
batctl n
ping 192.168.99.100
```

---

## Quick Reference Commands

### Mesh Management
```bash
# Start mesh manually
sudo /usr/local/bin/start-batman-mesh.sh
sudo /usr/local/bin/set-mesh-ip.sh

# Check mesh status
batctl n                    # View neighbors
ip addr show bat0          # View bat0 IP
iw dev wlan0 info          # Check IBSS mode

# Restart mesh
sudo ip link set bat0 down
sudo batctl if del wlan0
sudo /usr/local/bin/start-batman-mesh.sh
sudo /usr/local/bin/set-mesh-ip.sh
```

### Network Testing
```bash
# Ping Device 0
ping 192.168.99.100

# Test internet (via Device 0 gateway)
ping 8.8.8.8

# Trace route to internet
traceroute 8.8.8.8
```

### System Information
```bash
# Check hostname
hostname

# Check OS version
cat /etc/os-release

# Check WiFi interface
iw dev wlan0 info

# Check loaded modules
lsmod | grep batman
```

---

## Troubleshooting

### Issue: USB WiFi Adapter Not Detected (No wlan1)

**Error:** "No wlan1 detected" or "No USB WiFi adapter found!"

**Solution:**
```bash
# Check if wlan1 exists
ip link show

# If you don't see wlan1:
# 1. Unplug USB WiFi adapter
# 2. Wait 5 seconds
# 3. Plug it back in
# 4. Wait 10 seconds
# 5. Check again
ip link show wlan1

# Check if it's being detected by kernel
dmesg | tail -20
```

### Issue: WiFi Connection Failed

**Error:** "Failed to get IP address on wlan1"

**Causes:**
- Wrong WiFi password in script
- WiFi network not available
- USB WiFi adapter not compatible

**Solution:**
```bash
# Check if wlan1 is up
ip link show wlan1

# Try manual connection
sudo ip link set wlan1 up
sudo wpa_supplicant -B -i wlan1 -c /tmp/wpa_temp.conf
sudo dhcpcd wlan1

# Check for IP
ip addr show wlan1

# If still no connection, verify WiFi credentials in the script
nano ~/install_client_mesh.sh
# Look for WIFI_SSID and WIFI_PASSWORD lines
```

### Issue: Script Has Wrong WiFi Password

**Solution:**
```bash
# Edit the script and update credentials
nano ~/install_client_mesh.sh

# Find these lines and update:
# WIFI_SSID="smithhome"
# WIFI_PASSWORD="YOUR_ACTUAL_PASSWORD"

# Save (Ctrl+X, Y, Enter) and run again
sudo bash install_client_mesh.sh
```

### Issue: USB Drive Not Detected

**Solution:**
```bash
# Check if USB is recognized
lsblk

# If sda1 doesn't appear, try:
sudo dmesg | tail -20
```

### Issue: USB Shows Empty (ls -la shows only . and ..)

**Cause:** USB is NTFS formatted

**Solution:**
```bash
# Install NTFS support
sudo apt install -y ntfs-3g

# Unmount and remount
sudo umount /mnt/usb
sudo mount -t ntfs-3g /dev/sda1 /mnt/usb
```

### Issue: Script Shows "line 2: $'\r': command not found"

**Cause:** Windows line endings (CRLF) in the script

**Solution:**
```bash
# Install dos2unix
sudo apt install -y dos2unix

# Fix the script
dos2unix /mnt/usb/install_client_mesh.sh

# Or use sed
sed -i 's/\r$//' /mnt/usb/install_client_mesh.sh
```

### Issue: bat0 Interface Doesn't Come Up

**Solution:**
```bash
# Check if batman-adv module is loaded
lsmod | grep batman

# If not loaded, load it
sudo modprobe batman-adv

# Restart mesh
sudo /usr/local/bin/start-batman-mesh.sh
```

### Issue: Cannot Join IBSS Network

**Solution:**
```bash
# Check if wlan0 supports IBSS
iw list | grep -A 10 "Supported interface modes" | grep IBSS

# Check RF-kill status
sudo rfkill list

# Unblock if needed
sudo rfkill unblock wifi

# Try manual IBSS join
sudo iw dev wlan0 ibss join ft_mesh 2412 fixed-freq 00:11:22:33:44:55
```

### Issue: Can't Ping Device 0

**Checks:**
```bash
# Verify bat0 has IP
ip addr show bat0

# Check for neighbors
batctl n

# Verify wlan0 is in IBSS mode
iw dev wlan0 info

# Check routing
ip route
```

### Issue: Wrong IP Address Assigned

**Cause:** Hostname not matching expected format

**Solution:**
```bash
# Check hostname
hostname

# Hostname must be: Device1, Device2, Device3, Device4, or Device5
# Change hostname if needed
sudo raspi-config
# Navigate to: System Options → Hostname
# Set to: DeviceX (where X is 1-5)
# Reboot and run installation script again
```

---

## Repeating for Multiple Devices

To set up Devices 2-5, simply:

1. Flash new SD card with Trixie Lite
2. Use RPi Imager to set hostname to "Device2", "Device3", etc.
3. Boot device
4. Insert **USB thumb drive** (with script)
5. Insert **USB WiFi adapter** (for internet)
6. Follow this guide from Step 1
7. Remove USB WiFi adapter when prompted
8. Remove USB thumb drive after completion

The installation script automatically detects the device number and assigns the correct IP address!

**Pro Tip:** You can use the same USB thumb drive and USB WiFi adapter for all devices.

---

## Next Steps

Once all client devices (1-5) are on the mesh:

1. **From Device 0, verify all devices are reachable:**
   ```bash
   batctl n
   ping 192.168.99.101
   ping 192.168.99.102
   # ... etc
   ```

2. **Install Field Trainer hardware:**
   - Touch sensors with MPU6050
   - WS2812B LED strips
   - MAX98357A audio amplifiers

3. **Deploy Field Trainer application:**
   - Clone repository from Device 0
   - Install Python dependencies
   - Create systemd services
   - Test device registration with gateway

4. **Configure auto-start services** (if not already done in Step 7)

---

## File Locations Reference

### Scripts Created
- `/usr/local/bin/start-batman-mesh.sh` - Mesh startup script
- `/usr/local/bin/set-mesh-ip.sh` - IP assignment script

### Systemd Service (if created)
- `/etc/systemd/system/batman-mesh.service` - Auto-start service

### USB Drive
- `install_client_mesh.sh` - Installation script

---

## Summary Checklist

For each device (1-5):

- [ ] Flash SD card with Trixie Lite 32-bit
- [ ] Set hostname via RPi Imager (Device1, Device2, etc.)
- [ ] Boot device with monitor/keyboard
- [ ] Insert USB thumb drive (with script)
- [ ] Insert USB WiFi adapter (for internet)
- [ ] Mount USB thumb drive (with NTFS support if needed)
- [ ] Run `sudo bash install_client_mesh.sh`
- [ ] Wait for installation to complete
- [ ] Remove USB WiFi adapter when prompted
- [ ] Start mesh: `sudo /usr/local/bin/start-batman-mesh.sh`
- [ ] Set IP: `sudo /usr/local/bin/set-mesh-ip.sh`
- [ ] Test connectivity: `ping 192.168.99.100`
- [ ] Verify neighbors: `batctl n`
- [ ] SSH from Device 0: `ssh pi@192.168.99.10X`
- [ ] (Optional) Create systemd service for auto-start
- [ ] Remove monitor/keyboard - manage remotely from Device 0
- [ ] Remove USB thumb drive

---

## Version History

**Version 2.0 - November 9, 2025**
- Added automatic USB WiFi adapter (wlan1) detection and configuration
- Script now handles temporary internet connection for package installation
- Automatic disconnect of wlan1 after installation
- Updated prerequisites to require USB WiFi adapter
- Added troubleshooting for WiFi connection issues

**Version 1.0 - November 8, 2025**
- Initial release
- Manual internet connection setup required

---

**Document End - Version 2.0**
