#!/bin/bash
# Bad-network test: host + bot client through tools/lagproxy.py. Prints the client's --netstats lines.
# usage: tools/lagtest.sh RTT_MS JITTER_MS LOSS_PCT [--reorder]   e.g. tools/lagtest.sh 250 50 3 --reorder
cd "$(dirname "$0")/.."
godot --headless -- --server --start --port 7830 --mode 3 --size 1 --world 0 --quit-after-secs 40 > /tmp/lag_srv.log 2>&1 &
S=$!
python3 tools/lagproxy.py 7831 7830 $1 $2 $3 $4 > /tmp/lag_proxy.log 2>&1 &
P=$!
sleep 1.5
godot --headless -- --join --port 7831 --bot --netstats --quit-after-secs 25 > /tmp/lag_cli.log 2>&1
kill $P $S 2>/dev/null; wait 2>/dev/null
echo "== rtt $1 ms, jitter $2 ms, loss $3%, $4"
grep -E "^NET" /tmp/lag_cli.log | tail -2
grep -E "dropped" /tmp/lag_proxy.log | tail -1
