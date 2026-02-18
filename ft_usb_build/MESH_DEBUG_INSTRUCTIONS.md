# Mesh Network Debug Instructions

**Issue:** Client devices not connecting to Device0 mesh after reboot
**Status:** Need to capture diagnostic logs from both sides

---

## Step 1: Capture Device0 Status

**Run on Device0 Prod:**

```bash
cd /mnt/usb/ft_usb_build
sudo ./capture_device0_mesh_status.sh
```

This will create a file: `device0_mesh_status_YYYYMMDD_HHMMSS.log`

The script captures:
- batman-mesh service status and logs
- wlan0 interface configuration
- bat0 interface status
- BATMAN-adv neighbors and originators
- Startup script contents
- Service file contents
- Network configuration
- rfkill status
- Recent error logs

**Output will be saved to USB drive automatically**

---

## Step 2: Capture Client Status

**Which client device are you testing?**
- Device1 = 192.168.99.101
- Device2 = 192.168.99.102
- Device3 = 192.168.99.103
- Device4 = 192.168.99.104
- Device5 = 192.168.99.105

**Copy script to client device:**

```bash
# From Device0, copy to client (replace .101 with your client IP)
scp /mnt/usb/ft_usb_build/capture_client_mesh_status.sh pi@192.168.99.101:/tmp/
```

**SSH to client and run:**

```bash
# SSH to client device
ssh pi@192.168.99.101

# Run diagnostic script
cd /tmp
chmod +x capture_client_mesh_status.sh
sudo ./capture_client_mesh_status.sh
```

This will create a file: `/tmp/client_mesh_status_DeviceN_YYYYMMDD_HHMMSS.log`

The script captures:
- batman-mesh-client service status and logs
- **ALL service logs** (to see what happened during Phase 4 and reboots)
- wlan0 interface configuration
- bat0 interface status
- BATMAN-adv neighbors
- Startup script contents
- Service file contents
- **Manual test of startup script** (to see if it works when run manually)
- Connectivity test to Device0
- Recent error logs

**Copy the log file back to Device0:**

```bash
# On client device, copy log back to Device0 USB
# (The script will show you the exact command at the end)
scp /tmp/client_mesh_status_*.log pi@192.168.99.100:/mnt/usb/ft_usb_build/
```

Or if SSH from client to Device0 doesn't work, you can:
```bash
# Copy to USB drive directly if USB is mounted on client
sudo cp /tmp/client_mesh_status_*.log /mnt/usb/ft_usb_build/
```

---

## Step 3: Review the Logs

**On Device0 Dev (192.168.7.116):**

The logs will be on the USB drive:
- `device0_mesh_status_YYYYMMDD_HHMMSS.log` - Device0 diagnostics
- `client_mesh_status_DeviceN_YYYYMMDD_HHMMSS.log` - Client diagnostics

Review and look for:

### Common Issues to Check:

1. **SSID Mismatch**
   - Device0: Look for `iw dev wlan0 info` → `ssid`
   - Client: Look for `iw dev wlan0 info` → `ssid`
   - Must match exactly

2. **BSSID Mismatch**
   - Device0: Check startup script for `MESH_BSSID`
   - Client: Check startup script for `MESH_BSSID`
   - Must match exactly

3. **Channel/Frequency Mismatch**
   - Device0: Check `MESH_FREQ` in startup script
   - Client: Check `MESH_FREQ` in startup script
   - Must match

4. **Service Not Running**
   - Device0: `batman-mesh.service` should be active
   - Client: `batman-mesh-client.service` should be active

5. **wlan0 Not in IBSS Mode**
   - Both should show `type IBSS` in `iw dev wlan0 info`

6. **batman-adv Module Not Loaded**
   - Both should show `batman_adv` in `lsmod` output

7. **wlan0 Not Added to batman-adv**
   - Both should show `wlan0: active` in `batctl if` output

8. **bat0 Interface Missing**
   - Both should have bat0 interface with IP address
   - Device0: 192.168.99.100/24
   - Client: 192.168.99.101-105/24

9. **Service Logs Show Errors**
   - Check `journalctl` output for error messages
   - Look for failed commands in startup script execution

10. **Manual Script Execution Fails**
    - Client log includes manual run of startup script
    - Check if errors occur when script runs manually

---

## Step 4: Quick Checks Before Full Diagnostic

If you want to do quick checks first:

**On Device0:**
```bash
# Is service running?
sudo systemctl status batman-mesh

# Are there neighbors?
sudo batctl n

# What's wlan0 doing?
iw dev wlan0 info

# What's the SSID?
iw dev wlan0 info | grep ssid
```

**On Client:**
```bash
# Is service running?
sudo systemctl status batman-mesh-client

# Are there neighbors?
sudo batctl n

# What's wlan0 doing?
iw dev wlan0 info

# What's the SSID?
iw dev wlan0 info | grep ssid

# Can I ping Device0?
ping -c 3 192.168.99.100
```

---

## Expected Results (Working System)

**Device0 `batctl n` should show:**
```
[B.A.T.M.A.N. adv 2024.2, MainIF/MAC: wlan0/xx:xx:xx:xx:xx:xx]
IF             Neighbor              last-seen
wlan0          aa:bb:cc:dd:ee:ff     0.123s    ← Client MAC
```

**Client `batctl n` should show:**
```
[B.A.T.M.A.N. adv 2024.2, MainIF/MAC: wlan0/aa:bb:cc:dd:ee:ff]
IF             Neighbor              last-seen
wlan0          xx:xx:xx:xx:xx:xx     0.123s    ← Device0 MAC
```

**Both `iw dev wlan0 info` should show:**
```
type IBSS
ssid <same-ssid-name>
```

**Device0 `ip addr show bat0` should show:**
```
inet 192.168.99.100/24
```

**Client `ip addr show bat0` should show:**
```
inet 192.168.99.101/24  (or .102, .103, etc.)
```

---

## Next Steps After Capturing Logs

Once you have both log files, we can compare:
1. Configuration parameters (SSID, BSSID, frequency)
2. Service execution logs
3. Error messages
4. Whether manual script execution works vs systemd execution

This will tell us exactly why the mesh isn't forming.

---

## Quick Test: Does Manual Startup Work?

**On Client (while diagnostics are running):**

The diagnostic script will automatically test manual execution. Watch the output when it gets to "Step 8: Test Manual Script Execution"

If the manual execution works and you see neighbors, but the systemd service doesn't work, then we have a systemd configuration issue.

If the manual execution ALSO fails, then we have a script configuration issue (SSID/BSSID/frequency mismatch).
