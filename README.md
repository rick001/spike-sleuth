# Spike Sleuth

A real-time disk I/O monitoring tool that detects and logs high disk read activity spikes on Linux systems.

## Overview

Spike Sleuth continuously monitors disk I/O activity and automatically logs detailed information when it detects unusually high read rates (default threshold: 5GB/s). This tool is particularly useful for:

- Identifying processes causing disk I/O bottlenecks
- Troubleshooting performance issues
- Monitoring disk-intensive applications
- Debugging system slowdowns

## Prerequisites

- Linux operating system
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

## Usage

Run the script with root privileges:

```bash
sudo ./spike-sleuth.sh
```

The script will run continuously in the background, monitoring disk I/O activity. When a spike is detected, it will automatically log information to `/var/log/disk_io_spike.log`.

### Configuration

You can modify the following parameters in the script:

- `READ_THRESHOLD`: Disk read threshold in MB/s (default: 5000 MB/s = 5GB/s)
- `LOG_FILE`: Path to the log file (default: `/var/log/disk_io_spike.log`)
- `INTERVAL`: Monitoring interval in seconds (default: 5 seconds)

## Sample Output

When a disk I/O spike is detected, the log file will contain entries similar to this:

```
[2024-03-20 14:30:45] 🚨 Disk I/O Spike Detected (PID: 1234, > 5000 MB/s) 🚨
----------------------------------------
🔹 Process details (iotop):
1234  user1  123.4G/s  /usr/bin/some-process
🔹 Open files for PID 1234 (lsof):
n1234 /path/to/file1
n1234 /path/to/file2
==========================================
```

## Log File Information

The log file contains:
- Timestamp of the spike
- Process ID (PID) causing the spike
- I/O rate during the spike
- Process details from iotop
- List of open files for the process
- Additional system information

## Troubleshooting

If you encounter issues:

1. Ensure all required packages are installed
2. Verify you have root privileges
3. Check if the log directory exists and is writable
4. Monitor system resources to ensure the script isn't causing performance impact

## License

This project is licensed under the [MIT License](LICENSE).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 