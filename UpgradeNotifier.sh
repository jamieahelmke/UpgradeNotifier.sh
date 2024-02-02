#!/bin/sh
# UpgradeNotifier.sh - Server Package Upgrade Notification Script
#
# Notifies about available package upgrades and sends a detailed email report.
#
# Usage:
#   ./UpgradeNotifier.sh FROM TO [-h] [-v] [-t]
# Arguments:
#   FROM        Email sender
#   TO          Email recipient
# Options:
#   -h          Show help message
#   -v          Show version
#   -t          Test email sending

version="1.0"

# Get some simple OS Information
. /etc/os-release

# Functions for colored output
echo_green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
echo_red() { printf "\033[0;31m%s\033[0m\n" "$1"; }

# Help message
show_help() {
    echo "Usage: $0 FROM TO [OPTIONS]"
    echo "Arguments:"
    echo "  FROM      Email sender"
    echo "  TO        Email recipient"
    echo "Options:"
    echo "  -h        Show this help message"
    echo "  -v        Show version"
    echo "  -t        Test email sending"
}

# Check for mandatory arguments
if [ $# -lt 2 ]; then
    echo_red "Error: FROM and TO email addresses are required."
    show_help
    exit 1
fi

FROM="$1"
TO="$2"
shift 2

TEST_MODE="false"

# Parse command-line options
while getopts "hvt" opt; do
    case ${opt} in
        h) show_help; exit 0 ;;
        v) echo "Version $version"; exit 0 ;;
        t) TEST_MODE="true" ;;
        *) echo_red "Invalid option: $OPTARG"; show_help; exit 1 ;;
    esac
done

fetch_and_check_upgrades() {
    echo_green "Fetching package index..."
    apt update > /dev/null 2>&1 && echo_green "Done."
    echo_green "Package Statistics:"
    package_number=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    echo "Total upgradable packages: $package_number"

    if [ "$package_number" -gt 0 ]; then
        apt list --upgradable 2>/dev/null | grep -oP '\/\K[^ ]+' | sort | uniq -c | while read -r count repo; do
            echo "$count packages in \"$repo\""
        done
    else
        echo_green "No upgrades found, exiting."
        exit 0
    fi
}

build_and_send_email() {
    hostname=$(hostname -f)
    user=$(whoami)
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    package_number=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    # Prepare package counts per repository for email
    package_counts=$(apt list --upgradable 2>/dev/null | grep -oP '\/\K[^ ]+' | sort | uniq -c | while read -r count repo; do echo "$count packages in \"$repo\"<br>"; done)
    Subject="Upgrades are available for $package_number Packages on $hostname"
    Body="
<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"UTF-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
<title>Server Upgrade Notification</title>
<style>
  body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    margin: 0;
    padding: 20px;
    background-color: #F4F4F4;
    color: #333;
  }
  .container {
    max-width: 600px;
    margin: auto;
    background: #fff;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  }
  h2 {
    color: #007BFF;
    margin-bottom: 20px;
  }
  p {
    line-height: 1.5;
  }
  .highlight {
    color: #FF5722;
    font-weight: bold;
  }
  .footer {
    margin-top: 20px;
    padding-top: 20px;
    border-top: 1px solid #EEE;
    font-size: 0.8em;
    text-align: center;
    color: #777;
  }
</style>
</head>
<body>
<div class=\"container\">
<h2>Upgrade Notification for ${hostname}</h2>
<p>Dear Administrator,</p>
<p>This is an automated notification. There are <span class=\"highlight\">${package_number}</span> package(s) available for upgrade on your server <span class=\"highlight\">${hostname}</span>.</p>
<p>The following packages are upgradable:</p>
<p><span class=\"highlight\">${package_counts}</span></p>
<p>It is recommended to review and apply these upgrades to ensure the security and performance of your systems.</p>
<p>Best Regards,</p>
<p>Your Automated Notification System $user@$hostname</p>
<div class=\"footer\">
<code>Sent on ${timestamp} from a ${PRETTY_NAME} system.</code>
</div>
</div>
</body>
</html>
"

    echo_green "Sending Email..."
    printf "From: $FROM\nTo: $TO\nSubject: $Subject\nContent-Type: text/html; charset=UTF-8\n\n$Body" | sendmail -t && echo_green "Done."
}

# Main logic
if [ "$TEST_MODE" = "true" ]; then
    build_and_send_email
else
    fetch_and_check_upgrades && build_and_send_email
fi
