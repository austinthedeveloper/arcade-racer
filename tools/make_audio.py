#!/usr/bin/env python3
"""Synthesize every sound effect and the music loop.

Original sounds, made in code so there is nothing to license: additive engines with
uneven cylinder firing, modal (struck metal and glass) crashes, resonant-filtered noise
for tires, wind and gravel, a small room reverb on the chimes and fanfares. Standard
library only, and seeded, so the same script always writes the same files. A recorded
pack can still replace any cue: drop a file with the same name (.ogg, .wav or .mp3)
next to it, see assets/audio/README.md.

Usage:
    python3 tools/make_audio.py [project_dir] [--only=crash --only=music]
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 44100
TAU = 2.0 * math.pi
rng = random.Random(1987)


# --- Building blocks -------------------------------------------------------

def silence(seconds):
    return [0.0] * int(round(seconds * RATE))


def noise(n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def pink(n, white=None):
    """Pink-ish noise (Paul Kellet's economy filter): more body than white noise. Filters
    `white` when given (loop_noise passes a repeating one)."""
    b0 = b1 = b2 = 0.0
    out = []
    for w in (noise(n) if white is None else white):
        b0 = 0.99765 * b0 + w * 0.0990460
        b1 = 0.96300 * b1 + w * 0.2965164
        b2 = 0.57000 * b2 + w * 1.0526913
        out.append((b0 + b1 + b2 + w * 0.1848) * 0.25)
    return out


def lowpass(sig, cutoff):
    """One-pole lowpass; cutoff is a number (Hz) or a list per sample."""
    out = []
    y = 0.0
    fixed = not isinstance(cutoff, list)
    a = 1.0 - math.exp(-TAU * cutoff / RATE) if fixed else 0.0
    for i, x in enumerate(sig):
        if not fixed:
            a = 1.0 - math.exp(-TAU * cutoff[i] / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    return [x - y for x, y in zip(sig, lowpass(sig, cutoff))]


def biquad(sig, kind, freq, q=0.707, gain_db=0.0):
    """RBJ biquad: kind is lowpass, highpass, bandpass or peak. freq is a number (Hz) or a
    list per sample (coefficients follow it every 16 samples)."""
    fixed = not isinstance(freq, list)

    def coeffs(f):
        f = min(max(f, 10.0), RATE * 0.45)
        w = TAU * f / RATE
        cw, sw = math.cos(w), math.sin(w)
        alpha = sw / (2.0 * q)
        if kind == "lowpass":
            b = ((1 - cw) / 2, 1 - cw, (1 - cw) / 2)
            a = (1 + alpha, -2 * cw, 1 - alpha)
        elif kind == "highpass":
            b = ((1 + cw) / 2, -(1 + cw), (1 + cw) / 2)
            a = (1 + alpha, -2 * cw, 1 - alpha)
        elif kind == "bandpass":  # constant 0 dB peak gain
            b = (alpha, 0.0, -alpha)
            a = (1 + alpha, -2 * cw, 1 - alpha)
        else:  # peak
            g = 10.0 ** (gain_db / 40.0)
            b = (1 + alpha * g, -2 * cw, 1 - alpha * g)
            a = (1 + alpha / g, -2 * cw, 1 - alpha / g)
        return b[0] / a[0], b[1] / a[0], b[2] / a[0], a[1] / a[0], a[2] / a[0]

    b0, b1, b2, a1, a2 = coeffs(freq if fixed else freq[0])
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for i, x in enumerate(sig):
        if not fixed and i % 16 == 0:
            b0, b1, b2, a1, a2 = coeffs(freq[i])
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def osc(kind, freqs, duty=0.5):
    """Oscillator with phase accumulation; freqs is a list of Hz per sample."""
    out = []
    ph = 0.0
    for f in freqs:
        if kind == "square":
            v = 1.0 if ph < duty else -1.0
        elif kind == "saw":
            v = 2.0 * ph - 1.0
        elif kind == "tri":
            v = 4.0 * ph - 1.0 if ph < 0.5 else 3.0 - 4.0 * ph
        else:
            v = math.sin(TAU * ph)
        out.append(v)
        ph = (ph + f / RATE) % 1.0
        if ph > 1.0 - 1e-9:  # rounding; keeps whole-cycle loops exact
            ph = 0.0
    return out


def tone(kind, freq, seconds, duty=0.5, to=None, vibrato=0.0, vib_rate=6.0):
    n = int(round(seconds * RATE))
    freqs = []
    for i in range(n):
        t = i / n
        f = freq if to is None else freq * (to / freq) ** t
        if vibrato:
            f *= 1.0 + vibrato * math.sin(TAU * vib_rate * i / RATE)
        freqs.append(f)
    return osc(kind, freqs, duty)


def harmonics(freq, amps, seconds, to=None, vibrato=0.0, vib_rate=5.0):
    """Additive tone: amps[k] is the level of harmonic k + 1."""
    n = int(round(seconds * RATE))
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        f = freq if to is None else freq * (to / freq) ** (i / n)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(TAU * vib_rate * i / RATE)
        out[i] = sum(a * math.sin(TAU * (k + 1) * ph) for k, a in enumerate(amps))
        ph = (ph + f / RATE) % 1.0
    return out


def fm(freq, ratio, index, seconds, index_decay=0.3):
    """Two-operator FM bell: the brightness (index) dies away faster than the note."""
    n = int(round(seconds * RATE))
    return [math.sin(TAU * freq * i / RATE
                     + index * math.exp(-i / (index_decay * RATE)) * math.sin(TAU * freq * ratio * i / RATE))
            for i in range(n)]


def modal(modes, seconds):
    """Struck object: (Hz, decay seconds, level) modes, each a decaying sine."""
    n = int(round(seconds * RATE))
    out = [0.0] * n
    for f, d, a in modes:
        ph = rng.uniform(0.0, TAU)
        w = TAU * f / RATE
        k = math.exp(-1.0 / (d * RATE))
        g = a
        for i in range(n):
            out[i] += g * math.sin(ph + w * i)
            g *= k
            if g < 1e-5:
                break
    return out


def env(sig, attack=0.005, decay=0.1, sustain=1.0, release=0.05, hold=None):
    """ADSR; hold is how long the note is held (defaults to the whole length minus release)."""
    n = len(sig)
    a, r = int(attack * RATE), int(release * RATE)
    d = int(decay * RATE)
    h = n - r if hold is None else int(hold * RATE)
    out = []
    for i, x in enumerate(sig):
        if i < a:
            g = i / max(1, a)
        elif i < a + d:
            g = 1.0 - (1.0 - sustain) * (i - a) / max(1, d)
        else:
            g = sustain
        if i >= h:
            g *= max(0.0, 1.0 - (i - h) / max(1, r))
        out.append(x * g)
    return out


def decay(sig, seconds):
    """Exponential fade with time constant `seconds`."""
    k = math.exp(-1.0 / (seconds * RATE))
    g = 1.0
    out = []
    for x in sig:
        out.append(x * g)
        g *= k
    return out


def mix(*parts):
    """Sums (signal, gain) pairs, padding to the longest."""
    n = max(len(s) for s, _ in parts)
    out = [0.0] * n
    for s, g in parts:
        for i, x in enumerate(s):
            out[i] += x * g
    return out


def concat(*sigs):
    out = []
    for s in sigs:
        out += s
    return out


def add_at(buf, sig, start, gain=1.0, wrap=False):
    for i, x in enumerate(sig):
        j = start + i
        if wrap:
            j %= len(buf)
        elif j >= len(buf):
            break
        buf[j] += x * gain


def reverb(sig, wet=0.25, size=1.0, tail=0.8):
    """A small Schroeder room: four combs into two allpasses, `tail` seconds added."""
    sig = sig + silence(tail)
    combs = [int(d * size * RATE) for d in (0.0297, 0.0371, 0.0411, 0.0437)]
    fb = 0.78
    wet_sig = [0.0] * len(sig)
    for d in combs:
        buf = [0.0] * d
        damp = 0.0
        j = 0
        for i, x in enumerate(sig):
            y = buf[j]
            damp = y * 0.6 + damp * 0.4  # high frequencies die first
            buf[j] = x + damp * fb
            wet_sig[i] += y
            j = (j + 1) % d
    for d, g in ((int(0.005 * RATE), 0.7), (int(0.0017 * RATE), 0.7)):
        buf = [0.0] * d
        j = 0
        for i, x in enumerate(wet_sig):
            y = buf[j]
            buf[j] = x + y * g
            wet_sig[i] = y - g * buf[j]
            j = (j + 1) % d
    return [x + w * wet * 0.25 for x, w in zip(sig, wet_sig)]


def finish(sig, peak=0.89):
    """Soft clip, then normalize to `peak`."""
    sig = [math.tanh(x * 1.2) for x in sig]
    m = max(abs(x) for x in sig) or 1.0
    return [x * peak / m for x in sig]


def shot(sig, fade_in=0.002, fade_out=0.01):
    """A one-shot: short fades at both ends so it starts and stops without a click."""
    a, b = int(fade_in * RATE), int(fade_out * RATE)
    for i in range(min(a, len(sig))):
        sig[i] *= i / a
    for i in range(min(b, len(sig))):
        sig[-1 - i] *= i / b
    return sig


def trim(sig, floor=0.0005):
    """Drops the silent end (a reverb tail that has died away)."""
    end = len(sig)
    while end > 1 and abs(sig[end - 1]) < floor:
        end -= 1
    return sig[:end]


def seamless(render, seconds):
    """Renders two periods of a periodic signal and keeps the second, so filters have settled
    and the end joins the start without a click. `render(n)` gets n = two periods and should
    use loop_noise(n) for noise."""
    n = int(round(seconds * RATE))
    return render(2 * n)[n:]


def loop_noise(n, color=noise):
    """Noise that repeats every n / 2 samples (one loop period). A colored noise filters the
    repeating white noise, so by the second period (the one seamless keeps) it repeats too."""
    half = noise(n // 2)
    return half + half if color is noise else color(n, half + half)


def periodic(n, hz):
    """sin(2 pi hz t) for n samples: hz a whole number per loop second keeps it seamless."""
    return [math.sin(TAU * hz * i / RATE) for i in range(n)]


def midi(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def write(path, sig):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in sig)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


# --- Loops (whole cycles of every oscillator, so they repeat cleanly) ------

def engine(base, bright, rasp=0.0):
    """One second of engine at `base` Hz (a multiple of 4, so every part loops whole); the
    game pitch-shifts it with the revs. Each firing is a harmonic-rich pulse; the cylinders
    fire a little unevenly (the base / 2 and base / 4 sway), with exhaust noise in time."""
    def render(n):
        top = 28 if bright else 18
        amps = []
        for k in range(1, top + 1):
            f = base * k
            body = 1.0 / k ** 0.7
            formant = math.exp(-((math.log(f / (350.0 + 900.0 * bright))) ** 2) / 0.5)  # the exhaust's resonance
            amps.append(body * (0.35 + formant))
        out = [0.0] * n
        for k, a in enumerate(amps):
            w = TAU * base * (k + 1) / RATE
            ph = rng.uniform(0.0, TAU)
            for i in range(n):
                out[i] += a * math.sin(ph + w * i)
        sway = [0.82 + 0.12 * math.sin(TAU * base / 2 * i / RATE) + 0.06 * math.sin(TAU * base / 4 * i / RATE + 1.3)
                for i in range(n)]
        pulse = [max(0.0, math.sin(TAU * base * i / RATE)) ** 6 for i in range(n)]  # a puff per firing
        puff = biquad(loop_noise(n), "bandpass", 700.0 + 1600.0 * bright, 0.8)
        out = [x * s + (0.9 + rasp) * p * q for x, s, p, q in zip(out, sway, pulse, puff)]
        if rasp:
            out = [x + rasp * math.tanh(3.0 * x) for x in out]
        return biquad(out, "lowpass", 1400.0 + 2600.0 * bright, 0.9)
    return finish(seamless(render, 1.0), 0.8)


def skid():
    """Tire squeal: a few close partials that flutter against each other, over hiss."""
    def render(n):
        squeal = [0.0] * n
        for f, a in ((1100.0, 1.0), (1112.0, 0.7), (1654.0, 0.35), (2209.0, 0.2)):
            add_at(squeal, periodic(n, f), 0, a)
        flutter = [0.6 + 0.25 * math.sin(TAU * 13 * i / RATE) + 0.15 * math.sin(TAU * 7 * i / RATE + 0.4)
                   for i in range(n)]
        hiss = biquad(loop_noise(n), "bandpass", 3200.0, 0.9)
        return [0.5 * s * f + 0.6 * h for s, f, h in zip(squeal, flutter, hiss)]
    return finish(seamless(render, 1.0), 0.8)


def offroad():
    """Gravel: a low rumble under stones pinging off the floor pan."""
    def render(n):
        rumble = biquad(loop_noise(n, pink), "lowpass", 180.0, 0.9)
        half = n // 2
        stones = [0.0] * half
        ping = decay(biquad(noise(int(0.012 * RATE)), "bandpass", 2400.0, 3.0), 0.003)
        for _ in range(90):
            add_at(stones, ping, rng.randrange(half), rng.uniform(0.2, 1.0), wrap=True)
        stones = stones + stones
        bumps = periodic(n, 9)
        return [(1.6 * r * (0.7 + 0.3 * b)) + 0.5 * s for r, b, s in zip(rumble, bumps, stones)]
    return finish(seamless(render, 1.0), 0.8)


def wind():
    """Wind over the car at speed: pink noise through a slowly wandering band (2 s loop)."""
    def render(n):
        sway = [1100.0 + 500.0 * math.sin(TAU * 0.5 * i / RATE) + 200.0 * math.sin(TAU * 1.5 * i / RATE)
                for i in range(n)]
        air = biquad(loop_noise(n, pink), "bandpass", sway, 0.6)
        low = biquad(loop_noise(n, pink), "lowpass", 300.0)
        gust = [0.8 + 0.2 * math.sin(TAU * 0.5 * i / RATE + 2.0) for i in range(n)]
        return [(a * 2.0 + 0.8 * l) * g for a, l, g in zip(air, low, gust)]
    return finish(seamless(render, 2.0), 0.8)


def draft():
    """In a car's slipstream: low buffeting air, pulsing as the wake rolls over the nose."""
    def render(n):
        air = biquad(loop_noise(n, pink), "lowpass", 420.0, 1.2)
        buffet = [0.55 + 0.45 * math.sin(TAU * 9 * i / RATE) ** 2 for i in range(n)]
        whistle = [0.04 * math.sin(TAU * 660 * i / RATE) for i in range(n)]
        return [1.5 * a * b + w for a, b, w in zip(air, buffet, whistle)]
    return finish(seamless(render, 1.0), 0.8)


def horn():
    """A car horn, held: two reedy notes a third apart (370 and 466 Hz), honk-filtered."""
    def render(n):
        a = osc("saw", [370.0] * n)
        b = osc("saw", [466.0] * n)
        raw = [math.tanh(2.5 * (x + y)) for x, y in zip(a, b)]
        body = biquad(raw, "peak", 2100.0, 1.5, 9.0)
        return biquad(body, "lowpass", 3800.0)
    return finish(seamless(render, 1.0), 0.8)


# --- One-shots -------------------------------------------------------------

def nitro():
    """Nitro: a pop, then a jet roar sweeping up with a turbine whine."""
    n = int(1.5 * RATE)
    pop = decay(mix((biquad(noise(int(0.08 * RATE)), "lowpass", 1800.0), 1.0),
                    (tone("sine", 70.0, 0.08, to=40.0), 1.0)), 0.025)
    sweep = [400.0 + 2800.0 * (i / n) ** 0.6 for i in range(n)]
    roar = biquad(pink(n), "bandpass", sweep, 1.6)
    whine = biquad(tone("saw", 320.0, 1.5, to=1250.0), "lowpass", 2600.0)
    body = env(mix((roar, 3.0), (whine, 0.18)), attack=0.06, decay=0.4, sustain=0.75, release=0.7)
    out = silence(1.6)
    add_at(out, pop, 0, 1.2)
    add_at(out, body, int(0.03 * RATE))
    return shot(finish(out))


def crash():
    """Crash: a thump, crumpling panels (inharmonic struck metal), scraping, and glass."""
    n = int(1.4 * RATE)
    cut = [7000.0 * math.exp(-i / (0.2 * RATE)) + 250.0 for i in range(n)]
    crunch = decay(biquad(noise(n), "lowpass", cut, 0.8), 0.3)
    thump = decay(tone("sine", 95.0, 1.4, to=32.0), 0.18)
    metal = modal([(187.0, 0.35, 0.6), (311.0, 0.28, 0.5), (523.0, 0.22, 0.45), (787.0, 0.18, 0.4),
                   (1103.0, 0.14, 0.3), (1597.0, 0.1, 0.25), (2213.0, 0.08, 0.2), (2931.0, 0.06, 0.15)], 1.4)
    scrape = decay(biquad(noise(n), "bandpass", 1500.0, 2.0), 0.45)
    glass = [0.0] * n
    for _ in range(26):
        f = rng.uniform(3200.0, 7800.0)
        add_at(glass, modal([(f, rng.uniform(0.02, 0.07), 1.0), (f * 1.47, 0.02, 0.5)], 0.15),
               int(rng.uniform(0.03, 0.55) * RATE), rng.uniform(0.15, 0.5))
    out = mix((crunch, 1.0), (thump, 1.4), (metal, 0.9), (scrape, 0.6), (glass, 0.5))
    return shot(finish(reverb(out, 0.2, 0.8, 0.4)))


def bump():
    """A nudge: a dull thud and a short panel knock."""
    thump = decay(tone("sine", 115.0, 0.3, to=55.0), 0.05)
    panel = modal([(240.0, 0.06, 0.6), (410.0, 0.04, 0.4), (730.0, 0.025, 0.2)], 0.3)
    click = decay(biquad(noise(int(0.3 * RATE)), "lowpass", 2600.0), 0.012)
    return shot(finish(mix((thump, 1.0), (panel, 0.7), (click, 0.5))))


def land():
    """Touching down: a heavy thump, the springs taking it, and a scuff of grit."""
    thump = decay(tone("sine", 72.0, 0.45, to=36.0), 0.09)
    springs = decay(biquad(tone("saw", 140.0, 0.45, to=95.0), "bandpass", 600.0, 4.0), 0.12)
    scuff = decay(biquad(noise(int(0.45 * RATE)), "bandpass", 1600.0, 1.0), 0.05)
    return shot(finish(mix((thump, 1.0), (springs, 0.4), (scuff, 0.45))))


def beep():
    """Countdown 3, 2, 1: a clean arcade tone with a touch of room."""
    note = env(harmonics(880.0, [1.0, 0.0, 0.33, 0.0, 0.2], 0.22), attack=0.003, decay=0.05, sustain=0.7,
               release=0.05)
    return shot(finish(trim(reverb(note, 0.3, 1.0, 0.35))))


def go():
    """GO: an octave higher, a bright fifth on top, held longer."""
    a = harmonics(1760.0, [1.0, 0.0, 0.3, 0.0, 0.15], 0.6, vibrato=0.004)
    b = harmonics(2637.0, [1.0, 0.0, 0.2], 0.6, vibrato=0.004)
    note = env(mix((a, 1.0), (b, 0.35)), attack=0.004, decay=0.1, sustain=0.75, release=0.25)
    return shot(finish(trim(reverb(note, 0.35, 1.0, 0.6))))


def tick():
    """The low clock: a woodblock knock."""
    knock = modal([(1800.0, 0.03, 1.0), (2750.0, 0.018, 0.5), (4100.0, 0.01, 0.25)], 0.1)
    return shot(finish(knock, 0.7))


def checkpoint():
    """Checkpoint: a rising four-note bell arpeggio."""
    out = silence(0.9)
    for k, note in enumerate((84, 88, 91, 96)):
        bell = decay(fm(midi(note), 2.0, 1.8, 0.8, 0.12), 0.25)
        add_at(out, bell, int(k * 0.07 * RATE), 0.8)
    return shot(finish(trim(reverb(out, 0.3, 1.0, 0.7))))


def brass(note, seconds, swell=0.05):
    """A brass note: saw harmonics behind a filter that opens as the note swells."""
    n = int(round(seconds * RATE))
    raw = harmonics(midi(note), [1.0 / k for k in range(1, 12)], seconds, vibrato=0.004, vib_rate=5.5)
    cut = [600.0 + 3400.0 * min(1.0, i / (swell * 4 * RATE + 1)) for i in range(n)]
    return env(biquad(raw, "lowpass", cut, 1.0), attack=swell, decay=0.15, sustain=0.75, release=0.12)


def finish_fanfare():
    """The finish: three brass pickups into a held major chord over a timpani roll."""
    out = silence(2.4)
    for k, note in enumerate((67, 72, 76)):
        add_at(out, brass(note, 0.14, 0.01), int(k * 0.15 * RATE), 0.7)
    for note in (72, 76, 79, 84):
        add_at(out, brass(note, 1.8, 0.04), int(0.45 * RATE), 0.45)
    timp = [0.0] * int(1.0 * RATE)
    for k in range(14):
        add_at(timp, modal([(98.0, 0.4, 1.0), (147.0, 0.25, 0.4)], 0.5), int(k * 0.045 * RATE), 0.15 + k * 0.03)
    add_at(out, timp, int(0.2 * RATE), 0.8)
    add_at(out, modal([(65.0, 0.9, 1.0), (98.0, 0.5, 0.5)], 1.6), int(0.45 * RATE), 1.0)
    return shot(finish(trim(reverb(out, 0.3, 1.2, 1.0))))


def time_up():
    """Time up: three falling brass notes and a low thud under the last."""
    out = silence(1.6)
    for k, (a, b) in enumerate(((67, 66), (64, 63), (60, 55))):
        length = 0.3 if k < 2 else 0.85
        n = brass(a, length, 0.01)
        if a != b:  # bend down
            bend = harmonics(midi(a), [1.0 / k2 for k2 in range(1, 10)], length, to=midi(b))
            n = env(biquad(bend, "lowpass", 2200.0), attack=0.01, decay=0.1, sustain=0.7, release=0.1)
        add_at(out, n, int(k * 0.32 * RATE), 0.7)
    add_at(out, decay(tone("sine", 60.0, 0.8, to=40.0), 0.2), int(0.64 * RATE), 0.8)
    return shot(finish(trim(reverb(out, 0.3, 1.1, 0.8))))


def whoosh():
    """Passing a car: a rush of air falling in pitch (the doppler drop) with its engine hum."""
    seconds = 0.7
    n = int(seconds * RATE)
    sweep = [3800.0 * (0.25 ** (i / n)) for i in range(n)]
    air = biquad(pink(n), "bandpass", sweep, 1.2)
    hum = biquad(tone("saw", 210.0, seconds, to=150.0), "lowpass", 700.0)
    bell = [math.sin(math.pi * min(1.0, (i / n) / 0.85)) ** 1.5 for i in range(n)]
    return shot(finish([(2.5 * a + 0.25 * h) * b for a, h, b in zip(air, hum, bell)]), fade_out=0.05)


def draft_boost():
    """The slipstream boost kicks in: a short rising rush."""
    n = int(0.8 * RATE)
    sweep = [500.0 * (6.0 ** (i / n)) for i in range(n)]
    rush = biquad(pink(n), "bandpass", sweep, 1.4)
    return shot(finish(env(rush, attack=0.05, decay=0.3, sustain=0.6, release=0.35)))


def pickup_nitro():
    """Nitro canister: a fizzing ignition and a quick rising arpeggio."""
    out = silence(0.7)
    for k, note in enumerate((79, 83, 86, 91, 95)):
        add_at(out, decay(fm(midi(note), 2.0, 1.5, 0.25, 0.05), 0.08), int(k * 0.04 * RATE), 0.6)
    fizz = decay(biquad(noise(int(0.5 * RATE)), "highpass", 5000.0), 0.12)
    add_at(out, fizz, 0, 0.5)
    return shot(finish(trim(reverb(out, 0.25, 0.9, 0.4))))


def pickup_clock():
    """Extra seconds: two clock ticks and a bright bell."""
    out = silence(0.9)
    knock = modal([(2200.0, 0.02, 1.0), (3300.0, 0.012, 0.5)], 0.06)
    add_at(out, knock, 0, 0.7)
    add_at(out, knock, int(0.09 * RATE), 0.7)
    add_at(out, decay(fm(midi(96), 1.4, 3.0, 0.7, 0.1), 0.3), int(0.18 * RATE), 0.9)
    return shot(finish(trim(reverb(out, 0.3, 1.0, 0.5))))


def pickup_ram():
    """Ram plate: a heavy metal clang and a growl under it."""
    clang = modal([(130.0, 0.6, 1.0), (347.0, 0.4, 0.7), (612.0, 0.3, 0.5), (1210.0, 0.15, 0.3),
                   (1847.0, 0.08, 0.2)], 1.0)
    growl = env(biquad(tone("saw", 82.0, 0.6, to=110.0), "lowpass", 600.0), attack=0.02, decay=0.2,
                sustain=0.6, release=0.2)
    return shot(finish(trim(reverb(mix((clang, 1.0), (growl, 0.5)), 0.25, 1.0, 0.4))))


def pickup_ghost():
    """Ghost: a hollow, wavering glide up and away."""
    seconds = 1.0
    a = tone("sine", midi(72), seconds, to=midi(84), vibrato=0.02, vib_rate=7.0)
    b = tone("sine", midi(72) * 1.007, seconds, to=midi(84) * 1.007, vibrato=0.02, vib_rate=6.3)
    air = biquad(pink(int(seconds * RATE)), "bandpass", 1800.0, 2.0)
    out = env(mix((a, 0.6), (b, 0.6), (air, 0.8)), attack=0.08, decay=0.3, sustain=0.6, release=0.4)
    return shot(finish(trim(reverb(out, 0.45, 1.3, 0.8))))


def crowd():
    """The crowd at the finish line: a roar that swells and dies away, with clapping and a
    few whistles. Loud on purpose (the cue is mixed hot in SoundBank)."""
    seconds = 4.0
    n = int(seconds * RATE)
    # Roar: many voices, as band-limited noise in two formant bands, wobbling and swelling
    roar = biquad(pink(n), "bandpass", 700.0, 0.7)
    voices = biquad(pink(n), "bandpass", 1500.0, 1.2)
    wobble = [1.0 + 0.25 * math.sin(TAU * 3.1 * i / RATE) * math.sin(TAU * 0.7 * i / RATE)
              for i in range(n)]
    swell = [min(1.0, i / (0.35 * RATE)) * min(1.0, (n - i) / (1.8 * RATE)) for i in range(n)]
    out = [(2.0 * r + 1.4 * v) * w * s for r, v, w, s in zip(roar, voices, wobble, swell)]
    # Clapping: short bright bursts scattered through the swell
    clap = decay(biquad(noise(int(0.03 * RATE)), "bandpass", 1600.0, 1.2), 0.006)
    for k in range(160):
        t = rng.uniform(0.15, seconds - 1.2)
        add_at(out, clap, int(t * RATE), rng.uniform(0.5, 1.2) * swell[int(t * RATE)])
    # Whistles: a few rising-then-falling sine glides
    for t, f in ((0.4, 1900.0), (1.1, 2300.0), (1.9, 2100.0)):
        up = tone("sine", f, 0.18, to=f * 1.35, vibrato=0.01)
        down = tone("sine", f * 1.35, 0.3, to=f * 1.1, vibrato=0.01)
        add_at(out, env(concat(up, down), attack=0.02, decay=0.1, sustain=0.8, release=0.1), int(t * RATE), 0.35)
    return shot(finish(out), fade_out=0.2)


def thunder():
    """Thunder a beat after the lightning: a sharp crack, then a low rumble that rolls and
    dies away over a few seconds."""
    seconds = 3.5
    n = int(seconds * RATE)
    crack = decay(biquad(noise(n), "bandpass", 2500.0, 0.6), 0.07)
    rumble = biquad(biquad(pink(n), "lowpass", 140.0, 0.9), "lowpass", 200.0)
    roll = [min(1.0, i / (0.25 * RATE)) * math.exp(-i / (1.1 * RATE))
            * (0.7 + 0.3 * math.sin(TAU * 1.7 * i / RATE) * math.sin(TAU * 0.6 * i / RATE)) for i in range(n)]
    out = [r * g for r, g in zip(rumble, roll)]
    return shot(finish(reverb(mix((crack, 0.5), (out, 4.0)), 0.3, 1.6, 0.0)), fade_out=0.3)


# --- Music -----------------------------------------------------------------

BPM = 128
EIGHTH = 60.0 / BPM / 2  # seconds

# vi-IV-I-V in C, one bar each, played twice: (bass root, arpeggio notes)
CHORDS = [(45, (69, 72, 76)), (41, (65, 69, 72)), (48, (67, 72, 76)), (43, (67, 71, 74))] * 2
# Lead, (note or None, length in eighths); 8 eighths per bar.
LEAD = [
    (76, 2), (81, 2), (79, 1), (76, 2), (74, 1),
    (72, 2), (74, 1), (76, 3), (None, 2),
    (76, 1), (79, 2), (84, 2), (83, 1), (79, 2),
    (79, 3), (74, 1), (71, 2), (74, 2),
    (76, 2), (81, 2), (83, 1), (84, 2), (83, 1),
    (81, 2), (77, 1), (81, 3), (84, 2),
    (84, 2), (83, 1), (79, 2), (76, 1), (79, 2),
    (83, 4), (86, 2), (None, 2),
]


def music_race():
    bars = len(CHORDS)
    n = int(round(bars * 8 * EIGHTH * RATE))
    step = lambda k: int(round(k * EIGHTH * RATE))  # eighth k -> sample
    bass, arp, lead, drums = [0.0] * n, [0.0] * n, [0.0] * n, [0.0] * n

    kick = decay(tone("sine", 140.0, 0.25, to=45.0), 0.07)
    snare = mix((decay(highpass(noise(int(0.2 * RATE)), 1500.0), 0.06), 1.0),
                (decay(tone("tri", 190.0, 0.2), 0.04), 0.6))
    hat = decay(highpass(noise(int(0.05 * RATE)), 6000.0), 0.012)

    for bar, (root, chord) in enumerate(CHORDS):
        b0 = bar * 8
        for e in range(8):
            note = root + (12 if e % 2 else 0)
            add_at(bass, env(tone("square", midi(note), EIGHTH * 0.9), decay=0.08, sustain=0.5,
                             release=0.03), step(b0 + e), wrap=True)
            add_at(drums, hat, step(b0 + e), 0.35 if e % 2 else 0.2, wrap=True)
        for s in range(16):  # sixteenth-note arpeggio
            note = chord[s % 3] + (12 if (s // 3) % 2 else 0)
            add_at(arp, env(tone("square", midi(note), EIGHTH / 2, duty=0.125), decay=0.03,
                            sustain=0.3, release=0.02), step(b0 + s / 2), wrap=True)
        for e in (0, 3, 4):
            add_at(drums, kick, step(b0 + e), 1.0, wrap=True)
        for e in (2, 6):
            add_at(drums, snare, step(b0 + e), 0.7, wrap=True)
        if bar % 4 == 3:
            add_at(drums, snare, step(b0 + 7), 0.4, wrap=True)
            add_at(drums, snare, step(b0 + 7.5), 0.5, wrap=True)

    e = 0
    for note, length in LEAD:
        if note is not None:
            dur = length * EIGHTH
            add_at(lead, env(tone("square", midi(note), dur, duty=0.25, vibrato=0.008 if length > 1 else 0.0),
                             attack=0.004, decay=0.06, sustain=0.75, release=0.05), step(e), wrap=True)
        e += length

    bass = lowpass(bass, 1200.0)
    lead = lowpass(lead, 4000.0)
    out = [0.0] * n
    for i in range(n):
        out[i] = 0.55 * bass[i] + 0.18 * arp[i] + 0.35 * lead[i] + 0.6 * drums[i]
    return finish(out, 0.85)


FILES = {
    "sfx/engine_low.wav": lambda: engine(56.0, 0.0),
    "sfx/engine_high.wav": lambda: engine(112.0, 1.0),
    "sfx/rival.wav": lambda: engine(84.0, 0.6, rasp=0.4),
    "sfx/skid.wav": skid,
    "sfx/offroad.wav": offroad,
    "sfx/wind.wav": wind,
    "sfx/draft.wav": draft,
    "sfx/horn.wav": horn,
    "sfx/nitro.wav": nitro,
    "sfx/crash.wav": crash,
    "sfx/bump.wav": bump,
    "sfx/land.wav": land,
    "sfx/beep.wav": beep,
    "sfx/go.wav": go,
    "sfx/tick.wav": tick,
    "sfx/checkpoint.wav": checkpoint,
    "sfx/finish.wav": finish_fanfare,
    "sfx/time_up.wav": time_up,
    "sfx/whoosh.wav": whoosh,
    "sfx/draft_boost.wav": draft_boost,
    "sfx/pickup_nitro.wav": pickup_nitro,
    "sfx/pickup_clock.wav": pickup_clock,
    "sfx/pickup_ram.wav": pickup_ram,
    "sfx/pickup_ghost.wav": pickup_ghost,
    "sfx/crowd.wav": crowd,
    "sfx/thunder.wav": thunder,
    "music/music_race.wav": music_race,
}


def rms_db(sig):
    return 20.0 * math.log10(math.sqrt(sum(x * x for x in sig) / max(1, len(sig))) or 1e-9)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--only=")]
    project = args[0] if args else os.path.join(os.path.dirname(__file__), "..")
    for name, make in FILES.items():
        sig = make()  # every sound, in order, so the shared random stream gives the same files
        if only and not any(o in name for o in only):
            continue
        path = os.path.join(project, "assets", "audio", name)
        write(path, sig)
        print("wrote %s (%.2f s, %.1f dB RMS)" % (os.path.relpath(path, project), len(sig) / RATE, rms_db(sig)))


if __name__ == "__main__":
    main()
