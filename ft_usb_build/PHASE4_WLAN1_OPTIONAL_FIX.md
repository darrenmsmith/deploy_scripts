# Phase 4 Updated - wlan1 Made Optional

## Date: 2026-01-07

## Change Summary

Updated `/mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh` to make wlan1 (external USB WiFi adapter) optional and available for other uses.

## Previous Behavior

The earlier version disabled WiFi globally in NetworkManager:
```bash
nmcli radio wifi off
```

This disabled **ALL** WiFi radios:
- wlan0 (onboard) - needed for mesh
- wlan1 (external USB adapter) - might be needed for internet, etc.

## New Behavior

Now uses **targeted unmanaged configuration**:
```bash
# Only mark wlan0 and bat0 as unmanaged
/etc/NetworkManager/conf.d/99-unmanage-wlan0.conf:
[keyfile]
unmanaged-devices=interface-name:wlan0;interface-name:bat0
```

This allows:
- **wlan0** - Unmanaged by NetworkManager, used exclusively for BATMAN-adv mesh
- **wlan1** - Remains available for NetworkManager (WiFi connectivity, internet, etc.)

## What Changed

### 1. Step 4: Configure NetworkManager

**Before:**
- Globally disabled WiFi: `nmcli radio wifi off`
- Affected all WiFi interfaces

**After:**
- Creates unmanaged config for wlan0 only
- Verifies wlan0 is unmanaged
- Detects and reports wlan1 status (if present)
- wlan1 remains available for NetworkManager

### 2. Mesh Startup Script

**Before:**
```bash
# Disable WiFi in NetworkManager to prevent interference
if command -v nmcli &>/dev/null; then
    nmcli radio wifi off 2>/dev/null || true
fi
```

**After:**
```bash
# No longer disables WiFi globally
# NetworkManager unmanaged config handles wlan0
# wlan1 remains available
```

### 3. Status Messages

The script now reports:
- Whether wlan1 is detected
- wlan1's NetworkManager state
- Confirms wlan1 is available for other uses

## Benefits

1. **Flexibility**: wlan1 can be used for internet connectivity while mesh operates on wlan0
2. **Optional wlan1**: Script works whether wlan1 exists or not
3. **Cleaner separation**: Mesh uses wlan0 exclusively, other services can use wlan1
4. **No global WiFi disable**: NetworkManager WiFi features remain available for wlan1

## How It Works

### Device Configuration After Phase 4

```bash
nmcli device status
```

Expected output:
```
DEVICE  TYPE      STATE        CONNECTION
wlan0   wifi      unmanaged    --         # Mesh network
wlan1   wifi      disconnected --         # Available for NetworkManager
bat0    batadv    unmanaged    --         # Mesh virtual interface
```

### What Happens on Boot

1. **NetworkManager starts** - loads unmanaged config
2. **NetworkManager sees wlan0** - ignores it (unmanaged)
3. **NetworkManager sees wlan1** - can manage it (not in unmanaged list)
4. **batman-mesh-client.service starts** - configures wlan0 for IBSS mesh
5. **wlan0** stays in IBSS mode - NetworkManager doesn't interfere
6. **wlan1** available - can connect to WiFi AP, internet, etc.

## Testing Instructions

### 1. Run Updated Phase 4 on Device4

```bash
# On Device4
sudo /mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh
```

### 2. Verify NetworkManager Configuration

```bash
# Check device status
nmcli device status

# Should show:
# wlan0: unmanaged (mesh)
# wlan1: disconnected or connected (available)

# Check unmanaged config exists
cat /etc/NetworkManager/conf.d/99-unmanage-wlan0.conf
```

### 3. Verify Mesh Works on wlan0

```bash
iw dev wlan0 info          # Should show "type IBSS"
sudo batctl if             # Should show "wlan0: active"
sudo batctl n              # Should show Device0
ping 192.168.99.100        # Should ping Device0
```

### 4. Verify wlan1 Available (if present)

```bash
# Check if wlan1 exists
ip link show wlan1

# If wlan1 exists, you can connect it to WiFi:
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"

# Or use it for other purposes
```

### 5. Test Reboot Persistence

```bash
sudo reboot
```

After reboot:
```bash
# Mesh should still work
sudo batctl n              # Should show Device0

# wlan1 should still be available
nmcli device status        # wlan1 should be shown
```

## Use Cases

### Use Case 1: Mesh Only (No wlan1)
- Device has only onboard WiFi (wlan0)
- wlan0 used for mesh networking
- No internet connectivity needed
- **Works**: wlan1 not required

### Use Case 2: Mesh + Internet via wlan1
- Device has onboard WiFi (wlan0) + external USB WiFi (wlan1)
- wlan0 used for mesh networking (Device0 communication)
- wlan1 connected to WiFi AP for internet
- **Works**: Both interfaces independent

### Use Case 3: Development/Testing
- wlan0 for mesh to Device0 (production network)
- wlan1 for WiFi to dev network (updates, logs, debugging)
- **Works**: Can access both networks simultaneously

## Troubleshooting

### wlan0 Not Unmanaged

If `nmcli device status` shows wlan0 as anything other than "unmanaged":

```bash
# Check config exists
ls -l /etc/NetworkManager/conf.d/99-unmanage-wlan0.conf

# If missing, create it:
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/99-unmanage-wlan0.conf > /dev/null << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0;interface-name:bat0

[device]
wifi.scan-rand-mac-address=no
EOF

# Restart NetworkManager
sudo systemctl restart NetworkManager.service

# Verify
nmcli device status | grep wlan0
```

### Mesh Not Working

If mesh doesn't work after Phase 4:

```bash
# Check wlan0 mode
iw dev wlan0 info          # Should be "type IBSS"

# Check batman-adv
sudo batctl if             # Should show wlan0: active

# Check NetworkManager not interfering
nmcli device status | grep wlan0  # Should be "unmanaged"

# Restart mesh service
sudo systemctl restart batman-mesh-client.service

# Check logs
journalctl -u batman-mesh-client.service -b
```

### wlan1 Not Available

If wlan1 should be present but isn't showing:

```bash
# Check hardware
lsusb                      # Should show USB WiFi adapter

# Check interface exists
ip link show wlan1

# Check driver loaded
dmesg | grep -i wifi

# Check NetworkManager sees it
nmcli device status
```

## Configuration Files

### Created/Modified by Phase 4

1. `/etc/NetworkManager/conf.d/99-unmanage-wlan0.conf`
   - Marks wlan0 and bat0 as unmanaged
   - Does NOT mark wlan1 as unmanaged

2. `/usr/local/bin/start-batman-mesh-client.sh`
   - Configures wlan0 for IBSS mesh on boot
   - Does NOT disable WiFi globally
   - Does NOT affect wlan1

3. `/etc/systemd/system/batman-mesh-client.service`
   - Starts mesh on boot
   - Only manages wlan0 and bat0
   - Does not interact with wlan1

## Verification Commands

```bash
# NetworkManager status
nmcli general status
nmcli device status

# wlan0 mesh status
iw dev wlan0 info
sudo batctl if
sudo batctl n

# wlan1 status (if present)
ip link show wlan1
nmcli device show wlan1

# Full diagnostic
sudo /mnt/usb/ft_usb_build/diagnose_ibss_no_connection.sh
```

## Expected Results

After Phase 4 with updated script:
- ✅ wlan0 marked as unmanaged by NetworkManager
- ✅ wlan0 configured for IBSS mesh
- ✅ Mesh network works (can see Device0)
- ✅ wlan1 (if present) remains available
- ✅ wlan1 can be used for WiFi/internet
- ✅ Configuration persists through reboot

## Comparison: Device5 vs New Configuration

### Device5 (Original Working Config)
```
nmcli general status:
WIFI: disabled               # All WiFi disabled globally

nmcli device status:
wlan0  wifi  unavailable     # Can't be managed (WiFi disabled)
wlan1  wifi  unavailable     # Can't be managed (WiFi disabled)
```

### New Configuration (More Flexible)
```
nmcli general status:
WIFI: enabled                # WiFi enabled for wlan1

nmcli device status:
wlan0  wifi  unmanaged       # Can't be managed (explicitly unmanaged)
wlan1  wifi  disconnected    # CAN be managed (available for use)
```

Both configurations prevent NetworkManager from interfering with wlan0 mesh, but the new configuration allows wlan1 to remain usable.

## References

- `/mnt/usb/ft_usb_build/client_phases/phase4_mesh.sh` - Updated script
- `/mnt/usb/ft_usb_build/PHASE4_NETWORKMANAGER_FIX.md` - Previous version documentation
- `/mnt/usb/ft_usb_build/NETWORKMANAGER_TRUE_ROOT_CAUSE.md` - Root cause analysis

## Status

- ✅ Phase 4 script updated to make wlan1 optional
- ✅ wlan0 marked as unmanaged (not global WiFi disable)
- ✅ wlan1 remains available for NetworkManager
- ✅ Script detects and reports wlan1 status
- ⏳ Need to test on Device4
- ⏳ Verify mesh works with new configuration
- ⏳ Test wlan1 functionality if present

---

**This update makes the mesh configuration more flexible while still preventing NetworkManager interference.**
