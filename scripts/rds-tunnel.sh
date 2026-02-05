#!/bin/bash
# RDS SSH Tunnel through Bastion
# Usage: ./rds-tunnel.sh [start|stop|status]

RDS_HOST="regrada-production-postgres.cvjc3vnqsn7j.us-east-1.rds.amazonaws.com"
LOCAL_PORT=5433
REMOTE_PORT=5432
SSH_KEY="$HOME/.ssh/regrada"
SSH_USER="ec2-user"

is_running() {
    pgrep -f "ssh.*-L.*$LOCAL_PORT:$RDS_HOST" > /dev/null 2>&1
}

start_tunnel() {
    if is_running; then
        echo "Tunnel already running on port $LOCAL_PORT"
        exit 0
    fi

    echo "Starting RDS tunnel on localhost:$LOCAL_PORT..."
    ssh -i "$SSH_KEY" \
        -L "$LOCAL_PORT:$RDS_HOST:$REMOTE_PORT" \
        "$SSH_USER@jump-ec2" \
        -N -f \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=60 \
        -o StrictHostKeyChecking=no

    if is_running; then
        echo "Tunnel started. Connect to localhost:$LOCAL_PORT"
    else
        echo "Failed to start tunnel"
        exit 1
    fi
}

stop_tunnel() {
    if is_running; then
        pkill -f "ssh.*-L.*$LOCAL_PORT:$RDS_HOST"
        echo "Tunnel stopped"
    else
        echo "Tunnel not running"
    fi
}

status_tunnel() {
    if is_running; then
        echo "Tunnel is running on localhost:$LOCAL_PORT"
    else
        echo "Tunnel is not running"
    fi
}

case "${1:-start}" in
    start)  start_tunnel ;;
    stop)   stop_tunnel ;;
    status) status_tunnel ;;
    *)      echo "Usage: $0 [start|stop|status]"; exit 1 ;;
esac
