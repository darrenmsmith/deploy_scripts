#!/bin/bash

##############################################################################
# Field Trainer - Client Device Mesh Installation Script v2.2
# For Raspberry Pi Zero W (Devices 1-5)
# Trixie Lite 32-bit
# 
# Requirements:
# - USB thumb drive with this script
# - USB WiFi adapter for temporary internet access during installation
##############################################################################

set -e  # Exit on any error

echo "=========================================="
echo "Field Trainer Client Mesh Installation"
echo "Version 2.2 - With Auto WiFi Setup"
echo "=========================================="
echo ""

# WiFi credentials for temporary internet access
WIFI_SSID="smithhome"
WIFI_PASSWORD="ciscoME128"  # <<< UPDATE THIS WITH REAL PASSWORD

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run with sudo"
    echo "Usage: sudo bash install_client_mesh.sh"
    exit 1
fi

# Detect device number from hostname
HOSTNAME=$(hostname)
echo "Detected hostname: $HOSTNAME"

# Extract device number (Device1 -> 1, Device2 -> 2, etc.)
if [[ $HOSTNAME =~ Device([0-9]+) ]]; then
    DEVICE_NUM="${BASH_REMATCH[1]}"
else
    echo "ERROR: Hostname must be in format 'DeviceX' where X is 1-5"
    echo "Current hostname: $HOSTNAME"
    exit 1
fi

# Validate device number
if [ "$DEVICE_NUM" -lt 1 ] || [ "$DEVICE_NUM" -gt 5 ]; then
    echo "ERROR: Device number must be between 1 and 5"
    echo "Detected device number: $DEVICE_NUM"
    exit 1
fi

# Calculate IP address
MESH_IP="192.168.99.10${DEVICE_NUM}/24"
echo "Device Number: $DEVICE_NUM"
echo "Assigned IP: $MESH_IP"
echo ""

# Check for wlan1 (USB WiFi adapter)
echo "Checking for USB WiFi adapter (wlan1)..."
if ip link show wlan1 &>/dev/null; then
    echo "✓ Found wlan1 (USB WiFi adapter)"
    HAS_WLAN1=true
else
    echo "✗ No wlan1 detected"
    echo ""
    echo "WARNING: No USB WiFi adapter found!"
    echo "This script requires internet access to install packages."
    echo ""
    echo "Please:"
    echo "  1. Plug in a USB WiFi adapter"
    echo "  2. Wait 5 seconds for detection"
    echo "  3. Run this script again"
    echo ""
    exit 1
fi

echo ""

# Confirm before proceeding
read -p "Continue with installation? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "=========================================="
echo "Phase 1: Setting Up Internet Connection"
echo "=========================================="
echo ""

# Kill any existing wpa_supplicant processes
echo "Cleaning up existing wpa_supplicant processes..."
killall wpa_supplicant 2>/dev/null || true
sleep 1

# Remove stale control interface files
rm -rf /var/run/wpa_supplicant/* 2>/dev/null || true

# Create temporary WPA supplicant config for wlan1
echo "Creating WiFi configuration for wlan1..."
cat > /tmp/wpa_temp.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="${WIFI_SSID}"
    psk="${WIFI_PASSWORD}"
    key_mgmt=WPA-PSK
}
EOF

echo "Unblocking WiFi (RF-kill)..."
rfkill unblock wifi
sleep 1

echo "Bringing up wlan1..."
ip link set wlan1 up
sleep 2

echo "Connecting to ${WIFI_SSID}..."
wpa_supplicant -B -i wlan1 -c /tmp/wpa_temp.conf

echo "Waiting for connection..."
sleep 10

echo "Requesting IP address via DHCP..."
dhcpcd wlan1

echo "Waiting for IP assignment..."
sleep 5

# Check if we got an IP
if ip addr show wlan1 | grep -q "inet "; then
    WLAN1_IP=$(ip addr show wlan1 | grep "inet " | awk '{print $2}')
    echo "✓ Connected! wlan1 IP: $WLAN1_IP"
else
    echo "✗ Failed to get IP address on wlan1"
    echo "Please check:"
    echo "  - USB WiFi adapter is properly connected"
    echo "  - WiFi credentials are correct in the script"
    echo "  - WiFi network '${WIFI_SSID}' is available"
    exit 1
fi

# Test internet connectivity
echo "Testing internet connection..."
if ping -c 2 8.8.8.8 &>/dev/null; then
    echo "✓ Internet connection verified!"
else
    echo "✗ Cannot reach internet"
    echo "Please check your network configuration"
    exit 1
fi

echo ""
echo "=========================================="
echo "Phase 2: Installing Packages"
echo "=========================================="
echo ""

echo "Step 1: Updating package lists..."
apt update

echo ""
echo "Step 2: Installing BATMAN-adv and networking tools..."
apt install -y batctl wpasupplicant wireless-tools

echo ""
echo "Step 3: Loading batman-adv kernel module..."
modprobe batman-adv
if lsmod | grep -q batman; then
    echo "✓ batman-adv module loaded successfully"
else
    echo "ERROR: Failed to load batman-adv module"
    exit 1
fi

echo ""
echo "=========================================="
echo "Phase 3: Disconnecting Temporary WiFi"
echo "=========================================="
echo ""

echo "Stopping wpa_supplicant on wlan1..."
killall wpa_supplicant 2>/dev/null || true

echo "Releasing DHCP lease on wlan1..."
dhcpcd -k wlan1 2>/dev/null || true

echo "Bringing down wlan1..."
ip link set wlan1 down

echo "Removing temporary WiFi configuration..."
rm -f /tmp/wpa_temp.conf

echo "✓ wlan1 disconnected"
echo ""
echo "*** YOU CAN NOW REMOVE THE USB WIFI ADAPTER ***"
echo ""

echo "=========================================="
echo "Phase 4: Creating Mesh Scripts"
echo "=========================================="
echo ""

echo "Step 4: Creating mesh startup script..."
cat > /usr/local/bin/start-batman-mesh.sh << 'EOF'
#!/bin/bash

# Field Trainer - BATMAN-adv Mesh Network Startup
# Client Device Configuration

MESH_IFACE="wlan0"
MESH_SSID="ft_mesh"
MESH_CHANNEL="1"
BSSID="00:11:22:33:44:55"

# Load batman-adv module
modprobe batman-adv

# Bring down interface
ip link set ${MESH_IFACE} down

# Set interface to IBSS (Ad-hoc) mode
iw dev ${MESH_IFACE} set type ibss

# Bring interface up
ip link set ${MESH_IFACE} up

# Join IBSS network
iw dev ${MESH_IFACE} ibss join ${MESH_SSID} 2412 fixed-freq ${BSSID}

# Add interface to batman-adv
batctl if add ${MESH_IFACE}

# Bring up bat0 interface
ip link set bat0 up

# Assign IP to bat0 (will be set by systemd service or manually)
# ip addr add DEVICE_IP dev bat0

echo "BATMAN mesh started on ${MESH_IFACE}"
echo "Waiting for bat0 interface..."
sleep 2
echo "Ready for IP assignment"
EOF

# Make script executable
chmod +x /usr/local/bin/start-batman-mesh.sh
echo "✓ Created /usr/local/bin/start-batman-mesh.sh"

echo ""
echo "Step 5: Creating IP assignment script..."
cat > /usr/local/bin/set-mesh-ip.sh << EOF
#!/bin/bash

# Assign IP address to bat0
MESH_IP="${MESH_IP}"

ip addr add \${MESH_IP} dev bat0

echo "bat0 configured with IP \${MESH_IP}"
EOF

chmod +x /usr/local/bin/set-mesh-ip.sh
echo "✓ Created /usr/local/bin/set-mesh-ip.sh"

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Device: $HOSTNAME (Device $DEVICE_NUM)"
echo "Mesh IP: $MESH_IP"
echo ""
echo "IMPORTANT: Remove the USB WiFi adapter now if you haven't already!"
echo ""
echo "TO START THE MESH NETWORK:"
echo "  1. Start mesh: sudo /usr/local/bin/start-batman-mesh.sh"
echo "  2. Set IP: sudo /usr/local/bin/set-mesh-ip.sh"
echo "  3. Test: ping 192.168.99.100  (Device 0 gateway)"
echo ""
echo "TO CHECK MESH STATUS:"
echo "  - View neighbors: batctl n"
echo "  - View interface: ip addr show bat0"
echo "  - Check IBSS: iw dev wlan0 info"
echo ""
echo "NOTES:"
echo "  - These scripts do NOT auto-start on boot"
echo "  - You can create systemd services later if needed"
echo "  - SSH from Device 0: ssh pi@${MESH_IP%/*}"
echo ""
echo "=========================================="