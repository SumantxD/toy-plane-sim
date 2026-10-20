# World music (ours, CC0): six hand-written folk-style tunes rendered with small synths, seamless loops.
# Needs numpy and sox:  python3 -m venv /tmp/mv && /tmp/mv/bin/pip install numpy && /tmp/mv/bin/python tools/make_music.py
#
# What the ear likes, and how this file does it:
# - Consonance: diatonic/pentatonic tunes, chords voiced above ~C3 (close intervals down low turn rough),
#   bass on root/fifth only, no detuned beating near unison.
# - No harshness: the ear canal boosts 2-5 kHz, so every voice is soft-edged (few upper partials, slow
#   attacks, plucks that darken as they ring) and the master rolls off the top.
# - Joy: major/mixolydian/dorian/lydian modes, lilting 6/8 and 3/4 or a light 4/4 groove at walking pace,
#   moderate syncopation (the groove sweet spot), a tin-whistle-like lead with cuts and delayed vibrato.
# - Reward: a tune you can hum (AABB, repeated motifs) plus surprises - harmony lines, a lift up a whole
#   step, a quiet breakdown before the full band - so expectation and payoff keep trading places.
# - No fatigue: intensity rises and falls in waves, no drum fill at the loop seam, the reverb tail wraps
#   around so the loop never clicks, and it all sits under the game's sound effects.
import os, subprocess, wave
import numpy as np

SR = 44100
OUT = "assets/music/"
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(n):
    i, acc = 1, 0
    while n[i] in "#b":
        acc += 1 if n[i] == "#" else -1
        i += 1
    return 12 * (int(n[i:]) + 1) + NOTE[n[0]] + acc


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def chord_notes(name, shift):
    # "Bm" -> [B, D, F#] as midi around C4; root midi for the bass
    root = NOTE[name[0]] + (1 if name[1:2] == "#" else -1 if name[1:2] == "b" else 0)
    q = name[1 + (name[1:2] in ("#", "b")):]
    third = 3 if q.startswith("m") else 4
    r = 48 + (root + shift) % 12
    return r, [r, r + third, r + 7]


def parse(bars, meter):
    # bars: [(chords, "A4 D5 F#5 A5:2 F#5")] -> notes [(start eighth, len, midi|None)], chords per eighth
    notes, chords, t = [], [], 0
    for ch, line in bars:
        n0 = t
        for tok in line.split():
            name, _, ln = tok.partition(":")
            ln = int(ln or 1)
            notes.append((t, ln, None if name == "r" else midi(name)))
            t += ln
        assert t - n0 == meter, (ch, line, t - n0)
        names = ch.split()
        for k in range(meter):
            chords.append(names[min(k * len(names) // meter, len(names) - 1)])
    return notes, chords


# ---------- instruments ----------
rng = np.random.default_rng(7)


def onepole(x, cutoff):
    a = 1.0 - np.exp(-2 * np.pi * cutoff / SR)
    # first-order lowpass via FFT-free recursion in blocks is slow; use the frequency-domain response
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    h = a / (1 - (1 - a) * np.exp(-2j * np.pi * f / SR))
    return np.fft.irfft(np.fft.rfft(x) * h, n)


def pluck(f, dur, bright=0.5, ring=1.5):
    # Karplus-Strong at an integer period, resampled to the exact pitch; the string darkens as it rings.
    p = max(2, int(SR / f))
    n = int(dur * SR * (SR / p) / f) + p + 2
    out = np.zeros(n)
    burst = rng.uniform(-1, 1, p)
    for _ in range(int((1 - bright) * 6) + 1):
        burst = 0.5 * (burst + np.roll(burst, 1))
    out[:p] = burst - burst.mean()
    d = 0.001 ** (1.0 / ((SR / p) * ring))
    for k in range(p + 1, n, p):
        e = min(k + p, n)
        out[k:e] = d * 0.5 * (out[k - p:e - p] + out[k - p - 1:e - p - 1])
    m = int(dur * SR)
    y = np.interp(np.arange(m) * (f * p / SR), np.arange(n), out)
    y *= np.minimum(1.0, np.arange(m) / (0.002 * SR))
    return y / (np.abs(y).max() + 1e-9)


def bell(f, dur, ring=1.6):
    t = np.arange(int(dur * SR)) / SR
    y = np.sin(2 * np.pi * f * t) * np.exp(-t / ring) + 0.25 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / (ring * 0.4))
    y += 0.08 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / (ring * 0.2))
    return y * np.minimum(1.0, t / 0.003)


def saw_pad(freqs, dur, attack=0.35, release=0.5):
    # strings: three slightly detuned soft saws per note (partials fall faster than a real saw)
    t = np.arange(int((dur + release) * SR)) / SR
    y = np.zeros_like(t)
    vib = 1 + 0.002 * np.sin(2 * np.pi * 4.7 * t)
    for f in freqs:
        for det in (-0.0025, 0.0, 0.0031):
            ph = 2 * np.pi * f * (1 + det) * t * vib + rng.uniform(0, 6.3)
            for k in range(1, int(2400 / f) + 1):
                y += np.sin(k * ph) / k ** 1.6
    env = np.minimum(1.0, t / attack) * np.clip((dur + release - t) / release, 0.0, 1.0)
    return y * env / (3 * len(freqs))


def lead(notes, eighth, total, voice, scale, shift):
    # One breathing line: legato glides, a little tongue between notes, Irish "cuts" on long notes,
    # vibrato that blooms after the attack. voice = (harmonics, breath, vibrato cents)
    harm, breath, vib_c = voice
    n = int(total * SR)
    fr = np.zeros(n)
    amp = np.zeros(n)
    vib = np.zeros(n)
    last = None
    for st, ln, m in notes:
        a, b = int(st * eighth * SR), min(n, int((st + ln) * eighth * SR))
        if m is None or a >= n:
            continue
        m += shift
        f = hz(m)
        seg = np.arange(b - a) / SR
        glide = 0.03 if last is not None else 0.0
        f0 = hz(last) if last is not None else f
        fr[a:b] = f + (f0 - f) * np.exp(-seg / max(glide, 1e-4) * 3)
        if ln >= 2 and rng.random() < 0.45:  # cut: a flick to the scale note above
            up = next(x for x in range(m + 1, m + 4) if (x - shift) % 12 in scale)
            c = int(0.035 * SR)
            fr[a:a + c] = hz(up)
        env = np.minimum(1.0, seg / 0.025) * np.clip((b - a) / SR - seg, 0, 0.04) / 0.04
        amp[a:b] = env * (0.85 + 0.15 * np.exp(-seg / 0.15))
        vib[a:b] = np.clip((seg - 0.22) / 0.3, 0, 1) * vib_c
        last = m
    t = np.arange(n) / SR
    fr = np.where(fr > 0, fr, 1.0) * 2 ** (vib * np.sin(2 * np.pi * 5.3 * t) / 1200)
    ph = 2 * np.pi * np.cumsum(fr) / SR
    y = sum(h * np.sin((k + 1) * ph) for k, h in enumerate(harm))
    noise = onepole(rng.standard_normal(n), 1800.0)
    y = y + breath * noise * (0.6 + 0.4 * np.sin(ph))
    amp = onepole(amp, 60.0)
    return y * amp


def drum_low(dur=0.5, f0=110.0, f1=58.0):
    t = np.arange(int(dur * SR)) / SR
    f = f1 + (f0 - f1) * np.exp(-t / 0.035)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    y += 0.25 * onepole(rng.standard_normal(len(t)), 900.0) * np.exp(-t / 0.02)
    return y


def drum_tap(dur=0.12):
    t = np.arange(int(dur * SR)) / SR
    y = onepole(rng.standard_normal(len(t)), 2200.0) * np.exp(-t / 0.025)
    y += 0.5 * np.sin(2 * np.pi * 240 * t) * np.exp(-t / 0.04)
    return y


def shaker(dur=0.09):
    t = np.arange(int(dur * SR)) / SR
    x = rng.standard_normal(len(t))
    return (x - onepole(x, 4000.0)) * np.sin(np.pi * t / dur) ** 2 * 0.5


def clap(dur=0.2):
    t = np.arange(int(dur * SR)) / SR
    x = onepole(rng.standard_normal(len(t)), 2400.0) - onepole(rng.standard_normal(len(t)), 500.0) * 0.5
    env = np.exp(-t / 0.05) + sum(np.exp(-np.maximum(t - d, 0) / 0.006) * (t >= d) for d in (0.0, 0.011, 0.02))
    return x * env * 0.5


# ---------- the tunes ----------
# bars: (chord or "two chords" split across the bar, melody in eighths "note:len")
TUNES = {
    "valley": dict(meter=6, eighth=0.2, scale={0, 2, 4, 6, 7, 9, 11}, drums="jig", style="folk",
        A=[("D", "A4 D5 F#5 A5:2 F#5"), ("G", "G5:2 B5 A5 G5 F#5"), ("D", "F#5:2 A5 D6:2 A5"), ("A", "B5 A5 G5 F#5 E5 C#5"),
           ("D", "D5 F#5 A5 D6 A5 F#5"), ("G", "G5:2 E5 B5:2 G5"), ("D A", "F#5 A5 F#5 E5 C#5 A4"), ("D", "D5:3 r:3")],
        B=[("Bm", "B5:2 A5 F#5:2 D5"), ("G", "G5 B5 D6 B5:2 G5"), ("D", "A5:2 F#5 D5 E5 F#5"), ("A", "E5 C#5 A4 E5:3"),
           ("Bm", "D5 F#5 B5 A5 F#5 D5"), ("G", "B4 D5 G5 F#5 E5 D5"), ("A", "C#5 E5 A5 G5 E5 C#5"), ("D", "D5:6")]),
    "volcano": dict(meter=8, eighth=0.29, scale={2, 4, 5, 7, 9, 11, 0}, drums="shanty", style="shanty",
        A=[("Dm", "A4:2 D5:2 D5 E5 F5:2"), ("C", "E5:2 C5:2 G4:2 C5 E5"), ("Dm", "F5:2 A5:2 G5 F5 E5 D5"), ("Am", "E5:4 r:2 A4 C5"),
           ("Dm", "D5:2 F5 A5 D6:2 C6 A5"), ("C", "G5:2 E5:2 C6:3 B5"), ("F C", "A5 G5 F5 A5 G5:2 E5:2"), ("Dm", "D5:6 r:2")],
        B=[("F", "C6:3 A5 F5:2 A5:2"), ("C", "G5:3 E5 C5:2 E5:2"), ("G", "D5 G5 B5:2 D6:2 B5 G5"), ("Dm", "A5:4 F5:2 D5:2"),
           ("F", "F5 A5 C6:2 A5:2 F5:2"), ("C", "E5 G5 C6:2 G5:2 E5:2"), ("Am", "E5:2 A5:2 G5 F5 E5 C5"), ("Dm", "D5:6 r:2")]),
    "frozen": dict(meter=6, eighth=0.34, scale={7, 9, 11, 0, 2, 4, 6}, drums="waltz", style="waltz",
        A=[("G", "D5:4 B4:2"), ("Em", "G5:3 F#5 E5:2"), ("C", "E5:4 C5:2"), ("D", "A4:2 D5:2 F#5:2"),
           ("G", "B5:4 A5:2"), ("Em", "G5:3 E5 B4:2"), ("Am D", "C5:2 E5 F#5:2 A5"), ("G", "G5:6")],
        B=[("C", "E5:2 G5:2 C6:2"), ("G", "B5:4 G5:2"), ("Am", "A5:3 G5 E5:2"), ("D", "F#5:4 D5:2"),
           ("Em", "E5:2 G5:2 B5:2"), ("C", "C6:4 B5 A5"), ("D", "A5:3 B5 A5 F#5"), ("G", "G5:6")]),
    "desert": dict(meter=6, eighth=0.24, scale={2, 4, 6, 7, 9, 11, 0}, drums="frame", style="desert",
        A=[("D", "D5 E5 F#5 A5:3"), ("C", "G5:2 E5 C5:2 E5"), ("G", "D5:2 G5 B5:2 G5"), ("D", "A5:3 F#5:3"),
           ("D", "D6:2 C6 A5:2 F#5"), ("C", "G5:2 E5 C6:3"), ("Am C", "A5 G5 E5 G5 E5 C5"), ("D", "D5:6")],
        B=[("C", "C6:3 G5 E5 G5"), ("C", "A5:2 G5 E5:2 C5"), ("D", "D5 F#5 A5 D6:3"), ("D", "C6 A5 F#5 D5:3"),
           ("G", "B5:3 A5 G5 D5"), ("Am", "E5:3 A5:3"), ("C", "G5 E5 C5 E5 G5 C6"), ("D", "A5:2 F#5 D5:3")]),
    "metro": dict(meter=8, eighth=0.268, scale={0, 2, 4, 5, 7, 9, 11}, drums="pop", style="synth",
        A=[("C", "E5 G5:2 C6 r G5:2 E5"), ("Am", "C5 E5:2 A5:3 G5 E5"), ("F", "A5 C6:2 A5 G5:2 F5 E5"), ("G", "D5:3 G5:3 r:2"),
           ("C", "E5 G5:2 C6 r D6:2 C6"), ("Am", "A5:3 G5 E5:2 C5:2"), ("F G", "F5 A5 C6 A5 G5 B5 D6 B5"), ("C", "C6:6 r:2")],
        B=[("F", "C6:3 A5 F5:3 G5"), ("G", "G5:3 D5 B4:2 D5:2"), ("Em", "E5:2 G5 B5:3 A5 G5"), ("Am", "A5:5 r G5 E5"),
           ("F", "F5 A5 C6:3 A5 G5 F5"), ("G", "D6:3 B5 G5:2 D5:2"), ("C", "E5 G5 C6:3 B5 C6 D6"), ("C", "C6:6 r:2")]),
    "sky": dict(meter=6, eighth=0.28, scale={5, 7, 9, 11, 0, 2, 4}, drums="soft", style="dream",
        A=[("F", "C5 F5 A5 C6:3"), ("G", "B5:2 A5 G5 D5:2"), ("F", "A5:3 F5 C5 F5"), ("C", "G5:2 E5 C5:3"),
           ("Dm", "D5 F5 A5 D6:3"), ("G", "B5:2 D6 B5:2 G5"), ("C", "E5 G5 C6 G5:2 E5"), ("F", "F5:6")],
        B=[("Am", "C6:3 B5 A5 E5"), ("G", "D6:3 B5 G5 D5"), ("F", "C6:2 A5 F5:2 A5"), ("C", "G5:3 E5:3"),
           ("Dm", "A5:2 D6 C6:2 A5"), ("G", "B5:2 G5 D5:3"), ("C", "E5:2 G5 C6:2 B5"), ("F", "A5:6")]),
}

# Per style: lead voice (harmonics, breath, vibrato cents), plucked colour, levels.
STYLES = {
    "folk": dict(lead=([1, 0.22, 0.07, 0.03], 0.05, 14), pluck=0.55, harp=0.75, pad=0.22, bells=0.0),
    "shanty": dict(lead=([1, 0.3, 0.12, 0.05], 0.045, 16), pluck=0.5, harp=0.6, pad=0.3, bells=0.0),
    "waltz": dict(lead=([1, 0.15, 0.05], 0.06, 12), pluck=0.45, harp=0.8, pad=0.28, bells=0.35),
    "desert": dict(lead=([1, 0.35, 0.15, 0.06], 0.07, 22), pluck=0.6, harp=0.55, pad=0.2, bells=0.0),
    "synth": dict(lead=([1, 0.4, 0.12, 0.08, 0.03], 0.0, 9), pluck=0.75, harp=0.7, pad=0.25, bells=0.2),
    "dream": dict(lead=([1, 0.12, 0.04], 0.07, 12), pluck=0.5, harp=0.85, pad=0.3, bells=0.4),
}

# Arrangement: (part, layers, key shift). Waves of intensity; the lift up a tone is the payoff, then a
# calm A brings it home and the intro takes over again at the loop seam.
PLAN = [
    ("I", "pad harp", 0),
    ("A", "pad harp bass melpluck", 0),
    ("A", "strum bass lead drum1", 0),
    ("B", "strum bass lead pad drum1", 0),
    ("B", "strum bass lead harm pad drum2", 0),
    ("A", "pad harp melpluck bells", 0),
    ("A", "strum bass lead harm drum2 pad", 0),
    ("B", "strum bass strings harm drum2", 0),
    ("A", "strum bass lead harm drum2 pad bells", 2),
    ("B", "strum bass lead harm drum2 pad", 2),
    ("A", "pad harp bass lead", 0),
    ("B", "pad harp melpluck bells", 0),
]


def render(name):
    tune = TUNES[name]
    st = STYLES[tune["style"]]
    meter, e = tune["meter"], tune["eighth"]
    bar = meter * e
    secs = []
    for part, layers, shift in PLAN:
        bars = tune["A"][:4] if part == "I" else tune[part]
        secs.append((bars, set(layers.split()), shift, part == "I"))
    total = sum(len(b) for b, _, _, _ in secs) * bar
    tail = 4.0
    n = int((total + tail) * SR)
    dry = np.zeros((2, n))
    wet = np.zeros((2, n))

    def put(sig, at, gain, pan=0.0, send=0.3):
        a = max(0, int(at * SR))
        b = min(n, a + len(sig))
        if b <= a:
            return
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        s = sig[:b - a] * gain
        dry[0, a:b] += s * l
        dry[1, a:b] += s * r
        wet[0, a:b] += s * l * send
        wet[1, a:b] += s * r * send

    def hum():
        return rng.normal(0, 0.006)

    t0 = 0.0
    for bars, layers, shift, intro in secs:
        notes, chords = parse(bars, meter)
        dur = len(bars) * bar
        for bi in range(len(bars)):
            bt = t0 + bi * bar
            names = bars[bi][0].split()
            for ci, cname in enumerate(names):
                ct = bt + ci * bar / len(names)
                cd = bar / len(names)
                root, tri = chord_notes(cname, shift)
                voicing = [m + (12 if m < 55 else 0) for m in tri]
                if "pad" in layers:
                    put(saw_pad([hz(m) for m in voicing], cd + 0.05), ct, st["pad"] * (0.6 if intro else 1.0), 0.0, 0.6)
                if "bass" in layers:
                    put(pluck(hz(root - 12), cd * 0.95, 0.3, 1.2), ct + hum(), 0.55, 0.0, 0.1)
                    if len(names) == 1 and tune["drums"] != "waltz":
                        put(pluck(hz(root - 5), cd * 0.45, 0.3, 1.0), ct + cd / 2 + hum(), 0.35, 0.0, 0.1)
                if "harp" in layers:
                    arp = sorted(voicing + [voicing[0] + 12, voicing[1] + 12])
                    step = 1 if meter == 6 else 2
                    k = 0
                    for s8 in range(0, int(round(cd / e)), step):
                        m = arp[k % len(arp)] if (k // len(arp)) % 2 == 0 else arp[-1 - k % len(arp)]
                        put(pluck(hz(m), 2.5, st["harp"], 2.2), ct + s8 * e + hum(), 0.16, 0.35, 0.55)
                        k += 1
                if "strum" in layers:
                    pat = {6: [(0, 1.0), (2, 0.5), (3, 0.8), (5, 0.5)], 8: [(0, 1.0), (2, 0.6), (3, 0.5), (5, 0.6), (6, 0.8)]}[meter]
                    if tune["drums"] == "waltz":
                        pat = [(2, 0.7), (4, 0.6)]
                    for s8, acc in pat:
                        if s8 * e >= cd - 1e-6:
                            continue
                        for vi, m in enumerate(voicing + [voicing[0] + 12]):
                            put(pluck(hz(m), e * 1.6, st["pluck"], 0.7), ct + s8 * e + vi * 0.012 + hum(), 0.09 * acc, -0.35, 0.3)
                if "bells" in layers and st["bells"] > 0 and ci == 0 and bi % 2 == 0:
                    put(bell(hz(voicing[2] + 24), 3.0), ct + hum(), 0.06 * st["bells"], 0.5, 0.8)
        # melody lines
        if not intro:
            mel = [(s, l, m) for s, l, m in notes]
            if "lead" in layers:
                put(lead(mel, e, dur, st["lead"], tune["scale"], shift), t0, 0.32, 0.1, 0.35)
            if "strings" in layers:
                put(lead(mel, e, dur, ([1, 0.45, 0.25, 0.14, 0.08, 0.04], 0.0, 18), tune["scale"], shift - 12), t0, 0.3, 0.0, 0.5)
            if "melpluck" in layers:
                for s, l, m in mel:
                    if m is not None:
                        put(pluck(hz(m + shift), max(l * e * 2, 1.2), st["harp"], 2.0), t0 + s * e + hum(), 0.3, 0.2, 0.5)
            if "harm" in layers:
                for s, l, m in mel:
                    if m is None:
                        continue
                    root, tri = chord_notes(chords[s], 0)
                    pcs = {x % 12 for x in tri}
                    under = [m - d for d in (3, 4, 8, 9) if (m - d) % 12 in pcs]
                    if under:
                        put(pluck(hz(under[0] + shift), max(l * e * 1.8, 0.8), st["harp"] * 0.8, 1.6), t0 + s * e + 0.01 + hum(), 0.17, -0.45, 0.45)
        # drums: never a fill at the end of the loop
        if "drum1" in layers or "drum2" in layers:
            full = "drum2" in layers
            for bi in range(len(bars)):
                bt = t0 + bi * bar
                kind = tune["drums"]
                if kind in ("jig", "frame", "soft"):
                    for s8 in range(6):
                        if s8 in (0, 3):
                            put(drum_low(0.5, 120 if s8 == 0 else 105, 60), bt + s8 * e, 0.5 if kind != "soft" else 0.3, 0.0, 0.15)
                        elif full or s8 in (2, 5):
                            put(drum_tap(), bt + s8 * e + hum(), (0.16 if s8 in (2, 5) else 0.1) * (0.6 if kind == "soft" else 1.0), 0.15, 0.2)
                    if full and kind != "soft":
                        for s8 in range(6):
                            put(shaker(), bt + s8 * e, 0.05 * (1.0 if s8 % 3 == 0 else 0.6), -0.3, 0.2)
                elif kind == "waltz":
                    put(drum_low(0.6, 100, 55), bt, 0.3, 0.0, 0.25)
                    for s8 in (2, 4):
                        put(drum_tap(), bt + s8 * e, 0.06, 0.2, 0.3)
                elif kind in ("shanty", "pop"):
                    for s8 in range(8):
                        if s8 in (0, 4) or (full and s8 == 3 and kind == "pop") or (full and s8 == 7 and kind == "shanty" and bi % 2 == 1):
                            put(drum_low(0.5, 130, 55), bt + s8 * e, 0.6, 0.0, 0.15)
                        if s8 in (2, 6):
                            put(clap() if full else drum_tap(), bt + s8 * e + hum(), 0.22 if full else 0.15, 0.1, 0.35)
                        if full:
                            put(shaker(), bt + s8 * e, 0.045 * (1.0 if s8 % 2 == 0 else 0.6), -0.3, 0.2)
        t0 += dur

    # Desert: a soft open-fifth drone under everything (the tonic and its fifth, no thirds to roughen)
    if tune["style"] == "desert":
        drone = saw_pad([hz(50), hz(57)], total - 0.5, 4.0, 4.0)
        put(drone, 0.0, 0.18, 0.0, 0.5)

    # Reverb: a warm, darkening 2.4 s room (noise IR whose highs die first), convolved block-wise.
    ir_n = int(2.4 * SR)
    ti = np.arange(ir_n) / SR
    ir = []
    for c in range(2):
        bright = rng.standard_normal(ir_n) * np.exp(-ti / 0.18)
        dark = onepole(rng.standard_normal(ir_n), 2500.0) * np.exp(-ti / 0.55)
        x = np.concatenate([np.zeros(int(0.022 * SR)), (0.35 * bright + dark)])[:ir_n]
        ir.append(x / np.sqrt((x ** 2).sum()))
    mix = dry.copy()
    blk = 1 << 17
    fft_n = 1 << int(np.ceil(np.log2(blk + ir_n)))
    for c in range(2):
        H = np.fft.rfft(ir[c], fft_n)
        acc = np.zeros(n + fft_n)
        for a in range(0, n, blk):
            seg = wet[c, a:a + blk]
            acc[a:a + fft_n] += np.fft.irfft(np.fft.rfft(seg, fft_n) * H, fft_n)
        mix[c] += 0.55 * acc[:n]

    # Seamless loop: the tail past the end rings over the start.
    L = int(total * SR)
    out = mix[:, :L].copy()
    out[:, :n - L] += mix[:, L:]
    # Master: soften the top (2-5 kHz is where the ear hurts), then a gentle level.
    for c in range(2):
        out[c] = 0.75 * onepole(out[c], 7000.0) + 0.25 * onepole(out[c], 3000.0)
    out /= np.abs(out).max() + 1e-9
    out = np.tanh(out * 1.2) / np.tanh(1.2) * 0.89
    return out, total


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    tmp = "/tmp/_music_%s.wav" % name
    with wave.open(tmp, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x.T, -1, 1) * 32767).astype("<i2").tobytes())
    subprocess.run(["sox", tmp, "-C", "4", OUT + name + ".ogg"], check=True)
    os.remove(tmp)


if __name__ == "__main__":
    import sys
    for name in sys.argv[1:] or TUNES:
        x, total = render(name)
        save(name, x)
        print("%-8s %5.1f s" % (name, total))
