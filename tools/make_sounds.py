# Synthesizes the looping engine/wind beds and short gun/beep one-shots (ours, CC0). Run: python3 tools/make_sounds.py
import math, random, struct, wave
SR = 22050
OUT = "assets/sfx/"
random.seed(7)

def save(name, s):
    peak = max(1e-9, max(abs(x) for x in s))
    with wave.open(OUT + name, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(x / peak * 0.9 * 32767)) for x in s))

def lowpass(x, a, loops=2):
    # one-pole, run around the loop twice so the filter state wraps seamlessly
    y, out = x[-1], [0.0] * len(x)
    for _ in range(loops):
        for i, v in enumerate(x):
            y += a * (v - y); out[i] = y
    return out

def prop():  # 1 s: 4-stroke firing at 50 Hz with harmonics, prop chop at 25 Hz, rumble
    n = SR; noise = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.08)
    s = []
    for i in range(n):
        t = i / SR
        tone = sum(math.sin(2 * math.pi * 50 * k * t) / k ** 1.2 for k in range(1, 12))
        chop = 0.65 + 0.35 * math.sin(2 * math.pi * 25 * t) ** 2
        s.append((tone * 0.7 + noise[i] * 2.5) * chop)
    return s

def jet():  # 1 s: turbine whine 660/990 Hz over broadband roar
    n = SR; roar = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.15)
    return [roar[i] * 3.0 + 0.25 * math.sin(2 * math.pi * 660 * i / SR) + 0.12 * math.sin(2 * math.pi * 990 * i / SR) for i in range(n)]

def wind():  # 2 s: soft filtered noise with slow gusts
    n = 2 * SR; x = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.03)
    return [v * (0.7 + 0.3 * math.sin(2 * math.pi * 0.5 * i / SR)) for i, v in enumerate(x)]

def gun():  # 0.16 s: sharp supersonic crack + chest thump + short mechanical tail
    n = int(0.16 * SR)
    crack = [random.uniform(-1, 1) for _ in range(n)]
    body = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.25, 1)
    out = []
    for i in range(n):
        t = i / SR
        v = crack[i] * math.exp(-t / 0.006) * 1.4                      # crack
        v += body[i] * math.exp(-t / 0.03) * 2.2                      # muzzle blast
        v += math.sin(2 * math.pi * (95 - 200 * t) * t) * math.exp(-t / 0.05) * 1.2  # thump
        out.append(max(-1.0, min(1.0, v * 1.6)))                      # a little drive/clipping
    return out

def whiz():  # 0.3 s: bullet passing close: rising-then-falling band of noise with a snap
    n = int(0.3 * SR); out = []; y1 = y2 = 0.0
    for i in range(n):
        t = i / SR
        f = 0.35 + 0.25 * math.sin(math.pi * t / 0.3)                 # filter sweep (doppler-ish)
        x = random.uniform(-1, 1)
        y1 += f * (x - y1); y2 += f * (y1 - y2)
        env = math.sin(math.pi * min(t / 0.3, 1.0)) ** 2
        snap = random.uniform(-1, 1) * math.exp(-abs(t - 0.15) / 0.004) * 2.0
        out.append((x - y2) * env + snap)
    return out

def beep(f, d):
    n = int(d * SR)
    return [math.sin(2 * math.pi * f * i / SR) * min(1, i / 200, (n - i) / 200) for i in range(n)]

save("prop_loop.wav", prop()); save("jet_loop.wav", jet()); save("wind_loop.wav", wind())
save("gun.wav", gun()); save("whiz.wav", whiz()); save("lock.wav", beep(1500, 0.06)); save("warn.wav", beep(900, 0.12))
print("ok")
