#!/bin/bash
# Diagnose Port 5001 Failure After Restart
# Captures complete state for troubleshooting
# Date: 2026-01-04

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/mnt/usb/ft_usb_build/port5001_diagnostic_${TIMESTAMP}.log"

{
    echo "════════════════════════════════════════════════════════════"
    echo "Port 5001 Diagnostic - After Restart Attempt"
    echo "Timestamp: $(date)"
    echo "Hostname: $(hostname)"
    echo "════════════════════════════════════════════════════════════"
    echo ""

    echo "[1] System Network Configuration"
    echo "──────────────────────────────────────"
    ip addr show | grep -A 2 "inet "
    echo ""

    echo "[2] Field Trainer Service Status"
    echo "──────────────────────────────────────"
    sudo systemctl status field-trainer-server --no-pager -l
    echo ""

    echo "[3] Listening Ports"
    echo "──────────────────────────────────────"
    sudo netstat -tulpn | grep ":500"
    echo ""
    echo "All Python processes with ports:"
    sudo netstat -tulpn | grep python
    echo ""

    echo "[4] Field Trainer Process Information"
    echo "──────────────────────────────────────"
    PID=$(pgrep -f "field_trainer_main.py" | head -1)
    if [ -n "$PID" ]; then
        echo "Process ID: $PID"
        echo ""
        echo "Process details:"
        ps -p $PID -f
        echo ""
        echo "Process start time:"
        ps -p $PID -o lstart --no-headers
        echo ""
        echo "Process runtime:"
        ps -p $PID -o etime --no-headers
        echo ""
    else
        echo "✗ Field Trainer process NOT RUNNING"
        echo ""
    fi

    echo "[5] File Modification Times"
    echo "──────────────────────────────────────"
    echo "field_trainer_main.py:"
    ls -l /opt/field_trainer_main.py 2>/dev/null || echo "  File not found"
    stat /opt/field_trainer_main.py 2>/dev/null | grep "Modify:" || true
    echo ""
    echo "coach_interface.py:"
    ls -l /opt/coach_interface.py 2>/dev/null || echo "  File not found"
    stat /opt/coach_interface.py 2>/dev/null | grep "Modify:" || true
    echo ""

    echo "[6] Coach Interface File Check"
    echo "──────────────────────────────────────"
    if [ -f /opt/coach_interface.py ]; then
        echo "✓ coach_interface.py exists"
        echo "File size: $(wc -l /opt/coach_interface.py | awk '{print $1}') lines"
        echo ""
        echo "First 10 lines:"
        head -10 /opt/coach_interface.py
        echo ""
    else
        echo "✗ coach_interface.py NOT FOUND"
        echo ""
    fi

    echo "[7] Template Directory Check"
    echo "──────────────────────────────────────"
    if [ -d /opt/templates/coach ]; then
        echo "✓ Coach templates directory exists"
        echo "Template files:"
        ls -l /opt/templates/coach/
        echo ""
    else
        echo "✗ Coach templates directory NOT FOUND"
        echo ""
    fi

    echo "[8] Service Logs (Last 100 lines)"
    echo "──────────────────────────────────────"
    sudo journalctl -u field-trainer-server -n 100 --no-pager
    echo ""

    echo "[9] Recent Errors in Service Logs"
    echo "──────────────────────────────────────"
    sudo journalctl -u field-trainer-server --since "10 minutes ago" --no-pager | grep -i "error\|exception\|failed\|traceback" | tail -50
    if [ $? -ne 0 ]; then
        echo "No errors found in last 10 minutes"
    fi
    echo ""

    echo "[10] Test Port Connectivity"
    echo "──────────────────────────────────────"
    echo -n "Port 5000: "
    curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:5000 2>/dev/null
    echo ""

    echo -n "Port 5001: "
    curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:5001 2>/dev/null
    echo ""
    echo ""

    echo "[11] Database Check"
    echo "──────────────────────────────────────"
    if [ -f /opt/data/field_trainer.db ]; then
        echo "✓ Database exists"
        ls -lh /opt/data/field_trainer.db
        echo ""
    else
        echo "✗ Database NOT FOUND"
        echo ""
    fi

    echo "[12] Python Module Import Test"
    echo "──────────────────────────────────────"
    cd /opt
    python3 -c "import sys; sys.path.insert(0, '/opt'); import coach_interface; print('✓ coach_interface imports successfully')" 2>&1
    echo ""

    echo "[13] Check for Port Conflicts"
    echo "──────────────────────────────────────"
    echo "Processes using port 5001:"
    sudo lsof -i :5001 2>/dev/null || echo "No process using port 5001 (lsof may not be installed)"
    echo ""

    echo "[14] Service Journal Errors (Since Last Hour)"
    echo "──────────────────────────────────────"
    sudo journalctl -u field-trainer-server --since "1 hour ago" --no-pager | grep -B 2 -A 5 "5001\|coach"
    echo ""

    echo "════════════════════════════════════════════════════════════"
    echo "Diagnostic Complete"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Log saved to: $LOG_FILE"

} 2>&1 | tee "$LOG_FILE"

echo ""
echo "Diagnostic complete. Please attach USB drive to dev system."
