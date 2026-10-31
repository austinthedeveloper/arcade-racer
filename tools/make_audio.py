#!/usr/bin/env python3
"""Synthesize the placeholder sound effects and music loop.

Retro arcade style: pulse/saw oscillators, filtered noise, simple envelopes.
Standard library only, and seeded, so the same script always writes the same
files. Every file stands in until a real sound pack replaces it: drop a file
with the same name (.ogg, .wav or .mp3) next to it, see assets/audio/README.md.

Usage:
    python3 tools/make_audio.py [project_dir]
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 22050
rng = random.Random(1987)


# --- Building blocks -------------------------------------------------------

def silence(seconds):
    return [0.0] * int(round(seconds * RATE))


def noise(n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(sig, cutoff):
    """One-pole lowpass; cutoff is a number (Hz) or a list per sample."""
    out = []
    y = 0.0
    for i, x in enumerate(sig):
        c = cutoff[i] if isinstance(cutoff, list) else cutoff
        a = 1.0 - math.exp(-2.0 * math.pi * c / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    return [x - y for x, y in zip(sig, lowpass(sig, cutoff))]


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
            v = math.sin(2.0 * math.pi * ph)
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
            f *= 1.0 + vibrato * math.sin(2.0 * math.pi * vib_rate * i / RATE)
        freqs.append(f)
    return osc(kind, freqs, duty)


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
    return [x * math.exp(-i / (seconds * RATE)) for i, x in enumerate(sig)]


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


def seamless(render, seconds):
    """Renders two periods of a periodic signal and keeps the second, so filters have settled
    and the end joins the start without a click. `render(n)` gets n = two periods and should
    use loop_noise(n) for noise."""
    n = int(round(seconds * RATE))
    return render(2 * n)[n:]


def loop_noise(n):
    """Noise that repeats every n / 2 samples (one loop period)."""
    half = noise(n // 2)
    return half + half


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

def engine(base, bright):
    """One second of engine at `base` Hz (a multiple of 4, so every oscillator loops whole);
    the game pitch-shifts it with speed."""
    def render(n):
        saw = osc("saw", [base] * n)
        sub = osc("square", [base / 2] * n)
        pulse = osc("square", [base * 2] * n, duty=0.25)
        firing = osc("square", [base / 4] * n, duty=0.3)  # uneven cylinder thump
        rough = lowpass(loop_noise(n), 400.0)
        raw = [0.55 * s + (0.45 - bright * 0.3) * b + bright * 0.35 * p + 0.6 * r
               for s, b, p, r in zip(saw, sub, pulse, rough)]
        raw = [x * (0.75 + 0.25 * f) for x, f in zip(raw, firing)]
        return lowpass(raw, 900.0 + bright * 1800.0)
    return finish(seamless(render, 1.0), 0.8)


def skid():
    def render(n):
        squeal = osc("tri", [900.0 * (1.0 + 0.03 * math.sin(2 * math.pi * 7 * i / RATE)) for i in range(n)])
        hiss = highpass(lowpass(loop_noise(n), 3500.0), 800.0)
        return [0.6 * s + 0.5 * h for s, h in zip(squeal, hiss)]
    return finish(seamless(render, 1.0), 0.8)


def offroad():
    def render(n):
        rumble = lowpass(loop_noise(n), 250.0)
        grit = highpass(lowpass(loop_noise(n), 2500.0), 900.0)
        bumps = osc("sine", [11.0] * n)
        return [(0.8 * r + 0.25 * g) * (0.6 + 0.4 * b) for r, g, b in zip(rumble, grit, bumps)]
    return finish(seamless(render, 1.0), 0.8)


# --- One-shots -------------------------------------------------------------

def nitro():
    n = int(1.4 * RATE)
    cut = [300.0 + 5000.0 * (i / n) ** 0.5 for i in range(n)]
    whoosh = lowpass(noise(n), cut)
    rise = tone("saw", 180.0, 1.4, to=720.0)
    sig = mix((whoosh, 1.0), (lowpass(rise, 2000.0), 0.35))
    return shot(finish(env(sig, attack=0.03, decay=0.3, sustain=0.7, release=0.6)))


def crash():
    n = int(1.2 * RATE)
    cut = [6000.0 * math.exp(-i / (0.25 * RATE)) + 200.0 for i in range(n)]
    smash = decay(lowpass(noise(n), cut), 0.35)
    thump = decay(tone("sine", 90.0, 1.2, to=35.0), 0.25)
    clank = mix(*[(decay(tone("square", f, 1.2, duty=0.3), d), 0.15)
                  for f, d in ((523.0, 0.18), (811.0, 0.12), (1187.0, 0.09))])
    glass = decay(highpass(noise(n), 4000.0), 0.4)
    return shot(finish(mix((smash, 1.0), (thump, 1.2), (clank, 1.0), (glass, 0.3))))


def bump():
    thump = decay(tone("sine", 120.0, 0.3, to=60.0), 0.06)
    click = decay(lowpass(noise(int(0.3 * RATE)), 2500.0), 0.03)
    return shot(finish(mix((thump, 1.0), (click, 0.6))))


def land():
    thump = decay(tone("sine", 70.0, 0.35, to=40.0), 0.09)
    crunch = decay(lowpass(noise(int(0.35 * RATE)), 1200.0), 0.05)
    return shot(finish(mix((thump, 1.0), (crunch, 0.5))))


def beep():
    return shot(finish(env(tone("square", 660.0, 0.25), decay=0.05, sustain=0.6, release=0.05)))


def go():
    return shot(finish(env(tone("square", 1320.0, 0.6, vibrato=0.01), decay=0.1, sustain=0.7, release=0.25)))


def tick():
    return shot(finish(env(tone("square", 1000.0, 0.08, duty=0.25), attack=0.001, decay=0.02,
                               sustain=0.5, release=0.04), 0.7))


def checkpoint():
    out = silence(0.9)
    for k, note in enumerate((84, 88, 91, 96)):
        n = env(tone("square", midi(note), 0.25, duty=0.25), decay=0.05, sustain=0.5, release=0.12)
        add_at(out, n, int(k * 0.07 * RATE))
        add_at(out, n, int((k * 0.07 + 0.18) * RATE), 0.3)  # echo
    return shot(finish(out))


def finish_fanfare():
    out = silence(2.4)
    for k, note in enumerate((72, 76, 79)):
        add_at(out, env(tone("square", midi(note), 0.14), decay=0.03, sustain=0.6, release=0.04),
               int(k * 0.15 * RATE))
    for note in (84, 88, 91):
        chord = env(tone("square", midi(note), 1.9, duty=0.25, vibrato=0.006), decay=0.2, sustain=0.6, release=0.8)
        add_at(out, chord, int(0.45 * RATE), 0.6)
    add_at(out, env(tone("tri", midi(48), 1.9), decay=0.2, sustain=0.7, release=0.8), int(0.45 * RATE), 0.9)
    return shot(finish(out))


def crowd():
    """The crowd at the finish line: a roar that swells and dies away, with clapping and a
    few whistles. Loud on purpose (the cue is mixed hot in SoundBank)."""
    seconds = 4.0
    n = int(seconds * RATE)
    # Roar: band-limited noise, wobbling like many voices, swelling in and fading out
    roar = highpass(lowpass(noise(n), 2200.0), 250.0)
    voices = highpass(lowpass(noise(n), 900.0), 400.0)
    wobble = [1.0 + 0.25 * math.sin(2 * math.pi * 3.1 * i / RATE) * math.sin(2 * math.pi * 0.7 * i / RATE)
              for i in range(n)]
    swell = [min(1.0, i / (0.35 * RATE)) * min(1.0, (n - i) / (1.8 * RATE)) for i in range(n)]
    out = [(0.8 * r + 0.6 * v) * w * s for r, v, w, s in zip(roar, voices, wobble, swell)]
    # Clapping: short bright bursts scattered through the swell
    clap = decay(highpass(noise(int(0.03 * RATE)), 1200.0), 0.006)
    for k in range(140):
        t = rng.uniform(0.15, seconds - 1.2)
        add_at(out, clap, int(t * RATE), rng.uniform(0.25, 0.6) * swell[int(t * RATE)])
    # Whistles: a few rising-then-falling sine glides
    for t, f in ((0.4, 1900.0), (1.1, 2300.0), (1.9, 2100.0)):
        up = tone("sine", f, 0.18, to=f * 1.35, vibrato=0.01)
        down = tone("sine", f * 1.35, 0.3, to=f * 1.1, vibrato=0.01)
        add_at(out, env(concat(up, down), attack=0.02, decay=0.1, sustain=0.8, release=0.1), int(t * RATE), 0.35)
    return shot(finish(out), fade_out=0.2)


def time_up():
    out = silence(1.5)
    for k, (a, b) in enumerate(((67, 66), (64, 63), (60, 55))):
        length = 0.3 if k < 2 else 0.8
        add_at(out, env(tone("square", midi(a), length, to=midi(b)), decay=0.05, sustain=0.7, release=0.1),
               int(k * 0.32 * RATE))
    return shot(finish(out))


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
    "sfx/skid.wav": skid,
    "sfx/offroad.wav": offroad,
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
    "music/music_race.wav": music_race,
    "sfx/crowd.wav": crowd,  # last, so the shared random stream leaves the others as they were
}


def main():
    project = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..")
    for name, make in FILES.items():
        path = os.path.join(project, "assets", "audio", name)
        sig = make()
        write(path, sig)
        print("wrote %s (%.2f s)" % (os.path.relpath(path, project), len(sig) / RATE))


if __name__ == "__main__":
    main()
