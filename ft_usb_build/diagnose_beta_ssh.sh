#!/bin/bash
# Beta System Diagnostics - SSH & wlan1 troubleshooting
# Run on Beta system: sudo bash /mnt/usb/ft_usb_build/diagnose_beta_ssh.sh
# Results saved to: /mnt/usb/install_logs/beta_diag_[timestamp].log

LOGFILE="/mnt/usb/install_logs/beta_diag_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /mnt/usb/install_logs

exec > >(tee -a "$LOGFILE") 2>&1

echo "========================================"
echo "Beta System Diagnostics"
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "========================================"
echo ""

echo "--- OS VERSION ---"
cat /etc/os-release | grep -E "^(NAME|VERSION|ID)"
echo ""

echo "--- NETWORK INTERFACES (ip addr) ---"
ip addr show
echo ""

echo "--- INTERFACE NAMES & BUS TYPE ---"
for iface in wlan0 wlan1; do
    if [ -d "/sys/class/net/$iface" ]; then
        BUS=$(readlink -f /sys/class/net/$iface/device 2>/dev/null || echo "unknown")
        MAC=$(cat /sys/class/net/$iface/address 2>/dev/null || echo "unknown")
        echo "$iface: MAC=$MAC  BUS=$BUS"
    else
        echo "$iface: NOT FOUND"
    fi
done
echo ""

echo "--- RFKILL STATUS ---"
rfkill list all
echo ""

echo "--- USB DEVICES ---"
lsusb
echo ""

echo "--- SSH SERVICE STATUS ---"
systemctl status ssh --no-pager
echo ""

echo "--- SYSTEMD NETWORK SERVICES ---"
systemctl list-units --type=service --state=running --no-pager | grep -E "wlan|dhcp|network|ssh|wpa"
echo ""

echo "--- wlan1-wpa.service STATUS ---"
systemctl status wlan1-wpa.service --no-pager 2>/dev/null || echo "wlan1-wpa.service: not found"
echo ""

echo "--- wlan1-dhcp.service STATUS ---"
systemctl status wlan1-dhcp.service --no-pager 2>/dev/null || echo "wlan1-dhcp.service: not found"
echo ""

echo "--- DHCPCD SERVICE STATUS ---"
systemctl status dhcpcd.service --no-pager 2>/dev/null || echo "dhcpcd.service: not found"
echo ""

echo "--- NETWORKMANAGER STATUS ---"
systemctl status NetworkManager --no-pager 2>/dev/null || echo "NetworkManager: not running"
nmcli device status 2>/dev/null || echo "nmcli: not available"
echo ""

echo "--- WPA_SUPPLICANT wlan1 STATUS ---"
wpa_cli -i wlan1 status 2>/dev/null || echo "wpa_cli: could not connect to wlan1"
echo ""

echo "--- WPA SUPPLICANT CONFIG (no password) ---"
if [ -f /etc/wpa_supplicant/wpa_supplicant-wlan1.conf ]; then
    grep -v "psk=" /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
else
    echo "/etc/wpa_supplicant/wpa_supplicant-wlan1.conf: NOT FOUND"
fi
echo ""

echo "--- UDEV PERSISTENT NET RULES ---"
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
    cat /etc/udev/rules.d/70-persistent-net.rules
else
    echo "70-persistent-net.rules: NOT FOUND"
fi
echo ""

echo "--- NETWORKMANAGER UNMANAGED CONFIG ---"
cat /etc/NetworkManager/conf.d/unmanaged-wlan1.conf 2>/dev/null || echo "unmanaged-wlan1.conf: NOT FOUND"
echo ""

echo "--- ROUTING TABLE ---"
ip route show
echo ""

echo "--- RESOLV.CONF ---"
cat /etc/resolv.conf
echo ""

echo "--- INTERNET CONNECTIVITY TEST ---"
ping -c 3 -W 5 8.8.8.8 && echo "PING 8.8.8.8: OK" || echo "PING 8.8.8.8: FAILED"
echo ""

echo "--- wlan1-wpa.service JOURNAL (last 30 lines) ---"
journalctl -u wlan1-wpa.service --no-pager -n 30 2>/dev/null || echo "No journal for wlan1-wpa"
echo ""

echo "--- wlan1-dhcp.service JOURNAL (last 30 lines) ---"
journalctl -u wlan1-dhcp.service --no-pager -n 30 2>/dev/null || echo "No journal for wlan1-dhcp"
echo ""

echo "--- DHCPCD JOURNAL (last 20 lines) ---"
journalctl -u dhcpcd --no-pager -n 20 2>/dev/null || echo "No journal for dhcpcd"
echo ""

echo "--- DMESG wlan1 MESSAGES ---"
dmesg | grep -i "wlan\|wifi\|usb\|rfkill" | tail -30
echo ""

echo "--- INSTALL STATE ---"
cat /mnt/usb/install_state.json 2>/dev/null || echo "install_state.json not found"
echo ""

echo "========================================"
echo "Diagnostics complete!"
echo "Log saved to: $LOGFILE"
echo "========================================"
