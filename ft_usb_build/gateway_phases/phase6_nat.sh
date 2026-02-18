#!/bin/bash

################################################################################
# Phase 5: NAT/Firewall Configuration
# Enables IP forwarding and configures NAT for internet sharing
# Updated: Fixed FORWARD policy and better rule verification
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

ERRORS=0

# USB logging - capture all output to log file
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/phase6_nat_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
ln -sf "$LOG_FILE" "${LOG_DIR}/phase6_nat_latest.log"
echo "========================================" && echo "Field Trainer Installation - Phase 6: NAT/Firewall" && echo "Date: $(date)" && echo "Hostname: $(hostname)" && echo "Log: $LOG_FILE" && echo "========================================"
echo ""

echo "Phase 5: NAT/Firewall Configuration"
echo "===================================="
echo ""
echo "This phase configures NAT (Network Address Translation) to share"
echo "internet from wlan1 to the mesh network (bat0)."
echo ""
echo "Configuration will:"
echo "  • Enable IP forwarding"
echo "  • Protect essential services (SSH, DHCP, DNS)"
echo "  • Set FORWARD policy to ACCEPT"
echo "  • Create MASQUERADE rule (NAT)"
echo "  • Configure FORWARD rules (bat0 ↔ wlan1)"
echo "  • Save rules permanently"
echo ""
echo "IMPORTANT: SSH and wlan1 connectivity will be preserved!"
echo ""
read -p "Press Enter to begin configuration..."
echo ""

################################################################################
# Step 1: Verify Prerequisites
################################################################################

echo "Step 1: Verifying Prerequisites..."
echo "-----------------------------------"

# Check wlan1
echo -n "  wlan1 (internet)... "
if ip link show wlan1 &>/dev/null; then
    WLAN1_IP=$(ip addr show wlan1 | grep "inet " | grep -v "169.254" | awk '{print $2}')
    if [ -n "$WLAN1_IP" ]; then
        print_success "UP with IP $WLAN1_IP"
    else
        print_warning "UP but no IP address"
    fi
else
    print_error "not found"
    ERRORS=$((ERRORS + 1))
fi

# Check bat0
echo -n "  bat0 (mesh)... "
if ip link show bat0 &>/dev/null; then
    BAT0_IP=$(ip addr show bat0 | grep "inet " | grep -v "169.254" | awk '{print $2}')
    if [ -n "$BAT0_IP" ]; then
        print_success "UP with IP $BAT0_IP"
    else
        print_error "UP but no IP address"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_error "not found"
    print_warning "Run Phase 3 (BATMAN Mesh) first"
    ERRORS=$((ERRORS + 1))
fi

# Check iptables
echo -n "  iptables... "
if command -v iptables &>/dev/null; then
    IPTABLES_VERSION=$(iptables --version | head -n1)
    print_success "available ($IPTABLES_VERSION)"
else
    print_error "not found"
    print_info "Install with: sudo apt install -y iptables"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [ $ERRORS -gt 0 ]; then
    print_error "Prerequisites not met. Please fix issues before continuing."
    exit 1
fi

################################################################################
# Step 2: Enable IP Forwarding
################################################################################

echo "Step 2: Enabling IP Forwarding..."
echo "----------------------------------"

# Check current status
CURRENT_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
echo "  Current IP forwarding: $CURRENT_FORWARD"

if [ "$CURRENT_FORWARD" = "1" ]; then
    print_info "IP forwarding already enabled"
else
    print_info "Enabling IP forwarding..."
    if sudo sysctl -w net.ipv4.ip_forward=1 &>/dev/null; then
        print_success "IP forwarding enabled"
    else
        print_error "Failed to enable IP forwarding"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Make permanent
print_info "Making IP forwarding permanent..."

# Check if already in sysctl.conf
if grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
    print_info "Already configured in /etc/sysctl.conf"
else
    # Remove any existing (possibly commented) entries
    sudo sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf 2>/dev/null
    
    # Add new entry
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Added to /etc/sysctl.conf"
    else
        print_error "Failed to update /etc/sysctl.conf"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Verify it's enabled
VERIFY_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$VERIFY_FORWARD" = "1" ]; then
    print_success "IP forwarding verified: enabled"
else
    print_error "IP forwarding verification failed"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 3: Configure NAT (MASQUERADE)
################################################################################

echo "Step 3: Configuring NAT (MASQUERADE)..."
echo "----------------------------------------"

# Check if MASQUERADE rule already exists
print_info "Checking for existing MASQUERADE rule..."
if sudo iptables -t nat -C POSTROUTING -o wlan1 -j MASQUERADE 2>/dev/null; then
    print_info "MASQUERADE rule already exists"
    MASQ_EXISTS=true
else
    print_info "No existing MASQUERADE rule found"
    MASQ_EXISTS=false
fi

# Add MASQUERADE rule if needed
if [ "$MASQ_EXISTS" = false ]; then
    print_info "Adding MASQUERADE rule..."
    if sudo iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE; then
        print_success "MASQUERADE rule added"
    else
        print_error "Failed to add MASQUERADE rule"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_info "Skipping (rule already exists)"
fi

# Verify MASQUERADE rule
print_info "Verifying MASQUERADE rule..."
if sudo iptables -t nat -C POSTROUTING -o wlan1 -j MASQUERADE 2>/dev/null; then
    print_success "MASQUERADE rule verified"
    
    # Show the rule
    echo ""
    print_info "Current MASQUERADE rule:"
    sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE | head -1 | sed 's/^/    /'
else
    print_error "MASQUERADE rule not found after configuration"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 3.5: Protect Essential Services (CRITICAL)
################################################################################

echo "Step 3.5: Protecting Essential Services..."
echo "-------------------------------------------"

print_info "Adding rules to protect SSH, DHCP, DNS..."

# CRITICAL: Set INPUT policy to ACCEPT FIRST (prevents lockout)
INPUT_POLICY=$(sudo iptables -L INPUT | head -1 | grep -o "policy [A-Z]*" | awk '{print $2}')
if [ "$INPUT_POLICY" != "ACCEPT" ]; then
    print_info "Setting INPUT policy to ACCEPT (prevents lockout)..."
    if sudo iptables -P INPUT ACCEPT; then
        print_success "INPUT policy set to ACCEPT"
    else
        print_error "Failed to set INPUT policy - STOPPING to prevent lockout"
        exit 1
    fi
fi

# Allow all established connections (CRITICAL - prevents losing SSH)
if ! sudo iptables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
    if sudo iptables -I INPUT 1 -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
        print_success "INPUT: Allow established connections"
    elif sudo iptables -I INPUT 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
        print_success "INPUT: Allow established connections (conntrack)"
    else
        print_warning "Could not add established connection rule"
    fi
else
    print_info "INPUT: Established connections already allowed"
fi

# Allow SSH (port 22) - CRITICAL for remote access
if ! sudo iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null; then
    if sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT; then
        print_success "INPUT: Allow SSH (port 22)"
    else
        print_warning "Could not add SSH rule"
    fi
else
    print_info "INPUT: SSH already allowed"
fi

# Allow DHCP client (CRITICAL - wlan1 needs to renew IP)
if ! sudo iptables -C INPUT -p udp --sport 67 --dport 68 -j ACCEPT 2>/dev/null; then
    if sudo iptables -A INPUT -p udp --sport 67 --dport 68 -j ACCEPT; then
        print_success "INPUT: Allow DHCP client"
    else
        print_warning "Could not add DHCP client rule"
    fi
else
    print_info "INPUT: DHCP client already allowed"
fi

# Allow loopback (localhost)
if ! sudo iptables -C INPUT -i lo -j ACCEPT 2>/dev/null; then
    if sudo iptables -A INPUT -i lo -j ACCEPT; then
        print_success "INPUT: Allow loopback"
    else
        print_warning "Could not add loopback rule"
    fi
else
    print_info "INPUT: Loopback already allowed"
fi

# Allow all traffic on bat0 (mesh network)
if ! sudo iptables -C INPUT -i bat0 -j ACCEPT 2>/dev/null; then
    if sudo iptables -A INPUT -i bat0 -j ACCEPT; then
        print_success "INPUT: Allow all from bat0 (mesh)"
    else
        print_warning "Could not add bat0 rule"
    fi
else
    print_info "INPUT: bat0 already allowed"
fi

# Allow all traffic on wlan1 (internet connection - be permissive)
if ! sudo iptables -C INPUT -i wlan1 -j ACCEPT 2>/dev/null; then
    if sudo iptables -A INPUT -i wlan1 -j ACCEPT; then
        print_success "INPUT: Allow all from wlan1 (internet)"
    else
        print_warning "Could not add wlan1 rule"
    fi
else
    print_info "INPUT: wlan1 already allowed"
fi

# Allow DHCP client OUTPUT (wlan1 needs to send DHCP requests)
if ! sudo iptables -C OUTPUT -o wlan1 -p udp --sport 68 --dport 67 -j ACCEPT 2>/dev/null; then
    if sudo iptables -A OUTPUT -o wlan1 -p udp --sport 68 --dport 67 -j ACCEPT; then
        print_success "OUTPUT: Allow DHCP requests on wlan1"
    else
        print_warning "Could not add DHCP output rule"
    fi
else
    print_info "OUTPUT: DHCP requests already allowed"
fi

# Set OUTPUT policy to ACCEPT (ensure outgoing traffic works)
OUTPUT_POLICY=$(sudo iptables -L OUTPUT | head -1 | grep -o "policy [A-Z]*" | awk '{print $2}')
if [ "$OUTPUT_POLICY" != "ACCEPT" ]; then
    if sudo iptables -P OUTPUT ACCEPT; then
        print_success "OUTPUT: Policy set to ACCEPT"
    else
        print_warning "Could not set OUTPUT policy"
    fi
else
    print_info "OUTPUT: Policy already ACCEPT"
fi

print_info "Essential services protected"

echo ""

################################################################################
# Step 4: Configure FORWARD Rules
################################################################################

echo "Step 4: Configuring FORWARD Rules..."
echo "-------------------------------------"

# Check current FORWARD policy
FORWARD_POLICY=$(sudo iptables -L FORWARD | head -1 | grep -o "policy [A-Z]*" | awk '{print $2}')
print_info "Current FORWARD policy: $FORWARD_POLICY"

# Set FORWARD policy to ACCEPT if it's DROP
if [ "$FORWARD_POLICY" = "DROP" ]; then
    print_info "Changing FORWARD policy from DROP to ACCEPT..."
    if sudo iptables -P FORWARD ACCEPT; then
        print_success "FORWARD policy set to ACCEPT"
    else
        print_error "Failed to set FORWARD policy"
        ERRORS=$((ERRORS + 1))
    fi
elif [ "$FORWARD_POLICY" = "ACCEPT" ]; then
    print_info "FORWARD policy already set to ACCEPT"
else
    print_warning "Unknown FORWARD policy: $FORWARD_POLICY"
fi

echo ""

# Check how many FORWARD rules exist
EXISTING_BAT0_WLAN1=$(sudo iptables -L FORWARD -v | grep -E "bat0.*wlan1|all.*bat0.*wlan1" | wc -l)
EXISTING_WLAN1_BAT0=$(sudo iptables -L FORWARD -v | grep -E "wlan1.*bat0|all.*wlan1.*bat0" | wc -l)

# Rule 1: bat0 → wlan1 (mesh to internet)
print_info "Configuring bat0 → wlan1 forwarding..."
if [ "$EXISTING_BAT0_WLAN1" -gt 0 ]; then
    print_info "Rule already exists (count: $EXISTING_BAT0_WLAN1)"
else
    print_info "Adding bat0 → wlan1 rule..."
    if sudo iptables -A FORWARD -i bat0 -o wlan1 -j ACCEPT; then
        print_success "Rule added: bat0 → wlan1"
    else
        print_error "Failed to add FORWARD rule (bat0 → wlan1)"
        echo "  Error output:" >&2
        sudo iptables -A FORWARD -i bat0 -o wlan1 -j ACCEPT 2>&1 | head -3
        ERRORS=$((ERRORS + 1))
    fi
fi

# Rule 2: wlan1 → bat0 (established connections back)
print_info "Configuring wlan1 → bat0 forwarding (ESTABLISHED/RELATED)..."
if [ "$EXISTING_WLAN1_BAT0" -gt 0 ]; then
    print_info "Rule already exists (count: $EXISTING_WLAN1_BAT0)"
else
    print_info "Adding wlan1 → bat0 rule..."
    
    # Try with state module first
    if sudo iptables -A FORWARD -i wlan1 -o bat0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
        print_success "Rule added: wlan1 → bat0 (state module)"
    else
        # Fallback to conntrack module
        print_warning "state module failed, trying conntrack..."
        if sudo iptables -A FORWARD -i wlan1 -o bat0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; then
            print_success "Rule added: wlan1 → bat0 (conntrack module)"
        else
            print_error "Failed to add FORWARD rule (wlan1 → bat0)"
            echo "  Error output:" >&2
            sudo iptables -A FORWARD -i wlan1 -o bat0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>&1 | head -3
            ERRORS=$((ERRORS + 1))
        fi
    fi
fi

echo ""

# Verify FORWARD rules
print_info "Verifying FORWARD rules..."

# Check policy again
VERIFY_POLICY=$(sudo iptables -L FORWARD | head -1 | grep -o "policy [A-Z]*" | awk '{print $2}')
echo "  FORWARD policy: $VERIFY_POLICY"

# Count rules
FORWARD_BAT0_WLAN1=$(sudo iptables -L FORWARD -v | grep -E "bat0.*wlan1|all.*bat0.*wlan1" | wc -l)
FORWARD_WLAN1_BAT0=$(sudo iptables -L FORWARD -v | grep -E "wlan1.*bat0|all.*wlan1.*bat0" | wc -l)

echo "  bat0 → wlan1 rules: $FORWARD_BAT0_WLAN1"
echo "  wlan1 → bat0 rules: $FORWARD_WLAN1_BAT0"

if [ "$FORWARD_BAT0_WLAN1" -ge 1 ] && [ "$FORWARD_WLAN1_BAT0" -ge 1 ]; then
    print_success "FORWARD rules verified"
else
    print_error "FORWARD rules incomplete"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 4.5: CRITICAL Safety Check (Verify SSH and Internet Still Work)
################################################################################

echo "Step 4.5: Safety Check - Verifying Connectivity..."
echo "---------------------------------------------------"

# Test internet connectivity through wlan1
echo -n "  Internet (wlan1)... "
if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
    print_success "working"
else
    print_error "FAILED - Internet not working!"
    print_warning "This may cause issues. Rules will still be saved."
fi

# Check if SSH port is accessible
echo -n "  SSH port (22)... "
if sudo netstat -tlpn 2>/dev/null | grep -q ":22 " || sudo ss -tlpn 2>/dev/null | grep -q ":22 "; then
    print_success "listening"
else
    print_warning "SSH may not be listening"
fi

# Verify wlan1 still has IP
echo -n "  wlan1 IP address... "
WLAN1_CHECK=$(ip addr show wlan1 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}')
if [ -n "$WLAN1_CHECK" ]; then
    print_success "$WLAN1_CHECK"
else
    print_error "LOST IP ADDRESS!"
    print_warning "wlan1 may have been affected by iptables rules"
fi

print_info "Connectivity check complete"

echo ""

################################################################################
# Step 5: Save Rules Permanently
################################################################################

echo "Step 5: Saving Rules Permanently..."
echo "------------------------------------"

# Create iptables directory if needed
sudo mkdir -p /etc/iptables

# Try netfilter-persistent first
if command -v netfilter-persistent &>/dev/null; then
    print_info "Using netfilter-persistent to save rules..."
    
    if sudo netfilter-persistent save; then
        print_success "Rules saved via netfilter-persistent"
    else
        print_warning "netfilter-persistent save failed, trying manual method..."
        
        # Fallback to manual save
        if sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null; then
            print_success "Rules saved manually to /etc/iptables/rules.v4"
        else
            print_error "Failed to save rules"
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    # netfilter-persistent not available, use manual method
    print_info "Saving rules manually to /etc/iptables/rules.v4..."
    
    if sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null; then
        print_success "Rules saved to /etc/iptables/rules.v4"
    else
        print_error "Failed to save rules"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Verify saved rules file exists
if [ -f /etc/iptables/rules.v4 ]; then
    FILE_SIZE=$(stat -f%z /etc/iptables/rules.v4 2>/dev/null || stat -c%s /etc/iptables/rules.v4 2>/dev/null)
    print_success "Rules file exists (size: $FILE_SIZE bytes)"
    
    # Check if MASQUERADE is in the saved file
    if sudo grep -q "MASQUERADE" /etc/iptables/rules.v4; then
        print_success "MASQUERADE rule found in saved rules"
    else
        print_warning "MASQUERADE rule not found in saved file"
    fi
    
    # Check if FORWARD policy is saved
    if sudo grep -q ":FORWARD ACCEPT" /etc/iptables/rules.v4; then
        print_success "FORWARD ACCEPT policy found in saved rules"
    else
        print_warning "FORWARD policy may not be saved correctly"
    fi
else
    print_error "Rules file not created"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 6: Configure iptables-persistent (if available)
################################################################################

echo "Step 6: Configuring iptables-persistent..."
echo "-------------------------------------------"

if command -v netfilter-persistent &>/dev/null; then
    print_info "netfilter-persistent is available"
    
    # Enable the service
    if sudo systemctl enable netfilter-persistent &>/dev/null; then
        print_success "netfilter-persistent enabled"
    else
        print_warning "Could not enable netfilter-persistent"
    fi
    
    # Check service status
    if systemctl is-enabled netfilter-persistent &>/dev/null; then
        print_success "netfilter-persistent will restore rules on boot"
    fi
else
    print_warning "netfilter-persistent not available"
    print_info "Rules saved manually - will need to restore on boot"
    
    # Create restore script
    print_info "Creating iptables restore script..."
    
    sudo tee /usr/local/bin/restore-iptables.sh > /dev/null << 'EOF'
#!/bin/bash
# Restore iptables rules on boot
if [ -f /etc/iptables/rules.v4 ]; then
    iptables-restore < /etc/iptables/rules.v4
fi
EOF
    
    sudo chmod +x /usr/local/bin/restore-iptables.sh
    
    # Add to rc.local or create systemd service
    if [ -f /etc/rc.local ]; then
        if ! grep -q "restore-iptables.sh" /etc/rc.local; then
            sudo sed -i '/^exit 0/i /usr/local/bin/restore-iptables.sh' /etc/rc.local
            print_success "Added to /etc/rc.local"
        fi
    fi
fi

echo ""

################################################################################
# Step 7: Verification
################################################################################

echo "Step 7: Final Verification..."
echo "------------------------------"

# IP forwarding
echo -n "  IP forwarding... "
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
    print_success "enabled"
else
    print_error "disabled"
    ERRORS=$((ERRORS + 1))
fi

# INPUT policy
echo -n "  INPUT policy... "
INPUT_POLICY=$(sudo iptables -L INPUT | head -1 | grep -o "policy [A-Z]*" | awk '{print $2}')
if [ "$INPUT_POLICY" = "ACCEPT" ]; then
    print_success "ACCEPT"
elif [ "$INPUT_POLICY" = "DROP" ] || [ "$INPUT_POLICY" = "REJECT" ]; then
    # Check if we have essential INPUT rules
    SSH_RULE=$(sudo iptables -L INPUT -n | grep -c "tcp dpt:22")
    if [ "$SSH_RULE" -ge 1 ]; then
        print_success "$INPUT_POLICY (but SSH protected)"
    else
        print_warning "$INPUT_POLICY (SSH may be blocked!)"
    fi
else
    print_info "$INPUT_POLICY"
fi

# FORWARD policy
echo -n "  FORWARD policy... "
FINAL_POLICY=$(sudo iptables -L FORWARD | head -1 | grep -o "policy [A-Z]*" | awk '{print $2}')
if [ "$FINAL_POLICY" = "ACCEPT" ]; then
    print_success "ACCEPT"
else
    print_error "$FINAL_POLICY (should be ACCEPT)"
    ERRORS=$((ERRORS + 1))
fi

# MASQUERADE rule
echo -n "  MASQUERADE rule... "
if sudo iptables -t nat -C POSTROUTING -o wlan1 -j MASQUERADE 2>/dev/null; then
    print_success "configured"
else
    print_error "not found"
    ERRORS=$((ERRORS + 1))
fi

# FORWARD rules
echo -n "  FORWARD rules... "
FORWARD_BAT0_WLAN1=$(sudo iptables -L FORWARD -v | grep -E "bat0.*wlan1|all.*bat0.*wlan1" | wc -l)
FORWARD_WLAN1_BAT0=$(sudo iptables -L FORWARD -v | grep -E "wlan1.*bat0|all.*wlan1.*bat0" | wc -l)
if [ "$FORWARD_BAT0_WLAN1" -ge 1 ] && [ "$FORWARD_WLAN1_BAT0" -ge 1 ]; then
    print_success "configured (bat0↔wlan1)"
else
    print_error "incomplete (bat0→wlan1: $FORWARD_BAT0_WLAN1, wlan1→bat0: $FORWARD_WLAN1_BAT0)"
    ERRORS=$((ERRORS + 1))
fi

# Essential service protection
echo -n "  SSH protection... "
SSH_RULES=$(sudo iptables -L INPUT -n | grep -c "tcp dpt:22\|ESTABLISHED")
if [ "$SSH_RULES" -ge 1 ]; then
    print_success "protected"
else
    print_warning "not explicitly protected"
fi

# Saved rules
echo -n "  Saved rules... "
if [ -f /etc/iptables/rules.v4 ] && sudo grep -q "MASQUERADE" /etc/iptables/rules.v4 && sudo grep -q ":FORWARD ACCEPT" /etc/iptables/rules.v4; then
    print_success "saved permanently"
else
    print_warning "may not persist after reboot"
fi

echo ""

# Show current NAT rules
print_info "Current NAT POSTROUTING rules:"
sudo iptables -t nat -L POSTROUTING -n -v | sed 's/^/    /'

echo ""

# Show current FORWARD rules
print_info "Current FORWARD chain (policy and rules):"
sudo iptables -L FORWARD -n -v | head -10 | sed 's/^/    /'

echo ""

# Show INPUT protection
print_info "Current INPUT protection:"
sudo iptables -L INPUT -n -v | grep -E "ESTABLISHED|tcp dpt:22|bat0|wlan1" | head -10 | sed 's/^/    /'

echo ""

################################################################################
# Summary
################################################################################

echo "==============================="
echo "Configuration Summary"
echo "==============================="
echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "NAT/Firewall configured successfully!"
    echo ""
    print_info "Configuration details:"
    echo "  • IP forwarding: enabled"
    echo "  • FORWARD policy: ACCEPT"
    echo "  • NAT (MASQUERADE): configured on wlan1"
    echo "  • FORWARD rules: bat0 ↔ wlan1"
    echo "  • INPUT protection: SSH, DHCP, established connections"
    echo "  • Rules saved: /etc/iptables/rules.v4"
    echo ""
    print_info "Mesh clients (Devices 1-5) can now access internet through Device 0"
    echo ""
    print_warning "SSH and essential services are protected from iptables rules"
    echo ""
    print_info "Useful commands:"
    echo "  • Check IP forwarding: cat /proc/sys/net/ipv4/ip_forward"
    echo "  • View NAT rules: sudo iptables -t nat -L -n -v"
    echo "  • View FORWARD rules: sudo iptables -L FORWARD -n -v"
    echo "  • View INPUT rules: sudo iptables -L INPUT -n -v"
    echo "  • View saved rules: sudo cat /etc/iptables/rules.v4"
    echo ""
    print_info "Ready to proceed to Phase 6 (Field Trainer Application)"
    echo ""
    exit 0
else
    print_error "Found $ERRORS error(s) during configuration"
    echo ""
    print_warning "Please resolve issues before continuing"
    echo ""
    print_info "Common issues:"
    echo "  • Check that wlan1 has internet connection"
    echo "  • Check that bat0 is configured (Phase 3)"
    echo "  • Ensure iptables is installed"
    echo ""
    exit 1
fi
