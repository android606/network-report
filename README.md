# Network Device and Service Report

A tool that combines mDNS/Bonjour service discovery with ARP information to create a basic HTML report of network services and devices. The report includes service names, hostnames, IP addresses, MAC addresses, and additional service information.

I originally wrote this because sometimes, just sometimes, I would be connected remotely via VPN or something, and the service I'm trying to use just isn't working. I run this report periodically and place it on a webserver that's only accessible from inside the LAN. That way, if all else fails, I always have one more place I can look up a hostname, IP address, or service name of something in my LAN.

I absolutely do not recommend running this on a machine that's directly accessible via the internet. It's not information you want everyone everywhere to look at.


## Features

- Discovers mDNS/Bonjour services on your network
- Includes ARP table information (IP and MAC addresses)
- Pops it all into a table in an HTML report, sorted by hostname
- Automatic report generation via systemd timer
- Converts backslash-escaped characters in service names to readable text

## Prerequisites

- Linux system with systemd
- `net-tools` package installed (this comes with most linux distros)
- `avahi-utils` package installed
- Write permissions for the output directory

## Installation

1. Install required packages:
   ```bash
   # For Debian/Ubuntu
   sudo apt-get install avahi-utils
   sudo apt-get install net-tools
   ```

2. Copy the script and service files:
   ```bash
   sudo cp network-report.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/network-report.sh
   sudo cp network-report.service /etc/systemd/system/
   sudo cp network-report.timer /etc/systemd/system/
   ```

3. Create output directory:
   ```bash
   sudo mkdir -p /var/www/html/reports
   sudo chown nobody:nogroup /var/www/html/reports
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
# Use default output (network-report.html in current directory)
network-report.sh

# Specify custom output file
network-report.sh /path/to/output.html

# Show help
network-report.sh --help
```

## Service Configuration

The systemd service is configured to:
- Run every 15 minutes
- Start 5 minutes after boot
- Run as the `nobody` user
- Save reports to `/var/www/html/reports/network-report.html`

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
