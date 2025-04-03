#!/usr/local/bin/bash

# The path to bash is not /bin/bash because we're running this on OpenBSD


# The purpose of this script is to gather historical data about the stratum level
# that was reached by the NTP server.

# You can run this every minute using cron:
# Gather stratum data, for the NTP server    (just remove the leading # from the crontab entry
#* * * * * /path/to/gather_stratum_data.sh

# Define the output file
OUTPUT_FILE="output.csv"

# Check if the file exists and add headers if it's a new file
if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "Date,Status" > "$OUTPUT_FILE"
fi

# Run ntpctl -s status and process each line, including error handling
ntpctl -s status 2>&1 | while IFS= read -r line; do
  # Get the current date in YYYY-MM-DD HH:MM:SS format
  current_date=$(date +"%Y-%m-%d %H:%M:%S")

  # Escape any commas in the line to avoid CSV issues
  escaped_line=$(echo "$line" | sed 's/,/\\,/g')

  # Check for the connection refused error
  if [[ "$escaped_line" == "ntpctl: connect: /var/run/ntpd.sock: Connection refused" ]]; then
    # Log the error with a specific message
    echo "$current_date,ntpd is not running" >> "$OUTPUT_FILE"
  else
    # Append the date and line to the output file in CSV format
    echo "$current_date,$escaped_line" >> "$OUTPUT_FILE"
  fi
done

echo "Output appended to $OUTPUT_FILE"


# EOF
#
#
