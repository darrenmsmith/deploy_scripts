import RPi.GPIO as GPIO
import time

# Set GPIO mode
GPIO.setmode(GPIO.BCM)

# Define GPIO pins
TRIG = 23
ECHO = 24

# Set up the GPIO pins
GPIO.setup(TRIG, GPIO.OUT)
GPIO.setup(ECHO, GPIO.IN)

def get_distance():
    # Send a signal
    GPIO.output(TRIG, True)
    time.sleep(0.00001)  # 10 microseconds
    GPIO.output(TRIG, False)

    # Wait for the echo
    pulse_start = time.time()
    while GPIO.input(ECHO) == 0:
        pulse_start = time.time()

    pulse_end = time.time()
    while GPIO.input(ECHO) == 1:
        pulse_end = time.time()

    # Calculate distance
    pulse_duration = pulse_end - pulse_start
    distance = pulse_duration * 17150  # Convert to cm
    return round(distance, 2)

def calibrate_sensor(target_distances):
    calibration_data = []
    print("Calibration Mode: Measuring distances at specified points.")
    
    for target_distance in target_distances:
        input("Place an object at {} cm and press Enter...".format(target_distance))
        measured_distance = get_distance()
        print(f"Measured distance: {measured_distance} cm")
        error = measured_distance - target_distance
        calibration_data.append((target_distance, measured_distance, error))

    return calibration_data

def main():
    # Ask the user if they want to calibrate the sensor
    calibrate = input("Do you want to calibrate the sensor? (yes/no): ").strip().lower()
    
    if calibrate == 'yes':
        target_distances = [20, 50, 100, 200]
        calibration_results = calibrate_sensor(target_distances)
        
        print("\nCalibration Results:")
        for known, measured, error in calibration_results:
            print(f"Target: {known} cm, Measured: {measured} cm, Error: {error} cm")

        # Calculate average error for adjustment
        average_error = sum(error for _, _, error in calibration_results) / len(calibration_results)
        print(f"\nAverage Calibration Error: {average_error:.2f} cm")
    else:
        print("Calibration skipped.")

    print("\nStarting Distance Monitoring (Press Ctrl+C to stop)...")
    
    try:
        while True:
            distance = get_distance()
            adjusted_distance = distance - (average_error if calibrate == 'yes' else 0)  # Adjust for calibration error if calibrated
            print(f"Distance: {distance:.2f} cm, Adjusted Distance: {adjusted_distance:.2f} cm")
            time.sleep(1)

    except KeyboardInterrupt:
        print("Measurement stopped by User")
        GPIO.cleanup()

if __name__ == "__main__":
    main()