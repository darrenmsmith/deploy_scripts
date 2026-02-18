import os
import subprocess
import time

#How it works:
#The script prompts the user for the name of the .mp3 file and checks if it exists.
#It asks for the duration to play the file, with a default of 60 seconds.
#It then prompts the user to indicate whether they want the audio to loop until the specified time is met.
#If the user chooses to loop, the script will keep playing the audio file until the total duration is reached. If not, it will play the file just once for the specified duration.

def play_sound(file_path, duration, loop):
    try:
        # Start playing the audio file
        process = subprocess.Popen(['mpg123', file_path])
        print(f"Playing {file_path} for {duration} seconds... (Looping: {'Yes' if loop else 'No'})")
        
        # Loop until the specified duration
        start_time = time.time()
        while time.time() - start_time < duration:
            if not loop:
                time.sleep(duration)
                break
            time.sleep(1)  # Sleep for a short time to avoid busy waiting
        
        # Terminate the process after the duration
        process.terminate()
        print("Playback stopped.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # Ask the user for the audio file name
    audio_file = input("Enter the name of the .mp3 file (with extension): ")
    
    # Check if the file exists
    if os.path.isfile(audio_file):
        # Ask for the duration to play
        duration_input = input("Enter the duration to play the file in seconds (default is 60 seconds): ")
        
        # Set default duration if input is empty
        duration = 60 if duration_input.strip() == "" else int(duration_input)
        
        # Ask if the user wants to loop the audio
        loop_input = input("Do you want the audio to loop until the time is met? (yes/no, default is no): ")
        loop = loop_input.strip().lower() == 'yes'
        
        play_sound(audio_file, duration, loop)
    else:
        print(f"The file '{audio_file}' does not exist. Please check the name and try again.")
