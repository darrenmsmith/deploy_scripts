# Coach Interface Port 5001 Fix - Root Cause Analysis

**Date:** 2026-01-04
**Issue:** Port 5001 (Coach Interface) not accessible on Device0 Prod (192.168.7.232)
**Status:** Root cause identified, fix ready to apply

---

## Root Cause: Wrong Version of coach_interface.py

Device0 Prod has a **broken version** of `coach_interface.py` that was never supposed to be deployed.

### File Comparison

| System | File Size | Modified | Status |
|--------|-----------|----------|--------|
| **Dev** (192.168.7.116) | 31,670 bytes | Jan 1 15:27 | ✓ Working |
| **Prod** (192.168.7.232) | 77,097 bytes | Jan 2 12:31 | ✗ Broken |

### The Problem (Lines 1-30 comparison)

**Dev version (WORKING):**
```python
from flask import Flask, render_template, request, jsonify, redirect, url_for
from datetime import datetime
from typing import Optional
import sys
import os

from field_trainer.db_manager import DatabaseManager
from field_trainer.ft_registry import REGISTRY
```

**Prod version (BROKEN):**
```python
from flask import Flask, render_template, request, jsonify, redirect, url_for, send_from_directory, Response
from datetime import datetime
from typing import Optional
import sys

# Line 23 - THE PROBLEM:
from field_trainer.settings_manager import SettingsManager  # ← MODULE DOESN'T EXIST!
```

### What Happens

1. `field_trainer_main.py` starts successfully
2. It tries to start the coach interface (lines 116-130)
3. Python tries to import `coach_interface` module
4. Import fails: `ModuleNotFoundError: No module named 'field_trainer.settings_manager'`
5. Exception is caught, error is logged
6. Application continues **without starting port 5001**
7. Only ports 5000 and 6000 start successfully

### Diagnostic Evidence

From `port5001_diagnostic_20260104_182756.log`:

**Import test (line 115-121):**
```
Traceback (most recent call last):
  File "<string>", line 1, in <module>
  File "/opt/coach_interface.py", line 23, in <module>
    from field_trainer.settings_manager import SettingsManager
ModuleNotFoundError: No module named 'field_trainer.settings_manager'
```

**Ports listening (lines 33-37):**
```
tcp        0      0 0.0.0.0:5000            0.0.0.0:*               LISTEN      830/python3
```
Only port 5000, **NOT 5001**

**Port test (line 106):**
```
Port 5001: HTTP 000
```
Connection refused - nothing listening

---

## Additional Issue: Missing Systemd Service

The diagnostic also revealed:
```
Unit field-trainer-server.service could not be found.
```

The Field Trainer is running manually (PID 830) instead of via systemd service. This is a separate issue but explains why restarting via `systemctl restart` didn't work - there's no service to restart!

---

## The Fix

### Step 1: Replace the Broken File

Copy the working version from Dev to Prod:

**On Prod (192.168.7.232):**
```bash
cd /mnt/usb/ft_usb_build
./fix_coach_interface_file.sh
```

This script will:
1. ✓ Backup the broken file
2. ✓ Replace with working version (31KB file)
3. ✓ Test import works
4. ✓ Kill current process
5. ✓ Start new process
6. ✓ Verify ports 5000 AND 5001 are listening
7. ✓ Test HTTP connectivity

### Step 2: Verify Success

After running the script, you should see:
```
✓✓✓ SUCCESS! ✓✓✓

Both interfaces are now working:

  Admin:  http://192.168.7.232:5000
  Coach:  http://192.168.7.232:5001
```

Then access from your browser: **http://192.168.7.232:5001**

---

## Why This Happened

**Most likely scenario:**

1. Development work was done creating a new version of `coach_interface.py`
2. This version added new features requiring `settings_manager` module
3. The `settings_manager` module was never created or committed
4. This incomplete version somehow got deployed to Prod on Jan 2
5. The working version (from Jan 1) remained on Dev
6. Prod has been broken since Jan 2

**Evidence:**
- Prod file modified: Jan 2 12:31
- Dev file modified: Jan 1 15:27 (day earlier)
- Prod file is 2.4x larger (more features, incomplete)

---

## Files on USB Drive

1. **coach_interface_working.py** (31KB) - Working version from Dev
2. **fix_coach_interface_file.sh** - Automated fix script
3. **COACH_INTERFACE_FIX_SUMMARY.md** - This document
4. **diagnose_port5001_failure.sh** - Diagnostic script (already run)
5. **port5001_diagnostic_20260104_182756.log** - Diagnostic output

---

## Prevention for Future

### Before Deploying Code to Prod:

1. **Test imports:**
   ```bash
   python3 -c "import coach_interface"
   ```

2. **Check for missing dependencies:**
   ```bash
   grep "^from\|^import" coach_interface.py | grep -v "^#"
   ```

3. **Compare file sizes:**
   ```bash
   ls -lh coach_interface.py
   ```

4. **Run the application locally:**
   ```bash
   python3 field_trainer_main.py
   # Verify both ports 5000 and 5001 start
   ```

5. **Check startup logs:**
   ```bash
   # Look for "Coach interface started on port 5001"
   # Look for any exceptions or errors
   ```

---

## Next Steps After Fix

1. ✓ Run `fix_coach_interface_file.sh` on Prod
2. ✓ Verify port 5001 works from browser
3. Install systemd service on Prod (optional but recommended)
4. Apply Phase 5 dnsmasq fix if needed
5. Complete Device0 verification
6. Build Device1-5 clients

---

## Systemd Service Issue (Separate)

The diagnostic showed no systemd service exists on Prod:
```
Unit field-trainer-server.service could not be found.
```

**Current state:**
- Application runs manually (started by user or rc.local)
- Process PID: 830, running since Jan 4 15:22

**To fix (optional):**
1. Copy service file from Dev or installation scripts
2. Install to `/etc/systemd/system/field-trainer-server.service`
3. Enable and start: `sudo systemctl enable --now field-trainer-server`

But this is **not required** to fix port 5001. The manual process will work fine once we replace the broken file.

---

## Technical Details

### What field_trainer_main.py Does (Lines 116-130)

```python
try:
    import coach_interface as coach_app

    # Call the registration function from coach_interface
    coach_app.register_touch_handler()

    def run_coach_interface():
        coach_app.app.run(host='0.0.0.0', port=5001, use_reloader=False, debug=False)
    coach_thread = threading.Thread(target=run_coach_interface, daemon=True)
    coach_thread.start()
    REGISTRY.log("Coach interface started on port 5001")
except Exception as e:
    REGISTRY.log(f"Failed to start coach interface: {e}", level="error")
```

When `import coach_interface` fails:
- Exception is caught
- Error logged: "Failed to start coach interface: No module named 'field_trainer.settings_manager'"
- Thread never starts
- Port 5001 never opens
- Application continues with only port 5000

---

## Conclusion

**Root Cause:** Wrong version of `coach_interface.py` deployed to Prod with broken import
**Impact:** Port 5001 completely unavailable
**Fix:** Replace with working version from Dev
**Complexity:** Simple file replacement
**Risk:** Low - broken file is backed up
**Expected Result:** Both ports 5000 and 5001 working
