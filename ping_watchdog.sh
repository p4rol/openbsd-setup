#!/usr/local/bin/bash
#
# This scipt will use the ping commmand to determine that there is an external 
# internet connection. If there is no internet connection established, it will 
# reboot the host 
#
# Why reboot the host ? 
# - Sure, you don't need to reboot a host to restablish a PPP session etc
# - But sometimes network drivers are not reliable, and simply unloading and 
# reloading the driver doesn't work 
# - So yes, this method is a little aggressive, but it works
#
# You can call this script like this:
# bash ping_reboot.sh -c 10
#
# You can run it from cron every minute like this:
#
# */10 * * * * /root/dev/ping_watchdog.sh -c 3 -i 3 -t 5
#
# This script was written to run on OpenBSD, last tested on 7.5
# Warnig messages and the shutdown message will appear in /var/log/messages as per the logger defaults (on OpenBSD at least...)

# Define defaults
PING_COUNT=5
PING_INTERVAL=10  # In seconds
TIMEOUT_MINUTES=5

# Define the IP addresses of the DNS servers to ping
GOOGLE_DNS="8.8.8.8"
CLOUDFLARE_DNS="1.1.1.1"


# Process arguments (switches)
while getopts ":c:i:t:h?" opt; do
  case $opt in
    c) PING_COUNT="$OPTARG" ;;
    i) PING_INTERVAL="$OPTARG" ;;
    t) TIMEOUT_MINUTES="$OPTARG" ;;
    h|\?) echo "Usage: $0 [-c ping_count] [-i ping_interval] [-t timeout_minutes]"
          echo "       -c  Number of pings per attempt (default: $PING_COUNT)"
          echo "       -i  Interval between pings in seconds (default: $PING_INTERVAL)"
          echo "       -t  Timeout in minutes before reboot (default: $TIMEOUT_MINUTES)"
          echo "       -h   Print this help message"
          echo "       -?   Print this help message"
          exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
  esac
done

shift $((OPTIND-1))  # Remove processed options from arguments

# Validate numeric input for ping_count, ping_interval, and timeout_minutes
if [[ ! "$PING_COUNT" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid ping count. Please provide a number."
  exit 1
fi

if [[ ! "$PING_INTERVAL" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid ping interval. Please provide a number in seconds."
  exit 1
fi

if [[ ! "$TIMEOUT_MINUTES" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid timeout. Please provide a number in minutes."
  exit 1
fi


# Function to perform ping test
function ping_test() {
  local server="$1"
  local count=0
  local ping_count=${PING_COUNT:-5}  # Use default if no switch provided

  while [[ $count -lt $ping_count ]]; do
    if ping -c 1  "$server" &> /dev/null; then
      # Successful ping, exit loop
      return 0
    fi
    let count=count+1
    sleep $PING_INTERVAL
  done
  
  # No successful pings, return failure
  return 1
}

# Main logic
# Check Google DNS
if ping_test "$GOOGLE_DNS"; then
  echo "$(date): Ping to Google DNS successful."
else
  # Check Cloudflare DNS (if Google fails)
  if ping_test "$CLOUDFLARE_DNS"; then
    echo "$(date): Ping to Google DNS failed, but Cloudflare DNS successful."
  else
    echo "$(date): Ping to both Google and Cloudflare DNS failed. Rebooting in $TIMEOUT_MINUTES minutes..."
    logger "Ping to both Google and Cloudflare DNS failed. Rebooting in $TIMEOUT_MINUTES minutes..."
    sleep $((TIMEOUT_MINUTES * 60))  # Convert minutes to seconds
    reboot
  fi
fi

# Exit script after execution
exit 0


# EOF
