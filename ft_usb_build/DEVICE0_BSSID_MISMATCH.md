# Device0 BSSID Mismatch - CRITICAL FINDING

**Date:** 2026-01-05
**Issue:** Device0 startup script has wrong BSSID
**Impact:** Clients cannot join the mesh network

---

## The Problem

From the Device0 mesh config output, there's a discrepancy:

### What Device0 Startup Script Says:
```bash
iw dev wlan0 ibss join ft_mesh2 2412 fixed-freq 00:11:22:33:44:55
                                                   ^^^^^^^^^^^^^^^
                                                   Configured BSSID
```

### What Device0 Is Actually Using:
```
Interface wlan0
        addr b8:27:eb:3e:4a:99
             ^^^^^^^^^^^^^^^^^
             Actual BSSID
        ssid ft_mesh2
        type IBSS
```

**The configured BSSID (`00:11:22:33:44:55`) doesn't match the actual BSSID (`b8:27:eb:3e:4a:99`)!**

---

## Why This Breaks Client Connections

When clients try to join the mesh using the configured BSSID `00:11:22:33:44:55`, they're looking for a different mesh cell than the one Device0 created.

Device0 created a mesh cell with BSSID `b8:27:eb:3e:4a:99`, but clients are trying to join one with BSSID `00:11:22:33:44:55`.

**They never connect because they're joining different mesh networks!**

---

## Correct Configuration Values

Based on what Device0 is ACTUALLY running:

```bash
MESH_SSID="ft_mesh2"
MESH_FREQ="2412"
MESH_BSSID="b8:27:eb:3e:4a:99"  # ← Use ACTUAL BSSID, not configured one
```

---

## Fix for Clients

Clients must use the ACTUAL BSSID that Device0 is using:

On each client, edit `/usr/local/bin/start-batman-mesh-client.sh`:

```bash
MESH_SSID="ft_mesh2"
MESH_FREQ="2412"
MESH_BSSID="b8:27:eb:3e:4a:99"  # ← Device0's actual BSSID

# Then in the join command:
iw dev ${MESH_IFACE} ibss join ${MESH_SSID} ${MESH_FREQ} fixed-freq ${MESH_BSSID}
```

Restart the service:
```bash
sudo systemctl restart batman-mesh-client
sudo batctl n
```

After 10 seconds, run `sudo batctl n` again - you should see Device0 as a neighbor!

---

## Quick Fix Script for Clients

Copy this to the client and run it:

```bash
#!/bin/bash
# Fix client BSSID to match Device0

sudo sed -i 's/MESH_BSSID=".*"/MESH_BSSID="b8:27:eb:3e:4a:99"/' /usr/local/bin/start-batman-mesh-client.sh
sudo sed -i 's/MESH_FREQ=".*"/MESH_FREQ="2412"/' /usr/local/bin/start-batman-mesh-client.sh
sudo sed -i 's/MESH_SSID=".*"/MESH_SSID="ft_mesh2"/' /usr/local/bin/start-batman-mesh-client.sh

echo "Updated client configuration to match Device0"
echo "MESH_SSID=ft_mesh2"
echo "MESH_FREQ=2412"
echo "MESH_BSSID=b8:27:eb:3e:4a:99"

sudo systemctl restart batman-mesh-client

echo ""
echo "Waiting 10 seconds for mesh to connect..."
sleep 10

echo ""
echo "Checking for neighbors:"
sudo batctl n
```

---

## Why Device0 Still Works

Device0's mesh appears to work on the admin interface because:
1. Device0 successfully created an IBSS mesh network
2. It's using its own wlan0 MAC as the BSSID
3. The mesh interface is up and running
4. The admin interface shows the mesh as "active"

BUT: No clients can join because they're using the wrong BSSID from the startup script.

---

## The Root Cause

When the gateway phases were created, the BSSID `00:11:22:33:44:55` was used as a placeholder. It was never updated to Device0's actual MAC address.

When clients were built with Phase 4, they copied this placeholder BSSID value, so they're all trying to join a mesh network with BSSID `00:11:22:33:44:55` which doesn't exist!
