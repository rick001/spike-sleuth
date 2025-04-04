# Spike Sleuth

A real-time disk I/O monitoring tool that detects and logs high disk read activity spikes on Linux systems. Runs as a systemd service for reliable background monitoring.

## Overview

Spike Sleuth continuously monitors disk I/O activity and automatically logs detailed information when it detects unusually high read rates (default threshold: 5GB/s). This tool is particularly useful for:

- Identifying processes causing disk I/O bottlenecks
- Troubleshooting performance issues
- Monitoring disk-intensive applications
- Debugging system slowdowns

## Features

- 🚀 Runs as a systemd service for reliable background operation
- 📊 Configurable monitoring thresholds and intervals
- 📝 Automatic log rotation and retention
- 🔍 Detailed process and file information during spikes
- 🔄 Automatic service recovery
- ⚙️ Easy installation and management

## Prerequisites

- Linux operating system with systemd
- `iostat` (part of sysstat package)
- `iotop` (requires root privileges)
- `lsof` (for file monitoring)
- Bash shell

## Installation

1. Install required packages:

```bash
# For Debian/Ubuntu
sudo apt-get update
sudo apt-get install sysstat iotop lsof

# For RHEL/CentOS
sudo yum install sysstat iotop lsof
```

2. Clone this repository:
```bash
git clone https://github.com/rick001/spike-sleuth.git
cd spike-sleuth
```

3. Make the script executable:
```bash
chmod +x spike-sleuth.sh
```

4. Install the service:
```bash
sudo ./spike-sleuth.sh install
```

The script will be installed to `/usr/local/bin` and configured as a systemd service.

## Configuration

You can customize the service by setting environment variables before installation:

```bash
READ_THRESHOLD=1000 \
INTERVAL=10 \
LOG_FILE="/path/to/log" \
MIN_PROCESS_THRESHOLD=200 \
MAX_LOG_SIZE=5242880 \
LOG_RETENTION=14 \
sudo ./spike-sleuth.sh install
```

### Available Configuration Options

- `READ_THRESHOLD`: Disk read threshold in MB/s (default: 5000 MB/s = 5GB/s)
- `LOG_FILE`: Path to the log file (default: `/var/log/disk_io_spike.log`)
- `INTERVAL`: Monitoring interval in seconds (default: 5 seconds)
- `MIN_PROCESS_THRESHOLD`: Minimum I/O rate to log a process in MB/s (default: 500 MB/s)
- `MAX_LOG_SIZE`: Maximum log file size in bytes (default: 10MB)
- `LOG_RETENTION`: Number of days to keep old log files (default: 7 days)

## Usage

### Service Management

```bash
# Start the service
sudo ./spike-sleuth.sh start

# Stop the service
sudo ./spike-sleuth.sh stop

# Check service status
sudo ./spike-sleuth.sh status

# Uninstall the service
sudo ./spike-sleuth.sh uninstall
```

### Direct Usage (without service)

For testing or temporary monitoring, you can run the script directly:

```bash
sudo ./spike-sleuth.sh
```

## Sample Output

When a disk I/O spike is detected, the log file will contain entries similar to this:

```
[2024-03-20 14:30:45] 🚨 Disk I/O Spike Detected (PID: 1234, Rate: 1234.5 MB/s) 🚨
----------------------------------------
🔹 Process details (iotop):
1234  user1  123.4G/s  /usr/bin/some-process
🔹 Open files for PID 1234 (lsof):
n1234 /path/to/file1
n1234 /path/to/file2
==========================================
```

Note: The emoji icons (🚨, 🔹) will be displayed in the log file but not in the console output.

## Log Management

- Logs are automatically rotated when they exceed the configured size
- Old log files are automatically cleaned up based on the retention period
- Log files are stored with timestamps for historical tracking

## Troubleshooting

If you encounter issues:

1. Check service status:
```bash
sudo ./spike-sleuth.sh status
```

2. View system logs:
```bash
journalctl -u spike-sleuth
```

3. Common issues:
   - Ensure all required packages are installed
   - Verify you have root privileges
   - Check if the log directory exists and is writable
   - Monitor system resources to ensure the service isn't causing performance impact

4. Debug mode:
   - Set `DEBUG=true` before installation to enable detailed logging
   - Run the script directly with `DEBUG=true` for testing

## License

This project is licensed under the [MIT License](LICENSE).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 