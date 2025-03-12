# Network Service Discovery Reporter

A tool that combines mDNS/Bonjour service discovery with ARP information to create a comprehensive HTML report of network services and devices. The report includes service names, hostnames, IP addresses, MAC addresses, and additional service information.

## Features

- Discovers mDNS/Bonjour services on your network
- Includes ARP table information (IP and MAC addresses)
- Generates a clean, well-formatted HTML report
- Color-coded entries (green for mDNS services, blue for ARP-only entries)
- Case-insensitive sorting by hostname
- Automatic report generation via systemd timer
- Converts escaped characters in service names to readable text

## Prerequisites

- Linux system with systemd
- `avahi-utils` package installed
- Write permissions for the output directory

## Installation

1. Install required packages:
   ```bash
   # For Debian/Ubuntu
   sudo apt-get install avahi-utils

   # For RHEL/CentOS
   sudo yum install avahi-tools
   ```

2. Copy the script and service files:
   ```bash
   sudo cp network-report.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/network-report.sh
   sudo cp network-report.service /etc/systemd/system/
   sudo cp network-report.timer /etc/systemd/system/
   ```

3. Create output directory (if using default service configuration):
   ```bash
   sudo mkdir -p /var/www/html/mdns
   sudo chown nobody:nogroup /var/www/html/mdns
   ```

4. Enable and start the timer for automatic updates:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable network-report.timer
   sudo systemctl start network-report.timer
   ```

## Manual Usage

You can run the script manually with or without specifying an output file:

```bash
# Use default output (./network-report.html in current directory)
./network-report.sh

# Specify custom output file
./network-report.sh /path/to/output.html

# Show help
./network-report.sh --help
```

## Service Configuration

The systemd service is configured to:
- Run every 15 minutes
- Start 5 minutes after boot
- Run as the `nobody` user for security
- Save reports to `/var/www/html/mdns/mdns_services.html` by default

To modify the schedule, edit `/etc/systemd/system/network-report.timer` and run:
```bash
sudo systemctl daemon-reload
sudo systemctl restart network-report.timer
```

## Troubleshooting

1. Check if avahi-daemon is running:
   ```bash
   systemctl status avahi-daemon
   ```

2. Verify timer status:
   ```bash
   systemctl status network-report.timer
   ```

3. View recent service logs:
   ```bash
   journalctl -u network-report.service -n 50
   ```

4. Common issues:
   - Empty report: No mDNS services found or avahi-daemon not running
   - Permission denied: Check output directory permissions
   - Service not found: Ensure avahi-utils is installed

## Output Format

The HTML report includes:
- Service type and interface
- Protocol information
- Service name and type
- Domain and hostname
- IP and MAC addresses
- Port numbers
- TXT records (if available)

## License

This project is open source and available under the MIT License. 