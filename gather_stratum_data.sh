#!/usr/local/bin/bash

# The path to bash is not /bin/bash because we're running this on OpenBSD


# The purpose of this script is to gather historical data about the stratum level
# that was reached by the NTP server.

# You can run this every minute using cron:
# Gather stratum data, for the NTP server    (just remove the leading # from the crontab entry
#* * * * * /path/to/gather_stratum_data.sh




# Define the output file
OUTPUT_FILE="/path/to/output.csv"

# Check if the file exists and add headers if it's a new file
if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "Date,Status" > "$OUTPUT_FILE"
fi

# Run ntpctl -s status and process each line
ntpctl -s status | while IFS= read -r line; do
  # Get the current date in YYYY-MM-DD HH:MM:SS format
  current_date=$(date +"%Y-%m-%d %H:%M:%S")

  # Escape any commas in the line to avoid CSV issues
  escaped_line=$(echo "$line" | sed 's/,/\\,/g')

  # Append the date and line to the output file in CSV format
  echo "$current_date,$escaped_line" >> "$OUTPUT_FILE"
done

echo "Output appended to $OUTPUT_FILE"
