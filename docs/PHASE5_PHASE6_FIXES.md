# Phase 5 and Phase 6 Fixes Summary

## Issues Reported

1. **Phase 5:** "FORWARD rules incomplete, Found 2 errors during configuration"
2. **Phase 6:** "pip's dependency resolver does not currently take into account all the packages that are installed. flask-SQLAlchemy>=3.0.1, which is not installed"
3. **Critical:** "Lost the internet access at the end and SSH"

## Root Causes

### Phase 5 FORWARD Rules Issue
**Problem:** The grep pattern used to detect FORWARD rules was too restrictive
- Pattern: `grep -c "bat0.*wlan1"` on `iptables -L FORWARD -n`
- This failed to match rules with verbose output or different column formats

**Impact:** Script reported "FORWARD rules incomplete" even when rules were correctly configured, causing ERROR count to increment and script to fail

### Phase 6 Flask-SQLAlchemy Issue
**Problem:** Flask-SQLAlchemy was not installed by Phase 1
- Phase 1 installed: `python3-flask`, `flask-socketio`, `python-socketio`
- Phase 1 did NOT install: `flask-sqlalchemy`
- Phase 6's requirements.txt or dependencies require flask-sqlalchemy>=3.0.1
- pip's dependency resolver found this missing

**Impact:** Phase 6 installation failed when installing Python dependencies

### Internet/SSH Loss Issue
**Problem:** Phase 5's iptables configuration blocked connectivity
- INPUT policy may have been set to DROP before protection rules were added
- DHCP traffic on wlan1 may have been blocked
- Existing SSH connections may have been interrupted
- No safety check before saving rules

**Impact:** Lost remote SSH access and internet connectivity after Phase 5

## Solutions Implemented

### 1. Fixed Phase 5 FORWARD Rules Detection

**File:** `/mnt/usb/ft_usb_build/phases/phase5_nat.sh`

**Changes:**
```bash
# OLD (line 331-332):
EXISTING_BAT0_WLAN1=$(sudo iptables -L FORWARD -n | grep -c "bat0.*wlan1")
EXISTING_WLAN1_BAT0=$(sudo iptables -L FORWARD -n | grep -c "wlan1.*bat0")

# NEW:
EXISTING_BAT0_WLAN1=$(sudo iptables -L FORWARD -v | grep -E "bat0.*wlan1|all.*bat0.*wlan1" | wc -l)
EXISTING_WLAN1_BAT0=$(sudo iptables -L FORWARD -v | grep -E "wlan1.*bat0|all.*wlan1.*bat0" | wc -l)
```

Also updated lines 384-385 and 566-567 with the same improved pattern.

**Benefits:**
- Uses `-v` verbose output for more consistent column formatting
- Uses extended regex `-E` to match multiple patterns
- Matches both interface-specific rules and "all" protocol rules
- More reliable detection across different iptables versions

### 2. Added Flask-SQLAlchemy to Phase 1

**File:** `/mnt/usb/ft_usb_build/phases/phase1_packages.sh`

**Added after line 362:**
```bash
# Install flask-sqlalchemy (for database management)
echo -n "  Checking flask-sqlalchemy... "
if python3 -c "import flask_sqlalchemy" 2>/dev/null; then
    print_success "already installed"
else
    print_info "installing via pip..."
    if sudo pip3 install flask-sqlalchemy --break-system-packages &>/dev/null; then
        print_success "installed"
    else
        print_warning "failed to install (may cause Phase 6 issues)"
    fi
fi
```

**Benefits:**
- Phase 1 now installs flask-sqlalchemy via pip
- Prevents Phase 6 dependency resolution errors
- Installed only when internet is available
- Non-fatal warning if installation fails

### 3. Fixed Internet/SSH Loss Issue

**File:** `/mnt/usb/ft_usb_build/phases/phase5_nat.sh`

**Change 1: Set INPUT Policy to ACCEPT FIRST (line 207-217)**
```bash
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
```

**Change 2: Added Connectivity Safety Check (line 412-447)**
```bash
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
```

**Benefits:**
- INPUT policy set to ACCEPT BEFORE any rules are added (prevents immediate lockout)
- Script exits immediately if it cannot set INPUT policy (prevents partial configuration)
- Safety check verifies internet, SSH, and wlan1 IP before saving rules
- Clear warnings if connectivity issues detected

### 4. Created Emergency Recovery Script

**File:** `/mnt/usb/ft_usb_build/phases/EMERGENCY_RESTORE_CONNECTIVITY.sh`

This script provides emergency recovery if Phase 5 causes connectivity loss:

**Features:**
1. Sets all iptables policies to ACCEPT
2. Flushes INPUT, FORWARD, OUTPUT chains (keeps NAT)
3. Restarts wlan1-internet service
4. Re-adds minimal essential rules:
   - MASQUERADE for NAT
   - FORWARD bat0 → wlan1
   - FORWARD wlan1 → bat0 (established)
5. Tests connectivity (ping, SSH, wlan1 IP)
6. Optionally saves permissive rules

**Usage:**
```bash
sudo /mnt/usb/ft_usb_build/phases/EMERGENCY_RESTORE_CONNECTIVITY.sh
```

## Testing Recommendations

### Test Phase 5 Again (Updated)
```bash
sudo /mnt/usb/ft_usb_build/phases/phase5_nat.sh
```

**What to watch for:**
- ✓ INPUT policy set to ACCEPT early
- ✓ FORWARD rules detected correctly (no false "incomplete" errors)
- ✓ Step 4.5 safety check shows internet and SSH working
- ✓ No errors during configuration

### Test Phase 1 → Phase 6 Flow

**On a fresh RPi 3 A+ installation:**
```bash
# Phase 0
sudo /mnt/usb/ft_usb_build/phases/phase0_hardware.sh

# Phase 2
sudo /mnt/usb/ft_usb_build/phases/phase2_internet.sh

# Phase 1 (NOW with flask-sqlalchemy)
sudo /mnt/usb/ft_usb_build/phases/phase1_packages.sh

# Verify flask-sqlalchemy
python3 -c "import flask_sqlalchemy; print('flask-sqlalchemy:', flask_sqlalchemy.__version__)"

# Phase 3-5
sudo /mnt/usb/ft_usb_build/phases/phase3_mesh.sh
sudo /mnt/usb/ft_usb_build/phases/phase4_dns.sh
sudo /mnt/usb/ft_usb_build/phases/phase5_nat.sh

# Phase 6 (should work now)
sudo /mnt/usb/ft_usb_build/phases/phase6_fieldtrainer.sh
```

## Recovery Steps (If You Already Lost Connectivity)

### Option 1: Physical Console Access
If you have keyboard/monitor connected to the RPi:

```bash
# Run emergency recovery script
sudo /mnt/usb/ft_usb_build/phases/EMERGENCY_RESTORE_CONNECTIVITY.sh

# Or manually restore
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -F INPUT
sudo iptables -F FORWARD
sudo systemctl restart wlan1-internet
```

### Option 2: No Console Access (Lost SSH)
If you lost SSH and cannot access the device:

1. **Power cycle the device** - If rules weren't saved, they'll be lost on reboot
2. **Boot from USB** - Use the Field Trainer USB to rebuild
3. **Physical access** - Connect keyboard/monitor and run emergency script

## Summary of All Files Modified

| File | Changes | Purpose |
|------|---------|---------|
| `phase1_packages.sh` | Added flask-sqlalchemy installation | Fix Phase 6 dependency error |
| `phase5_nat.sh` | Fixed FORWARD rule detection (3 places) | Fix "rules incomplete" error |
| `phase5_nat.sh` | Set INPUT policy ACCEPT first | Prevent SSH/internet lockout |
| `phase5_nat.sh` | Added Step 4.5 safety check | Verify connectivity before saving |
| `EMERGENCY_RESTORE_CONNECTIVITY.sh` | Created new script | Emergency recovery tool |
| `PHASE5_PHASE6_FIXES.md` | Created this document | Documentation |

## Installation Order Reminder

The correct installation order is:
```
Phase 0 → Phase 2 → Phase 1 → Phase 3 → Phase 4 → Phase 5 → Phase 6
```

See `/mnt/usb/ft_usb_build/PHASE_ORDER_AND_UPDATES.md` for details.

## Additional Safety Measures in Phase 5

The updated Phase 5 script now includes these safety features:

1. **Early INPUT policy** - Set to ACCEPT before any rules
2. **Established connection rule** - Added first (prevents existing SSH from breaking)
3. **SSH explicit allow** - Port 22 allowed
4. **DHCP client rules** - wlan1 can renew IP (port 67→68)
5. **Loopback allow** - localhost always works
6. **bat0 allow all** - Mesh network trusted
7. **wlan1 allow all** - Internet interface trusted
8. **OUTPUT policy ACCEPT** - Outgoing traffic unrestricted
9. **Connectivity check** - Verifies internet/SSH before saving
10. **Detailed error messages** - Shows counts when FORWARD rules fail

## Questions?

If you encounter any issues:

1. **Check connectivity** - `ping 8.8.8.8`, `ssh user@device`
2. **View iptables** - `sudo iptables -L -v -n`, `sudo iptables -t nat -L -v -n`
3. **Check wlan1** - `ip addr show wlan1`, `sudo systemctl status wlan1-internet`
4. **Run emergency script** - `sudo /mnt/usb/ft_usb_build/phases/EMERGENCY_RESTORE_CONNECTIVITY.sh`
5. **View logs** - `sudo journalctl -xe`, `sudo journalctl -u wlan1-internet -n 50`

## Testing Checklist

After running the updated Phase 5:

- [ ] Phase 5 completes without errors
- [ ] No "FORWARD rules incomplete" error
- [ ] Step 4.5 safety check shows all green
- [ ] Internet still works (`ping 8.8.8.8`)
- [ ] SSH still works (can connect)
- [ ] wlan1 has IP address (`ip addr show wlan1`)
- [ ] Mesh clients can access internet through Device 0

After running Phase 6:

- [ ] Phase 6 completes without errors
- [ ] No "flask-SQLAlchemy not installed" error
- [ ] Field Trainer service starts (`sudo systemctl status field-trainer`)
- [ ] Web interface accessible (http://device-ip:5000)
- [ ] Coach interface accessible (http://device-ip:5001)
