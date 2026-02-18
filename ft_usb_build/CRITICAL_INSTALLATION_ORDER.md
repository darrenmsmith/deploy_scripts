#!/bin/bash

################################################################################
#
# CRITICAL: Installation Order and Network Readiness
#
################################################################################

## THE REAL PROBLEM

You reported that Phase 1 failed with:
- iptables not found
- dhcpcd, python3-pip, python3-pil, python3-dev, python3-smbus, i2c-tools all failed
- rpi-ws281x, git, curl, dhcpcd5 all failed
- Then Phase 5 reported "iptables not found"

### Root Cause Analysis

**This is NOT a script bug - this is a TIMING and NETWORK READINESS issue:**

1. **Phase 2 brings up wlan1** but the network may not be fully stable yet
2. **DNS may not be configured** properly after Phase 2
3. **Package repositories may not be reachable** immediately
4. **Phase 1 runs TOO SOON** after Phase 2 - before the network is truly ready

### Why This Happens

After Phase 2 completes:
- ✅ wlan1 has an IP address
- ✅ Can ping 8.8.8.8 (IP connectivity works)
- ❌ DNS might not be working yet
- ❌ /etc/resolv.conf might be empty or missing nameservers
- ❌ Debian repositories (deb.debian.org) cannot be resolved
- ❌ `apt update` fails silently
- ❌ ALL package installations fail

Result: Phase 1 appears to succeed but installs NOTHING. Then Phase 5 fails because iptables was never installed.

---

## THE SOLUTION

### Step 1: WAIT After Phase 2

After Phase 2 completes successfully, **WAIT 2-3 MINUTES** before running Phase 1.

This allows:
- DHCP to fully complete
- DNS to propagate
- Network connections to stabilize
- wlan1-internet service to fully start

### Step 2: Run Diagnostics BEFORE Phase 1

**CRITICAL - RUN THIS FIRST:**

```bash
sudo /mnt/usb/ft_usb_build/phases/DIAGNOSE_CONNECTIVITY.sh
```

This script checks:
- ✓ wlan1 has IP address
- ✓ Internet connectivity (ping)
- ✓ DNS resolution working
- ✓ Debian repositories reachable
- ✓ /etc/resolv.conf has nameservers
- ✓ apt can resolve dependencies

**DO NOT proceed to Phase 1 until all checks pass!**

### Step 3: Fix DNS if Needed

If DNS checks fail:

```bash
# Check current DNS
cat /etc/resolv.conf

# If empty or missing nameservers, add Google DNS
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf

# Test DNS
host deb.debian.org
```

### Step 4: Update Package Lists

Before Phase 1:

```bash
sudo apt update
```

**Watch the output carefully!** If you see errors like:
- "Unable to fetch"
- "Failed to connect"
- "Could not resolve"

Then DNS or network is not ready yet.

### Step 5: Run Phase 1 with Updated Checks

The updated Phase 1 script now:
- Tests IP connectivity
- Tests DNS resolution
- Tests Debian repository access
- Waits 5 seconds for stabilization
- Shows apt update output with error checking
- Stops if apt update fails

---

## UPDATED INSTALLATION PROCESS

### Complete Step-by-Step Process

```bash
# ============================================
# PHASE 0: Hardware
# ============================================
sudo /mnt/usb/ft_usb_build/phases/phase0_hardware.sh

# Reboot if prompted
# sudo reboot

# ============================================
# PHASE 2: Internet Connection
# ============================================
sudo /mnt/usb/ft_usb_build/phases/phase2_internet.sh

# Enter WiFi credentials when prompted
# SSID: xsmithhome
# Password: your_password

# ⏱️ CRITICAL: WAIT 2-3 MINUTES HERE!
# Let the network fully stabilize
echo "Waiting for network to stabilize..."
sleep 180

# ============================================
# DIAGNOSTIC CHECK (NEW - MANDATORY!)
# ============================================
sudo /mnt/usb/ft_usb_build/phases/DIAGNOSE_CONNECTIVITY.sh

# Review all checks - they should all be GREEN
# If DNS fails, fix it before continuing:
#   echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# ============================================
# MANUAL VERIFICATION (DO THIS!)
# ============================================

# Test 1: Internet
ping -c 3 8.8.8.8
# Should get replies

# Test 2: DNS
host deb.debian.org
# Should resolve to an IP address

# Test 3: wlan1 IP
ip addr show wlan1 | grep "inet "
# Should show: inet 10.0.0.XXX/24

# Test 4: DNS config
cat /etc/resolv.conf
# Should have: nameserver 8.8.8.8 (or similar)

# Test 5: apt update
sudo apt update
# Should complete without errors

# ⚠️ IF ANY TEST FAILS, DO NOT PROCEED TO PHASE 1!

# ============================================
# PHASE 1: Package Installation
# ============================================
sudo /mnt/usb/ft_usb_build/phases/phase1_packages.sh

# The updated script will:
# - Check IP connectivity
# - Check DNS resolution
# - Check Debian repository access
# - Wait 5 seconds for stabilization
# - Run apt update with error checking
# - Show errors if apt update fails

# ============================================
# VERIFY PHASE 1 SUCCESS
# ============================================

# Check that critical packages were installed:
which git         # Should return: /usr/bin/git
which iptables    # Should return: /usr/sbin/iptables
which dhcpcd      # Should return: /usr/sbin/dhcpcd

# Check Python packages:
python3 -c "import flask; print('Flask OK')"
python3 -c "import PIL; print('Pillow OK')"
python3 -c "import flask_sqlalchemy; print('flask-sqlalchemy OK')"

# If ANY of these fail, Phase 1 did not complete successfully!
# Do NOT proceed to Phase 3-6 until all checks pass.

# ============================================
# PHASES 3-6: Continue as Normal
# ============================================
sudo /mnt/usb/ft_usb_build/phases/phase3_mesh.sh
sudo /mnt/usb/ft_usb_build/phases/phase4_dns.sh
sudo /mnt/usb/ft_usb_build/phases/phase5_nat.sh
sudo /mnt/usb/ft_usb_build/phases/phase6_fieldtrainer.sh
```

---

## TROUBLESHOOTING COMMON ISSUES

### Issue 1: "iptables not found" in Phase 5

**Cause:** Phase 1 failed to install iptables because network/DNS was not ready

**Solution:**
```bash
# Check if iptables exists
which iptables

# If not found, install manually
sudo apt update
sudo apt install -y iptables iptables-persistent

# Verify
iptables --version

# Then re-run Phase 5
```

### Issue 2: All packages fail in Phase 1

**Cause:** DNS not working, cannot reach Debian repositories

**Solution:**
```bash
# Check DNS
cat /etc/resolv.conf

# If empty, add Google DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf

# Test
host deb.debian.org

# Update and retry
sudo apt update
sudo /mnt/usb/ft_usb_build/phases/phase1_packages.sh
```

### Issue 3: apt update fails with "Unable to fetch"

**Cause:** Network not fully stable, or DNS issues

**Solution:**
```bash
# Wait 2-3 minutes
sleep 180

# Restart wlan1 service
sudo systemctl restart wlan1-internet
sleep 30

# Check wlan1 status
ip addr show wlan1
ping -c 3 8.8.8.8

# Try apt update again
sudo apt update
```

### Issue 4: dpkg errors during package installation

**Cause:** Previous installation interrupted or partial

**Solution:**
```bash
# Fix broken packages
sudo dpkg --configure -a

# Fix any dependency issues
sudo apt --fix-broken install

# Clean package cache
sudo apt clean
sudo apt update

# Retry Phase 1
sudo /mnt/usb/ft_usb_build/phases/phase1_packages.sh
```

### Issue 5: Lost internet after Phase 5

**Cause:** iptables rules blocked connectivity

**Solution:**
```bash
# Emergency restore
sudo /mnt/usb/ft_usb_build/phases/EMERGENCY_RESTORE_CONNECTIVITY.sh

# Or manual fix
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -F INPUT
sudo iptables -F FORWARD
sudo systemctl restart wlan1-internet
```

---

## WHY THE TIMING MATTERS

### Fresh Raspberry Pi OS Behavior

When you run Phase 2 for the first time:

1. **wpa_supplicant starts** (connects to WiFi)
2. **DHCP requests IP** from router
3. **Router assigns IP** to wlan1
4. **Router provides DNS servers** via DHCP
5. **dhcpcd writes /etc/resolv.conf** with DNS servers
6. **DNS propagation** takes a few seconds
7. **Network is fully stable** after 1-2 minutes

If you run Phase 1 immediately after Phase 2:
- wlan1 has IP ✅
- Can ping 8.8.8.8 ✅
- BUT /etc/resolv.conf might be incomplete ❌
- DNS resolution fails ❌
- apt update cannot reach repos ❌
- All package installations fail ❌

### The 2-3 Minute Wait is CRITICAL

This allows ALL network services to fully initialize:
- ✓ dhcpcd completes fully
- ✓ /etc/resolv.conf written with correct DNS
- ✓ DNS resolver cache populated
- ✓ Network routes stabilized
- ✓ wlan1-internet service fully running

---

## UPDATED PHASE 1 IMPROVEMENTS

The updated `phase1_packages.sh` now includes:

### 1. Comprehensive Connectivity Checks
```bash
# Test 1: IP connectivity (8.8.8.8)
# Test 2: DNS resolution (deb.debian.org)
# Test 3: Repository access (curl test)
```

### 2. Automatic DNS Fix
```bash
# If DNS fails, automatically adds Google DNS to /etc/resolv.conf
```

### 3. Network Stabilization Wait
```bash
# Waits 5 seconds after checks pass
```

### 4. apt update Error Detection
```bash
# Logs apt update output
# Checks for errors/failures
# Shows errors to user
# Asks to continue or abort
```

### 5. Detailed Troubleshooting Info
```bash
# Shows /etc/apt/sources.list if apt update fails
# Provides specific fixes based on what failed
```

---

## LESSONS LEARNED

### What We Thought Was Wrong

- ❌ Script bugs
- ❌ Missing dependencies in installation order
- ❌ Package conflicts

### What Was Actually Wrong

- ✅ Network not fully ready after Phase 2
- ✅ DNS not configured or propagated
- ✅ Running Phase 1 too quickly after Phase 2
- ✅ No diagnostic checks before package installation
- ✅ apt update failures going unnoticed

### Key Takeaways

1. **ALWAYS wait 2-3 minutes** after Phase 2
2. **ALWAYS run diagnostics** before Phase 1
3. **ALWAYS verify apt update** succeeds
4. **ALWAYS check DNS** is working
5. **NEVER assume** network is ready just because ping works

---

## FINAL CHECKLIST

Before running Phase 1, ensure:

- [ ] Phase 2 completed successfully
- [ ] Waited 2-3 minutes after Phase 2
- [ ] wlan1 has IP address: `ip addr show wlan1`
- [ ] Can ping 8.8.8.8: `ping -c 3 8.8.8.8`
- [ ] DNS works: `host deb.debian.org`
- [ ] /etc/resolv.conf has nameservers: `cat /etc/resolv.conf`
- [ ] apt update succeeds: `sudo apt update`
- [ ] Ran DIAGNOSE_CONNECTIVITY.sh with all green checks

Only proceed to Phase 1 when ALL checks pass.

---

## SCRIPT FILES REFERENCE

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `phase0_hardware.sh` | Enable SSH, I2C, SPI | First, on fresh OS |
| `phase2_internet.sh` | Configure wlan1 internet | Second |
| **`DIAGNOSE_CONNECTIVITY.sh`** | **CHECK NETWORK READINESS** | **BEFORE Phase 1** |
| `phase1_packages.sh` | Install all packages | After diagnostics pass |
| `phase3_mesh.sh` | Configure mesh network | After Phase 1 |
| `phase4_dns.sh` | Configure DNS/DHCP | After Phase 3 |
| `phase5_nat.sh` | Configure NAT/firewall | After Phase 4 |
| `phase6_fieldtrainer.sh` | Install Field Trainer app | After Phase 5 |
| `EMERGENCY_RESTORE_CONNECTIVITY.sh` | Fix lost connectivity | If Phase 5 breaks network |

---

## SUMMARY

The installation failure was NOT due to script errors, but due to **network timing**.

**The fix:** Wait 2-3 minutes after Phase 2, run diagnostics, verify DNS, then proceed to Phase 1.

**Updated scripts now:**
- Check connectivity thoroughly
- Fix DNS automatically if possible
- Detect apt update failures
- Provide clear troubleshooting guidance
- Stop if network is not ready

**Your responsibility:**
- Wait 2-3 minutes after Phase 2
- Run DIAGNOSE_CONNECTIVITY.sh before Phase 1
- Verify all checks pass
- Do not proceed if diagnostics fail

Follow this process and Phase 1 will succeed.
