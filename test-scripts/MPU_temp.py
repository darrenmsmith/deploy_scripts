import smbus
import time

# MPU6050 address
MPU6050_ADDR = 0x68

# Register addresses
PWR_MGMT_1 = 0x6B
TEMP_OUT_H = 0x41

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
    # Calibrate the sensor by averaging multiple temperature readings
    temp_offset = 0

    print(f"Calibrating sensor with {samples} samples. Please keep the sensor still.")

    for _ in range(samples):
        temp_raw = read_raw_data(TEMP_OUT_H)
        temp_offset += temp_raw / 340.00 + 36.53  # Convert to temperature
        time.sleep(0.01)  # Small delay between readings

    # Calculate average temperature offset
    temp_offset /= samples
    print("Calibration complete.")
    print(f"Average Temperature Offset: {temp_offset:.2f} °C")
    return temp_offset

def read_temperature(offset):
    # Read raw temperature data
    temp_raw = read_raw_data(TEMP_OUT_H)
    # Convert to temperature in degrees Celsius and apply offset
    temperature = (temp_raw / 340.00 + 36.53) - offset
    return temperature

def main():
    try:
        # Calibrate the sensor
        temp_offset = calibrate_sensor(samples=100)

        print("Reading temperature from MPU6050...")
        while True:
            temperature = read_temperature(temp_offset)
            print(f"Temperature: {temperature:.2f} °C")
            time.sleep(1)  # Delay of 1 second between readings
 
    except KeyboardInterrupt:
        print("Temperature monitoring stopped by User")

if __name__ == "__main__":
    main()
