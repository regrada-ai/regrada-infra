#!/bin/bash
# Redis SSH Tunnel through Bastion
# Usage: ./redis-tunnel.sh [start|stop|status]

REDIS_HOST="regrada-production-redis.jfdhgp.0001.use1.cache.amazonaws.com"
LOCAL_PORT=6380
REMOTE_PORT=6379
SSH_KEY="$HOME/.ssh/regrada"
SSH_USER="ec2-user"

is_running() {
    pgrep -f "ssh.*-L.*$LOCAL_PORT:$REDIS_HOST" > /dev/null 2>&1
}

start_tunnel() {
    if is_running; then
        echo "Tunnel already running on port $LOCAL_PORT"
        exit 0
    fi

    echo "Starting Redis tunnel on localhost:$LOCAL_PORT..."
    ssh -i "$SSH_KEY" \
        -L "$LOCAL_PORT:$REDIS_HOST:$REMOTE_PORT" \
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
        pkill -f "ssh.*-L.*$LOCAL_PORT:$REDIS_HOST"
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
