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

# Directories to deploy to each client cone
CLIENT_DIRS=(
    "field_trainer/audio"
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
echo "Directories to deploy:"
for d in "${CLIENT_DIRS[@]}"; do
    if [ -d "${SOURCE_DIR}/${d}" ]; then
        COUNT=$(find "${SOURCE_DIR}/${d}" -type f | wc -l)
        printf "  %-40s %s files\n" "$d" "$COUNT"
    else
        print_warning "  $d/ (NOT FOUND on Device0)"
    fi
done
echo ""
read -p "Press Enter to begin deployment..."
echo ""

################################################################################
# Step 1: Copy SSH Keys to Client Devices
################################################################################

echo "Step 1: Setting Up SSH Keys..."
echo "------------------------------"
echo ""
print_info "SSH key auth is required for deployment."
print_info "You will be prompted for the pi password on each device."
print_info "(Default password is usually: raspberry)"
echo ""

SSH_PUB_KEY="$HOME/.ssh/id_ed25519.pub"
if [ ! -f "$SSH_PUB_KEY" ]; then
    SSH_PUB_KEY="$HOME/.ssh/id_rsa.pub"
fi

if [ ! -f "$SSH_PUB_KEY" ]; then
    print_warning "No SSH public key found - generating one..."
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -q
    SSH_PUB_KEY="$HOME/.ssh/id_ed25519.pub"
    print_success "SSH key generated"
fi

print_info "Using key: $SSH_PUB_KEY"
echo ""

for LAST_OCTET in "${DEVICES[@]}"; do
    DEVICE_IP="192.168.99.${LAST_OCTET}"
    DEVICE_NUM=$((LAST_OCTET - 100))
    DEVICE_NAME="Device${DEVICE_NUM}"

    echo -n "  ${DEVICE_NAME} (${DEVICE_IP})... "

    # Skip if unreachable
    if ! ping -c 1 -W 2 "${DEVICE_IP}" &>/dev/null; then
        print_warning "unreachable - skipping"
        continue
    fi

    # Already have key auth?
    if ssh -o ConnectTimeout=3 -o BatchMode=yes "${SSH_USER}@${DEVICE_IP}" "exit" 2>/dev/null; then
        print_success "key already installed"
        continue
    fi

    # Copy key (will prompt for password)
    echo ""
    print_info "  Enter password for pi@${DEVICE_IP}:"
    if ssh-copy-id -i "$SSH_PUB_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${SSH_USER}@${DEVICE_IP}" 2>/dev/null; then
        print_success "  ${DEVICE_NAME} key installed"
    else
        print_warning "  ${DEVICE_NAME} key copy failed - will retry during deploy"
    fi
    echo ""
done

echo ""

################################################################################
# Step 2: Verify source files exist
################################################################################

echo "Step 2: Verifying Source Files..."
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
for d in "${CLIENT_DIRS[@]}"; do
    echo -n "  ${d}/... "
    if [ -d "${SOURCE_DIR}/${d}" ]; then
        print_success "found"
    else
        print_error "MISSING"
        MISSING=$((MISSING + 1))
    fi
done

echo ""

if [ $MISSING -gt 0 ]; then
    print_error "$MISSING source file(s)/dir(s) missing from ${SOURCE_DIR}"
    exit 1
fi

################################################################################
# Step 2: Deploy to each device
################################################################################

echo "Step 3: Deploying to Client Devices..."
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

    # Copy files to /tmp first (always writable), then sudo move to /opt
    echo -n "  Copying files... "
    COPY_ERRORS=0
    ssh "${SSH_USER}@${DEVICE_IP}" "mkdir -p /tmp/ft_update" 2>/dev/null
    for f in "${CLIENT_FILES[@]}"; do
        if ! scp -q "${SOURCE_DIR}/${f}" "${SSH_USER}@${DEVICE_IP}:/tmp/ft_update/${f}" 2>/dev/null; then
            print_error "failed to copy ${f}"
            COPY_ERRORS=$((COPY_ERRORS + 1))
        fi
    done
    for d in "${CLIENT_DIRS[@]}"; do
        DIRNAME=$(basename "${d}")
        if ! scp -q -r "${SOURCE_DIR}/${d}" "${SSH_USER}@${DEVICE_IP}:/tmp/ft_update/${DIRNAME}" 2>/dev/null; then
            print_error "failed to copy ${d}/"
            COPY_ERRORS=$((COPY_ERRORS + 1))
        fi
    done

    if [ $COPY_ERRORS -eq 0 ]; then
        print_success "files and dirs staged"
    else
        print_error "${COPY_ERRORS} item(s) failed to copy"
        FAILED=$((FAILED + 1))
        echo ""
        continue
    fi

    # Move from /tmp to /opt with sudo and fix permissions
    echo -n "  Installing to /opt... "
    # Copy files
    MOVE_CMD="sudo cp /tmp/ft_update/*.py ${DEST_DIR}/"
    # Copy audio dir - ensure parent dir exists
    MOVE_CMD="${MOVE_CMD} && sudo mkdir -p ${DEST_DIR}/field_trainer"
    MOVE_CMD="${MOVE_CMD} && sudo cp -r /tmp/ft_update/audio ${DEST_DIR}/field_trainer/"
    # Fix ownership
    MOVE_CMD="${MOVE_CMD} && sudo chown -R pi:pi ${DEST_DIR}/field_trainer/audio"
    for f in "${CLIENT_FILES[@]}"; do
        MOVE_CMD="${MOVE_CMD} && sudo chown pi:pi ${DEST_DIR}/${f}"
    done
    MOVE_CMD="${MOVE_CMD} && rm -rf /tmp/ft_update"
    if ssh "${SSH_USER}@${DEVICE_IP}" "$MOVE_CMD" 2>/dev/null; then
        print_success "done"
    else
        print_error "failed to install files"
        FAILED=$((FAILED + 1))
        echo ""
        continue
    fi

    # Patch batman startup script to include default gateway route
    echo -n "  Patching mesh startup script (default gateway)... "
    PATCH_CMD="grep -q 'ip route add default' /usr/local/bin/start-batman-mesh-client.sh 2>/dev/null"
    PATCH_CMD="${PATCH_CMD} || echo 'ip route add default via 192.168.99.100 2>/dev/null || true'"
    PATCH_CMD="${PATCH_CMD} | sudo tee -a /usr/local/bin/start-batman-mesh-client.sh > /dev/null"
    if ssh "${SSH_USER}@${DEVICE_IP}" "$PATCH_CMD" 2>/dev/null; then
        print_success "done"
    else
        print_warning "patch failed (non-fatal)"
    fi

    # Apply default gateway immediately (no reboot needed)
    echo -n "  Applying default gateway now... "
    ssh "${SSH_USER}@${DEVICE_IP}" "sudo ip route add default via 192.168.99.100 2>/dev/null || true" 2>/dev/null
    print_success "done"

    # Configure DNS nameservers
    echo -n "  Configuring DNS nameservers... "
    DNS_CMD="grep -q 'nameserver 8.8.8.8' /etc/resolv.conf 2>/dev/null"
    DNS_CMD="${DNS_CMD} || echo -e 'nameserver 8.8.8.8\nnameserver 8.8.4.4' | sudo tee -a /etc/resolv.conf > /dev/null"
    DNS_CMD="${DNS_CMD}; echo -e 'nameserver 8.8.8.8\nnameserver 8.8.4.4' | sudo tee /etc/resolv.conf.tail > /dev/null"
    ssh "${SSH_USER}@${DEVICE_IP}" "$DNS_CMD" 2>/dev/null
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
    for d in "${CLIENT_DIRS[@]}"; do
        echo "  • ${d}/ (directory)"
    done
    echo ""
    print_info "Log: ${LOG_FILE}"
    echo ""
    exit 0
fi
