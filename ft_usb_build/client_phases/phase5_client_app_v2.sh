#!/bin/bash

################################################################################
# Field Trainer - Client Phase 5: Client Application Deployment
# Download client software from Device0 and configure services
# Version 2: Better sudo handling
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

log_start "Client Phase 5: Client Application Deployment"

################################################################################
# Step 1: Get Device Number
################################################################################

HOSTNAME=$(hostname)
if [[ $HOSTNAME =~ Device([1-5]) ]]; then
    DEVICE_NUM="${BASH_REMATCH[1]}"
    DEVICE_IP="192.168.99.10${DEVICE_NUM}"
    NODE_ID="$DEVICE_IP"
    log_info "Device: Device${DEVICE_NUM}"
    log_info "Node ID: $NODE_ID"
else
    log_error "Invalid hostname: $HOSTNAME"
    exit 1
fi

################################################################################
# Step 2: Test Connection to Device0
################################################################################

log_step "Testing connection to Device0 (192.168.99.100)"

DEVICE0_IP="192.168.99.100"

if ping -c 3 -W 5 $DEVICE0_IP &>/dev/null; then
    log_success "Can reach Device0"
else
    log_error "Cannot reach Device0"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify Device0 is powered on"
    echo "  2. Check Device0 mesh network is active:"
    echo "     ssh pi@192.168.99.100"
    echo "     sudo systemctl status batman-mesh"
    echo "  3. Check mesh neighbors: sudo batctl n"
    echo ""
    exit 1
fi

################################################################################
# Step 3: Test SSH Access to Device0
################################################################################

log_step "Testing SSH access to Device0"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SSH Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This script will download files from Device0 using SCP"
echo "You will need the password for pi@192.168.99.100"
echo ""
echo "NOTE: For future builds, consider setting up SSH keys"
echo ""

# Test SSH connection
if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no pi@$DEVICE0_IP "echo SSH OK" &>/dev/null; then
    log_success "SSH connection successful"
else
    log_warning "SSH connection test failed"
    log_info "You may need to enter password during file transfer"
fi

################################################################################
# Step 4: Download Files from Device0 (NO SUDO YET)
################################################################################

log_step "Downloading files from Device0"

# Create temp directories (no sudo needed)
mkdir -p /tmp/ft_download/field_trainer/audio/male 2>/dev/null
mkdir -p /tmp/ft_download/field_trainer/audio/female 2>/dev/null

# Download field_client_connection.py
log_info "Downloading field_client_connection.py..."
scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_client_connection.py /tmp/ft_download/field_client_connection.py

if [ $? -eq 0 ] && [ -f /tmp/ft_download/field_client_connection.py ]; then
    log_success "field_client_connection.py downloaded ($(stat -c%s /tmp/ft_download/field_client_connection.py) bytes)"
else
    log_error "Failed to download field_client_connection.py"
    exit 1
fi

# Download audio_manager.py
log_info "Downloading audio_manager.py..."
scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/audio_manager.py /tmp/ft_download/audio_manager.py 2>/dev/null
if [ -f /tmp/ft_download/audio_manager.py ]; then
    log_success "audio_manager.py downloaded"
else
    log_warning "audio_manager.py not found (may not be needed)"
fi

# Download ft_touch.py
log_info "Downloading ft_touch.py..."
scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/ft_touch.py /tmp/ft_download/field_trainer/ft_touch.py

if [ $? -eq 0 ] && [ -f /tmp/ft_download/field_trainer/ft_touch.py ]; then
    log_success "ft_touch.py downloaded"
else
    log_error "Failed to download ft_touch.py"
    exit 1
fi

# Download ft_led.py
log_info "Downloading ft_led.py..."
scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/ft_led.py /tmp/ft_download/field_trainer/ft_led.py 2>/dev/null
if [ -f /tmp/ft_download/field_trainer/ft_led.py ]; then
    log_success "ft_led.py downloaded"
else
    log_warning "ft_led.py not found"
fi

# Download ft_audio.py
log_info "Downloading ft_audio.py..."
scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/ft_audio.py /tmp/ft_download/field_trainer/ft_audio.py 2>/dev/null
if [ -f /tmp/ft_download/field_trainer/ft_audio.py ]; then
    log_success "ft_audio.py downloaded"
else
    log_warning "ft_audio.py not found"
fi

# Download audio files
echo ""
log_info "Downloading male voice audio files (this may take a minute)..."
scp -r -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/audio/male/* /tmp/ft_download/field_trainer/audio/male/ 2>/dev/null
MALE_COUNT=$(ls -1 /tmp/ft_download/field_trainer/audio/male/*.mp3 2>/dev/null | wc -l)
if [ $MALE_COUNT -gt 0 ]; then
    log_success "Male audio files downloaded ($MALE_COUNT files)"
else
    log_warning "Male audio files not downloaded"
fi

log_info "Downloading female voice audio files..."
scp -r -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/audio/female/* /tmp/ft_download/field_trainer/audio/female/ 2>/dev/null
FEMALE_COUNT=$(ls -1 /tmp/ft_download/field_trainer/audio/female/*.mp3 2>/dev/null | wc -l)
if [ $FEMALE_COUNT -gt 0 ]; then
    log_success "Female audio files downloaded ($FEMALE_COUNT files)"
else
    log_warning "Female audio files not downloaded"
fi

log_success "All files downloaded to /tmp/ft_download/"

################################################################################
# Step 5: SINGLE SUDO BLOCK - Install Everything at Once
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Sudo Access Required"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This script now needs ONE-TIME sudo access to:"
echo "  • Create /opt directories"
echo "  • Install downloaded files"
echo "  • Set permissions"
echo "  • Create systemd service"
echo "  • Enable and start service"
echo ""
echo "You will be prompted for your password ONCE."
echo "All installation steps will run together in a single sudo session."
echo ""
read -p "Press Enter to continue..."
echo ""

log_step "Installing files (this runs as one sudo command block)"

# Run ALL sudo operations in a single sudo bash session
sudo bash << 'SUDO_SCRIPT'
set -e  # Exit on any error

echo "Creating directories..."
mkdir -p /opt/field_trainer/audio/male
mkdir -p /opt/field_trainer/audio/female

echo "Installing main application..."
cp /tmp/ft_download/field_client_connection.py /opt/field_client_connection.py
chmod +x /opt/field_client_connection.py

echo "Installing support libraries..."
if [ -f /tmp/ft_download/audio_manager.py ]; then
    cp /tmp/ft_download/audio_manager.py /opt/audio_manager.py
fi

cp /tmp/ft_download/field_trainer/ft_touch.py /opt/field_trainer/ft_touch.py

if [ -f /tmp/ft_download/field_trainer/ft_led.py ]; then
    cp /tmp/ft_download/field_trainer/ft_led.py /opt/field_trainer/ft_led.py
fi

if [ -f /tmp/ft_download/field_trainer/ft_audio.py ]; then
    cp /tmp/ft_download/field_trainer/ft_audio.py /opt/field_trainer/ft_audio.py
fi

echo "Installing audio files..."
if [ -d /tmp/ft_download/field_trainer/audio/male ]; then
    cp -r /tmp/ft_download/field_trainer/audio/male/* /opt/field_trainer/audio/male/ 2>/dev/null || true
fi

if [ -d /tmp/ft_download/field_trainer/audio/female ]; then
    cp -r /tmp/ft_download/field_trainer/audio/female/* /opt/field_trainer/audio/female/ 2>/dev/null || true
fi

echo "Setting permissions..."
chown -R pi:pi /opt/field_trainer
chmod -R 755 /opt/field_trainer

echo "✓ All files installed successfully"
SUDO_SCRIPT

if [ $? -eq 0 ]; then
    log_success "All files installed successfully"
else
    log_error "Installation failed"
    exit 1
fi

################################################################################
# Step 6: Create and Start Service (Separate sudo for clarity)
################################################################################

log_step "Creating systemd service"

sudo tee /etc/systemd/system/field-client.service > /dev/null << EOF
[Unit]
Description=Field Trainer Client (Device${DEVICE_NUM})
After=network.target batman-mesh-client.service
Requires=batman-mesh-client.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt
ExecStart=/usr/bin/python3 /opt/field_client_connection.py --node-id=${NODE_ID}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

log_success "Systemd service created"

log_step "Enabling and starting service"

sudo bash << 'SUDO_SCRIPT2'
systemctl daemon-reload
systemctl enable field-client.service
systemctl start field-client.service
SUDO_SCRIPT2

sleep 3

# Check status
if sudo systemctl is-active --quiet field-client.service; then
    log_success "Field client service is running!"
else
    log_error "Service failed to start"
    echo ""
    echo "Check logs with: sudo journalctl -u field-client -n 50"
    echo ""
fi

################################################################################
# Summary
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Client Application Deployment Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Device: Device${DEVICE_NUM}"
echo "  Node ID: $NODE_ID"
echo "  IP Address: $DEVICE_IP"
echo ""
echo "  Files Installed:"
echo "    ✓ /opt/field_client_connection.py"
echo "    ✓ /opt/field_trainer/ft_touch.py"
echo "    ✓ /opt/field_trainer/ft_led.py (optional)"
echo "    ✓ /opt/field_trainer/ft_audio.py (optional)"
echo "    ✓ /opt/field_trainer/audio/male/ ($MALE_COUNT files)"
echo "    ✓ /opt/field_trainer/audio/female/ ($FEMALE_COUNT files)"
echo ""
echo "  Service Status:"
if sudo systemctl is-active --quiet field-client.service; then
    echo "    ✓ field-client.service is RUNNING"
else
    echo "    ✗ field-client.service is NOT running"
fi
echo ""
echo "  Useful Commands:"
echo "    sudo systemctl status field-client    # Check service status"
echo "    sudo journalctl -u field-client -f    # View live logs"
echo "    sudo systemctl restart field-client   # Restart service"
echo "    ping 192.168.99.100                   # Test Device0 connection"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup
rm -rf /tmp/ft_download 2>/dev/null

log_success "Phase 5 complete!"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  CLIENT BUILD COMPLETE!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Device${DEVICE_NUM} is now fully configured and running"
echo ""
echo "  Next Steps:"
echo "    1. Verify device appears on Device0 web interface"
echo "       → http://192.168.99.100:5000"
echo ""
echo "    2. Register device MAC in Device0 settings (if using whitelist)"
echo "       → Settings → Device Whitelisting"
echo "       → MAC: $(cat /sys/class/net/wlan0/address)"
echo ""
echo "    3. Test LED by deploying a course from web interface"
echo ""
echo "    4. Test touch sensor during an active course"
echo ""
echo "    5. Repeat this process for remaining field devices"
echo "       (Device2, Device3, Device4, Device5)"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

log_end "Client Phase 5 complete - Build finished!"
exit 0
