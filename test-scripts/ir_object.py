import RPi.GPIO as GPIO
import time

# Set the GPIO mode
GPIO.setmode(GPIO.BCM)

# Set up GPIO 17 as an input with a pull-up resistor
# GPIO.setup(17, GPIO.IN, pull_up_down=GPIO.PUD_UP)

# Define the GPIO pin for the IR sensor
# IR_SENSOR_PIN = 17  # Change this to the GPIO pin you are using
IR_SENSOR_PIN = 3 # Pull-up instead of pull-down of 17, no change 

# Set up the GPIO pin as an input
GPIO.setup(IR_SENSOR_PIN, GPIO.IN)

try:
    print("Starting object detection...")
    while True:
        # Read the state of the IR sensor
        if GPIO.input(IR_SENSOR_PIN):
            print("No Object Detected!")
        else:
            print("--- Object Detected.----")
        
        # Wait for a short time before checking again
        time.sleep(0.5)

except KeyboardInterrupt:
    print("Program stopped by User.")

finally:
    # Cleanup GPIO settings
    GPIO.cleanup()
