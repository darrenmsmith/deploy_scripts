# Port 5001 (Coach Interface) Fix - Device0 Prod

**Date:** 2026-01-04
**Issue:** Coach interface at port 5001 not accessible on Device0 Prod (192.168.7.232)
**Status:** Fix ready to apply

---

## Problem Summary

When accessing `http://192.168.7.232:5001` from your browser, the page cannot be reached or returns errors.

### Root Cause

The Field Trainer service has **old code loaded in memory**:
- **Service started:** Dec 29, 2025 (6+ days ago)
- **Code last updated:** Jan 1, 2026 (3 days ago)
- **Issue:** Python doesn't reload code until the process restarts

The old version of `coach_interface.py` tried to render a template (`dashboard/index.html`) that doesn't exist, causing crashes. The current version renders `team_list.html` which exists.

---

## Solution: Restart the Service

Simply restart the Field Trainer service to load the current code.

---

## How to Apply Fix on Device0 Prod (192.168.7.232)

### Step 1: Mount the USB Drive

```bash
# If not already mounted
sudo mount /dev/sda1 /mnt/usb
cd /mnt/usb/ft_usb_build
```

### Step 2: Run the Fix Script

```bash
./fix_coach_interface_port5001.sh
```

The script will:
1. Show current service and port status
2. Check for stale code in memory
3. Restart the Field Trainer service
4. Verify both ports (5000 and 5001) are working
5. Test HTTP connectivity to both interfaces
6. Display any startup errors

### Step 3: Verify the Fix

After the script completes, you should see:

```
✓ SUCCESS! Both interfaces are now working:

  Admin Interface:  http://192.168.7.232:5000
  Coach Interface:  http://192.168.7.232:5001

You can now access the Coach interface from your browser!
```

### Step 4: Test from Browser

Open your browser and navigate to:
- **http://192.168.7.232:5001** - Should show the Teams page

---

## What the Script Does

1. **Checks current status:** Shows service state and which ports are listening
2. **Detects stale code:** Compares process start time vs file modification time
3. **Restarts service:** `sudo systemctl restart field-trainer-server`
4. **Verifies ports:** Confirms ports 5000 and 5001 are listening
5. **Tests connectivity:** Makes HTTP requests to both interfaces
6. **Reports results:** Clear success/failure message

---

## Expected Results

### Before Fix
```bash
$ curl http://localhost:5001
curl: (7) Failed to connect to localhost port 5001: Connection refused
```
OR
```bash
$ curl http://localhost:5001
<!doctype html>
<html lang=en>
<title>500 Internal Server Error</title>
...
```

### After Fix
```bash
$ curl http://localhost:5001
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Teams - Field Trainer</title>
...
```

---

## Verification Commands

If you want to manually verify without the script:

```bash
# Check service status
sudo systemctl status field-trainer-server

# Check listening ports
sudo netstat -tulpn | grep ":500"

# Expected output:
# tcp        0      0 0.0.0.0:5000            0.0.0.0:*               LISTEN      <PID>/python3
# tcp        0      0 0.0.0.0:5001            0.0.0.0:*               LISTEN      <PID>/python3

# Test ports locally
curl -I http://localhost:5000
curl -I http://localhost:5001

# Both should return: HTTP/1.1 200 OK or HTTP/1.1 302 FOUND
```

---

## Manual Fix (Alternative)

If you prefer to do it manually:

```bash
# Restart the service
sudo systemctl restart field-trainer-server

# Wait 5 seconds
sleep 5

# Check status
sudo systemctl status field-trainer-server

# Verify ports
sudo netstat -tulpn | grep ":500"
```

---

## Troubleshooting

### If Port 5001 Still Not Working After Restart

1. **Check service logs:**
   ```bash
   sudo journalctl -u field-trainer-server -n 50
   ```

2. **Look for errors:**
   ```bash
   sudo journalctl -u field-trainer-server | grep -i "error\|exception\|failed"
   ```

3. **Check if coach_interface.py exists:**
   ```bash
   ls -l /opt/coach_interface.py
   ```

4. **Check template files:**
   ```bash
   ls -l /opt/templates/coach/
   ```

5. **Check database:**
   ```bash
   ls -l /opt/data/field_trainer.db
   ```

### If Service Fails to Start

Check the service logs for specific errors:
```bash
sudo journalctl -u field-trainer-server --since "5 minutes ago" --no-pager
```

Common issues:
- Missing Python dependencies
- Database file locked or corrupted
- Port already in use by another process
- Template files missing

---

## Why This Happened

The Field Trainer application runs as a long-lived systemd service. When code files are updated:
1. Files on disk are changed ✓
2. Running Python process still has old code in memory ✗
3. Service must be restarted to load new code ✓

This is normal Python behavior - processes don't automatically reload code.

---

## Prevention for Future Updates

When updating Python code files:
1. Make changes to files
2. **Always restart the service:**
   ```bash
   sudo systemctl restart field-trainer-server
   ```
3. Verify the service started successfully
4. Test functionality

---

## Files on USB Drive

- **fix_coach_interface_port5001.sh** - Automated fix script
- **PORT_5001_FIX_README.md** - This documentation

---

## Next Steps After Fix

Once port 5001 is working:
1. ✓ Complete Device0 build verification
2. Apply Phase 5 dnsmasq fix (if not already done)
3. Prepare to build Device1-5 client devices
4. Push all fixes to GitHub repository
