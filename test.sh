#!/bin/sh
# Headless match: server + N bot clients for S seconds. Usage: ./test.sh [mode 0|1] [clients] [seconds]
cd "$(dirname "$0")"
MODE=${1:-0}; N=${2:-2}; S=${3:-60}; SPEED=${4:-1}; PORTARG=""
pkill -f "godot --headless -- --(server|join|host-online)" ; sleep 0.5
godot --headless -- --server --start --port 7801 --mode $MODE --speed $SPEED > /tmp/ps_srv.log 2>&1 &
sleep 1.5
for i in $(seq 1 $N); do godot --headless -- --join --port 7801 --bot --speed $SPEED > /tmp/ps_cli$i.log 2>&1 & done
sleep $S
pkill -f "godot --headless -- --(server|join|host-online)"
echo "=== server"; grep -v "^Godot Engine" /tmp/ps_srv.log
for i in $(seq 1 $N); do echo "=== client $i"; grep -v "^Godot Engine" /tmp/ps_cli$i.log | sort | uniq -c | sort -rn | head -15; done
