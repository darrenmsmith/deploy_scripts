#!/bin/bash

################################################################################
# Field Trainer - Unified Build Script
# Supports both Gateway (Device0) and Client (Device1-5) builds
################################################################################

# Get script directory (where USB is mounted)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

################################################################################
# Device Type Detection
################################################################################

HOSTNAME=$(hostname)
DEVICE_TYPE=""
DEVICE_NUM=""

# Detect device type from hostname
if [[ $HOSTNAME =~ Device0 ]] || [[ $HOSTNAME =~ device0 ]]; then
    DEVICE_TYPE="gateway"
    DEVICE_NUM="0"
elif [[ $HOSTNAME =~ Device([1-5]) ]]; then
    DEVICE_TYPE="client"
    DEVICE_NUM="${BASH_REMATCH[1]}"
else
    # Unknown hostname - prompt user
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║         Field Trainer - Unified Build System             ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Current hostname: $HOSTNAME"
    echo ""
    echo "ERROR: Hostname must be 'Device0' (gateway) or 'Device1-5' (client)"
    echo ""
    echo "Please set hostname using:"
    echo "  sudo raspi-config"
    echo "  → System Options → Hostname"
    echo ""
    echo "Or use: sudo hostnamectl set-hostname Device0"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

################################################################################
# Offline Package Detection (runs BEFORE print functions are defined)
################################################################################

if [ "$DEVICE_TYPE" == "gateway" ] && [ -d "$SCRIPT_DIR/packages/debs" ]; then
    PKG_COUNT=$(ls -1 "$SCRIPT_DIR/packages/debs"/*.deb 2>/dev/null | wc -l)

    if [ "$PKG_COUNT" -gt 0 ]; then
        clear
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                                                            ║"
        echo "║         Offline Package Cache Detected on USB             ║"
        echo "║                                                            ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "  Found: $PKG_COUNT packages"
        echo "  Location: $SCRIPT_DIR/packages/debs/"
        echo ""
        echo "  These packages can be installed now without internet."
        echo "  This is recommended if you haven't run Phase 2 yet."
        echo ""

        read -p "Install offline packages now? (y/n): " INSTALL_OFFLINE

        if [[ "$INSTALL_OFFLINE" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Installing offline packages..."
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""

            cd "$SCRIPT_DIR/packages"

            if [ -x install_offline_packages.sh ]; then
                # Use installer script if available
                ./install_offline_packages.sh
                INSTALL_RESULT=$?
            else
                # Manual installation
                echo "Installing .deb files..."
                sudo dpkg -i debs/*.deb 2>&1 | grep -E "Unpacking|Setting up"
                echo ""
                echo "Fixing dependencies..."
                sudo dpkg --configure -a
                INSTALL_RESULT=$?
            fi

            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            if [ $INSTALL_RESULT -eq 0 ]; then
                echo "✓ Offline package installation complete"
            else
                echo "⚠ Some packages may have failed - check output above"
            fi

            echo ""
            read -p "Press Enter to continue with Field Trainer build..."

            cd "$SCRIPT_DIR"
        else
            echo ""
            echo "Skipping offline package installation."
            echo "You can install them later by running:"
            echo "  cd $SCRIPT_DIR/packages"
            echo "  ./install_offline_packages.sh"
            echo ""
            read -p "Press Enter to continue..."
        fi

        clear
    fi
fi

################################################################################
# Color codes and print functions
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

################################################################################
# Configuration based on device type
################################################################################

if [ "$DEVICE_TYPE" == "gateway" ]; then
    PHASES_DIR="$SCRIPT_DIR/gateway_phases"
    STATE_FILE="$SCRIPT_DIR/.build_state_gateway"
    MAX_PHASE=7  # Phases 0-7 (8 total)

    # Gateway phase names
    PHASE_NAMES=(
        "Phase 1: Hardware Verification + udev Rules"
        "Phase 2: Internet Connection (wlan1 - USB WiFi)"
        "Phase 3: Package Installation"
        "Phase 4: BATMAN Mesh Network (wlan0 - Onboard WiFi)"
        "Phase 5: DNS/DHCP Server (dnsmasq)"
        "Phase 6: NAT/Firewall (iptables)"
        "Phase 7: Field Trainer Application"
        "Phase 8: Deploy Client Application to Field Cones"
    )

    DEVICE_NAME="Gateway (Device0)"
    DEVICE_IP="192.168.99.100"
else
    PHASES_DIR="$SCRIPT_DIR/client_phases"
    STATE_FILE="$SCRIPT_DIR/.build_state_client${DEVICE_NUM}"
    MAX_PHASE=5  # Phases 0-5 (6 total)

    # Client phase names
    PHASE_NAMES=(
        "Phase 1: Hardware Verification (Pi Zero W, I2C, SPI, LED, Touch)"
        "Phase 2: Internet Connection (USB WiFi - Temporary)"
        "Phase 3: Package Installation (batman-adv, batctl)"
        "Phase 4: Mesh Network Join (Connect to Device0)"
        "Phase 5: Client Application (Download from Device0)"
        "Phase 6: Update Client Application from Device0"
    )

    DEVICE_NAME="Field Device (Device${DEVICE_NUM})"
    DEVICE_IP="192.168.99.10${DEVICE_NUM}"
fi

CURRENT_PHASE=0

################################################################################
# Functions
################################################################################

# Load current phase from state file
load_state() {
    if [ -f "$STATE_FILE" ]; then
        CURRENT_PHASE=$(cat "$STATE_FILE")
    else
        CURRENT_PHASE=0
    fi
}

# Save current phase to state file
save_state() {
    echo "$1" > "$STATE_FILE"
    sync  # Flush writes to USB to ensure state is saved
}

# Display banner
show_banner() {
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    if [ "$DEVICE_TYPE" == "gateway" ]; then
        echo "║      Field Trainer - Gateway Build System (D0)           ║"
    else
        echo "║      Field Trainer - Client Build System (D${DEVICE_NUM})            ║"
    fi
    echo "║              Automated Installation Script                ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Device: $DEVICE_NAME"
    echo "  IP Address: $DEVICE_IP"
    echo "  Phases Directory: $(basename $PHASES_DIR)"
    echo ""
}

# Show current progress
show_progress() {
    echo "Build Progress:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for i in "${!PHASE_NAMES[@]}"; do
        if [ $i -lt $CURRENT_PHASE ]; then
            echo -e "${GREEN}✓${NC} ${PHASE_NAMES[$i]}"
        elif [ $i -eq $CURRENT_PHASE ]; then
            echo -e "${CYAN}▶${NC} ${PHASE_NAMES[$i]} ${YELLOW}(Next)${NC}"
        else
            echo -e "${CYAN}○${NC} ${PHASE_NAMES[$i]}"
        fi
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Run a specific phase
run_phase() {
    local PHASE_NUM=$1
    local PHASE_SCRIPT="$PHASES_DIR/phase$((PHASE_NUM + 1))_*.sh"

    # Find the phase script
    local SCRIPT_PATH=$(ls $PHASE_SCRIPT 2>/dev/null | head -1)

    if [ -z "$SCRIPT_PATH" ]; then
        print_error "Phase $((PHASE_NUM + 1)) script not found!"
        echo "  Looking for: $PHASE_SCRIPT"
        return 1
    fi

    if [ ! -x "$SCRIPT_PATH" ]; then
        chmod +x "$SCRIPT_PATH"
    fi

    print_info "Running: ${PHASE_NAMES[$PHASE_NUM]}"
    echo ""

    # Run the phase script
    bash "$SCRIPT_PATH"
    local RESULT=$?

    echo ""

    if [ $RESULT -eq 0 ]; then
        print_success "Phase $((PHASE_NUM + 1)) completed successfully!"
        save_state $((PHASE_NUM + 1))
        CURRENT_PHASE=$((PHASE_NUM + 1))
        return 0
    else
        print_error "Phase $((PHASE_NUM + 1)) failed!"
        echo ""
        read -p "Would you like to retry this phase? (y/n): " RETRY

        if [[ "$RETRY" =~ ^[Yy]$ ]]; then
            return 2  # Retry code
        else
            return 1  # Failure code
        fi
    fi
}

# Test Scripts Menu
show_test_menu() {
    clear
    show_banner

    echo "Test Scripts Menu"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Sensor Testing (all devices)
    echo "Sensor Testing:"
    echo "  1) I2C Sensor Verification (MPU6500/MPU9250)"
    echo ""

    # Mesh Network Status (device-specific)
    echo "Mesh Network Status:"
    if [ "$DEVICE_TYPE" == "gateway" ]; then
        echo "  2) Capture Gateway Mesh Status"
        echo "  3) Diagnose Gateway Mesh Network"
        echo "  4) Manual Mesh Test - Gateway"
        echo "  5) Manual Mesh Test - Gateway (Logged)"
    else
        echo "  2) Capture Client Mesh Status"
        echo "  3) Check Client Mesh Configuration"
        echo "  4) Diagnose Client Mesh Network"
        echo "  5) Diagnose IBSS Connection Issues"
        echo "  6) Manual Mesh Test - Client"
        echo "  7) Manual Mesh Test - Client (Logged)"
    fi
    echo "  8) Quick Mesh Status Check"
    echo "  9) Diagnose Mesh on Boot"
    echo "  10) Capture BATMAN Error Logs"
    echo ""

    # Network & Connectivity (all devices)
    echo "Network & Connectivity:"
    echo "  11) Check Network Interference"
    echo "  12) Check NetworkManager Configuration"
    echo "  13) Diagnose Port 5001 Issues"
    echo ""

    # Application Testing (gateway only)
    if [ "$DEVICE_TYPE" == "gateway" ]; then
        echo "Application Testing:"
        echo "  14) Check Field Trainer Application"
        echo ""
    fi

    # System Verification (all devices)
    echo "System Verification:"
    echo "  15) Verify All Devices in System"
    echo "  16) Verify Recent Fixes Status"
    echo "  17) Check Phase 5 Errors"
    echo "  18) Debug BATMAN Service"
    echo ""

    echo "  0) Back to Main Menu"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "Enter choice: " TEST_CHOICE
}

# Run test script
run_test_script() {
    local SCRIPT_NAME=$1
    local FRIENDLY_NAME=$2

    echo ""
    print_header "Running: $FRIENDLY_NAME"
    echo ""

    if [ -f "$SCRIPT_DIR/$SCRIPT_NAME" ]; then
        bash "$SCRIPT_DIR/$SCRIPT_NAME"
    else
        print_error "Script not found: $SCRIPT_NAME"
        echo "Expected location: $SCRIPT_DIR/$SCRIPT_NAME"
    fi

    echo ""
    read -p "Press Enter to return to test menu..."
}

# Handle test menu selection
handle_test_menu() {
    while true; do
        show_test_menu

        case $TEST_CHOICE in
            0)
                # Back to main menu
                return
                ;;
            1)
                run_test_script "verify_sensors.sh" "I2C Sensor Verification"
                ;;
            2)
                if [ "$DEVICE_TYPE" == "gateway" ]; then
                    run_test_script "capture_device0_mesh_status.sh" "Capture Gateway Mesh Status"
                else
                    run_test_script "capture_client_mesh_status.sh" "Capture Client Mesh Status"
                fi
                ;;
            3)
                if [ "$DEVICE_TYPE" == "gateway" ]; then
                    run_test_script "diagnose_device0_mesh.sh" "Diagnose Gateway Mesh Network"
                else
                    run_test_script "check_client_mesh_config.sh" "Check Client Mesh Configuration"
                fi
                ;;
            4)
                if [ "$DEVICE_TYPE" == "gateway" ]; then
                    run_test_script "manual_mesh_test_device0.sh" "Manual Mesh Test - Gateway"
                else
                    run_test_script "diagnose_client_mesh.sh" "Diagnose Client Mesh Network"
                fi
                ;;
            5)
                if [ "$DEVICE_TYPE" == "gateway" ]; then
                    run_test_script "manual_mesh_test_device0_logged.sh" "Manual Mesh Test - Gateway (Logged)"
                else
                    run_test_script "diagnose_ibss_no_connection.sh" "Diagnose IBSS Connection Issues"
                fi
                ;;
            6)
                if [ "$DEVICE_TYPE" == "client" ]; then
                    run_test_script "manual_mesh_test.sh" "Manual Mesh Test - Client"
                fi
                ;;
            7)
                if [ "$DEVICE_TYPE" == "client" ]; then
                    run_test_script "manual_mesh_test_client_logged.sh" "Manual Mesh Test - Client (Logged)"
                fi
                ;;
            8)
                run_test_script "quick_mesh_check.sh" "Quick Mesh Status Check"
                ;;
            9)
                run_test_script "diagnose_boot_mesh.sh" "Diagnose Mesh on Boot"
                ;;
            10)
                run_test_script "capture_batman_error.sh" "Capture BATMAN Error Logs"
                ;;
            11)
                run_test_script "check_network_interference.sh" "Check Network Interference"
                ;;
            12)
                run_test_script "check_networkmanager_config.sh" "Check NetworkManager Configuration"
                ;;
            13)
                run_test_script "diagnose_port5001_failure.sh" "Diagnose Port 5001 Issues"
                ;;
            14)
                if [ "$DEVICE_TYPE" == "gateway" ]; then
                    run_test_script "check_field_trainer_app.sh" "Check Field Trainer Application"
                fi
                ;;
            15)
                run_test_script "verify_all_devices.sh" "Verify All Devices in System"
                ;;
            16)
                run_test_script "verify_fix_status.sh" "Verify Recent Fixes Status"
                ;;
            17)
                run_test_script "check_phase5_error.sh" "Check Phase 5 Errors"
                ;;
            18)
                run_test_script "debug_batman_service.sh" "Debug BATMAN Service"
                ;;
            *)
                print_error "Invalid choice"
                sleep 1
                ;;
        esac
    done
}

# Main menu
show_menu() {
    echo "What would you like to do?"
    echo ""
    echo "  1) Run Next Phase (Phase $((CURRENT_PHASE + 1)))"
    echo "  2) Run All Remaining Phases"
    echo "  3) Jump to Specific Phase"
    echo "  4) Re-run Current/Previous Phase"
    echo "  5) View Build Status"
    echo "  6) Reset Build (Start Over)"
    echo "  7) Test Scripts"
    echo "  8) Exit"
    echo "  9) Clean Logs and Exit"
    echo ""
    read -p "Enter choice [1-9]: " CHOICE
}

################################################################################
# Main Loop
################################################################################

# Load saved state
load_state

# Main menu loop
while true; do
    show_banner
    show_progress
    show_menu

    case $CHOICE in
        1)
            # Run next phase
            if [ $CURRENT_PHASE -gt $MAX_PHASE ]; then
                print_success "All phases complete!"
                echo ""
                if [ "$DEVICE_TYPE" == "client" ]; then
                    echo "Next steps:"
                    echo "  1. Verify client is visible on Device0 web interface"
                    echo "  2. Test LED states: Deploy a course and check LED colors"
                    echo "  3. Test touch sensor: Touch device during active course"
                    echo "  4. Test audio: Verify sound plays when touched"
                    echo ""
                fi
                read -p "Press Enter to continue..."
            else
                run_phase $CURRENT_PHASE

                if [ $? -eq 2 ]; then
                    # Retry requested
                    continue
                fi

                echo ""
                read -p "Press Enter to continue..."
            fi
            ;;

        2)
            # Run all remaining phases
            while [ $CURRENT_PHASE -le $MAX_PHASE ]; do
                run_phase $CURRENT_PHASE
                RESULT=$?

                if [ $RESULT -eq 1 ]; then
                    # Failed and don't retry
                    break
                elif [ $RESULT -eq 2 ]; then
                    # Retry current phase
                    continue
                fi
            done

            if [ $CURRENT_PHASE -gt $MAX_PHASE ]; then
                print_success "All phases complete!"
            fi

            echo ""
            read -p "Press Enter to continue..."
            ;;

        3)
            # Jump to specific phase
            echo ""
            echo "Available phases:"
            for i in "${!PHASE_NAMES[@]}"; do
                echo "  $((i + 1))) ${PHASE_NAMES[$i]}"
            done
            echo ""
            read -p "Enter phase number [1-$((MAX_PHASE + 1))]: " JUMP_PHASE

            # Convert to 0-indexed
            JUMP_PHASE=$((JUMP_PHASE - 1))

            if [ "$JUMP_PHASE" -ge 0 ] && [ "$JUMP_PHASE" -le "$MAX_PHASE" ]; then
                run_phase $JUMP_PHASE
                echo ""
                read -p "Press Enter to continue..."
            else
                print_error "Invalid phase number"
                sleep 2
            fi
            ;;

        4)
            # Re-run phase
            echo ""
            read -p "Enter phase number to re-run [1-$((MAX_PHASE + 1))]: " RERUN_PHASE

            # Convert to 0-indexed
            RERUN_PHASE=$((RERUN_PHASE - 1))

            if [ "$RERUN_PHASE" -ge 0 ] && [ "$RERUN_PHASE" -le "$MAX_PHASE" ]; then
                run_phase $RERUN_PHASE
                echo ""
                read -p "Press Enter to continue..."
            else
                print_error "Invalid phase number"
                sleep 2
            fi
            ;;

        5)
            # View status
            show_banner
            show_progress
            echo ""
            read -p "Press Enter to continue..."
            ;;

        6)
            # Reset build
            echo ""
            print_warning "This will reset the build state to start over."
            read -p "Are you sure? (y/n): " CONFIRM

            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                save_state 0
                CURRENT_PHASE=0
                print_success "Build state reset to Phase 1"
                sleep 2
            fi
            ;;

        7)
            # Test Scripts
            handle_test_menu
            ;;

        8)
            # Exit
            echo ""
            print_info "Exiting Field Trainer build system"
            exit 0
            ;;

        9)
            # Clean logs and exit
            echo ""
            print_header "Cleaning up log files..."
            echo ""

            # Find and count log files
            LOG_COUNT=0

            # Clean install_logs directory
            if [ -d "$SCRIPT_DIR/../install_logs" ]; then
                LOGS_FOUND=$(find "$SCRIPT_DIR/../install_logs" -name "*.log" -type f 2>/dev/null | wc -l)
                if [ "$LOGS_FOUND" -gt 0 ]; then
                    print_info "Found $LOGS_FOUND log files in install_logs/"
                    rm -f "$SCRIPT_DIR/../install_logs"/*.log 2>/dev/null
                    LOG_COUNT=$((LOG_COUNT + LOGS_FOUND))
                fi
            fi

            # Clean any log files in ft_usb_build directory
            LOGS_FOUND=$(find "$SCRIPT_DIR" -name "*.log" -type f 2>/dev/null | wc -l)
            if [ "$LOGS_FOUND" -gt 0 ]; then
                print_info "Found $LOGS_FOUND log files in ft_usb_build/"
                find "$SCRIPT_DIR" -name "*.log" -type f -delete 2>/dev/null
                LOG_COUNT=$((LOG_COUNT + LOGS_FOUND))
            fi

            # Clean any temp files
            TEMP_COUNT=$(find "$SCRIPT_DIR" -name "*.tmp" -o -name "*.bak" 2>/dev/null | wc -l)
            if [ "$TEMP_COUNT" -gt 0 ]; then
                print_info "Found $TEMP_COUNT temporary files"
                find "$SCRIPT_DIR" -name "*.tmp" -delete 2>/dev/null
                find "$SCRIPT_DIR" -name "*.bak" -delete 2>/dev/null
                LOG_COUNT=$((LOG_COUNT + TEMP_COUNT))
            fi

            # Clean build state files
            STATE_FILES=$(find "$SCRIPT_DIR" -name ".build_state*" -type f 2>/dev/null | wc -l)
            if [ "$STATE_FILES" -gt 0 ]; then
                echo ""
                print_warning "Found $STATE_FILES build state files"
                echo "  This will reset all build progress for all devices."
                read -p "Reset all build progress? (y/n): " RESET_STATE
                if [[ "$RESET_STATE" =~ ^[Yy]$ ]]; then
                    find "$SCRIPT_DIR" -name ".build_state*" -type f -delete 2>/dev/null
                    LOG_COUNT=$((LOG_COUNT + STATE_FILES))
                    print_success "Build state files removed - all devices reset to Phase 1"
                else
                    print_info "Build state files preserved"
                fi
            fi

            echo ""
            if [ "$LOG_COUNT" -gt 0 ]; then
                print_success "Cleaned up $LOG_COUNT files"
            else
                print_info "No log files found to clean"
            fi

            echo ""
            print_info "Exiting Field Trainer build system"
            sleep 2
            exit 0
            ;;

        *)
            print_error "Invalid choice"
            sleep 1
            ;;
    esac
done
