#!/bin/bash

################################################################################
# Phase 8: Deploy Client Application to Field Cones (Devices 1-5)
# Pushes updated client files from Device0 to all reachable client cones
# Run from Device0 (gateway) after Phase 7 completes
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info()    { echo -e "${BLUE}ℹ $1${NC}"; }

ERRORS=0

# USB logging
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/phase8_deploy_clients_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
ln -sf "$LOG_FILE" "${LOG_DIR}/phase8_deploy_clients_latest.log"
echo "========================================"
echo "Field Trainer Installation - Phase 8: Deploy Clients"
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "Log: $LOG_FILE"
echo "========================================"
echo ""

################################################################################
# Configuration
################################################################################

SOURCE_DIR="/opt"
DEST_DIR="/opt"
SSH_USER="pi"
DEVICES=(101 102 103 104 105)

# Files to deploy to each client cone
CLIENT_FILES=(
    "field_client_connection.py"
    "audio_manager.py"
    "led_controller.py"
    "mpu65xx_touch_sensor.py"
    "shutdown_leds.py"
)

echo "Phase 8: Deploy Client Application to Field Cones"
echo "=================================================="
echo ""
echo "Source:  ${SOURCE_DIR}"
echo "Dest:    ${DEST_DIR} on each client"
echo "User:    ${SSH_USER}"
echo ""
echo "Files to deploy:"
for f in "${CLIENT_FILES[@]}"; do
    if [ -f "${SOURCE_DIR}/${f}" ]; then
        SIZE=$(stat -c%s "${SOURCE_DIR}/${f}" 2>/dev/null)
        printf "  %-40s %s bytes\n" "$f" "$SIZE"
    else
        print_warning "  $f (NOT FOUND on Device0)"
    fi
done
echo ""
read -p "Press Enter to begin deployment..."
echo ""

################################################################################
# Step 1: Verify source files exist
################################################################################

echo "Step 1: Verifying Source Files..."
echo "----------------------------------"

MISSING=0
for f in "${CLIENT_FILES[@]}"; do
    echo -n "  ${f}... "
    if [ -f "${SOURCE_DIR}/${f}" ]; then
        print_success "found"
    else
        print_error "MISSING"
        MISSING=$((MISSING + 1))
    fi
done

echo ""

if [ $MISSING -gt 0 ]; then
    print_error "$MISSING source file(s) missing from ${SOURCE_DIR}"
    exit 1
fi

################################################################################
# Step 2: Deploy to each device
################################################################################

echo "Step 2: Deploying to Client Devices..."
echo "--------------------------------------"
echo ""

DEPLOYED=0
SKIPPED=0
FAILED=0

for LAST_OCTET in "${DEVICES[@]}"; do
    DEVICE_IP="192.168.99.${LAST_OCTET}"
    DEVICE_NUM=$((LAST_OCTET - 100))
    DEVICE_NAME="Device${DEVICE_NUM}"

    echo "--- ${DEVICE_NAME} (${DEVICE_IP}) ---"

    # Check reachability
    echo -n "  Reachable... "
    if ! ping -c 1 -W 3 "${DEVICE_IP}" &>/dev/null; then
        print_warning "unreachable - skipping"
        SKIPPED=$((SKIPPED + 1))
        echo ""
        continue
    fi
    print_success "yes"

    # Check SSH
    echo -n "  SSH accessible... "
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${SSH_USER}@${DEVICE_IP}" "exit" 2>/dev/null; then
        print_error "SSH failed - skipping"
        SKIPPED=$((SKIPPED + 1))
        echo ""
        continue
    fi
    print_success "yes"

    # Stop client service before update
    echo -n "  Stopping field-client service... "
    ssh "${SSH_USER}@${DEVICE_IP}" "sudo systemctl stop field-client 2>/dev/null; true" 2>/dev/null
    print_success "done"

    # Copy files
    echo -n "  Copying files... "
    COPY_ERRORS=0
    for f in "${CLIENT_FILES[@]}"; do
        if ! scp -q "${SOURCE_DIR}/${f}" "${SSH_USER}@${DEVICE_IP}:${DEST_DIR}/${f}" 2>/dev/null; then
            print_error "failed to copy ${f}"
            COPY_ERRORS=$((COPY_ERRORS + 1))
        fi
    done

    if [ $COPY_ERRORS -eq 0 ]; then
        print_success "${#CLIENT_FILES[@]} files copied"
    else
        print_error "${COPY_ERRORS} file(s) failed to copy"
        FAILED=$((FAILED + 1))
        echo ""
        continue
    fi

    # Fix permissions
    echo -n "  Setting permissions... "
    PERM_CMD="sudo chown pi:pi"
    for f in "${CLIENT_FILES[@]}"; do
        PERM_CMD="${PERM_CMD} ${DEST_DIR}/${f}"
    done
    ssh "${SSH_USER}@${DEVICE_IP}" "$PERM_CMD" 2>/dev/null
    print_success "done"

    # Restart client service
    echo -n "  Starting field-client service... "
    if ssh "${SSH_USER}@${DEVICE_IP}" "sudo systemctl start field-client" 2>/dev/null; then
        sleep 2
        STATUS=$(ssh "${SSH_USER}@${DEVICE_IP}" "systemctl is-active field-client" 2>/dev/null)
        if [ "$STATUS" = "active" ]; then
            print_success "running"
        else
            print_warning "started but status: ${STATUS}"
        fi
    else
        print_error "failed to start"
        FAILED=$((FAILED + 1))
        echo ""
        continue
    fi

    print_success "${DEVICE_NAME} deployed successfully"
    DEPLOYED=$((DEPLOYED + 1))
    echo ""
done

################################################################################
# Summary
################################################################################

echo "==============================="
echo "Deployment Summary"
echo "==============================="
echo ""
echo "  Deployed:  ${DEPLOYED} device(s)"
echo "  Skipped:   ${SKIPPED} device(s) (unreachable/no SSH)"
echo "  Failed:    ${FAILED} device(s)"
echo ""

if [ $FAILED -gt 0 ]; then
    print_error "Deployment completed with ${FAILED} failure(s)"
    echo ""
    print_info "Log: ${LOG_FILE}"
    echo ""
    exit 1
elif [ $DEPLOYED -eq 0 ]; then
    print_warning "No devices were updated"
    echo ""
    print_info "Ensure client devices are powered on and connected to mesh"
    echo ""
    exit 1
else
    print_success "Client deployment complete!"
    echo ""
    print_info "Files deployed to ${DEPLOYED} device(s):"
    for f in "${CLIENT_FILES[@]}"; do
        echo "  • ${f}"
    done
    echo ""
    print_info "Log: ${LOG_FILE}"
    echo ""
    exit 0
fi
