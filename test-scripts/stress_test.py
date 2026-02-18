import time
import threading
from datetime import datetime
import platform
import socket

def get_rpi_info():
    # Get Raspberry Pi model
    model = platform.uname().machine
    # Get IP address
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)
    return model, ip_address

def cpu_stress_test(duration):
    end_time = time.time() + duration
    log_interval = 60  # Log every 60 seconds
    last_log_time = time.time()

    print("Stress test is running...")
    while time.time() < end_time:
        # Perform a CPU-bound operation
        sum([i * i for i in range(10000)])

        # Log the running time every 60 seconds
        current_time = time.time()
        if current_time - last_log_time >= log_interval:
            elapsed = current_time - (end_time - duration)  # Calculate elapsed time
            log_running_time(elapsed)
            last_log_time = current_time  # Update last log time

def log_running_time(elapsed_time):
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    model, ip_address = get_rpi_info()
    with open("stress_test_log.txt", "a") as log_file:
        log_file.write(f"{current_time} - Stress test running for {elapsed_time:.2f} seconds on {model} with IP {ip_address}\n")

def run_stress_test(duration, num_threads):
    threads = []
    start_time = time.time()

    for _ in range(num_threads):
        thread = threading.Thread(target=cpu_stress_test, args=(duration,))
        thread.start()
        threads.append(thread)

    for thread in threads:
        thread.join()

    end_time = time.time()
    total_elapsed_time = end_time - start_time
    log_results(total_elapsed_time)
    return total_elapsed_time  # Return the total elapsed time for printing

def log_results(total_elapsed_time):
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    model, ip_address = get_rpi_info()
    with open("stress_test_log.txt", "a") as log_file:
        log_file.write(f"{current_time} - Stress test completed in {total_elapsed_time:.2f} seconds on {model} with IP {ip_address}\n")

# Example usage
if __name__ == "__main__":
    # Prompt the user for input with default values
    duration_input = input("Enter the duration of the stress test in seconds (default is 10): ")
    stress_test_duration = int(duration_input) if duration_input else 10  # Default to 10 if empty
    
    threads_input = input("Enter the number of threads to use (default is 4): ")
    number_of_threads = int(threads_input) if threads_input else 4  # Default to 4 if empty
    
    total_time = run_stress_test(stress_test_duration, number_of_threads)
    print(f"Stress test completed in {total_time:.2f} seconds.")


