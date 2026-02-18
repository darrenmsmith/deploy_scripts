import smbus
import time

# MPU6050 address
MPU6050_ADDR = 0x68

# Register addresses
PWR_MGMT_1 = 0x6B
ACCEL_XOUT_H = 0x3B
GYRO_XOUT_H = 0x43

# Initialize I2C (SMBus)
bus = smbus.SMBus(1)

# Wake up the MPU6050
bus.write_byte_data(MPU6050_ADDR, PWR_MGMT_1, 0)

def read_raw_data(addr):
    # Read 2 bytes of data from the given address
    high = bus.read_byte_data(MPU6050_ADDR, addr)
    low = bus.read_byte_data(MPU6050_ADDR, addr + 1)
    # Combine high and low bytes
    value = ((high << 8) | low)
    # Convert to signed value
    if value > 32768:
        value -= 65536
    return value

def calibrate_sensor(samples=100):
    # Calibrate the sensor by averaging multiple readings
    accel_x_offset, accel_y_offset, accel_z_offset = 0, 0, 0

    print(f"Calibrating sensor with {samples} samples. Please keep the sensor still.")

    for _ in range(samples):
        accel_x_offset += read_raw_data(ACCEL_XOUT_H)
        accel_y_offset += read_raw_data(ACCEL_XOUT_H + 2)
        accel_z_offset += read_raw_data(ACCEL_XOUT_H + 4)
        time.sleep(0.01)  # Small delay between readings

    # Calculate average offsets
    accel_x_offset /= samples
    accel_y_offset /= samples
    accel_z_offset /= samples

    print("Calibration complete.")
    print(f"Accelerometer Offsets - X: {accel_x_offset}, Y: {accel_y_offset}, Z: {accel_z_offset}")
    return accel_x_offset, accel_y_offset, accel_z_offset

def is_touched(threshold, offsets):
    # Read accelerometer data
    accel_x = read_raw_data(ACCEL_XOUT_H) - offsets[0]
    accel_y = read_raw_data(ACCEL_XOUT_H + 2) - offsets[1]
    accel_z = read_raw_data(ACCEL_XOUT_H + 4) - offsets[2]

    # Calculate the magnitude of acceleration
    magnitude = (accel_x**2 + accel_y**2 + accel_z**2)**0.5
    print(f"Current Magnitude: {magnitude}")

    # Check if the magnitude exceeds the threshold
    return magnitude > threshold, magnitude

def main():
    try:
        # Calibrate the sensor
        offsets = calibrate_sensor(samples=100)

        # Set a predefined threshold for touch detection, lower is more sensitive
        threshold = 1000 
        

        print("Monitoring for touch...")

        while True:
            touched, magnitude = is_touched(threshold, offsets)
            if touched:
                print(f"Touched detected! Magnitude: {magnitude:.2f}")
            time.sleep(0.5)  # Delay in seconds between readings

    except KeyboardInterrupt:
        print("Monitoring stopped by User")

if __name__ == "__main__":
    main()
