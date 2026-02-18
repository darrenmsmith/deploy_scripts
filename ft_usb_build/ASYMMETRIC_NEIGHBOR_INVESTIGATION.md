# Asymmetric Neighbor Visibility Investigation

## The Mystery

**Symptoms:**
- Device0 Prod sees **2 neighbors** with different last-seen times:
  - One at **80.332s** (very stale - dying connection)
  - One at **0.668s** (active - healthy connection)
- Device4 sees **NO neighbors** (batctl n returns nothing)
- Device5 works fine after reboot
- Device3 on Dev system works fine
- Robust fix works on **restart** but NOT on **reboot**

**Critical Question:** Why can Device0 see Device4 (with stale timestamp) but Device4 cannot see Device0?

## Asymmetric Connection Analysis

### Scenario A: One-Way Communication
- Device4 is transmitting (Device0 can hear it)
- Device4 is NOT receiving (cannot hear Device0)
- Possible causes:
  - RF-kill blocking reception but not transmission
  - wlan0 not in proper IBSS mode (in managed mode, can send but not mesh-receive)
  - Antenna/hardware issue on Device4

### Scenario B: Stale Entry
- Device4 WAS connected (hence the 80s entry)
- Device4 connection died but Device0 still has cached entry
- After reboot, Device4 fails to rejoin properly
- Device0 hasn't timed out the old entry yet

### Scenario C: Interface State Mismatch
- Device4 thinks it's in IBSS but actually isn't
- Service reports success but interface is in wrong state
- Batman-adv added wlan0 but wlan0 is not actually in IBSS mode

## What We Need to Determine

### On Device0 Prod:

1. **Which neighbor is which?**
   - Run `device0_neighbor_analysis.sh`
   - Match MAC addresses to device numbers:
     - Device4 MAC: `b8:27:eb:a9:54:36`
     - Device5 MAC: `b8:27:eb:61:4b:0e`
   - Identify which has 80.332s and which has 0.668s

2. **Can Device0 see Device4 at WiFi layer?**
   - Check `iw dev wlan0 station dump`
   - If Device4 shows up here, it's transmitting
   - If not, Device4's radio might be off

### On Device3 (Dev - Working):

1. **Full baseline of working configuration**
   - Run `compare_device_full.sh`
   - This is our "known good" reference

### On Device4 (Prod - Broken):

1. **Compare to Device3**
   - Run `compare_device_full.sh`
   - Compare every section side-by-side with Device3

2. **Key things to check:**
   - Is phy0 soft-blocked? (should be NO)
   - Is wlan0 type IBSS? (should be yes)
   - Does `iw dev wlan0 station dump` show Device0?
   - Does startup script have robust RF-kill unblock?
   - Are there any error messages in service logs?

### On Device5 (Prod - Working):

1. **Another working reference**
   - Run `compare_device_full.sh`
   - Compare to Device3 and Device4
   - What's different about Device5 that makes it work?

## Specific Questions to Answer

1. **RF-kill after reboot:**
   - Device4: Is phy0 soft-blocked?
   - Device3/Device5: Is phy0 soft-blocked?

2. **IBSS mode:**
   - Device4: `iw dev wlan0 info | grep type` shows what?
   - Device3/Device5: Same command shows what?

3. **WiFi layer visibility:**
   - Device4: Can it see ANY IBSS stations? (`iw dev wlan0 station dump`)
   - Device0: Can it see Device4 in station dump?

4. **Service execution:**
   - Device4: What do service logs show from this boot?
   - Any errors in `journalctl -u batman-mesh-client.service -b`?

5. **Timing:**
   - How long has Device4 been up?
   - When did the service start?
   - Is 80.332s roughly matching Device4's uptime?

## Running the Diagnostics

### Step 1: On Device0 Prod (current location)
```bash
sudo /mnt/usb/ft_usb_build/device0_neighbor_analysis.sh
```

### Step 2: Move USB to Device4 Prod
```bash
sudo /mnt/usb/ft_usb_build/compare_device_full.sh
```

### Step 3: Move USB to Device5 Prod
```bash
sudo /mnt/usb/ft_usb_build/compare_device_full.sh
```

### Step 4: Move USB to Device3 Dev
```bash
sudo /mnt/usb/ft_usb_build/compare_device_full.sh
```

### Step 5: Bring USB back to Device0 for analysis

## What the 80.332s Timing Tells Us

**Last-seen: 80.332s** means:
- Device0 last received a batman-adv packet from this neighbor 80 seconds ago
- Normal last-seen should be < 5 seconds for healthy mesh
- 80+ seconds means:
  - No batman-adv packets received in over a minute
  - Connection is effectively dead/dying
  - Entry will timeout soon (typically 200s)

**If this is Device4:**
- Device4 was transmitting at boot
- Then stopped transmitting (or Device0 stopped receiving)
- But Device4 never established proper mesh connection

**If this is an old/ghost entry:**
- From a previous boot/connection attempt
- Device4 never actually connected this boot

## Expected Differences Between Working and Broken

### Working Device (Device3/Device5):
```
phy0: Soft blocked: no
wlan0 type: IBSS
wlan0 ssid: ft_mesh2
batctl if: wlan0: active
batctl n: Shows Device0 with fresh timestamp (< 5s)
iw dev wlan0 station dump: Shows Device0 MAC
```

### Broken Device (Device4 suspected):
```
phy0: Soft blocked: YES (or NO if robust fix worked)
wlan0 type: managed (not IBSS!)
wlan0 ssid: off/any
batctl if: wlan0: inactive
batctl n: Shows nothing
iw dev wlan0 station dump: Shows nothing or Device0 but no proper connection
```

## Next Steps After Diagnostics

Once we have all the logs, we'll compare:
1. Startup scripts (line by line)
2. RF-kill states
3. Interface states
4. Service execution logs
5. Hardware differences (WiFi chipset)
6. Timing of service startup vs system initialization

This will reveal exactly what's different between working and broken devices.
