"""Forge Guardian fight music: the forge wakes up. Synthesised with numpy.

Same key (D minor) and the same bronze sounds as the calm cave track, so the
game can crossfade between them. 128 BPM, 32 bars = exactly 60 s, built on a
circular timeline so it loops with no seam.

  bars 1-8    taiko drums, anvil strikes on 2 and 4, driving bass
  bars 9-16   + bronze arpeggio and low brass chords
  bars 17-32  + the cave melody, now played loud and fast on a horn

usage: python3 boss_music.py out_dir
"""
import sys, wave
import numpy as np

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
BPM = 128
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 32
L = BARS * BAR          # 60 s
N = int(round(L * SR))
S16 = BEAT / 4          # one 16th note
rng = np.random.default_rng(21)


def hz(note):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[note[0]]; rest = note[1:]
    if rest[0] == "b": n -= 1; rest = rest[1:]
    elif rest[0] == "#": n += 1; rest = rest[1:]
    return 440.0 * 2 ** ((12 * (int(rest) + 1) + n - 69) / 12)


def add(buf, sig, start_s, gain=1.0, pan=0.0):
    s0 = int(round(start_s * SR)) % N
    idx = (s0 + np.arange(len(sig))) % N
    buf[0][idx] += sig * np.cos((pan + 1) * np.pi / 4) * gain
    buf[1][idx] += sig * np.sin((pan + 1) * np.pi / 4) * gain


def fft_filter(x, shape):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * shape(f), len(x))


def lowpass(fc, order=2):
    return lambda f: 1 / np.sqrt(1 + (f / fc) ** (2 * order))


def highpass(fc, order=2):
    return lambda f: 1 / np.sqrt(1 + (fc / np.maximum(f, 1e-6)) ** (2 * order))


dry = np.zeros((2, N)); wet = np.zeros((2, N))

# one chord per bar, an 8 bar cycle played four times
CYCLE = [
    ("D2", ["D3", "F3", "A3"]), ("D2", ["D3", "F3", "A3", "E4"]),
    ("Bb1", ["Bb2", "D3", "F3", "A3"]), ("C2", ["C3", "E3", "G3"]),
    ("D2", ["D3", "F3", "A3"]), ("D2", ["D3", "F3", "C4"]),
    ("G1", ["G2", "D3", "Bb3", "D4"]), ("A1", ["A2", "E3", "A3", "C#4"]),
]
def chord_at(bar): return CYCLE[bar % 8]

# ---------------------------------------------------------------- instruments
def saw(f0, dur, cut0, cut1, cut_t=0.15, harmonics=24, detune=0.0):
    n = int(dur * SR); t = np.arange(n) / SR
    cut = cut1 + (cut0 - cut1) * np.exp(-t / cut_t)
    out = np.zeros(n)
    for d in ((0.0,) if not detune else (-detune, detune)):
        f = f0 * 2 ** (d / 1200); ph = rng.uniform(0, 6)
        for h in range(1, harmonics + 1):
            if f * h > 9000: break
            out += (1 / h) * np.exp(-(f * h) / cut) * np.sin(2 * np.pi * f * h * t + ph * h)
    return out


def env_adsr(n, a=0.005, r=0.03):
    e = np.ones(n); ai = max(1, int(a * SR)); ri = max(1, int(r * SR))
    e[:ai] = np.linspace(0, 1, ai); e[-ri:] *= np.linspace(1, 0, ri)
    return e


def taiko(vel=1.0, pitch=1.0):
    n = int(0.6 * SR); t = np.arange(n) / SR
    f = (55 + 95 * np.exp(-t / 0.035)) * pitch
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.2)
    skin = np.sin(2 * np.pi * np.cumsum(f * 2.3) / SR) * np.exp(-t / 0.05) * 0.3
    click = rng.standard_normal(n) * np.exp(-t / 0.008) * 0.35
    click = np.convolve(click, np.ones(6) / 6, "same")
    s = body + skin + click
    s[:40] *= np.linspace(0, 1, 40)
    return np.tanh(s * 1.6) * vel


ANVIL_R = [1.0, 2.76, 5.40, 8.93]
ANVIL_T = [0.32, 0.22, 0.12, 0.06]
ANVIL_A = [1.0, 0.6, 0.35, 0.2]
def anvil(f0=880.0, vel=1.0):
    n = int(0.9 * SR); t = np.arange(n) / SR
    s = sum(a * np.exp(-t / T) * np.sin(2 * np.pi * f0 * r * t + rng.uniform(0, 6))
            for r, T, a in zip(ANVIL_R, ANVIL_T, ANVIL_A))
    hit = rng.standard_normal(n) * np.exp(-t / 0.004) * 0.6
    s = s + hit
    s[:20] *= np.linspace(0, 1, 20)
    return s * vel


_hat_base = None
def hat(vel=1.0, open_=False):
    global _hat_base
    n = int((0.18 if open_ else 0.06) * SR); t = np.arange(n) / SR
    w = rng.standard_normal(n)
    w = np.diff(np.diff(w, prepend=0), prepend=0)          # tilt it bright
    return w * np.exp(-t / (0.06 if open_ else 0.014)) * vel * 0.25


def tine(f0, length=1.2, bright=1.0):
    n = int(length * SR); t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a, T in ((1.0, 1.0, 0.5), (2.01, 0.35 * bright, 0.25), (5.4, 0.18 * bright, 0.06), (3.0, 0.1, 0.15)):
        out += a * np.exp(-t / T) * np.sin(2 * np.pi * f0 * r * t)
    out[:80] *= np.linspace(0, 1, 80)
    return out


BELL_R = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166, 5.433]
BELL_A = [0.45, 1.0, 0.55, 0.35, 0.4, 0.22, 0.18, 0.12, 0.08, 0.05]
def bell(f0, length=7.0):
    n = int(length * SR); t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a in zip(BELL_R, BELL_A):
        if f0 * r > 9000: continue
        out += a * np.exp(-t / (6.0 / r ** 0.75) * 2.5) * np.sin(2 * np.pi * f0 * r * t + rng.uniform(0, 6))
    out[:200] *= np.linspace(0, 1, 200)
    return out


def horn(f0, dur):
    """A brassy lead: saw whose brightness swells in, with a little vibrato."""
    n = int((dur + 0.25) * SR); t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    ph = 2 * np.pi * f0 * np.cumsum(vib) / SR
    cut = 500 + 2300 * (1 - np.exp(-t / 0.08)) * (0.75 + 0.25 * np.exp(-t / 0.4))
    out = np.zeros(n)
    for h in range(1, 20):
        if f0 * h > 8000: break
        out += (1 / h) * np.exp(-(f0 * h) / cut) * np.sin(h * ph)
    e = np.ones(n); a = int(0.03 * SR)
    e[:a] = np.linspace(0, 1, a)
    rel = int(dur * SR)
    e[rel:] = np.exp(-np.arange(n - rel) / SR / 0.07)
    return out * e

# ---------------------------------------------------------------- arrangement
for bar in range(BARS):
    t0 = bar * BAR
    root, chord = chord_at(bar)
    section = 0 if bar < 8 else (1 if bar < 16 else 2)
    fill = bar % 8 == 7

    # taiko
    steps = {0: 1.0, 6: 0.7, 8: 0.9, 11: 0.45}
    if section >= 1: steps[14] = 0.5
    if fill: steps.update({12: 0.6, 13: 0.7, 14: 0.8, 15: 0.95})
    for st, v in steps.items():
        s = taiko(v * (0.95 + 0.1 * rng.random()), pitch=1.0 if st in (0, 8) else 1.12)
        add(dry, s, t0 + st * S16, 0.42, rng.uniform(-0.15, 0.15))
        add(wet, s, t0 + st * S16, 0.12)

    # anvil: the forge hammering on 2 and 4
    for st, v, f in ((4, 1.0, 880), (12, 1.0, 880), (14, 0.35, 1175)):
        if st == 14 and bar % 2 == 0: continue
        s = anvil(f * (1 + rng.uniform(-0.004, 0.004)), v)
        add(dry, s, t0 + st * S16, 0.05, 0.25)
        add(wet, s, t0 + st * S16, 0.04, 0.25)

    # hats in 16ths, off-beats leaning
    for st in range(16):
        v = [0.5, 0.25, 0.9, 0.3][st % 4] * (0.8 + 0.4 * rng.random())
        if section == 0 and st % 2: continue
        s = hat(v, open_=(st == 14 and bar % 4 == 3))
        add(dry, s, t0 + st * S16, 0.32, 0.35 if st % 2 else -0.3)

    # bass: driving eighths
    r = hz(root)
    pattern = [r, r, 2 * r, r, r, 1.5 * r, r, 2 * r]
    for k, f in enumerate(pattern):
        accent = 1.0 if k in (0, 3, 6) else 0.75
        s = saw(f, BEAT / 2 * 0.92, 1500 * accent, 260, 0.06, detune=6) * env_adsr(int(BEAT / 2 * 0.92 * SR))
        add(dry, s, t0 + k * BEAT / 2, 0.16 * accent)

    # deep forge bell at each section start (the same bell as the calm track)
    if bar % 8 == 0:
        s = bell(hz("D2"), 8.0)
        add(wet, s, t0, 0.09); add(dry, s, t0, 0.06)

    # bronze arpeggio in eighths
    if section >= 1:
        notes = [hz(n) * 2 for n in chord]
        order = [0, 1, 2, 1, 3 % len(notes), 2, 1, 2]
        for k, o in enumerate(order):
            s = tine(notes[o % len(notes)], 1.0, bright=1.2)
            pan = [-0.45, 0.45][k % 2]
            add(dry, s, t0 + k * BEAT / 2, 0.05, pan)
            add(wet, s, t0 + k * BEAT / 2, 0.035, pan)

    # low brass chords, one swell per bar
    if section >= 1:
        n_len = BAR + 0.2
        for vi, note in enumerate(chord):
            s = saw(hz(note), n_len, 900, 1500, 0.6, harmonics=16, detune=8)
            e = np.minimum(1, np.arange(len(s)) / SR / 0.25)
            e *= np.clip((n_len - np.arange(len(s)) / SR) / 0.2, 0, 1)
            pan = [-0.5, 0.5, -0.2, 0.25][vi % 4]
            g = 0.035 if section == 1 else 0.04
            add(dry, s * e, t0, g, pan); add(wet, s * e, t0, g * 0.8, pan)

# the cave melody, now on a horn (bars 17-24, then again 25-32 ending up high)
q, e_, h = BEAT, BEAT / 2, BEAT * 2
MELODY = [
    [("A4", q * 1.5), ("C5", e_), ("A4", q), ("G4", q)], [("F4", q), ("E4", q), ("D4", h)],
    [("F4", q), ("G4", q), ("A4", q), ("Bb4", q)], [("C5", h), ("G4", h)],
    [("D5", q * 1.5), ("C5", e_), ("A4", q), ("C5", q)], [("D5", h), ("A4", h)],
    [("Bb4", q), ("A4", q), ("G4", q), ("F4", q)], [("G4", q), ("F4", q), ("E4", h)],
]
MELODY_2_END = [[("Bb4", q), ("C5", q), ("D5", q), ("F5", q)], [("E5", h), ("C#5", h)]]
for rep in range(2):
    bars = MELODY if rep == 0 else MELODY[:6] + MELODY_2_END
    for bi, notes in enumerate(bars):
        tt = (16 + rep * 8 + bi) * BAR
        for note, dur in notes:
            s = horn(hz(note), dur * 0.95)
            add(dry, s, tt, 0.07, -0.1); add(wet, s, tt, 0.06, -0.1)
            if rep == 1:   # second time, doubled an octave down
                s2 = horn(hz(note) / 2, dur * 0.95)
                add(dry, s2, tt, 0.04, 0.15); add(wet, s2, tt, 0.03, 0.15)
            tt += dur

# low rumble of the awake forge, the same cave air underneath everything
for c in (0, 1):
    rum = fft_filter(rng.standard_normal(N), lambda f: lowpass(110, 2)(f) * highpass(25, 2)(f))
    rum /= np.abs(rum).max()
    dry[c] += rum * 0.03

# ---------------------------------------------------------------- room (shorter than the calm cave)
def make_ir(seconds=2.6, seed=5):
    r = np.random.default_rng(seed); n = int(seconds * SR); t = np.arange(n) / SR
    irs = []
    for c in (0, 1):
        noise = r.standard_normal(n); out = np.zeros(n)
        for lo, hi, t60 in ((0, 300, 2.4), (300, 2500, 1.9), (2500, 22050, 0.8)):
            band = fft_filter(noise, lambda f, lo=lo, hi=hi: ((f >= lo) & (f < hi)).astype(float))
            out += band * np.exp(-6.91 * t / t60)
        pre = int(0.02 * SR)
        out = np.concatenate([np.zeros(pre), out[:-pre]])
        out[:pre * 2] *= np.linspace(0, 1, pre * 2)
        irs.append(out / np.sqrt(np.sum(out ** 2)))
    return irs

ir = make_ir()
rev = np.zeros((2, N))
for c in (0, 1):
    hh = np.zeros(N); hh[: len(ir[c])] = ir[c]
    rev[c] = np.fft.irfft(np.fft.rfft(wet[c]) * np.fft.rfft(hh), N)
mix = dry + rev * 0.8

for c in (0, 1):
    shelf = lambda f: 0.75 + 0.25 * f ** 2 / (f ** 2 + 110.0 ** 2)
    mix[c] = fft_filter(mix[c], lambda f: highpass(30, 2)(f) * lowpass(13000, 1)(f) * shelf(f))
mix = np.tanh(mix * 1.6) / 1.6          # a little glue
mix *= 0.89 / np.abs(mix).max()
print(f"boss: {L:.2f}s, rms {20*np.log10(np.sqrt(np.mean(mix**2))):.1f} dBFS, seam {np.abs(mix[:,0]-mix[:,-1]).max():.4f}")
pcm = (np.clip(mix.T, -1, 1) * 32767).astype("<i2")
with wave.open(f"{OUT}/cave_boss_forge_awake.wav", "wb") as wf:
    wf.setnchannels(2); wf.setsampwidth(2); wf.setframerate(SR); wf.writeframes(pcm.tobytes())
print(f"{OUT}/cave_boss_forge_awake.wav")
