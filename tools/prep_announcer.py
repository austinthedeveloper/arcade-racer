#!/usr/bin/env python3
"""The announcer's recordings into the game (docs/announcer/VOICE.md).

Reads every vo_<id>.wav in a folder of recordings (docs/announcer/lines.csv names them),
trims the silence, levels the voiced part to one loudness with peaks under -1 dBFS, resamples
to 24 kHz mono 16-bit, and writes the lines the race says today (Announcer.LINES) over their
placeholders in assets/audio/sfx/. The "to wire" lines are left where they are, and listed.

Run: python3 tools/prep_announcer.py <recordings> [--dry-run] [--all-to=<folder>]
  --dry-run       say what it would write, write nothing
  --all-to=DIR    also write every prepared line, said or not, into DIR (to listen to them)
Needs numpy and scipy (pip install -r tools/requirements.txt).
"""
import os
import sys
import wave

import numpy as np
from scipy.signal import resample_poly

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import announcer_script  # noqa: E402

ROOT = announcer_script.ROOT
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
RATE = 24000
TARGET_RMS_DB = -18.0  # the voiced part's loudness (about where the placeholders sit)
PEAK_DB = -1.0
GATE_DB = -45.0  # quieter than this, at the ends, is silence to trim
LEAD_S = 0.03  # kept before the first sound and after the last
TAIL_S = 0.06


def read(path):
    """(samples as float mono, rate) from a 16- or 24-bit PCM WAV."""
    with wave.open(path) as w:
        rate, width, channels = w.getframerate(), w.getsampwidth(), w.getnchannels()
        raw = w.readframes(w.getnframes())
    if width == 2:
        x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    elif width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        x = np.where(v >= 1 << 23, v - (1 << 24), v).astype(np.float64) / float(1 << 23)
    else:
        raise ValueError("%s: %d-bit WAV; record 16-bit" % (path, width * 8))
    return x.reshape(-1, channels).mean(axis=1), rate


def to_rate(x, rate):
    if rate == RATE:
        return x
    g = np.gcd(rate, RATE)
    return resample_poly(x, RATE // g, rate // g)


def db(v):
    return 20.0 * np.log10(max(v, 1e-12))


def trim(x):
    """The voiced part, LEAD_S before its first sound to TAIL_S after its last (10 ms windows)."""
    win = RATE // 100
    n = len(x) // win
    if n == 0:
        return x
    levels = np.sqrt((x[: n * win].reshape(n, win) ** 2).mean(axis=1))
    loud = np.nonzero(levels > 10 ** (GATE_DB / 20.0))[0]
    if loud.size == 0:
        return x[:0]
    a = max(0, loud[0] * win - int(LEAD_S * RATE))
    b = min(len(x), (loud[-1] + 1) * win + int(TAIL_S * RATE))
    return x[a:b]


def level(x):
    """Brings the voiced windows' RMS to TARGET_RMS_DB, then soft-limits the peaks under PEAK_DB."""
    win = RATE // 100
    n = len(x) // win
    if n == 0:
        return x
    levels = np.sqrt((x[: n * win].reshape(n, win) ** 2).mean(axis=1))
    voiced = levels[levels > 10 ** (GATE_DB / 20.0) * 4]
    rms = np.sqrt((voiced ** 2).mean()) if voiced.size else np.sqrt((x ** 2).mean())
    x = x * 10 ** ((TARGET_RMS_DB - db(rms)) / 20.0)
    ceiling = 10 ** (PEAK_DB / 20.0)
    knee = ceiling * 0.7
    over = np.abs(x) > knee
    x[over] = np.sign(x[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(x[over]) - knee) / (ceiling - knee)))
    # A short fade at each end so a trim never clicks.
    f = min(len(x) // 2, int(0.005 * RATE))
    if f > 0:
        ramp = np.linspace(0.0, 1.0, f)
        x[:f] *= ramp
        x[-f:] *= ramp[::-1]
    return x


def write(path, x):
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def prepare(path):
    x, rate = read(path)
    return level(trim(to_rate(x, rate)))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        sys.exit(__doc__)
    src = args[0]
    dry = "--dry-run" in sys.argv
    all_to = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--all-to=")), "")
    script = {r["id"]: r for r in announcer_script.rows()}
    said = announcer_script.game_lines()
    wrote, kept, unknown, over = [], [], [], []
    for name in sorted(os.listdir(src)):
        if not (name.startswith("vo_") and name.endswith(".wav")):
            continue
        line_id = name[3:-4]
        if line_id not in script:
            unknown.append(name)
            continue
        x = prepare(os.path.join(src, name))
        seconds = len(x) / RATE
        if seconds > float(script[line_id]["max_seconds"]) + 0.25:
            over.append("%s %.2f s (most %s)" % (line_id, seconds, script[line_id]["max_seconds"]))
        if all_to and not dry:
            os.makedirs(all_to, exist_ok=True)
            write(os.path.join(all_to, name), x)
        if line_id in said:
            if not dry:
                write(os.path.join(SFX, name), x)
            wrote.append(line_id)
        else:
            kept.append(line_id)
    missing = sorted(set(said) - set(wrote))
    print("%s %d said lines into assets/audio/sfx/" % ("would write" if dry else "wrote", len(wrote)))
    if missing:
        print("  not recorded yet (the placeholder stays): " + ", ".join(missing))
    if kept:
        print("%d to-wire lines prepared, not in the game yet: %s" % (len(kept), ", ".join(kept)))
    if over:
        print("longer than the script allows (re-read faster?):\n  " + "\n  ".join(over))
    if unknown:
        print("not in docs/announcer/lines.csv (a typo in the name?): " + ", ".join(unknown))
    if wrote and not dry:
        print("then: godot --headless --path . --import")


if __name__ == "__main__":
    main()
