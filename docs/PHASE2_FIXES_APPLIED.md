# Phase 2 Fixes Applied - 2025-11-18

## Issues Found and Fixed

### Issue 1: Legacy /var/run/ Path
**Problem**: systemd warned about deprecated `/var/run/` paths
**Fixed**: Changed all paths to `/run/` (modern systemd standard)

### Issue 2: Wrong dhcpcd PID File Location
**Problem**: Service specified `/run/dhcpcd-wlan1.pid` but dhcpcd creates `/run/dhcpcd/wlan1.pid`
**Fixed**: Updated PIDFile path to `/run/dhcpcd/wlan1.pid`

### Issue 3: Wrong Service Type for dhcpcd
**Problem**: Used `Type=simple` but dhcpcd naturally forks into daemon
**Fixed**: Changed to `Type=forking` with correct PID file

### Issue 4: Wrong dhcpcd Flags
**Problem**: Used `-w` flag which makes dhcpcd exit after getting IP
**Fixed**: Use no special flags - just `-4 wlan1` to let dhcpcd daemonize naturally

### Issue 5: Missing wpa_supplicant Config Headers
**Problem**: Existing wpa_supplicant config missing ctrl_interface, update_config, country
**Fixed**: Added auto-detection and auto-fix for incomplete configs

### Issue 6: Interactive Credential Prompt Blocking
**Problem**: Script always prompted for WiFi credentials even if config exists
**Fixed**: Check for existing valid config, only prompt if missing

---

## Final Service Configurations

### wlan1-wpa.service (WiFi Connection)
```ini
[Unit]
Description=wlan1 WPA Supplicant
After=network-pre.target
Before=network.target wlan1-dhcp.service
Wants=network-pre.target

[Service]
Type=forking
PIDFile=/run/wpa_supplicant-wlan1.pid

ExecStartPre=/usr/sbin/rfkill unblock wifi
ExecStartPre=/sbin/ip link set wlan1 down
ExecStartPre=/sbin/ip addr flush dev wlan1
ExecStartPre=/sbin/ip link set wlan1 up
ExecStartPre=/bin/sleep 3

ExecStart=/usr/sbin/wpa_supplicant -B -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant-wlan1.conf -P /run/wpa_supplicant-wlan1.pid

ExecStop=/usr/bin/killall wpa_supplicant

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### wlan1-dhcp.service (DHCP Client)
```ini
[Unit]
Description=wlan1 DHCP Client
After=wlan1-wpa.service
Requires=wlan1-wpa.service
Before=network-online.target

[Service]
Type=forking
PIDFile=/run/dhcpcd/wlan1.pid
ExecStartPre=/bin/sleep 15
ExecStart=/usr/sbin/dhcpcd -4 wlan1
ExecStop=/usr/bin/killall dhcpcd
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

## Key Technical Details

### Why Type=forking?
Both wpa_supplicant and dhcpcd naturally daemonize (fork into background). systemd needs to know this is expected behavior and track the daemon via PID file.

### Why These PID File Paths?
- wpa_supplicant: Creates PID at the path we specify with `-P` flag → `/run/wpa_supplicant-wlan1.pid`
- dhcpcd: Automatically creates PID at `/run/dhcpcd/<interface>.pid` → `/run/dhcpcd/wlan1.pid`

### Why No Special dhcpcd Flags?
- `-b`: Backgrounds immediately, causes Type=forking to hang waiting for fork
- `-w`: Waits for IP then exits, causes Type=simple to think process crashed
- No flags: Natural daemon behavior, forks properly for Type=forking

### dhcpcd Process Tree
When dhcpcd starts correctly, you'll see:
```
dhcpcd: wlan1 [ip4]                    # Main process
dhcpcd: [privileged proxy] wlan1       # Privileged operations
dhcpcd: [control proxy] wlan1          # Control socket
dhcpcd: [BPF ARP] wlan1 <IP>          # ARP handling
```

---

## wpa_supplicant Config Format

### Correct Format:
```
ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="YourSSID"
    psk="YourPassword"
    key_mgmt=WPA-PSK
}
```

### Why Headers Matter:
- `ctrl_interface`: Allows wpa_cli and other tools to control wpa_supplicant
- `update_config=1`: Allows saving network configs
- `country=US`: Required for regulatory compliance, enables proper WiFi channels

---

## Phase 2 Script Behavior

### On Fresh Install (No WiFi Config):
1. Creates both systemd services
2. Enables services for boot
3. Prompts for WiFi SSID and password
4. Creates wpa_supplicant config with proper headers
5. Starts wlan1-wpa.service (WiFi)
6. Waits 10 seconds for WiFi connection
7. Starts wlan1-dhcp.service (DHCP)
8. Waits 20 seconds for IP
9. Verifies IP obtained
10. Verifies internet connectivity

### On Retry (Existing Config):
1. Creates both systemd services
2. Enables services for boot
3. Detects existing WiFi config
4. Checks if config has proper headers
5. If headers missing, adds them automatically
6. If headers present, uses config as-is
7. Continues with service startup (steps 5-10 above)

---

## Testing on Build System

### Expected Success Output:
```
Phase 2: Internet Connection (DHCPCD SERVICE FIX)
==================================================

✓ Created two-service architecture
✓ Services enabled

ℹ Now configure WiFi and start services...

ℹ Existing WiFi config found, checking validity...
✓ Valid WiFi config already exists

ℹ Starting wlan1-wpa.service...
✓ wpa service active
ℹ Starting wlan1-dhcp.service...
✓ dhcp service active

✓ IP obtained: 192.168.x.x
✓ Internet working!

========================================
Phase 2 Complete
========================================

✓ wlan1 connected via two-service architecture

Services:
  • wlan1-wpa.service: Manages WiFi connection
  • wlan1-dhcp.service: Manages DHCP (auto-restart)
  • IP: 192.168.x.x
```

### Verification Commands:
```bash
# Check services are running
systemctl status wlan1-wpa.service
systemctl status wlan1-dhcp.service

# Check dhcpcd process tree
ps aux | grep dhcpcd

# Check IP address
ip addr show wlan1

# Check internet
ping -c 3 8.8.8.8
```

---

## Changes Made to Files

### /mnt/usb/ft_usb_build/phases/phase2_internet.sh

**Lines 40-67**: wlan1-wpa.service definition
- Changed PID path: `/var/run/` → `/run/`

**Lines 69-88**: wlan1-dhcp.service definition
- Changed Type: `simple` → `forking`
- Added PIDFile: `/run/dhcpcd/wlan1.pid`
- Removed flag: `-w` from dhcpcd command
- Final command: `/usr/sbin/dhcpcd -4 wlan1`

**Lines 104-156**: WiFi configuration logic
- Added check for existing config
- Added auto-fix for missing headers
- Only prompts for credentials if no config exists
- Uses `/run/` instead of `/var/run/` for ctrl_interface

---

## Status: READY FOR BUILD SYSTEM TESTING

All fixes applied. Phase 2 should now:
- ✅ Use correct modern paths (/run/ not /var/run/)
- ✅ Use correct service type (Type=forking)
- ✅ Use correct PID file paths
- ✅ Use correct dhcpcd flags (none except -4)
- ✅ Auto-detect and fix WiFi configs
- ✅ Skip credential prompt if config exists
- ✅ Create auto-restarting services
- ✅ Survive through all installation phases

Ready to test on build system with fresh OS install.
