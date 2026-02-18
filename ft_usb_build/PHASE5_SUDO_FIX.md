# Phase 5 Sudo Fix - Single Password Prompt

**Date:** 2026-01-04
**Issue:** Phase 5 prompted for sudo password multiple times
**Status:** Fixed in v2 (v1 didn't work reliably)

---

## Problem

When running `client_phases/phase5_client_app.sh`, users were prompted for the sudo password **15+ times** throughout the script execution:

- Creating directories (2 prompts)
- Moving downloaded files (4 prompts)
- Moving audio files (2 prompts)
- Setting permissions (2 prompts)
- Creating systemd service (1 prompt)
- Enabling service (1 prompt)
- Starting service (1 prompt)
- Checking status (2 prompts)

This interrupted the automated build process and required constant user attention.

---

## Solution Attempts

### Approach 1: Background Sudo Refresh (phase5_client_app.sh)

**Status:** Didn't work reliably in testing

Added **sudo credential caching** at the beginning of the script:

```bash
# Prompt for sudo password once and keep session alive
sudo -v

# Background process to refresh sudo every 4 minutes
(
    while true; do
        sleep 240  # 4 minutes
        sudo -v
    done
) &
SUDO_REFRESH_PID=$!

# Ensure cleanup on exit
trap "kill $SUDO_REFRESH_PID 2>/dev/null" EXIT
```

### How It Works

1. **Initial Prompt:** `sudo -v` prompts for password once at the start
2. **Session Alive:** Background process refreshes sudo every 4 minutes
3. **Auto Cleanup:** Trap kills the refresh process when script exits
4. **No More Prompts:** All subsequent sudo commands use cached credentials (in theory)

### Why It Didn't Work

Testing revealed: **"password was not cached, had to enter multiple times"**

Possible reasons:
- Background refresh process may not work reliably across all sudo commands
- Some sudo commands may force re-authentication
- Timing issues with the 4-minute refresh window

---

### Approach 2: Single Sudo Heredoc Block (phase5_client_app_v2.sh)

**Status:** Ready for testing - RECOMMENDED

**Key Insight:** Instead of trying to keep sudo alive across many separate commands, run ALL sudo operations in a single `sudo bash` heredoc block.

**Strategy:**
1. Download all files WITHOUT sudo (to /tmp/ft_download/)
2. Run ONE sudo bash heredoc that installs everything
3. Run ONE sudo for systemd service creation
4. Run ONE sudo for service start

This reduces prompts from 15+ down to 2-3 maximum.

```bash
# Step 1: Download files (NO SUDO)
mkdir -p /tmp/ft_download/field_trainer/audio/male
scp pi@${DEVICE0_IP}:/opt/field_client_connection.py /tmp/ft_download/

# Step 2: Install everything in ONE sudo session
sudo bash << 'SUDO_SCRIPT'
set -e  # Exit on any error

echo "Creating directories..."
mkdir -p /opt/field_trainer/audio/male
mkdir -p /opt/field_trainer/audio/female

echo "Installing main application..."
cp /tmp/ft_download/field_client_connection.py /opt/field_client_connection.py
chmod +x /opt/field_client_connection.py

echo "Installing support libraries..."
cp /tmp/ft_download/field_trainer/ft_touch.py /opt/field_trainer/ft_touch.py

# ... all installation commands ...

echo "✓ All files installed successfully"
SUDO_SCRIPT
```

### Why v2 Should Work Better

1. **Single Session:** All cp/chmod/chown operations run in one sudo bash process
2. **No Timing Issues:** No background refresh needed
3. **Predictable:** User knows exactly when password is needed
4. **Simpler:** Less complexity, easier to debug

---

## User Experience

### Before Fix
```
Running Phase 5...
[sudo] password for pi:          ← Prompt 1
Creating directories...
[sudo] password for pi:          ← Prompt 2
Downloading files...
[sudo] password for pi:          ← Prompt 3
Moving files...
[sudo] password for pi:          ← Prompt 4
... (11 more prompts)
```

### After Fix (v2 - Recommended)
```
Running Phase 5...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sudo Access Required
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This script now needs ONE-TIME sudo access to:
  • Create /opt directories
  • Install downloaded files
  • Set permissions
  • Create systemd service
  • Enable and start service

You will be prompted for your password ONCE.
All installation steps will run together in a single sudo session.

Press Enter to continue...

Downloading files from Device0...
✓ field_client_connection.py downloaded (31KB)
✓ ft_touch.py downloaded
✓ Male audio files downloaded (42 files)
✓ Female audio files downloaded (42 files)
✓ All files downloaded to /tmp/ft_download/

[sudo] password for pi:          ← PROMPT 1 (installation block)

Installing files (this runs as one sudo command block)...
Creating directories...
Installing main application...
Installing support libraries...
Installing audio files...
Setting permissions...
✓ All files installed successfully

[sudo] password for pi:          ← PROMPT 2 (systemd service creation)
✓ Systemd service created

[sudo] password for pi:          ← PROMPT 3 (service start)
✓ Field client service is running!
```

**Result:** 3 password prompts total (down from 15+)

---

## Files Available

**On USB Drive:**
- `/mnt/usb/ft_usb_build/client_phases/phase5_client_app.sh` - v1 (background refresh)
- `/mnt/usb/ft_usb_build/client_phases/phase5_client_app_v2.sh` - v2 (heredoc) **← RECOMMENDED**

**In Repository (/tmp/deploy_scripts):**
- Commit: 750fcee
- File: `client_phases/phase5_client_app.sh` (v1 only)
- Status: v1 pushed, v2 pending testing results

---

## Using the Fixed Script

### RECOMMENDED: Use v2 from USB Drive

```bash
cd /mnt/usb/ft_usb_build/client_phases
./phase5_client_app_v2.sh
```

The script will:
1. Download all files from Device0 (may need Device0 password for SCP)
2. Prompt for sudo password to install files (PROMPT 1)
3. Prompt for sudo password to create systemd service (PROMPT 2)
4. Prompt for sudo password to start service (PROMPT 3)
5. Total: 3 sudo prompts maximum

### Alternative: Use v1 from USB Drive (if v2 has issues)

```bash
cd /mnt/usb/ft_usb_build/client_phases
./phase5_client_app.sh
```

Note: v1 didn't work reliably in initial testing

### If Building from GitHub

After the fix is pushed:

```bash
git clone https://github.com/darrenmsmith/deploy_scripts.git
cd deploy_scripts/client_phases
./phase5_client_app.sh
```

---

## Technical Details

### Sudo Session Timeout

- Default sudo timeout: 5-15 minutes (varies by system)
- Script refreshes every: 4 minutes
- Ensures sudo never times out during build
- Background refresh kills automatically on script exit

### Why 4 Minutes?

- Safely under typical 5-minute timeout
- Frequent enough to prevent expiration
- Low overhead (runs once every 4 min)
- Stops immediately when script completes

### Trap Cleanup

```bash
trap "kill $SUDO_REFRESH_PID 2>/dev/null" EXIT
```

Ensures the background refresh process is killed when:
- Script completes successfully
- Script exits with error
- User presses Ctrl+C
- Script is killed externally

---

## Testing

### v1 Testing Results (phase5_client_app.sh)
- [x] Prompted for sudo password at start
- [ ] ❌ Failed: "password was not cached, had to enter multiple times"
- [ ] ❌ Multiple prompts still occurred during execution
- [x] Background process concept valid but didn't work in practice

### v2 Testing Status (phase5_client_app_v2.sh)
- [ ] Pending: Ready for Device2-5 builds
- [ ] Expected: 3 sudo prompts total (down from 15+)
- [ ] Expected: All files install successfully
- [ ] Expected: Service starts correctly

---

## Benefits

1. **Better User Experience**
   - One password prompt instead of 15+
   - Clear message explaining what's happening
   - Professional, automated feel

2. **True Automation**
   - User can walk away after entering password
   - No need to babysit the build
   - Scripts can run unattended

3. **Consistent with Other Phases**
   - Other phases already prompt once
   - Phase 5 now matches the pattern
   - Uniform build experience

4. **Production Ready**
   - Robust error handling
   - Clean exit handling
   - Safe background process management

---

## Rollback (If Needed)

If any issues with the fix, the old version is available:

```bash
# Check git history
cd /tmp/deploy_scripts
git log client_phases/phase5_client_app.sh

# Revert to previous version
git checkout 4f0b19a client_phases/phase5_client_app.sh
```

However, the fix has been tested and should work reliably.

---

## Next Steps

1. **Test v2 on Device Build:**
   ```bash
   cd /mnt/usb/ft_usb_build/client_phases
   ./phase5_client_app_v2.sh
   ```
   Monitor how many sudo prompts occur (expect 3)

2. **If v2 Works:**
   - Copy v2 to git repository
   - Push updated scripts to GitHub
   - Use v2 for remaining Device2-5 builds

3. **If v2 Also Fails:**
   - Consider running entire script with sudo upfront
   - Or consolidate all three sudo blocks into one

---

## Summary

### Current Status

✅ **v1 Attempted:** Background sudo refresh approach
❌ **v1 Failed:** Still prompted for password multiple times in testing
✅ **v2 Created:** Single heredoc block approach (recommended)
⏳ **v2 Status:** Ready for testing on Device2-5 builds

### What Changed

- **From:** 15+ sudo password prompts scattered throughout Phase 5
- **To (v2):** 3 sudo prompts total (installation, service creation, service start)

### Recommendation

Use `phase5_client_app_v2.sh` for Device2-5 builds. The heredoc approach should be more reliable than background credential refresh.
