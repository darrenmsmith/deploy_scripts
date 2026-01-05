# WiFi Persistence Fix - Ready for Testing

## Problem Fixed

**Issue**: WiFi connection was available during Phase 2 but lost before Phase 3
- User reported: "wifi internet was available and then it wasn't when it got to Phase 3"
- Root cause: Phase 2 only ENABLED wlan1-internet.service but never STARTED it
- Manual connection during Phase 2 would timeout before Phase 3 began

## Solution Implemented

### 1. Phase 2 Now Starts the Service (phase2_internet.sh:589)

**OLD Behavior**:
```bash
sudo systemctl enable wlan1-internet.service  # Only enabled for boot
```

**NEW Behavior**:
```bash
sudo systemctl enable wlan1-internet.service
sudo systemctl start wlan1-internet.service   # NOW STARTS IT!
sleep 3
systemctl is-active --quiet wlan1-internet.service  # Verifies running
```

### 2. Phase 3 Pre-Flight Check (phase3_packages.sh:30)

Added connection verification before running apt:
```bash
# Check wlan1 IP
WLAN1_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}')

# If no IP, attempt recovery
if [ -z "$WLAN1_IP" ]; then
    sudo systemctl restart wlan1-internet.service
    sleep 10
    # Check again
fi
```

### 3. Menu System Updated

Fixed three menu bugs:
- `show_all_phases()` now shows Phase 1.5 in status list
- `menu_run_specific()` now allows manual selection of Phase 1.5
- `menu_help()` now documents Phase 1.5 in installation order

## How to Test

### Step 1: Delete Old State File

The old state file doesn't have phase1.5 entry:

```bash
rm /mnt/usb/install_state.json
```

### Step 2: Start Fresh Installation

```bash
cd /mnt/usb/ft_usb_build
sudo ./install_menu.sh
```

### Step 3: Run Phases in Order

Press **1** to run next phase for each:

**Phase 1**: Hardware Setup
- Should complete quickly
- Enables SSH, I2C, SPI

**Phase 1.5**: Network Prerequisites ← **YOU SHOULD NOW SEE THIS**
- Checks for wpasupplicant, dhcpcd5, iptables
- If missing, offers to install from `/mnt/usb/ft_usb_build/offline_packages/`
- **Expected**: Should find offline .deb files and offer to install them

**Phase 2**: Internet Connection
- Connects to xsmithhome WiFi
- **CRITICAL CHECKPOINT 1**: Look for these new messages:
  ```
  ✓ Service enabled - will start on boot
  ⏱  Starting service...
  ✓ Service started
  ✓ Service is running
  ```
- 3-minute countdown timer
- Shows IP address at end

**Between Phase 2 and Phase 3** (Optional Manual Check):
```bash
# Open another SSH session and check:
systemctl status wlan1-internet
# Should show "active (running)"

ip addr show wlan1
# Should show IP address (not 169.254.x.x)
```

**Phase 3**: Package Installation
- **CRITICAL CHECKPOINT 2**: Pre-flight check should pass:
  ```
  Pre-flight Check: Verifying wlan1 connection...
    wlan1 IP: ✓ 192.168.1.xxx/24
  ```
- If connection lost, should show recovery attempt
- Installs all apt/pip packages

### Expected Success Indicators

✅ **Phase 1.5 appears in menu**
✅ **Offline packages install successfully** (if on minimal OS)
✅ **"Service started" message appears in Phase 2**
✅ **"Service is running" confirmation in Phase 2**
✅ **Pre-flight check shows wlan1 IP in Phase 3**
✅ **No "connection lost" errors between Phase 2 and Phase 3**
✅ **Phase 3 apt update/install commands succeed**

### If It Still Fails

Check the logs:
```bash
cat /mnt/usb/install_logs/phase2_internet_*.log | grep -A5 "Starting service"
cat /mnt/usb/install_logs/phase3_packages_*.log | grep -A5 "Pre-flight"
```

Manual service check:
```bash
sudo systemctl status wlan1-internet
sudo journalctl -u wlan1-internet -n 50
```

## What Changed

### Files Modified

1. **install_menu.sh**:
   - Line 157: Added 1.5 to phase loop in `show_all_phases()`
   - Line 346: Added 1.5 to phase loop in `menu_run_specific()`
   - Line 355: Updated regex to accept "1.5" as valid input
   - Line 424: Added Phase 1.5 to help documentation

2. **phases/phase2_internet.sh**:
   - Line 589: Added service START commands (not just enable)
   - Added verification that service is running
   - Added logging for service start events

3. **phases/phase3_packages.sh**:
   - Line 30: Added pre-flight wlan1 connection check
   - Added automatic recovery attempt if connection lost
   - Improved error messages

### Files Already Created

- `phases/phase1.5_network_prerequisites.sh` - Prerequisite check phase
- `offline_packages/dhcpcd5_*.deb` - Offline DHCP client
- `offline_packages/wpasupplicant_*.deb` - Offline WiFi tools
- `offline_packages/iptables_*.deb` - Offline firewall

## Bottom Line

**The Fix**: Phase 2 now actually STARTS the wlan1-internet.service (not just enables it for boot), ensuring WiFi connection persists between phases.

**The Safety Net**: Phase 3 checks the connection before starting and attempts recovery if lost.

**The User Experience**: Phase 1.5 now appears in menu and handles network prerequisite installation.

**Ready to test!** Just delete the old state file and run the menu.
