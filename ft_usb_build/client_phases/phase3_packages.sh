#!/bin/bash

################################################################################
# Field Trainer - Client Phase 3: Package Installation
# Install packages needed for mesh networking and client hardware
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

log_start "Client Phase 3: Package Installation"

################################################################################
# Step 1: Verify Internet Connection
################################################################################

log_step "Verifying internet connection"

if ! ping -c 2 -W 5 8.8.8.8 &>/dev/null; then
    log_error "No internet connection"
    log_info "Please run Phase 2 first to establish internet connection"
    exit 1
fi

log_success "Internet connection verified"

################################################################################
# Step 2: Update Package Lists
################################################################################

log_step "Updating package lists"

sudo apt-get update

if [ $? -eq 0 ]; then
    log_success "Package lists updated"
else
    log_error "Failed to update package lists"
    exit 1
fi

################################################################################
# Step 3: Install BATMAN-adv and Networking Tools
################################################################################

log_step "Installing BATMAN-adv mesh networking"

sudo apt-get install -y batctl wpasupplicant wireless-tools iw

if [ $? -eq 0 ]; then
    log_success "BATMAN-adv and networking tools installed"
else
    log_error "Failed to install mesh networking packages"
    exit 1
fi

################################################################################
# Step 3.5: Install I2C Tools (for touch sensor)
################################################################################

log_step "Installing I2C tools for touch sensor"

sudo apt-get install -y i2c-tools

if [ $? -eq 0 ]; then
    log_success "i2c-tools installed"
else
    log_error "Failed to install i2c-tools"
    exit 1
fi

# Load batman-adv kernel module
log_info "Loading batman-adv kernel module..."
sudo modprobe batman-adv

if lsmod | grep -q batman; then
    log_success "batman-adv module loaded"
else
    log_error "Failed to load batman-adv module"
    exit 1
fi

# Add to /etc/modules for persistence
if ! grep -q "^batman-adv" /etc/modules; then
    echo "batman-adv" | sudo tee -a /etc/modules > /dev/null
    log_success "batman-adv added to /etc/modules"
fi

################################################################################
# Step 4: Install Python and Development Tools
################################################################################

log_step "Installing Python and development tools"

sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-setuptools \
    git

if [ $? -eq 0 ]; then
    log_success "Python and development tools installed"
else
    log_error "Failed to install Python packages"
    exit 1
fi

################################################################################
# Step 5: Install Python Libraries for Hardware
################################################################################

log_step "Installing Python libraries for LED, touch sensor, and audio"

# Install LED strip library (rpi_ws281x)
log_info "Installing LED strip library (rpi_ws281x)..."
sudo pip3 install --break-system-packages rpi_ws281x

if [ $? -eq 0 ]; then
    log_success "rpi_ws281x installed"
else
    log_warning "rpi_ws281x installation failed (may need to build from source)"
fi

# Install touch sensor library (smbus2 - works with all MPU sensors)
log_info "Installing I2C sensor library (smbus2 for MPU6500/MPU9250)..."
sudo pip3 install --break-system-packages smbus2

if [ $? -eq 0 ]; then
    log_success "smbus2 library installed (supports MPU6050/MPU6500/MPU9250)"
else
    log_warning "smbus2 library installation failed"
fi

# Install audio library (pygame for audio playback)
log_info "Installing audio library (pygame)..."
sudo apt-get install -y python3-pygame

if [ $? -eq 0 ]; then
    log_success "pygame installed"
else
    log_warning "pygame installation failed"
fi

################################################################################
# Step 6: Install Additional Dependencies
################################################################################

log_step "Installing additional dependencies"

sudo apt-get install -y \
    alsa-utils \
    sox \
    libsox-fmt-mp3

if [ $? -eq 0 ]; then
    log_success "Audio utilities installed"
else
    log_warning "Some audio utilities may have failed"
fi

################################################################################
# Step 7: Disconnect USB WiFi (Temporary Internet)
################################################################################

log_step "Disconnecting temporary internet connection"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Package installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The USB WiFi adapter is no longer needed."
echo "It will be disconnected and you can remove it."
echo ""

read -p "Disconnect USB WiFi now? (y/n): " DISCONNECT

if [[ "$DISCONNECT" =~ ^[Yy]$ ]]; then
    log_info "Stopping wpa_supplicant on wlan1..."
    sudo killall wpa_supplicant 2>/dev/null || true

    log_info "Releasing DHCP lease on wlan1..."
    sudo dhcpcd -k wlan1 2>/dev/null || true

    log_info "Bringing down wlan1..."
    sudo ip link set wlan1 down 2>/dev/null || true

    log_success "USB WiFi disconnected"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "YOU CAN NOW REMOVE THE USB WIFI ADAPTER"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

################################################################################
# Summary
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Package Installation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Installed:"
echo "    ✓ BATMAN-adv mesh networking"
echo "    ✓ I2C tools (i2cdetect, i2cget, i2cset)"
echo "    ✓ Python 3 and development tools"
echo "    ✓ LED strip library (rpi_ws281x)"
echo "    ✓ Touch sensor library (smbus2 for MPU6500/MPU9250)"
echo "    ✓ Audio libraries (pygame, sox)"
echo "    ✓ Wireless tools (iw, wpa_supplicant)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_success "Phase 3 complete!"

echo ""
echo "Ready for Phase 4: Mesh Network Join"
echo ""

log_end "Client Phase 3 complete"
exit 0
