# 🚀 Field Trainer USB Build - Quick Start

**Updated:** November 15, 2025 (v2.2 - Hardware Auto-Config)

---

## **New in v2.2:** ✨

- ✅ **SSH, I2C, SPI auto-enabled** - No more manual `raspi-config`!
- ✅ **Hardware libraries auto-install** - Touch sensors and LEDs work immediately
- ✅ **Phase 2 service fixes** - More robust internet connection
- ✅ **SSH ready after Phase 2** - Remote access ASAP

---

## **Prerequisites**

- **Raspberry Pi 5** (or Pi 3 A+ with 512MB+ RAM)
- **Fresh Raspberry Pi OS Trixie** (Debian 13, 64-bit)
- **USB WiFi adapter** (for internet via wlan1)
- **This USB drive** (mounted at `/mnt/usb/ft_usb_build/`)

---

## **Quick Installation (Fresh Build)**

### **Step 1: Boot Pi with USB drive inserted**

```bash
# Mount USB if not auto-mounted
sudo mkdir -p /mnt/usb
sudo mount /dev/sda1 /mnt/usb

# Navigate to build directory
cd /mnt/usb/ft_usb_build

# Make scripts executable
chmod +x ft_build.sh phases/*.sh
```

---

### **Step 2: Run Build Script**

```bash
./ft_build.sh
```

---

### **Step 3: Select Phases (Recommended Order)**

**For fastest SSH access, use this order:**

#### **Phase 0: Hardware Verification** (Required First)
```
Choose: 3 (Jump to Specific Phase)
Enter: 0

✅ What it does:
- Verifies Trixie OS, kernel, memory
- Checks for wlan0 and wlan1
- Tests IBSS support
- 🆕 Enables SSH, I2C, SPI automatically
```

#### **Phase 2: Internet Connection** (Run BEFORE Phase 1!)
```
Choose: 3 (Jump to Specific Phase)
Enter: 2

✅ What it does:
- Configures wlan1 with WiFi credentials
- Gets IP from your router (e.g., 10.0.0.61)
- 🔥 SSH now accessible via that IP!

After this completes:
  ssh pi@10.0.0.61  ← You can SSH in now!
```

#### **Phase 1: Package Installation** (Now has internet!)
```
Choose: 3 (Jump to Specific Phase)
Enter: 1

✅ What it does:
- Installs networking packages (batctl, dnsmasq, iptables)
- 🆕 Installs hardware libraries (smbus2, rpi-ws281x)
- 🆕 Installs I2C tools (i2cdetect)
- Installs Python deps (Flask, etc.)
```

#### **Phases 3-6: Complete Setup**
```
Choose: 2 (Run All Remaining Phases)

✅ Runs:
- Phase 3: BATMAN Mesh Network (wlan0)
- Phase 4: DNS/DHCP Server (dnsmasq)
- Phase 5: NAT/Firewall (iptables)
- Phase 6: Field Trainer Application
```

---

## **Installation Order Comparison**

### **❌ OLD WAY (Doesn't Work Well):**
```
Phase 0 → Phase 1 → Phase 2 → Phase 3-6
         ↑ PROBLEM: No internet yet!
```

### **✅ NEW WAY (Recommended):**
```
Phase 0 → Phase 2 → Phase 1 → Phase 3-6
         ↑ Get internet FIRST!
         ↑ SSH ready here! 🎉
```

---

## **What Gets Auto-Configured Now**

### **Phase 0 (Hardware) - NEW! 🆕**
```bash
# Automatically runs:
sudo raspi-config nonint do_ssh 0    # Enable SSH
sudo raspi-config nonint do_i2c 0    # Enable I2C (touch sensor)
sudo raspi-config nonint do_spi 0    # Enable SPI (LEDs)
```

**No more manual raspi-config steps!** 🎉

### **Phase 1 (Packages) - NEW! 🆕**
```bash
# Automatically installs:
apt install python3-dev python3-smbus i2c-tools
pip3 install smbus2          # I2C for MPU6500 touch sensor
pip3 install rpi-ws281x      # LED control (WS2812B)
pip3 install flask-socketio  # Real-time calibration
```

**Hardware ready to go!** 🎉

---

## **Verification After Installation**

### **Test SSH (after Phase 2):**
```bash
# From your laptop/PC on same WiFi:
ssh pi@10.0.0.61  # Use the IP shown by Phase 2
```

### **Test Hardware Interfaces (after Phase 0):**
```bash
raspi-config nonint get_ssh   # Returns: 0 (enabled)
raspi-config nonint get_i2c   # Returns: 0 (enabled)
raspi-config nonint get_spi   # Returns: 0 (enabled)
```

### **Test I2C (after Phase 1 + reboot):**
```bash
# Check I2C device exists
ls /dev/i2c-1

# Scan for MPU6500 sensor
sudo i2cdetect -y 1
# Should show device at 0x68, 0x69, 0x71, or 0x73
```

### **Test Python Libraries (after Phase 1):**
```bash
python3 -c "import smbus2; print('✓ I2C library OK')"
python3 -c "import rpi_ws281x; print('✓ LED library OK')"
python3 -c "import flask_socketio; print('✓ WebSocket OK')"
```

### **Test Field Trainer (after Phase 6):**
```bash
# Check service status
sudo systemctl status field-trainer

# Check listening ports
sudo ss -tlpn | grep -E "5000|5001"

# Access web interfaces
# From mesh network: http://192.168.99.100:5000
# From home WiFi:    http://10.0.0.61:5000
```

---

## **Common Issues & Fixes**

### **Issue: "No internet connection" in Phase 1**

**Solution:** Run Phase 2 FIRST to get internet, then come back to Phase 1
```bash
Choose: 3 (Jump to Specific Phase)
Enter: 2  ← Configure internet first
# Then return to Phase 1 after Phase 2 succeeds
```

---

### **Issue: "I2C device not found" after Phase 1**

**Solution:** Reboot required for I2C to activate
```bash
sudo reboot
# After reboot:
ls /dev/i2c-1        # Should exist now
sudo i2cdetect -y 1   # Should detect MPU6500
```

---

### **Issue: "wlan1-internet.service failed to start"**

**Solution:** Fixed in v2.2! If still fails:
```bash
# Check service logs
sudo journalctl -u wlan1-internet.service -n 50

# Manual restart
sudo systemctl restart wlan1-internet

# Check wlan1 status
ip addr show wlan1
sudo wpa_cli -i wlan1 status
```

---

### **Issue: "LEDs don't light up"**

**Checklist:**
```bash
# 1. Is SPI enabled?
raspi-config nonint get_spi  # Should return: 0

# 2. Is rpi-ws281x installed?
python3 -c "import rpi_ws281x"

# 3. Is Field Trainer running?
sudo systemctl status field-trainer

# 4. Check logs for LED errors
sudo journalctl -u field-trainer | grep -i led

# 5. Reboot if needed (SPI requires reboot)
sudo reboot
```

---

## **Hardware Requirements**

Field Trainer uses these interfaces:

| Interface | Purpose | Hardware | Library |
|-----------|---------|----------|---------|
| **I2C** | Touch detection | MPU6500 accelerometer | `smbus2` |
| **SPI/PWM** | LED control | WS2812B LED strip (8 LEDs) | `rpi-ws281x` |
| **GPIO18** | LED data pin | Connected to WS2812B DIN | - |
| **SSH** | Remote access | Network (wlan1 or eth0) | - |

**I2C Addresses:** 0x68, 0x69, 0x71, or 0x73 (auto-detected)
**LED Count:** 8 LEDs on GPIO18
**Brightness:** 32/255 (default, configurable)

---

## **Network Configuration**

After complete installation:

### **Device 0 Network Interfaces:**
```
wlan1 (USB WiFi)    → Internet (e.g., 10.0.0.61)
wlan0 (Onboard)     → BATMAN Mesh (IBSS mode)
bat0 (Virtual)      → Mesh Gateway (192.168.99.100)
```

### **Access URLs:**

**From Mesh Network (Devices 1-5):**
- Web Interface: `http://192.168.99.100:5000`
- Coach Interface: `http://192.168.99.100:5001`

**From Home WiFi (your laptop):**
- Web Interface: `http://10.0.0.61:5000` (use your wlan1 IP)
- Coach Interface: `http://10.0.0.61:5001`

---

## **Useful Commands**

### **Check Build State:**
```bash
cat /mnt/usb/ft_usb_build/.build_state
# Shows current phase number (0-7)
```

### **Re-run a Phase:**
```bash
cd /mnt/usb/ft_usb_build
./ft_build.sh
Choose: 4 (Re-run Current/Previous Phase)
Enter: <phase number>
```

### **View All Services:**
```bash
sudo systemctl status wlan1-internet
sudo systemctl status batman-mesh
sudo systemctl status dnsmasq
sudo systemctl status field-trainer
```

### **View Logs:**
```bash
# Internet connection
sudo journalctl -u wlan1-internet -f

# Mesh network
sudo journalctl -u batman-mesh -f

# Field Trainer application
sudo journalctl -u field-trainer -f
```

---

## **Complete System Test**

After all phases complete, run this test:

```bash
#!/bin/bash

echo "=== Field Trainer System Test ==="
echo ""

# Network interfaces
echo "1. Network Interfaces:"
ip addr show wlan1 | grep "inet " | grep -v "169.254"
ip addr show bat0 | grep "inet "
echo ""

# Services
echo "2. Services:"
systemctl is-active wlan1-internet && echo "  ✓ Internet" || echo "  ✗ Internet"
systemctl is-active batman-mesh && echo "  ✓ Mesh" || echo "  ✗ Mesh"
systemctl is-active dnsmasq && echo "  ✓ DNS/DHCP" || echo "  ✗ DNS/DHCP"
systemctl is-active field-trainer && echo "  ✓ Field Trainer" || echo "  ✗ Field Trainer"
echo ""

# Hardware interfaces
echo "3. Hardware Interfaces:"
[ $(raspi-config nonint get_ssh) -eq 0 ] && echo "  ✓ SSH" || echo "  ✗ SSH"
[ $(raspi-config nonint get_i2c) -eq 0 ] && echo "  ✓ I2C" || echo "  ✗ I2C"
[ $(raspi-config nonint get_spi) -eq 0 ] && echo "  ✓ SPI" || echo "  ✗ SPI"
echo ""

# Python libraries
echo "4. Python Hardware Libraries:"
python3 -c "import smbus2" 2>/dev/null && echo "  ✓ smbus2" || echo "  ✗ smbus2"
python3 -c "import rpi_ws281x" 2>/dev/null && echo "  ✓ rpi-ws281x" || echo "  ✗ rpi-ws281x"
python3 -c "import flask_socketio" 2>/dev/null && echo "  ✓ flask-socketio" || echo "  ✗ flask-socketio"
echo ""

# Listening ports
echo "5. Listening Ports:"
sudo ss -tlpn | grep -E "5000|5001" | awk '{print "  " $0}'
echo ""

# Internet
echo "6. Internet Connectivity:"
ping -c 1 -W 2 8.8.8.8 >/dev/null && echo "  ✓ Internet OK" || echo "  ✗ No Internet"
echo ""

echo "=== Test Complete ==="
```

---

## **Summary: What Changed in v2.2**

| Feature | Before (v2.1) | After (v2.2) |
|---------|---------------|--------------|
| SSH Enable | Manual `raspi-config` | ✅ Auto in Phase 0 |
| I2C Enable | Manual `raspi-config` | ✅ Auto in Phase 0 |
| SPI Enable | Manual `raspi-config` | ✅ Auto in Phase 0 |
| smbus2 Install | Manual pip | ✅ Auto in Phase 1 |
| rpi-ws281x Install | Manual pip | ✅ Auto in Phase 1 |
| i2c-tools Install | Manual apt | ✅ Auto in Phase 1 |
| Phase 2 Service | Could fail on boot | ✅ Fixed with `-` prefix |
| SSH Info | Not shown | ✅ Shown after Phase 2 |

---

**🎉 Zero manual configuration required! Everything is automated!**

For detailed changes, see: `USB_BUILD_UPDATES.md`
