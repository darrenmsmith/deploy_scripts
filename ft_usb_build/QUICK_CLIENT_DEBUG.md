# Quick Client Mesh Debug

**Status:** Device0 mesh is ACTIVE (confirmed via admin page)
**Problem:** Clients not appearing as neighbors on Device0

This is a **client-side configuration issue**.

---

## Quick Test Commands

Run these on Device0 Prod to check Device0 mesh configuration:

```bash
# What SSID is Device0 using?
iw dev wlan0 info | grep ssid

# What BSSID is Device0 using?
iw dev wlan0 info | grep addr

# What frequency/channel?
iw dev wlan0 info | grep channel
```

**Copy these values - clients must match them EXACTLY**

---

## Then Run on Client Device

Which client did you test? (Device1-5, IP 192.168.99.101-105)

### Quick Check Commands:

```bash
# Is the service enabled?
systemctl is-enabled batman-mesh-client

# Is it active?
systemctl is-active batman-mesh-client

# What's the service status?
sudo systemctl status batman-mesh-client

# What SSID is the client trying to join?
sudo grep MESH_SSID /usr/local/bin/start-batman-mesh-client.sh

# What BSSID?
sudo grep MESH_BSSID /usr/local/bin/start-batman-mesh-client.sh

# What frequency?
sudo grep MESH_FREQ /usr/local/bin/start-batman-mesh-client.sh

# Is wlan0 in IBSS mode?
iw dev wlan0 info | grep type

# What SSID is wlan0 actually joined to?
iw dev wlan0 info | grep ssid

# Does bat0 exist?
ip addr show bat0

# Is wlan0 added to batman-adv?
sudo batctl if

# Any neighbors?
sudo batctl n
```

---

## Most Likely Issues

Based on Device0 working but clients not connecting:

### 1. Client Service Not Starting
**Check:**
```bash
systemctl is-active batman-mesh-client
```

**If inactive:**
```bash
sudo systemctl start batman-mesh-client
sudo systemctl status batman-mesh-client
```

Look for error messages in the status output.

### 2. SSID/BSSID Mismatch
**Device0 and client MUST have identical:**
- MESH_SSID (exact string match)
- MESH_BSSID (exact MAC address)
- MESH_FREQ (exact frequency in MHz)

**To check client startup script:**
```bash
cat /usr/local/bin/start-batman-mesh-client.sh
```

Compare to Device0:
```bash
cat /usr/local/bin/start-batman-mesh.sh
```

### 3. Client Service Enabled But Not Running After Boot
**Check if enabled:**
```bash
systemctl is-enabled batman-mesh-client
# Should show: enabled
```

**If not enabled:**
```bash
sudo systemctl enable batman-mesh-client
sudo systemctl start batman-mesh-client
```

### 4. Service Starts But Fails Silently
**Check logs:**
```bash
sudo journalctl -u batman-mesh-client -n 50
```

Look for error messages like:
- "failed to join"
- "invalid argument"
- "device or resource busy"
- "operation not permitted"

---

## Quick Fix Steps

### If Service Not Enabled:
```bash
sudo systemctl enable batman-mesh-client
sudo systemctl start batman-mesh-client
sudo batctl n
# Wait 10 seconds
sudo batctl n
```

### If SSID/BSSID Mismatch:

You'll need to manually edit the client startup script to match Device0.

**Get Device0 values:**
```bash
# On Device0
iw dev wlan0 info | grep ssid
iw dev wlan0 info
cat /usr/local/bin/start-batman-mesh.sh | grep -E "MESH_SSID|MESH_BSSID|MESH_FREQ"
```

**Update client script:**
```bash
# On client
sudo nano /usr/local/bin/start-batman-mesh-client.sh

# Update these lines to match Device0:
MESH_SSID="<exact-ssid-from-device0>"
MESH_FREQ="<exact-freq-from-device0>"
MESH_BSSID="<exact-bssid-from-device0>"

# Save and exit (Ctrl+X, Y, Enter)

# Restart service
sudo systemctl restart batman-mesh-client

# Check neighbors
sudo batctl n
```

### If Service Fails to Start:

Run the startup script manually to see errors:
```bash
# On client
sudo /usr/local/bin/start-batman-mesh-client.sh

# Check if it worked
iw dev wlan0 info
sudo batctl if
sudo batctl n
```

If manual execution works but systemd doesn't, it's the boot timing issue we tried to fix.

If manual execution ALSO fails, you'll see the error message directly.

---

## Expected Working State

**Client service status:**
```
● batman-mesh-client.service - BATMAN-adv Mesh Network (Client)
   Loaded: loaded (/etc/systemd/system/batman-mesh-client.service; enabled)
   Active: active (exited) since...
```

**Client wlan0 info:**
```
type IBSS
ssid <same-as-device0>
```

**Client batctl if:**
```
wlan0: active
```

**Client batctl n:**
```
wlan0    <device0-mac>    0.XXXs
```

**Device0 batctl n (from Device0):**
```
wlan0    <client-mac>     0.XXXs
```

---

## Next Steps

1. **Get Device0 mesh config values** (SSID, BSSID, freq)
2. **Check client service status** (enabled? active?)
3. **Check client config values** (do they match Device0?)
4. **Check client logs** for errors
5. **Try manual startup** if service fails

Once you run these quick checks on a client device, we'll know:
- Is it a configuration mismatch?
- Is it a service startup issue?
- Is it a network/hardware issue?
