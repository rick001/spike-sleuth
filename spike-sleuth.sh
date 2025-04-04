#!/bin/bash

# Default configuration
READ_THRESHOLD=${READ_THRESHOLD:-5000}  # 5GB/sec
LOG_FILE=${LOG_FILE:-"/var/log/disk_io_spike.log"}
INTERVAL=${INTERVAL:-5}
DEBUG=${DEBUG:-false}
MIN_PROCESS_THRESHOLD=${MIN_PROCESS_THRESHOLD:-500}  # MB/s
MAX_LOG_SIZE=${MAX_LOG_SIZE:-10485760}  # 10MB
LOG_RETENTION=${LOG_RETENTION:-7}  # days

# Service configuration
SERVICE_NAME="spike-sleuth"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
INSTALL_DIR="/usr/local/bin"

SPIKE_ACTIVE=false
declare -A LOGGED_PIDS  # Tracks already logged PIDs during spike
LAST_CLEANUP=$(date +%s)

# Debug function
debug() {
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG] $1"
    fi
}

# Signal handler for graceful shutdown
cleanup() {
    echo "Shutting down spike-sleuth..."
    exit 0
}

# Rotate log file if it exceeds MAX_LOG_SIZE
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c %s "$LOG_FILE") -gt "$MAX_LOG_SIZE" ]; then
        mv "$LOG_FILE" "${LOG_FILE}.$(date +%Y%m%d%H%M%S)"
        touch "$LOG_FILE"
    fi
}

# Clean up old log files
cleanup_old_logs() {
    find "$(dirname "$LOG_FILE")" -name "disk_io_spike.log.*" -mtime +$LOG_RETENTION -delete
}

# Clean up old PIDs from tracking
cleanup_old_pids() {
    local current_time=$(date +%s)
    if [ $((current_time - LAST_CLEANUP)) -gt 3600 ]; then  # Cleanup every hour
        for pid in "${!LOGGED_PIDS[@]}"; do
            if ! ps -p "$pid" > /dev/null 2>&1; then
                unset LOGGED_PIDS["$pid"]
            fi
        done
        LAST_CLEANUP=$current_time
    fi
}

log_io_info() {
    local pid=$1
    local read_rate=$2
    
    # Rotate log if needed
    rotate_log
    
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] 🚨 Disk I/O Spike Detected (PID: $pid, Rate: $read_rate MB/s) 🚨" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"

    echo "🔹 Process details (iotop):" >> "$LOG_FILE"
    iotop -boanP -d 2 -n 2 | grep -w "^$pid" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    echo "🔹 Open files for PID $pid (lsof):" >> "$LOG_FILE"
    lsof -p "$pid" +D / -Fn | grep -vE "(mem|DEL|txt|cwd|rtd)" | head -20 >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# Installation functions
install_service() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: Installation must be run as root"
        exit 1
    fi

    echo "Installing spike-sleuth service..."
    
    # Create service file
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Spike Sleuth Disk I/O Monitoring Service
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$SERVICE_NAME
Restart=always
RestartSec=5
Environment="READ_THRESHOLD=$READ_THRESHOLD"
Environment="LOG_FILE=$LOG_FILE"
Environment="INTERVAL=$INTERVAL"
Environment="MIN_PROCESS_THRESHOLD=$MIN_PROCESS_THRESHOLD"
Environment="MAX_LOG_SIZE=$MAX_LOG_SIZE"
Environment="LOG_RETENTION=$LOG_RETENTION"

[Install]
WantedBy=multi-user.target
EOF

    # Copy script to installation directory
    cp "$0" "$INSTALL_DIR/$SERVICE_NAME"
    chmod +x "$INSTALL_DIR/$SERVICE_NAME"
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    echo "Installation complete. To start the service, run:"
    echo "  sudo systemctl start $SERVICE_NAME"
}

uninstall_service() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: Uninstallation must be run as root"
        exit 1
    fi

    echo "Uninstalling spike-sleuth service..."
    
    # Stop and disable service
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    systemctl disable "$SERVICE_NAME" 2>/dev/null
    
    # Remove files
    rm -f "$SERVICE_FILE"
    rm -f "$INSTALL_DIR/$SERVICE_NAME"
    
    # Reload systemd
    systemctl daemon-reload
    
    echo "Uninstallation complete."
}

# Check if required commands are available
check_dependencies() {
    for cmd in iostat iotop lsof systemctl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: Required command '$cmd' is not installed."
            exit 1
        fi
    done
}

# Main monitoring function
monitor() {
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root"
        exit 1
    fi

    check_dependencies

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    # Set up signal handlers
    trap cleanup SIGINT SIGTERM

    # Initial cleanup of old logs
    cleanup_old_logs

    # Log initial setup confirmation
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] ✅ Spike Sleuth setup complete. Monitoring started." >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    echo "Configuration:" >> "$LOG_FILE"
    echo "- Read threshold: $READ_THRESHOLD MB/s" >> "$LOG_FILE"
    echo "- Log file: $LOG_FILE" >> "$LOG_FILE"
    echo "- Check interval: $INTERVAL seconds" >> "$LOG_FILE"
    echo "- Minimum process threshold: $MIN_PROCESS_THRESHOLD MB/s" >> "$LOG_FILE"
    echo "- Max log size: $((MAX_LOG_SIZE/1024/1024))MB" >> "$LOG_FILE"
    echo "- Log retention: $LOG_RETENTION days" >> "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    while true; do
        # Get disk read rate in MB/s
        READ_MB=$(iostat -dmx 1 2 | awk 'END{print $6}')
        debug "Raw iostat output: $READ_MB"
        
        # Check if we got a valid number
        if [[ "$READ_MB" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            READ_INT=${READ_MB%.*}
            debug "Parsed read rate: $READ_INT MB/s"
            
            if [ "$READ_INT" -ge "$READ_THRESHOLD" ]; then
                SPIKE_ACTIVE=true
                debug "Spike detected: $READ_INT MB/s"
                
                # Get top high-read process IDs
                TOP_PIDS=$(iotop -boanP -d 1 -n 1 | awk -v threshold="$MIN_PROCESS_THRESHOLD" '
                    NR>7 && $4 ~ /[MG]\/s/ { 
                        split($4,a," "); 
                        if(a[2]=="G/s" || (a[2]=="M/s" && a[1]>=threshold)) print $1 
                    }')
                debug "Top PIDs: $TOP_PIDS"

                for pid in $TOP_PIDS; do
                    if [ -z "${LOGGED_PIDS[$pid]}" ]; then
                        log_io_info "$pid" "$READ_INT"
                        LOGGED_PIDS[$pid]=1
                    fi
                done
            else
                # Reset state and PID tracking when spike ends
                if [ "$SPIKE_ACTIVE" = true ]; then
                    SPIKE_ACTIVE=false
                    unset LOGGED_PIDS
                    declare -A LOGGED_PIDS
                    debug "Spike ended"
                fi
            fi
            
            # Clean up old PIDs periodically
            cleanup_old_pids
        else
            debug "Invalid read rate value: $READ_MB"
        fi

        sleep "$INTERVAL"
    done
}

# Main script logic
case "$1" in
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    start)
        systemctl start "$SERVICE_NAME"
        ;;
    stop)
        systemctl stop "$SERVICE_NAME"
        ;;
    status)
        systemctl status "$SERVICE_NAME"
        ;;
    *)
        monitor
        ;;
esac
