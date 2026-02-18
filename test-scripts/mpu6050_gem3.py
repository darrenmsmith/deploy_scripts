import smbus
import time
import json
import argparse
import math

# MPU-6050 registers
MPU6050_ADDR = 0x68  # Default I2C address
PWR_MGMT_1 = 0x6B
SMPLRT_DIV = 0x19
CONFIG = 0x1A
GYRO_CONFIG = 0x1B
ACCEL_CONFIG = 0x1C
INT_PIN_CFG = 0x37
INT_ENABLE = 0x38
ACCEL_XOUT_H = 0x3B
ACCEL_YOUT_H = 0x3D
ACCEL_ZOUT_H = 0x3F
GYRO_XOUT_H = 0x43
GYRO_YOUT_H = 0x45
GYRO_ZOUT_H = 0x47

# Scale factors
ACCEL_SCALE = 16384.0  # For +/- 2g range
GYRO_SCALE = 131.0  # For +/- 250 deg/s range

def read_byte(bus, address, reg):
    return bus.read_byte_data(address, reg)

def read_word(bus, address, reg):
    high = bus.read_byte_data(address, reg)
    low = bus.read_byte_data(address, reg + 1)
    value = (high << 8) | low
    return value

def read_word_2c(bus, address, reg):
    val = read_word(bus, address, reg)
    if (val >= 0x8000):
        return -((65535 - val) + 1)
    else:
        return val

def write_byte(bus, address, reg, value):
    bus.write_byte_data(address, reg, value)

def initialize_mpu6050(bus, address):
    try:
        # Wake up MPU-6050
        write_byte(bus, address, PWR_MGMT_1, 0x00)
        # Set sample rate divider
        write_byte(bus, address, SMPLRT_DIV, 0x07)  # 100Hz sample rate @ 1kHz internal
        # Configure DLPF
        write_byte(bus, address, CONFIG, 0x00)
        # Set gyroscope range
        write_byte(bus, address, GYRO_CONFIG, 0x00)  # +/- 250 deg/s
        # Set accelerometer range
        write_byte(bus, address, ACCEL_CONFIG, 0x00)  # +/- 2g
        # Enable interrupts (optional)
        write_byte(bus, address, INT_PIN_CFG, 0x02)  # INT_RD_CLEAR on any read
        write_byte(bus, address, INT_ENABLE, 0x01)  # Enable data ready interrupt
        return True
    except Exception as e:
        print(f"Error initializing MPU-6050: {e}")
        return False

def calibrate_mpu6050(bus, address, calibration_file):
    print("Calibrating MPU-6050. Please keep the sensor stationary.")
    num_readings = 200
    accel_offsets = [0.0] * 3
    gyro_offsets = [0.0] * 3

    for _ in range(num_readings):
        accel_x = read_word_2c(bus, address, ACCEL_XOUT_H)
        accel_y = read_word_2c(bus, address, ACCEL_YOUT_H)
        accel_z = read_word_2c(bus, address, ACCEL_ZOUT_H)
        gyro_x = read_word_2c(bus, address, GYRO_XOUT_H)
        gyro_y = read_word_2c(bus, address, GYRO_YOUT_H)
        gyro_z = read_word_2c(bus, address, GYRO_ZOUT_H)

        accel_offsets[0] += accel_x
        accel_offsets[1] += accel_y
        accel_offsets[2] += accel_z
        gyro_offsets[0] += gyro_x
        gyro_offsets[1] += gyro_y
        gyro_offsets[2] += gyro_z
        time.sleep(0.01)

    accel_offsets = [offset / num_readings for offset in accel_offsets]
    gyro_offsets = [offset / num_readings for offset in gyro_offsets]

    # Adjust Z-axis accelerometer offset (gravity)
    accel_offsets[2] -= ACCEL_SCALE  # Subtract 1g

    calibration_data = {
        "accel_offsets": accel_offsets,
        "gyro_offsets": gyro_offsets
    }

    try:
        with open(calibration_file, "w") as f:
            json.dump(calibration_data, f)
        print(f"Calibration data saved to {calibration_file}")
    except Exception as e:
        print(f"Error saving calibration data: {e}")

    return calibration_data

def load_calibration(calibration_file):
    try:
        with open(calibration_file, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return None
    except json.JSONDecodeError:
        print(f"Error decoding JSON in {calibration_file}. Recalibrating.")
        return None

def main():
    parser = argparse.ArgumentParser(description="MPU-6050 Touch Detection")
    parser.add_argument("--bus", type=int, default=1, help="I2C bus number")
    parser.add_argument("--address", type=int, default=MPU6050_ADDR, help="MPU-6050 I2C address")
    parser.add_argument("--calibrate", action="store_true", help="Perform calibration")
    parser.add_argument("--threshold", type=float, default=2.0, help="Touch threshold")
    parser.add_argument("--calibration_file", type=str, default="calibration.json", help="Calibration file path")
    parser.add_argument("--touches", type=int, default=5, help="Number of touches before exiting")
    args = parser.parse_args()

    bus = smbus.SMBus(args.bus)

    if not initialize_mpu6050(bus, args.address):
        exit(1)

    calibration_data = load_calibration(args.calibration_file)

    if args.calibrate or calibration_data is None:
        calibration_data = calibrate_mpu6050(bus, args.address, args.calibration_file)

    if calibration_data is None:
        print("Calibration failed. Exiting.")
        exit(1)

    accel_offsets = calibration_data["accel_offsets"]
    gyro_offsets = calibration_data["gyro_offsets"]

    touch_count = 0
    prev_accel_mag = 0.0  # Initialize previous magnitude
    touch_debounce = 0.2 # Debounce time in seconds
    last_touch_time = 0.0

    try:
        while touch_count < args.touches:
            accel_x = read_word_2c(bus, args.address, ACCEL_XOUT_H) / ACCEL_SCALE
            accel_y = read_word_2c(bus, args.address, ACCEL_YOUT_H) / ACCEL_SCALE
            accel_z = read_word_2c(bus, args.address, ACCEL_ZOUT_H) / ACCEL_SCALE

            # Apply calibration offsets
            accel_x -= accel_offsets[0] / ACCEL_SCALE
            accel_y -= accel_offsets[1] / ACCEL_SCALE
            accel_z -= accel_offsets[2] / ACCEL_SCALE

            accel_mag = math.sqrt(accel_x**2 + accel_y**2 + accel_z**2)
            delta_accel_mag = abs(accel_mag - prev_accel_mag)

            current_time = time.time()

            if delta_accel_mag > args.threshold and current_time - last_touch_time > touch_debounce:
                print("Touched!")
                touch_count += 1
		touch_detected = True

                if touch_count >= 5:  # Exit after 5 touches
                   print("5 touches detected. Exiting.")
                   break  # Exit the loop

            else:
                 touch_detected = False  # Reset debouncing

	    prev_accel_mag = accel_mag

            # Print calibrated readings (optional - same as before)
            # ...

            time.sleep(0.01)  # Adjust reading frequency

        except KeyboardInterrupt:
            print("Exiting...")
            break
        except Exception as e:
            print(f"Error in main loop: {e}")
            break

if __name__ == "__main__":
    main()
