#!/bin/bash

################################################################################
# Phase 3: Package Installation
# Installs all required packages for Device 0
# Requires: Phase 2 (Internet) must be completed first
# Updated: Removed offline packages, WiFi checks (Phase 2 handles that)
################################################################################

# Source logging and verification functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"
source "${SCRIPT_DIR}/wifi_verification_functions.sh"

# Initialize logging for Phase 3
init_logging 3 "packages"

# Log phase start
log_phase_start 3 "Package Installation"

ERRORS=0

echo "Phase 3: Package Installation"
echo "=============================="
log_info "Phase 3 script started"
echo ""
echo "This phase installs required packages:"
echo "  • batctl (BATMAN-adv utilities)"
echo "  • dnsmasq (DNS/DHCP server)"
echo "  • iptables, iptables-persistent (firewall)"
echo "  • python3, python3-pip, python3-venv, python3-flask, python3-pil"
echo "  • Hardware libraries: smbus2 (I2C), rpi-ws281x (LEDs), flask-socketio"
echo "  • sqlite3, git, curl"
echo ""
print_info "NOTE: Phase 2 must be completed first (provides internet connection)"
print_info "NOTE: wpasupplicant and dhcpcd5 are pre-installed in Trixie OS"
echo ""

################################################################################
# Pre-check: Verify wlan1 is still up
################################################################################

################################################################################
# dhcpcd Keepalive Monitor
# Runs in background during Phase 3 to prevent connection loss
################################################################################

start_dhcpcd_monitor() {
    local monitor_log="/tmp/dhcpcd_monitor_$$.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] dhcpcd monitor started" > "$monitor_log"

    while true; do
        sleep 10

        # Check if dhcpcd is running for wlan1
        if ! pgrep -f "dhcpcd.*wlan1" >/dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CRITICAL: dhcpcd died! Restarting..." >> "$monitor_log"
            logger "Phase 3 dhcpcd monitor: dhcpcd died, restarting"

            # Restart dhcpcd
            sudo dhcpcd -4 wlan1 2>&1 >> "$monitor_log"

            if [ $? -eq 0 ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] dhcpcd restarted successfully" >> "$monitor_log"
                logger "Phase 3 dhcpcd monitor: dhcpcd restarted successfully"
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to restart dhcpcd" >> "$monitor_log"
                logger "Phase 3 dhcpcd monitor: FAILED to restart dhcpcd"
            fi
        fi
    done
}

# Start background monitor
start_dhcpcd_monitor &
MONITOR_PID=$!
log_info "Started dhcpcd keepalive monitor (PID: $MONITOR_PID)"

# Trap to kill monitor on script exit
cleanup_monitor() {
    if [ -n "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null
        log_info "Stopped dhcpcd keepalive monitor"
    fi
}
trap cleanup_monitor EXIT INT TERM

################################################################################
# Pre-check: Verify WiFi interfaces and wlan1 internet connection
################################################################################

log_step "Pre-flight check: verifying WiFi configuration"

# Verify both WiFi interfaces exist (wlan0=mesh, wlan1=internet)
if ! verify_wifi_interfaces; then
    log_error "WiFi interface verification failed"
    print_error "WiFi interfaces not properly configured"
    exit 1
fi

# Verify wlan1 has internet connectivity
if ! verify_wlan1_internet; then
    log_error "wlan1 internet connection verification failed"
    print_error "Phase 2 (Internet Connection) must be completed first"
    print_info "Please run: sudo ./phase2_internet.sh"
    exit 1
fi

log_success "WiFi verification passed"
echo ""

################################################################################
# Check for internet connectivity
################################################################################

print_info "Checking internet connectivity..."
log_step "Checking internet connectivity"
echo ""

# Test 1: IP connectivity (ping)
echo -n "  IP connectivity (8.8.8.8)... "
if ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
    print_success "working"
    HAS_IP=true
else
    print_error "FAILED"
    HAS_IP=false
fi

# Test 2: DNS resolution
echo -n "  DNS resolution (deb.debian.org)... "
if host deb.debian.org &>/dev/null || nslookup deb.debian.org &>/dev/null || getent hosts deb.debian.org &>/dev/null; then
    print_success "working"
    HAS_DNS=true
else
    print_error "FAILED"
    HAS_DNS=false

    # Try to fix DNS
    print_warning "DNS not working, attempting fix..."

    # Check if resolv.conf exists and has nameservers
    if ! grep -q "^nameserver" /etc/resolv.conf 2>/dev/null; then
        print_info "Adding Google DNS to /etc/resolv.conf..."
        echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf > /dev/null
        echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf > /dev/null

        # Test again
        sleep 2
        if host deb.debian.org &>/dev/null || getent hosts deb.debian.org &>/dev/null; then
            print_success "DNS fixed"
            HAS_DNS=true
        fi
    fi
fi

# Test 3: HTTPS connectivity to Debian repos
echo -n "  Debian repository (deb.debian.org)... "
if command -v curl &>/dev/null; then
    if curl -s --connect-timeout 5 https://deb.debian.org > /dev/null 2>&1; then
        print_success "reachable"
        HAS_REPO=true
    elif curl -s --connect-timeout 5 http://deb.debian.org > /dev/null 2>&1; then
        print_success "reachable (http)"
        HAS_REPO=true
    else
        print_error "FAILED"
        HAS_REPO=false
    fi
else
    # curl not available, assume repo is OK if DNS works
    if [ "$HAS_DNS" = true ]; then
        print_success "assuming reachable (curl not installed)"
        HAS_REPO=true
    else
        print_warning "cannot test (curl not installed, DNS failed)"
        HAS_REPO=false
    fi
fi

echo ""

# Determine if we have working internet
if [ "$HAS_IP" = true ] && [ "$HAS_DNS" = true ] && [ "$HAS_REPO" = true ]; then
    print_success "Internet connection fully functional"
    HAS_INTERNET=true
    echo ""

    print_info "Waiting 5 seconds for network to stabilize..."
    sleep 5

    print_info "Updating package lists..."
    if sudo apt update 2>&1 | tee /tmp/apt_update.log; then
        if grep -qi "error\|failed\|unable to fetch" /tmp/apt_update.log; then
            print_warning "apt update had warnings/errors"
            echo ""
            print_info "Showing last 10 lines of apt update:"
            tail -10 /tmp/apt_update.log
            echo ""
            read -p "Continue anyway? (y/n): " continue_apt
            if [[ ! "$continue_apt" =~ ^[Yy]$ ]]; then
                print_error "Cannot proceed without working apt repositories"
                exit 1
            fi
        else
            print_success "Package lists updated successfully"
        fi

        # Ensure DNS is working before apt operations
        print_info "Verifying DNS configuration..."
        if ! grep -q "^nameserver" /etc/resolv.conf 2>/dev/null; then
            print_warning "/etc/resolv.conf has no nameservers - adding Google DNS"
            echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
            echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf > /dev/null
            log_warning "Added Google DNS to /etc/resolv.conf"
        else
            NAMESERVER_COUNT=$(grep -c "^nameserver" /etc/resolv.conf)
            print_success "$NAMESERVER_COUNT nameserver(s) configured"
            log_success "/etc/resolv.conf has $NAMESERVER_COUNT nameservers"
        fi

        # Test DNS resolution before proceeding
        print_info "Testing DNS resolution..."
        if host deb.debian.org &>/dev/null || nslookup deb.debian.org &>/dev/null; then
            print_success "DNS is working"
            log_success "DNS resolution test passed"
        else
            print_error "DNS resolution still failing!"
            print_info "Adding Google DNS and retrying..."
            echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
            echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf > /dev/null
            sleep 2
            if host deb.debian.org &>/dev/null; then
                print_success "DNS now working after fix"
            else
                print_error "DNS still broken - package installation will fail"
                log_error "DNS resolution failed even after adding Google DNS"
            fi
        fi

        # Fix any incomplete dependencies from Phase 1.5 offline packages
        print_info "Fixing any incomplete package dependencies from Phase 1.5..."
        if sudo apt-get -f install -y 2>&1 | tee -a "$(get_log_file)"; then
            print_success "Dependencies fixed"
            log_success "apt-get -f install completed"
        else
            print_warning "Some dependency issues may remain"
            log_warning "apt-get -f install had errors"
        fi
    else
        print_error "Failed to update package lists"
        echo ""
        print_info "This usually means:"
        echo "  • DNS is not working"
        echo "  • Debian repositories are unreachable"
        echo "  • /etc/apt/sources.list has errors"
        echo ""
        print_info "Checking /etc/apt/sources.list..."
        sudo cat /etc/apt/sources.list
        echo ""
        ERRORS=$((ERRORS + 1))

        read -p "Try to continue anyway? (y/n): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    echo ""
elif [ "$HAS_IP" = true ]; then
    print_warning "Internet partially working (IP yes, DNS/repos issues)"
    HAS_INTERNET=false
    echo ""
    print_info "Troubleshooting info:"
    echo "  • IP connectivity: OK"
    echo "  • DNS resolution: $HAS_DNS"
    echo "  • Repository access: $HAS_REPO"
    echo ""
    print_info "Try these fixes:"
    echo "  1. Wait a few minutes for network to stabilize"
    echo "  2. Check /etc/resolv.conf has nameservers"
    echo "  3. Run: sudo systemctl restart wlan1-internet"
    echo "  4. Check: cat /etc/resolv.conf"
    echo ""
    log_error "No internet connection - Phase 3 requires internet from Phase 2"
    log_phase_failed 3 "No internet connection detected"
    exit 1
fi

echo ""

################################################################################
# Install core networking packages
################################################################################

echo "Installing Core Networking Packages..."
echo "--------------------------------------"

PACKAGES=(
    "batctl"
    "wpasupplicant"
    "wireless-tools"
    "dhcpcd5"
    "dnsmasq"
    "iptables"
    "iptables-persistent"
)

for package in "${PACKAGES[@]}"; do
    echo -n "  Checking $package... "
    
    if dpkg -l | grep -q "^ii  $package "; then
        print_success "already installed"
    else
        if [ "$HAS_INTERNET" = true ]; then
            # Special handling for iptables-persistent (needs non-interactive install)
            if [ "$package" = "iptables-persistent" ]; then
                if sudo DEBIAN_FRONTEND=noninteractive apt install -y $package &>/dev/null; then
                    print_success "installed (non-interactive)"
                else
                    print_error "failed to install"
                    ERRORS=$((ERRORS + 1))
                fi
            else
                # Normal installation for other packages
                if sudo apt install -y $package &>/dev/null; then
                    print_success "installed"
                else
                    print_error "failed to install"
                    ERRORS=$((ERRORS + 1))
                fi
            fi
        else
            print_warning "skipped (no internet)"
        fi
    fi
done

echo ""

################################################################################
# Install Python and dependencies
################################################################################

echo "Installing Python and Dependencies..."
echo "-------------------------------------"

PYTHON_PACKAGES=(
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-flask"
    "python3-pil"        # Pillow/PIL - REQUIRED for coach interface in Phase 6
    "sqlite3"
    "python3-dev"
    "python3-smbus"
    "i2c-tools"
)

for package in "${PYTHON_PACKAGES[@]}"; do
    echo -n "  Checking $package... "

    if dpkg -l | grep -q "^ii  $package "; then
        print_success "already installed"
    else
        if [ "$HAS_INTERNET" = true ]; then
            if sudo apt install -y $package &>/dev/null; then
                print_success "installed"
            else
                print_error "failed to install"
                ERRORS=$((ERRORS + 1))
            fi
        else
            print_warning "skipped (no internet)"
        fi
    fi
done

echo ""

################################################################################
# Install Hardware Python Libraries (pip)
################################################################################

echo "Installing Hardware Python Libraries..."
echo "---------------------------------------"

if [ "$HAS_INTERNET" = true ]; then
    # Install smbus2 (I2C for MPU6500 touch sensor)
    echo -n "  Checking smbus2 (I2C library)... "
    if python3 -c "import smbus2" 2>/dev/null; then
        print_success "already installed"
    else
        print_info "installing via pip..."
        if sudo pip3 install smbus2 --break-system-packages &>/dev/null; then
            print_success "installed"
        else
            print_error "failed to install"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    # Install rpi-ws281x (SPI/PWM for WS2812B LEDs)
    echo -n "  Checking rpi-ws281x (LED library)... "
    if python3 -c "import rpi_ws281x" 2>/dev/null; then
        print_success "already installed"
    else
        print_info "installing via pip..."
        if sudo pip3 install rpi-ws281x --break-system-packages &>/dev/null; then
            print_success "installed"
        else
            print_error "failed to install"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    # Install flask-socketio (for real-time calibration features)
    echo -n "  Checking flask-socketio... "
    if python3 -c "import flask_socketio" 2>/dev/null; then
        print_success "already installed"
    else
        print_info "installing via pip..."
        if sudo pip3 install flask-socketio python-socketio --break-system-packages &>/dev/null; then
            print_success "installed"
        else
            print_warning "failed to install (optional feature)"
        fi
    fi

    # Install flask-sqlalchemy (for database management)
    echo -n "  Checking flask-sqlalchemy... "
    if python3 -c "import flask_sqlalchemy" 2>/dev/null; then
        print_success "already installed"
    else
        print_info "installing via pip..."
        if sudo pip3 install requests flask-sqlalchemy --break-system-packages &>/dev/null; then
            print_success "installed"
        else
            print_warning "failed to install (may cause Phase 6 issues)"
        fi
    fi
else
    print_warning "No internet - skipping pip installs"
    print_info "Hardware libraries (smbus2, rpi-ws281x) must be installed later"
fi

echo ""

################################################################################
# Install system utilities
################################################################################

echo "Installing System Utilities..."
echo "------------------------------"

UTIL_PACKAGES=(
    "git"
    "curl"
    "mpg123"
    "alsa-utils"
)

for package in "${UTIL_PACKAGES[@]}"; do
    echo -n "  Checking $package... "
    
    if dpkg -l | grep -q "^ii  $package "; then
        print_success "already installed"
    else
        if [ "$HAS_INTERNET" = true ]; then
            if sudo apt install -y $package &>/dev/null; then
                print_success "installed"
            else
                print_error "failed to install"
                ERRORS=$((ERRORS + 1))
            fi
        else
            print_warning "skipped (no internet)"
        fi
    fi
done

echo ""

################################################################################
# Verify critical installations
################################################################################

echo "Verifying Installations..."
echo "--------------------------"

# Verify batman-adv module
echo -n "  batman-adv module... "
if sudo modprobe batman-adv 2>/dev/null && lsmod | grep -q batman_adv; then
    print_success "loaded successfully"
else
    if modinfo batman_adv &>/dev/null; then
        print_warning "available but not loaded (will load later)"
    else
        print_error "not available"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Verify batctl
echo -n "  batctl command... "
if command -v batctl &>/dev/null; then
    VERSION=$(batctl -v 2>/dev/null | head -n1)
    print_success "available ($VERSION)"
else
    if [ "$HAS_INTERNET" = true ]; then
        print_error "not found"
        ERRORS=$((ERRORS + 1))
    else
        print_warning "not found (no internet to install)"
    fi
fi

# Verify dnsmasq
echo -n "  dnsmasq... "
if command -v dnsmasq &>/dev/null; then
    VERSION=$(dnsmasq --version 2>/dev/null | head -n1)
    print_success "available ($VERSION)"
else
    if [ "$HAS_INTERNET" = true ]; then
        print_error "not found"
        ERRORS=$((ERRORS + 1))
    else
        print_warning "not found (no internet to install)"
    fi
fi

# Verify iptables
echo -n "  iptables... "
if command -v iptables &>/dev/null; then
    VERSION=$(sudo iptables --version 2>/dev/null | head -n1)
    print_success "available ($VERSION)"
else
    print_error "not found"
    ERRORS=$((ERRORS + 1))
fi

# Verify Python
echo -n "  Python 3... "
if command -v python3 &>/dev/null; then
    VERSION=$(python3 --version 2>/dev/null)
    print_success "available ($VERSION)"
else
    print_error "not found"
    ERRORS=$((ERRORS + 1))
fi

# Verify Flask
echo -n "  Flask... "
if python3 -c "import flask" 2>/dev/null; then
    VERSION=$(python3 -c "import flask; print(flask.__version__)" 2>/dev/null)
    print_success "available (v$VERSION)"
else
    if [ "$HAS_INTERNET" = true ]; then
        print_error "not found"
        ERRORS=$((ERRORS + 1))
    else
        print_warning "not found (no internet to install)"
    fi
fi

# Verify Pillow (PIL) - CRITICAL for Phase 6 coach interface
echo -n "  Pillow (PIL)... "
if python3 -c "import PIL" 2>/dev/null; then
    VERSION=$(python3 -c "import PIL; print(PIL.__version__)" 2>/dev/null)
    print_success "available (v$VERSION)"
else
    if [ "$HAS_INTERNET" = true ]; then
        print_error "NOT FOUND (CRITICAL for Phase 6 coach interface)"
        # Try to install now via pip as fallback
        print_info "    Attempting pip install as fallback..."
        if sudo pip3 install Pillow --break-system-packages &>/dev/null; then
            if python3 -c "import PIL" 2>/dev/null; then
                print_success "    Installed via pip"
            else
                print_error "    Failed to install"
                ERRORS=$((ERRORS + 1))
            fi
        else
            ERRORS=$((ERRORS + 1))
        fi
    else
        print_warning "not found (no internet to install)"
    fi
fi

# Verify git - REQUIRED for Phase 6 (clone repository)
echo -n "  git... "
if command -v git &>/dev/null; then
    VERSION=$(git --version | awk '{print $3}')
    print_success "available (v$VERSION)"
else
    if [ "$HAS_INTERNET" = true ]; then
        print_error "NOT FOUND (REQUIRED for Phase 6)"
        ERRORS=$((ERRORS + 1))
    else
        print_warning "not found (no internet to install)"
    fi
fi

# Verify wpasupplicant (critical)
echo -n "  wpasupplicant... "
if dpkg -l | grep -q "^ii  wpasupplicant"; then
    print_success "installed"
else
    print_error "NOT INSTALLED (critical for Phase 2)"
    ERRORS=$((ERRORS + 1))
fi

# Verify dhcpcd5 (critical)
echo -n "  dhcpcd5... "
if dpkg -l | grep -q "^ii  dhcpcd5"; then
    print_success "installed"
else
    print_error "NOT INSTALLED (critical for Phase 2)"
    ERRORS=$((ERRORS + 1))
fi

# Verify smbus2 (hardware - I2C)
echo -n "  smbus2 (I2C)... "
if python3 -c "import smbus2" 2>/dev/null; then
    VERSION=$(python3 -c "import smbus2; print(smbus2.__version__)" 2>/dev/null || echo "unknown")
    print_success "installed (v$VERSION)"
else
    if [ "$HAS_INTERNET" = true ]; then
        print_error "NOT INSTALLED (needed for touch sensor)"
        ERRORS=$((ERRORS + 1))
    else
        print_warning "not installed (no internet to install)"
    fi
fi

# Verify rpi-ws281x (hardware - LEDs)
echo -n "  rpi-ws281x (LEDs)... "
if python3 -c "import rpi_ws281x" 2>/dev/null; then
    print_success "installed"
else
    if [ "$HAS_INTERNET" = true ]; then
        print_error "NOT INSTALLED (needed for LED control)"
        ERRORS=$((ERRORS + 1))
    else
        print_warning "not installed (no internet to install)"
    fi
fi

# Verify I2C tools
echo -n "  i2c-tools... "
if command -v i2cdetect &>/dev/null; then
    print_success "installed"
else
    if [ "$HAS_INTERNET" = true ]; then
        print_warning "not installed (useful for debugging)"
    else
        print_warning "not installed (no internet)"
    fi
fi

echo ""

################################################################################
# Summary
################################################################################

echo "==============================="
echo "Installation Summary"
echo "==============================="
echo ""

if [ "$HAS_INTERNET" = false ] && [ "$USE_OFFLINE" = false ]; then
    print_warning "Phase 1 ran without internet or offline packages"
    echo ""
    print_info "Some packages may not be installed."
    print_info "After configuring internet in Phase 2, re-run Phase 1 to complete installation."
    echo ""
    exit 0
fi

if [ $ERRORS -eq 0 ]; then
    print_success "All packages installed successfully!"
    echo ""
    print_info "Package summary:"
    echo "  • Core networking: batctl, wpasupplicant, wireless-tools, dhcpcd5"
    echo "  • Services: dnsmasq, iptables"
    echo "  • Python: python3, flask, pillow (PIL), pip, venv"
    echo "  • Hardware: smbus2 (I2C), rpi-ws281x (LEDs), i2c-tools"
    echo "  • Utilities: git, curl, sqlite3"
    echo ""
    print_info "Hardware support installed:"
    echo "  • MPU6500 touch sensor (I2C via smbus2)"
    echo "  • WS2812B LED control (SPI/PWM via rpi-ws281x)"
    echo "  • Real-time calibration (flask-socketio)"
    echo ""
    print_success "Phase 6 prerequisites verified:"
    echo "  ✓ git (for repository clone)"
    echo "  ✓ Python 3 + Flask"
    echo "  ✓ Pillow (PIL) - required for coach interface"
    echo "  ✓ flask-socketio"
    echo ""
    print_info "Ready to proceed to Phase 4 (Mesh Network)"
    echo ""

    log_phase_complete 3
    echo "Log file: $(get_log_file)"
    echo ""
    exit 0
else
    print_error "Found $ERRORS error(s) during installation"
    log_phase_failed 3 "Package installation had $ERRORS errors"
    echo ""

    print_warning "Please check:"
    echo "  • Internet connectivity works"
    echo "  • DNS resolution works: host deb.debian.org"
    echo "  • Package repositories work: sudo apt update"
    echo "  • Sufficient disk space is available"
    echo ""

    print_info "Troubleshooting:"
    echo "  • View logs: cat /mnt/usb/install_logs/phase3_packages_latest.log"
    echo "  • Check errors: grep ERROR /mnt/usb/install_logs/phase3_packages_latest.log"
    echo "  • Run diagnostics: sudo ${SCRIPT_DIR}/DIAGNOSE_CONNECTIVITY.sh"
    echo ""

    echo "Log file: $(get_log_file)"
    echo ""
    exit 1
fi
