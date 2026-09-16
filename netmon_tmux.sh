#!/bin/sh
# netmon_tmux.sh — create a 4-quadrant layout with custom top-right sizing

set -eu

WIN_NAME="netmon"

# 1. Ensure root execution
if [ "$(id -u)" -ne 0 ]; then
  SCRIPT="$(realpath "$0")"
  exec su - root -c "sh $SCRIPT"
fi

# 2. Get current terminal dimensions so tmux doesn't default to 80x24
COLS="$(tput cols 2>/dev/null || echo 160)"
LINES="$(tput lines 2>/dev/null || echo 50)"

# 3. Kill previous session completely
tmux kill-session -t "$WIN_NAME" 2>/dev/null || true

# 4. Create session at real terminal dimensions
P_TOP_LEFT="$(tmux new-session -d -s "$WIN_NAME" -n "$WIN_NAME" -x "$COLS" -y "$LINES" -P -F '#{pane_id}')"

# -------------------------------------------------------------
# 5. Build 2x2 base quadrants (exact 50% width and height)

# Split Left / Right (50% width)
P_TOP_RIGHT="$(tmux split-window -d -h -p 50 -P -F '#{pane_id}' -t "$P_TOP_LEFT")"

# Split Left column (50% height) -> Top-Left & Bottom-Left
P_BOT_LEFT="$(tmux split-window -d -v -p 50 -P -F '#{pane_id}' -t "$P_TOP_LEFT")"

# Split Right column (50% height) -> Top-Right & Bottom-Right
P_BOT_RIGHT="$(tmux split-window -d -v -p 50 -P -F '#{pane_id}' -t "$P_TOP_RIGHT")"

# 6. Split Top-Right for queues:
# -l 9 gives systat queues 9 lines (perfect for your 4 queues) and leaves the rest for top.
# Change "-l 9" to "-p 50" if you prefer an exact 50/50 split of the quadrant instead.
P_MID_RIGHT="$(tmux split-window -d -v -l 9 -P -F '#{pane_id}' -t "$P_TOP_RIGHT")"
# -------------------------------------------------------------

# Send commands
tmux send-keys -t "$P_TOP_LEFT"  "/root/dev/pf_top" C-m
tmux send-keys -t "$P_BOT_LEFT"  "sh -lc 'watch ntpctl -s all'" C-m
tmux send-keys -t "$P_TOP_RIGHT" "top -C -s 1 -g ntpd" C-m
tmux send-keys -t "$P_MID_RIGHT" "systat -s 1 queues" C-m
tmux send-keys -t "$P_BOT_RIGHT" "systat -s 1 sensors" C-m

# Set titles
tmux select-pane -t "$P_TOP_LEFT"  -T "netmon"
tmux select-pane -t "$P_BOT_LEFT"  -T "ntpctl loop"
tmux select-pane -t "$P_TOP_RIGHT" -T "top"
tmux select-pane -t "$P_MID_RIGHT" -T "systat queues"
tmux select-pane -t "$P_BOT_RIGHT" -T "systat sensors"

# Attach to session
if [ -z "${TMUX-}" ]; then
  exec tmux attach-session -t "$WIN_NAME"
else
  exec tmux switch-client -t "$WIN_NAME" 2>/dev/null || exec tmux attach-session -t "$WIN_NAME"
fi
