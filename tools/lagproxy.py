# UDP relay that makes a bad network on purpose: python3 tools/lagproxy.py LISTEN_PORT SERVER_PORT RTT_MS JITTER_MS LOSS_PCT
# Point a client at LISTEN_PORT. Each direction gets RTT/2 delay + random jitter, and drops LOSS_PCT of packets.
# Packets keep their order per direction (jitter bunches them up, like real links), unless --reorder is passed.
# --blackout START_S DUR_S (repeatable) drops everything both ways in that window (Wi-Fi loss);
# SIGUSR1 toggles a blackout by hand.
import asyncio, random, signal, sys, time

listen, server, rtt, jitter, loss = int(sys.argv[1]), int(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
reorder = "--reorder" in sys.argv
stats = {"up": 0, "down": 0, "dropped": 0}
blackouts = [(float(sys.argv[i + 1]), float(sys.argv[i + 2])) for i, a in enumerate(sys.argv) if a == "--blackout"]
manual = [False]
t0 = time.monotonic()


def dark():
    t = time.monotonic() - t0
    return manual[0] or any(s <= t < s + d for s, d in blackouts)


class Link:
    def __init__(self):
        self.last = 0.0  # release time of the previous packet, keeps order

    def delay(self, loop):
        if dark() or random.random() < loss / 100.0:
            stats["dropped"] += 1
            return None
        d = rtt / 2000.0 + max(0.0, random.gauss(0.0, jitter / 1000.0))
        t = loop.time() + d
        if not reorder:
            t = max(t, self.last + 1e-6)  # strictly later: equal deadlines may fire out of order
            self.last = t
        return t - loop.time()


class Upstream(asyncio.DatagramProtocol):  # proxy <-> server, one per client address
    def __init__(self, front, client):
        self.front, self.client, self.down = front, client, Link()

    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        loop = asyncio.get_running_loop()
        d = self.down.delay(loop)
        if d is not None:
            stats["down"] += 1
            loop.call_later(d, self.front.transport.sendto, data, self.client)


class Front(asyncio.DatagramProtocol):  # clients -> proxy
    def __init__(self):
        self.ups, self.links = {}, {}

    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        loop = asyncio.get_running_loop()
        if addr not in self.ups:
            self.links[addr] = Link()
            self.ups[addr] = None
            loop.create_task(self.connect(addr))
        d = self.links[addr].delay(loop)
        if d is None:
            return
        stats["up"] += 1
        loop.call_later(d, self.send_up, addr, data)

    async def connect(self, addr):
        loop = asyncio.get_running_loop()
        t, p = await loop.create_datagram_endpoint(lambda: Upstream(self, addr), remote_addr=("127.0.0.1", server))
        self.ups[addr] = t

    def send_up(self, addr, data):
        if self.ups.get(addr):
            self.ups[addr].sendto(data)


async def main():
    loop = asyncio.get_running_loop()
    await loop.create_datagram_endpoint(Front, local_addr=("127.0.0.1", listen))
    loop.add_signal_handler(signal.SIGUSR1, lambda: (manual.__setitem__(0, not manual[0]), print(f"proxy blackout {'on' if manual[0] else 'off'}", flush=True)))
    print(f"lagproxy :{listen} -> :{server}  rtt {rtt}ms  jitter {jitter}ms  loss {loss}%  blackouts {blackouts}", flush=True)
    while True:
        await asyncio.sleep(10)
        print(f"proxy up {stats['up']} down {stats['down']} dropped {stats['dropped']}", flush=True)

asyncio.run(main())
