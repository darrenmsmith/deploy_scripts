#!/bin/bash

################################################################################
# Field Trainer - Client Phase 1: Hardware Verification
# For Raspberry Pi Zero W (Devices 1-5)
# - Verify Pi Zero W hardware
# - Enable I2C (touch sensor)
# - Enable SPI (LED strip)
# - Test hardware components
# - Record MAC address
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

log_start "Client Phase 1: Hardware Verification"

################################################################################
# Step 1: Detect Device Number
################################################################################

log_step "Detecting device number from hostname"

HOSTNAME=$(hostname)
if [[ $HOSTNAME =~ Device([1-5]) ]]; then
    DEVICE_NUM="${BASH_REMATCH[1]}"
    log_success "Device number: $DEVICE_NUM"
    log_info "IP will be: 192.168.99.10${DEVICE_NUM}"
else
    log_error "Hostname must be Device1, Device2, Device3, Device4, or Device5"
    log_error "Current hostname: $HOSTNAME"
    exit 1
fi

################################################################################
# Step 2: Verify Pi Zero W Hardware
################################################################################

log_step "Verifying Raspberry Pi Zero W hardware"

# Check CPU
CPU_MODEL=$(cat /proc/cpuinfo | grep "Model" | head -1)
if echo "$CPU_MODEL" | grep -iq "Zero"; then
    log_success "Raspberry Pi Zero detected"
else
    log_warning "Not a Pi Zero - this may not work correctly"
    log_info "Detected: $CPU_MODEL"
fi

# Check RAM (Pi Zero W has 512MB)
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))

if [ $TOTAL_RAM_MB -lt 600 ]; then
    log_success "RAM: ${TOTAL_RAM_MB}MB (Pi Zero W = 512MB)"
else
    log_warning "RAM: ${TOTAL_RAM_MB}MB (expected ~512MB for Pi Zero W)"
fi

# Check WiFi
if ip link show wlan0 &>/dev/null; then
    WLAN0_MAC=$(cat /sys/class/net/wlan0/address)
    log_success "WiFi interface wlan0 found: $WLAN0_MAC"
else
    log_error "No WiFi interface found"
    exit 1
fi

################################################################################
# Step 3: Enable I2C (for touch sensor)
################################################################################

log_step "Enabling I2C for touch sensor"

if grep -q "^dtparam=i2c_arm=on" /boot/firmware/config.txt; then
    log_info "I2C already enabled in config.txt"
else
    echo "dtparam=i2c_arm=on" | sudo tee -a /boot/firmware/config.txt > /dev/null
    log_success "I2C enabled in config.txt"
fi

# Enable I2C kernel module
sudo modprobe i2c-dev
if lsmod | grep -q i2c_dev; then
    log_success "I2C kernel module loaded"
else
    log_error "Failed to load I2C module"
    exit 1
fi

# Add to /etc/modules for persistence
if ! grep -q "^i2c-dev" /etc/modules; then
    echo "i2c-dev" | sudo tee -a /etc/modules > /dev/null
    log_success "I2C module added to /etc/modules"
fi

################################################################################
# Step 4: Enable SPI (for LED strip)
################################################################################

log_step "Enabling SPI for LED strip"

if grep -q "^dtparam=spi=on" /boot/firmware/config.txt; then
    log_info "SPI already enabled in config.txt"
else
    echo "dtparam=spi=on" | sudo tee -a /boot/firmware/config.txt > /dev/null
    log_success "SPI enabled in config.txt"
fi

# Enable SPI kernel module
sudo modprobe spi_bcm2835
if lsmod | grep -q spi_bcm2835; then
    log_success "SPI kernel module loaded"
else
    log_warning "SPI module not loaded (may need reboot)"
fi

################################################################################
# Step 5: Test Touch Sensor (MPU6050)
################################################################################

log_step "Testing for touch sensor (MPU6050 accelerometer)"

# Install i2c-tools if not present
if ! command -v i2cdetect &> /dev/null; then
    log_info "Installing i2c-tools..."
    sudo apt-get update -qq
    sudo apt-get install -y i2c-tools
fi

# Scan I2C bus for MPU6050 (address 0x68 or 0x69)
I2C_DEVICES=$(sudo i2cdetect -y 1 2>/dev/null)

if echo "$I2C_DEVICES" | grep -q " 68 "; then
    log_success "Touch sensor detected at I2C address 0x68"
    TOUCH_SENSOR_FOUND=true
elif echo "$I2C_DEVICES" | grep -q " 69 "; then
    log_success "Touch sensor detected at I2C address 0x69"
    TOUCH_SENSOR_FOUND=true
else
    log_warning "Touch sensor NOT detected on I2C bus"
    log_info "Continuing anyway - sensor may not be connected yet"
    TOUCH_SENSOR_FOUND=false
fi

################################################################################
# Step 6: Test LED Strip (GPIO12)
################################################################################

log_step "Checking LED strip GPIO configuration"

# GPIO12 (PWM0) is used for WS2812B LED strip
# We can't fully test without rpi_ws281x library, but we can check GPIO exists

if [ -d "/sys/class/gpio" ]; then
    log_success "GPIO system available"
    log_info "LED strip will use GPIO12 (PWM0)"
    log_info "LED library (rpi_ws281x) will be installed in Phase 3"
else
    log_error "GPIO system not available"
    exit 1
fi

################################################################################
# Step 7: Test Audio Output
################################################################################

log_step "Testing audio output"

if aplay -l 2>/dev/null | grep -q "card"; then
    AUDIO_DEVICE=$(aplay -l 2>/dev/null | grep "card" | head -1)
    log_success "Audio device found"
    log_info "$AUDIO_DEVICE"
else
    log_warning "No audio device detected"
    log_info "Audio output may not work"
fi

################################################################################
# Step 8: Record MAC Address
################################################################################

log_step "Recording device MAC address"

MAC_FILE="/mnt/usb/ft_usb_build/device_macs.txt"

# Create file if it doesn't exist
if [ ! -f "$MAC_FILE" ]; then
    echo "# Field Trainer Device MAC Addresses" > "$MAC_FILE"
    echo "# Format: DeviceN: MAC_ADDRESS" >> "$MAC_FILE"
    echo "" >> "$MAC_FILE"
fi

# Check if this device is already recorded
if grep -q "^Device${DEVICE_NUM}:" "$MAC_FILE" 2>/dev/null; then
    EXISTING_MAC=$(grep "^Device${DEVICE_NUM}:" "$MAC_FILE" | awk '{print $2}')
    if [ "$EXISTING_MAC" == "$WLAN0_MAC" ]; then
        log_info "MAC address already recorded: $WLAN0_MAC"
    else
        log_warning "MAC address changed from $EXISTING_MAC to $WLAN0_MAC"
        # Update the entry
        sed -i "/^Device${DEVICE_NUM}:/d" "$MAC_FILE"
        echo "Device${DEVICE_NUM}: $WLAN0_MAC" >> "$MAC_FILE"
        log_success "MAC address updated in $MAC_FILE"
    fi
else
    echo "Device${DEVICE_NUM}: $WLAN0_MAC" >> "$MAC_FILE"
    log_success "MAC address recorded: $WLAN0_MAC"
    log_info "Saved to: $MAC_FILE"
fi

################################################################################
# Summary
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Hardware Verification Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Device Number: ${DEVICE_NUM}"
echo "  Device IP: 192.168.99.10${DEVICE_NUM}"
echo "  MAC Address: $WLAN0_MAC"
echo "  RAM: ${TOTAL_RAM_MB}MB"
echo ""
echo "  Hardware Status:"
echo "    ✓ WiFi (wlan0) available"
echo "    ✓ I2C enabled (for touch sensor)"
echo "    ✓ SPI enabled (for LED strip)"
if [ "$TOUCH_SENSOR_FOUND" == "true" ]; then
    echo "    ✓ Touch sensor detected on I2C"
else
    echo "    ⚠ Touch sensor not detected (install before Phase 5)"
fi
echo "    ✓ GPIO available for LED control"
if aplay -l 2>/dev/null | grep -q "card"; then
    echo "    ✓ Audio output detected"
else
    echo "    ⚠ Audio output not detected"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_success "Phase 1 complete!"

echo ""
echo "IMPORTANT: Register this device on Device0 web interface"
echo "  1. Go to http://192.168.99.100:5000/settings"
echo "  2. Find 'Device Whitelisting' section"
echo "  3. Add MAC address: $WLAN0_MAC for Device${DEVICE_NUM}"
echo ""
echo "NOTE: A reboot is recommended for I2C/SPI changes to take full effect"
read -p "Reboot now? (y/n): " DO_REBOOT

if [[ "$DO_REBOOT" =~ ^[Yy]$ ]]; then
    log_info "Rebooting in 5 seconds..."
    sleep 5
    sudo reboot
else
    echo ""
    echo "Reboot skipped. Remember to reboot before Phase 2"
    echo ""
fi

log_end "Client Phase 1 complete"
exit 0
