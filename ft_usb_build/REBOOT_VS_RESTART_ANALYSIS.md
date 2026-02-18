# Reboot vs Restart - Mesh Connection Failure Analysis

## The Problem

**Observed Behavior:**

| Device | After Service Restart | After Reboot | Admin Shows Device |
|--------|----------------------|--------------|-------------------|
| Device4 | ✅ Works (ping, neighbors) | ❌ Broken (no ping, no neighbors) | ✅ Yes |
| Device5 | ✅ Works | ✅ Works | ✅ Yes |

## Key Questions

1. **Why does restart work but reboot fails on Device4?**
2. **Why does Device5 work after reboot but Device4 doesn't?**
3. **Why does Device4 show in Admin interface if mesh is broken?**

## Hypothesis 1: Startup Script Not Actually Modified

### Scenario
The `fix_client_rfkill.sh` script might not have successfully modified Device4's startup script.

### Why This Would Explain Symptoms
- **Service restart:** When you ran the fix and restarted, the fix script might have run commands that fixed RF-kill **temporarily** (in the running system)
- **Reboot:** On reboot, the startup script runs from scratch. If it doesn't have `rfkill unblock`, it fails

### Why Device5 Works
- Device5 might not have RF-kill enabled/soft-blocked, so it doesn't need the fix
- OR Device5's startup script was successfully modified

### How to Verify
Run on Device4:
```bash
sudo /mnt/usb/ft_usb_build/diagnose_boot_mesh.sh
```

Look for:
```
✓ RF-kill unblock FOUND in startup script
```

vs

```
✗ RF-kill unblock MISSING from startup script
```

## Hypothesis 2: Boot-Time Race Condition

### Scenario
The systemd service starts too early, before RF-kill subsystem is ready, or before network is fully initialized.

### Current Service Configuration
```ini
[Unit]
Description=BATMAN-adv Mesh Network (Client Device4)
After=network.target network-online.target
Wants=network-online.target
Before=field-client.service
```

### Problem
- `network.target` is reached very early (interfaces are discovered)
- `network-online.target` might not wait for WiFi specifically
- RF-kill state might be set AFTER our service runs

### Why Service Restart Works
- When you manually restart the service, the system is fully booted
- All subsystems (RF-kill, network, WiFi drivers) are ready
- No race condition

### Why Reboot Fails
- During boot, services start in parallel
- batman-mesh-client might start before:
  - RF-kill subsystem is fully initialized
  - WiFi driver is fully loaded
  - wlan0 interface is ready

### Why Device5 Works
- Might have slightly different hardware/timing
- Different WiFi chipset that initializes faster
- No RF-kill soft-block to begin with

### Fix: Add More Dependencies and Delays

Update service to wait for system to be fully ready:

```ini
[Unit]
Description=BATMAN-adv Mesh Network (Client Device4)
After=network.target network-online.target multi-user.target
Wants=network-online.target
Before=field-client.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 5
ExecStart=/usr/local/bin/start-batman-mesh-client.sh
ExecStop=/usr/local/bin/stop-batman-mesh-client.sh
Restart=on-failure
RestartSec=10
```

Note: `ExecStartPre=/bin/sleep 5` adds a 5-second delay to let system settle

## Hypothesis 3: RF-kill Re-enabled During Boot

### Scenario
Something during the boot process re-enables RF-kill AFTER our script runs.

### How This Could Happen
1. Our service runs and calls `rfkill unblock wifi`
2. Some other service/script runs later and soft-blocks RF-kill again
3. wlan0 gets blocked, IBSS join fails

### Why Service Restart Works
- Nothing else is running to re-enable RF-kill
- System is stable

### Why Device5 Works
- Might not have the conflicting service/script
- Different firmware that doesn't auto-enable RF-kill

### How to Verify
Check `journalctl` for RF-kill messages during boot:

```bash
journalctl -b | grep -i "rf-kill\|rfkill"
```

### Fix: Unblock RF-kill in Multiple Places

Add RF-kill unblock to:
1. Startup script (already done)
2. Before bringing interface up
3. After bringing interface up (belt and suspenders)

```bash
# In startup script
rfkill unblock wifi
ip link set ${MESH_IFACE} down
rfkill unblock wifi  # Again
iw dev ${MESH_IFACE} set type ibss
rfkill unblock wifi  # And again
ip link set ${MESH_IFACE} up
```

## Hypothesis 4: Admin Interface Showing Cached Connection

### Why Device4 Shows in Admin Interface

The admin interface likely shows field-client connections. Here's what probably happened:

1. **During boot:** Mesh formed briefly (maybe for 1-2 seconds)
2. **Field client connected:** Made TCP connection to Device0
3. **Mesh broke:** Due to RF-kill or timing issue
4. **Admin UI still shows Device4:** Because:
   - TCP connection hasn't timed out yet
   - Admin caches "last seen" devices
   - Websocket connection might still be in "connecting" state

This would explain:
- Device4 shows in admin ✅
- But can't ping Device4 ❌
- And batctl shows no neighbors ❌

## Most Likely Root Cause

Based on the symptoms, **Hypothesis 1 + Hypothesis 2** combined:

1. **Device4's startup script was NOT successfully modified**
   - The `fix_client_rfkill.sh` ran but the `sed` command might have failed silently
   - OR the script was modified but then overwritten by something

2. **Plus boot-time race condition**
   - Even if RF-kill unblock was there, timing during boot might be wrong
   - Service starts before system is ready

## Recommended Actions

### Step 1: Diagnose Device4
Run on Device4 (with USB drive mounted):
```bash
sudo /mnt/usb/ft_usb_build/diagnose_boot_mesh.sh
```

Review the log to check:
1. Is `rfkill unblock` in the startup script?
2. What does service status show?
3. What do service logs say?
4. What's the RF-kill state after boot?

### Step 2: Compare with Device5
Run the same diagnostic on Device5:
```bash
sudo /mnt/usb/ft_usb_build/diagnose_boot_mesh.sh
```

Compare the two logs to find differences:
- Startup script contents
- Service logs
- RF-kill state
- Timing differences

### Step 3: Apply Proper Fix

Based on diagnostic results, likely need to:

**If startup script is missing rfkill unblock:**
```bash
# Re-run the fix
sudo /mnt/usb/ft_usb_build/fix_client_rfkill.sh
# Verify it worked
grep "rfkill" /usr/local/bin/start-batman-mesh-client.sh
```

**If startup script has rfkill unblock but still fails:**
Add boot delay to systemd service:

```bash
# Edit service
sudo nano /etc/systemd/system/batman-mesh-client.service

# Add this line under [Service]:
ExecStartPre=/bin/sleep 5

# Reload and test
sudo systemctl daemon-reload
sudo systemctl restart batman-mesh-client.service
sudo reboot
```

**If RF-kill is getting re-enabled:**
Create a persistent RF-kill rule:

```bash
# Create udev rule to keep WiFi unblocked
echo 'ACTION=="add", SUBSYSTEM=="rfkill", ATTR{type}=="wlan", ATTR{soft}="0"' | \
sudo tee /etc/udev/rules.d/10-rfkill-wifi-unblock.rules

sudo udevadm control --reload-rules
```

## Testing Matrix

After applying fixes:

| Test | Expected Result |
|------|----------------|
| Service restart | ✅ Works (ping Device0, see neighbors) |
| Reboot | ✅ Works after boot (ping Device0, see neighbors) |
| Wait 60 seconds | ✅ Still works (stable connection) |
| Check admin interface | ✅ Shows Device4 with active connection |
| From Device0: batctl n | ✅ Shows Device4 in neighbor list |

## Next Steps

1. Move USB to Device4, run diagnostic
2. Move USB to Device5, run diagnostic
3. Compare both diagnostic logs
4. Apply targeted fix based on root cause
5. Test thoroughly (restart + reboot)
6. Apply same fix to remaining devices

## Files Needed

- `/mnt/usb/ft_usb_build/diagnose_boot_mesh.sh` - Run this on Device4 and Device5
- `/mnt/usb/ft_usb_build/fix_client_rfkill.sh` - Re-run if needed
- Diagnostic logs will save to USB automatically
