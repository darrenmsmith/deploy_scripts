# Device2-5 Build Checklist

**Date:** 2026-01-04
**Status:** Ready to Build
**Prerequisites:** ✅ Device0 complete, ✅ deploy_scripts ready, ✅ v2026.01.04 released

---

## Pre-Build Verification

### Repositories Ready

- [x] **field-trainer-releases:** v2026.01.04 pushed
  - coach_interface.py: 862 lines ✅
  - Port 5001 fix included ✅
  - https://github.com/darrenmsmith/field-trainer-releases

- [x] **deploy_scripts:** v2026.01.04 pushed
  - All phase scripts with fixes ✅
  - Complete documentation ✅
  - https://github.com/darrenmsmith/deploy_scripts

### Device0 (Gateway) Status

- [x] All phases completed
- [x] Mesh network running (192.168.99.100)
- [x] DNS/DHCP server active
- [x] Port 5000 (Admin) working
- [x] Port 5001 (Coach) working ✅ FIXED
- [x] Port 6000 (Client server) working
- [x] Ready to serve clients

---

## Client Build Process

### Per Device (Device1-5)

**Time Estimate:** 30-40 minutes per device

### Hardware Setup

1. **Raspberry Pi 4B/5** with fresh Raspberry Pi OS
2. **One WiFi adapter** (built-in wlan0)
3. **Touch sensor** (GPIO connected)
4. **LED strip** (connected)
5. **microSD card** (32GB+)
6. **Keyboard, mouse, monitor** (for initial setup)

---

## Device1 Build

### Phase 1: Hardware Configuration

```bash
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts/client_phases

./phase1_hardware.sh
```

**What it does:**
- Detects WiFi adapter (wlan0)
- Sets hostname to **Device1**
- Configures for client mode
- **Duration:** ~3 minutes

**Verify:**
- [ ] Hostname set to Device1: `hostname`
- [ ] wlan0 detected: `ip link show wlan0`

### Phase 2: Internet Connectivity

```bash
./phase2_internet.sh
```

**What it does:**
- Connects to home WiFi
- Verifies internet access
- Required for package downloads
- **Duration:** ~2 minutes

**Verify:**
- [ ] Connected to home WiFi
- [ ] Can ping 8.8.8.8: `ping -c 3 8.8.8.8`

### Phase 3: Package Installation

```bash
./phase3_packages.sh
```

**What it does:**
- Installs batman-adv kernel module
- Installs Python, Flask, audio libraries
- Installs touch sensor dependencies
- Installs LED control libraries
- **Duration:** ~10-15 minutes

**Verify:**
- [ ] batman-adv installed: `modprobe batman-adv && lsmod | grep batman`
- [ ] Python 3 installed: `python3 --version`

### Phase 4: Mesh Network

```bash
./phase4_mesh.sh
```

**What it does:**
- Configures wlan0 for IBSS ad-hoc mode
- Joins BATMAN mesh network
- Gets DHCP IP from Device0 (192.168.99.101)
- Creates systemd service
- **Includes all fixes:**
  - ✅ RF-kill unblock
  - ✅ NetworkManager disable
  - ✅ Auto-diagnostics
- **Duration:** ~5 minutes

**Verify:**
- [ ] batman-mesh service running: `sudo systemctl status batman-mesh`
- [ ] bat0 has IP 192.168.99.101: `ip addr show bat0 | grep "inet "`
- [ ] Can ping gateway: `ping -c 3 192.168.99.100`
- [ ] Can ping internet via gateway: `ping -c 3 8.8.8.8`

### Phase 5: Client Application

```bash
./phase5_client_app.sh
```

**What it does:**
- Clones field-trainer-client application
- Installs touch sensor drivers
- Configures LED strips
- Creates systemd service
- **Duration:** ~10 minutes

**Verify:**
- [ ] field-trainer-client service running: `sudo systemctl status field-trainer-client`
- [ ] Touch sensor responding
- [ ] LEDs working
- [ ] Connects to Device0:6000

### Device1 Complete!

**Final Checks:**
- [ ] Hostname: Device1
- [ ] Mesh IP: 192.168.99.101
- [ ] Can reach gateway
- [ ] Touch sensor working
- [ ] LEDs working
- [ ] Shows up in Device0 admin UI

---

## Device2 Build

**Repeat same process, hostname will be Device2**

Expected DHCP IP: **192.168.99.102**

```bash
# Same commands as Device1
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts/client_phases

./phase1_hardware.sh  # Sets hostname to Device2
./phase2_internet.sh
./phase3_packages.sh
./phase4_mesh.sh
./phase5_client_app.sh
```

**Verify:**
- [ ] Hostname: Device2
- [ ] Mesh IP: 192.168.99.102
- [ ] All other checks same as Device1

---

## Device3 Build

Expected DHCP IP: **192.168.99.103**

```bash
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts/client_phases

./phase1_hardware.sh  # Sets hostname to Device3
./phase2_internet.sh
./phase3_packages.sh
./phase4_mesh.sh
./phase5_client_app.sh
```

**Verify:**
- [ ] Hostname: Device3
- [ ] Mesh IP: 192.168.99.103

---

## Device4 Build

Expected DHCP IP: **192.168.99.104**

```bash
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts/client_phases

./phase1_hardware.sh  # Sets hostname to Device4
./phase2_internet.sh
./phase3_packages.sh
./phase4_mesh.sh
./phase5_client_app.sh
```

**Verify:**
- [ ] Hostname: Device4
- [ ] Mesh IP: 192.168.99.104

---

## Device5 Build

Expected DHCP IP: **192.168.99.105**

```bash
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts/client_phases

./phase1_hardware.sh  # Sets hostname to Device5
./phase2_internet.sh
./phase3_packages.sh
./phase4_mesh.sh
./phase5_client_app.sh
```

**Verify:**
- [ ] Hostname: Device5
- [ ] Mesh IP: 192.168.99.105

---

## Full System Verification

### On Device0 (Gateway)

**Check all clients connected:**

```bash
# Check DHCP leases
cat /var/lib/misc/dnsmasq.leases

# Expected:
# ... 192.168.99.101 Device1 ...
# ... 192.168.99.102 Device2 ...
# ... 192.168.99.103 Device3 ...
# ... 192.168.99.104 Device4 ...
# ... 192.168.99.105 Device5 ...

# Check BATMAN neighbors
sudo batctl n

# Should show 5 neighbors

# Ping all devices
ping -c 1 192.168.99.101  # Device1
ping -c 1 192.168.99.102  # Device2
ping -c 1 192.168.99.103  # Device3
ping -c 1 192.168.99.104  # Device4
ping -c 1 192.168.99.105  # Device5
```

### From Any Client

**Test connectivity:**

```bash
# Ping gateway
ping -c 3 192.168.99.100

# Ping other clients
ping -c 1 192.168.99.101
ping -c 1 192.168.99.102
ping -c 1 192.168.99.103
ping -c 1 192.168.99.104
ping -c 1 192.168.99.105

# Test internet via gateway
ping -c 3 8.8.8.8

# Check mesh status
sudo batctl n  # Should show other devices
```

### Web Interface Test

**Access from your computer:**

```bash
# Admin interface
http://192.168.99.100:5000

# Coach interface
http://192.168.99.100:5001

# Check all devices visible in UI
# Should show Device0-Device5
```

---

## Troubleshooting

### Issue: Phase 4 fails (RF-kill or NetworkManager)

**Solution:** Scripts have auto-fix, but if needed:

```bash
cd ~/deploy_scripts/troubleshooting
./fix_rfkill.sh
```

### Issue: No DHCP IP on bat0

**Check on Device0:**
```bash
sudo systemctl status dnsmasq
cat /var/lib/misc/dnsmasq.leases
```

**Check on client:**
```bash
sudo batctl if  # Should show wlan0
sudo batctl n   # Should show Device0
ip addr show bat0  # Should have IP
```

### Issue: Can't reach gateway

**Verify mesh:**
```bash
sudo systemctl status batman-mesh
sudo batctl n
iw dev wlan0 info  # Should show IBSS mode
```

### Issue: Touch sensor not working

**Check GPIO:**
```bash
sudo systemctl status field-trainer-client
sudo journalctl -u field-trainer-client -n 50
```

---

## Expected Final State

### Device0 (Gateway)
- **Hostname:** Device0
- **Mesh IP:** 192.168.99.100
- **Role:** Gateway, DNS/DHCP, App Server
- **Services:** batman-mesh, dnsmasq, field-trainer
- **Ports:** 5000 (Admin), 5001 (Coach), 6000 (Client server)

### Device1 (Client)
- **Hostname:** Device1
- **Mesh IP:** 192.168.99.101 (DHCP)
- **Role:** Touch sensor, LED, Audio
- **Services:** batman-mesh, field-trainer-client
- **Hardware:** Touch sensor, LED strip

### Device2 (Client)
- **Hostname:** Device2
- **Mesh IP:** 192.168.99.102 (DHCP)
- **Role:** Touch sensor, LED, Audio
- **Services:** batman-mesh, field-trainer-client
- **Hardware:** Touch sensor, LED strip

### Device3 (Client)
- **Hostname:** Device3
- **Mesh IP:** 192.168.99.103 (DHCP)
- **Role:** Touch sensor, LED, Audio
- **Services:** batman-mesh, field-trainer-client
- **Hardware:** Touch sensor, LED strip

### Device4 (Client)
- **Hostname:** Device4
- **Mesh IP:** 192.168.99.104 (DHCP)
- **Role:** Touch sensor, LED, Audio
- **Services:** batman-mesh, field-trainer-client
- **Hardware:** Touch sensor, LED strip

### Device5 (Client)
- **Hostname:** Device5
- **Mesh IP:** 192.168.99.105 (DHCP)
- **Role:** Touch sensor, LED, Audio
- **Services:** batman-mesh, field-trainer-client
- **Hardware:** Touch sensor, LED strip

---

## Build Progress Tracker

### Device0 (Gateway)
- [x] Hardware configured
- [x] Internet connectivity
- [x] Packages installed
- [x] Mesh network setup
- [x] DNS/DHCP configured
- [x] NAT routing configured
- [x] Field Trainer app installed
- [x] All ports working (5000, 5001, 6000)
- [x] **Status: COMPLETE ✅**

### Device1 (Client)
- [ ] Phase 1: Hardware
- [ ] Phase 2: Internet
- [ ] Phase 3: Packages
- [ ] Phase 4: Mesh network
- [ ] Phase 5: Client app
- [ ] Verification complete
- [ ] **Status: PENDING**

### Device2 (Client)
- [ ] Phase 1: Hardware
- [ ] Phase 2: Internet
- [ ] Phase 3: Packages
- [ ] Phase 4: Mesh network
- [ ] Phase 5: Client app
- [ ] Verification complete
- [ ] **Status: PENDING**

### Device3 (Client)
- [ ] Phase 1: Hardware
- [ ] Phase 2: Internet
- [ ] Phase 3: Packages
- [ ] Phase 4: Mesh network
- [ ] Phase 5: Client app
- [ ] Verification complete
- [ ] **Status: PENDING**

### Device4 (Client)
- [ ] Phase 1: Hardware
- [ ] Phase 2: Internet
- [ ] Phase 3: Packages
- [ ] Phase 4: Mesh network
- [ ] Phase 5: Client app
- [ ] Verification complete
- [ ] **Status: PENDING**

### Device5 (Client)
- [ ] Phase 1: Hardware
- [ ] Phase 2: Internet
- [ ] Phase 3: Packages
- [ ] Phase 4: Mesh network
- [ ] Phase 5: Client app
- [ ] Verification complete
- [ ] **Status: PENDING**

---

## Success Criteria

**System Complete When:**

- [x] Device0 fully operational
- [ ] Device1 joins mesh, all hardware working
- [ ] Device2 joins mesh, all hardware working
- [ ] Device3 joins mesh, all hardware working
- [ ] Device4 joins mesh, all hardware working
- [ ] Device5 joins mesh, all hardware working
- [ ] All devices visible in admin UI
- [ ] All touch sensors responding
- [ ] All LEDs functioning
- [ ] Mesh network stable
- [ ] Internet access working on all devices
- [ ] Field Trainer application functional

---

## Quick Command Reference

**Clone build scripts:**
```bash
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts/client_phases
```

**Run all phases (if no errors):**
```bash
./phase1_hardware.sh && \
./phase2_internet.sh && \
./phase3_packages.sh && \
./phase4_mesh.sh && \
./phase5_client_app.sh
```

**Check status:**
```bash
hostname  # Should be Device1, Device2, etc.
ip addr show bat0 | grep inet  # Should have 192.168.99.x
ping 192.168.99.100  # Gateway
sudo systemctl status batman-mesh field-trainer-client
```

---

## Notes

- All scripts include error handling and diagnostics
- If any phase fails, check logs in `/tmp/`
- Troubleshooting scripts available in `~/deploy_scripts/troubleshooting/`
- Documentation available in `~/deploy_scripts/docs/`
- Each device build is independent (can build in parallel if you have multiple SD cards)

---

**Ready to Build Device1-5!**

All prerequisites met:
✅ Scripts tested and working
✅ All bugs fixed
✅ Documentation complete
✅ Device0 operational
✅ Repeatable build process

Good luck with the builds! 🚀
