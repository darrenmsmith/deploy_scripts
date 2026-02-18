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

class KalmanFilter:
    def __init__(self, process_variance, measurement_variance):
        self.process_variance = process_variance  # Process noise variance
        self.measurement_variance = measurement_variance  # Measurement noise variance
        self.posteri_estimate = 0.0  # Initial estimate
        self.posteri_error_estimate = 1.0  # Initial error estimate

    def update(self, measurement):
        # Prediction update
        priori_estimate = self.posteri_estimate
        priori_error_estimate = self.posteri_error_estimate + self.process_variance

        # Measurement update
        blending_factor = priori_error_estimate / (priori_error_estimate + self.measurement_variance)
        self.posteri_estimate = priori_estimate + blending_factor * (measurement - priori_estimate)
        self.posteri_error_estimate = (1 - blending_factor) * priori_error_estimate

        return self.posteri_estimate

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
    # Initialize Kalman Filter
    process_variance = 1e-5  # Adjust based on expected noise
    measurement_variance = 0.5  # Adjust based on sensor characteristics
    kalman_filter = KalmanFilter(process_variance, measurement_variance)

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
        average_error = 0  # No calibration adjustment if skipped

    print("\nStarting Distance Monitoring (Press Ctrl+C to stop)...")
    
    try:
        while True:
            distance = get_distance()
            adjusted_distance = distance - average_error  # Adjust for calibration error
            
            # Apply Kalman filter
            filtered_distance = kalman_filter.update(adjusted_distance)
            
            print(f"Raw Distance: {distance:.2f} cm, Adjusted Distance: {adjusted_distance:.2f} cm, Filtered Distance: {filtered_distance:.2f} cm")
            time.sleep(1)

    except KeyboardInterrupt:
        print("Measurement stopped by User")
        GPIO.cleanup()

if __name__ == "__main__":
    main()