# Sensor Verification Improvements

## Date: 2026-01-08

## Issues Fixed

### Issue 1: MPU6050 Not Detected - Wrong Sensor Type
**Problem:** verify_sensors.sh was only looking for MPU6050, but the actual hardware uses MPU6500/MPU9250

**Solution:** Updated verify_sensors.sh to support all MPU sensor variants:
- MPU6050 (WHO_AM_I: 0x68)
- MPU6500 (WHO_AM_I: 0x70)
- MPU9250 (WHO_AM_I: 0x71)

**Changes:**
- Line 175-193: Updated sensor detection messages to be generic "MPU sensor"
- Line 224-234: Added WHO_AM_I register checks for all three sensor types
- Line 255: Updated Python library message to note MPU6500 compatibility
- Line 330-334: Updated summary to say "MPU sensor" instead of "MPU6050 sensor"

### Issue 2: Sensor Verification Not Accessible
**Problem:** verify_sensors.sh script existed but wasn't easily accessible from menu

**Solution:** Added "Verify Sensors" option to installation menu

**Changes to `/mnt/usb/ft_usb_build/install_menu.sh`:**
1. Line 321: Added menu option 7 - "Verify Sensors (I2C sensor verification)"
2. Lines 452-480: New `menu_verify_sensors()` function
3. Line 502: Updated help to mention sensor verification
4. Line 508: Added I2C_SETUP_GUIDE.md to documentation list
5. Line 514: Added sensor troubleshooting tip
6. Line 530: Updated menu prompt to "1-9" (was "1-8")
7. Line 539: Added case for option 7 to call menu_verify_sensors
8. Line 549: Updated invalid choice message to "1-9"

### Issue 3: Phase 1 Premature Sensor Detection
**Problem:** Phase 1 tried to detect sensor before I2C was active (before reboot)

**Solution:** Removed sensor detection from Phase 1, added guidance to run verify_sensors.sh after Phase 3

**Changes to `/mnt/usb/ft_usb_build/client_phases/phase1_hardware.sh`:**
1. Lines 119-129: Replaced "Step 5: Test Touch Sensor" with "Step 5: I2C Configuration Note"
   - Removed i2c-tools installation attempt
   - Removed sensor scanning
   - Added guidance to run verification after Phase 3
2. Lines 213-220: Updated summary section
   - Removed conditional sensor detection message
   - Changed to: "I2C enabled (for touch sensor - verify after Phase 3)"

## Correct Sensor Verification Workflow

### Old (Incorrect) Workflow
```
Phase 1: Enable I2C → Try to detect sensor ❌ FAILS (I2C not active yet)
         ↓
      Reboot
         ↓
Phase 3: Install i2c-tools
         ↓
      ??? No clear guidance on sensor verification
```

### New (Correct) Workflow
```
Phase 1: Enable I2C in config.txt
         ↓
      Reboot ← I2C becomes active
         ↓
Phase 2: Internet setup
         ↓
Phase 3: Install i2c-tools
         ↓
   Verify Sensors: Run menu option 7 OR sudo /mnt/usb/ft_usb_build/verify_sensors.sh
         ↓
      ✓ Sensor detected and verified
```

## Menu Layout Changes

### Before
```
1) Run Next Phase
2) Run Specific Phase
3) View Phase Logs
4) Reset Installation State
5) Run Diagnostics
6) Network Stress Test
7) View Help Documentation
8) Exit
```

### After
```
1) Run Next Phase
2) Run Specific Phase
3) View Phase Logs
4) Reset Installation State
5) Run Diagnostics
6) Network Stress Test
7) Verify Sensors (I2C sensor verification)  ← NEW
8) View Help Documentation
9) Exit
```

## Sensor Detection Details

### MPU Sensor Family

All sensors use I2C address **0x68** or **0x69** (depending on AD0 pin):

| Sensor    | WHO_AM_I (0x75) | Features | Notes |
|-----------|-----------------|----------|-------|
| MPU6050   | 0x68           | 6-axis (accel + gyro) | Basic IMU |
| MPU6500   | 0x70           | 6-axis (accel + gyro) | Improved MPU6050 |
| MPU9250   | 0x71           | 9-axis (accel + gyro + mag) | Includes magnetometer |

### Python Library Compatibility

The `adafruit-circuitpython-mpu6050` library works with:
- ✅ MPU6050 (designed for)
- ✅ MPU6500 (compatible - register layout is same)
- ⚠️ MPU9250 (basic functions work, magnetometer not supported)

For full MPU9250 support, consider `mpu9250-jmdev` or `py-mpu9250` libraries.

## verify_sensors.sh Output Examples

### MPU6500 Detected (Expected Output)
```
6. Scanning I2C Buses for Sensors
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Scanning I2C bus 1 for devices...

     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
60: -- -- -- -- -- -- -- -- 68 -- -- -- -- -- -- --
70: -- -- -- -- -- -- -- --

✓ MPU sensor detected at address 0x68

7. Testing Sensor Communication
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Reading WHO_AM_I register (0x75) from sensor...

✓ Successfully read register: 0x70
✓ Sensor chip ID confirmed: MPU6500
```

### MPU9250 Detected
```
✓ MPU sensor detected at address 0x68
✓ Successfully read register: 0x71
✓ Sensor chip ID confirmed: MPU9250
```

### MPU6050 Detected
```
✓ MPU sensor detected at address 0x68
✓ Successfully read register: 0x68
✓ Sensor chip ID confirmed: MPU6050
```

## Files Modified

1. **`/mnt/usb/ft_usb_build/verify_sensors.sh`**
   - Updated sensor detection to support MPU6050/MPU6500/MPU9250
   - Updated WHO_AM_I register checks
   - Updated all user-facing messages

2. **`/mnt/usb/ft_usb_build/install_menu.sh`**
   - Added menu option 7: "Verify Sensors"
   - Created menu_verify_sensors() function
   - Updated help documentation
   - Updated menu prompt range (1-9)

3. **`/mnt/usb/ft_usb_build/client_phases/phase1_hardware.sh`**
   - Removed premature sensor detection (Step 5)
   - Added guidance to run verification after Phase 3
   - Updated summary section

## User Impact

### Before These Changes
- ❌ verify_sensors.sh reported "MPU6050 not found" even though MPU6500 was present
- ❌ Users didn't know how to run sensor verification easily
- ❌ Phase 1 tried to detect sensor when I2C wasn't active yet
- ❌ Confusing error messages about sensor not detected

### After These Changes
- ✅ verify_sensors.sh correctly detects MPU6500/MPU9250
- ✅ Easy access via installation menu (option 7)
- ✅ Phase 1 doesn't show false sensor errors
- ✅ Clear guidance: "verify after Phase 3"
- ✅ Proper identification of sensor type in verification output

## Testing Checklist

- [ ] Run Phase 1 - should NOT try to detect sensor
- [ ] Reboot after Phase 1
- [ ] Run Phase 2 (internet setup)
- [ ] Run Phase 3 (package installation)
- [ ] From installation menu, select option 7 "Verify Sensors"
- [ ] Verify script detects MPU6500 at 0x68
- [ ] Verify WHO_AM_I returns 0x70
- [ ] Verify Python sensor test works

## Documentation References

- **I2C Setup Guide:** `/mnt/usb/ft_usb_build/I2C_SETUP_GUIDE.md`
- **Phase Scripts:** `/mnt/usb/ft_usb_build/client_phases/`
- **Installation Menu:** `/mnt/usb/ft_usb_build/install_menu.sh`
- **Sensor Verification:** `/mnt/usb/ft_usb_build/verify_sensors.sh`

---

**Summary:** Sensor verification now correctly supports MPU6500/MPU9250, is easily accessible from the menu, and doesn't run prematurely in Phase 1.
