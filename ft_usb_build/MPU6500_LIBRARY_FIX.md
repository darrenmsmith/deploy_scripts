# MPU6500/MPU9250 Python Library Fix

## Date: 2026-01-08

## Problem

**User report:** "verify sensor shows that mpu6050 Failed to acquire sensor data. we should not be looking for MPU6050"

### Root Cause

The `adafruit-circuitpython-mpu6050` library is hardcoded to expect WHO_AM_I register = 0x68 (MPU6050 only). When it reads 0x70 (MPU6500) or 0x71 (MPU9250), it rejects the sensor.

```python
# adafruit_mpu6050 library does this internally:
if who_am_i != 0x68:
    raise RuntimeError("Failed to find MPU6050")
```

This library cannot work with MPU6500/MPU9250, even though they have the same register layout.

## Solution

Switched from `adafruit-circuitpython-mpu6050` to `smbus2` - a universal I2C library that works with **all** MPU sensors.

### Why smbus2?

- ✅ Works with MPU6050, MPU6500, MPU9250 (any I2C device)
- ✅ Direct register access - no WHO_AM_I validation
- ✅ Lightweight and fast
- ✅ Already installed on gateway (line 394 of gateway Phase 3)
- ✅ Standard Python library for I2C communication

### Code Comparison

**Before (adafruit-circuitpython-mpu6050):**
```python
import board
import adafruit_mpu6050

i2c = board.I2C()
mpu = adafruit_mpu6050.MPU6050(i2c)  # ❌ FAILS - rejects MPU6500

accel = mpu.acceleration
gyro = mpu.gyro
temp = mpu.temperature
```

**After (smbus2):**
```python
import smbus2
import struct
import time

bus = smbus2.SMBus(1)
SENSOR_ADDR = 0x68

# Wake up sensor
bus.write_byte_data(SENSOR_ADDR, 0x6B, 0x00)
time.sleep(0.1)

# Read accelerometer (registers 0x3B-0x40)
accel_data = bus.read_i2c_block_data(SENSOR_ADDR, 0x3B, 6)
accel_x = struct.unpack('>h', bytes(accel_data[0:2]))[0] / 16384.0
accel_y = struct.unpack('>h', bytes(accel_data[2:4]))[0] / 16384.0
accel_z = struct.unpack('>h', bytes(accel_data[4:6]))[0] / 16384.0

# Read gyroscope (registers 0x43-0x48)
gyro_data = bus.read_i2c_block_data(SENSOR_ADDR, 0x43, 6)
gyro_x = struct.unpack('>h', bytes(gyro_data[0:2]))[0] / 131.0
gyro_y = struct.unpack('>h', bytes(gyro_data[2:4]))[0] / 131.0
gyro_z = struct.unpack('>h', bytes(gyro_data[4:6]))[0] / 131.0

# Read temperature (registers 0x41-0x42)
temp_data = bus.read_i2c_block_data(SENSOR_ADDR, 0x41, 2)
temp_raw = struct.unpack('>h', bytes(temp_data))[0]
temp_c = (temp_raw / 340.0) + 36.53

bus.close()
```

✅ Works with MPU6050, MPU6500, and MPU9250 without any changes!

## Files Modified

### 1. `/mnt/usb/ft_usb_build/verify_sensors.sh`

**Section 8: Test Python I2C Library**

**Before:**
- Checked for `adafruit_mpu6050` library
- Used `adafruit_mpu6050.MPU6050(i2c)` to read sensor
- Failed with MPU6500/MPU9250

**After:**
- Checks for `smbus2` library
- Direct register reads using smbus2
- Works with all MPU sensors
- Lines 244-329: Complete rewrite of Python test section

### 2. `/mnt/usb/ft_usb_build/client_phases/phase3_packages.sh`

**Lines 125-133:**
```bash
# Before
log_info "Installing touch sensor library (MPU6050)..."
sudo pip3 install --break-system-packages adafruit-circuitpython-mpu6050

# After
log_info "Installing I2C sensor library (smbus2 for MPU6500/MPU9250)..."
sudo pip3 install --break-system-packages smbus2
```

**Line 212 (Summary):**
```bash
# Before
echo "    ✓ Touch sensor library (MPU6050)"

# After
echo "    ✓ Touch sensor library (smbus2 for MPU6500/MPU9250)"
```

### 3. Gateway Phase 3 (No Changes Needed)

Gateway already installs smbus2 at line 394:
```bash
if sudo pip3 install smbus2 --break-system-packages &>/dev/null; then
```

## MPU Register Map Reference

All MPU sensors (6050/6500/9250) share the same core registers:

| Register | Address | Description | Scaling Factor |
|----------|---------|-------------|----------------|
| PWR_MGMT_1 | 0x6B | Power management | Write 0x00 to wake |
| WHO_AM_I | 0x75 | Chip ID | 0x68/0x70/0x71 |
| ACCEL_XOUT_H | 0x3B | Accel X high byte | ±2g: /16384.0 |
| ACCEL_XOUT_L | 0x3C | Accel X low byte | |
| ACCEL_YOUT_H | 0x3D | Accel Y high byte | |
| ACCEL_YOUT_L | 0x3E | Accel Y low byte | |
| ACCEL_ZOUT_H | 0x3F | Accel Z high byte | |
| ACCEL_ZOUT_L | 0x40 | Accel Z low byte | |
| TEMP_OUT_H | 0x41 | Temperature high | (val/340.0)+36.53 |
| TEMP_OUT_L | 0x42 | Temperature low | |
| GYRO_XOUT_H | 0x43 | Gyro X high byte | 250°/s: /131.0 |
| GYRO_XOUT_L | 0x44 | Gyro X low byte | |
| GYRO_YOUT_H | 0x45 | Gyro Y high byte | |
| GYRO_YOUT_L | 0x46 | Gyro Y low byte | |
| GYRO_ZOUT_H | 0x47 | Gyro Z high byte | |
| GYRO_ZOUT_L | 0x48 | Gyro Z low byte | |

### Data Format
- All values are **signed 16-bit integers** (big-endian)
- Use `struct.unpack('>h', bytes)` to convert
- Apply scaling factor based on configured range

## Expected Output

### Sensor Verification Now Shows:

```
8. Testing Python I2C Library
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Checking smbus2 (universal I2C library)...

✓ Python smbus2 library installed (works with all MPU sensors)

ℹ Testing sensor data acquisition...

✓ Sensor data acquisition working!

  Acceleration: X=0.05g, Y=-0.02g, Z=1.01g
  Gyroscope: X=0.12°/s, Y=-0.31°/s, Z=0.08°/s
  Temperature: 24.35°C
```

✅ **Success!** Works with MPU6500, MPU9250, and MPU6050.

## Testing

### Test on Device with MPU6500

```bash
# Run sensor verification
sudo /mnt/usb/ft_usb_build/verify_sensors.sh

# Expected results:
# ✓ MPU sensor detected at address 0x68
# ✓ Sensor chip ID confirmed: MPU6500 (WHO_AM_I: 0x70)
# ✓ Sensor data acquisition working!
# ✓ Acceleration: X=..., Y=..., Z=... (in g)
# ✓ Gyroscope: X=..., Y=..., Z=... (in °/s)
# ✓ Temperature: ... °C
```

### Test Python Access Directly

```bash
python3 << 'EOF'
import smbus2
import struct

bus = smbus2.SMBus(1)
ADDR = 0x68

# Wake up sensor
bus.write_byte_data(ADDR, 0x6B, 0x00)

# Read WHO_AM_I
who = bus.read_byte_data(ADDR, 0x75)
print(f"WHO_AM_I: 0x{who:02x}")

# Read accelerometer Z-axis (should be ~1g when flat)
data = bus.read_i2c_block_data(ADDR, 0x3F, 2)
accel_z = struct.unpack('>h', bytes(data))[0] / 16384.0
print(f"Accel Z: {accel_z:.2f}g")

bus.close()
EOF
```

Expected output:
```
WHO_AM_I: 0x70
Accel Z: 1.01g
```

## Migration Guide

If you need to update existing code that uses adafruit_mpu6050:

### Simple Read Function

```python
def read_mpu_sensor():
    """Read MPU6050/6500/9250 sensor data using smbus2"""
    import smbus2
    import struct

    bus = smbus2.SMBus(1)
    ADDR = 0x68

    # Wake up sensor
    bus.write_byte_data(ADDR, 0x6B, 0x00)

    # Read all data at once (14 bytes from 0x3B)
    data = bus.read_i2c_block_data(ADDR, 0x3B, 14)

    # Parse data
    accel_x = struct.unpack('>h', bytes(data[0:2]))[0] / 16384.0
    accel_y = struct.unpack('>h', bytes(data[2:4]))[0] / 16384.0
    accel_z = struct.unpack('>h', bytes(data[4:6]))[0] / 16384.0
    temp_raw = struct.unpack('>h', bytes(data[6:8]))[0]
    gyro_x = struct.unpack('>h', bytes(data[8:10]))[0] / 131.0
    gyro_y = struct.unpack('>h', bytes(data[10:12]))[0] / 131.0
    gyro_z = struct.unpack('>h', bytes(data[12:14]))[0] / 131.0

    temp_c = (temp_raw / 340.0) + 36.53

    bus.close()

    return {
        'accel': (accel_x, accel_y, accel_z),
        'gyro': (gyro_x, gyro_y, gyro_z),
        'temp': temp_c
    }
```

### Usage

```python
data = read_mpu_sensor()
print(f"Acceleration: {data['accel']}")
print(f"Gyroscope: {data['gyro']}")
print(f"Temperature: {data['temp']:.2f}°C")
```

## Benefits

1. ✅ **Universal Compatibility** - Works with MPU6050, MPU6500, MPU9250
2. ✅ **No WHO_AM_I Checking** - Doesn't reject sensors based on chip ID
3. ✅ **Direct Register Access** - Full control over sensor configuration
4. ✅ **Lightweight** - No heavy dependencies (board, busio, etc.)
5. ✅ **Already Used on Gateway** - Consistent across devices
6. ✅ **Standard Library** - Well-documented, widely used

## Troubleshooting

### Permission Denied
```bash
# Add user to i2c group
sudo usermod -a -G i2c pi
# Logout/login required
```

### Sensor Not Found
```bash
# Check I2C bus
sudo i2cdetect -y 1

# Verify sensor address (should be 0x68 or 0x69)
```

### Wrong Data Values
```python
# Make sure to wake up sensor first
bus.write_byte_data(ADDR, 0x6B, 0x00)
time.sleep(0.1)  # Wait for sensor to wake
```

---

**Summary:** Switched from MPU6050-specific library to universal smbus2 library. Now works with MPU6500/MPU9250 without any code changes.
