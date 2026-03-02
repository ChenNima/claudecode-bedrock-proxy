#!/bin/bash
set -e
cd "$(dirname "$0")"

if [ -f proxy.pid ] && kill -0 "$(cat proxy.pid)" 2>/dev/null; then
    echo "Proxy already running (PID: $(cat proxy.pid))"
    exit 0
fi

export AWS_REGION="${AWS_REGION:-ap-northeast-1}"
export LISTEN_HOST="${LISTEN_HOST:-127.0.0.1}"  # localhost-only for direct run

echo "Starting Bedrock Effort Max Proxy..."
: > proxy.log  # truncate log
python3 proxy.py >> proxy.log 2>&1 &
echo $! > proxy.pid

for i in $(seq 1 20); do
    if curl -sf http://127.0.0.1:8888/health > /dev/null 2>&1; then
        echo "Proxy started (PID: $(cat proxy.pid))"
        curl -s http://127.0.0.1:8888/health | python3 -m json.tool
        exit 0
    fi
    sleep 0.25
done

echo "ERROR: Proxy failed to start. Check proxy.log:"
tail -20 proxy.log
kill "$(cat proxy.pid)" 2>/dev/null || true
rm -f proxy.pid
exit 1
