# Phase 2 dhcpcd Death Issue - Root Cause and Fix

## Problem Summary
dhcpcd dies 5-25 seconds after starting, causing internet connection to fail during Phase 2 stabilization wait and Phase 3 package installation.

## Root Causes Found

### Issue 1: Service uses `-t 30` timeout flag
**File**: `phase2_internet.sh` line 551 (in service creation)
```bash
ExecStartPost=/usr/sbin/dhcpcd -4 -t 30 wlan1
```

The `-t 30` flag makes dhcpcd exit after 30 seconds if it encounters any issue. Combined with `Type=oneshot`, systemd doesn't restart it.

### Issue 2: Service is Type=oneshot
**File**: `phase2_internet.sh` line 510
```bash
[Service]
Type=oneshot
RemainAfterExit=yes
```

This means systemd considers the service "active" even after dhcpcd exits. No automatic restart.

### Issue 3: Manual vs Service Conflict
Phase 2 starts dhcpcd manually (line 422), then creates a service but doesn't use it. If the service gets triggered somehow (watchdog, boot, etc.), it conflicts with manual dhcpcd.

## The Fix

**Change Phase 2 to use systemd service immediately instead of manual processes:**

1. Create service file (as currently done)
2. **Immediately start the service**: `systemctl start wlan1-internet.service`
3. Let systemd manage dhcpcd properly
4. Service monitors and restarts if needed

**Also fix the service file:**
1. Remove `-t 30` timeout flag from dhcpcd
2. Consider changing Type from oneshot to forking or simple
3. Add Restart=on-failure to auto-restart dhcpcd

## Implementation

See attached script modifications.
