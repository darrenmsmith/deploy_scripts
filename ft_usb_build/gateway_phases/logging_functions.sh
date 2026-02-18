#!/bin/bash

################################################################################
# Logging Infrastructure for Field Trainer Installation
# Source this file in each phase script
################################################################################

# Default log directory on USB
LOG_DIR="/mnt/usb/install_logs"
LOG_FILE=""
PHASE_NAME=""

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Initialize Logging for a Phase
################################################################################
init_logging() {
    local phase_num=$1
    local phase_desc=$2

    PHASE_NAME="phase${phase_num}_${phase_desc}"

    # Create log directory if needed (no USB check per user request)
    mkdir -p "$LOG_DIR" 2>/dev/null

    # Create timestamped log file
    local timestamp=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="${LOG_DIR}/${PHASE_NAME}_${timestamp}.log"

    # Write header to log
    {
        echo "========================================"
        echo "Field Trainer Installation"
        echo "Phase $phase_num: $phase_desc"
        echo "========================================"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Hostname: $(hostname)"
        echo "User: $(whoami)"
        echo "Working Directory: $(pwd)"
        echo "========================================"
        echo ""
    } > "$LOG_FILE"

    # Also log to symlink for easy access to latest log
    ln -sf "$LOG_FILE" "${LOG_DIR}/${PHASE_NAME}_latest.log" 2>/dev/null

    log_info "Logging initialized: $LOG_FILE"
}

################################################################################
# Logging Functions
################################################################################

log_step() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] STEP: $message" | tee -a "$LOG_FILE"
}

log_info() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] INFO: $message" >> "$LOG_FILE"
}

log_success() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}✓ $message${NC}"
    echo "[$timestamp] SUCCESS: $message" >> "$LOG_FILE"
}

log_error() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}✗ $message${NC}" >&2
    echo "[$timestamp] ERROR: $message" >> "$LOG_FILE"
}

log_warning() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}⚠ $message${NC}"
    echo "[$timestamp] WARNING: $message" >> "$LOG_FILE"
}

log_command() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}ℹ $message${NC}"
    echo "[$timestamp] COMMAND: $message" >> "$LOG_FILE"
}

################################################################################
# Execute Command with Logging
################################################################################

# Execute a command and log both the command and its output
exec_logged() {
    local description=$1
    shift  # Remove first argument, rest is the command
    local cmd="$@"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Mask sensitive info in logs (WiFi passwords)
    local logged_cmd="$cmd"
    if [[ "$cmd" == *"wpa_passphrase"* ]] || [[ "$cmd" == *"password"* ]]; then
        logged_cmd=$(echo "$cmd" | sed 's/\(password[= ]\)[^ ]*/\1********/gi')
    fi

    log_command "$description"
    echo "[$timestamp] EXECUTING: $logged_cmd" >> "$LOG_FILE"
    echo "[$timestamp] ----------------------------------------" >> "$LOG_FILE"

    # Execute command and capture output
    local output
    local exit_code

    output=$("$@" 2>&1)
    exit_code=$?

    # Log output
    echo "$output" >> "$LOG_FILE"
    echo "[$timestamp] EXIT CODE: $exit_code" >> "$LOG_FILE"
    echo "[$timestamp] ----------------------------------------" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    # Return the exit code
    return $exit_code
}

# Execute command, log, and show output to user
exec_logged_verbose() {
    local description=$1
    shift
    local cmd="$@"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Mask sensitive info
    local logged_cmd="$cmd"
    if [[ "$cmd" == *"wpa_passphrase"* ]] || [[ "$cmd" == *"password"* ]]; then
        logged_cmd=$(echo "$cmd" | sed 's/\(password[= ]\)[^ ]*/\1********/gi')
    fi

    log_command "$description"
    echo "[$timestamp] EXECUTING: $logged_cmd" >> "$LOG_FILE"
    echo "[$timestamp] ----------------------------------------" >> "$LOG_FILE"

    # Execute command, show output to user AND log it
    "$@" 2>&1 | tee -a "$LOG_FILE"
    local exit_code=${PIPESTATUS[0]}

    echo "[$timestamp] EXIT CODE: $exit_code" >> "$LOG_FILE"
    echo "[$timestamp] ----------------------------------------" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    return $exit_code
}

################################################################################
# Phase Status Functions
################################################################################

log_phase_start() {
    local phase_num=$1
    local phase_desc=$2

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo ""
    echo "========================================"
    echo "Phase $phase_num: $phase_desc"
    echo "========================================"
    echo ""

    {
        echo ""
        echo "========================================"
        echo "[$timestamp] PHASE START: Phase $phase_num - $phase_desc"
        echo "========================================"
        echo ""
    } >> "$LOG_FILE"
}

log_phase_complete() {
    local phase_num=$1

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo ""
    log_success "Phase $phase_num completed successfully!"
    echo ""

    {
        echo ""
        echo "========================================"
        echo "[$timestamp] PHASE COMPLETE: Phase $phase_num"
        echo "========================================"
        echo ""
    } >> "$LOG_FILE"
}

log_phase_failed() {
    local phase_num=$1
    local error_msg=$2

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo ""
    log_error "Phase $phase_num FAILED: $error_msg"
    echo ""

    {
        echo ""
        echo "========================================"
        echo "[$timestamp] PHASE FAILED: Phase $phase_num"
        echo "[$timestamp] ERROR: $error_msg"
        echo "========================================"
        echo ""
    } >> "$LOG_FILE"
}

################################################################################
# Utility Functions
################################################################################

# Print colored messages (backward compatibility)
print_success() { log_success "$1"; }
print_error() { log_error "$1"; }
print_warning() { log_warning "$1"; }
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log_info "$1"
}

# Get log file path (for showing to user)
get_log_file() {
    echo "$LOG_FILE"
}

# Show tail of log file
show_log_tail() {
    local lines=${1:-20}
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "Last $lines lines of log:"
        echo "----------------------------------------"
        tail -n "$lines" "$LOG_FILE"
        echo "----------------------------------------"
        echo ""
    fi
}

################################################################################
# Export Functions
################################################################################

export -f init_logging
export -f log_step
export -f log_info
export -f log_success
export -f log_error
export -f log_warning
export -f log_command
export -f exec_logged
export -f exec_logged_verbose
export -f log_phase_start
export -f log_phase_complete
export -f log_phase_failed
export -f print_success
export -f print_error
export -f print_warning
export -f print_info
export -f get_log_file
export -f show_log_tail
