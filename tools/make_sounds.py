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
def thunder():  # 2.5 s: crack then long low rumble
    n = int(2.5 * SR); rumble = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.02, 1)
    out = []
    for i in range(n):
        t = i / SR
        crack = random.uniform(-1, 1) * math.exp(-t / 0.05)
        out.append(crack * 0.8 + rumble[i] * 6.0 * math.exp(-t / 0.9) * (0.7 + 0.3 * math.sin(t * 9.0)))
    return out

def waterfall():  # 3 s: dense roaring noise, seamless (state-wrapped filter)
    n = 3 * SR; a = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.35); b = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.05)
    return [a[i] * 1.0 + b[i] * 3.0 for i in range(n)]

def creak():  # 4 s: slow wooden squeaks from a turning windmill
    n = 4 * SR; out = []
    for i in range(n):
        t = i / SR; ph = (t % 2.0)
        env = math.exp(-((ph - 0.6) ** 2) / 0.02) + 0.6 * math.exp(-((ph - 1.5) ** 2) / 0.01)
        f = 180 + 60 * math.sin(t * 3.1)
        out.append(math.sin(2 * math.pi * f * t + 3 * math.sin(2 * math.pi * 23 * t)) * env * 0.6 + random.uniform(-1, 1) * 0.03)
    return out

def rumble():  # 4 s: deep volcanic rumble
    n = 4 * SR; x = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.01)
    return [v * (0.8 + 0.2 * math.sin(2 * math.pi * 0.5 * i / SR)) for i, v in enumerate(x)]

save("waterfall_loop.wav", waterfall()); save("creak_loop.wav", creak()); save("rumble_loop.wav", rumble())
save("thunder.wav", thunder()); save("gun.wav", gun()); save("whiz.wav", whiz()); save("lock.wav", beep(1500, 0.06)); save("warn.wav", beep(900, 0.12))

# ---------- per-plane guns, turret guns, ordnance, events ----------
def shot(dur, crack, crack_t, body, body_a, body_t, thump_f, thump_t, thump_a, ring=(), drive=1.6):
    n = int(dur * SR)
    c = [random.uniform(-1, 1) for _ in range(n)]
    b = lowpass([random.uniform(-1, 1) for _ in range(n)], body, 1)
    out = []
    for i in range(n):
        t = i / SR
        v = c[i] * math.exp(-t / crack_t) * crack
        v += b[i] * math.exp(-t / body_t) * body_a
        v += math.sin(2 * math.pi * (thump_f - thump_f * 1.5 * t) * t) * math.exp(-t / thump_t) * thump_a
        for f, a, d in ring:  # metallic ring of the mechanism
            v += math.sin(2 * math.pi * f * t) * a * math.exp(-t / d)
        out.append(max(-1.0, min(1.0, v * drive)) * min(1.0, (n - i) / 110))  # 5 ms fade: no click at the end
    return out

save("gun_cub.wav", shot(0.09, 1.0, 0.004, 0.45, 1.2, 0.012, 190, 0.02, 0.6, ((1250, 0.25, 0.015),)))      # toy rattle: light, bright
save("gun_racer.wav", shot(0.1, 1.8, 0.005, 0.35, 1.6, 0.018, 150, 0.025, 0.9))                           # snappy high crack
save("gun_twin.wav", shot(0.32, 0.8, 0.008, 0.12, 2.6, 0.07, 62, 0.12, 1.8, drive=1.3))                    # heavy cannon boom
save("gun_fighter.wav", shot(0.18, 1.4, 0.006, 0.25, 2.0, 0.03, 95, 0.05, 1.2, ((2300, 0.18, 0.03), (3150, 0.1, 0.02))))  # autocannon ring
save("aa_gun.wav", shot(0.15, 0.7, 0.006, 0.18, 2.2, 0.04, 120, 0.06, 1.4, drive=1.4))                    # AA turret chug
save("flak.wav", shot(0.9, 0.6, 0.01, 0.04, 3.0, 0.25, 55, 0.3, 1.5, drive=1.2))                          # high-altitude whump

def whistle():  # 2 s falling bomb whistle, swelling as it drops
    n = 2 * SR; out = []; ph = 0.0
    for i in range(n):
        t = i / SR
        ph += 2 * math.pi * (1400 - 450 * t) / SR
        out.append(math.sin(ph) * (0.2 + 0.8 * t / 2.0) * min(1, (n - i) / 400) + random.uniform(-1, 1) * 0.04)
    return out

def flare():  # 0.7 s: pop then a sizzling fizz
    n = int(0.7 * SR); hiss = [random.uniform(-1, 1) for _ in range(n)]; out = []; y = 0.0
    for i in range(n):
        t = i / SR
        y += 0.6 * (hiss[i] - y)
        pop = math.sin(2 * math.pi * (260 - 300 * t) * t) * math.exp(-t / 0.03) * 1.5
        out.append(pop + (hiss[i] - y) * math.exp(-t / 0.35) * 1.2)
    return out

def siren():  # 5 s distant air-raid siren: slow rise and fall, muffled
    n = 5 * SR; ph = 0.0; out = []
    for i in range(n):
        t = i / SR
        f = 300 + 380 * math.sin(math.pi * t / 5.0) ** 2
        ph += 2 * math.pi * f / SR
        out.append((math.sin(ph) + 0.4 * math.sin(2 * ph) + 0.2 * math.sin(3 * ph)) * math.sin(math.pi * t / 5.0))
    return lowpass(out, 0.25, 1)

def fanfare():  # 1 s: three bright rising notes and a held chord
    n = SR; out = [0.0] * n
    for k, (f, start) in enumerate(((523.25, 0.0), (659.25, 0.12), (783.99, 0.24), (1046.5, 0.36))):
        for i in range(int(start * SR), n):
            t = i / SR - start
            out[i] += (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t)) * math.exp(-t / (0.5 if k == 3 else 0.2)) * min(1, t * 300)
    return out

save("bomb_whistle.wav", whistle()); save("flare.wav", flare()); save("siren.wav", siren()); save("fanfare.wav", fanfare())

# ---------- world beds: quiet IGI-style background, 16 s seamless loops ----------
# Every partial and LFO is a whole number of cycles in L, and events wrap around, so loops never click.
L = 16.0
N = int(L * SR)

def q(f):  # snap a frequency so it completes whole cycles in the loop
    return round(f * L) / L

def pad(out, f, amp, lfo_cycles=1, phase=0.0, bright=0.3, sharp=1.0):
    f = q(f)
    for i in range(N):
        t = i / SR
        env = (0.5 + 0.5 * math.sin(2 * math.pi * lfo_cycles * t / L + phase)) ** sharp
        out[i] += (math.sin(2 * math.pi * f * t) + bright * math.sin(4 * math.pi * f * t)) * amp * env

def bell(out, f, at, amp, decay):
    f = q(f)
    for k in range(int(decay * 5 * SR)):
        t = k / SR
        out[(int(at * SR) + k) % N] += (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 2.76 * t)) * amp * math.exp(-t / decay)

def air(out, a, amp, lfo_cycles=2):
    x = lowpass([random.uniform(-1, 1) for _ in range(N)], a)
    for i in range(N):
        out[i] += x[i] * amp * (0.6 + 0.4 * math.sin(2 * math.pi * lfo_cycles * i / N))

def bed(name, build):
    out = [0.0] * N
    build(out)
    save(name, out)

bed("bed_valley.wav", lambda o: ([pad(o, f, a, c, p) for f, a, c, p in ((110, 0.5, 1, 0), (164.81, 0.35, 2, 1), (220, 0.3, 1, 2), (277.18, 0.22, 3, 3), (329.63, 0.18, 2, 4))], air(o, 0.02, 4.0)))
bed("bed_volcano.wav", lambda o: ([pad(o, f, a, c, p, 0.5) for f, a, c, p in ((73.42, 0.6, 1, 0), (73.67, 0.5, 1, 0.5), (87.31, 0.3, 2, 2), (110, 0.25, 1, 3))], air(o, 0.01, 6.0, 1)))
bed("bed_frozen.wav", lambda o: ([pad(o, f, a, c, p, 0.1, 3.0) for f, a, c, p in ((329.63, 0.3, 2, 0), (493.88, 0.22, 3, 2), (659.25, 0.15, 5, 4), (164.81, 0.3, 1, 1))], air(o, 0.06, 3.0, 3)))
bed("bed_desert.wav", lambda o: ([pad(o, f, a, c, p, 0.4) for f, a, c, p in ((73.42, 0.55, 1, 0), (110, 0.35, 2, 1), (155.56, 0.2, 3, 2.5), (146.83, 0.22, 1, 4))], air(o, 0.12, 1.5, 4)))

def metro(o):
    for f, a, c, p in ((220, 0.18, 1, 0), (261.63, 0.14, 2, 1), (329.63, 0.12, 1, 2), (392, 0.1, 3, 3)):
        pad(o, f, a, c, p, 0.2)
    bass = q(55.0)
    for i in range(N):  # soft pulsing synth bass, 2 pulses a second (32 per loop)
        t = i / SR; beat = (t * 2.0) % 1.0
        saw = sum(math.sin(2 * math.pi * bass * k * t) / k for k in range(1, 7))
        o[i] += saw * 0.35 * math.exp(-beat / 0.18)
    air(o, 0.03, 1.5, 1)

def sky(o):
    for f, a, c, p in ((196, 0.3, 1, 0), (293.66, 0.22, 2, 1.5), (392, 0.15, 1, 3)):
        pad(o, f, a, c, p, 0.15)
    for at, f in ((0.5, 1046.5), (3.1, 1318.5), (5.9, 1568.0), (8.4, 1174.7), (11.2, 1318.5), (13.8, 987.77)):
        bell(o, f, at, 0.18, 0.9)
    air(o, 0.04, 2.0, 2)

bed("bed_metro.wav", metro); bed("bed_sky.wav", sky)

def pop():  # 0.35 s balloon pop: sharp snap, a rubbery flap, no explosion
    n = int(0.35 * SR); out = []
    for i in range(n):
        t = i / SR
        snap = random.uniform(-1, 1) * math.exp(-t / 0.004) * 1.6
        flap = math.sin(2 * math.pi * (420 - 600 * t) * t) * math.exp(-t / 0.05) * 0.6
        out.append((snap + flap + random.uniform(-1, 1) * math.exp(-t / 0.06) * 0.3) * min(1.0, (n - i) / 110))
    return out

save("pop.wav", pop())
print("ok")
