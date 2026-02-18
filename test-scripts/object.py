import RPi.GPIO as GPIO
import time

# Set GPIO mode
GPIO.setmode(GPIO.BCM)

# Define GPIO pins
TRIG = 23  # GPIO pin for Trigger
ECHO = 24  # GPIO pin for Echo

# Set up the GPIO pins
GPIO.setup(TRIG, GPIO.OUT)
GPIO.setup(ECHO, GPIO.IN)

def measure_distance():
    # Send a 10us pulse to trigger the sensor
    GPIO.output(TRIG, True)
    time.sleep(0.00001)
    GPIO.output(TRIG, False)

    # Wait for the echo to start
    while GPIO.input(ECHO) == 0:
        pulse_start = time.time()

    # Wait for the echo to end
    while GPIO.input(ECHO) == 1:
        pulse_end = time.time()

    # Calculate the distance
    pulse_duration = pulse_end - pulse_start
    distance = pulse_duration * 17150  # Convert to cm
    distance = round(distance, 2)

    return distance

try:
    print("Object Detection using JSN-SR04T V3.0")
    while True:
        distance = measure_distance()
        print(f"Distance: {distance} cm")

        # Set the threshold distance for object detection
        threshold_distance = 30  # cm

        if distance < threshold_distance:
            print("Alert! Object detected within the area!")
        
        time.sleep(1)  # Wait for a second before the next measurement

except KeyboardInterrupt:
    print("Measurement stopped by User")
    GPIO.cleanup()
