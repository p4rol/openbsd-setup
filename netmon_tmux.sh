#!/bin/sh
# netmon_tmux.sh — create a tmux window running root-only tools
# Show the packet rate of the ntpd service, the sensors/queues output, the current stratum level
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

tmux select-window -t "$WIN_ID"

# 1. Get initial top-left pane
P_TL="$(tmux display-message -p -t "$WIN_ID" '#{pane_id}')"

# 2. Split left/right (50/50 width)
P_TR="$(tmux split-window -h -P -F '#{pane_id}' -t "$P_TL")"

# 3. Split left side vertically -> bottom-left
P_BL="$(tmux split-window -v -P -F '#{pane_id}' -t "$P_TL")"

# 4. Split right side vertically -> bottom-right
P_BR="$(tmux split-window -v -P -F '#{pane_id}' -t "$P_TR")"

# 5. Split top-right vertically -> lower top-right pane
P_TR_BOT="$(tmux split-window -v -P -F '#{pane_id}' -t "$P_TR")"

# Send commands to each pane
# Top-left: pf_top
tmux send-keys -t "$P_TL" "/root/dev/pf_top" C-m

# Bottom-left: ntpctl loop
tmux send-keys -t "$P_BL" "sh -lc 'watch ntpctl -s all'" C-m

# Top-right (upper): top
tmux send-keys -t "$P_TR" "top -C -s 1 -g ntpd" C-m

# Top-right (lower): systat queues
tmux send-keys -t "$P_TR_BOT" "systat -s 1 queues" C-m

# Bottom-right: systat sensors
tmux send-keys -t "$P_BR" "systat -s 1 sensors" C-m

# Set pane titles
tmux select-pane -t "$P_TL"     -T "netmon"
tmux select-pane -t "$P_BL"     -T "ntpctl loop"
tmux select-pane -t "$P_TR"     -T "top"
tmux select-pane -t "$P_TR_BOT" -T "systat queues"
tmux select-pane -t "$P_BR"     -T "systat sensors"

# Attach if we created a new session; otherwise focus the window.
if [ -z "${TMUX-}" ]; then
  exec tmux attach -t "$WIN_NAME"
else
  tmux select-window -t "$WIN_ID"
fi

# EOF comment
