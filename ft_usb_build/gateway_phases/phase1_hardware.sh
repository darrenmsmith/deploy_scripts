#!/bin/bash

################################################################################
# Phase 0: Hardware Verification
# Verifies system meets requirements for Device 0 (Gateway)
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

ERRORS=0

# USB logging - capture all output to log file
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/phase1_hardware_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
ln -sf "$LOG_FILE" "${LOG_DIR}/phase1_hardware_latest.log"
echo "========================================" && echo "Field Trainer Installation - Phase 1: Hardware" && echo "Date: $(date)" && echo "Hostname: $(hostname)" && echo "Log: $LOG_FILE" && echo "========================================"
echo ""

echo "Phase 0: Hardware Verification"
echo "==============================="
echo ""
echo "This phase verifies that your system meets the requirements:"
echo "  • Raspberry Pi OS Trixie (64-bit)"
echo "  • Kernel 6.1+ with batman-adv support"
echo "  • Two WiFi interfaces (wlan0 and wlan1)"
echo "  • IBSS (Ad-hoc) support on wlan0"
echo ""
read -p "Press Enter to begin verification..."
echo ""

################################################################################
# Step 1: Check OS Version
################################################################################

echo "Step 1: Verifying OS Version..."
echo "--------------------------------"

if [ ! -f /etc/os-release ]; then
    print_error "Cannot find /etc/os-release"
    ERRORS=$((ERRORS + 1))
else
    source /etc/os-release
    
    echo "  OS Name: $PRETTY_NAME"
    
    if [ "$VERSION_CODENAME" = "trixie" ]; then
        print_success "Correct OS: Trixie (Debian 13)"
    else
        print_error "Wrong OS version: Expected 'trixie', got '$VERSION_CODENAME'"
        print_warning "This script is designed for Raspberry Pi OS Trixie (64-bit)"
        ERRORS=$((ERRORS + 1))
    fi
fi

echo ""

################################################################################
# Step 2: Check Architecture
################################################################################

echo "Step 2: Verifying Architecture..."
echo "----------------------------------"

ARCH=$(uname -m)
echo "  Architecture: $ARCH"

if [ "$ARCH" = "aarch64" ]; then
    print_success "64-bit ARM architecture confirmed"
else
    print_error "Wrong architecture: Expected 'aarch64', got '$ARCH'"
    print_warning "This script requires 64-bit Raspberry Pi OS"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 3: Check Kernel Version
################################################################################

echo "Step 3: Verifying Kernel Version..."
echo "------------------------------------"

KERNEL=$(uname -r)
KERNEL_MAJOR=$(echo $KERNEL | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL | cut -d. -f2)

echo "  Kernel: $KERNEL"

if [ "$KERNEL_MAJOR" -ge 6 ] && [ "$KERNEL_MINOR" -ge 1 ]; then
    print_success "Kernel version is adequate (>= 6.1)"
else
    print_error "Kernel version too old: Need >= 6.1, got $KERNEL"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 4: Check Memory
################################################################################

echo "Step 4: Verifying Memory..."
echo "---------------------------"

TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
echo "  Total Memory: ${TOTAL_MEM} MB"

if [ "$TOTAL_MEM" -ge 7000 ]; then
    print_success "Memory is adequate for Device 0 (8GB model)"
elif [ "$TOTAL_MEM" -ge 3500 ]; then
    print_warning "Memory is 4GB - adequate but less than recommended 8GB"
elif [ "$TOTAL_MEM" -ge 400 ]; then
    print_warning "Memory is ${TOTAL_MEM}MB - This is low for Device 0 RPI 3 A+ config"
    print_warning "Expect potential performance issues and out of memory"
    print_warning "Consider using RPI 4/5 with at least 4GB for Device 0"
else
    print_error "Insufficient memory: Device 0 requires at least 4GB RAM"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 5: Check WiFi Interfaces
################################################################################

echo "Step 5: Verifying WiFi Interfaces..."
echo "-------------------------------------"

WLAN_COUNT=$(ip link show | grep -c "^[0-9]*: wlan")

echo "  WiFi interfaces found: $WLAN_COUNT"

if [ "$WLAN_COUNT" -ge 2 ]; then
    print_success "Found 2+ WiFi interfaces"
    echo ""
    echo "  Interface details:"
    for iface in $(ip link show | grep "^[0-9]*: wlan" | awk -F: '{print $2}' | tr -d ' '); do
        MAC=$(ip link show $iface | grep link/ether | awk '{print $2}')
        echo "    - $iface: $MAC"
    done
elif [ "$WLAN_COUNT" -eq 1 ]; then
    print_error "Only 1 WiFi interface found"
    print_warning "Device 0 requires:"
    print_warning "  - wlan0 (onboard) for BATMAN mesh"
    print_warning "  - wlan1 (USB adapter) for internet connection"
    print_warning "Please attach a USB WiFi adapter and reboot."
    ERRORS=$((ERRORS + 1))
else
    print_error "No WiFi interfaces found!"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 6: Create Persistent WiFi Interface Names (udev rules)
################################################################################

echo "Step 6: Creating Persistent WiFi Interface Names..."
echo "----------------------------------------------------"

if [ "$WLAN_COUNT" -ge 2 ]; then
    print_info "Configuring udev rules to lock interface names..."
    echo ""

    # Get interface details
    WLAN0_MAC=""
    WLAN1_MAC=""
    WLAN0_PATH=""
    WLAN1_PATH=""

    if ip link show wlan0 &>/dev/null; then
        WLAN0_MAC=$(cat /sys/class/net/wlan0/address)
        WLAN0_PATH=$(readlink -f /sys/class/net/wlan0)
    fi

    if ip link show wlan1 &>/dev/null; then
        WLAN1_MAC=$(cat /sys/class/net/wlan1/address)
        WLAN1_PATH=$(readlink -f /sys/class/net/wlan1)
    fi

    # Verify we have both MACs
    if [ -n "$WLAN0_MAC" ] && [ -n "$WLAN1_MAC" ]; then
        echo "  Current interfaces:"
        echo "    wlan0: $WLAN0_MAC"

        # Check if wlan0 is onboard (mmc/sdio)
        if echo "$WLAN0_PATH" | grep -q "mmc\|sdio"; then
            print_success "    └─ Onboard WiFi (correct for mesh network)"
        else
            print_warning "    └─ NOT onboard (may be USB adapter)"
        fi

        echo "    wlan1: $WLAN1_MAC"

        # Check if wlan1 is USB
        if echo "$WLAN1_PATH" | grep -q "usb"; then
            print_success "    └─ USB WiFi adapter (correct for internet)"
        else
            print_warning "    └─ NOT USB (may be onboard)"
        fi

        echo ""

        # Create udev rule
        UDEV_FILE="/etc/udev/rules.d/70-persistent-net.rules"

        print_info "Creating $UDEV_FILE"

        sudo tee "$UDEV_FILE" > /dev/null << EOF
# Field Trainer - Persistent WiFi Interface Names
# Created by phase1_hardware.sh on $(date)
#
# This ensures interfaces maintain consistent names:
#   wlan0 = Onboard WiFi (mesh network via batman-adv)
#   wlan1 = USB WiFi adapter (internet connection)

# Force onboard WiFi to wlan0 (for mesh network)
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$WLAN0_MAC", NAME="wlan0"

# Force USB WiFi to wlan1 (for internet)
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$WLAN1_MAC", NAME="wlan1"
EOF

        if [ $? -eq 0 ]; then
            print_success "udev rules created successfully"
            echo ""
            print_info "Rules will ensure:"
            echo "    • $WLAN0_MAC is ALWAYS wlan0 (mesh)"
            echo "    • $WLAN1_MAC is ALWAYS wlan1 (internet)"
            echo ""
            print_warning "A reboot is REQUIRED for udev rules to take effect"
            echo ""
        else
            print_error "Failed to create udev rules"
            ERRORS=$((ERRORS + 1))
        fi
    else
        print_error "Could not read MAC addresses from both interfaces"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_warning "Skipping udev rules (need 2 WiFi interfaces)"
fi

echo ""

################################################################################
# Step 7: Check batman-adv Module
################################################################################

echo "Step 7: Verifying batman-adv Support..."
echo "----------------------------------------"

if modinfo batman_adv &>/dev/null; then
    print_success "batman-adv module is available in kernel"
    
    # Check if already loaded
    if lsmod | grep -q batman_adv; then
        echo "  Module is currently loaded"
    else
        echo "  Module is available but not loaded (this is fine)"
    fi
else
    print_error "batman-adv module not found in kernel"
    print_warning "Trixie should have batman-adv pre-compiled in kernel"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 8: Test IBSS Support
################################################################################

echo "Step 8: Testing IBSS Support on wlan0..."
echo "-----------------------------------------"

if ip link show wlan0 &>/dev/null; then
    print_info "Testing IBSS (Ad-hoc) mode on wlan0..."
    
    # Check if interface is up
    if ip link show wlan0 | grep -q "state UP"; then
        print_info "Bringing wlan0 down for testing..."
        sudo ip link set wlan0 down
        sleep 1
    fi
    
    # Test IBSS mode
    if sudo iw dev wlan0 set type ibss 2>/dev/null; then
        print_success "wlan0 supports IBSS mode (required for BATMAN mesh)"
        
        # Set back to managed mode
        sudo iw dev wlan0 set type managed 2>/dev/null
    else
        print_error "wlan0 does NOT support IBSS mode"
        print_warning "IBSS support is REQUIRED for BATMAN mesh networking"
        print_warning "The onboard WiFi on RPi 5 should support IBSS"
        print_warning "Check if RF-kill is blocking: rfkill list"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_error "wlan0 interface not found - cannot test IBSS support"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 9: Enable Required Hardware Interfaces
################################################################################

echo "Step 9: Enabling Hardware Interfaces..."
echo "----------------------------------------"

print_info "Field Trainer requires SSH, I2C, and SPI interfaces"
echo ""

# Enable SSH
echo -n "  SSH... "
if raspi-config nonint get_ssh 2>/dev/null; then
    CURRENT_SSH=$(raspi-config nonint get_ssh)
    if [ "$CURRENT_SSH" = "0" ]; then
        print_info "already enabled"
    else
        print_info "enabling..."
        if sudo raspi-config nonint do_ssh 0; then
            print_success "enabled"
        else
            print_error "failed to enable"
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    print_warning "cannot detect status (will attempt to enable)"
    sudo raspi-config nonint do_ssh 0 2>/dev/null && print_success "enabled" || print_warning "enable failed"
fi

# Enable I2C (for MPU6500 touch sensor)
echo -n "  I2C... "
if raspi-config nonint get_i2c 2>/dev/null; then
    CURRENT_I2C=$(raspi-config nonint get_i2c)
    if [ "$CURRENT_I2C" = "0" ]; then
        print_info "already enabled"
    else
        print_info "enabling..."
        if sudo raspi-config nonint do_i2c 0; then
            print_success "enabled"
        else
            print_error "failed to enable"
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    print_warning "cannot detect status (will attempt to enable)"
    sudo raspi-config nonint do_i2c 0 2>/dev/null && print_success "enabled" || print_warning "enable failed"
fi

# Enable SPI (for WS2812B LEDs via rpi-ws281x)
echo -n "  SPI... "
if raspi-config nonint get_spi 2>/dev/null; then
    CURRENT_SPI=$(raspi-config nonint get_spi)
    if [ "$CURRENT_SPI" = "0" ]; then
        print_info "already enabled"
    else
        print_info "enabling..."
        if sudo raspi-config nonint do_spi 0; then
            print_success "enabled"
        else
            print_error "failed to enable"
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    print_warning "cannot detect status (will attempt to enable)"
    sudo raspi-config nonint do_spi 0 2>/dev/null && print_success "enabled" || print_warning "enable failed"
fi

echo ""
print_info "Hardware interface status:"
echo "  • SSH: Required for remote access"
echo "  • I2C: Required for MPU6500 touch sensor (addresses: 0x68, 0x69, 0x71, 0x73)"
echo "  • SPI: Required for WS2812B LEDs (GPIO18 via rpi-ws281x)"
echo ""
print_warning "Note: A reboot may be required for I2C/SPI changes to take effect"

echo ""

################################################################################
# Summary
################################################################################

echo "==============================="
echo "Verification Summary"
echo "==============================="
echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "All hardware checks passed!"
    echo ""
    print_info "Your system meets all requirements for Device 0."
    echo ""
    print_info "Hardware interfaces configured:"
    echo "  ✓ SSH enabled (for remote access)"
    echo "  ✓ I2C enabled (for touch sensor)"
    echo "  ✓ SPI enabled (for LED control)"
    echo "  ✓ WiFi interface names locked (wlan0=mesh, wlan1=internet)"
    echo ""
    print_warning "IMPORTANT: Reboot required for WiFi udev rules to take effect"
    echo ""
    read -p "Reboot now? (y/n): " do_reboot
    if [[ $do_reboot =~ ^[Yy]$ ]]; then
        print_info "Rebooting in 5 seconds..."
        sleep 5
        sudo reboot
    else
        print_warning "Please reboot manually before continuing to Phase 2"
        print_info "Run: sudo reboot"
    fi
    echo ""
    exit 0
else
    print_error "Found $ERRORS error(s) during verification"
    echo ""
    print_warning "Please resolve the issues above before continuing."
    print_warning "Common solutions:"
    echo "  • Wrong OS: Flash Raspberry Pi OS Trixie (64-bit) to SD card"
    echo "  • Missing wlan1: Attach USB WiFi adapter and reboot"
    echo "  • IBSS failure: Check 'rfkill list' and 'rfkill unblock wifi'"
    echo ""
    exit 1
fi
