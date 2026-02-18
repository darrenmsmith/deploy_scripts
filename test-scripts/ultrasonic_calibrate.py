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

def calibrate_sensor():
    calibration_data = []
    print("Calibration Mode: Measure known distances and enter them.")
    print("Enter 'done' when finished.")
    
    while True:
        try:
            known_distance = input("Enter known distance (cm): ")
            if known_distance.lower() == 'done':
                break
            known_distance = float(known_distance)
            measured_distance = get_distance()
            print(f"Measured distance: {measured_distance} cm")
            calibration_data.append((known_distance, measured_distance))
        except ValueError:
            print("Please enter a valid number or 'done'.")

    return calibration_data

try:
    # Start calibration
    calibration_results = calibrate_sensor()
    print("Calibration Results:")
    for known, measured in calibration_results:
        error = measured - known
        print(f"Known: {known} cm, Measured: {measured} cm, Error: {error} cm")

    # You can use the calibration results to adjust your readings in the main loop
    while True:
        distance = get_distance()
        print(f"Distance: {distance} cm")
        time.sleep(1)

except KeyboardInterrupt:
    print("Measurement stopped by User")
    GPIO.cleanup()
