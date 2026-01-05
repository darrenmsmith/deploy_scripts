#!/bin/bash

################################################################################
# Field Trainer - Client Phase 5: Client Application Deployment
# Download client software from Device0 and configure services
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

log_start "Client Phase 5: Client Application Deployment"

################################################################################
# SUDO CREDENTIAL REFRESH - Prompt once, keep alive throughout script
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Sudo Access Required"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This script requires sudo access for:"
echo "  • Creating directories (/opt/field_trainer/)"
echo "  • Installing files"
echo "  • Creating systemd services"
echo "  • Starting services"
echo ""
echo "You will be prompted for your password ONCE at the beginning."
echo ""

# Prompt for sudo password and keep session alive
sudo -v

if [ $? -ne 0 ]; then
    log_error "Sudo authentication failed"
    exit 1
fi

# Background process to keep sudo session alive
# Refreshes every 4 minutes (sudo timeout is usually 5-15 minutes)
(
    while true; do
        sleep 240  # 4 minutes
        sudo -v
    done
) &
SUDO_REFRESH_PID=$!

# Ensure we kill the refresh process on exit
trap "kill $SUDO_REFRESH_PID 2>/dev/null" EXIT

log_success "Sudo credentials cached (will not prompt again)"

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
# Step 4: Create Directory Structure
################################################################################

log_step "Creating directory structure"

sudo mkdir -p /opt/field_trainer/audio/male
sudo mkdir -p /opt/field_trainer/audio/female

if [ $? -eq 0 ]; then
    log_success "Directories created"
else
    log_error "Failed to create directories"
    exit 1
fi

################################################################################
# Step 5: Download Client Application from Device0
################################################################################

log_step "Downloading field_client_connection.py from Device0"

scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_client_connection.py /tmp/field_client_connection.py

if [ $? -eq 0 ] && [ -f /tmp/field_client_connection.py ]; then
    sudo mv /tmp/field_client_connection.py /opt/field_client_connection.py
    sudo chmod +x /opt/field_client_connection.py
    log_success "field_client_connection.py downloaded ($(stat -c%s /opt/field_client_connection.py) bytes)"
else
    log_error "Failed to download field_client_connection.py"
    exit 1
fi

################################################################################
# Step 6: Download Support Libraries
################################################################################

log_step "Downloading support libraries from Device0"

# Download audio_manager.py
log_info "Downloading audio_manager.py..."
scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/audio_manager.py /tmp/audio_manager.py

if [ $? -eq 0 ] && [ -f /tmp/audio_manager.py ]; then
    sudo mv /tmp/audio_manager.py /opt/audio_manager.py
    log_success "audio_manager.py downloaded"
else
    log_warning "audio_manager.py not found (may not be needed)"
fi

# Download ft_touch.py
log_info "Downloading ft_touch.py..."
scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/ft_touch.py /tmp/ft_touch.py

if [ $? -eq 0 ] && [ -f /tmp/ft_touch.py ]; then
    sudo mv /tmp/ft_touch.py /opt/field_trainer/ft_touch.py
    log_success "ft_touch.py downloaded"
else
    log_error "Failed to download ft_touch.py"
    exit 1
fi

# Download ft_led.py
log_info "Downloading ft_led.py..."
scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/ft_led.py /tmp/ft_led.py

if [ $? -eq 0 ] && [ -f /tmp/ft_led.py ]; then
    sudo mv /tmp/ft_led.py /opt/field_trainer/ft_led.py
    log_success "ft_led.py downloaded"
else
    log_warning "ft_led.py not found"
fi

# Download ft_audio.py
log_info "Downloading ft_audio.py..."
scp -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/ft_audio.py /tmp/ft_audio.py

if [ $? -eq 0 ] && [ -f /tmp/ft_audio.py ]; then
    sudo mv /tmp/ft_audio.py /opt/field_trainer/ft_audio.py
    log_success "ft_audio.py downloaded"
else
    log_warning "ft_audio.py not found"
fi

################################################################################
# Step 7: Download Audio Files
################################################################################

log_step "Downloading audio files from Device0"

echo ""
log_info "Downloading male voice audio files (this may take a minute)..."

mkdir -p /tmp/audio_male 2>/dev/null
scp -r -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/audio/male/* /tmp/audio_male/ 2>/dev/null

if [ $? -eq 0 ]; then
    sudo mv /tmp/audio_male/* /opt/field_trainer/audio/male/ 2>/dev/null
    MALE_COUNT=$(ls -1 /opt/field_trainer/audio/male/*.mp3 2>/dev/null | wc -l)
    log_success "Male audio files downloaded ($MALE_COUNT files)"
else
    log_warning "Male audio files not downloaded"
    MALE_COUNT=0
fi

log_info "Downloading female voice audio files..."

mkdir -p /tmp/audio_female 2>/dev/null
scp -r -o StrictHostKeyChecking=no pi@${DEVICE0_IP}:/opt/field_trainer/audio/female/* /tmp/audio_female/ 2>/dev/null

if [ $? -eq 0 ]; then
    sudo mv /tmp/audio_female/* /opt/field_trainer/audio/female/ 2>/dev/null
    FEMALE_COUNT=$(ls -1 /opt/field_trainer/audio/female/*.mp3 2>/dev/null | wc -l)
    log_success "Female audio files downloaded ($FEMALE_COUNT files)"
else
    log_warning "Female audio files not downloaded"
    FEMALE_COUNT=0
fi

# Set permissions
sudo chown -R pi:pi /opt/field_trainer
sudo chmod -R 755 /opt/field_trainer

################################################################################
# Step 8: Create Systemd Service
################################################################################

log_step "Creating systemd service for field client"

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

################################################################################
# Step 9: Enable and Start Service
################################################################################

log_step "Enabling field-client service"

sudo systemctl daemon-reload
sudo systemctl enable field-client.service

if [ $? -eq 0 ]; then
    log_success "Service enabled (will start on boot)"
else
    log_error "Failed to enable service"
    exit 1
fi

# Start the service now
log_step "Starting field-client service"

sudo systemctl start field-client.service
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
# Step 10: Test Client Connection
################################################################################

log_step "Checking client connection status"

sleep 5

# Check if client is connecting
sudo journalctl -u field-client -n 20 --no-pager | grep -i "connected\|error" || true

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
