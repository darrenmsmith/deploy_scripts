#!/bin/bash

################################################################################
# Sensor Verification Script
# Run this AFTER Phase 3 to verify hardware sensors are working
# For both Device0 (gateway) and client devices (Device1-5)
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
WARNINGS=0

echo "════════════════════════════════════════════════════════════"
echo "  Field Trainer - Hardware Sensor Verification"
echo "  Device: $(hostname)"
echo "  Date: $(date)"
echo "════════════════════════════════════════════════════════════"
echo ""

################################################################################
# 1. Check i2c-tools Installed
################################################################################

echo "1. Checking i2c-tools Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v i2cdetect &> /dev/null; then
    I2CDETECT_PATH=$(which i2cdetect)
    print_success "i2cdetect found at: $I2CDETECT_PATH"
else
    print_error "i2cdetect NOT FOUND"
    print_info "Installing i2c-tools..."
    sudo apt-get update -qq
    sudo apt-get install -y i2c-tools

    if command -v i2cdetect &> /dev/null; then
        print_success "i2c-tools installed successfully"
    else
        print_error "Failed to install i2c-tools"
        ERRORS=$((ERRORS + 1))
    fi
fi

echo ""

################################################################################
# 2. Check I2C Enabled in Config
################################################################################

echo "2. Checking I2C Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if grep -q "^dtparam=i2c_arm=on" /boot/firmware/config.txt 2>/dev/null; then
    print_success "I2C enabled in /boot/firmware/config.txt"
elif grep -q "^dtparam=i2c_arm=on" /boot/config.txt 2>/dev/null; then
    print_success "I2C enabled in /boot/config.txt"
else
    print_error "I2C NOT enabled in config.txt"
    print_info "To enable:"
    echo "  echo 'dtparam=i2c_arm=on' | sudo tee -a /boot/firmware/config.txt"
    echo "  sudo reboot"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# 3. Check I2C Kernel Module
################################################################################

echo "3. Checking I2C Kernel Module"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if lsmod | grep -q i2c_dev; then
    print_success "i2c_dev kernel module loaded"
else
    print_warning "i2c_dev module not loaded"
    print_info "Loading module..."
    sudo modprobe i2c-dev

    if lsmod | grep -q i2c_dev; then
        print_success "Module loaded successfully"

        # Add to /etc/modules for persistence
        if ! grep -q "^i2c-dev" /etc/modules; then
            echo "i2c-dev" | sudo tee -a /etc/modules > /dev/null
            print_success "Added to /etc/modules for auto-load on boot"
        fi
    else
        print_error "Failed to load i2c_dev module"
        ERRORS=$((ERRORS + 1))
    fi
fi

echo ""

################################################################################
# 4. Check I2C Devices
################################################################################

echo "4. Checking I2C Device Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

I2C_DEVICES=$(ls /dev/i2c-* 2>/dev/null)

if [ -n "$I2C_DEVICES" ]; then
    print_success "I2C device files found:"
    for dev in $I2C_DEVICES; do
        echo "  • $dev"
    done
else
    print_error "NO I2C device files found in /dev/"
    print_warning "I2C may not be properly enabled - reboot may be required"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# 5. Check User Permissions
################################################################################

echo "5. Checking User Permissions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if groups | grep -q i2c; then
    print_success "User '$(whoami)' is in i2c group"
else
    print_warning "User '$(whoami)' NOT in i2c group"
    print_info "Adding to i2c group..."
    sudo usermod -a -G i2c $(whoami)
    print_success "Added to i2c group (logout/login required for effect)"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

################################################################################
# 6. Scan I2C Buses for Sensors
################################################################################

echo "6. Scanning I2C Buses for Sensors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Exit early if no I2C devices
if [ ! -e "/dev/i2c-1" ]; then
    print_error "Cannot scan - /dev/i2c-1 does not exist"
    print_warning "Reboot required after enabling I2C in config.txt"
    ERRORS=$((ERRORS + 1))
else
    print_info "Scanning I2C bus 1 for devices..."
    echo ""

    I2C_SCAN=$(sudo i2cdetect -y 1 2>&1)
    echo "$I2C_SCAN"
    echo ""

    # Check for MPU6050/MPU6500/MPU9250 sensor (address 0x68 or 0x69)
    if echo "$I2C_SCAN" | grep -q " 68 "; then
        print_success "MPU sensor detected at address 0x68"
        SENSOR_FOUND=true
        SENSOR_ADDRESS="0x68"
    elif echo "$I2C_SCAN" | grep -q " 69 "; then
        print_success "MPU sensor detected at address 0x69"
        SENSOR_FOUND=true
        SENSOR_ADDRESS="0x69"
    else
        print_warning "MPU sensor NOT detected on I2C bus 1"
        print_info "This could mean:"
        echo "  • Sensor not physically connected"
        echo "  • Wrong wiring (check SDA/SCL connections)"
        echo "  • Sensor on different I2C bus"
        echo "  • Sensor address conflict"
        SENSOR_FOUND=false
        WARNINGS=$((WARNINGS + 1))
    fi

    echo ""

    # Check for other devices
    DEVICE_COUNT=$(echo "$I2C_SCAN" | grep -oE " [0-9a-f]{2} " | wc -l)
    if [ $DEVICE_COUNT -gt 0 ]; then
        print_info "Total I2C devices found: $DEVICE_COUNT"
    else
        print_warning "No I2C devices detected on any address"
    fi
fi

echo ""

################################################################################
# 7. Test Sensor Communication (if found)
################################################################################

if [ "$SENSOR_FOUND" = true ]; then
    echo "7. Testing Sensor Communication"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    print_info "Reading WHO_AM_I register (0x75) from sensor..."

    WHO_AM_I=$(sudo i2cget -y 1 $SENSOR_ADDRESS 0x75 2>/dev/null)

    if [ $? -eq 0 ]; then
        print_success "Successfully read register: $WHO_AM_I"

        # MPU WHO_AM_I values: 0x68 (MPU6050), 0x70 (MPU6500), 0x71 (MPU9250)
        if [ "$WHO_AM_I" = "0x68" ]; then
            print_success "Sensor chip ID confirmed: MPU6050"
        elif [ "$WHO_AM_I" = "0x70" ]; then
            print_success "Sensor chip ID confirmed: MPU6500"
        elif [ "$WHO_AM_I" = "0x71" ]; then
            print_success "Sensor chip ID confirmed: MPU9250"
        else
            print_warning "Unexpected chip ID: $WHO_AM_I"
            print_info "Expected: 0x68 (MPU6050), 0x70 (MPU6500), or 0x71 (MPU9250)"
        fi
    else
        print_error "Failed to read from sensor"
        print_info "Sensor detected but communication failed"
        ERRORS=$((ERRORS + 1))
    fi

    echo ""
fi

################################################################################
# 8. Test Python I2C Library
################################################################################

echo "8. Testing Python I2C Library"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

print_info "Checking smbus2 (universal I2C library)..."

if python3 -c "import smbus2" 2>/dev/null; then
    print_success "Python smbus2 library installed (works with all MPU sensors)"

    if [ "$SENSOR_FOUND" = true ]; then
        print_info "Testing sensor data acquisition..."
        echo ""

        # Try to read sensor data using smbus2
        SENSOR_TEST=$(python3 << EOF 2>&1
try:
    import smbus2
    import struct
    import time

    # Convert hex address to integer
    SENSOR_ADDR = int("$SENSOR_ADDRESS", 16)

    # Initialize I2C
    bus = smbus2.SMBus(1)

    # Wake up MPU (write 0 to PWR_MGMT_1 register 0x6B)
    bus.write_byte_data(SENSOR_ADDR, 0x6B, 0x00)
    time.sleep(0.1)

    # Read accelerometer (registers 0x3B-0x40, 6 bytes)
    accel_data = bus.read_i2c_block_data(SENSOR_ADDR, 0x3B, 6)
    accel_x = struct.unpack('>h', bytes(accel_data[0:2]))[0] / 16384.0
    accel_y = struct.unpack('>h', bytes(accel_data[2:4]))[0] / 16384.0
    accel_z = struct.unpack('>h', bytes(accel_data[4:6]))[0] / 16384.0

    # Read gyroscope (registers 0x43-0x48, 6 bytes)
    gyro_data = bus.read_i2c_block_data(SENSOR_ADDR, 0x43, 6)
    gyro_x = struct.unpack('>h', bytes(gyro_data[0:2]))[0] / 131.0
    gyro_y = struct.unpack('>h', bytes(gyro_data[2:4]))[0] / 131.0
    gyro_z = struct.unpack('>h', bytes(gyro_data[4:6]))[0] / 131.0

    # Read temperature (registers 0x41-0x42, 2 bytes)
    temp_data = bus.read_i2c_block_data(SENSOR_ADDR, 0x41, 2)
    temp_raw = struct.unpack('>h', bytes(temp_data))[0]
    temp_c = (temp_raw / 340.0) + 36.53

    bus.close()

    print(f"SUCCESS")
    print(f"Acceleration: X={accel_x:.2f}g, Y={accel_y:.2f}g, Z={accel_z:.2f}g")
    print(f"Gyroscope: X={gyro_x:.2f}°/s, Y={gyro_y:.2f}°/s, Z={gyro_z:.2f}°/s")
    print(f"Temperature: {temp_c:.2f}°C")
except Exception as e:
    print(f"ERROR: {e}")
EOF
)

        if echo "$SENSOR_TEST" | grep -q "SUCCESS"; then
            print_success "Sensor data acquisition working!"
            echo ""
            echo "$SENSOR_TEST" | grep -v "SUCCESS" | sed 's/^/  /'
        else
            print_error "Failed to acquire sensor data"
            echo ""
            echo "$SENSOR_TEST" | sed 's/^/  /'
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    print_warning "Python smbus2 library NOT installed"
    print_info "Installing library..."

    sudo pip3 install --break-system-packages smbus2 2>&1 | grep -v "Requirement already satisfied" | head -5

    if python3 -c "import smbus2" 2>/dev/null; then
        print_success "Library installed successfully"
    else
        print_error "Failed to install Python library"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

echo ""

################################################################################
# Summary
################################################################################

echo "════════════════════════════════════════════════════════════"
echo "  Verification Summary"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "Status:"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    print_success "All checks passed - sensor system ready!"
elif [ $ERRORS -eq 0 ]; then
    print_warning "$WARNINGS warning(s) - sensor may work with limitations"
else
    print_error "$ERRORS error(s), $WARNINGS warning(s) - sensor NOT ready"
fi

echo ""
echo "Hardware Status:"
if [ "$SENSOR_FOUND" = true ]; then
    print_success "MPU sensor detected and communicating"
else
    print_warning "MPU sensor not detected - check physical connection"
fi

echo ""
echo "Next Steps:"
if [ $ERRORS -gt 0 ]; then
    echo "  1. Review errors above and fix issues"
    echo "  2. If I2C not enabled: edit /boot/firmware/config.txt and reboot"
    echo "  3. Check sensor wiring: VCC→3.3V, GND→GND, SDA→GPIO2, SCL→GPIO3"
    echo "  4. Re-run this script after fixes"
else
    echo "  1. Sensor verification complete"
    echo "  2. Continue with next phase (Phase 4 or later)"
    echo "  3. Sensor will be available to Field Trainer application"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""

# Exit with error code if there are errors
if [ $ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
