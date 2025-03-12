#!/bin/bash

# Display usage information if -h or --help is provided
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: $0 [output_file]"
    echo "Scans for mDNS services and generates an HTML report"
    echo ""
    echo "Arguments:"
    echo "  output_file    Optional: Path to save the HTML report (default: ./network-report.html)"
    exit 0
fi

# Set output file from argument or use default
output_file="${1:-./network-report.html}"

# Create output directory if it doesn't exist
output_dir=$(dirname "$output_file")
if [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir" || {
        echo "Error: Failed to create output directory: $output_dir"
        exit 1
    }
fi

# Check if output directory is writable
if [ ! -w "$output_dir" ]; then
    echo "Error: Output directory is not writable: $output_dir"
    exit 1
fi

# Check if avahi-browse is installed
if ! command -v avahi-browse &> /dev/null; then
    echo "Error: avahi-browse is not installed. Please install avahi-utils package."
    echo "On Debian/Ubuntu: sudo apt-get install avahi-utils"
    echo "On RHEL/CentOS: sudo yum install avahi-tools"
    exit 1
fi

# Function to convert backslash-escaped octal codes to readable characters
unescape_chars() {
    local str="$1"
    # Convert common octal codes
    str="${str//\\032/ }"    # space
    str="${str//\\040/@}"    # @
    str="${str//\\041/!}"    # !
    str="${str//\\045/%}"    # %
    str="${str//\\046/&}"    # &
    str="${str//\\050/(}"    # (
    str="${str//\\051/)}"    # )
    str="${str//\\054/,}"    # ,
    str="${str//\\056/.}"    # .
    str="${str//\\057//}"    # /
    str="${str//\\072/:}"    # :
    str="${str//\\073/;}"    # ;
    str="${str//\\137/_}"    # _
    echo "$str"
}

# Create a timestamp for the title
timestamp=$(date +"%Y%m%d_%H%M%S")

# Start capturing the avahi-browse output
echo "Scanning mDNS services..."
if ! avahi_output=$(avahi-browse -atvrp 2>&1); then
    echo "Error: Failed to execute avahi-browse command."
    echo "Error message: $avahi_output"
    echo "Please check if avahi-daemon is running: systemctl status avahi-daemon"
    exit 1
fi

# Get ARP information
echo "Getting ARP information..."
arp_output=$(arp -a)

# Create arrays to store IP and MAC mappings
declare -A mac_addresses
declare -A ip_seen
declare -A arp_hostnames

# Parse ARP output
while read -r line; do
    if [[ $line =~ ([^[:space:]]+)[[:space:]]+\(([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\)[[:space:]]+at[[:space:]]+([0-9a-fA-F:]+)[[:space:]] ]]; then
        hostname="${BASH_REMATCH[1]}"
        ip="${BASH_REMATCH[2]}"
        mac="${BASH_REMATCH[3]}"
        mac_addresses["$ip"]="$mac"
        arp_hostnames["$ip"]="$hostname"
    fi
done <<< "$arp_output"

# Check if output is empty
if [ -z "$avahi_output" ] && [ -z "$arp_output" ]; then
    echo "Warning: No mDNS or ARP entries found. Creating empty report..."
fi

# Create HTML file with header
cat > "$output_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Network Services - ${timestamp}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 95%;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        .timestamp {
            color: #666;
            font-style: italic;
            margin-bottom: 20px;
        }
        .error-message {
            color: #721c24;
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            padding: 10px;
            border-radius: 4px;
            margin-bottom: 20px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            font-size: 14px;
        }
        th, td {
            padding: 8px;
            text-align: left;
            border: 1px solid #ddd;
        }
        th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        tr:hover {
            background-color: #f2f2f2;
        }
        td {
            white-space: pre-wrap;
            word-wrap: break-word;
            max-width: 300px;
        }
        .mac-address {
            color: #666;
            font-family: monospace;
        }
        .source-arp {
            color: #2196F3;
        }
        .source-mdns {
            color: #4CAF50;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Network Services Discovery Report</h1>
        <div class="timestamp">Generated on: $(date)</div>
$(if [ -z "$avahi_output" ] && [ -z "$arp_output" ]; then
    echo '<div class="error-message">No services were found. This could mean either:'
    echo '<ul>'
    echo '<li>There are no mDNS/Bonjour services on your network</li>'
    echo '<li>The avahi-daemon service is not running</li>'
    echo '<li>Your network does not allow mDNS traffic</li>'
    echo '<li>The ARP cache is empty</li>'
    echo '</ul>'
    echo '</div>'
fi)
        <table>
            <thead>
                <tr>
                    <th>Type</th>
                    <th>Interface</th>
                    <th>Protocol</th>
                    <th>Service Name</th>
                    <th>Service Type</th>
                    <th>Domain</th>
                    <th>Hostname</th>
                    <th>Address</th>
                    <th>Port</th>
                    <th>TXT Records</th>
                </tr>
            </thead>
            <tbody>
EOF

# Create a temporary file for sorting
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

# Use ASCII unit separator as field delimiter (this character is very unlikely to appear in the data)
delim=$'\x1f'

# Process mDNS entries
echo "$avahi_output" | while IFS=';' read -r type iface proto name stype domain host addr port txt; do
    # Skip empty lines
    [ -z "$type" ] && continue
    
    # Mark this IP as seen
    if [ -n "$addr" ]; then
        ip_seen["$addr"]=1
    fi
    
    # Add MAC address if available for this IP
    addr_display="$addr"
    if [[ -n "$addr" && "${mac_addresses[$addr]}" ]]; then
        addr_display="$addr<br><span class='mac-address'>${mac_addresses[$addr]}</span>"
    fi
    
    # Escape HTML special characters and convert escaped chars
    name=$(echo "$name" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    name=$(unescape_chars "$name")
    txt=$(echo "$txt" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    
    # Use hostname as sort key, fallback to IP if no hostname
    sort_key="${host:-$addr}"
    echo -n "${sort_key,,}$delim<tr class='source-mdns'>" >> "$temp_file"
    echo -n "<td>$type</td>" >> "$temp_file"
    echo -n "<td>$iface</td>" >> "$temp_file"
    echo -n "<td>$proto</td>" >> "$temp_file"
    echo -n "<td>$name</td>" >> "$temp_file"
    echo -n "<td>$stype</td>" >> "$temp_file"
    echo -n "<td>$domain</td>" >> "$temp_file"
    echo -n "<td>$host</td>" >> "$temp_file"
    echo -n "<td>$addr_display</td>" >> "$temp_file"
    echo -n "<td>$port</td>" >> "$temp_file"
    echo "<td>$txt</td></tr>" >> "$temp_file"
done

# Add ARP entries that weren't in mDNS
for ip in "${!mac_addresses[@]}"; do
    if [ -z "${ip_seen[$ip]}" ]; then
        hostname="${arp_hostnames[$ip]}"
        sort_key="${hostname:-$ip}"
        echo -n "${sort_key,,}$delim<tr class='source-arp'>" >> "$temp_file"
        echo -n "<td>ARP</td>" >> "$temp_file"
        echo -n "<td>-</td>" >> "$temp_file"
        echo -n "<td>IPv4</td>" >> "$temp_file"
        echo -n "<td>$hostname</td>" >> "$temp_file"
        echo -n "<td>-</td>" >> "$temp_file"
        echo -n "<td>-</td>" >> "$temp_file"
        echo -n "<td>$hostname</td>" >> "$temp_file"
        echo -n "<td>$ip<br><span class='mac-address'>${mac_addresses[$ip]}</span></td>" >> "$temp_file"
        echo -n "<td>-</td>" >> "$temp_file"
        echo "<td>-</td></tr>" >> "$temp_file"
    fi
done

# Sort entries by hostname (case-insensitive) and output HTML rows
sort -f -t "$delim" -k1,1 "$temp_file" | cut -d "$delim" -f2- >> "$output_file"

# Close HTML file
cat >> "$output_file" << EOF
            </tbody>
        </table>
    </div>
</body>
</html>
EOF

echo "Report has been generated: $output_file" 