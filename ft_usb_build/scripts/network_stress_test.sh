#!/bin/bash

################################################################################
# Network Stress Test and Connection Monitor
# Tests wlan1 connection stability over time with detailed logging
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Configuration
DURATION="${1:-300}"  # Default 5 minutes, or use argument
INTERVAL=5            # Check every 5 seconds
LOG_FILE="/mnt/usb/install_logs/network_stress_test_$(date +%Y%m%d_%H%M%S).log"

# Initialize log
{
    echo "========================================"
    echo "Network Stress Test"
    echo "========================================"
    echo "Date: $(date)"
    echo "Duration: ${DURATION} seconds"
    echo "Check interval: ${INTERVAL} seconds"
    echo "========================================"
    echo ""
} | tee "$LOG_FILE"

print_info "Starting network stress test for ${DURATION} seconds..."
print_info "Log file: $LOG_FILE"
echo ""

# Counters
CHECKS=0
FAILURES=0
CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=5
START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))

# Function to log with timestamp
log_with_time() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check network status
check_network() {
    local elapsed=$1
    local check_num=$2

    log_with_time "=== Check #${check_num} (${elapsed}s elapsed) ==="

    # Check wlan1 interface exists
    if ! ip link show wlan1 &>/dev/null; then
        log_with_time "ERROR: wlan1 interface missing!"
        return 1
    fi
    log_with_time "OK: wlan1 interface exists"

    # Check wlan1 is UP
    if ! ip link show wlan1 | grep -q "state UP"; then
        log_with_time "ERROR: wlan1 is DOWN!"
        return 1
    fi
    log_with_time "OK: wlan1 is UP"

    # Check WiFi association
    local ssid=$(iw dev wlan1 link | grep "SSID:" | awk '{print $2}')
    if [ -z "$ssid" ]; then
        log_with_time "ERROR: Not connected to any WiFi network!"
        return 1
    fi
    log_with_time "OK: Connected to SSID: $ssid"

    # Check signal strength
    local signal=$(iw dev wlan1 link | grep "signal:" | awk '{print $2, $3}')
    log_with_time "INFO: Signal strength: $signal"

    # Check wpa_supplicant is running
    if ! pgrep -f "wpa_supplicant.*wlan1" >/dev/null; then
        log_with_time "ERROR: wpa_supplicant not running for wlan1!"
        return 1
    fi
    log_with_time "OK: wpa_supplicant running"

    # Check dhcpcd is running
    if ! pgrep -f "dhcpcd.*wlan1" >/dev/null; then
        log_with_time "WARNING: dhcpcd not running for wlan1!"
        # Not a hard failure, but concerning
    else
        log_with_time "OK: dhcpcd running"
    fi

    # Check IPv4 address
    local ipv4=$(ip addr show wlan1 | grep "inet " | grep -v "169.254" | awk '{print $2}')
    if [ -z "$ipv4" ]; then
        log_with_time "ERROR: No IPv4 address on wlan1!"
        return 1
    fi
    log_with_time "OK: IPv4 address: $ipv4"

    # Check DNS resolution
    if ! host google.com &>/dev/null; then
        log_with_time "ERROR: DNS resolution failed!"
        return 1
    fi
    log_with_time "OK: DNS resolution working"

    # Check internet connectivity (ping Google DNS)
    local ping_result=$(ping -c 3 -W 2 8.8.8.8 2>&1)
    local packet_loss=$(echo "$ping_result" | grep "packet loss" | grep -oE "[0-9]+%" | tr -d '%')

    if [ -z "$packet_loss" ]; then
        log_with_time "ERROR: Ping to 8.8.8.8 failed completely!"
        log_with_time "Ping output: $ping_result"
        return 1
    fi

    log_with_time "OK: Ping 8.8.8.8 - ${packet_loss}% packet loss"

    if [ "$packet_loss" -gt 50 ]; then
        log_with_time "WARNING: High packet loss (${packet_loss}%)!"
    fi

    # Check routes
    local default_route=$(ip route | grep "^default")
    if [ -z "$default_route" ]; then
        log_with_time "ERROR: No default route!"
        return 1
    fi
    log_with_time "OK: Default route exists"
    log_with_time "INFO: $default_route"

    # Check /etc/resolv.conf
    local nameservers=$(grep "^nameserver" /etc/resolv.conf | wc -l)
    log_with_time "INFO: /etc/resolv.conf has $nameservers nameservers"

    # Get RX/TX stats
    local rx_bytes=$(cat /sys/class/net/wlan1/statistics/rx_bytes 2>/dev/null)
    local tx_bytes=$(cat /sys/class/net/wlan1/statistics/tx_bytes 2>/dev/null)
    log_with_time "INFO: RX: $((rx_bytes / 1024)) KB, TX: $((tx_bytes / 1024)) KB"

    # Check for errors
    local rx_errors=$(cat /sys/class/net/wlan1/statistics/rx_errors 2>/dev/null)
    local tx_errors=$(cat /sys/class/net/wlan1/statistics/tx_errors 2>/dev/null)
    if [ "$rx_errors" -gt 0 ] || [ "$tx_errors" -gt 0 ]; then
        log_with_time "WARNING: Interface errors - RX: $rx_errors, TX: $tx_errors"
    fi

    log_with_time "CHECK PASSED"
    echo "" | tee -a "$LOG_FILE"

    return 0
}

# Main monitoring loop
print_info "Monitoring wlan1 connection..."
echo ""

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    # Check if we've exceeded duration
    if [ $CURRENT_TIME -ge $END_TIME ]; then
        break
    fi

    CHECKS=$((CHECKS + 1))

    if check_network "$ELAPSED" "$CHECKS"; then
        print_success "Check #${CHECKS} PASSED"
        CONSECUTIVE_FAILURES=0  # Reset on success
    else
        print_error "Check #${CHECKS} FAILED"
        FAILURES=$((FAILURES + 1))
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))

        # Stop if too many consecutive failures
        if [ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]; then
            echo ""
            print_error "Stopping: ${CONSECUTIVE_FAILURES} consecutive failures detected"
            log_with_time "TEST STOPPED: ${CONSECUTIVE_FAILURES} consecutive failures"
            break
        fi
    fi

    # Sleep for interval
    sleep $INTERVAL
done

# Final report
echo ""
echo "========================================"
echo "Test Complete"
echo "========================================"

{
    echo ""
    echo "========================================"
    echo "Final Report"
    echo "========================================"
    echo "Total duration: ${DURATION} seconds"
    echo "Total checks: ${CHECKS}"
    echo "Successful checks: $((CHECKS - FAILURES))"
    echo "Failed checks: ${FAILURES}"
    echo "Success rate: $(( (CHECKS - FAILURES) * 100 / CHECKS ))%"
    echo "========================================"
} | tee -a "$LOG_FILE"

if [ $FAILURES -eq 0 ]; then
    print_success "ALL CHECKS PASSED - Connection is stable!"
    exit 0
else
    print_error "FAILURES DETECTED - Connection is unstable!"
    print_info "Check log file: $LOG_FILE"
    exit 1
fi
