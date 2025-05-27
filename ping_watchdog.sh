#!/bin/ksh
#
# This script will use the ping commmand to determine that there is an external
# internet connection. If there is no internet connection established, it will
# attempt to recover the connection or, if specified, reboot the host.
#
# Why reboot the host ?
# - Sure, you don't need to reboot a host to restablish a PPP session etc
# - But sometimes network drivers are not reliable, and simply unloading and
# reloading the driver doesn't work
# - So yes, this method is a little aggressive, but it works
#
# You can call this script like this:
# ksh ping_watchdog.sh -c 10
# With reboot enabled:
# ksh ping_watchdog.sh -c 10 -r
#
# You can run it from cron every minute like this:
#
# */10 * * * * /root/dev/ping_watchdog.sh -c 3 -i 3 -t 5
# Or with reboot enabled:
# */10 * * * * /root/dev/ping_watchdog.sh -c 3 -i 3 -t 5 -r
* or every 30 minnutes with:
* */30 * * * * /root/ping_watchdog.sh
#
# This script was written to run on OpenBSD, last tested on 7.5
# Warning messages and the shutdown message will appear in /var/log/messages as per the logger defaults (on OpenBSD at least...)

# Define defaults
PING_COUNT=5
PING_INTERVAL=10  # In seconds
TIMEOUT_MINUTES=5
REBOOT_ENABLED=false # Default: do not reboot, try to recover network

# Define the array of IP addresses of the DNS servers to ping
# Use ksh/pdksh compatible array assignment
set -A DNS_SERVERS "8.8.8.8" "8.8.4.4" "1.1.1.1" "9.9.9.9" "1.0.0.1"

# Process arguments (switches)
while getopts ":c:i:t:rh?" opt; do
  case $opt in
    c) PING_COUNT="$OPTARG" ;;
    i) PING_INTERVAL="$OPTARG" ;;
    t) TIMEOUT_MINUTES="$OPTARG" ;;
    r) REBOOT_ENABLED=true ;;
    h|\?) echo "Usage: $0 [-c ping_count] [-i ping_interval] [-t timeout_minutes] [-r]"
          echo "       -c  Number of pings per attempt (default: $PING_COUNT)"
          echo "       -i  Interval between pings in seconds (default: $PING_INTERVAL)"
          echo "       -t  Timeout in minutes before reboot (default: $TIMEOUT_MINUTES)"
          echo "       -r  Enable reboot if internet connection fails (default: try to restart pppoe0)"
          echo "       -h  Print this help message"
          echo "       -?  Print this help message"
          exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
  esac
done

shift $((OPTIND-1))  # Remove processed options from arguments

# Validate numeric input for ping_count
case "$PING_COUNT" in
    (*[!0-9]*|'')
        echo "Error: Invalid ping count. Please provide a number." >&2
        exit 1
        ;;
esac

# Validate numeric input for ping_interval
case "$PING_INTERVAL" in
    (*[!0-9]*|'')
        echo "Error: Invalid ping interval. Please provide a number in seconds." >&2
        exit 1
        ;;
esac

# Validate numeric input for timeout_minutes
case "$TIMEOUT_MINUTES" in
    (*[!0-9]*|'')
        echo "Error: Invalid timeout. Please provide a number in minutes." >&2
        exit 1
        ;;
esac


# Function to perform ping test
# Tries to ping the specified server PING_COUNT times, with PING_INTERVAL seconds between attempts.
# Returns 0 on first successful ping, 1 if all attempts fail.
ping_test() {
  typeset server="$1" # Use typeset for local variables in ksh
  typeset count=0     # Use typeset for local variables in ksh

  while [ $count -lt $PING_COUNT ]; do
    # OpenBSD ping: -c count
    # -t timeout (total timeout for the ping command in seconds)
    if ping -c 1 "$server" > /dev/null 2>&1; then
      # Successful ping
      return 0
    fi
    count=$((count + 1))
    # Sleep between attempts
    sleep "$PING_INTERVAL"
  done

  # No successful pings after PING_COUNT attempts
  return 1
}

# Main logic
internet_up=false
successful_server=""

# Iterate over ksh array
for server_ip in "${DNS_SERVERS[@]}"; do
  echo "$(date): Attempting to ping $server_ip (Attempt $PING_COUNT times, Interval $PING_INTERVAL s)..."
  if ping_test "$server_ip"; then
    successful_server="$server_ip"
    internet_up=true
    break # Exit loop on first success
  else
    echo "$(date): Ping to $server_ip failed after $PING_COUNT attempts."
  fi
done

if [ "$internet_up" = true ]; then
  echo "$(date): Internet connection confirmed via $successful_server."
  # Optional: logger "Watchdog: Internet connection confirmed via $successful_server."
else
  echo "$(date): Ping to all configured DNS servers failed."
  logger "Watchdog: Ping to all configured DNS servers failed. Taking action."

  if [ "$REBOOT_ENABLED" = true ]; then
    echo "$(date): Reboot enabled. Rebooting in $TIMEOUT_MINUTES minutes..."
    logger "Watchdog: Internet connection lost. Rebooting host in $TIMEOUT_MINUTES minutes as per -r flag."
    sleep $((TIMEOUT_MINUTES * 60))  # Convert minutes to seconds
    /sbin/reboot # Use full path for reboot
  else
    echo "$(date): Reboot not enabled. Attempting to restart pppoe0 interface..."
    logger "Watchdog: Internet connection lost. Attempting to restart pppoe0 via /etc/netstart."
    # On OpenBSD, netstart is typically /etc/netstart.
    if /bin/sh /etc/netstart pppoe0; then
      logger "Watchdog: Command '/etc/netstart pppoe0' executed successfully."
      echo "$(date): '/etc/netstart pppoe0' executed. Check connection manually if issues persist."
    else
      logger "Watchdog: Command '/etc/netstart pppoe0' failed. Exit code: $?."
      echo "$(date): Command '/etc/netstart pppoe0' failed. Manual intervention may be required."
    fi
  fi
fi

# Exit script after execution
exit 0

# EOF
