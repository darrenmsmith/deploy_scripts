import time
from rpi_ws281x import PixelStrip, Color

# LED strip configuration:
LED_COUNT = 15        # Number of LED pixels.
LED_PIN = 12          # GPIO pin connected to the pixels (must support PWM).
LED_FREQ_HZ = 800000  # LED signal frequency in hertz (usually 800khz)
LED_DMA = 10          # DMA channel to use for generating the signal.
LED_INVERT = False    # True to invert the signal (when using NPN transistor level shift).
LED_CHANNEL = 0       # set to '1' for GPIOs 13, 19, 41, 45 or 53

# Create an instance of the PixelStrip class.
strip = PixelStrip(LED_COUNT, LED_PIN, LED_FREQ_HZ, LED_DMA, LED_INVERT, 255, LED_CHANNEL)
strip.begin()

# Define a function to set the color of the LEDs
def color_wipe(color, wait_ms=50):
    for i in range(strip.numPixels()):
        strip.setPixelColor(i, color)
        strip.show()
        time.sleep(wait_ms / 1000.0)

# Example usage
if __name__ == '__main__':
    try:
        color_wipe(Color(255, 0, 0))  # Red wipe
        color_wipe(Color(0, 255, 0))  # Green wipe
        color_wipe(Color(0, 0, 255))  # Blue wipe

    except KeyboardInterrupt:
        pass  # Allow the user to exit with CTRL+C
    finally:
        color_wipe(Color(0, 255, 0))  # Turn off LEDs when done
