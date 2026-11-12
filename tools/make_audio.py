#!/usr/bin/env python3
"""Synthesize every sound effect and the music loop.

Original sounds, made in code so there is nothing to license: additive engines with
uneven cylinder firing, modal (struck metal and glass) crashes, resonant-filtered noise
for tires, wind and gravel, a small room reverb on the chimes and fanfares. Standard
library only, and seeded, so the same script always writes the same files. A recorded
pack can still replace any cue: drop a file with the same name (.ogg, .wav or .mp3)
next to it, see assets/audio/README.md.

Usage:
    python3 tools/make_audio.py [project_dir] [--only=crash --only=music] [--out=DIR]

--out writes into DIR (sfx/, music/, radio/) instead of the project's assets/audio. The radio's
songs and stings (SONGS) each have their own random stream, so --only=sting_rock renders
just that one; the rest share one stream, so --only=crash still renders everything before it.
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


def write(path, sig, rate=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in sig)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate or RATE)
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


# --- Music: the radio (four original stations) ------------------------------
#
# Each station is one loop of 16 bars, A section then B section, sequenced in
# sixteenth notes. Notes are added into a loop-length buffer with wrap=True, and the
# effects run over two loops keeping the second (loop_fx), so a reverb tail or a
# filter's state carries across the seam. Music renders at MUSIC_RATE to keep the files
# small; Godot compresses them on import too.

MUSIC_RATE = 32000


class Song:
    """A loop-length buffer per part, with a sixteenth-note clock."""

    def __init__(self, bpm, bars):
        self.six = 60.0 / bpm / 4.0  # seconds per sixteenth
        self.bars = bars
        self.n = int(round(bars * 16 * self.six * RATE))
        self.parts = {}

    def at(self, step):
        return int(round(step * self.six * RATE))

    def secs(self, steps):
        return steps * self.six

    def add(self, part, sig, step, gain=1.0):
        buf = self.parts.setdefault(part, [0.0] * self.n)
        add_at(buf, sig, self.at(step) % self.n, gain, wrap=True)

    def part(self, name):
        return self.parts.get(name, [0.0] * self.n)

    def mixdown(self, levels):
        out = [0.0] * self.n
        for name, g in levels.items():
            for i, x in enumerate(self.part(name)):
                out[i] += x * g
        return out


def loop_fx(buf, fx):
    """Runs fx over two copies of a loop and keeps the second, so the loop stays seamless."""
    n = len(buf)
    return fx(buf + buf)[n:2 * n]


def pattern(song, part, hits, sound, gain=1.0, bars=None, accent=None):
    """hits: a 16-character bar ("x" a hit, "o" a softer one, "." a rest), every bar (or
    `bars`, a list of bar numbers)."""
    for bar in (range(song.bars) if bars is None else bars):
        for k, ch in enumerate(hits):
            if ch in "xo":
                g = gain * (1.0 if ch == "x" else 0.45)
                if accent and k in accent:
                    g *= 1.2
                song.add(part, sound, bar * 16 + k, g)


def play_notes(song, part, notes, make, gain=1.0, offset=0):
    """notes: (step, midi or [midis], length in sixteenths); make(notes, seconds) renders one."""
    for step, note, length in notes:
        if note is None:
            continue
        song.add(part, make(note if isinstance(note, list) else [note], song.secs(length)), offset + step, gain)


def m_kick(punch=1.0):
    body = decay(tone("sine", 150.0, 0.35, to=44.0), 0.11 * punch)
    click = decay(biquad(noise(int(0.01 * RATE)), "highpass", 3000.0), 0.002)
    return shot(mix((body, 1.0), (click, 0.4)))


def m_snare(tight=1.0):
    n = int(0.25 * RATE)
    rattle = decay(biquad(noise(n), "bandpass", 1900.0, 0.7), 0.09 * tight)
    body = decay(tone("tri", 190.0, 0.25, to=170.0), 0.045)
    return shot(mix((rattle, 1.1), (body, 0.8)))


def m_hat(open_hat=False):
    n = int((0.3 if open_hat else 0.06) * RATE)
    return shot(decay(biquad(noise(n), "highpass", 7500.0, 0.8), 0.09 if open_hat else 0.014))


def m_clap():
    out = silence(0.25)
    burst = biquad(noise(int(0.012 * RATE)), "bandpass", 1300.0, 1.0)
    for k in range(3):
        add_at(out, burst, int(k * 0.011 * RATE), 0.7)
    add_at(out, decay(biquad(noise(int(0.2 * RATE)), "bandpass", 1300.0, 1.0), 0.06), int(0.033 * RATE))
    return shot(out)


def m_crash():
    n = int(1.6 * RATE)
    wash = decay(biquad(noise(n), "highpass", 4500.0, 0.6), 0.55)
    ring = modal([(3150.0, 0.5, 0.2), (4720.0, 0.4, 0.15), (5980.0, 0.3, 0.1)], 1.6)
    return shot(mix((wash, 1.0), (ring, 0.6)))


def m_tom(note):
    return shot(decay(tone("sine", midi(note), 0.4, to=midi(note) * 0.7), 0.12))


def saws(notes, seconds, detune=0.006, voices=2):
    """Detuned saws for every note: the pads, leads and guitars start here."""
    out = [0.0] * int(round(seconds * RATE))
    for note in notes:
        for v in range(voices):
            d = 1.0 + detune * (v - (voices - 1) / 2.0)
            add_at(out, osc("saw", [midi(note) * d] * len(out)), 0, 1.0 / voices)
    return out


# Rock: 98.3 THE CANYON. E minor, 144 bpm. Palm-muted eighths on power chords (A), then
# open chords under a lead guitar (B).

def guitar(notes, seconds, muted=False):
    root = notes[0]
    raw = saws([root, root + 7, root + 12], seconds, 0.008, 2)
    raw = [math.tanh(6.0 * x) for x in raw]
    tone_ = biquad(biquad(raw, "lowpass", 1300.0 if muted else 3400.0, 0.8), "peak", 900.0, 1.0, 4.0)
    if muted:
        return env(tone_, attack=0.002, decay=0.08, sustain=0.25, release=0.03)
    return env(tone_, attack=0.004, decay=0.3, sustain=0.7, release=0.08)


def lead_guitar(notes, seconds):
    raw = tone("saw", midi(notes[0]), seconds, vibrato=0.012, vib_rate=5.5)
    raw = [math.tanh(4.0 * x) for x in raw]
    return env(biquad(raw, "lowpass", 3200.0, 1.2), attack=0.01, decay=0.2, sustain=0.8, release=0.06)


def rock_bass(notes, seconds):
    raw = osc("saw", [midi(notes[0])] * int(round(seconds * RATE)))
    return env(biquad(raw, "lowpass", 700.0, 1.0), attack=0.003, decay=0.1, sustain=0.6, release=0.03)


def station_rock():
    song = Song(144, 16)
    a_roots = [40, 40, 36, 38, 40, 40, 43, 45]  # E E C D E E G A
    b_roots = [36, 43, 38, 40, 36, 43, 45, 47]  # C G D E C G A B
    for bar, root in enumerate(a_roots):
        for e in range(8):
            song.add("gtr", guitar([root], song.secs(1.8), muted=e != 0), bar * 16 + e * 2, 0.8 if e else 1.0)
            song.add("bass", rock_bass([root - 12], song.secs(1.8)), bar * 16 + e * 2)
    for bar, root in enumerate(b_roots):
        b = 8 + bar
        song.add("gtr", guitar([root], song.secs(7.5)), b * 16)
        song.add("gtr", guitar([root], song.secs(7.5)), b * 16 + 8, 0.85)
        for e in range(8):
            song.add("bass", rock_bass([root - 12], song.secs(1.8)), b * 16 + e * 2)
    lead = [(0, 64, 6), (6, 67, 2), (8, 71, 4), (12, 69, 4), (16, 67, 6), (22, 66, 2), (24, 64, 8),
            (32, 64, 4), (36, 67, 4), (40, 71, 4), (44, 74, 4), (48, 72, 8), (56, 71, 8),
            (64, 76, 6), (70, 74, 2), (72, 72, 4), (76, 71, 4), (80, 69, 8), (88, 71, 8),
            (96, 72, 6), (102, 74, 2), (104, 76, 8), (112, 79, 4), (116, 78, 4), (120, 76, 8)]
    play_notes(song, "lead", lead, lead_guitar, 1.0, offset=8 * 16)
    pattern(song, "drums", "x.....x.x.......", m_kick(), 1.0)
    pattern(song, "drums", "....x.......x...", m_snare(), 0.9)
    pattern(song, "drums", "x.x.x.x.x.x.x.x.", m_hat(), 0.3)
    for bar in (0, 8):
        song.add("drums", m_crash(), bar * 16, 0.6)
    for k, note in enumerate((50, 50, 45, 45, 41, 41)):  # tom fill into the B section
        song.add("drums", m_tom(note), 7 * 16 + 10 + k, 0.7)
    gtr = loop_fx(song.part("gtr"), lambda x: reverb(x, 0.15, 0.8, 0.0))
    lead_wet = loop_fx(song.part("lead"), lambda x: reverb(x, 0.3, 1.1, 0.0))
    drums = loop_fx(song.part("drums"), lambda x: reverb(x, 0.12, 0.7, 0.0))
    out = [0.33 * g + 0.5 * b + 0.3 * l + 0.75 * d
           for g, b, l, d in zip(gtr, song.part("bass"), lead_wet, drums)]
    return finish(out, 0.85)


# Synthwave: 104.7 NEON FM. A minor, 100 bpm. Octave bass in sixteenths, wide pads, a
# gated big-room snare and a singing saw lead.

def pad(notes, seconds):
    raw = saws(notes, seconds, 0.012, 3)
    return env(biquad(raw, "lowpass", 1800.0, 0.7), attack=0.25, decay=0.3, sustain=0.85, release=0.3)


def synth_bass(notes, seconds):
    raw = osc("saw", [midi(notes[0])] * int(round(seconds * RATE)))
    return env(biquad(raw, "lowpass", 900.0, 1.4), attack=0.002, decay=0.09, sustain=0.4, release=0.02)


def synth_lead(notes, seconds):
    n = int(round(seconds * RATE))
    raw = [0.0] * n
    for d in (0.996, 1.004):
        add_at(raw, tone("saw", midi(notes[0]) * d, seconds, vibrato=0.01, vib_rate=5.0), 0, 0.5)
    return env(biquad(raw, "lowpass", 2600.0, 1.0), attack=0.02, decay=0.15, sustain=0.85, release=0.15)


def arp_pluck(notes, seconds):
    raw = osc("square", [midi(notes[0])] * int(round(seconds * RATE)), 0.25)
    return env(biquad(raw, "lowpass", 3000.0), attack=0.002, decay=0.06, sustain=0.2, release=0.03)


def station_synthwave():
    song = Song(100, 16)
    chords = [(45, [57, 60, 64]), (41, [57, 60, 65]), (48, [55, 60, 64]), (43, [55, 59, 62])] * 4  # Am F C G
    for bar, (root, chord) in enumerate(chords):
        for s16 in range(16):
            song.add("bass", synth_bass([root - 12 + (12 if s16 % 2 else 0)], song.secs(0.9)), bar * 16 + s16, 0.8)
        song.add("pad", pad(chord, song.secs(16)), bar * 16)
        if bar >= 8:
            for s16 in range(0, 16, 2):
                note = chord[(s16 // 2) % 3] + 12
                song.add("arp", arp_pluck([note], song.secs(1.5)), bar * 16 + s16, 0.5)
    lead = [(0, 76, 4), (4, 74, 2), (6, 72, 2), (8, 69, 8), (16, 72, 4), (20, 74, 4), (24, 72, 4), (28, 69, 4),
            (32, 67, 4), (36, 69, 2), (38, 72, 2), (40, 76, 8), (48, 74, 12), (60, 71, 4),
            (64, 76, 4), (68, 79, 4), (72, 81, 8), (80, 79, 4), (84, 77, 4), (88, 76, 8),
            (96, 72, 4), (100, 74, 4), (104, 76, 8), (112, 74, 8), (120, 71, 8)]
    play_notes(song, "lead", lead, synth_lead, 1.0, offset=8 * 16)
    pattern(song, "kick", "x.......x.......", m_kick(1.2), 1.0)
    pattern(song, "snare", "....x.......x...", m_snare(0.8), 1.0)
    pattern(song, "hat", "..x...x...x...x.", m_hat(), 0.35)
    pattern(song, "hat", "x.x.x.x.x.x.x.x.", m_hat(), 0.18, bars=range(8, 16))
    song.add("hat", m_crash(), 8 * 16, 0.5)
    snare = loop_fx(song.part("snare"), lambda x: reverb(x, 0.9, 1.6, 0.0))  # the big gated room
    pad_wet = loop_fx(song.part("pad"), lambda x: reverb(x, 0.4, 1.4, 0.0))
    lead_wet = loop_fx(song.part("lead"), lambda x: reverb(x, 0.45, 1.3, 0.0))
    arp_wet = loop_fx(song.part("arp"), lambda x: reverb(x, 0.35, 1.0, 0.0))
    out = [0.55 * b + 0.18 * p + 0.28 * l + 0.25 * a + 0.9 * k + 0.6 * s + h
           for b, p, l, a, k, s, h in zip(song.part("bass"), pad_wet, lead_wet, arp_wet, song.part("kick"),
                                          snare, song.part("hat"))]
    return finish(out, 0.85)


# Funk: 92.1 SOUL STOP. E, 104 bpm. A slap bass vamp on E7 and A7, wah clav chords on the
# off-sixteenths, ghost-note drums, and horn stabs in the B section.

def slap_bass(notes, seconds):
    n = int(round(seconds * RATE))
    raw = mix((osc("saw", [midi(notes[0])] * n), 0.7), (osc("tri", [midi(notes[0])] * n), 0.6))
    cut = [400.0 + 2600.0 * math.exp(-i / (0.03 * RATE)) for i in range(n)]
    return env(biquad(raw, "lowpass", cut, 2.0), attack=0.001, decay=0.12, sustain=0.5, release=0.03)


def clav(notes, seconds):
    n = int(round(seconds * RATE))
    raw = [0.0] * n
    for note in notes:
        add_at(raw, osc("square", [midi(note)] * n, 0.3), 0, 0.4)
    cut = [700.0 + 3200.0 * math.exp(-i / (0.045 * RATE)) for i in range(n)]  # the wah snapping shut
    return env(biquad(raw, "bandpass", cut, 3.0), attack=0.001, decay=0.06, sustain=0.3, release=0.02)


def horns(notes, seconds):
    out = [0.0] * int(round(seconds * RATE))
    for note in notes:
        add_at(out, brass(note, seconds, 0.02), 0, 0.5)
    return out


def station_funk():
    song = Song(104, 16)
    riff = [(0, 40, 2), (3, 52, 1), (4, 40, 1), (6, 50, 1), (7, 52, 1), (10, 40, 2), (12, 47, 1), (14, 50, 1), (15, 52, 1)]
    for bar in range(16):
        root_shift = 5 if bar % 4 == 2 else 0  # E7 E7 A7 E7
        if bar >= 8 and bar % 4 == 3:
            root_shift = 7  # B7 turnaround in the B section
        play_notes(song, "bass", [(s, n + root_shift, l) for s, n, l in riff], slap_bass, 1.0, offset=bar * 16)
        chord = [64 + root_shift, 68 + root_shift, 74 + root_shift]  # 3, 5... the 7th on top
        for s16 in (2, 5, 7, 10, 13, 15):
            song.add("clav", clav(chord, song.secs(0.8)), bar * 16 + s16, 0.8)
    stabs = [(0, [71, 75, 78], 2), (3, [71, 75, 78], 1), (6, [74, 78, 81], 2), (12, [76, 80, 83], 4)]
    for bar in range(8, 16, 2):
        play_notes(song, "horns", stabs, horns, 1.0, offset=bar * 16)
    pattern(song, "drums", "x..x..x...x..x..", m_kick(0.9), 1.0)
    pattern(song, "drums", "....x..o....x.o.", m_snare(0.7), 0.85)
    pattern(song, "drums", "xxxxxxxxxxxxxxxx", m_hat(), 0.16, accent=(0, 4, 8, 12))
    pattern(song, "drums", "..............x.", m_hat(True), 0.3)
    drums = loop_fx(song.part("drums"), lambda x: reverb(x, 0.12, 0.6, 0.0))
    horns_wet = loop_fx(song.part("horns"), lambda x: reverb(x, 0.3, 1.0, 0.0))
    out = [0.6 * b + 0.32 * c + 0.4 * h + 0.8 * d
           for b, c, h, d in zip(song.part("bass"), song.part("clav"), horns_wet, drums)]
    return finish(out, 0.85)


# Techno: 107.9 PULSE. F minor, 128 bpm. Four on the floor, an acid line whose filter
# opens over the loop, off-beat hats, chord stabs and a riser into the B section.

def acid(notes, seconds, cutoff):
    n = int(round(seconds * RATE))
    raw = osc("saw", [midi(notes[0])] * n)
    cut = [cutoff * (0.35 + 0.65 * math.exp(-i / (0.06 * RATE))) for i in range(n)]
    out = biquad(raw, "lowpass", cut, 7.0)
    return env([math.tanh(1.8 * x) for x in out], attack=0.002, decay=0.1, sustain=0.6, release=0.02)


def stab(notes, seconds):
    raw = saws(notes, seconds, 0.01, 2)
    n = len(raw)
    cut = [500.0 + 3000.0 * math.exp(-i / (0.05 * RATE)) for i in range(n)]
    return env(biquad(raw, "lowpass", cut, 1.5), attack=0.002, decay=0.1, sustain=0.3, release=0.05)


def station_techno():
    song = Song(128, 16)
    line = [41, 41, 53, 41, 44, 41, 51, 41, 41, 53, 41, 48, 41, 46, 41, 56]  # F minor sixteenths
    accents = {2, 6, 9, 15}
    for bar in range(16):
        sweep = 600.0 + 2600.0 * (0.5 - 0.5 * math.cos(TAU * bar / 16.0))  # opens and closes over the loop
        for k, note in enumerate(line):
            song.add("acid", acid([note - 12 + (12 if bar >= 8 and k in accents else 0)], song.secs(0.9), sweep),
                     bar * 16 + k, 1.0 if k in accents else 0.7)
        if bar >= 8:
            for s16 in (3, 11):
                song.add("stab", stab([65, 68, 72], song.secs(1.5)), bar * 16 + s16, 0.8)
    pattern(song, "drums", "x...x...x...x...", m_kick(1.1), 1.0)
    pattern(song, "drums", "....x.......x...", m_clap(), 0.7)
    pattern(song, "drums", "..x...x...x...x.", m_hat(True), 0.3)
    pattern(song, "drums", "x.x.x.x.x.x.x.x.", m_hat(), 0.14, bars=range(4, 16))
    riser_n = int(song.secs(32) * RATE)
    riser = biquad(noise(riser_n), "bandpass", [300.0 * (20.0 ** (i / riser_n)) for i in range(riser_n)], 1.5)
    riser = [x * (i / riser_n) ** 2 for i, x in enumerate(riser)]
    song.add("fx", riser, 6 * 16, 0.6)
    song.add("drums", m_crash(), 8 * 16, 0.5)
    stab_wet = loop_fx(song.part("stab"), lambda x: reverb(x, 0.5, 1.3, 0.0))
    acid_wet = loop_fx(song.part("acid"), lambda x: reverb(x, 0.15, 0.9, 0.0))
    out = [0.4 * a + 0.3 * s + 0.85 * d + f
           for a, s, d, f in zip(acid_wet, stab_wet, song.part("drums"), song.part("fx"))]
    return finish(out, 0.85)


def radio_tune():
    """Changing station: a burst of tuning static with a whistle sliding through it."""
    seconds = 0.35
    n = int(seconds * RATE)
    hiss = biquad(noise(n), "bandpass", 2500.0, 0.5)
    whistle = tone("sine", 2600.0, seconds, to=900.0)
    chop = [0.6 + 0.4 * math.sin(TAU * 31 * i / RATE) for i in range(n)]
    out = env([h * c + 0.25 * w for h, c, w in zip(hiss, chop, whistle)], attack=0.01, decay=0.1, sustain=0.8,
              release=0.12)
    return shot(finish(out))


def shutter():
    """The photo key (PR-21): a camera shutter, the blades snapping open and shut a beat apart,
    each a click of metal over a puff of air, and the mirror's soft thump under the first."""
    out = silence(0.25)
    for k, (at, pitch) in enumerate(((0.0, 1.0), (0.065, 0.82))):
        click = modal([(3400.0 * pitch, 0.012, 1.0), (5200.0 * pitch, 0.008, 0.6), (7900.0 * pitch, 0.005, 0.3)], 0.05)
        puff = decay(biquad(noise(int(0.05 * RATE)), "bandpass", 4200.0 * pitch, 0.9), 0.008)
        add_at(out, mix((click, 1.0), (puff, 0.6)), int(at * RATE), 1.0 if k == 0 else 0.8)
    add_at(out, decay(tone("sine", 140.0, 0.12, to=90.0), 0.02), 0, 0.5)
    return shot(finish(trim(reverb(out, 0.15, 0.6, 0.15))))


# --- The announcer (Announcer.LINES, read from scripts/audio/announcer.gd) ---
#
# Not words: patter in each line's rhythm, the way a cartoon character talks. Each
# syllable is a glottal buzz through two vowel formants, led by a consonant burst; the
# pitch climbs through the line and jumps on a "!". The subtitle carries the words.

VOWELS = {"a": (780.0, 1250.0), "e": (520.0, 1850.0), "i": (320.0, 2300.0), "o": (520.0, 900.0),
          "u": (360.0, 820.0), "y": (340.0, 2150.0)}
PLOSIVES = "pbtdkgcq"
FRICATIVES = {"s": 6200.0, "z": 5200.0, "f": 3800.0, "v": 3000.0, "h": 1600.0, "x": 5000.0, "j": 3200.0}


def announcer_lines(project):
    """{id: text} from Announcer.LINES."""
    import re
    src = open(os.path.join(project, "scripts", "audio", "announcer.gd"), encoding="utf-8").read()
    block = src[src.index("const LINES := {"):]
    block = block[:block.index("}")]
    return dict(re.findall(r'"(\w+)": "([^"]*)"', block))


def syllables(text):
    """[(onset consonants, vowel letters, pause after in seconds, excited)] for the line."""
    out = []
    for word in text.lower().replace(",", " , ").replace(".", " . ").replace("!", " ! ").replace("?", " ? ").split():
        if word in ",.!?":
            if out:
                c, v, _, ex = out[-1]
                out[-1] = (c, v, 0.16 if word in ".!?" else 0.1, ex or word == "!")
            continue
        onset, vowels, parts = "", "", []
        for ch in word:
            if ch in VOWELS:
                vowels += ch
            else:
                if vowels:
                    parts.append((onset, vowels))
                    onset, vowels = "", ""
                onset += ch
        if vowels:
            parts.append((onset, vowels))
        elif parts:
            parts[-1] = (parts[-1][0], parts[-1][1])  # a trailing consonant folds into the last syllable
        for k, (c, v) in enumerate(parts):
            out.append((c, v, 0.04 if k == len(parts) - 1 else 0.0, False))
    return out


def voice(text, base=150.0):
    sylls = syllables(text)
    out = silence(0.05)
    count = max(1, len(sylls))
    for k, (onset, vowels, pause, excited) in enumerate(sylls):
        lead = onset[:1]
        if lead and lead in PLOSIVES:
            out += decay(biquad(noise(int(0.018 * RATE)), "bandpass", 2800.0, 0.8), 0.005)
        elif lead in FRICATIVES:
            n = int(0.055 * RATE)
            out += env(biquad(noise(n), "bandpass", FRICATIVES[lead], 1.2), attack=0.01, decay=0.02, sustain=0.6,
                       release=0.015)
        length = 0.12 + (0.06 if excited else 0.0) + 0.015 * (len(vowels) - 1)
        n = int(length * RATE)
        rise = 1.0 + 0.25 * k / count  # climbing through the line
        f0 = base * rise * (1.35 if excited else 1.0) * rng.uniform(0.95, 1.06)
        contour = [f0 * (1.0 + (0.15 if excited else 0.05) * math.sin(math.pi * i / n)) for i in range(n)]
        buzz = osc("saw", contour)
        if lead and lead in "mnlrw":
            buzz = env(buzz, attack=0.02, decay=0.02, sustain=1.0, release=0.0)
        f1, f2 = VOWELS[vowels[0]]
        if len(vowels) > 1:  # a glide toward the second vowel
            g1, g2 = VOWELS[vowels[-1]]
            f1s = [f1 + (g1 - f1) * i / n for i in range(n)]
            f2s = [f2 + (g2 - f2) * i / n for i in range(n)]
        else:
            f1s, f2s = f1, f2
        vowel = mix((biquad(buzz, "bandpass", f1s, 5.0), 1.0), (biquad(buzz, "bandpass", f2s, 8.0), 0.7),
                    (biquad(buzz, "bandpass", 2700.0, 6.0), 0.25))
        out += env(vowel, attack=0.012, decay=0.04, sustain=0.85, release=0.035)
        out += silence(pause)
    pa = biquad(biquad(out, "highpass", 280.0), "lowpass", 3800.0)  # the stadium speakers
    pa = biquad(pa, "peak", 1800.0, 1.0, 5.0)
    return shot(finish(trim(reverb(pa, 0.35, 1.5, 0.6))), fade_out=0.03)


def at_music_rate(make):
    """Renders `make` with RATE set to MUSIC_RATE (the helpers all read RATE)."""
    def run():
        global RATE
        saved, RATE = RATE, MUSIC_RATE
        try:
            return make(), MUSIC_RATE
        finally:
            RATE = saved
    return run


# --- Radio v2 (PR-24): four more songs per station, and each station's sting ---
#
# Each song comes from its genre's generator with its own tempo, key, changes and drum
# feel, and a lead line written by a seeded walk over the scale (melody). They render
# last, each on its own random stream (own_rng), so adding them changed none of the files
# above, and adding more later changes none of these. The stings are the station's
# ident between songs: a two-second hit in the station's own sound.

def own_rng(seed, make):
    """Runs `make` with the shared random stream swapped for one seeded with `seed`."""
    def run():
        global rng
        saved, rng = rng, random.Random(seed)
        try:
            return make()
        finally:
            rng = saved
    return run


MINOR_PENT = (0, 3, 5, 7, 10)
MINOR = (0, 2, 3, 5, 7, 8, 10)
MIXO = (0, 2, 4, 5, 7, 9, 10)
CELLS = ((4, 4, 4, 4), (6, 2, 4, 4), (2, 2, 4, 8), (8, 8), (4, 2, 2, 8), (3, 3, 2, 8), (12, 4),
         (2, 2, 2, 2, 8), (4, 4, 8), (6, 6, 4))


def melody(tonic, scale, bars, rests=0.15):
    """A lead line: (step, midi, length) over `bars` bars, a walk over `scale` (semitones
    above `tonic`, two octaves) in rhythm cells, each four-bar phrase coming home on the
    tonic. Reads the shared random stream (own_rng gives each song its own)."""
    notes = [tonic + o * 12 + s for o in (0, 1) for s in scale] + [tonic + 24]
    home = len(scale)  # the tonic an octave up: the middle of the range
    at = home
    out = []
    for bar in range(bars):
        cell = rng.choice(CELLS)
        step = bar * 16
        for k, length in enumerate(cell):
            last = k == len(cell) - 1 and bar % 4 == 3
            if last:
                at = home if rng.random() < 0.7 else home - len(scale)
            else:
                at = max(0, min(len(notes) - 1, at + rng.choice((-2, -1, -1, 0, 1, 1, 2, 3))))
            if last or rng.random() > rests:
                out.append((step, notes[at], length))
            step += length
    return out


def rock_song(bpm, key, a_prog, b_prog, kick, snare, gallop=False):
    """98.3 THE CANYON's songs: power chords in the A section (palm-muted eighths, or a
    gallop), open chords under a lead guitar in the B section."""
    song = Song(bpm, 16)
    for bar, shift in enumerate(a_prog):
        root = key + shift
        hits = (0, 3, 4, 6, 8, 11, 12, 14) if gallop else range(0, 16, 2)
        for k, s16 in enumerate(hits):
            song.add("gtr", guitar([root], song.secs(1.6), muted=k != 0), bar * 16 + s16, 0.8 if k else 1.0)
        for e in range(8):
            song.add("bass", rock_bass([root - 12], song.secs(1.8)), bar * 16 + e * 2)
    for bar, shift in enumerate(b_prog):
        b = 8 + bar
        song.add("gtr", guitar([key + shift], song.secs(7.5)), b * 16)
        song.add("gtr", guitar([key + shift], song.secs(7.5)), b * 16 + 8, 0.85)
        for e in range(8):
            song.add("bass", rock_bass([key + shift - 12], song.secs(1.8)), b * 16 + e * 2)
    play_notes(song, "lead", melody(key + 12, MINOR_PENT, 8), lead_guitar, 1.0, offset=8 * 16)
    pattern(song, "drums", kick, m_kick(), 1.0)
    pattern(song, "drums", snare, m_snare(), 0.9)
    pattern(song, "drums", "x.x.x.x.x.x.x.x.", m_hat(), 0.3)
    for bar in (0, 8):
        song.add("drums", m_crash(), bar * 16, 0.6)
    for k, note in enumerate((key + 10, key + 10, key + 5, key + 5, key + 1, key + 1)):
        song.add("drums", m_tom(note), 7 * 16 + 10 + k, 0.7)
    gtr = loop_fx(song.part("gtr"), lambda x: reverb(x, 0.15, 0.8, 0.0))
    lead_wet = loop_fx(song.part("lead"), lambda x: reverb(x, 0.3, 1.1, 0.0))
    drums = loop_fx(song.part("drums"), lambda x: reverb(x, 0.12, 0.7, 0.0))
    out = [0.33 * g + 0.5 * b + 0.3 * l + 0.75 * d
           for g, b, l, d in zip(gtr, song.part("bass"), lead_wet, drums)]
    return finish(out, 0.85)


def synth_song(bpm, chords, bass_octaves=True, arp_from=8, hats="..x...x...x...x."):
    """104.7 NEON FM's songs: bass in sixteenths under wide pads, an arpeggio, a gated
    snare and a saw lead. `chords` are four (bass root, [pad notes]) bars, round and round."""
    song = Song(bpm, 16)
    for bar, (root, chord) in enumerate(chords * 4):
        for s16 in range(16):
            up = 12 if (bass_octaves and s16 % 2) else (7 if not bass_octaves and s16 % 4 == 2 else 0)
            song.add("bass", synth_bass([root - 12 + up], song.secs(0.9)), bar * 16 + s16, 0.8)
        song.add("pad", pad(chord, song.secs(16)), bar * 16)
        if bar >= arp_from:
            for s16 in range(0, 16, 2):
                song.add("arp", arp_pluck([chord[(s16 // 2) % 3] + 12], song.secs(1.5)), bar * 16 + s16, 0.5)
    tonic = chords[0][0] + 24
    play_notes(song, "lead", melody(tonic, MINOR, 8, 0.1), synth_lead, 1.0, offset=8 * 16)
    pattern(song, "kick", "x.......x.......", m_kick(1.2), 1.0)
    pattern(song, "snare", "....x.......x...", m_snare(0.8), 1.0)
    pattern(song, "hat", hats, m_hat(), 0.35)
    pattern(song, "hat", "x.x.x.x.x.x.x.x.", m_hat(), 0.18, bars=range(8, 16))
    song.add("hat", m_crash(), 8 * 16, 0.5)
    snare = loop_fx(song.part("snare"), lambda x: reverb(x, 0.9, 1.6, 0.0))
    pad_wet = loop_fx(song.part("pad"), lambda x: reverb(x, 0.4, 1.4, 0.0))
    lead_wet = loop_fx(song.part("lead"), lambda x: reverb(x, 0.45, 1.3, 0.0))
    arp_wet = loop_fx(song.part("arp"), lambda x: reverb(x, 0.35, 1.0, 0.0))
    out = [0.55 * b + 0.18 * p + 0.28 * l + 0.25 * a + 0.9 * k + 0.6 * s + h
           for b, p, l, a, k, s, h in zip(song.part("bass"), pad_wet, lead_wet, arp_wet, song.part("kick"),
                                          snare, song.part("hat"))]
    return finish(out, 0.85)


def funk_song(bpm, key, riff, changes, kick, clav_hits=(2, 5, 7, 10, 13, 15)):
    """92.1 SOUL STOP's songs: a slap bass riff over the changes (a semitone shift per bar),
    wah clav on the off-sixteenths, ghost-note drums and horn lines in the B section."""
    song = Song(bpm, 16)
    for bar in range(16):
        shift = changes[bar % len(changes)]
        play_notes(song, "bass", [(s, key + n + shift, l) for s, n, l in riff], slap_bass, 1.0, offset=bar * 16)
        chord = [key + 24 + shift, key + 28 + shift, key + 34 + shift]  # 3, 5, the 7th on top
        for s16 in clav_hits:
            song.add("clav", clav(chord, song.secs(0.8)), bar * 16 + s16, 0.8)
    for bar in range(8, 16, 2):
        shift = changes[bar % len(changes)]
        hit = [key + 31 + shift, key + 35 + shift, key + 38 + shift]
        line = [(s, [n], l) for s, n, l in melody(key + 24 + shift, MIXO, 1, 0.3) if s >= 6]
        play_notes(song, "horns", [(0, hit, 2), (3, hit, 1)] + line, horns, 1.0, offset=bar * 16)
    pattern(song, "drums", kick, m_kick(0.9), 1.0)
    pattern(song, "drums", "....x..o....x.o.", m_snare(0.7), 0.85)
    pattern(song, "drums", "xxxxxxxxxxxxxxxx", m_hat(), 0.16, accent=(0, 4, 8, 12))
    pattern(song, "drums", "..............x.", m_hat(True), 0.3)
    drums = loop_fx(song.part("drums"), lambda x: reverb(x, 0.12, 0.6, 0.0))
    horns_wet = loop_fx(song.part("horns"), lambda x: reverb(x, 0.3, 1.0, 0.0))
    out = [0.6 * b + 0.32 * c + 0.4 * h + 0.8 * d
           for b, c, h, d in zip(song.part("bass"), song.part("clav"), horns_wet, drums)]
    return finish(out, 0.85)


def techno_song(bpm, key, chord, clap="....x.......x...", sweeps=1.0):
    """107.9 PULSE's songs: four on the floor under an acid line (sixteen notes picked from
    the minor scale), its filter opening `sweeps` times over the song, and stabs in the B
    section after a riser."""
    song = Song(bpm, 16)
    line = [key] + [key + rng.choice((0, 0, 0, 12, 3, 7, 10, 15, 5)) for _ in range(15)]
    accents = set(rng.sample(range(1, 16), 4))
    for bar in range(16):
        sweep = 600.0 + 2600.0 * (0.5 - 0.5 * math.cos(TAU * sweeps * bar / 16.0))
        for k, note in enumerate(line):
            song.add("acid", acid([note - 12 + (12 if bar >= 8 and k in accents else 0)], song.secs(0.9), sweep),
                     bar * 16 + k, 1.0 if k in accents else 0.7)
        if bar >= 8:
            for s16 in (3, 11):
                song.add("stab", stab(chord, song.secs(1.5)), bar * 16 + s16, 0.8)
    pattern(song, "drums", "x...x...x...x...", m_kick(1.1), 1.0)
    pattern(song, "drums", clap, m_clap(), 0.7)
    pattern(song, "drums", "..x...x...x...x.", m_hat(True), 0.3)
    pattern(song, "drums", "x.x.x.x.x.x.x.x.", m_hat(), 0.14, bars=range(4, 16))
    riser_n = int(song.secs(32) * RATE)
    riser = biquad(noise(riser_n), "bandpass", [300.0 * (20.0 ** (i / riser_n)) for i in range(riser_n)], 1.5)
    riser = [x * (i / riser_n) ** 2 for i, x in enumerate(riser)]
    song.add("fx", riser, 6 * 16, 0.6)
    song.add("drums", m_crash(), 8 * 16, 0.5)
    stab_wet = loop_fx(song.part("stab"), lambda x: reverb(x, 0.5, 1.3, 0.0))
    acid_wet = loop_fx(song.part("acid"), lambda x: reverb(x, 0.15, 0.9, 0.0))
    out = [0.4 * a + 0.3 * s + 0.85 * d + f
           for a, s, d, f in zip(acid_wet, stab_wet, song.part("drums"), song.part("fx"))]
    return finish(out, 0.85)


def sting(kind):
    """A station's ident between songs: about two seconds in its own sound, into a ring-out."""
    out = silence(2.2)

    def at(beat):
        return int(beat * 0.18 * RATE)
    if kind == "rock":  # three power-chord hits and a crash: E, G, A
        for k, root in enumerate((40, 43, 45)):
            add_at(out, guitar([root], 0.16 if k < 2 else 1.4), at(k), 0.8)
            add_at(out, m_kick(), at(k), 0.7)
        add_at(out, m_crash(), at(2), 0.5)
    elif kind == "synthwave":  # an arpeggio up an A minor chord into a pad swell
        for k, note in enumerate((57, 60, 64, 69, 72, 76)):
            add_at(out, arp_pluck([note], 0.25), int(k * 0.09 * RATE), 0.5)
        add_at(out, pad([57, 64, 72], 1.6), at(1), 0.5)
        add_at(out, m_snare(0.8), at(3), 0.6)
    elif kind == "funk":  # a slap pickup into a horn hit and a clav chord
        for k, note in enumerate((40, 52, 50, 52)):
            add_at(out, slap_bass([note], 0.12), int(k * 0.09 * RATE), 0.8)
        add_at(out, horns([71, 75, 78], 1.0), at(2), 0.8)
        add_at(out, clav([64, 68, 74], 0.25), at(2), 0.5)
        add_at(out, m_snare(0.7), at(2), 0.6)
    else:  # techno: a riser into a stab on the one
        n = int(0.5 * RATE)
        rise = biquad(noise(n), "bandpass", [400.0 * (12.0 ** (i / n)) for i in range(n)], 1.5)
        add_at(out, [x * (i / n) ** 2 for i, x in enumerate(rise)], 0, 0.6)
        add_at(out, stab([65, 68, 72], 1.2), n, 0.9)
        add_at(out, m_kick(1.1), n, 0.9)
        add_at(out, m_clap(), n, 0.5)
    return shot(finish(trim(reverb(out, 0.35, 1.2, 0.6)), 0.8), fade_out=0.05)


RIFF_A = [(0, 0, 2), (3, 12, 1), (4, 0, 1), (6, 10, 1), (7, 12, 1), (10, 0, 2), (12, 7, 1), (14, 10, 1), (15, 12, 1)]
RIFF_B = [(0, 0, 3), (3, 0, 1), (5, 12, 1), (7, 10, 1), (8, 0, 2), (11, 3, 1), (12, 4, 1), (14, 7, 2)]
RIFF_C = [(0, 0, 1), (2, 0, 1), (3, 12, 1), (6, 0, 2), (9, 10, 1), (10, 12, 1), (12, 0, 1), (13, 7, 1), (15, 12, 1)]

# Radio.STATIONS' songs after each station's first, and the stings: (file, seed, generator).
# The songs and the stings go in radio/, which the Web build leaves out (its download budget,
# EQ-23); each station's first song stays in music/.
SONGS = [
    ("radio/rock_dust_devil.wav", 2401, lambda: rock_song(
        152, 45, (0, 0, 3, 5, 0, 0, 7, 5), (-4, 3, -2, 0, -4, 3, 5, 7), "x.....x.x.......", "....x.......x...")),
    ("radio/rock_mesa_run.wav", 2402, lambda: rock_song(
        136, 38, (0, 0, 5, 3, 0, 0, -2, -4), (5, 3, -2, 0, 5, 3, 7, 7), "x.x...x...x.....", "....x.......x...",
        gallop=True)),
    ("radio/rock_high_noon.wav", 2403, lambda: rock_song(
        160, 43, (0, 3, 5, 3, 0, 3, 7, 5), (-4, -2, 0, 0, -4, -2, 3, 5), "x...x...x...x...", "....x.......x..x")),
    ("radio/rock_salt_flats.wav", 2404, lambda: rock_song(
        120, 40, (0, 0, 0, -2, 0, 0, 3, 2), (3, 5, 7, 5, 3, 5, 10, 7), "x.......x.x.....", "........x.......")),
    ("radio/synthwave_afterglow.wav", 2411, lambda: synth_song(
        96, [(41, [53, 57, 60]), (43, [55, 58, 62]), (45, [57, 60, 64]), (40, [55, 59, 64])])),
    ("radio/synthwave_chrome_heart.wav", 2412, lambda: synth_song(
        108, [(38, [57, 62, 65]), (46, [58, 62, 65]), (41, [57, 60, 65]), (45, [57, 61, 64])], bass_octaves=False)),
    ("radio/synthwave_night_drive.wav", 2413, lambda: synth_song(
        88, [(40, [55, 59, 64]), (36, [55, 60, 64]), (43, [55, 59, 62]), (38, [54, 57, 62])], arp_from=4)),
    ("radio/synthwave_palm_static.wav", 2414, lambda: synth_song(
        112, [(42, [54, 57, 61]), (38, [54, 57, 62]), (45, [57, 61, 64]), (40, [56, 59, 64])],
        hats="x.x.x.x.x.x.x.x.")),
    ("radio/funk_slick_back.wav", 2421, lambda: funk_song(
        100, 45, RIFF_B, (0, 0, 5, 0, 0, 0, 7, 5), "x..x..x...x..x..")),
    ("radio/funk_double_parked.wav", 2422, lambda: funk_song(
        110, 38, RIFF_A, (0, 5, 0, 7), "x.x...x..x.x....")),
    ("radio/funk_velvet_turn.wav", 2423, lambda: funk_song(
        96, 43, RIFF_C, (0, 0, 0, 0, 5, 5, 0, 0, 7, 5, 0, 7), "x.....x.x..x....", clav_hits=(1, 4, 6, 9, 12, 14))),
    ("radio/funk_tailwind.wav", 2424, lambda: funk_song(
        116, 41, RIFF_A, (0, 0, 5, 5, 0, 0, 7, 7), "x..x...x..x..x..")),
    ("radio/techno_redline.wav", 2431, lambda: techno_song(132, 43, [67, 70, 74])),
    ("radio/techno_overpass.wav", 2432, lambda: techno_song(124, 38, [62, 65, 69], clap="....x.......x..x", sweeps=2.0)),
    ("radio/techno_grid_lock.wav", 2433, lambda: techno_song(136, 45, [69, 72, 76], sweeps=0.5)),
    ("radio/techno_static_bloom.wav", 2434, lambda: techno_song(128, 40, [64, 67, 71], clap="..x.x.......x...")),
    ("radio/sting_rock.wav", 2441, lambda: sting("rock")),
    ("radio/sting_synthwave.wav", 2442, lambda: sting("synthwave")),
    ("radio/sting_funk.wav", 2443, lambda: sting("funk")),
    ("radio/sting_techno.wav", 2444, lambda: sting("techno")),
]


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
    "sfx/radio_tune.wav": radio_tune,
    "music/station_rock.wav": at_music_rate(station_rock),
    "music/station_synthwave.wav": at_music_rate(station_synthwave),
    "music/station_funk.wav": at_music_rate(station_funk),
    "music/station_techno.wav": at_music_rate(station_techno),
    "sfx/shutter.wav": shutter,  # after the music, so adding it moved only the announcer's lines
}


def rms_db(sig):
    return 20.0 * math.log10(math.sqrt(sum(x * x for x in sig) / max(1, len(sig))) or 1e-9)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--only=")]
    project = args[0] if args else os.path.join(os.path.dirname(__file__), "..")
    outs = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--out=")]
    out_dir = outs[0] if outs else os.path.join(project, "assets", "audio")
    files = dict(FILES)
    for line_id, text in announcer_lines(project).items():  # last, so the others don't move
        files["sfx/vo_%s.wav" % line_id] = (lambda t: lambda: voice(t))(text)
    own = set()
    for name, seed, make in SONGS:  # after everything on the shared stream, each on its own (PR-24)
        files[name] = at_music_rate(own_rng(seed, make))
        own.add(name)
    shared_wanted = not only or any(n not in own and any(o in n for o in only) for n in files)
    for name, make in files.items():
        wanted = not only or any(o in name for o in only)
        if not wanted and (name in own or not shared_wanted):
            continue  # on its own random stream, or nothing after it on the shared one is wanted
        sig = make()  # every sound, in order, so the shared random stream gives the same files
        sig, rate = sig if isinstance(sig, tuple) else (sig, RATE)
        if not wanted:
            continue
        path = os.path.join(out_dir, name)
        write(path, sig, rate)
        print("wrote %s (%.2f s, %.1f dB RMS)" % (os.path.relpath(path, project), len(sig) / rate, rms_db(sig)))


if __name__ == "__main__":
    main()
