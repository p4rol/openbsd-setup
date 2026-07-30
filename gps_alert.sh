#!/bin/sh
# ==============================================================================
# Script:  /usr/local/bin/gps_alert.sh
# Purpose: Handles state-change events from OpenBSD's sensorsd for the nmea(4)
#          GPS time source, logging alerts and recoveries via syslog.
#
# Usage:
# This script is not meant to be run manually. It is executed by sensorsd(8)
# when a monitored sensor changes its status (e.g., OK -> CRITICAL).
#
# Required /etc/sensorsd.conf configuration:
# hw.sensors.nmea0.indicator0:status:command=/usr/local/bin/gps_alert.sh hw.sensors.nmea0.indicator0 "%2" "%s"
# ==============================================================================

# ------------------------------------------------------------------------------
# Argument Mapping
# sensorsd injects these arguments dynamically based on the config tokens.
# ------------------------------------------------------------------------------
SENSOR_NAME=$1  # Hardcoded sensor name passed from config (e.g., hw.sensors.nmea0.indicator0)
SENSOR_VAL=$2   # The current reading mapped from the %2 token (e.g., "On" or "Off")
SENSOR_STAT=$3  # The kernel state mapped from the %s token (e.g., "OK", "WARN", "CRITICAL")

# ------------------------------------------------------------------------------
# State Handling & Logging
# ------------------------------------------------------------------------------
if [ "$SENSOR_STAT" = "OK" ]; then
    # The sensor has recovered (e.g., the GPS antenna was reconnected and has a fix).
    logger -t gps_monitor "RECOVERY: GPS sensor $SENSOR_NAME has returned to normal (State: $SENSOR_STAT, Value: $SENSOR_VAL)"
else
    # The sensor has degraded (e.g., the GPS lost its fix or the device disconnected).
    logger -t gps_monitor "ALERT: GPS sensor $SENSOR_NAME transitioned to state $SENSOR_STAT (Value: $SENSOR_VAL)"
fi
