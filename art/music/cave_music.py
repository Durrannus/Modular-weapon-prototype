"""Tutorial cave atmosphere music, synthesised from scratch with numpy.

Everything is built on a circular timeline of exactly L seconds: notes that ring
past the end wrap round to the start, noise is filtered with FFTs over the whole
loop and the reverb is a circular convolution, so the file loops with no seam.

usage: python3 cave_music.py A|B out_dir
  A  "Sleeping Forge"  darker: drone, bronze bells, drips, one lonely melody
  B  "Tide and Ember"  warmer: adds slow bronze-tine arpeggios, more melody, more sea
"""
import sys, wave
import numpy as np

SR = 44100
VAR = sys.argv[1] if len(sys.argv) > 1 else "A"
OUT = sys.argv[2] if len(sys.argv) > 2 else "."
CHORD_LEN = 16.0
L = 8 * CHORD_LEN                     # 128 s loop
N = int(SR * L)
rng = np.random.default_rng({"A": 7, "B": 11, "M": 13}[VAR])
t_all = np.arange(N) / SR


def hz(note):
    """'D3' / 'Bb2' / 'C#4' -> Hz."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[note[0]]
    rest = note[1:]
    if rest[0] == "b":
        n -= 1; rest = rest[1:]
    elif rest[0] == "#":
        n += 1; rest = rest[1:]
    midi = 12 * (int(rest) + 1) + n
    return 440.0 * 2 ** ((midi - 69) / 12)


def loopq(f):
    """Nudge a frequency so it fits a whole number of cycles in the loop."""
    return round(f * L) / L


def lfo(cycles, phase=0.0):
    """A slow sine that repeats a whole number of times per loop (0..1)."""
    return 0.5 + 0.5 * np.sin(2 * np.pi * cycles * t_all / L + phase)


def add(buf, sig, start_s, gain=1.0, pan=0.0):
    """Mix a mono signal into a stereo circular buffer, wrapping at the end."""
    s0 = int(round(start_s * SR)) % N
    idx = (s0 + np.arange(len(sig))) % N
    gl = np.cos((pan + 1) * np.pi / 4) * gain
    gr = np.sin((pan + 1) * np.pi / 4) * gain
    buf[0][idx] += sig * gl          # signals are always shorter than the loop
    buf[1][idx] += sig * gr


def fft_filter(x, shape):
    """Filter a full-loop signal circularly. shape(freqs) -> gain."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * shape(f), len(x))


def lowpass(fc, order=2):
    return lambda f: 1 / np.sqrt(1 + (f / fc) ** (2 * order))


def highpass(fc, order=2):
    return lambda f: 1 / np.sqrt(1 + (fc / np.maximum(f, 1e-6)) ** (2 * order))


def raised_env(n, att, rel):
    e = np.ones(n)
    a = min(int(att * SR), n // 2)
    r = min(int(rel * SR), n // 2)
    if a:
        e[:a] = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    if r:
        e[-r:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, r))
    return e


dry = np.zeros((2, N))   # goes out mostly as is
wet = np.zeros((2, N))   # goes through the cave reverb

# ---------------------------------------------------------------- harmony
CHORDS = [
    ["D3", "A3", "E4", "F4"],      # Dm9
    ["Bb2", "F3", "A3", "D4"],     # Bbmaj7
    ["G2", "D3", "A3", "Bb3"],     # Gm9
    ["A2", "E3", "G3", "D4"],      # A7sus4
    ["D3", "F3", "C4", "E4"],      # Dm9
    ["C3", "F3", "A3", "E4"],      # Fmaj7/C
    ["Bb2", "D3", "A3", "C4"],     # Bbmaj9
    ["A2", "E3", "A3", "C#4"],     # A major: the old, uneasy turn back home
]

# brightness of the pads rises and falls twice per loop
bright = 380 + 520 * lfo(2, -np.pi / 2) * (0.7 + 0.3 * lfo(3))

# ---------------------------------------------------------------- pads
def pad_voice(f0, dur, cut_slice, detune_cents=7.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for d in (-detune_cents, 0.0, detune_cents):
        f = f0 * 2 ** (d / 1200)
        ph = rng.uniform(0, 2 * np.pi)
        vib = 0.0015 * np.sin(2 * np.pi * rng.uniform(0.08, 0.17) * t + rng.uniform(0, 6))
        phase_base = 2 * np.pi * f * (t + np.cumsum(vib) / SR)
        for h in range(1, 18):
            if f * h > 5000:
                break
            amp = (1 / h) * np.exp(-(f * h) / cut_slice)
            if amp.max() < 0.003:
                break
            out += amp * np.sin(h * phase_base + ph * h)
    return out / 3


for ci, chord in enumerate(CHORDS):
    start = ci * CHORD_LEN - 4.0
    dur = CHORD_LEN + 9.0
    n = int(dur * SR)
    idx = (int(start * SR) + np.arange(n)) % N
    cut = bright[idx]
    env = raised_env(n, 6.0, 7.0)
    for vi, note in enumerate(chord):
        f = hz(note)
        sig = pad_voice(f, dur, cut * (1.0 if vi else 0.8)) * env
        pan = [-0.45, 0.35, -0.2, 0.5][vi]
        g = 0.085 if vi else 0.09
        add(dry, sig, start, g * 0.55, pan)
        add(wet, sig, start, g * 0.8, pan)

# ---------------------------------------------------------------- drone (D pedal)
d1 = loopq(hz("D1"))
d2 = loopq(hz("D2"))
breathe = 0.65 + 0.35 * lfo(4, 1.0)
drone = (np.sin(2 * np.pi * d1 * t_all) * 0.16
         + np.sin(2 * np.pi * d2 * t_all) * 0.35 * breathe
         + np.sin(2 * np.pi * loopq(d2 * 1.5) * t_all) * 0.06 * lfo(3, 2.0)
         + np.sin(2 * np.pi * loopq(d2 * 2.0 + 0.25) * t_all) * 0.08 * lfo(5, 0.3))
drone *= 0.13
for c in (0, 1):
    dry[c] += drone
    wet[c] += drone * 0.15

# ---------------------------------------------------------------- bronze bells
BELL_R = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166, 5.433]
BELL_A = [0.45, 1.0, 0.55, 0.35, 0.4, 0.22, 0.18, 0.12, 0.08, 0.05]


def bell(f0, length=9.0, soft=0.006):
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a in zip(BELL_R, BELL_A):
        f = f0 * r
        if f > 9000:
            continue
        T = 7.5 / r ** 0.75
        beat = 1 + 0.3 * np.sin(2 * np.pi * rng.uniform(0.3, 1.2) * t)
        out += a * np.exp(-t / T * 2.5) * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * beat
    att = int(soft * SR)
    out[:att] *= np.linspace(0, 1, att)
    return out


bell_times = []
tt = 3.0
while tt < L - 1:
    bell_times.append(tt)
    tt += {"A": rng.uniform(5.5, 11.0), "B": rng.uniform(7.0, 13.0), "M": rng.uniform(6.5, 12.0)}[VAR]
for bt in bell_times:
    chord = CHORDS[int(bt // CHORD_LEN) % 8]
    note = chord[rng.integers(1, 4)]
    f = hz(note) * (2 if rng.random() < 0.6 else 4)
    if f > 1400:
        f /= 2
    g = rng.uniform(0.022, 0.04)
    pan = rng.uniform(-0.8, 0.8)
    s = bell(f)
    add(wet, s, bt, g, pan)
    add(dry, s, bt, g * 0.25, pan)

# one deep struck bronze, the sleeping forge itself, twice a loop
for bt in (0.5, L / 2 + 0.5):
    s = bell(hz("D2"), length=16.0, soft=0.03)
    add(wet, s, bt, 0.06, 0.0)
    add(dry, s, bt, 0.03, 0.0)

# ---------------------------------------------------------------- lonely melody
def glass(f0, dur, gain=1.0):
    n = int((dur + 1.6) * SR)
    t = np.arange(n) / SR
    vib_depth = 0.004 * np.clip(t / 1.2, 0, 1)
    ph = 2 * np.pi * f0 * (t + np.cumsum(vib_depth * np.sin(2 * np.pi * 4.6 * t)) / SR)
    s = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.07 * np.sin(3 * ph) + 0.03 * np.sin(5 * ph)
    breath = np.convolve(rng.standard_normal(n), np.ones(40) / 40, "same") * 0.05
    env = np.ones(n)
    a = int(0.35 * SR)
    env[:a] = np.linspace(0, 1, a) ** 1.5
    rel_start = int(dur * SR)
    env[rel_start:] = np.exp(-np.arange(n - rel_start) / SR / 0.4)
    env *= 1 - 0.15 * (t / (dur + 1.6))
    return (s + breath * s) * env * gain


PHRASE_1 = [("A4", 2.0), ("C5", 1.0), ("A4", 1.0), ("G4", 2.0), ("F4", 1.5), ("E4", 1.5), ("D4", 4.0)]
PHRASE_2 = [("F4", 1.5), ("E4", 1.0), ("D4", 1.5), ("C4", 2.0), ("D4", 1.5), ("E4", 1.0), ("A3", 4.5)]
PHRASE_3 = [("D5", 2.0), ("C5", 1.0), ("A4", 2.0), ("F4", 1.5), ("G4", 1.0), ("E4", 4.0)]
phrases = [(33.0, PHRASE_1), (97.0, PHRASE_2)]
if VAR in ("B", "M"):
    phrases += [(65.0, PHRASE_3)]
for start, phrase in phrases:
    tt = start
    for note, dur in phrase:
        s = glass(hz(note), dur * 1.15)
        add(wet, s, tt, 0.05, -0.15)
        add(dry, s, tt, 0.028, -0.15)
        tt += dur * 1.15

# ---------------------------------------------------------------- bronze tines (B only)
def tine(f0, length=4.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a, T in ((1.0, 1.0, 1.6), (2.01, 0.25, 0.7), (5.4, 0.12, 0.15), (3.0, 0.08, 0.4)):
        out += a * np.exp(-t / T) * np.sin(2 * np.pi * f0 * r * t)
    out[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    return out


if VAR in ("B", "M"):
    for ci, chord in enumerate(CHORDS):
        base = ci * CHORD_LEN
        notes = [hz(n) * 2 for n in chord]
        pattern = [0, 2, 1, 3, 2, 1] if ci % 2 == 0 else [3, 1, 2, 0]
        if VAR == "M":   # the mix: plucks a little sparser, and silent under the melodies
            if ci in (2, 4, 6):
                continue
            pattern = [0, 2, 1, 3] if ci % 2 == 0 else [3, 1, 2]
        step = 1.35
        for k, p in enumerate(pattern):
            tt = base + 1.5 + k * step + rng.uniform(-0.04, 0.04)
            s = tine(notes[p])
            pan = -0.5 + p * 0.33
            g = 0.03 * (0.85 + 0.3 * rng.random()) * (1 - 0.06 * k)
            add(wet, s, tt, g, pan)
            add(dry, s, tt, g * 0.5, pan)

# ---------------------------------------------------------------- water drips
n_drips = {"A": 46, "B": 36, "M": 40}[VAR]
for _ in range(n_drips):
    dt = rng.uniform(0, L)
    f0 = rng.uniform(1300, 2800)
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + 0.9 * (1 - np.exp(-t / 0.012)))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / rng.uniform(0.02, 0.045))
    s[:30] *= np.linspace(0, 1, 30)
    g = rng.uniform(0.012, 0.035)
    pan = rng.uniform(-0.9, 0.9)
    add(wet, s, dt, g * 1.4, pan)
    add(dry, s, dt, g * 0.5, pan)
    if rng.random() < 0.35:           # the same drop again, from the same spot
        add(wet, s * 0.8, dt + rng.uniform(0.6, 1.1), g, pan)

# ---------------------------------------------------------------- sea and cave air
sea_amt = {"A": 1.0, "B": 1.6, "M": 1.3}[VAR]
for c in (0, 1):
    w = rng.standard_normal(N)
    rumble = fft_filter(w, lambda f: lowpass(140, 2)(f) * highpass(25, 2)(f))
    rumble /= np.abs(rumble).max()
    surf = fft_filter(rng.standard_normal(N), lambda f: np.exp(-((np.log(np.maximum(f, 1) / 520)) ** 2) / 0.5))
    surf /= np.abs(surf).max()
    swell = lfo(12, c * 0.4) ** 2.2 * (0.6 + 0.4 * lfo(5, 1.3))
    air = rumble * 0.045 * (0.7 + 0.3 * lfo(4)) + surf * 0.05 * swell * sea_amt
    dry[c] += air * 0.75
    wet[c] += air * 0.35

# resonant metal: noise ringing at the forge's bell partials, swelling twice a loop
f_base = hz("D2")
def resonances(f):
    g = np.zeros_like(f)
    for r, a in zip(BELL_R[:8], BELL_A[:8]):
        fc = f_base * r * 2
        g += a * np.exp(-((f - fc) / (fc * 0.004)) ** 2)
    return g
hum = fft_filter(rng.standard_normal(N), resonances)
hum /= np.abs(hum).max()
hum *= 0.05 * lfo(2, np.pi) ** 2
for c in (0, 1):
    wet[c] += hum * (1 if c == 0 else 0.9)
    dry[c] += hum * 0.3

# the forge's slow heartbeat: a soft low thump, lub-dub, every 8 seconds (A only)
if VAR in ("A", "M"):
    for k in range(int(L // 8)):
        for off, g in ((0.0, 1.0), (0.32, 0.6)):
            n = int(0.5 * SR)
            t = np.arange(n) / SR
            s = np.sin(2 * np.pi * (42 + 30 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.12)
            s[:60] *= np.linspace(0, 1, 60)
            gg = 0.05 * g * (0.5 + 0.5 * np.cos(2 * np.pi * k * 8 / L * 2))
            add(dry, s, k * 8 + 6.0 + off, gg, 0.0)

# ---------------------------------------------------------------- cave reverb
def make_ir(seconds=5.0, seed=3):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    irs = []
    for c in (0, 1):
        noise = r.standard_normal(n)
        out = np.zeros(n)
        # three bands, each with its own decay: lows ring longest, highs die fast
        for lo, hi, t60 in ((0, 300, 5.2), (300, 2500, 3.8), (2500, 22050, 1.4)):
            band = fft_filter(noise, lambda f, lo=lo, hi=hi: ((f >= lo) & (f < hi)).astype(float))
            out += band * np.exp(-6.91 * t / t60)
        pre = int(0.035 * SR)
        out = np.concatenate([np.zeros(pre), out[:-pre]])
        out[:pre * 2] *= np.linspace(0, 1, pre * 2)
        for d, g in ((0.011, 0.5), (0.023, 0.35), (0.041, 0.3), (0.067, 0.2)):   # early rock reflections
            out[int((d + c * 0.004) * SR)] += g * 8
        irs.append(out / np.sqrt(np.sum(out ** 2)))
    return irs


ir = make_ir()
rev = np.zeros((2, N))
for c in (0, 1):
    h = np.zeros(N)
    h[: len(ir[c])] = ir[c]
    rev[c] = np.fft.irfft(np.fft.rfft(wet[c]) * np.fft.rfft(h), N)   # circular, so it loops
rev *= 1.0

mix = dry + rev * 0.9

# ---------------------------------------------------------------- master
for c in (0, 1):
    shelf = lambda f: 0.62 + 0.38 * f ** 2 / (f ** 2 + 130.0 ** 2)      # about -4 dB under 100 Hz
    mix[c] = fft_filter(mix[c], lambda f: highpass(28, 2)(f) * lowpass(11000, 1)(f) * shelf(f))
mix = np.tanh(mix * 1.1) / 1.1
peak = np.abs(mix).max()
mix *= 0.89 / peak
rms_db = 20 * np.log10(np.sqrt(np.mean(mix ** 2)))
seam = np.abs(mix[:, 0] - mix[:, -1]).max()
step = np.abs(np.diff(mix, axis=1)).max()
print(f"variant {VAR}: {L:.0f}s, rms {rms_db:.1f} dBFS, seam jump {seam:.4f} (largest normal step {step:.4f})")

pcm = (np.clip(mix.T, -1, 1) * 32767).astype("<i2")
name = {"A": "cave_sleeping_forge", "B": "cave_tide_and_ember", "M": "cave_calm"}[VAR]
with wave.open(f"{OUT}/{name}.wav", "wb") as wf:
    wf.setnchannels(2); wf.setsampwidth(2); wf.setframerate(SR)
    wf.writeframes(pcm.tobytes())
print(f"{OUT}/{name}.wav")
