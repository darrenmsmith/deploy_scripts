# Test Scripts Menu System

## Date: 2026-01-08

## Overview

The `ft_build.sh` menu now includes a comprehensive "Test Scripts" submenu (option 7) that provides organized access to all diagnostic and testing scripts on the USB drive.

## Features

### 1. Categorized Organization
Scripts are grouped into 5 logical categories:
- **Sensor Testing** - I2C sensor verification
- **Mesh Network Status** - BATMAN mesh diagnostics
- **Network & Connectivity** - Network configuration checks
- **Application Testing** - Field Trainer app verification (gateway only)
- **System Verification** - System-wide checks

### 2. Device-Specific Filtering
The menu automatically shows only relevant scripts based on device type:
- **Gateway (Device0)** - Shows gateway-specific mesh tests
- **Client (Device1-5)** - Shows client-specific mesh tests
- **All Devices** - Common scripts shown on all devices

### 3. Friendly Names
All scripts have clear, descriptive names:
- `verify_sensors.sh` → "I2C Sensor Verification (MPU6500/MPU9250)"
- `quick_mesh_check.sh` → "Quick Mesh Status Check"

### 4. Automatic Return
After running a test script, the menu automatically returns to the test scripts submenu. Press `0` to return to main menu.

## Menu Structure

### Main Menu
```
1) Run Next Phase
2) Run All Remaining Phases
3) Jump to Specific Phase
4) Re-run Current/Previous Phase
5) View Build Status
6) Reset Build (Start Over)
7) Test Scripts                    ← NEW!
8) Exit
9) Clean Logs and Exit
```

### Test Scripts Submenu

#### Gateway (Device0)
```
Sensor Testing:
  1) I2C Sensor Verification (MPU6500/MPU9250)

Mesh Network Status:
  2) Capture Gateway Mesh Status
  3) Diagnose Gateway Mesh Network
  4) Manual Mesh Test - Gateway
  5) Manual Mesh Test - Gateway (Logged)
  8) Quick Mesh Status Check
  9) Diagnose Mesh on Boot
  10) Capture BATMAN Error Logs

Network & Connectivity:
  11) Check Network Interference
  12) Check NetworkManager Configuration
  13) Diagnose Port 5001 Issues

Application Testing:
  14) Check Field Trainer Application

System Verification:
  15) Verify All Devices in System
  16) Verify Recent Fixes Status
  17) Check Phase 5 Errors
  18) Debug BATMAN Service

  0) Back to Main Menu
```

#### Client (Device1-5)
```
Sensor Testing:
  1) I2C Sensor Verification (MPU6500/MPU9250)

Mesh Network Status:
  2) Capture Client Mesh Status
  3) Check Client Mesh Configuration
  4) Diagnose Client Mesh Network
  5) Diagnose IBSS Connection Issues
  6) Manual Mesh Test - Client
  7) Manual Mesh Test - Client (Logged)
  8) Quick Mesh Status Check
  9) Diagnose Mesh on Boot
  10) Capture BATMAN Error Logs

Network & Connectivity:
  11) Check Network Interference
  12) Check NetworkManager Configuration
  13) Diagnose Port 5001 Issues

System Verification:
  15) Verify All Devices in System
  16) Verify Recent Fixes Status
  17) Check Phase 5 Errors
  18) Debug BATMAN Service

  0) Back to Main Menu
```

## Script Mapping

### All Devices (18 scripts total)

| Menu # | Script Filename | Friendly Name | Category |
|--------|----------------|---------------|----------|
| 1 | verify_sensors.sh | I2C Sensor Verification (MPU6500/MPU9250) | Sensor Testing |
| 8 | quick_mesh_check.sh | Quick Mesh Status Check | Mesh Network |
| 9 | diagnose_boot_mesh.sh | Diagnose Mesh on Boot | Mesh Network |
| 10 | capture_batman_error.sh | Capture BATMAN Error Logs | Mesh Network |
| 11 | check_network_interference.sh | Check Network Interference | Network |
| 12 | check_networkmanager_config.sh | Check NetworkManager Configuration | Network |
| 13 | diagnose_port5001_failure.sh | Diagnose Port 5001 Issues | Network |
| 15 | verify_all_devices.sh | Verify All Devices in System | System |
| 16 | verify_fix_status.sh | Verify Recent Fixes Status | System |
| 17 | check_phase5_error.sh | Check Phase 5 Errors | System |
| 18 | debug_batman_service.sh | Debug BATMAN Service | System |

### Gateway Only (4 scripts)

| Menu # | Script Filename | Friendly Name | Category |
|--------|----------------|---------------|----------|
| 2 | capture_device0_mesh_status.sh | Capture Gateway Mesh Status | Mesh Network |
| 3 | diagnose_device0_mesh.sh | Diagnose Gateway Mesh Network | Mesh Network |
| 4 | manual_mesh_test_device0.sh | Manual Mesh Test - Gateway | Mesh Network |
| 5 | manual_mesh_test_device0_logged.sh | Manual Mesh Test - Gateway (Logged) | Mesh Network |
| 14 | check_field_trainer_app.sh | Check Field Trainer Application | Application |

### Client Only (6 scripts)

| Menu # | Script Filename | Friendly Name | Category |
|--------|----------------|---------------|----------|
| 2 | capture_client_mesh_status.sh | Capture Client Mesh Status | Mesh Network |
| 3 | check_client_mesh_config.sh | Check Client Mesh Configuration | Mesh Network |
| 4 | diagnose_client_mesh.sh | Diagnose Client Mesh Network | Mesh Network |
| 5 | diagnose_ibss_no_connection.sh | Diagnose IBSS Connection Issues | Mesh Network |
| 6 | manual_mesh_test.sh | Manual Mesh Test - Client | Mesh Network |
| 7 | manual_mesh_test_client_logged.sh | Manual Mesh Test - Client (Logged) | Mesh Network |

## Usage Examples

### Example 1: Verify Sensors After Phase 3

```bash
# Run ft_build.sh
sudo /mnt/usb/ft_usb_build/ft_build.sh

# Select option 7 (Test Scripts)
# Select option 1 (I2C Sensor Verification)
# Script runs and shows sensor status
# Press Enter to return to test menu
# Press 0 to return to main menu
```

### Example 2: Check Mesh Network Status

**On Gateway:**
```bash
# Run ft_build.sh
sudo /mnt/usb/ft_usb_build/ft_build.sh

# Select option 7 (Test Scripts)
# Select option 8 (Quick Mesh Status Check)
# See mesh neighbors, BATMAN status
```

**On Client:**
```bash
# Same steps - option 8 shows client perspective
```

### Example 3: Diagnose IBSS Connection Issues

**On Client only:**
```bash
# Run ft_build.sh
sudo /mnt/usb/ft_usb_build/ft_build.sh

# Select option 7 (Test Scripts)
# Select option 5 (Diagnose IBSS Connection Issues)
# Script analyzes RF-kill, NetworkManager, IBSS mode
```

### Example 4: Verify All Devices in System

**On Gateway:**
```bash
# Run ft_build.sh
sudo /mnt/usb/ft_usb_build/ft_build.sh

# Select option 7 (Test Scripts)
# Select option 15 (Verify All Devices in System)
# Script checks all Device1-5 connectivity
```

## Implementation Details

### Code Structure

**New Functions:**
```bash
# Show test scripts submenu (device-aware)
show_test_menu()

# Run a specific test script with friendly name
run_test_script(SCRIPT_NAME, FRIENDLY_NAME)

# Handle test menu navigation and selection
handle_test_menu()
```

**Integration:**
```bash
# Main menu option 7 now calls:
7) handle_test_menu ;;
```

### Device Type Detection

The menu uses the existing `$DEVICE_TYPE` variable:
```bash
if [ "$DEVICE_TYPE" == "gateway" ]; then
    # Show gateway-specific options
else
    # Show client-specific options
fi
```

### Script Location

All scripts are expected in:
```bash
$SCRIPT_DIR/script_name.sh
# Example: /mnt/usb/ft_usb_build/verify_sensors.sh
```

### Error Handling

If a script is not found:
```
✗ Script not found: script_name.sh
Expected location: /mnt/usb/ft_usb_build/script_name.sh
```

## Benefits

### 1. Organization
- 21 test scripts now organized by category
- Easy to find the right tool for the job
- No need to remember script names

### 2. Discoverability
- All available tests visible in one menu
- Friendly names explain what each script does
- Context-aware (only shows relevant tests)

### 3. Consistency
- Same interface as phase management
- Familiar navigation (numbers + Enter)
- Automatic return to menu

### 4. Efficiency
- Quick access to diagnostic tools
- No need to type long script paths
- Run multiple tests in sequence

## Troubleshooting

### Menu Doesn't Show Test Scripts Option

**Problem:** Old ft_build.sh cached in memory

**Solution:**
```bash
# Exit current menu
# Re-run from USB
sudo /mnt/usb/ft_usb_build/ft_build.sh
```

### Script Not Found Error

**Problem:** Script missing or USB not mounted

**Solution:**
```bash
# Check USB mounted
mount | grep usb

# Verify script exists
ls -la /mnt/usb/ft_usb_build/verify_sensors.sh

# Re-mount USB if needed
```

### Wrong Scripts Showing (Gateway vs Client)

**Problem:** Hostname not set correctly

**Solution:**
```bash
# Check hostname
hostname

# Should be: Device0 (gateway) or Device1-5 (client)
# Fix if needed:
sudo hostnamectl set-hostname Device0
```

## Future Enhancements

Possible additions:
- Add timestamps to test results
- Save test outputs to logs automatically
- Add "Run All Tests" option
- Add test result history viewer
- Color-coded test status (pass/fail/warning)

## Related Documentation

- `/mnt/usb/ft_usb_build/SENSOR_VERIFICATION_IMPROVEMENTS.md` - Sensor testing details
- `/mnt/usb/ft_usb_build/MPU6500_LIBRARY_FIX.md` - MPU6500 library changes
- `/mnt/usb/ft_usb_build/I2C_SETUP_GUIDE.md` - I2C setup guide
- `/mnt/usb/ft_usb_build/PHASE4_*.md` - Mesh network documentation

---

**Summary:** The Test Scripts menu provides organized, device-aware access to all 21 diagnostic scripts with friendly names and automatic navigation.
