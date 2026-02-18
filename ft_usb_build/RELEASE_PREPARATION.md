# Release Preparation - Fix Coach Interface Issue

**Date:** 2026-01-04
**Release Version:** 2025.01.04 (suggested)
**Repositories:**
- Application: `field-trainer-releases`
- Build Scripts: `deploy_scripts`

---

## 1. Create New Release in field-trainer-releases

### Current Status

**Problem:**
- Current releases/main has broken coach_interface.py (2049 lines, bad import)
- Need to release current working version (862 lines)

### Files to Include in Release

**From /opt (Dev system):**

#### Critical Files (MUST be correct):
- ✓ coach_interface.py (862 lines) - PRIMARY FIX
- ✓ field_trainer_main.py (current version)
- ✓ field_trainer_web.py
- ✓ field_trainer_core.py
- ✓ field_client_connection.py

#### field_trainer/ module:
- ✓ All .py files in /opt/field_trainer/
- ✓ __init__.py
- ✓ db_manager.py
- ✓ ft_*.py files
- ✓ All subdirectories (audio/, calibration/, config/, etc.)

#### Templates:
- ✓ /opt/templates/ (complete directory)
- ✓ Especially templates/coach/ for coach interface

#### Data files:
- ✓ courses.json (if exists)
- ✓ Initial database schema

### Verification Checklist

Before pushing release:

```bash
cd /opt

# 1. Verify coach_interface.py
wc -l coach_interface.py
# Must show: 862 lines

grep "settings_manager" coach_interface.py
# Must return: nothing (no matches)

# 2. Test import
python3 -c "import sys; sys.path.insert(0, '.'); import coach_interface; print('✓')"
# Must succeed

# 3. Check for any bad imports in all files
find . -name "*.py" -exec grep -l "settings_manager" {} \;
# Should return nothing

# 4. Verify all templates exist
ls templates/coach/
# Should list all template files

# 5. Test main app can start
python3 field_trainer_main.py --help
# Should show help without errors
```

### Create Release

```bash
cd /opt

# Verify current state
git status
git log -1 --oneline

# Create release tag
git tag -a v2025.01.04 -m "Fix: Remove broken settings_manager import from coach_interface.py

- coach_interface.py: Fixed to 862-line working version
- Removed non-existent settings_manager dependency
- Port 5001 (Coach interface) now starts correctly
- All build fixes included
- Tested on Device0"

# Push to releases repository
git push releases main:main
git push releases v2025.01.04

# Verify
git ls-remote releases
```

### Alternative: Cherry-pick Specific Files

If you don't want to push everything:

```bash
# Create clean release branch
git checkout -b release-2025.01.04

# Reset to last known good release
git reset --hard releases/main

# Copy only the fixed files
cp /opt/coach_interface.py .
cp /opt/field_trainer_main.py .
# ... etc

# Commit
git add coach_interface.py field_trainer_main.py
git commit -m "Fix coach interface and update main"

# Push
git push releases release-2025.01.04:main
git tag v2025.01.04
git push releases v2025.01.04
```

---

## 2. Push Build Scripts to deploy_scripts Repository

### Repository Setup

**URL:** `https://github.com/darrenmsmith/deploy_scripts.git`

**Purpose:** Deployment and build automation

**Structure:**
```
deploy_scripts/
├── README.md
├── gateway_phases/
│   ├── phase1_hardware.sh
│   ├── phase2_internet.sh
│   ├── phase3_packages.sh
│   ├── phase4_mesh.sh         ← WITH FIXES
│   ├── phase5_dns.sh           ← WITH FIXES
│   ├── phase6_nat.sh
│   └── phase7_fieldtrainer.sh
├── client_phases/
│   ├── phase1_hardware.sh
│   ├── phase2_internet.sh
│   ├── phase3_packages.sh
│   └── phase4_mesh.sh          ← WITH FIXES
├── docs/
│   ├── AUTO_DIAGNOSTICS_SUMMARY.md
│   ├── PHASE5_FIX_README.md
│   ├── LINK_LOCAL_EXPLANATION.md
│   └── COACH_INTERFACE_FIX_SUMMARY.md
└── troubleshooting/
    ├── check_phase5_error.sh
    ├── diagnose_port5001_failure.sh
    ├── fix_coach_interface_file.sh
    └── verify_fix_status.sh
```

### Files to Push from USB

From `/mnt/usb/ft_usb_build/`:

```bash
# Create local git repo
cd /tmp
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts

# Copy gateway phases
mkdir -p gateway_phases
cp /mnt/usb/ft_usb_build/gateway_phases/*.sh gateway_phases/

# Copy client phases
mkdir -p client_phases
cp /mnt/usb/ft_usb_build/client_phases/*.sh client_phases/

# Copy documentation
mkdir -p docs
cp /mnt/usb/ft_usb_build/AUTO_DIAGNOSTICS_SUMMARY.md docs/
cp /mnt/usb/ft_usb_build/PHASE5_FIX_README.md docs/
cp /mnt/usb/ft_usb_build/LINK_LOCAL_EXPLANATION.md docs/
cp /mnt/usb/ft_usb_build/COACH_INTERFACE_FIX_SUMMARY.md docs/
cp /mnt/usb/ft_usb_build/COMBINED_BUILD_GUIDE.md docs/

# Copy troubleshooting scripts
mkdir -p troubleshooting
cp /mnt/usb/ft_usb_build/check_phase5_error.sh troubleshooting/
cp /mnt/usb/ft_usb_build/diagnose_port5001_failure.sh troubleshooting/
cp /mnt/usb/ft_usb_build/fix_coach_interface_file.sh troubleshooting/
cp /mnt/usb/ft_usb_build/verify_fix_status.sh troubleshooting/
cp /mnt/usb/ft_usb_build/fix_phase5_dnsmasq.sh troubleshooting/

# Create README
cat > README.md << 'EOF'
# Field Trainer Deployment Scripts

Raspberry Pi build automation for Field Trainer mesh network system.

## Overview

This repository contains phase-based installation scripts for deploying Field Trainer on Raspberry Pi devices in a mesh network configuration.

### Device Types

- **Gateway (Device0):** DNS/DHCP server, NAT router, application server
- **Clients (Device1-5):** Mesh nodes with touch sensors and LEDs

## Quick Start

### Gateway Build

```bash
# On fresh Raspberry Pi OS
cd ~
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts/gateway_phases

# Run phases in order:
./phase1_hardware.sh
./phase2_internet.sh
./phase3_packages.sh
./phase4_mesh.sh
./phase5_dns.sh
./phase6_nat.sh
./phase7_fieldtrainer.sh
```

### Client Build

```bash
cd ~/deploy_scripts/client_phases

./phase1_hardware.sh
./phase2_internet.sh
./phase3_packages.sh
./phase4_mesh.sh
```

## Gateway Phases

1. **Phase 1 - Hardware:** Configure WiFi adapters, set hostname
2. **Phase 2 - Internet:** Ensure internet connectivity via wlan1
3. **Phase 3 - Packages:** Install batman-adv, Flask, Python deps
4. **Phase 4 - Mesh:** Configure BATMAN mesh on wlan0
5. **Phase 5 - DNS/DHCP:** Install dnsmasq for mesh clients
6. **Phase 6 - NAT:** Configure routing and NAT for internet sharing
7. **Phase 7 - Field Trainer:** Clone app, install service

## Client Phases

1. **Phase 1 - Hardware:** Configure WiFi, set hostname
2. **Phase 2 - Internet:** Ensure connectivity
3. **Phase 3 - Packages:** Install batman-adv, Python deps
4. **Phase 4 - Mesh:** Join mesh network, get DHCP

## Key Fixes Included

### Phase 4 (Mesh Network)
- ✓ RF-kill unblock (WiFi blocked by default)
- ✓ NetworkManager disable (prevents interference)
- ✓ Idempotent IP assignment (no "address exists" errors)
- ✓ Auto-diagnostics on failure

### Phase 5 (DNS/DHCP)
- ✓ Link-local address filtering (169.254.x.x)
- ✓ Prevents multi-line IP variable bug in dnsmasq config

### Phase 7 (Field Trainer)
- ✓ Clones correct version from field-trainer-releases
- ✓ Working coach_interface.py (no broken imports)
- ✓ Port 5001 starts correctly

## Troubleshooting

See `/troubleshooting/` directory for diagnostic and fix scripts:

- `check_phase5_error.sh` - Diagnose DNS/DHCP issues
- `diagnose_port5001_failure.sh` - Check Coach interface
- `fix_coach_interface_file.sh` - Replace broken coach file
- `fix_phase5_dnsmasq.sh` - Fix dnsmasq config

## Documentation

See `/docs/` directory for detailed information:

- `AUTO_DIAGNOSTICS_SUMMARY.md` - Auto-diagnostic features
- `PHASE5_FIX_README.md` - Link-local address issue
- `COACH_INTERFACE_FIX_SUMMARY.md` - Port 5001 fix
- `COMBINED_BUILD_GUIDE.md` - Complete build guide

## Requirements

- Raspberry Pi 4B or 5 (4GB+ RAM)
- Raspberry Pi OS (Bookworm or later)
- Two WiFi interfaces (built-in + USB adapter recommended)
- For Gateway: 2.4GHz and 5GHz capable adapters

## Support

For issues, see troubleshooting scripts or documentation.

## Version

Last updated: 2026-01-04
Includes all fixes through Device0 Prod deployment
EOF

# Commit and push
git add .
git commit -m "Initial commit: Complete build scripts with all fixes

- Gateway phases 1-7 with mesh, DNS, NAT, and app deployment
- Client phases 1-4 for mesh joining
- All fixes: RF-kill, NetworkManager, link-local filtering, coach interface
- Auto-diagnostics in Phase 4
- Troubleshooting and fix scripts
- Complete documentation"

git push origin main
```

---

## 3. Update Phase 7 to Use New Release

After creating the new release, update `phase7_fieldtrainer.sh`:

```bash
# Line 27: Update to use specific tag
DEFAULT_BRANCH="v2025.01.04"  # Instead of "main"

# Or add option for user to choose:
BRANCH_NAME="${1:-v2025.01.04}"
```

---

## 4. Testing Before Device1-5 Build

**Test the complete build process:**

```bash
# 1. Fresh Raspberry Pi OS on test device

# 2. Clone deploy scripts
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts

# 3. Run gateway or client phases

# 4. Verify port 5001 works:
curl -s -o /dev/null -w "%{http_code}" http://localhost:5001
# Should return: 200 or 302

# 5. Verify no settings_manager errors:
sudo journalctl -u field-trainer-server | grep -i error
# Should be clean
```

---

## Summary

### Action Items

1. **Release field-trainer-releases:**
   - [ ] Push current working files to releases repo
   - [ ] Tag as v2025.01.04
   - [ ] Verify coach_interface.py is 862 lines
   - [ ] Test fresh clone and import

2. **Push deploy_scripts:**
   - [ ] Copy all build scripts from USB
   - [ ] Organize into gateway/client/docs/troubleshooting
   - [ ] Create README.md
   - [ ] Commit and push

3. **Update Phase 7:**
   - [ ] Set DEFAULT_BRANCH="v2025.01.04"
   - [ ] Test clone and deployment

4. **Verify:**
   - [ ] Fresh build test on clean device
   - [ ] Port 5001 works
   - [ ] No import errors
   - [ ] Ready for Device1-5 builds

### Expected Result

- ✓ Repeatable build process
- ✓ All fixes included by default
- ✓ Separate app and build script repos
- ✓ Versioned releases
- ✓ Confidence in Device1-5 deployment
