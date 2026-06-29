#!/bin/bash

LOG_DIR="$(pwd)/logs"

if [ ! -d "$LOG_DIR" ]; then
    echo "No running services found (logs directory missing)."
    exit 0
fi

echo "==========================================="
echo " Stopping Services "
echo "==========================================="

FOUND=false
for PID_FILE in "$LOG_DIR"/*.pid; do
    if [ -f "$PID_FILE" ]; then
        FOUND=true
        SERVICE=$(basename "$PID_FILE" .pid)
        PID=$(cat "$PID_FILE")
        
        if ps -p $PID > /dev/null; then
            echo "-> Stopping $SERVICE (PID: $PID)..."
            kill $PID
        else
            echo "-> $SERVICE is not running (stale PID: $PID)."
        fi
        
        rm "$PID_FILE"
    fi
done

if [ "$FOUND" = false ]; then
    echo "No PID files found. Services might not be running."
fi

echo "==========================================="
echo "Stop process complete."
echo "==========================================="
