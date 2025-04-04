#!/bin/bash

READ_THRESHOLD=5000  # 5GB/sec
LOG_FILE="/var/log/disk_io_spike.log"
INTERVAL=5

SPIKE_ACTIVE=false
declare -A LOGGED_PIDS  # Tracks already logged PIDs during spike

log_io_info() {
    local pid=$1
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] 🚨 Disk I/O Spike Detected (PID: $pid, > $READ_THRESHOLD MB/s) 🚨" >> "$LOG_FILE"
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

while true; do
    READ_MB=$(iostat -dmx 1 2 | awk 'END{print $6}')
    READ_INT=${READ_MB%.*}

    if [ "$READ_INT" -ge "$READ_THRESHOLD" ]; then
        SPIKE_ACTIVE=true
        # Get top high-read process IDs (filter processes above a smaller threshold, e.g., 500 MB/s)
        TOP_PIDS=$(iotop -boanP -d 1 -n 1 | awk 'NR>7 && $4 ~ /[MG]\/s/ { 
            split($4,a," "); 
            if(a[2]=="G/s" || (a[2]=="M/s" && a[1]>=500)) print $1 
        }')

        for pid in $TOP_PIDS; do
            if [ -z "${LOGGED_PIDS[$pid]}" ]; then
                log_io_info "$pid"
                LOGGED_PIDS[$pid]=1
            fi
        done
    else
        # Reset state and PID tracking when spike ends
        if [ "$SPIKE_ACTIVE" = true ]; then
            SPIKE_ACTIVE=false
            unset LOGGED_PIDS
            declare -A LOGGED_PIDS
        fi
    fi

    sleep "$INTERVAL"
done
