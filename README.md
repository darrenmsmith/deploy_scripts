# Field Trainer Deployment Scripts

**Version:** 2026.01.04
**Purpose:** Automated build system for Field Trainer mesh network on Raspberry Pi

---

## Overview

This repository contains phase-based installation scripts for deploying Field Trainer on Raspberry Pi devices in a BATMAN-adv mesh network configuration.

### System Architecture

- **Gateway (Device0):** DNS/DHCP server, NAT router, application server, mesh coordinator
- **Clients (Device1-5):** Mesh nodes with touch sensors, LEDs, and audio

---

## Quick Start

### Gateway Build (Device0)

```bash
# On fresh Raspberry Pi OS
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts/gateway_phases

# Run phases in order:
./phase1_hardware.sh      # Configure hardware, WiFi adapters
./phase2_internet.sh      # Ensure internet connectivity
./phase3_packages.sh      # Install dependencies
./phase4_mesh.sh          # Configure BATMAN mesh network
./phase5_dns.sh           # Install DNS/DHCP server
./phase6_nat.sh           # Configure NAT routing
./phase7_fieldtrainer.sh  # Install Field Trainer application
```

### Client Build (Device1-5)

```bash
cd deploy_scripts/client_phases

./phase1_hardware.sh      # Configure hardware
./phase2_internet.sh      # Ensure connectivity
./phase3_packages.sh      # Install dependencies
./phase4_mesh.sh          # Join mesh network
./phase5_client_app.sh    # Install client application
```

---

## Repository Structure

```
deploy_scripts/
├── README.md                    # This file
├── gateway_phases/              # Gateway (Device0) build scripts
│   ├── phase1_hardware.sh       # Hardware setup
│   ├── phase2_internet.sh       # Internet connectivity
│   ├── phase3_packages.sh       # Package installation
│   ├── phase4_mesh.sh           # Mesh network setup
│   ├── phase5_dns.sh            # DNS/DHCP configuration
│   ├── phase6_nat.sh            # NAT routing
│   ├── phase7_fieldtrainer.sh   # Application deployment
│   └── *.sh                     # Helper functions
│
├── client_phases/               # Client (Device1-5) build scripts
│   ├── phase1_hardware.sh       # Hardware setup
│   ├── phase2_internet.sh       # Internet connectivity
│   ├── phase3_packages.sh       # Package installation
│   ├── phase4_mesh.sh           # Join mesh network
│   └── phase5_client_app.sh     # Install client app
│
├── docs/                        # Documentation
│   ├── AUTO_DIAGNOSTICS_SUMMARY.md
│   ├── PHASE5_FIX_README.md
│   ├── LINK_LOCAL_EXPLANATION.md
│   ├── COACH_INTERFACE_FIX_SUMMARY.md
│   └── COMBINED_BUILD_GUIDE.md
│
└── troubleshooting/             # Diagnostic and fix scripts
    ├── check_phase5_error.sh
    ├── diagnose_port5001_failure.sh
    ├── fix_coach_interface_file.sh
    └── verify_fix_status.sh
```

---

## Gateway Phases (Device0)

### Phase 1: Hardware Configuration
- Detect WiFi adapters (wlan0 for mesh, wlan1 for internet)
- Set hostname to Device0
- Configure adapter assignments
- **Duration:** ~5 minutes

### Phase 2: Internet Connectivity
- Ensure wlan1 connected to home network
- Verify internet access
- Required for package downloads
- **Duration:** ~2 minutes

### Phase 3: Package Installation
- Install batman-adv kernel module
- Install dnsmasq, hostapd
- Install Python 3, Flask, dependencies
- Install batctl, network tools
- **Duration:** ~10-15 minutes

### Phase 4: Mesh Network Setup
- Configure wlan0 for IBSS ad-hoc mode
- Enable BATMAN-adv mesh protocol
- Assign IP: 192.168.99.100/24
- Create systemd service
- **Includes fixes:**
  - ✅ RF-kill unblock (WiFi blocked by default)
  - ✅ NetworkManager disable (prevents interference)
  - ✅ Idempotent IP assignment
  - ✅ Auto-diagnostics on failure
- **Duration:** ~5 minutes

### Phase 5: DNS/DHCP Server
- Install and configure dnsmasq
- DHCP range: 192.168.99.101-120
- DNS forwarding to internet
- **Includes fixes:**
  - ✅ Link-local address filtering (169.254.x.x)
  - ✅ Multi-line IP variable bug fix
- **Duration:** ~3 minutes

### Phase 6: NAT Routing
- Configure iptables NAT
- Enable IP forwarding
- Route mesh traffic to internet via wlan1
- **Duration:** ~3 minutes

### Phase 7: Field Trainer Application
- Clone from field-trainer-releases (v2026.01.04)
- Install Python dependencies
- Create systemd service
- Initialize database
- **Includes fixes:**
  - ✅ Working coach_interface.py (862 lines)
  - ✅ Port 5001 starts correctly
  - ✅ No broken imports
- **Duration:** ~10 minutes

**Total Gateway Build Time:** ~40-50 minutes

---

## Client Phases (Device1-5)

### Phase 1: Hardware Configuration
- Detect WiFi adapter
- Set hostname (Device1, Device2, etc.)
- **Duration:** ~3 minutes

### Phase 2: Internet Connectivity
- Connect to home network for updates
- **Duration:** ~2 minutes

### Phase 3: Package Installation
- Install batman-adv
- Install Python, audio libraries
- Install touch sensor dependencies
- **Duration:** ~10-15 minutes

### Phase 4: Mesh Network
- Join BATMAN mesh via wlan0
- Get DHCP from Device0 (192.168.99.101-120)
- Test mesh connectivity
- **Includes fixes:**
  - ✅ RF-kill unblock
  - ✅ NetworkManager disable
  - ✅ Auto-diagnostics
- **Duration:** ~5 minutes

### Phase 5: Client Application
- Clone field-trainer-client
- Install touch sensor drivers
- Configure LED strips
- Create systemd service
- **Duration:** ~10 minutes

**Total Client Build Time:** ~30-40 minutes

---

## Key Fixes Included

### Phase 4 Mesh Network (All Devices)

**RF-kill Fix:**
```bash
sudo rfkill unblock wifi
```
WiFi is blocked by default on Raspberry Pi OS. This unblocks it.

**NetworkManager Interference:**
```bash
sudo systemctl disable NetworkManager
sudo systemctl stop NetworkManager
sudo systemctl mask NetworkManager
```
NetworkManager resets WiFi to managed mode. We disable it completely.

**Idempotent IP Assignment:**
```bash
if ! ip addr show bat0 | grep -q "192.168.99.100"; then
    sudo ip addr add 192.168.99.100/24 dev bat0
fi
```
Prevents "address already assigned" errors on re-run.

**Auto-Diagnostics:**
On failure, automatically captures:
- RF-kill status
- Interface status
- BATMAN-adv status
- Recent logs
- Saves to `/tmp/phase4_mesh_failure_*.log`

### Phase 5 DNS/DHCP (Gateway Only)

**Link-local Address Filter:**
```bash
BAT0_IP=$(ip addr show bat0 | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d/ -f1 | head -1)
```

The bat0 interface has TWO IP addresses:
- 192.168.99.100 (our static IP)
- 169.254.x.x (Linux auto-assigned link-local)

Previous code captured both, creating multi-line variable that broke dnsmasq config. Now we filter out link-local addresses.

### Phase 7 Field Trainer (Gateway Only)

**Coach Interface Fix:**
- Previous releases had broken coach_interface.py (2049 lines)
- Imported non-existent settings_manager module
- Port 5001 failed to start silently
- **Fixed:** Now uses v2026.01.04 release (862 lines, working imports)

---

## Requirements

### Hardware
- **Raspberry Pi 4B or 5** (4GB+ RAM recommended)
- **Two WiFi interfaces** (Gateway only):
  - Built-in WiFi (wlan0) for mesh
  - USB WiFi adapter (wlan1) for internet
  - Recommended: 2.4GHz + 5GHz capable
- **One WiFi interface** (Clients)
- **microSD card** (32GB+ recommended)
- **Touch sensors** (Clients only)
- **LED strips** (Clients only)

### Software
- **Raspberry Pi OS** (Bookworm 64-bit or later)
- Fresh installation recommended
- Internet connection during build

### Network
- **Home WiFi network** for internet access during build
- **Mesh network** created automatically (192.168.99.0/24)
- **Gateway acts as router** between mesh and internet

---

## Network Configuration

### IP Address Scheme

| Device | Hostname | Mesh IP | Role |
|--------|----------|---------|------|
| Device0 | Device0 | 192.168.99.100 | Gateway, DNS, DHCP, App Server |
| Device1 | Device1 | 192.168.99.101 (DHCP) | Client, Touch sensor, LED |
| Device2 | Device2 | 192.168.99.102 (DHCP) | Client, Touch sensor, LED |
| Device3 | Device3 | 192.168.99.103 (DHCP) | Client, Touch sensor, LED |
| Device4 | Device4 | 192.168.99.104 (DHCP) | Client, Touch sensor, LED |
| Device5 | Device5 | 192.168.99.105 (DHCP) | Client, Touch sensor, LED |

### Ports

| Port | Service | Description |
|------|---------|-------------|
| 5000 | Admin UI | Field Trainer admin interface |
| 5001 | Coach UI | Coach interface (team/athlete management) |
| 6000 | Client Server | Touch sensor data collection |
| 53 | DNS | DNS forwarding (dnsmasq) |
| 67 | DHCP | DHCP server (dnsmasq) |

### Mesh Network Details

- **Protocol:** BATMAN-adv (Layer 2 mesh)
- **Mode:** IBSS ad-hoc
- **SSID:** field-trainer-mesh
- **Channel:** 6 (2.4GHz)
- **IP Range:** 192.168.99.0/24
- **Gateway:** 192.168.99.100

---

## Troubleshooting

### Common Issues

**Issue: WiFi blocked / Mesh not starting**
```bash
# Solution: Run RF-kill fix
sudo rfkill unblock wifi
sudo systemctl restart batman-mesh
```

**Issue: Port 5001 (Coach interface) not accessible**
```bash
# Solution: Run diagnostic
cd troubleshooting
./diagnose_port5001_failure.sh

# If coach_interface.py is broken, fix it:
./fix_coach_interface_file.sh
```

**Issue: Phase 5 dnsmasq syntax error**
```bash
# Solution: Fix link-local IP bug
cd troubleshooting
./fix_phase5_dnsmasq.sh
```

**Issue: Can't ping clients from gateway**
```bash
# Check mesh status
sudo batctl if
sudo batctl n

# Check client got DHCP
# On client: ip addr show bat0
```

### Diagnostic Scripts

Located in `/troubleshooting/`:

- **check_phase5_error.sh** - Diagnose DNS/DHCP issues
- **diagnose_port5001_failure.sh** - Check Coach interface
- **fix_coach_interface_file.sh** - Replace broken coach file
- **fix_phase5_dnsmasq.sh** - Fix dnsmasq config
- **verify_fix_status.sh** - Verify fixes applied

---

## Documentation

Detailed documentation in `/docs/`:

- **AUTO_DIAGNOSTICS_SUMMARY.md** - Auto-diagnostic features
- **PHASE5_FIX_README.md** - Link-local address issue explained
- **COACH_INTERFACE_FIX_SUMMARY.md** - Port 5001 fix details
- **LINK_LOCAL_EXPLANATION.md** - RFC 3927 link-local addressing
- **COMBINED_BUILD_GUIDE.md** - Complete build walkthrough
- **RELEASE_v2026.01.04_SUMMARY.md** - Latest release notes

---

## Build Process Best Practices

### Before Starting
1. ✅ Fresh Raspberry Pi OS installation
2. ✅ Home WiFi credentials ready
3. ✅ Device hostname decided (Device0, Device1, etc.)
4. ✅ Internet connection verified
5. ✅ USB WiFi adapter connected (Gateway only)

### During Build
1. ✅ Run phases in order (don't skip)
2. ✅ Wait for each phase to complete
3. ✅ Check for errors before continuing
4. ✅ Reboot when prompted
5. ✅ Save diagnostic logs if failures occur

### After Build
1. ✅ Verify all services running
2. ✅ Test mesh connectivity
3. ✅ Access web interfaces (ports 5000, 5001)
4. ✅ Test touch sensors (clients)
5. ✅ Document any issues

---

## Testing Checklist

### Gateway (Device0)

- [ ] Phase 1-7 completed without errors
- [ ] batman-mesh service running
- [ ] dnsmasq service running
- [ ] field-trainer service running
- [ ] Port 5000 accessible (Admin UI)
- [ ] Port 5001 accessible (Coach UI)
- [ ] Port 6000 accessible (Client server)
- [ ] bat0 has IP 192.168.99.100
- [ ] Can ping 8.8.8.8 (internet)
- [ ] No errors in `sudo journalctl -u field-trainer`

### Client (Device1-5)

- [ ] Phase 1-5 completed without errors
- [ ] batman-mesh service running
- [ ] field-trainer-client service running
- [ ] bat0 has DHCP IP (192.168.99.101-120)
- [ ] Can ping 192.168.99.100 (gateway)
- [ ] Can ping 8.8.8.8 (internet via gateway)
- [ ] Touch sensor working
- [ ] LED strip working
- [ ] No errors in `sudo journalctl -u field-trainer-client`

---

## Version History

### v2026.01.04 (Current)
- ✅ Fixed coach_interface.py port 5001 issue
- ✅ RF-kill auto-unblock in mesh setup
- ✅ NetworkManager interference fix
- ✅ Link-local IP filtering in Phase 5
- ✅ Auto-diagnostics in Phase 4
- ✅ Idempotent script execution
- ✅ Repeatable build process

### Previous Issues (Now Fixed)
- ❌ Port 5001 not starting (settings_manager import)
- ❌ WiFi blocked by RF-kill
- ❌ NetworkManager resetting wlan0
- ❌ Link-local IPs breaking dnsmasq
- ❌ "Address already assigned" errors

---

## Related Repositories

- **Application:** [field-trainer-releases](https://github.com/darrenmsmith/field-trainer-releases) (v2026.01.04)
- **Development:** [FT_2025](https://github.com/darrenmsmith/FT_2025)
- **Build Scripts:** [deploy_scripts](https://github.com/darrenmsmith/deploy_scripts) (this repo)

---

## Support

For issues or questions:
- Check `/docs/` for detailed documentation
- Check `/troubleshooting/` for diagnostic scripts
- Review phase script comments for inline help
- Check GitHub Issues for known problems

---

## License

Field Trainer is proprietary software. These deployment scripts are provided for authorized users only.

---

## Contributing

This repository contains tested, production-ready build scripts. Changes should:
1. Be tested on fresh Raspberry Pi OS
2. Maintain idempotent execution
3. Include error handling and diagnostics
4. Update documentation
5. Not break existing builds

---

## Quick Reference

**Clone this repo:**
```bash
git clone https://github.com/darrenmsmith/deploy_scripts.git
```

**Build Gateway:**
```bash
cd deploy_scripts/gateway_phases
./phase1_hardware.sh && ./phase2_internet.sh && ./phase3_packages.sh && \
./phase4_mesh.sh && ./phase5_dns.sh && ./phase6_nat.sh && ./phase7_fieldtrainer.sh
```

**Build Client:**
```bash
cd deploy_scripts/client_phases
./phase1_hardware.sh && ./phase2_internet.sh && ./phase3_packages.sh && \
./phase4_mesh.sh && ./phase5_client_app.sh
```

**Check Gateway Status:**
```bash
sudo systemctl status batman-mesh dnsmasq field-trainer
curl http://localhost:5000  # Admin UI
curl http://localhost:5001  # Coach UI
```

**Check Client Status:**
```bash
sudo systemctl status batman-mesh field-trainer-client
ip addr show bat0  # Should have 192.168.99.x IP
ping 192.168.99.100  # Ping gateway
```

---

**Last Updated:** 2026-01-04
**Tested On:** Raspberry Pi OS Bookworm 64-bit
**Status:** Production Ready ✅
