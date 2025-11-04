#!/bin/sh
#
#
# Script to reboot this host
#
# Crontab entry, runs at midnight every day
# 0 0 * * * /root/dev/reboot.sh             #  Daily at Midnight (12:00 AM)
#
#
#

logger "Attempting to reboot the host"

reboot

# EOF
