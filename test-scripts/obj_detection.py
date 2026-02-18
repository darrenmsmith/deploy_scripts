import RPi.GPIO as GPIO
import time

# Set the GPIO mode
GPIO.setmode(GPIO.BCM)

# Define GPIO pins
TRIG = 23  # GPIO pin for Trigger
ECHO = 24  # GPIO pin for Echo

# Set up the pins
GPIO.setup(TRIG, GPIO.OUT)
GPIO.setup(ECHO, GPIO.IN)

def detect_object():
    # Send a pulse to trigger the sensor
    GPIO.output(TRIG, True)
    time.sleep(0.01)  # 10ms pulse
    GPIO.output(TRIG, False)

    # Wait for the echo pin to go high
    while GPIO.input(ECHO) == 0:
        pulse_start = time.time()

    # Wait for the echo pin to go low
    while GPIO.input(ECHO) == 1:
        pulse_end = time.time()

    # Calculate the duration of the pulse
    pulse_duration = pulse_end - pulse_start

    # Calculate the distance (in cm)
    distance = pulse_duration * 17150
    distance = round(distance, 2)

    # Detect if an object is within a certain distance (e.g., 10 cm)
    if distance < 150:
        print("Object detected!")
    else:
        print("No object detected.")

try:
    print("Starting object detection...")
    while True:
        detect_object()
        time.sleep(1)  # Check every second

except KeyboardInterrupt:
    print("Measurement stopped by User")
    GPIO.cleanup()  # Clean up GPIO on exit
