#!/bin/bash
# Verify Fix Status - Check if coach interface fix worked
# Date: 2026-01-04

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/mnt/usb/ft_usb_build/fix_verification_${TIMESTAMP}.log"

{
    echo "════════════════════════════════════════════════════════════"
    echo "Coach Interface Fix Verification"
    echo "Timestamp: $(date)"
    echo "Hostname: $(hostname)"
    echo "════════════════════════════════════════════════════════════"
    echo ""

    echo "[1] Check coach_interface.py file"
    echo "──────────────────────────────────────"
    if [ -f /opt/coach_interface.py ]; then
        echo "File info:"
        ls -lh /opt/coach_interface.py
        stat /opt/coach_interface.py | grep "Modify:"
        echo ""
        echo "File size: $(wc -l /opt/coach_interface.py | awk '{print $1}') lines"
        echo ""
        echo "Expected: ~862 lines (31KB) for working version"
        echo "Previous:  2049 lines (77KB) for broken version"
        echo ""
    else
        echo "✗ coach_interface.py NOT FOUND"
        echo ""
    fi

    echo "[2] Check for backup of broken file"
    echo "──────────────────────────────────────"
    ls -lh /opt/coach_interface.py.broken_* 2>/dev/null || echo "No backup found"
    echo ""

    echo "[3] Test import"
    echo "──────────────────────────────────────"
    cd /opt
    python3 -c "import sys; sys.path.insert(0, '/opt'); import coach_interface; print('✓ Import successful')" 2>&1
    IMPORT_STATUS=$?
    echo ""

    echo "[4] Process status"
    echo "──────────────────────────────────────"
    PID=$(pgrep -f "field_trainer_main.py" | head -1)
    if [ -n "$PID" ]; then
        echo "✓ Process running (PID: $PID)"
        echo "Started:"
        ps -p $PID -o lstart --no-headers
        echo "Runtime:"
        ps -p $PID -o etime --no-headers
        echo ""
    else
        echo "✗ Process NOT running"
        echo ""
    fi

    echo "[5] Listening ports"
    echo "──────────────────────────────────────"
    sudo netstat -tulpn | grep ":500"
    NETSTAT_5001=$(sudo netstat -tulpn | grep ":5001")
    echo ""

    echo "[6] Test HTTP connectivity"
    echo "──────────────────────────────────────"
    echo -n "Port 5000 (Admin): "
    HTTP_5000=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000 2>/dev/null)
    echo "HTTP $HTTP_5000"

    echo -n "Port 5001 (Coach): "
    HTTP_5001=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001 2>/dev/null)
    echo "HTTP $HTTP_5001"
    echo ""

    echo "[7] Startup logs"
    echo "──────────────────────────────────────"
    if [ -f /tmp/field_trainer.log ]; then
        echo "Last 30 lines of startup log:"
        tail -30 /tmp/field_trainer.log
    else
        echo "No /tmp/field_trainer.log found"
    fi
    echo ""

    echo "[8] Check for errors mentioning coach or 5001"
    echo "──────────────────────────────────────"
    if [ -f /tmp/field_trainer.log ]; then
        grep -i "coach\|5001\|error\|exception" /tmp/field_trainer.log | tail -20
    fi
    echo ""

    echo "════════════════════════════════════════════════════════════"
    echo "SUMMARY"
    echo "════════════════════════════════════════════════════════════"
    echo ""

    # Determine status
    if [ "$IMPORT_STATUS" -eq 0 ]; then
        echo "✓ Import: SUCCESS"
    else
        echo "✗ Import: FAILED"
    fi

    if [ -n "$NETSTAT_5001" ]; then
        echo "✓ Port 5001: LISTENING"
    else
        echo "✗ Port 5001: NOT LISTENING"
    fi

    if [ "$HTTP_5001" = "200" ] || [ "$HTTP_5001" = "302" ]; then
        echo "✓ HTTP Test: SUCCESS (HTTP $HTTP_5001)"
    else
        echo "✗ HTTP Test: FAILED (HTTP $HTTP_5001)"
    fi

    echo ""

    if [ "$IMPORT_STATUS" -eq 0 ] && [ -n "$NETSTAT_5001" ] && ([ "$HTTP_5001" = "200" ] || [ "$HTTP_5001" = "302" ]); then
        echo "════════════════════════════════════════════════════════════"
        echo "✓✓✓ FIX SUCCESSFUL! ✓✓✓"
        echo "════════════════════════════════════════════════════════════"
        echo ""
        echo "Coach interface is now working!"
        echo ""
        echo "Access from browser:"
        IP=$(hostname -I | awk '{print $2}')
        echo "  http://$IP:5001"
        echo ""
    else
        echo "════════════════════════════════════════════════════════════"
        echo "✗ FIX DID NOT WORK"
        echo "════════════════════════════════════════════════════════════"
        echo ""
        echo "Issues detected:"
        if [ "$IMPORT_STATUS" -ne 0 ]; then
            echo "  - coach_interface.py still has import errors"
        fi
        if [ -z "$NETSTAT_5001" ]; then
            echo "  - Port 5001 not listening"
        fi
        if [ "$HTTP_5001" != "200" ] && [ "$HTTP_5001" != "302" ]; then
            echo "  - HTTP test failed"
        fi
        echo ""
    fi

    echo "════════════════════════════════════════════════════════════"

} 2>&1 | tee "$LOG_FILE"

echo ""
echo "Verification saved to: $LOG_FILE"
echo "Please attach USB drive to dev system for review."
