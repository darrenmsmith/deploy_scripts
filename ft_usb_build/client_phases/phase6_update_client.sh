#!/bin/bash

################################################################################
# Client Phase 6: Update Client Application from Device0
# Pull updated client files from Device0 and restart service
# Run on each client cone (Device1-5) individually
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

log_start "Client Phase 6: Update Client Application"

################################################################################
# Step 1: Identify this device
################################################################################

HOSTNAME=$(hostname)
if [[ $HOSTNAME =~ Device([1-5]) ]]; then
    DEVICE_NUM="${BASH_REMATCH[1]}"
    DEVICE_IP="192.168.99.10${DEVICE_NUM}"
    log_info "Device: Device${DEVICE_NUM} (${DEVICE_IP})"
else
    log_error "Invalid hostname: $HOSTNAME (expected Device1-Device5)"
    exit 1
fi

DEVICE0_IP="192.168.99.100"
SOURCE_DIR="/opt"
DEST_DIR="/opt"
SSH_USER="pi"

# Files to pull from Device0
CLIENT_FILES=(
    "field_client_connection.py"
    "audio_manager.py"
    "led_controller.py"
    "mpu65xx_touch_sensor.py"
    "shutdown_leds.py"
)

echo ""
echo "Will pull from Device0 (${DEVICE0_IP}):"
for f in "${CLIENT_FILES[@]}"; do
    echo "  • ${f}"
done
echo ""

################################################################################
# Step 2: Verify connection to Device0
################################################################################

log_step "Testing connection to Device0"

if ping -c 2 -W 5 "$DEVICE0_IP" &>/dev/null; then
    log_success "Device0 reachable"
else
    log_error "Cannot reach Device0 (${DEVICE0_IP})"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify Device0 is powered on"
    echo "  2. Check mesh is active: sudo systemctl status batman-mesh"
    echo "  3. Check mesh neighbors: sudo batctl n"
    echo ""
    exit 1
fi

if ssh -o ConnectTimeout=5 -o BatchMode=yes "${SSH_USER}@${DEVICE0_IP}" "exit" 2>/dev/null; then
    log_success "SSH to Device0 working"
else
    log_error "Cannot SSH to Device0"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Ensure SSH keys are set up: ssh-copy-id pi@${DEVICE0_IP}"
    echo "  2. Check Device0 SSH service: sudo systemctl status ssh"
    echo ""
    exit 1
fi

################################################################################
# Step 3: Verify source files exist on Device0
################################################################################

log_step "Verifying source files on Device0"

MISSING=0
for f in "${CLIENT_FILES[@]}"; do
    echo -n "  ${f}... "
    if ssh "${SSH_USER}@${DEVICE0_IP}" "test -f ${SOURCE_DIR}/${f}" 2>/dev/null; then
        log_success "found"
    else
        log_error "NOT FOUND on Device0"
        MISSING=$((MISSING + 1))
    fi
done

if [ $MISSING -gt 0 ]; then
    log_error "$MISSING file(s) missing on Device0"
    exit 1
fi

################################################################################
# Step 4: Stop service before update
################################################################################

log_step "Stopping field-client service"

sudo systemctl stop field-client 2>/dev/null
sleep 1
log_success "Service stopped"

################################################################################
# Step 5: Pull files from Device0
################################################################################

log_step "Pulling files from Device0"

COPY_ERRORS=0
for f in "${CLIENT_FILES[@]}"; do
    echo -n "  ${f}... "
    if scp -q "${SSH_USER}@${DEVICE0_IP}:${SOURCE_DIR}/${f}" "${DEST_DIR}/${f}" 2>/dev/null; then
        log_success "copied"
    else
        log_error "FAILED"
        COPY_ERRORS=$((COPY_ERRORS + 1))
    fi
done

if [ $COPY_ERRORS -gt 0 ]; then
    log_error "${COPY_ERRORS} file(s) failed to copy"
    log_warning "Attempting to restart service with existing files..."
    sudo systemctl start field-client 2>/dev/null
    exit 1
fi

################################################################################
# Step 6: Fix permissions
################################################################################

log_step "Setting file permissions"

for f in "${CLIENT_FILES[@]}"; do
    sudo chown pi:pi "${DEST_DIR}/${f}" 2>/dev/null
done
log_success "Permissions set"

################################################################################
# Step 7: Restart service
################################################################################

log_step "Starting field-client service"

if sudo systemctl start field-client; then
    sleep 2
    STATUS=$(systemctl is-active field-client)
    if [ "$STATUS" = "active" ]; then
        log_success "field-client is running"
    else
        log_warning "field-client status: ${STATUS}"
        echo ""
        echo "Check logs: sudo journalctl -u field-client -n 30 --no-pager"
    fi
else
    log_error "Failed to start field-client"
    echo ""
    echo "Check logs: sudo journalctl -u field-client -n 30 --no-pager"
    exit 1
fi

################################################################################
# Summary
################################################################################

echo ""
echo "==============================="
echo "Update Summary"
echo "==============================="
echo ""
log_success "Client application updated on ${HOSTNAME}"
echo ""
echo "Files updated:"
for f in "${CLIENT_FILES[@]}"; do
    echo "  • ${f}"
done
echo ""
echo "Service status: $(systemctl is-active field-client)"
echo ""
log_info "Log saved to USB install_logs"
echo ""
exit 0
