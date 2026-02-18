# Phase 4 Updated - Combined Mesh + WiFi Setup

## Date: 2026-01-07

## Overview

Phase 4 has been updated to combine mesh network setup (wlan0) with optional WiFi/Internet setup (wlan1) in a single deployment phase.

## What's New

### Single Phase Does Everything

**Before:** Phase 4 only set up mesh networking
**After:** Phase 4 sets up both:
1. Mesh network on wlan0 (required)
2. WiFi/Internet on wlan1 (optional)

### Automatic Detection

The script automatically:
- Detects if wlan1 (external USB WiFi adapter) is present
- Prompts to configure wlan1 if detected
- Continues smoothly if wlan1 is not present
- Makes wlan1 configuration completely optional

## Step-by-Step Flow

When you run Phase 4, here's what happens:

### Steps 1-12: Mesh Network Setup (wlan0)
1. Detect device number
2. Get mesh configuration (SSID, channel, BSSID)
3. Verify wlan0 exists
4. **Configure NetworkManager to ignore wlan0**
5. Load BATMAN-adv module
6. Configure wlan0 for IBSS mode
7. Join IBSS mesh network
8. Add wlan0 to BATMAN-adv
9. Bring up bat0 interface
10. Assign static IP to bat0
11. Test connection to Device0
12. Check mesh neighbors

### Step 13: WiFi Setup (wlan1) - NEW!

**If wlan1 detected:**
```
Do you want to configure wlan1 for WiFi connectivity? (y/n):
```

**If yes:**
- Scans for available WiFi networks
- Prompts for SSID
- Prompts for password
- Connects wlan1 to WiFi
- Displays wlan1 IP address for SSH access
- Sets auto-connect on boot

**If no or wlan1 not present:**
- Continues without wlan1 setup
- Shows how to configure later if needed

### Steps 14-17: Service Setup
14. Create systemd service
15. Create mesh startup script
16. Create mesh shutdown script
17. Enable service for boot

### Summary Display

Shows complete configuration:
```
Phase 4 Configuration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Device: Device4

  Mesh Network (wlan0):
    • IP Address: 192.168.99.104
    • Mesh SSID: ft_mesh2
    • Channel: 1
    • Mode: IBSS (Ad-hoc)
    • Purpose: BATMAN-adv mesh to Device0

  WiFi Network (wlan1):
    • IP Address: 192.168.1.150
    • WiFi SSID: YourDevNetwork
    • Purpose: SSH access, internet, development
    • Auto-connect: Enabled

  SSH Access:
    ssh pi@192.168.1.150

  Status:
    ✓ NetworkManager: wlan0 unmanaged, wlan1 available
    ✓ wlan0 in IBSS mode
    ✓ BATMAN-adv active
    ✓ bat0 interface up
    ✓ Static IP assigned: 192.168.99.104
    ✓ Systemd service enabled
```

## Example Deployment Session

### Device with wlan1 Present

```bash
sudo /mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh

# ... mesh setup steps ...

Step 13: Configuring wlan1 for WiFi/Internet (Optional)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
wlan1 Configuration (Optional)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If you have an external USB WiFi adapter (wlan1), you can configure it
to connect to your development WiFi network for:
  • Direct SSH access from your laptop
  • Internet connectivity for updates
  • File transfers and debugging

Note: wlan0 will continue to handle the mesh network to Device0

✓ wlan1 interface detected
  wlan1 MAC address: 00:c0:ca:a1:b2:c3

Do you want to configure wlan1 for WiFi connectivity? (y/n): y

Scanning for available WiFi networks on wlan1...

IN-USE  BSSID              SSID                MODE   CHAN  RATE        SIGNAL  BARS  SECURITY
        AA:BB:CC:DD:EE:FF  YourDevNetwork      Infra  6     270 Mbit/s  85      ▂▄▆█  WPA2
        11:22:33:44:55:66  OtherNetwork        Infra  11    130 Mbit/s  65      ▂▄▆_  WPA2

Enter WiFi SSID to connect to: YourDevNetwork
Enter WiFi password:
Connecting wlan1 to 'YourDevNetwork'...
✓ wlan1 connected to WiFi
✓ wlan1 IP address: 192.168.1.150

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SSH Access Information
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  You can now SSH to this device from your laptop:

    ssh pi@192.168.1.150

  Network Configuration:
    wlan0 (mesh): 192.168.99.104 → Device0 mesh network
    wlan1 (WiFi): 192.168.1.150 → Your WiFi network

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ WiFi connection will auto-connect on boot
```

### Device without wlan1

```bash
sudo /mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh

# ... mesh setup steps ...

Step 13: Configuring wlan1 for WiFi/Internet (Optional)

ℹ wlan1 not detected - only using wlan0 for mesh network

If you add an external USB WiFi adapter later, you can configure it with:
  nmcli device wifi list ifname wlan1
  nmcli device wifi connect 'SSID' password 'PASSWORD' ifname wlan1

# ... continues with service setup ...
```

### User Skips wlan1 Configuration

```bash
Do you want to configure wlan1 for WiFi connectivity? (y/n): n

ℹ Skipping wlan1 WiFi configuration

You can configure wlan1 later using:
  nmcli device wifi list ifname wlan1
  nmcli device wifi connect 'SSID' password 'PASSWORD' ifname wlan1
```

## Network Architecture After Phase 4

### With wlan1 Configured

```
┌─────────────────────────────────────────────────────┐
│              Client Device (e.g., Device4)          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  wlan0 (Onboard WiFi)                              │
│    • Mode: IBSS (Ad-hoc)                           │
│    • SSID: ft_mesh2                                │
│    • Purpose: BATMAN-adv mesh                      │
│    • NetworkManager: Unmanaged                     │
│    • IP: None (layer 2 only)                       │
│         │                                          │
│         └──> bat0 (Virtual)                        │
│                • IP: 192.168.99.104                │
│                • Routes to: Device0, other clients  │
│                                                     │
│  wlan1 (External USB WiFi)                         │
│    • Mode: Managed (Station)                       │
│    • SSID: YourDevNetwork                          │
│    • Purpose: SSH, Internet, Dev access            │
│    • NetworkManager: Managed                       │
│    • IP: 192.168.1.150 (DHCP from your router)    │
│    • Routes to: Internet, your laptop              │
│                                                     │
└─────────────────────────────────────────────────────┘

         │ wlan0/bat0                    │ wlan1
         │ (Mesh)                        │ (WiFi)
         ▼                               ▼
    ┌─────────┐                    ┌─────────────┐
    │Device0  │                    │ Your WiFi   │
    │Gateway  │                    │ Router      │
    │(Prod)   │                    │             │
    └─────────┘                    └─────────────┘
         │                               │
         ▼                               ▼
    Field Client                    Internet
    Application                     Your Laptop
    Communication                   SSH Access
```

### Without wlan1

```
┌─────────────────────────────────────────────────────┐
│              Client Device (e.g., Device4)          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  wlan0 (Onboard WiFi)                              │
│    • Mode: IBSS (Ad-hoc)                           │
│    • SSID: ft_mesh2                                │
│    • Purpose: BATMAN-adv mesh                      │
│    • IP: None (layer 2 only)                       │
│         │                                          │
│         └──> bat0 (Virtual)                        │
│                • IP: 192.168.99.104                │
│                • Routes to: Device0, other clients  │
│                                                     │
└─────────────────────────────────────────────────────┘

         │ wlan0/bat0
         │ (Mesh only)
         ▼
    ┌─────────┐
    │Device0  │
    │Gateway  │
    │(Prod)   │
    └─────────┘
         │
         ▼
    Field Client
    Application
```

## Use Cases

### 1. Production Deployment (No wlan1)
- Device has only onboard WiFi
- Uses wlan0 for mesh to Device0
- No external connectivity needed
- **Works perfectly**

### 2. Development Deployment (With wlan1)
- Device has USB WiFi adapter
- wlan0 for mesh to Device0 (production network)
- wlan1 for WiFi to dev network (SSH, internet)
- Can SSH directly from laptop
- Can debug while system is running
- **Best for development**

### 3. Field + Internet (With wlan1)
- Device needs mesh AND internet
- wlan0 for mesh to Device0
- wlan1 for internet connectivity
- Can receive updates while deployed
- **Production with updates**

## Benefits

### For You as Developer

1. **Direct SSH Access**
   - No need to hop through Device0
   - Faster debugging and log access
   - Can work on multiple devices simultaneously

2. **Internet Access**
   - apt install packages during development
   - git pull updates
   - Download dependencies

3. **Flexible Deployment**
   - Same script works with or without wlan1
   - No separate Phase 4.5 needed
   - One deployment flow for all scenarios

4. **Auto-Reconnect**
   - wlan1 WiFi connection auto-connects on boot
   - Survives reboots
   - Always accessible for SSH

### For Production

1. **Optional Feature**
   - wlan1 setup can be skipped
   - Doesn't interfere with mesh if not configured
   - No extra overhead if not used

2. **Clean Separation**
   - wlan0 dedicated to mesh (can't be disturbed)
   - wlan1 for other purposes (isolated)
   - NetworkManager properly configured

3. **Easy Maintenance**
   - Can add wlan1 later if needed
   - Can reconfigure WiFi without affecting mesh
   - Both networks independent

## Manual Configuration Later

If you skip wlan1 during Phase 4, you can configure it anytime:

```bash
# List available networks
nmcli device wifi list ifname wlan1

# Connect to WiFi
nmcli device wifi connect "SSID" password "PASSWORD" ifname wlan1

# Make it auto-connect
nmcli connection modify "SSID" connection.autoconnect yes

# Check status
nmcli device status
ip addr show wlan1
```

## Troubleshooting

### wlan1 Not Detected During Phase 4

If you have a USB WiFi adapter plugged in but Phase 4 doesn't detect it:

```bash
# Check USB device
lsusb
# Should show WiFi adapter

# Check interface
ip link show
# Should show wlan1

# Check driver
dmesg | grep -i wifi
# Should show driver loaded

# If wlan1 exists but wasn't detected, manually configure:
nmcli device wifi connect "SSID" password "PASSWORD" ifname wlan1
```

### wlan1 WiFi Connection Failed

If WiFi connection fails during Phase 4:

```bash
# Verify SSID exists
nmcli device wifi list ifname wlan1

# Try manual connection with verbose output
nmcli device wifi connect "SSID" password "PASSWORD" ifname wlan1

# Check NetworkManager status
nmcli device status
nmcli connection show

# Check logs
journalctl -u NetworkManager -f
```

### Can't SSH to wlan1 IP

If wlan1 connected but can't SSH:

```bash
# Verify IP assigned
ip addr show wlan1

# Verify SSH running
systemctl status ssh

# Verify firewall allows SSH
sudo ufw status

# Try from device itself first
ssh localhost

# Verify laptop can ping wlan1 IP
ping 192.168.1.150
```

## Testing After Deployment

### Verify Both Networks Work

```bash
# On the device:

# Check wlan0 mesh
iw dev wlan0 info          # Should show "type IBSS"
sudo batctl n              # Should show Device0
ping 192.168.99.100        # Ping Device0 via mesh

# Check wlan1 WiFi (if configured)
ip addr show wlan1         # Should show IP address
ping 8.8.8.8               # Test internet
```

### From Your Laptop

```bash
# SSH via wlan1
ssh pi@192.168.1.150

# Once connected, verify mesh still works
sudo batctl n
ping 192.168.99.100
```

## Files Modified

`/mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh`

**Changes:**
- Added Step 13: wlan1 WiFi configuration (optional)
- Updated summary to show wlan1 info
- Renumbered remaining steps (14-17)
- Enhanced final summary display

## Documentation

- `/mnt/usb/ft_usb_build/PHASE4_COMBINED_WLAN1_SUPPORT.md` - This file
- `/mnt/usb/ft_usb_build/PHASE4_WLAN1_OPTIONAL_FIX.md` - Technical details
- `/mnt/usb/ft_usb_build/PHASE4_NETWORKMANAGER_FIX.md` - NetworkManager fix

## Ready to Deploy

You can now run Phase 4 on Device4:

```bash
sudo /mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh
```

The script will:
1. Set up mesh network on wlan0 ✓
2. Prompt for wlan1 configuration (if present) ✓
3. Show SSH access info if wlan1 configured ✓
4. Create systemd service for mesh ✓
5. Display complete summary ✓

---

**Phase 4 now handles both mesh networking and optional WiFi/SSH access in one deployment.**
