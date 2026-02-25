#!/bin/bash

################################################################################
# Phase 6: Field Trainer Application Installation
# Clones the Field Trainer repository and sets up the systemd service
# Updated: PIL dependency, correct clone location, fixed service paths
# Updated: Database initialization with built-in courses and AI Team
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

ERRORS=0

# USB logging - capture all output to log file
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/phase7_fieldtrainer_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
ln -sf "$LOG_FILE" "${LOG_DIR}/phase7_fieldtrainer_latest.log"

echo "========================================"
echo "Field Trainer Installation - Phase 7"
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "Log: $LOG_FILE"
echo "========================================"
echo ""

# Configuration
APP_DIR="/opt"
REPO_URL="https://github.com/darrenmsmith/field-trainer-releases.git"
DEFAULT_BRANCH="main"
SERVICE_FILE="/etc/systemd/system/field-trainer.service"

echo "Phase 6: Field Trainer Application Installation"
echo "================================================"
echo ""
echo "This phase will:"
echo "  • Clone Field Trainer from GitHub to $APP_DIR"
echo "  • Initialize clean database (built-in courses + AI Team)"
echo "  • Install Python dependencies (Flask, Pillow/PIL, etc.)"
echo "  • Create systemd service"
echo "  • Configure auto-start on boot"
echo ""
read -p "Press Enter to begin installation..."
echo ""

################################################################################
# Step 1: Verify Prerequisites
################################################################################

echo "Step 1: Verifying Prerequisites..."
echo "-----------------------------------"

# Check internet
echo -n "  Internet connection... "
if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    print_success "available"
    HAS_INTERNET=true
else
    print_warning "not available"
    print_info "Internet is recommended for cloning repository"
    HAS_INTERNET=false
fi

# Check git
echo -n "  git... "
if command -v git &>/dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    print_success "available (v$GIT_VERSION)"
else
    print_error "not found"
    print_info "Install with: sudo apt install -y git"
    ERRORS=$((ERRORS + 1))
fi

# Check Python
echo -n "  Python 3... "
if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    print_success "available (v$PYTHON_VERSION)"
else
    print_error "not found"
    print_info "Install with: sudo apt install -y python3"
    ERRORS=$((ERRORS + 1))
fi

# Check Flask
echo -n "  Flask... "
if python3 -c "import flask" 2>/dev/null; then
    FLASK_VERSION=$(python3 -c "import flask; print(flask.__version__)" 2>/dev/null)
    print_success "available (v$FLASK_VERSION)"
else
    print_error "not found"
    print_info "Install with: sudo apt install -y python3-flask"
    ERRORS=$((ERRORS + 1))
fi

# Check Pillow (PIL) - CRITICAL for coach interface
echo -n "  Pillow (PIL)... "
if python3 -c "import PIL" 2>/dev/null; then
    PIL_VERSION=$(python3 -c "import PIL; print(PIL.__version__)" 2>/dev/null)
    print_success "available (v$PIL_VERSION)"
else
    print_warning "not found - will install now"
    if [ "$HAS_INTERNET" = true ]; then
        echo ""
        print_info "Installing Pillow (PIL)..."

        # Try apt first
        if sudo apt install -y python3-pil &>/dev/null; then
            if python3 -c "import PIL" 2>/dev/null; then
                PIL_VERSION=$(python3 -c "import PIL; print(PIL.__version__)" 2>/dev/null)
                print_success "Pillow installed via apt (v$PIL_VERSION)"
            else
                # Try pip as fallback
                print_info "apt install succeeded but import failed, trying pip..."
                if pip3 install Pillow --break-system-packages &>/dev/null; then
                    print_success "Pillow installed via pip"
                else
                    print_error "Failed to install Pillow"
                    ERRORS=$((ERRORS + 1))
                fi
            fi
        else
            # apt failed, try pip
            print_info "apt install failed, trying pip..."
            if pip3 install Pillow --break-system-packages 2>&1; then
                print_success "Pillow installed via pip"
            else
                print_error "Failed to install Pillow"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    else
        print_error "no internet - cannot install"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check bat0 (mesh network)
echo -n "  bat0 (mesh network)... "
if ip link show bat0 &>/dev/null; then
    BAT0_IP=$(ip addr show bat0 | grep "inet " | awk '{print $2}')
    if [ -n "$BAT0_IP" ]; then
        print_success "UP with IP $BAT0_IP"
    else
        print_warning "UP but no IP address"
    fi
else
    print_warning "not found"
    print_info "Application will work but mesh features unavailable"
fi

echo ""

if [ $ERRORS -gt 0 ]; then
    print_error "Prerequisites not met. Please fix issues before continuing."
    exit 1
fi

################################################################################
# Step 2: Prompt for Repository Information
################################################################################

echo "Step 2: Repository Configuration..."
echo "------------------------------------"

# Repository URL
echo ""
print_info "Default repository: $REPO_URL"
read -p "Enter repository URL (or press Enter for default): " USER_REPO_URL

if [ -n "$USER_REPO_URL" ]; then
    REPO_URL="$USER_REPO_URL"
    print_info "Using: $REPO_URL"
else
    print_info "Using default repository"
fi

# Version/Branch selection
echo ""
print_info "Fetching available releases from GitHub..."

# Get latest release tag from repository
LATEST_RELEASE=$(git ls-remote --tags --refs "$REPO_URL" | grep -oP 'refs/tags/v\K[0-9]{4}\.[0-9]{2}\.[0-9]{2}' | sort -V | tail -1)

if [ -n "$LATEST_RELEASE" ]; then
    LATEST_TAG="v${LATEST_RELEASE}"
    print_success "Latest release: $LATEST_TAG"
    echo ""
    print_info "Version options:"
    echo "  1. $LATEST_TAG (latest release - RECOMMENDED)"
    echo "  2. main (bleeding edge - latest development)"
    echo "  3. Custom version/branch"
    echo ""
    read -p "Select option (1/2/3, default: 1): " VERSION_CHOICE

    case "$VERSION_CHOICE" in
        2)
            BRANCH_NAME="main"
            print_info "Selected: main branch (development)"
            ;;
        3)
            echo ""
            read -p "Enter custom version tag or branch name: " BRANCH_NAME
            if [ -z "$BRANCH_NAME" ]; then
                print_error "No version specified, using latest release"
                BRANCH_NAME="$LATEST_TAG"
            fi
            print_info "Selected: $BRANCH_NAME"
            ;;
        1|"")
            BRANCH_NAME="$LATEST_TAG"
            print_info "Selected: $LATEST_TAG (latest stable release)"
            ;;
        *)
            print_warning "Invalid option, using latest release"
            BRANCH_NAME="$LATEST_TAG"
            ;;
    esac
else
    print_warning "Could not fetch releases, using main branch"
    BRANCH_NAME="$DEFAULT_BRANCH"
fi

echo ""
print_info "Will clone: $BRANCH_NAME from $REPO_URL"

echo ""

################################################################################
# Step 3: Check Existing Installation
################################################################################

echo "Step 3: Checking for Existing Installation..."
echo "-----------------------------------------------"

if [ -d "$APP_DIR/.git" ]; then
    print_warning "Git repository already exists in $APP_DIR"

    # Check current branch
    CURRENT_BRANCH=$(cd $APP_DIR && git branch --show-current 2>/dev/null)
    if [ -n "$CURRENT_BRANCH" ]; then
        print_info "Current branch: $CURRENT_BRANCH"
    fi

    # Check for uncommitted changes
    cd $APP_DIR
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "Uncommitted changes detected"
        echo ""
        git status --short | head -10
        echo ""
    fi

    echo ""
    read -p "Update existing repository? (y/n): " UPDATE_REPO

    if [[ "$UPDATE_REPO" =~ ^[Yy]$ ]]; then
        print_info "Will update existing repository"
        UPDATE_MODE=true
    else
        print_info "Will skip repository update"
        UPDATE_MODE=false
    fi
elif [ "$(ls -A $APP_DIR 2>/dev/null)" ]; then
    print_warning "$APP_DIR exists and is not empty"
    echo ""
    print_info "Contents:"
    ls -la $APP_DIR | head -10
    echo ""
    read -p "Continue anyway? This will clone into the existing directory (y/n): " CONTINUE

    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        print_error "Installation cancelled"
        exit 1
    fi
    UPDATE_MODE=false
else
    print_info "$APP_DIR is empty or doesn't exist"
    UPDATE_MODE=false
fi

echo ""

################################################################################
# Step 4: Clone or Update Repository
################################################################################

echo "Step 4: Setting Up Repository..."
echo "---------------------------------"

# Ensure directory exists
if [ ! -d "$APP_DIR" ]; then
    print_info "Creating $APP_DIR..."
    if sudo mkdir -p $APP_DIR; then
        print_success "Directory created"
    else
        print_error "Failed to create directory"
        ERRORS=$((ERRORS + 1))
        exit 1
    fi
fi

# Set ownership to pi user
print_info "Setting ownership to pi user..."
sudo chown -R pi:pi $APP_DIR

if [ "$UPDATE_MODE" = true ]; then
    # Update existing repository
    print_info "Updating repository in $APP_DIR..."

    cd $APP_DIR

    # Fetch latest changes
    print_info "Fetching latest changes..."
    if git fetch origin; then
        print_success "Fetched successfully"
    else
        print_error "Failed to fetch"
        ERRORS=$((ERRORS + 1))
    fi

    # Checkout requested branch
    print_info "Checking out branch: $BRANCH_NAME"
    if git checkout $BRANCH_NAME; then
        print_success "Checked out $BRANCH_NAME"
    else
        print_error "Failed to checkout $BRANCH_NAME"
        ERRORS=$((ERRORS + 1))
    fi

    # Pull latest
    print_info "Pulling latest changes..."
    if git pull origin $BRANCH_NAME; then
        print_success "Updated successfully"
    else
        print_warning "Pull had conflicts or errors"
    fi

else
    # Fresh clone
    if [ -d "$APP_DIR/.git" ]; then
        print_info "Repository already exists, skipping clone"
    else
        print_info "Cloning $REPO_URL (branch: $BRANCH_NAME) to $APP_DIR..."

        cd $APP_DIR

        # Clone directly into current directory (not a subdirectory)
        if sudo -u pi git clone --branch "$BRANCH_NAME" "$REPO_URL" .; then
            print_success "Repository cloned successfully"
        else
            print_error "Failed to clone repository"
            print_info "Check that:"
            echo "  • Repository URL is correct"
            echo "  • Branch name exists"
            echo "  • You have internet connection"
            echo "  • You have access permissions"
            ERRORS=$((ERRORS + 1))
            exit 1
        fi
    fi
fi

# Verify clone
echo ""
print_info "Verifying repository..."

if [ -f "$APP_DIR/field_trainer_main.py" ]; then
    print_success "Main application file found"
else
    print_error "field_trainer_main.py not found in $APP_DIR"
    print_info "Repository structure may be incorrect"
    ERRORS=$((ERRORS + 1))
fi

# Show current status
cd $APP_DIR
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)

print_info "Repository status:"
echo "  Branch: $CURRENT_BRANCH"
echo "  Commit: $CURRENT_COMMIT"
echo "  Location: $APP_DIR"

echo ""

################################################################################
# Step 5: Create Data Directory
################################################################################

echo "Step 5: Creating Data Directory..."
echo "-----------------------------------"

DATA_DIR="$APP_DIR/data"

if [ -d "$DATA_DIR" ]; then
    print_info "Data directory already exists"
else
    print_info "Creating $DATA_DIR..."
    if mkdir -p $DATA_DIR; then
        print_success "Data directory created"
    else
        print_error "Failed to create data directory"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Set ownership
sudo chown -R pi:pi $DATA_DIR

echo ""

################################################################################
# Step 5.5: Initialize Clean Database
################################################################################

echo "Step 5.5: Initializing Database..."
echo "-----------------------------------"

DB_FILE="$DATA_DIR/field_trainer.db"
INIT_SCRIPT="$APP_DIR/scripts/init_clean_database.py"

# Check if database initialization script exists
if [ ! -f "$INIT_SCRIPT" ]; then
    if [ -f "$DB_FILE" ]; then
        print_warning "Init script not found but existing database found - skipping initialization"
        print_info "Using existing database: $DB_FILE ($(( $(stat -c%s "$DB_FILE") / 1024 )) KB)"
    else
        print_error "Database initialization script not found and no existing database!"
        print_info "Expected location: $INIT_SCRIPT"
        print_warning "Application may not start correctly without a database"
        ERRORS=$((ERRORS + 1))
    fi
    SKIP_DB_INIT=true
else
    SKIP_DB_INIT=false
fi

if [ "$SKIP_DB_INIT" = false ]; then
    if [ -f "$DB_FILE" ]; then
        print_warning "Database already exists at $DB_FILE"

        # Show database info
        DB_SIZE=$(stat -c%s "$DB_FILE" 2>/dev/null || echo "0")
        print_info "Current size: $((DB_SIZE / 1024)) KB"

        echo ""
        print_warning "Reinitializing will ERASE all existing data!"
        read -p "Reinitialize database? (y/n): " REINIT

        if [[ "$REINIT" =~ ^[Yy]$ ]]; then
            print_info "Creating backup..."
            BACKUP_FILE="$DB_FILE.backup_$(date +%Y%m%d_%H%M%S)"

            if cp "$DB_FILE" "$BACKUP_FILE"; then
                print_success "Backup saved to $BACKUP_FILE"
                INIT_DB=true
            else
                print_error "Failed to create backup!"
                INIT_DB=false
            fi
        else
            print_info "Keeping existing database"
            INIT_DB=false
        fi
    else
        print_info "No database found - will create clean database"
        INIT_DB=true
    fi

    if [ "$INIT_DB" = true ]; then
        print_info "Running database initialization script..."
        echo ""

        # Run the initialization script
        if python3 "$INIT_SCRIPT" "$DB_FILE"; then
            echo ""
            print_success "Database initialized successfully!"

            # Verify database was created
            if [ -f "$DB_FILE" ]; then
                DB_SIZE=$(stat -c%s "$DB_FILE" 2>/dev/null)
                print_info "Database created: $((DB_SIZE / 1024)) KB"

                # Quick verification of contents
                print_info "Verifying database contents..."

                COURSE_COUNT=$(python3 -c "import sqlite3; conn = sqlite3.connect('$DB_FILE'); c = conn.execute('SELECT COUNT(*) FROM courses WHERE is_builtin=1').fetchone()[0]; conn.close(); print(c)" 2>/dev/null)
                TEAM_COUNT=$(python3 -c "import sqlite3; conn = sqlite3.connect('$DB_FILE'); c = conn.execute('SELECT COUNT(*) FROM teams').fetchone()[0]; conn.close(); print(c)" 2>/dev/null)
                ATHLETE_COUNT=$(python3 -c "import sqlite3; conn = sqlite3.connect('$DB_FILE'); c = conn.execute('SELECT COUNT(*) FROM athletes').fetchone()[0]; conn.close(); print(c)" 2>/dev/null)

                if [ -n "$COURSE_COUNT" ] && [ "$COURSE_COUNT" -gt 0 ]; then
                    print_success "Built-in courses: $COURSE_COUNT"
                else
                    print_warning "Built-in courses: 0 (expected 14)"
                fi

                if [ -n "$TEAM_COUNT" ] && [ "$TEAM_COUNT" -gt 0 ]; then
                    print_success "Teams: $TEAM_COUNT (AI Team)"
                else
                    print_warning "Teams: 0 (expected 1 AI Team)"
                fi

                if [ "$ATHLETE_COUNT" = "0" ]; then
                    print_success "Athletes: 0 (clean database)"
                else
                    print_warning "Athletes: $ATHLETE_COUNT (expected 0 for clean database)"
                fi

            else
                print_error "Database file not created!"
                ERRORS=$((ERRORS + 1))
            fi
        else
            print_error "Database initialization failed!"
            print_info "You will need to run manually:"
            echo "  python3 $INIT_SCRIPT $DB_FILE"
            ERRORS=$((ERRORS + 1))
        fi
    fi
fi

echo ""

################################################################################
# Step 6: Install Additional Python Dependencies (if requirements.txt exists)
################################################################################

echo "Step 6: Checking Python Dependencies..."
echo "----------------------------------------"

if [ -f "$APP_DIR/requirements.txt" ]; then
    print_info "requirements.txt found"

    if [ "$HAS_INTERNET" = true ]; then
        read -p "Install Python dependencies from requirements.txt? (y/n): " INSTALL_DEPS

        if [[ "$INSTALL_DEPS" =~ ^[Yy]$ ]]; then
            print_info "Installing dependencies..."

            if pip3 install -r $APP_DIR/requirements.txt --break-system-packages; then
                print_success "Dependencies installed"
            else
                print_warning "Some dependencies may have failed to install"
            fi
        else
            print_info "Skipping dependency installation"
        fi
    else
        print_warning "No internet - skipping dependency installation"
    fi
else
    print_info "No requirements.txt found - skipping"
fi

echo ""

################################################################################
# Step 7: Verify Critical Dependencies Again
################################################################################

echo "Step 7: Final Dependency Verification..."
echo "-----------------------------------------"

# Verify PIL one more time
echo -n "  Pillow (PIL)... "
if python3 -c "import PIL" 2>/dev/null; then
    print_success "✓ available"
else
    print_error "✗ MISSING (coach interface will fail)"
    ERRORS=$((ERRORS + 1))
fi

# Verify Flask
echo -n "  Flask... "
if python3 -c "import flask" 2>/dev/null; then
    print_success "✓ available"
else
    print_error "✗ MISSING"
    ERRORS=$((ERRORS + 1))
fi

# Verify sqlite3
echo -n "  sqlite3... "
if python3 -c "import sqlite3" 2>/dev/null; then
    print_success "✓ available"
else
    print_warning "⚠ not available (may impact database features)"
fi

echo ""

################################################################################
# Step 8: Pre-Service Database Verification
################################################################################

echo "Step 8: Pre-Service Database Check..."
echo "--------------------------------------"

if [ ! -f "$DB_FILE" ]; then
    print_error "Database not found at $DB_FILE!"
    print_warning "Service will likely fail to start without a database"
    print_info "To create database manually, run:"
    echo "  python3 $INIT_SCRIPT $DB_FILE"
    ERRORS=$((ERRORS + 1))
else
    print_success "Database file exists"
    DB_SIZE=$(stat -c%s "$DB_FILE" 2>/dev/null)
    print_info "Database size: $((DB_SIZE / 1024)) KB"
fi

echo ""

################################################################################
# Step 9: Create Systemd Service
################################################################################

echo "Step 9: Creating Systemd Service..."
echo "------------------------------------"

if [ -f "$SERVICE_FILE" ]; then
    print_warning "Service file already exists"
    read -p "Overwrite existing service? (y/n): " OVERWRITE

    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        print_info "Keeping existing service"
        SKIP_SERVICE=true
    else
        SKIP_SERVICE=false
    fi
else
    SKIP_SERVICE=false
fi

if [ "$SKIP_SERVICE" = false ]; then
    print_info "Creating $SERVICE_FILE..."

    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Field Trainer Application - Device 0
After=network.target batman-mesh.service dnsmasq.service
Wants=batman-mesh.service dnsmasq.service

[Service]
Type=simple
User=pi
WorkingDirectory=/opt
ExecStart=/usr/bin/python3 /opt/field_trainer_main.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Environment
Environment="PYTHONUNBUFFERED=1"
Environment="FIELD_TRAINER_ENABLE_SERVER_AUDIO=1"
Environment="FIELD_TRAINER_ENABLE_SERVER_LED=1"
Environment="FIELD_TRAINER_LED_PIN=12"
Environment="FIELD_TRAINER_LED_COUNT=15"
Environment="FIELD_TRAINER_LED_BRIGHTNESS=128"

[Install]
WantedBy=multi-user.target
EOF

    if [ $? -eq 0 ]; then
        print_success "Service file created"
    else
        print_error "Failed to create service file"
        ERRORS=$((ERRORS + 1))
    fi

    # Reload systemd
    print_info "Reloading systemd daemon..."
    if sudo systemctl daemon-reload; then
        print_success "Systemd reloaded"
    else
        print_error "Failed to reload systemd"
        ERRORS=$((ERRORS + 1))
    fi
fi

echo ""

################################################################################
# Step 10: Enable and Start Service
################################################################################

echo "Step 10: Service Configuration..."
echo "----------------------------------"

# Enable service
print_info "Enabling field-trainer service..."
if sudo systemctl enable field-trainer.service; then
    print_success "Service enabled (will start on boot)"
else
    print_error "Failed to enable service"
    ERRORS=$((ERRORS + 1))
fi

# Ask to start now
echo ""
read -p "Start field-trainer service now? (y/n): " START_NOW

if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    print_info "Starting field-trainer service..."

    if sudo systemctl start field-trainer.service; then
        print_success "Service started"

        # Wait a moment for service to initialize
        sleep 3

        # Check status
        if systemctl is-active --quiet field-trainer.service; then
            print_success "Service is running"

            # Check listening ports
            echo ""
            print_info "Checking listening ports..."
            sleep 2

            PORT_5000=$(sudo ss -tlpn | grep ":5000" | wc -l)
            PORT_5001=$(sudo ss -tlpn | grep ":5001" | wc -l)

            if [ "$PORT_5000" -gt 0 ]; then
                print_success "Port 5000 (Web Interface) is listening"
            else
                print_warning "Port 5000 not listening yet"
            fi

            if [ "$PORT_5001" -gt 0 ]; then
                print_success "Port 5001 (Coach Interface) is listening"
            else
                print_warning "Port 5001 not listening yet (check for PIL errors)"
            fi

            # Show recent logs
            echo ""
            print_info "Recent logs (last 15 lines):"
            sudo journalctl -u field-trainer.service -n 15 --no-pager

        else
            print_error "Service failed to start"
            echo ""
            print_info "Service status:"
            sudo systemctl status field-trainer.service --no-pager
            ERRORS=$((ERRORS + 1))
        fi
    else
        print_error "Failed to start service"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_info "Service not started (start manually with: sudo systemctl start field-trainer.service)"
fi

echo ""

################################################################################
# Summary
################################################################################

echo "==============================="
echo "Installation Summary"
echo "==============================="
echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "Field Trainer installed successfully!"
    echo ""
    print_info "Installation details:"
    echo "  • Repository: $REPO_URL"
    echo "  • Branch: $BRANCH_NAME"
    echo "  • Location: $APP_DIR"
    echo "  • Database: $DB_FILE"
    echo "  • Service: field-trainer.service"
    echo ""

    # Get bat0 IP if available
    BAT0_IP=$(ip addr show bat0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

    if [ -n "$BAT0_IP" ]; then
        print_info "Access URLs (from mesh network):"
        echo "  • Web Interface: http://$BAT0_IP:5000"
        echo "  • Coach Interface: http://$BAT0_IP:5001"
    fi

    # Get wlan1 IP if available
    WLAN1_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d'/' -f1)

    if [ -n "$WLAN1_IP" ]; then
        echo ""
        print_info "Access URLs (from home WiFi):"
        echo "  • Web Interface: http://$WLAN1_IP:5000"
        echo "  • Coach Interface: http://$WLAN1_IP:5001"
    fi

    echo ""
    print_info "Useful commands:"
    echo "  • Check service: sudo systemctl status field-trainer"
    echo "  • View logs: sudo journalctl -u field-trainer -f"
    echo "  • Restart service: sudo systemctl restart field-trainer"
    echo "  • Update code: cd /opt && git pull"
    echo ""

    # ── Touch Sensor Calibration ─────────────────────────────────────────────
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_header "  Touch Sensor Calibration (D0 Gateway)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Calibration measures the resting baseline and detects"
    echo "  5 taps to calculate the optimal touch threshold."
    echo ""

    CAL_SCRIPT="/opt/field_trainer/scripts/calibrate_touch.py"
    if [ ! -f "$CAL_SCRIPT" ]; then
        print_warning "Calibration script not found - skipping"
        print_info "You can calibrate later via Settings → Calibration"
    else
        read -p "  Calibrate D0 touch sensor now? (y/n): " DO_CAL
        if [[ "$DO_CAL" =~ ^[Yy]$ ]]; then
            echo ""
            print_info "Stopping service to free I2C bus..."
            sudo systemctl stop field-trainer.service
            sleep 1
            echo ""
            echo "  Place the device on a flat surface and keep it still."
            echo "  When prompted, tap the device firmly 5 times."
            echo ""

            CAL_SUCCESS=false
            for attempt in 1 2 3; do
                [ $attempt -gt 1 ] && echo "" && echo "  Retry $attempt of 3..."
                python3 "$CAL_SCRIPT" 192.168.99.100 5
                if [ $? -eq 0 ]; then
                    CAL_SUCCESS=true
                    break
                fi
                if [ $attempt -lt 3 ]; then
                    read -p "  Calibration failed. Retry? (y/n): " RETRY_CAL
                    [[ "$RETRY_CAL" =~ ^[Yy]$ ]] || break
                fi
            done

            echo ""
            print_info "Restarting service..."
            sudo systemctl start field-trainer.service
            sleep 2

            if $CAL_SUCCESS; then
                print_success "Touch sensor calibrated!"
            else
                print_warning "Calibration incomplete - you can calibrate later via:"
                echo "    Settings → Calibration → D0 → Calibrate"
            fi
        else
            print_info "Skipping - calibrate later via Settings → Calibration"
        fi
    fi
    echo ""

    # Final recommendations
    print_info "Next steps:"
    echo "  1. Test web interfaces via URLs above"
    echo "  2. Check logs for any errors"
    echo "  3. Verify built-in courses and AI Team are present"
    echo "  4. Reboot to test auto-start"
    echo ""

    # Ask about reboot
    read -p "Reboot now to test auto-start? (y/n): " REBOOT_NOW

    if [[ "$REBOOT_NOW" =~ ^[Yy]$ ]]; then
        print_info "Rebooting in 5 seconds..."
        print_warning "Press Ctrl+C to cancel"
        sleep 5
        sudo reboot
    else
        print_info "Remember to reboot later to test auto-start!"
    fi

    echo ""
    exit 0
else
    print_error "Found $ERRORS error(s) during installation"
    echo ""
    print_warning "Please resolve issues and try again"
    echo ""
    print_info "Common issues:"
    echo "  • Check internet connection"
    echo "  • Verify repository URL and branch name"
    echo "  • Ensure all dependencies are installed"
    echo "  • Check database initialization script exists"
    echo "  • Check service logs: sudo journalctl -u field-trainer -n 50"
    echo ""
    exit 1
fi
