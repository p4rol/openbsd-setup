#!/bin/sh
# netmon_tmux.sh — create a tmux window (2×2) running root-only tools
# Show the packet rate of the ntpd service, the sensors output, the current stratum level
# and the CPU utilisation 

set -eu

WIN_NAME="netmon"

# If not root, re-exec this script once via su to do everything as root.
if [ "$(id -u)" -ne 0 ]; then
  # Resolve the absolute path before switching users
  SCRIPT="$(realpath "$0")"
  exec su - root -c "sh $SCRIPT"
fi

# Create a window in the current tmux session if inside tmux; otherwise a new session.
if [ -n "${TMUX-}" ]; then
  WIN_ID="$(tmux new-window -P -F '#{window_id}' -n "$WIN_NAME")"
else
  tmux new-session -d -s "$WIN_NAME" -n "$WIN_NAME"
  WIN_ID="$(tmux display-message -p -t "${WIN_NAME}:0" '#{window_id}')"
fi

# Build a 2×2 layout, then force equal sizing.
tmux select-window -t "$WIN_ID"
tmux select-pane   -t "$WIN_ID".0
tmux split-window  -h -t "$WIN_ID".0
tmux select-pane   -t "$WIN_ID".0
tmux split-window  -v -t "$WIN_ID".0
tmux select-pane   -t "$WIN_ID".1
tmux split-window  -v -t "$WIN_ID".1
tmux select-layout -t "$WIN_ID" tiled

# Pane indices after splits:
# 0: top-left     1: top-right     2: bottom-left     3: bottom-right

# Top-left: /root/dev/netmon_combined -c .
tmux send-keys -t "$WIN_ID".0 "/root/dev/netmon_combined -c ." C-m

# Top-right: top
tmux send-keys -t "$WIN_ID".1 "top" C-m

# Bottom-left: clear each second then ntpctl -s all
tmux send-keys -t "$WIN_ID".2 "sh -lc 'while :; do clear; ntpctl -s all; sleep 1; done'" C-m

# Bottom-right: systat -s 1 sensors
tmux send-keys -t "$WIN_ID".3 "systat -s 1 sensors" C-m

# Optional titles
tmux select-pane -t "$WIN_ID".0 \; select-pane -T "netmon"
tmux select-pane -t "$WIN_ID".1 \; select-pane -T "top"
tmux select-pane -t "$WIN_ID".2 \; select-pane -T "ntpctl loop"
tmux select-pane -t "$WIN_ID".3 \; select-pane -T "systat sensors"

# Attach if we created a new session; otherwise focus the window.
if [ -z "${TMUX-}" ]; then
  exec tmux attach -t "$WIN_NAME"
else
  tmux select-window -t "$WIN_ID"
fi
