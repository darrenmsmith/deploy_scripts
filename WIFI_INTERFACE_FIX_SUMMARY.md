# WiFi Interface Persistent Naming - Build Script Updates

**Date:** 2026-01-02
**Issue:** WiFi interface names (wlan0/wlan1) can swap between boots
**Solution:** Automated udev rules creation in Phase 1

---

## Problem Statement

Raspberry Pi with two WiFi interfaces:
- **Onboard WiFi** (mmc bus) - needed for MESH network
- **USB WiFi adapter** - needed for INTERNET connection

**Issue:** Interface names can swap:
- Sometimes onboard = wlan0, USB = wlan1 ✓ (correct)
- Sometimes onboard = wlan1, USB = wlan0 ✗ (wrong)

This breaks the build scripts which expect:
- `wlan0` = mesh network (onboard)
- `wlan1` = internet (USB)

---

## Solution Implemented

### Updated Scripts

**1. phase1_hardware.sh**
   - Added **Step 6: Create Persistent WiFi Interface Names**
   - Automatically detects WiFi MAC addresses
   - Creates udev rules to lock interface names
   - Verifies onboard vs USB adapter
   - Prompts for reboot after completion

**2. phase3_packages.sh**
   - Added WiFi interface verification before package installation
   - Sources `wifi_verification_functions.sh`
   - Verifies both wlan0 and wlan1 exist
   - Verifies wlan1 has internet connectivity
   - Clearer error messages if Phase 2 incomplete

**3. phase4_mesh.sh**
   - Fixed systemd service dependency (removed wlan1-internet.service dependency)
   - Now depends on `network-pre.target` instead
   - Prevents timeout errors on batman-mesh.service startup

**4. New Verification Tools**
   - `wifi_verification_functions.sh` - Shared verification functions
   - `VERIFY_WIFI_INTERFACES.sh` - Standalone diagnostic tool

---

## How It Works

### Phase 1 (Hardware Verification)

When you run `phase1_hardware.sh`, it now:

1. **Detects WiFi Interfaces** (Step 5)
   - Counts WiFi interfaces
   - Lists MAC addresses

2. **Creates udev Rules** (Step 6) ✨ **NEW**
   - Reads MAC addresses from wlan0 and wlan1
   - Verifies which is onboard (mmc bus) and which is USB
   - Creates `/etc/udev/rules.d/70-persistent-net.rules`
   - Locks interface names by MAC address

3. **Prompts for Reboot**
   - udev rules require reboot to take effect
   - Offers automatic reboot or manual reboot reminder

### Example udev Rule Created

```bash
# Field Trainer - Persistent WiFi Interface Names
# wlan0 = Onboard WiFi (mesh network via batman-adv)
# wlan1 = USB WiFi adapter (internet connection)

SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="b8:27:eb:3e:4a:99", NAME="wlan0"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="9c:ef:d5:f9:5d:01", NAME="wlan1"
```

**Result:**
- MAC `b8:27:eb:3e:4a:99` will ALWAYS be `wlan0` (mesh)
- MAC `9c:ef:d5:f9:5d:01` will ALWAYS be `wlan1` (internet)

No more interface swapping!

---

## Updated Installation Flow

### Fresh Installation Process

**Step 1: Flash SD Card**
- Use Raspberry Pi Imager
- **Do NOT configure WiFi** in imager (important!)
- Enable SSH
- Set username/password
- Boot Pi

**Step 2: Insert USB WiFi Adapter**
- Plug in USB WiFi adapter
- Wait for it to be detected

**Step 3: Run Phase 1 (Hardware Verification)**
```bash
cd /mnt/usb/ft_usb_build/phases
sudo ./phase1_hardware.sh
```

Phase 1 will:
- ✓ Verify OS (Trixie)
- ✓ Verify kernel (6.1+)
- ✓ Verify memory
- ✓ Detect both WiFi interfaces
- ✓ **Create udev rules** (locks wlan0/wlan1 names) ✨
- ✓ Verify batman-adv module
- ✓ Test IBSS support
- ✓ Enable SSH, I2C, SPI
- ⚠ Prompt for reboot

**Step 4: Reboot**
```bash
sudo reboot
```

**After reboot:**
- wlan0 will ALWAYS be onboard WiFi (for mesh)
- wlan1 will ALWAYS be USB WiFi (for internet)

**Step 5: Run Phase 2 (Internet Connection)**
```bash
cd /mnt/usb/ft_usb_build/phases
sudo ./phase2_internet.sh
```

Configures wlan1 for internet via WiFi.

**Step 6: Run Phase 3 (Packages)**
```bash
sudo ./phase3_packages.sh
```

Now includes verification:
- Checks both wlan0 and wlan1 exist
- Verifies wlan1 has IP address
- Verifies internet connectivity
- Installs packages

**Step 7: Run Phase 4 (Mesh Network)**
```bash
sudo ./phase4_mesh.sh
```

Configures wlan0 for batman-adv mesh network.

---

## Verification Tools

### Standalone WiFi Verification

Before running any phase, you can verify WiFi configuration:

```bash
cd /mnt/usb/ft_usb_build/phases
sudo ./VERIFY_WIFI_INTERFACES.sh
```

**Output:**
```
==========================================
WiFi Interface Verification
==========================================

Step 1: Checking WiFi Interfaces...
  wlan0 (onboard WiFi)... ✓ exists
  wlan1 (USB WiFi)... ✓ exists

Step 2: Verifying Interface Types...
  wlan0 type... ✓ onboard (mmc/sdio bus)
    Path: /sys/devices/.../mmc.../wlan0
  wlan1 type... ✓ USB adapter
    Path: /sys/devices/.../usb.../wlan1

Step 3: Checking Interface States...
  wlan0 state: DOWN
  wlan1 state: UP

Step 4: Checking for Conflicts...
  wlan0 IP address... ✓ none (correct for mesh config)
  wlan1 IP address... ✓ HAS IP: 192.168.7.122/24

Step 5: Checking RF-Kill Status...
  ✓ WiFi not blocked

==========================================
✓ All checks passed!

Configuration:
  • wlan0 (onboard)  → MESH network (batman-adv)
  • wlan1 (USB)      → INTERNET connection (DHCP)
```

---

## Troubleshooting

### If Interfaces Still Swap

1. **Check udev rules exist:**
```bash
cat /etc/udev/rules.d/70-persistent-net.rules
```

Should show both wlan0 and wlan1 rules.

2. **Verify MAC addresses match:**
```bash
cat /sys/class/net/wlan0/address
cat /sys/class/net/wlan1/address
```

Compare to MAC addresses in udev rules.

3. **Reload udev rules:**
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

4. **Re-run Phase 1:**
```bash
cd /mnt/usb/ft_usb_build/phases
sudo ./phase1_hardware.sh
```

Will recreate udev rules with current MAC addresses.

### If wlan0 is Connected to Home WiFi

This happens if you configured WiFi in Raspberry Pi Imager.

**Fix:**
```bash
# Disconnect wlan0
sudo ip addr flush dev wlan0
sudo ip link set wlan0 down
sudo pkill -f "wpa_supplicant.*wlan0"

# Remove wpa_supplicant config for wlan0
sudo rm -f /etc/wpa_supplicant/wpa_supplicant.conf

# Verify wlan0 is free
ip addr show wlan0
# Should show: no IP, state DOWN
```

### If wlan1 Shows "carrier lost"

Check USB WiFi adapter:
```bash
# Check USB device
lsusb

# Check power management
iw dev wlan1 get power_save

# Disable power save
sudo iw dev wlan1 set power_save off

# Check signal
iwconfig wlan1
```

If signal weak or 5GHz not supported:
- Move Pi closer to router
- Use 2.4GHz network instead
- Check if USB adapter supports 5GHz

---

## Files Modified

### `/mnt/usb/ft_usb_build/phases/`

**Updated:**
1. `phase1_hardware.sh` - Added Step 6 (udev rules creation)
2. `phase3_packages.sh` - Added WiFi verification
3. `phase4_mesh.sh` - Fixed systemd dependency

**Created:**
4. `wifi_verification_functions.sh` - Shared verification functions
5. `VERIFY_WIFI_INTERFACES.sh` - Standalone diagnostic tool

---

## Benefits

✅ **Automated** - No manual MAC address lookup needed
✅ **Persistent** - Interface names never swap after reboot
✅ **Verified** - Scripts verify correct configuration before proceeding
✅ **Documented** - udev rules include comments explaining purpose
✅ **Recoverable** - Can re-run Phase 1 to recreate rules

---

## Technical Details

### udev Rule Syntax

```bash
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="MAC", NAME="wlanX"
```

- `SUBSYSTEM=="net"` - Matches network devices
- `ACTION=="add"` - Triggers when device is added
- `ATTR{address}=="MAC"` - Matches specific MAC address
- `NAME="wlanX"` - Assigns interface name

### Why This Works

- udev rules are processed during boot
- MAC address is hardware-specific and never changes
- Rule assigns interface name BEFORE network services start
- Subsequent scripts can rely on consistent naming

### Priority

File: `/etc/udev/rules.d/70-persistent-net.rules`
- Number `70` = priority (lower = earlier)
- Runs before network configuration (75)
- Runs after hardware detection (50-69)

---

## Next Steps for Fresh Install

1. **Flash SD Card** - Don't configure WiFi in imager
2. **Insert USB WiFi adapter**
3. **Run Phase 1** - Creates udev rules automatically
4. **Reboot** - udev rules take effect
5. **Run Phase 2** - Configure wlan1 for internet
6. **Run Phase 3** - Install packages (now verified)
7. **Run Phase 4** - Configure wlan0 for mesh

**You're now protected from interface swapping!** 🎉

---

**Summary:** Build scripts now automatically create persistent WiFi interface naming rules. No more manual udev configuration needed!
