# Final dhcpcd Fix - Two-Service Architecture

## The Real Problem

dhcpcd was being started in `ExecStartPost` of a `Type=oneshot` service. This meant:
1. dhcpcd would run and get an IP
2. dhcpcd would exit/fork into background
3. systemd had no way to monitor if dhcpcd stayed alive
4. When dhcpcd died, nothing restarted it
5. `Type=oneshot` with `RemainAfterExit=yes` considered it "active" even when dead

## The Solution

**Split into TWO separate monitored services:**

### Service 1: wlan1-wpa.service
- **Purpose**: Manages wpa_supplicant only
- **Type**: forking (systemd tracks the daemon)
- **PID File**: /var/run/wpa_supplicant-wlan1.pid
- **Restart**: on-failure (auto-restart if crashes)

### Service 2: wlan1-dhcp.service
- **Purpose**: Manages dhcpcd only
- **Type**: forking (systemd tracks the daemon)
- **PID File**: /run/dhcpcd-wlan1.pid
- **Depends on**: wlan1-wpa.service (won't start until WiFi connected)
- **Restart**: always + RestartSec=10 (auto-restart every time)

## Why This Works

1. **systemd monitors both processes** via PID files
2. **Type=forking** means systemd knows when process dies
3. **Restart=always** on dhcp service means it will restart if killed
4. **Dependency chain**: wpa → dhcp (dhcp waits for WiFi connection)
5. **Separate services** = separate monitoring and restart policies

## Implementation

File: `/mnt/usb/ft_usb_build/phases/phase2_internet.sh` (REPLACED)

### What Phase 2 Does Now:

1. Creates `wlan1-wpa.service` (WiFi connection manager)
2. Creates `wlan1-dhcp.service` (DHCP client manager)
3. Enables both for boot
4. Gets WiFi credentials from user
5. Creates wpa_supplicant config
6. **Starts wlan1-wpa.service** (WiFi)
7. Waits 10 seconds
8. **Starts wlan1-dhcp.service** (DHCP)
9. Waits 20 seconds
10. Verifies IP obtained
11. Verifies internet working

### What Happens at Boot (Post-Installation):

1. systemd starts `wlan1-wpa.service`
2. wpa_supplicant connects to WiFi
3. systemd starts `wlan1-dhcp.service` (waits 15s first)
4. dhcpcd gets IP address
5. If either process dies, systemd automatically restarts it
6. System maintains internet connection permanently

## Key Differences from Old Approach

| Old (Broken) | New (Fixed) |
|-------------|-------------|
| Single service | Two services |
| Type=oneshot | Type=forking |
| No PID tracking | PID files tracked |
| No restart | Restart=always |
| dhcpcd in ExecStartPost | dhcpcd as separate service |
| No monitoring | Full systemd monitoring |

## Testing

On build system:
```bash
cd /mnt/usb/ft_usb_build
./install_menu.sh

# Run Phase 2
# Enter WiFi credentials when prompted
# Phase 2 should complete successfully

# Verify services
systemctl status wlan1-wpa.service
systemctl status wlan1-dhcp.service

# Both should show "active (running)"

# Run stress test
# Option 6 from menu
# Should pass or stop after 5 failures (not 30+)

# Run Phase 3
# Should complete without connection loss
```

## Production Benefits

1. **Field deployment ready**: Works on any WiFi network with DHCP
2. **Auto-recovery**: Services restart if they crash
3. **Cloning ready**: Same setup works on all 6 devices
4. **Persistent**: Survives reboots, maintains connection
5. **Monitored**: systemd tracks process health
6. **Simple**: Two small focused services vs one complex service

## Files Modified

- `/mnt/usb/ft_usb_build/phases/phase2_internet.sh` - Completely rewritten (195 lines)
- Old version backed up as: `phase2_internet.sh.BROKEN`

## Rollback

If this doesn't work:
```bash
cd /mnt/usb/ft_usb_build/phases
cp phase2_internet.sh.BROKEN phase2_internet.sh
```

## Success Criteria

✅ Phase 2 completes successfully
✅ Both services active after Phase 2
✅ dhcpcd stays running indefinitely
✅ Phase 3 completes without errors
✅ Services survive reboot
✅ Connection maintained through all phases

Ready to test on fresh OS install on build system.
