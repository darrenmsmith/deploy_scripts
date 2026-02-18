#!/bin/bash

################################################################################
# Field Trainer Installation Menu
# Interactive menu system with state tracking
################################################################################

# Source logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/phases/logging_functions.sh"

# State file location
STATE_FILE="/mnt/usb/install_state.json"
PHASES_DIR="${SCRIPT_DIR}/phases"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# State Management
################################################################################

init_state() {
    if [ ! -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" << 'EOF'
{
  "phase1": "pending",
  "phase1.5": "pending",
  "phase2": "pending",
  "phase3": "pending",
  "phase4": "pending",
  "phase5": "pending",
  "phase6": "pending",
  "phase7": "pending",
  "last_run": "",
  "installation_started": ""
}
EOF
    fi
}

get_phase_status() {
    local phase=$1
    if [ ! -f "$STATE_FILE" ]; then
        echo "pending"
        return
    fi
    grep "\"$phase\"" "$STATE_FILE" | cut -d'"' -f4
}

set_phase_status() {
    local phase=$1
    local status=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Update state file
    if [ -f "$STATE_FILE" ]; then
        # Simple sed replacement
        sed -i "s/\"$phase\": \"[^\"]*\"/\"$phase\": \"$status\"/" "$STATE_FILE"
        sed -i "s/\"last_run\": \"[^\"]*\"/\"last_run\": \"$timestamp\"/" "$STATE_FILE"

        # Set installation_started if not set
        if ! grep -q "\"installation_started\": \"[0-9]" "$STATE_FILE"; then
            sed -i "s/\"installation_started\": \"\"/\"installation_started\": \"$timestamp\"/" "$STATE_FILE"
        fi
    fi
}

get_next_phase() {
    # Check phases in order: 1, 1.5, 2, 3, 4, 5, 6, 7
    for phase_num in 1 1.5 2 3 4 5 6 7; do
        local status=$(get_phase_status "phase$phase_num")
        if [ "$status" != "completed" ]; then
            echo "$phase_num"
            return
        fi
    done
    echo "0"  # All completed
}

################################################################################
# Phase Descriptions
################################################################################

get_phase_description() {
    local phase_num=$1
    case $phase_num in
        1) echo "Hardware Setup (SSH, I2C, SPI)" ;;
        1.5) echo "Network Prerequisites Check" ;;
        2) echo "Internet Connection (WiFi)" ;;
        3) echo "Package Installation (apt, pip)" ;;
        4) echo "Mesh Network (batman-adv)" ;;
        5) echo "DNS/DHCP Server (dnsmasq)" ;;
        6) echo "NAT/Firewall (iptables)" ;;
        7) echo "Field Trainer Application" ;;
        *) echo "Unknown Phase" ;;
    esac
}

get_phase_script() {
    local phase_num=$1
    case $phase_num in
        1) echo "phase1_hardware.sh" ;;
        1.5) echo "phase1.5_network_prerequisites.sh" ;;
        2) echo "phase2_internet.sh" ;;
        3) echo "phase3_packages.sh" ;;
        4) echo "phase4_mesh.sh" ;;
        5) echo "phase5_dns.sh" ;;
        6) echo "phase6_nat.sh" ;;
        7) echo "phase7_fieldtrainer.sh" ;;
        *) echo "" ;;
    esac
}

################################################################################
# Display Functions
################################################################################

show_header() {
    clear
    echo ""
    echo -e "${CYAN}=======================================${NC}"
    echo -e "${CYAN}  Field Trainer Installation System${NC}"
    echo -e "${CYAN}=======================================${NC}"
    echo ""
}

show_phase_status() {
    local phase_num=$1
    local status=$(get_phase_status "phase$phase_num")
    local desc=$(get_phase_description $phase_num)

    case $status in
        "completed")
            echo -e "  ${GREEN}✓${NC} Phase $phase_num: $desc ${GREEN}[COMPLETED]${NC}"
            ;;
        "in_progress")
            echo -e "  ${YELLOW}⚙${NC} Phase $phase_num: $desc ${YELLOW}[IN PROGRESS]${NC}"
            ;;
        "failed")
            echo -e "  ${RED}✗${NC} Phase $phase_num: $desc ${RED}[FAILED]${NC}"
            ;;
        *)
            echo -e "  ${BLUE}○${NC} Phase $phase_num: $desc [PENDING]"
            ;;
    esac
}

show_all_phases() {
    echo "Installation Progress:"
    echo ""
    for phase_num in 1 1.5 2 3 4 5 6 7; do
        show_phase_status $phase_num
    done
    echo ""
}

################################################################################
# Phase Execution
################################################################################

run_phase() {
    local phase_num=$1
    local script=$(get_phase_script $phase_num)
    local desc=$(get_phase_description $phase_num)

    if [ -z "$script" ] || [ ! -f "${PHASES_DIR}/$script" ]; then
        echo -e "${RED}Error: Phase $phase_num script not found${NC}"
        return 1
    fi

    echo ""
    echo -e "${CYAN}=======================================${NC}"
    echo -e "${CYAN}Starting Phase $phase_num: $desc${NC}"
    echo -e "${CYAN}=======================================${NC}"
    echo ""

    # Set status to in_progress
    set_phase_status "phase$phase_num" "in_progress"

    # Run the phase script
    if sudo bash "${PHASES_DIR}/$script"; then
        # Success
        set_phase_status "phase$phase_num" "completed"
        echo ""
        echo -e "${GREEN}=======================================${NC}"
        echo -e "${GREEN}Phase $phase_num completed successfully!${NC}"
        echo -e "${GREEN}=======================================${NC}"
        echo ""
        return 0
    else
        # Failure
        set_phase_status "phase$phase_num" "failed"
        echo ""
        echo -e "${RED}=======================================${NC}"
        echo -e "${RED}Phase $phase_num FAILED${NC}"
        echo -e "${RED}=======================================${NC}"
        echo ""
        return 1
    fi
}

run_phase_with_retry() {
    local phase_num=$1
    local max_retries=3
    local attempt=1

    while [ $attempt -le $max_retries ]; do
        if [ $attempt -gt 1 ]; then
            echo -e "${YELLOW}Retry attempt $attempt of $max_retries${NC}"
            echo ""
        fi

        run_phase $phase_num

        if [ $? -eq 0 ]; then
            return 0
        fi

        # Failed - offer retry
        if [ $attempt -lt $max_retries ]; then
            echo ""
            echo -e "${YELLOW}Phase $phase_num failed.${NC}"
            echo ""
            echo "Troubleshooting tips:"
            show_troubleshooting_tips $phase_num
            echo ""
            read -p "Would you like to retry this phase? (y/n): " retry_choice

            if [[ ! "$retry_choice" =~ ^[Yy]$ ]]; then
                echo ""
                echo "Stopping installation. You can resume later from the main menu."
                return 1
            fi

            attempt=$((attempt + 1))
        else
            echo ""
            echo -e "${RED}Phase $phase_num failed after $max_retries attempts.${NC}"
            echo ""
            echo "Please review the log files and fix the issues manually."
            echo "Log directory: /mnt/usb/install_logs/"
            return 1
        fi
    done
}

show_troubleshooting_tips() {
    local phase_num=$1

    case $phase_num in
        1)
            echo "  • Reboot the device and try again"
            echo "  • Check that raspi-config is available"
            ;;
        2)
            echo "  • Check WiFi credentials are correct"
            echo "  • Ensure WiFi router is powered on"
            echo "  • Check USB WiFi adapter is plugged in"
            echo "  • Try: sudo systemctl status wlan1-internet"
            ;;
        3)
            echo "  • Check internet connection: ping -c 3 8.8.8.8"
            echo "  • Check DNS: host deb.debian.org"
            echo "  • Check /etc/resolv.conf has nameservers"
            echo "  • Try: sudo apt update"
            echo "  • Wait 2-3 minutes after Phase 2"
            ;;
        4)
            echo "  • Check that Phase 3 completed successfully"
            echo "  • Check batctl is installed: which batctl"
            echo "  • Try: sudo modprobe batman-adv"
            ;;
        5)
            echo "  • Check that dnsmasq is installed"
            echo "  • Check bat0 interface exists: ip addr show bat0"
            ;;
        6)
            echo "  • Check iptables is installed: which iptables"
            echo "  • Check internet still works: ping -c 3 8.8.8.8"
            echo "  • Emergency restore: sudo ${PHASES_DIR}/EMERGENCY_RESTORE_CONNECTIVITY.sh"
            ;;
        7)
            echo "  • Check internet connection works"
            echo "  • Check git is installed: which git"
            echo "  • Check Flask and Pillow: python3 -c 'import flask, PIL'"
            echo "  • Try cloning repo manually"
            ;;
    esac
}

################################################################################
# Menu System
################################################################################

show_main_menu() {
    show_header
    show_all_phases

    local next_phase=$(get_next_phase)

    echo "Options:"
    echo ""

    if [ "$next_phase" != "0" ]; then
        echo "  1) Run Next Phase (Phase $next_phase: $(get_phase_description $next_phase))"
    else
        echo "  1) All phases completed!"
    fi

    echo "  2) Run Specific Phase (manual selection)"
    echo "  3) View Phase Logs"
    echo "  4) Reset Installation State"
    echo "  5) Run Diagnostics"
    echo "  6) Network Stress Test (test wlan1 stability)"
    echo "  7) Verify Sensors (I2C sensor verification)"
    echo "  8) View Help Documentation"
    echo "  9) Exit"
    echo ""
}

menu_run_next() {
    local next_phase=$(get_next_phase)

    if [ "$next_phase" = "0" ]; then
        echo ""
        echo -e "${GREEN}All phases have been completed!${NC}"
        echo ""
        read -p "Press Enter to return to menu..."
        return
    fi

    run_phase_with_retry $next_phase
    echo ""
    read -p "Press Enter to return to menu..."
}

menu_run_specific() {
    show_header
    echo "Select Phase to Run:"
    echo ""

    for phase_num in 1 1.5 2 3 4 5 6 7; do
        show_phase_status $phase_num
    done

    echo ""
    echo "  8) Back to Main Menu"
    echo ""
    read -p "Enter phase number (1-7 or 1.5): " phase_choice

    if [[ "$phase_choice" =~ ^(1|1\.5|2|3|4|5|6|7)$ ]]; then
        run_phase_with_retry $phase_choice
        echo ""
        read -p "Press Enter to return to menu..."
    fi
}

menu_view_logs() {
    show_header
    echo "Available Log Files:"
    echo ""

    if [ -d "/mnt/usb/install_logs" ]; then
        ls -lh /mnt/usb/install_logs/*.log 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
        echo ""
        echo "Log directory: /mnt/usb/install_logs/"
        echo ""
        echo "To view a log: cat /mnt/usb/install_logs/phase1_latest.log"
        echo "To view recent errors: grep ERROR /mnt/usb/install_logs/phase*.log"
    else
        echo "  No logs found yet."
    fi

    echo ""
    read -p "Press Enter to return to menu..."
}

menu_reset_state() {
    show_header
    echo -e "${YELLOW}WARNING: This will reset the installation state.${NC}"
    echo "All phases will be marked as PENDING."
    echo ""
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        rm -f "$STATE_FILE"
        init_state
        echo ""
        echo -e "${GREEN}Installation state has been reset.${NC}"
    else
        echo ""
        echo "Reset cancelled."
    fi

    echo ""
    read -p "Press Enter to return to menu..."
}

menu_diagnostics() {
    show_header
    echo "Running Network Diagnostics..."
    echo ""

    if [ -f "${PHASES_DIR}/DIAGNOSE_CONNECTIVITY.sh" ]; then
        sudo bash "${PHASES_DIR}/DIAGNOSE_CONNECTIVITY.sh"
    else
        echo -e "${RED}Diagnostic script not found.${NC}"
    fi

    echo ""
    read -p "Press Enter to return to menu..."
}

menu_network_stress_test() {
    show_header
    echo "Network Stress Test"
    echo "==================="
    echo ""
    echo "This test monitors wlan1 connection stability over time."
    echo "It checks WiFi association, IP address, DNS, and internet connectivity."
    echo ""
    echo "Recommended duration:"
    echo "  • 300 seconds (5 minutes) - Quick test"
    echo "  • 900 seconds (15 minutes) - Thorough test"
    echo "  • 1800 seconds (30 minutes) - Long-term stability test"
    echo ""
    read -p "Enter test duration in seconds [300]: " duration
    duration=${duration:-300}

    echo ""
    echo "Starting network stress test for $duration seconds..."
    echo "Press Ctrl+C to abort."
    echo ""

    if [ -f "${SCRIPT_DIR}/scripts/network_stress_test.sh" ]; then
        sudo "${SCRIPT_DIR}/scripts/network_stress_test.sh" "$duration"
    else
        echo -e "${RED}Error: network_stress_test.sh not found!${NC}"
        echo "Expected location: ${SCRIPT_DIR}/scripts/network_stress_test.sh"
    fi

    echo ""
    read -p "Press Enter to return to menu..."
}

menu_verify_sensors() {
    show_header
    echo "I2C Sensor Verification"
    echo "======================="
    echo ""
    echo "This will verify:"
    echo "  • i2c-tools installation"
    echo "  • I2C enabled in config.txt"
    echo "  • I2C kernel modules loaded"
    echo "  • I2C device files present"
    echo "  • MPU6050/MPU6500/MPU9250 sensor detection"
    echo "  • Sensor communication test"
    echo "  • Python I2C library test"
    echo ""
    echo "Run this AFTER Phase 3 (Package Installation)"
    echo ""
    read -p "Press Enter to continue..."

    if [ -f "${SCRIPT_DIR}/verify_sensors.sh" ]; then
        echo ""
        sudo bash "${SCRIPT_DIR}/verify_sensors.sh"
    else
        echo -e "${RED}Error: verify_sensors.sh not found!${NC}"
        echo "Expected location: ${SCRIPT_DIR}/verify_sensors.sh"
    fi

    echo ""
    read -p "Press Enter to return to menu..."
}

menu_help() {
    show_header
    echo "Help Documentation:"
    echo ""
    echo "Installation Order:"
    echo "  1. Phase 1: Hardware Setup - Enables SSH, I2C, SPI"
    echo "  2. Phase 1.5: Network Prerequisites - Checks/installs dhcpcd5, wpasupplicant"
    echo "  3. Phase 2: Internet - Connects USB WiFi to home network"
    echo "  4. Phase 3: Packages - Installs all required software"
    echo "  5. Phase 4: Mesh Network - Configures batman-adv mesh"
    echo "  6. Phase 5: DNS/DHCP - Sets up dnsmasq for mesh clients"
    echo "  7. Phase 6: NAT/Firewall - Enables internet sharing"
    echo "  8. Phase 7: Field Trainer - Installs the application"
    echo ""
    echo "Important Notes:"
    echo "  • After Phase 2, wait for the automatic countdown"
    echo "  • Phase 2 includes a 3-minute network stabilization period"
    echo "  • All phases create logs in /mnt/usb/install_logs/"
    echo "  • You can retry failed phases up to 3 times"
    echo "  • Use 'Run Diagnostics' to check network readiness"
    echo "  • Use 'Verify Sensors' after Phase 3 to check I2C sensors"
    echo ""
    echo "Documentation Files:"
    echo "  • /mnt/usb/ft_usb_build/CRITICAL_INSTALLATION_ORDER.md"
    echo "  • /mnt/usb/ft_usb_build/PHASE_ORDER_AND_UPDATES.md"
    echo "  • /mnt/usb/ft_usb_build/PHASE5_PHASE6_FIXES.md"
    echo "  • /mnt/usb/ft_usb_build/I2C_SETUP_GUIDE.md"
    echo ""
    echo "Troubleshooting:"
    echo "  • View logs: ls /mnt/usb/install_logs/"
    echo "  • Check errors: grep ERROR /mnt/usb/install_logs/*.log"
    echo "  • Emergency WiFi restore: EMERGENCY_RESTORE_CONNECTIVITY.sh"
    echo "  • Sensor issues: Run 'Verify Sensors' from menu option 7"
    echo ""
    read -p "Press Enter to return to menu..."
}

################################################################################
# Main Loop
################################################################################

main() {
    # Initialize state tracking
    init_state

    # Main menu loop
    while true; do
        show_main_menu
        read -p "Enter your choice (1-9): " choice

        case $choice in
            1) menu_run_next ;;
            2) menu_run_specific ;;
            3) menu_view_logs ;;
            4) menu_reset_state ;;
            5) menu_diagnostics ;;
            6) menu_network_stress_test ;;
            7) menu_verify_sensors ;;
            8) menu_help ;;
            9)
                echo ""
                echo "Exiting installation menu."
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}Invalid choice. Please enter 1-9.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run main menu
main
