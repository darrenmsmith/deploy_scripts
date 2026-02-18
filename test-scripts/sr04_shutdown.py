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

def disable_sensor():
    # Set the trigger pin to LOW to disable the sensor
    GPIO.output(TRIG, GPIO.LOW)
    print("JSN-SR04T sensor disabled.")

def cleanup():
    print("Cleaning up GPIO settings...")
    GPIO.cleanup()  # Reset GPIO settings

try:
    disable_sensor()  # Disable the sensor
    time.sleep(1)  # Wait a moment to ensure the sensor is disabled

except KeyboardInterrupt:
    print("Script interrupted by User")
    
finally:
    cleanup()  # Ensure GPIO is cleaned up on exit
