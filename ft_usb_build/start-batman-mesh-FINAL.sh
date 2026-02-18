#!/bin/bash

################################################################################
# Field Trainer - BATMAN-adv Mesh Network Startup
# Device 0 - Gateway Configuration
# IP: 192.168.99.100/24
# FIXED: Idempotent - can run multiple times safely
################################################################################

MESH_IFACE="wlan0"
MESH_IP="192.168.99.100/24"
MESH_SSID="ft_mesh2"
MESH_CHANNEL="1"

echo "Starting BATMAN-adv mesh network..."

# Load batman-adv module
modprobe batman-adv
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to load batman-adv module"
    exit 1
fi

# Unblock WiFi (RF-kill fix)
rfkill unblock wifi

# Bring down interface
ip link set ${MESH_IFACE} down

# Set interface to IBSS (Ad-hoc) mode
iw dev ${MESH_IFACE} set type ibss
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to set IBSS mode on ${MESH_IFACE}"
    exit 1
fi

# Bring interface up
ip link set ${MESH_IFACE} up
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to bring up ${MESH_IFACE}"
    exit 1
fi

# Join IBSS network (2412 = Channel 1)
# First leave if already joined (idempotent)
iw dev ${MESH_IFACE} ibss leave 2>/dev/null
iw dev ${MESH_IFACE} ibss join ${MESH_SSID} 2412 fixed-freq 00:11:22:33:44:55
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to join IBSS network"
    exit 1
fi

# Small delay for interface to stabilize
sleep 2

# Add interface to batman-adv (idempotent - batctl handles this)
batctl if add ${MESH_IFACE}
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to add ${MESH_IFACE} to batman-adv"
    exit 1
fi

# Bring up bat0 interface
ip link set bat0 up
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to bring up bat0"
    exit 1
fi

# Assign IP to bat0 (idempotent - only add if not already assigned)
if ! ip addr show bat0 | grep -q "${MESH_IP}"; then
    ip addr add ${MESH_IP} dev bat0
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to assign IP to bat0"
        exit 1
    fi
    echo "IP ${MESH_IP} assigned to bat0"
else
    echo "IP ${MESH_IP} already assigned to bat0 (ok)"
fi

echo "SUCCESS: BATMAN mesh started on ${MESH_IFACE}"
echo "  bat0 configured with IP ${MESH_IP}"
echo "  SSID: ${MESH_SSID}"

# Show mesh status
echo ""
echo "Mesh interface status:"
iw dev ${MESH_IFACE} info
echo ""
echo "bat0 status:"
ip addr show bat0

exit 0
