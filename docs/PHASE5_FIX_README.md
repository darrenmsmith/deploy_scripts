# Phase 5 (DNS/DHCP) Fix - README

**Date:** 2026-01-04
**Issue:** dnsmasq configuration syntax error due to multi-line IP variable
**Status:** FIXED in main script

---

## The Problem

**Error from diagnostic log:**
```
dnsmasq: bad option at line 22 of /etc/dnsmasq.conf
```

**Invalid configuration created:**
```
dhcp-option=option:router,192.168.99.100
169.254.8.82                                 ← INVALID LINE
dhcp-option=option:dns-server,192.168.99.100
169.254.8.82                                 ← INVALID LINE
```

---

## Root Cause

**The Bug:** Line 64 in `gateway_phases/phase5_dns.sh`

```bash
BAT0_IP=$(ip addr show bat0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
```

**Why it failed:**

bat0 has MULTIPLE IP addresses:
1. `192.168.99.100/24` (primary - correct)
2. `169.254.8.82/16` (link-local - auto-assigned by Linux)

The `grep "inet "` command returns **BOTH lines**, so `$BAT0_IP` becomes a **multi-line variable**:
```
192.168.99.100
169.254.8.82
```

When this variable is used in the heredoc to create dnsmasq.conf:
```bash
dhcp-option=option:router,$BAT0_IP
```

It expands to:
```
dhcp-option=option:router,192.168.99.100
169.254.8.82
```

The standalone `169.254.8.82` line is invalid dnsmasq syntax.

---

## The Fix

**Updated code in `gateway_phases/phase5_dns.sh` (lines 64-71):**

```bash
# Get only the primary IP (exclude link-local 169.254.x.x)
BAT0_IP=$(ip addr show bat0 | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d/ -f1 | head -1)
if [ -z "$BAT0_IP" ]; then
    print_error "No valid IP address found on bat0"
    ERRORS=$((ERRORS + 1))
else
    echo "    bat0 IP: $BAT0_IP"
fi
```

**Key changes:**
1. Added `grep -v "169.254"` to exclude link-local addresses
2. Added `head -1` to ensure only ONE IP is captured
3. Added validation check if IP is empty

**Result:** `$BAT0_IP` is now always a single line: `192.168.99.100`

---

## How to Fix Device0 Prod NOW

### On Device0 Prod, run:

```bash
cd /mnt/usb/ft_usb_build
sudo ./fix_phase5_dnsmasq.sh
```

**This script will:**
1. Backup the broken config
2. Get bat0 primary IP (excluding link-local)
3. Create corrected dnsmasq.conf
4. Test configuration syntax
5. Restart dnsmasq service
6. Verify service is running

**Expected output:**
```
✓✓✓ Phase 5 Fixed Successfully! ✓✓✓

dnsmasq is now providing:
  • DHCP: 192.168.99.101 - 192.168.99.200
  • DNS: Forwarding to 8.8.8.8 and 8.8.4.4
  • Gateway: 192.168.99.100

You can now continue with Phase 6 (NAT/Firewall)
```

---

## What dnsmasq Does

**DHCP Server:**
- Assigns IP addresses to mesh clients (192.168.99.101-200)
- Tells clients Device0 (192.168.99.100) is the gateway
- Lease time: 12 hours

**DNS Server:**
- Provides DNS resolution for mesh clients
- Forwards DNS queries to Google DNS (8.8.8.8, 8.8.4.4)
- Caches DNS responses for faster lookups

**Why It's Important:**
- Client devices (Device1-5) need DHCP for IP addresses
- Client devices need DNS to resolve domain names
- Without dnsmasq, clients would need static IPs and manual DNS config

---

## Technical Details

### Why Link-Local Addresses Exist

**Link-local addresses (169.254.x.x):**
- Automatically assigned by Linux when no DHCP is available
- Used for local network communication without routing
- Valid only on the local network segment
- Should NOT be used for DHCP/DNS gateway configuration

**bat0 has link-local because:**
- batman-adv creates the interface
- Linux kernel auto-assigns 169.254.x.x before we assign 192.168.99.100
- Both addresses coexist on the interface

### Why This Bug Was Subtle

1. **Silent failure:** Script completed, but dnsmasq wouldn't start
2. **Config looked valid:** At first glance, dhcp-option lines look correct
3. **Only visible with syntax test:** `dnsmasq --test` shows the error
4. **Multi-line variable expansion:** Uncommon bash scripting error

---

## Verification

After running the fix script, verify with:

```bash
# Check service is running
sudo systemctl status dnsmasq

# Test configuration syntax
sudo dnsmasq --test

# Check configuration file
sudo grep -v "^#\|^$" /etc/dnsmasq.conf

# Check dnsmasq is listening on bat0
sudo lsof -i :53  # Should show dnsmasq on port 53
sudo lsof -i :67  # Should show dnsmasq on port 67
```

---

## Future Builds

**✓ FIXED in main script:** `gateway_phases/phase5_dns.sh`

Future Device0 builds will:
- Automatically exclude link-local addresses
- Only use the primary bat0 IP (192.168.99.100)
- Generate valid dnsmasq configuration
- No manual intervention needed

---

## Next Steps

### 1. Fix Device0 Prod:
```bash
sudo ./fix_phase5_dnsmasq.sh
```

### 2. Continue with Phase 6 (NAT/Firewall):
```bash
cd /mnt/usb/ft_usb_build
sudo ./ft_build.sh
# Choose option 1: Run Next Phase
```

### 3. Then Phase 7 (Field Trainer Application):
After Phase 6, run Phase 7 to complete the Device0 setup.

---

## Summary

| Item | Status |
|------|--------|
| **Bug identified** | ✓ Multi-line IP variable |
| **Root cause** | ✓ Link-local address included |
| **Main script fixed** | ✓ phase5_dns.sh updated |
| **Fix script created** | ✓ fix_phase5_dnsmasq.sh |
| **Future builds** | ✓ Will work correctly |

---

**Run `sudo ./fix_phase5_dnsmasq.sh` to fix Device0 Prod and continue!**
