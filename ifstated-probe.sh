#!/bin/sh
# /etc/ifstated-probe.sh

STATE_FILE="/tmp/.ifstated_probe_state"
LAST_STATE=$(cat "$STATE_FILE" 2>/dev/null)

log_change() {
    NEW_STATE="$1"
    MSG="$2"
    # Only write to syslog if the diagnostic state actually changed
    if [ "$LAST_STATE" != "$NEW_STATE" ]; then
        logger -t ifstated_diag "$MSG"
        echo "$NEW_STATE" > "$STATE_FILE"
    fi
}

# -------------------------------------------------------------------------
# Diagnostic Step 1: Administrative Interface Status
# -------------------------------------------------------------------------
if ! ifconfig em0 | grep -Fq '<UP,'; then
    log_change "EM0_ADMIN_DOWN" "PROBE FAILED [1/4]: em0 is administratively DOWN (e.g. ifconfig em0 down)"
    exit 1
fi

# -------------------------------------------------------------------------
# Diagnostic Step 2: Physical Cable / Carrier Status
# -------------------------------------------------------------------------
if ! ifconfig em0 | grep -Fq 'status: active'; then
    log_change "EM0_NO_CARRIER" "PROBE FAILED [2/4]: em0 has no physical carrier (cable unplugged or ONT link lost)"
    exit 1
fi

# -------------------------------------------------------------------------
# Diagnostic Step 3: PPPoE Protocol / Session Status
# -------------------------------------------------------------------------
if ! ifconfig pppoe0 | grep -Fq 'status: active'; then
    log_change "PPPOE_DOWN" "PROBE FAILED [3/4]: pppoe0 session is DOWN or renegotiating"
    exit 1
fi

# -------------------------------------------------------------------------
# Diagnostic Step 4: ICMP Ping Reachability
# -------------------------------------------------------------------------
if ! timeout 1.5 ping -q -c 1 -w 1 8.8.8.8 >/dev/null 2>&1; then
    log_change "PING_FAILED" "PROBE FAILED [4/4]: ICMP ping to 8.8.8.8 timed out (silent ISP packet loss)"
    exit 1
fi

# -------------------------------------------------------------------------
# All Diagnostics Passed
# -------------------------------------------------------------------------
log_change "PRIMARY_OK" "PROBE SUCCESS: All primary health checks passed (em0 UP, carrier active, PPPoE active, 8.8.8.8 ping OK)"
exit 0


# EOF
