"""Reproduce Spark Stampede's original synthesized audio with Python's standard library.

No samples, MIDI files, sound fonts, libraries, or downloaded audio are used.
All melodies, voicings, rhythms and synthesis parameters are authored here.

Run (writes every WAV and assets/audio/manifest.json):  python tools/generate_audio.py
Verify the committed files read-only:                    python tools/generate_audio.py --verify
Prove byte-for-byte reproduction (renders to a temp dir): python tools/generate_audio.py --reproduce

Two generations live in this file:
* LEGACY (2026-10-25): catch/bank/dash/upgrade/round_reward + pop_meadow_loop.
  The code below is unchanged so those six files keep their original bytes.
* 2026-11 EXTENSION: fifteen gameplay/UI cues (44.1 kHz mono) and three arena
  loops with matching FINALE intensity layers (22.05 kHz; base stereo, finale
  mono). Music uses 22.05 kHz to keep the whole audio folder well under the
  15 MB budget; its 11.025 kHz Nyquist also enforces the no-harsh-treble rule.
"""
from __future__ import annotations

import argparse
from array import array
from collections import deque
import hashlib
from itertools import accumulate
import json
import math
import operator
from pathlib import Path
import random
import statistics
import struct
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio"
TAU = math.tau
SFX_RATE = 44100
MUSIC_RATE = 44100


# ---------------------------------------------------------------------------
# LEGACY GENERATION (2026-10-25). Do not edit: changing anything here changes
# the bytes of the six original files recorded in the manifest.
# ---------------------------------------------------------------------------
def midi(note: int) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def envelope(t: float, duration: float, attack: float = 0.006, decay: float = 6.0) -> float:
    """Rounded attack and a zero-valued tail prevent hard sample edges."""
    fade_in = min(1.0, t / attack)
    fade_out = min(1.0, max(0.0, duration - t) / min(0.025, duration / 4))
    return fade_in * fade_in * (3 - 2 * fade_in) * math.exp(-decay * t / duration) * fade_out


def mallet(t: float, frequency: float) -> float:
    return (math.sin(TAU * frequency * t)
            + 0.22 * math.sin(TAU * frequency * 2 * t) * math.exp(-9 * t)
            + 0.055 * math.sin(TAU * frequency * 3 * t) * math.exp(-14 * t)) / 1.275


def new_track(duration: float, rate: int, channels: int) -> list[array]:
    return [array("f", [0.0]) * round(duration * rate) for _ in range(channels)]


def note(track: list[array], rate: int, start: float, duration: float, pitch: int,
         gain: float, pan: float = 0.0, voice: str = "mallet", wrap: bool = False) -> None:
    frequency = midi(pitch)
    offset = round(start * rate)
    count = len(track[0])
    for i in range(round(duration * rate)):
        target = offset + i
        if target >= count and not wrap:
            break
        target %= count
        t = i / rate
        if voice == "pad":
            attack = min(1.0, t / 0.12)
            release = min(1.0, (duration - t) / 0.30)
            env = math.sin(attack * math.pi / 2) * math.sin(release * math.pi / 2)
            sound = (math.sin(TAU * frequency * t)
                     + 0.15 * math.sin(TAU * frequency * 2 * t)) / 1.15
        elif voice == "bass":
            env = envelope(t, duration, attack=0.012, decay=2.8)
            sound = (math.sin(TAU * frequency * t)
                     + 0.12 * math.sin(TAU * frequency * 2 * t)) / 1.12
        else:
            env = envelope(t, duration, decay=4.8)
            sound = mallet(t, frequency)
        value = sound * env * gain
        if len(track) == 1:
            track[0][target] += value
        else:
            track[0][target] += value * math.sqrt((1 - pan) / 2)
            track[1][target] += value * math.sqrt((1 + pan) / 2)


def noise_hit(track: list[array], rate: int, start: float, duration: float,
              gain: float, seed: int, kind: str, wrap: bool = False) -> None:
    rng = random.Random(seed)
    offset = round(start * rate)
    count = len(track[0])
    filtered = 0.0
    phase = 0.0
    for i in range(round(duration * rate)):
        target = offset + i
        if target >= count and not wrap:
            break
        target %= count
        t = i / rate
        white = rng.uniform(-1, 1)
        filtered = 0.72 * filtered + 0.28 * white
        if kind == "kick":
            frequency = 48 + 75 * math.exp(-32 * t)
            phase += TAU * frequency / rate
            value = math.sin(phase) * envelope(t, duration, attack=0.003, decay=7)
        elif kind == "brush":
            value = (filtered * 0.8 + math.sin(TAU * 185 * t) * 0.2) * envelope(t, duration, decay=7)
        else:
            # Airy but low-pass filtered: avoid sharp, high-volume hiss.
            value = filtered * envelope(t, duration, attack=0.004, decay=8)
        for channel in track:
            channel[target] += value * gain


def write_wav(name: str, track: list[array], rate: int, peak: float) -> Path:
    absolute_peak = max(abs(value) for channel in track for value in channel)
    scale = peak / absolute_peak if absolute_peak else 1.0
    # Use a bounded fixed peak; runtime mixer applies per-category volume independently.
    pcm = bytearray()
    for frame in zip(*track):
        for value in frame:
            sample = round(value * scale * 32767)
            pcm.extend(struct.pack("<h", max(-32767, min(32767, sample))))
    path = OUTPUT / name
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(len(track))
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(pcm)
    return path


def make_sfx() -> None:
    catch = new_track(0.34, SFX_RATE, 1)
    for start, pitch, gain in [(0.0, 79, 0.72), (0.055, 83, 0.46), (0.11, 86, 0.30)]:
        note(catch, SFX_RATE, start, 0.20, pitch, gain)
    write_wav("catch.wav", catch, SFX_RATE, 0.48)

    bank = new_track(0.85, SFX_RATE, 1)
    for i, pitch in enumerate([72, 76, 79, 84]):
        note(bank, SFX_RATE, i * 0.10, 0.43, pitch, 0.52)
    for pitch in [60, 64, 67]:
        note(bank, SFX_RATE, 0.30, 0.50, pitch, 0.16)
    write_wav("bank.wav", bank, SFX_RATE, 0.55)

    dash = new_track(0.30, SFX_RATE, 1)
    rng = random.Random(4815)
    filtered = 0.0
    phase = 0.0
    for i in range(len(dash[0])):
        t = i / SFX_RATE
        filtered = filtered * 0.88 + rng.uniform(-1, 1) * 0.12
        phase += TAU * (170 + 520 * (t / 0.30)) / SFX_RATE
        env = math.sin(math.pi * t / 0.30) ** 2 * math.exp(-5 * t)
        dash[0][i] = (filtered * 0.72 + math.sin(phase) * 0.10) * env
    write_wav("dash.wav", dash, SFX_RATE, 0.34)

    upgrade = new_track(1.10, SFX_RATE, 1)
    for i, pitch in enumerate([67, 72, 76, 79, 86]):
        note(upgrade, SFX_RATE, i * 0.11, 0.50, pitch, 0.45)
    for pitch in [60, 67, 72]:
        note(upgrade, SFX_RATE, 0.44, 0.62, pitch, 0.15)
    write_wav("upgrade.wav", upgrade, SFX_RATE, 0.55)

    reward = new_track(1.90, SFX_RATE, 1)
    for start, pitch in [(0.0, 72), (0.16, 76), (0.32, 79), (0.56, 81), (0.74, 79), (0.98, 84)]:
        note(reward, SFX_RATE, start, 0.62, pitch, 0.44)
    for pitch in [48, 60, 64, 67, 74]:
        note(reward, SFX_RATE, 0.98, 0.88, pitch, 0.12)
    write_wav("round_reward.wav", reward, SFX_RATE, 0.58)


def make_music() -> None:
    # 120 BPM, eight 4/4 bars = sixteen seconds. All trailing voices wrap into
    # the opening samples, preserving the steady-state reverb-free loop seam.
    track = new_track(16.0, MUSIC_RATE, 2)
    chords = [(60, 64, 67, 69), (57, 60, 64, 67), (53, 57, 60, 64), (55, 62, 67, 69)]
    basses = [36, 33, 29, 31]
    melodies = [
        [(0,76),(1.5,79),(2.5,81)],
        [(0.5,79),(2,76),(3.0,74)],
        [(0,76),(1.5,72),(3,74)],
        [(0.5,79),(2.5,74)],
        [(0,76),(1,79),(2.5,84)],
        [(0.5,83),(2,79),(3.0,76)],
        [(0,81),(1.5,79),(3,76)],
        [(0.5,74),(2,79),(3.25,74)],
    ]
    for bar in range(8):
        start = bar * 2.0
        chord = chords[bar % 4]
        for j, pitch in enumerate(chord):
            note(track, MUSIC_RATE, start, 2.45, pitch, 0.035, pan=-0.55 + j * 0.36, voice="pad", wrap=True)
        for beat in [0, 1.5, 2.5]:
            note(track, MUSIC_RATE, start + beat * 0.5, 0.40, basses[bar % 4], 0.24, voice="bass", wrap=True)
        for beat in [0, 2]:
            noise_hit(track, MUSIC_RATE, start + beat * 0.5, 0.20, 0.26, 100 + bar, "kick", wrap=True)
        for beat in [1, 3]:
            noise_hit(track, MUSIC_RATE, start + beat * 0.5, 0.13, 0.17, 200 + bar * 4 + beat, "brush", wrap=True)
        for step in range(8):
            noise_hit(track, MUSIC_RATE, start + step * 0.25, 0.065, 0.065 if step % 2 else 0.045,
                      300 + bar * 8 + step, "shaker", wrap=True)
        for step in [1, 3, 5, 7]:
            pitch = chord[(step + bar) % 4] + 12
            note(track, MUSIC_RATE, start + step * 0.25, 0.33, pitch, 0.052, pan=-0.4 if step % 4 == 1 else 0.4, wrap=True)
        for beat, pitch in melodies[bar]:
            note(track, MUSIC_RATE, start + beat * 0.5, 0.50, pitch, 0.135, pan=0.12, wrap=True)
    write_wav("pop_meadow_loop.wav", track, MUSIC_RATE, 0.48)


# ===========================================================================
# 2026-11 EXTENSION: original cue set + arena loops with finale layers.
# ===========================================================================
CUE_RATE = 44100
LOOP_RATE = 22050
PROVENANCE = "original, generated by tools/generate_audio.py, no third-party samples"
LEGACY_PROVENANCE = ("original, generated by tools/generate_audio.py (2026-10-25 legacy set), "
                     "no third-party samples")
PEAK_LIMIT_DBFS = -1.0        # hard rule for every file and for base+finale sums
MUSIC_CEILING_DBFS = -1.5     # mastering ceiling, leaves margin under the hard rule
CUE_LOWPASS_HZ = 9000.0
LOOP_LOWPASS_HZ = 8500.0
HF_SPLIT_HZ = 10000.0
HF_LIMIT_DB = -30.0           # energy above ~10 kHz must sit this far below full-band energy
DC_LIMIT = 0.002              # |mean| in full-scale units (new files)
LEGACY_DC_LIMIT = 0.005       # original 2026-10-25 bound, kept for the legacy set
BUDGET_BYTES = 15_000_000
BASE_GAP_DB = 8.7             # base loop RMS below the reference (median) cue peak
COMBINED_GAP_DB = 7.5         # base + finale RMS below the reference cue peak
GAP_WINDOW_DB = (6.0, 9.0)    # requested "music RMS roughly 6-9 dB below cue peaks"
LOOP_SECONDS = (16.0, 24.0)
BUTTER4_Q = (0.5411961001461970, 1.3065629648763766)

TABLE_SIZE = 8192
TABLE_MASK = TABLE_SIZE - 1


def log(message: str) -> None:
    # Progress goes to stderr: stdout carries only the manifest JSON + PASS marker
    # (tools/run_checks.ps1 parses everything before the last "PASS:" as JSON).
    print(message, file=sys.stderr, flush=True)


def to_db(value: float) -> float:
    return 20 * math.log10(value) if value > 0 else -200.0


def from_db(value: float) -> float:
    return 10 ** (value / 20)


def frames_for(seconds: float, rate: int) -> int:
    return max(1, round(seconds * rate))


# ---- oscillators and envelopes -------------------------------------------
_tables: dict = {}


def wavetable(shape: str, harmonics: int = 1) -> array:
    """Single-cycle band-limited table; harmonic count chosen by the caller."""
    key = (shape, harmonics)
    if key not in _tables:
        if shape == "saw":
            partials = [(k, 1 / k ** 1.5) for k in range(1, harmonics + 1)]
        elif shape == "square":
            partials = [(k, 1 / k ** 1.7) for k in range(1, harmonics + 1, 2)]
        elif shape == "organ":
            partials = [(k, a) for k, a in ((1, 1.0), (2, 0.45), (3, 0.22), (4, 0.12), (6, 0.05)) if k <= harmonics]
        else:
            partials = [(1, 1.0)]
        values = [sum(a * math.sin(TAU * k * i / TABLE_SIZE) for k, a in partials) for i in range(TABLE_SIZE)]
        top = max(abs(v) for v in values)
        _tables[key] = array("d", [v / top for v in values])
    return _tables[key]


def harmonics_for(frequency: float, ceiling: float = 7000.0, cap: int = 12) -> int:
    return max(1, min(cap, int(ceiling // max(frequency, 1.0))))


def phase_indices(n: int, rate: int, frequency: float, glide: tuple | None = None,
                  vibrato: tuple | None = None, phase: float = 0.0) -> list[int]:
    """Table indices for a pitch that may glide (start_ratio, tau_s) and wobble (rate_hz, depth)."""
    step = frequency * TABLE_SIZE / rate
    start = phase * TABLE_SIZE
    if glide is None and vibrato is None:
        return [int(start + i * step) & TABLE_MASK for i in range(n)]
    increments = [step] * n
    if glide is not None:
        ratio, tau = glide
        k = -1.0 / (tau * rate)
        increments = [step * (1 + (ratio - 1) * math.exp(k * i)) for i in range(n)]
    if vibrato is not None:
        speed, depth = vibrato
        w = TAU * speed / rate
        increments = [inc * (1 + depth * math.sin(w * i)) for i, inc in enumerate(increments)]
    return [int(p) & TABLE_MASK for p in accumulate(increments, initial=start)][:n]


def lookup(table: array, indices: list[int]) -> list[float]:
    return [table[j] for j in indices]


def env_shape(n: int, rate: int, attack: float = 0.004, tau: float | None = None,
              release: float = 0.02) -> list[float]:
    """Smoothstep attack, optional exponential decay, smoothstep release to an exact zero."""
    if tau:
        k = -1.0 / (tau * rate)
        env = [math.exp(k * i) for i in range(n)]
    else:
        env = [1.0] * n
    a = max(1, round(attack * rate))
    for i in range(min(a, n)):
        x = i / a
        env[i] *= x * x * (3 - 2 * x)
    r = max(1, round(release * rate))
    for j in range(min(r, n)):
        x = j / r
        env[n - 1 - j] *= x * x * (3 - 2 * x)
    return env


def times(a: list[float], b: list[float]) -> list[float]:
    return [x * y for x, y in zip(a, b)]


def noise(n: int, seed: int) -> list[float]:
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def onepole_lp(x: list[float], cutoff: float, rate: int) -> list[float]:
    a = math.exp(-TAU * cutoff / rate)
    b = 1.0 - a
    y = 0.0
    out = [0.0] * len(x)
    for i, v in enumerate(x):
        y = b * v + a * y
        out[i] = y
    return out


def onepole_hp(x: list[float], cutoff: float, rate: int) -> list[float]:
    return [v - l for v, l in zip(x, onepole_lp(x, cutoff, rate))]


# ---- biquad filters (RBJ cookbook) -----------------------------------------
def biquad_coeffs(kind: str, cutoff: float, rate: int, q: float) -> tuple:
    w0 = TAU * cutoff / rate
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2 * q)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    else:
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    return b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0


def biquad_run(x, coeffs: tuple, state: tuple = (0.0, 0.0, 0.0, 0.0)) -> tuple[list[float], tuple]:
    b0, b1, b2, a1, a2 = coeffs
    x1, x2, y1, y2 = state
    out = [0.0] * len(x)
    for i, v in enumerate(x):
        y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, y
        out[i] = y
    return out, (x1, x2, y1, y2)


def filter_chain(x: list[float], stages: list[tuple], circular: bool) -> list[float]:
    """Apply biquads in series. Circular mode primes each stage with the loop's own
    tail so the filtered loop is periodic (no seam transient)."""
    for coeffs in stages:
        state = (0.0, 0.0, 0.0, 0.0)
        if circular:
            _, state = biquad_run(x[-8192:], coeffs)
        x, _ = biquad_run(x, coeffs, state)
    return x


def lowpass4(cutoff: float, rate: int) -> list[tuple]:
    return [biquad_coeffs("lp", cutoff, rate, q) for q in BUTTER4_Q]


def highpass2(cutoff: float, rate: int) -> list[tuple]:
    return [biquad_coeffs("hp", cutoff, rate, math.sqrt(0.5))]


# ---- instrument voices (all original synthesis) ----------------------------
def v_bell(rate, frequency, duration, tau, bright):
    n = frames_for(duration, rate)
    out = [0.0] * n
    for ratio, amp, scale in ((1.0, 1.0, 1.0), (2.0, 0.28 * bright, 0.55), (3.01, 0.12 * bright, 0.35),
                              (4.17, 0.07 * bright, 0.22)):
        f = frequency * ratio
        if f > 8000.0 or amp <= 0:
            continue
        k = -1.0 / (tau * scale * rate)
        wave_ = lookup(wavetable("sine"), phase_indices(n, rate, f))
        out = [o + amp * w * math.exp(k * i) for i, (o, w) in enumerate(zip(out, wave_))]
    return times(out, env_shape(n, rate, attack=0.002, release=min(0.03, duration / 4)))


def v_epiano(rate, frequency, duration, tau):
    """Two-operator phase-modulation electric piano with a short soft 'tine'."""
    n = frames_for(duration, rate)
    sine = wavetable("sine")
    step = frequency * TABLE_SIZE / rate
    depth = 1.5 * min(1.0, 600.0 / frequency)
    k_index = -1.0 / (0.09 * rate)
    scale = TABLE_SIZE / TAU
    modulator = [sine[int(i * step) & TABLE_MASK] for i in range(n)]
    out = [sine[int(i * step + (depth * math.exp(k_index * i) + 0.12) * m * scale) & TABLE_MASK]
           for i, m in enumerate(modulator)]
    if frequency * 7 < 8000.0:
        k_tine = -1.0 / (0.02 * rate)
        tine = lookup(sine, phase_indices(n, rate, frequency * 7))
        out = [o + 0.12 * t * math.exp(k_tine * i) for i, (o, t) in enumerate(zip(out, tine))]
    return times(out, env_shape(n, rate, attack=0.003, tau=tau, release=min(0.04, duration / 4)))


def v_pad(rate, frequency, duration, attack, release, shape, bright):
    n = frames_for(duration, rate)
    table = wavetable(shape, harmonics_for(frequency, 3500.0 * bright, 8))
    out = [0.0] * n
    for ratio, phase in ((1.0, 0.0), (1.0058, 0.31), (0.9943, 0.67)):
        w = lookup(table, phase_indices(n, rate, frequency * ratio, phase=phase))
        out = [o + x for o, x in zip(out, w)]
    env = env_shape(n, rate, attack=attack, release=release)
    return [o * e / 3 for o, e in zip(out, env)]


def v_bass(rate, frequency, duration, tau, slap):
    n = frames_for(duration, rate)
    sine = wavetable("sine")
    idx = phase_indices(n, rate, frequency)
    k = -1.0 / ((0.025 if slap else 0.06) * rate)
    bite = 0.40 if slap else 0.18
    out = [sine[j] + 0.30 * sine[(2 * j) & TABLE_MASK] + (0.10 + bite * math.exp(k * i)) * sine[(3 * j) & TABLE_MASK]
           + (bite * 0.5 * math.exp(k * i) * sine[(5 * j) & TABLE_MASK] if slap else 0.0)
           for i, j in enumerate(idx)]
    return times(out, env_shape(n, rate, attack=0.004, tau=tau, release=min(0.025, duration / 4)))


def v_lead(rate, frequency, duration, harmonics):
    n = frames_for(duration, rate)
    table = wavetable("square", min(harmonics, harmonics_for(frequency, 4000.0, 9)))
    w = lookup(table, phase_indices(n, rate, frequency, vibrato=(5.2, 0.0035)))
    return times(w, env_shape(n, rate, attack=0.02, tau=2.5, release=min(0.07, duration / 3)))


def v_brass(rate, frequency, duration):
    """Round, friendly horn: sine/soft-saw blend whose brightness swells then mellows."""
    n = frames_for(duration, rate)
    idx = phase_indices(n, rate, frequency, vibrato=(5.0, 0.003))
    saw = lookup(wavetable("saw", harmonics_for(frequency, 3200.0, 10)), idx)
    sine = lookup(wavetable("sine"), idx)
    k1, k2 = -1.0 / (0.03 * rate), -1.0 / (0.25 * rate)
    out = [s + (w - s) * (0.25 + 0.5 * (1 - math.exp(k1 * i)) * math.exp(k2 * i))
           for i, (s, w) in enumerate(zip(sine, saw))]
    return times(out, env_shape(n, rate, attack=0.025, release=min(0.08, duration / 3)))


def v_pluck(rate, frequency, duration, seed, damp):
    """Karplus-Strong plucked string from a seeded, mean-free, softened burst."""
    n = frames_for(duration, rate)
    length = max(2, round(rate / frequency))
    burst = onepole_lp(noise(length, seed), 2000.0, rate)
    mean = sum(burst) / length
    buf = [v - mean for v in burst]
    out = [0.0] * n
    pos = 0
    for i in range(n):
        current = buf[pos]
        out[i] = current
        buf[pos] = damp * 0.5 * (current + buf[(pos + 1) % length])
        pos = (pos + 1) % length
    return times(out, env_shape(n, rate, attack=0.003, release=min(0.02, duration / 4)))


def v_kick(rate, duration, f_start, f_end, tau_pitch, tau_amp):
    n = frames_for(duration, rate)
    k = -1.0 / (tau_pitch * rate)
    sine = wavetable("sine")
    incs = [(f_end + (f_start - f_end) * math.exp(k * i)) * TABLE_SIZE / rate for i in range(n)]
    body = [sine[int(p) & TABLE_MASK] for p in accumulate(incs, initial=0.0)][:n]
    click = onepole_lp(noise(n, 9001), 2500.0, rate)
    k_click = -1.0 / (0.003 * rate)
    out = [b + 0.25 * c * math.exp(k_click * i) for i, (b, c) in enumerate(zip(body, click))]
    return times(out, env_shape(n, rate, attack=0.0015, tau=tau_amp, release=0.01))


def v_snare(rate, seed, duration, tone, clap):
    n = frames_for(duration, rate)
    hiss = onepole_hp(onepole_lp(noise(n, seed), 4500.0, rate), 900.0, rate)
    if clap:
        bursts = [0.0, 0.011, 0.022]
        k_b, k_t = -1.0 / (0.006 * rate), -1.0 / (0.07 * rate)
        env = [sum(math.exp(k_b * (i - round(b * rate))) for b in bursts if i >= round(b * rate)) * 0.6
               + (math.exp(k_t * (i - round(0.022 * rate))) if i >= round(0.022 * rate) else 0.0)
               for i in range(n)]
        out = [h * e for h, e in zip(hiss, env)]
    else:
        k_n, k_b = -1.0 / (0.07 * rate), -1.0 / (0.05 * rate)
        body = lookup(wavetable("sine"), phase_indices(n, rate, tone))
        out = [h * math.exp(k_n * i) + 0.5 * b * math.exp(k_b * i) for i, (h, b) in enumerate(zip(hiss, body))]
    return times(out, env_shape(n, rate, attack=0.001, release=min(0.03, duration / 4)))


def v_hat(rate, seed, duration, tau, low, high):
    n = frames_for(duration, rate)
    band = onepole_lp(onepole_hp(noise(n, seed), low, rate), high, rate)
    return times(band, env_shape(n, rate, attack=0.001 if tau < 0.03 else 0.008, tau=tau,
                                 release=min(0.015, duration / 4)))


def v_tom(rate, frequency, duration, tau):
    n = frames_for(duration, rate)
    w = lookup(wavetable("sine"), phase_indices(n, rate, frequency, glide=(1.6, 0.04)))
    return times(w, env_shape(n, rate, attack=0.0015, tau=tau, release=min(0.02, duration / 4)))


def v_block(rate, frequency, duration):
    n = frames_for(duration, rate)
    sine = wavetable("sine")
    a = lookup(sine, phase_indices(n, rate, frequency))
    b = lookup(sine, phase_indices(n, rate, frequency * 2.76))
    k1, k2 = -1.0 / (0.03 * rate), -1.0 / (0.012 * rate)
    out = [x * math.exp(k1 * i) + 0.45 * y * math.exp(k2 * i) for i, (x, y) in enumerate(zip(a, b))]
    return times(out, env_shape(n, rate, attack=0.001, release=min(0.01, duration / 4)))


def v_whoosh(rate, seed, duration, low, high):
    """Seeded noise through a rising one-pole low-pass with a bell-shaped swell."""
    n = frames_for(duration, rate)
    out = [0.0] * n
    y = 0.0
    for i, v in enumerate(noise(n, seed)):
        x = i / n
        a = math.exp(-TAU * (low + (high - low) * x) / rate)
        y = (1 - a) * v + a * y
        out[i] = y * math.sin(math.pi * x) ** 2
    return out


VOICES = {"bell": v_bell, "epiano": v_epiano, "pad": v_pad, "bass": v_bass, "lead": v_lead,
          "brass": v_brass, "pluck": v_pluck, "kick": v_kick, "snare": v_snare, "hat": v_hat,
          "tom": v_tom, "block": v_block}
_voice_cache: dict = {}


def voice(kind: str, *args) -> array:
    """Render (or reuse) one note. Arguments are rounded so equal notes share a render."""
    key = (kind,) + tuple(round(a, 6) if isinstance(a, float) else a for a in args)
    cached = _voice_cache.get(key)
    if cached is None:
        cached = array("d", VOICES[kind](*key[1:]))
        _voice_cache[key] = cached
    return cached


# ---- mixing ---------------------------------------------------------------
class Bus:
    """Float mix buffer. wrap=True makes every note tail fold into the start (loops)."""

    def __init__(self, length: int, rate: int, channels: int, wrap: bool):
        self.length, self.rate, self.wrap = length, rate, wrap
        self.ch = [array("d", bytes(8 * length)) for _ in range(channels)]

    def add(self, src, start: float, gain: float, pan: float = 0.0) -> None:
        count, n = self.length, len(src)
        offset = round(start * self.rate)
        if self.wrap:
            offset %= count
        elif offset >= count:
            return
        if len(self.ch) == 1:
            gains = (gain,)
        else:
            angle = (max(-1.0, min(1.0, pan)) + 1) * math.pi / 4
            gains = (gain * math.cos(angle), gain * math.sin(angle))
        pos = 0
        while pos < n:
            o = (offset + pos) % count if self.wrap else offset + pos
            if o >= count:
                break
            take = min(n - pos, count - o)
            part = src[pos:pos + take]
            for channel, g in zip(self.ch, gains):
                channel[o:o + take] = array("d", [a + g * b for a, b in zip(channel[o:o + take], part)])
            pos += take


def mean_square(channels) -> float:
    total = sum(sum(v * v for v in ch) for ch in channels)
    return total / sum(len(ch) for ch in channels)


def duck(bus: Bus, starts: list[float], depth: float, release: float, attack: float = 0.004) -> None:
    """Loop-safe sidechain-style ducking: dip the bus smoothly at each kick so kick
    and bass/pads do not stack into large peaks (a standard pop-mix technique)."""
    count, rate = bus.length, bus.rate
    curve = [1.0] * count
    lead_in = max(1, round(attack * rate))
    k = -1.0 / (release * rate)
    span = round(5 * release * rate)
    for start in starts:
        origin = round(start * rate) - lead_in
        for i in range(lead_in + span):
            if i < lead_in:
                x = i / lead_in
                amount = depth * x * x * (3 - 2 * x)
            else:
                amount = depth * math.exp(k * (i - lead_in))
            j = (origin + i) % count
            if 1.0 - amount < curve[j]:
                curve[j] = 1.0 - amount
    for channel in bus.ch:
        channel[:] = array("d", [v * c for v, c in zip(channel, curve)])


def pingpong(bus: Bus, delay: float, feedback: float, taps: int) -> None:
    """Circular ping-pong echo (loop-safe): tap k is the bus delayed k*delay, alternating sides."""
    count = bus.length
    d = round(delay * bus.rate)
    dry = [sum(frame) for frame in zip(*bus.ch)] if len(bus.ch) > 1 else list(bus.ch[0])
    for k in range(1, taps + 1):
        shift = (k * d) % count
        delayed = dry[count - shift:] + dry[:count - shift]
        g = feedback ** k
        sides = (0.3, 0.7) if k % 2 else (0.7, 0.3)
        for channel, side in zip(bus.ch, sides if len(bus.ch) > 1 else (1.0,)):
            channel[:] = array("d", [a + g * side * b for a, b in zip(channel, delayed)])


# ---- cue mastering ----------------------------------------------------------
def finish_cue(samples, peak_dbfs: float, highpass_hz: float = 30.0) -> list[float]:
    x = filter_chain(list(samples), highpass2(highpass_hz, CUE_RATE) + lowpass4(CUE_LOWPASS_HZ, CUE_RATE), False)
    n = len(x)
    fade_in, fade_out = round(0.0005 * CUE_RATE), round(0.004 * CUE_RATE)
    for i in range(fade_in):
        x[i] *= i / fade_in
    for j in range(fade_out):
        x[n - 1 - j] *= j / fade_out
    peak = max(abs(v) for v in x)
    scale = from_db(peak_dbfs) / peak
    return [v * scale for v in x]


def write_pcm(path: Path, channels: list, rate: int) -> None:
    frames = len(channels[0])
    pcm = array("h", bytes(2 * frames * len(channels)))
    for c, channel in enumerate(channels):
        quantized = [round(v * 32767) for v in channel]
        worst = max(abs(q) for q in quantized)
        if worst > 32767 * from_db(PEAK_LIMIT_DBFS):
            raise RuntimeError(f"{path.name}: rendered peak {worst} exceeds the -1 dBFS rule")
        pcm[c::len(channels)] = array("h", quantized)
    if sys.byteorder == "big":
        pcm.byteswap()
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(len(channels))
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(pcm.tobytes())


# ---- cue compositions (44.1 kHz mono) --------------------------------------
R = CUE_RATE


def cue_bus(seconds: float) -> Bus:
    return Bus(frames_for(seconds, R), R, 1, wrap=False)


def cue_zap():
    # Friendly cartoon "bwoo-oop": a descending wobbly tone, no harsh buzz.
    bus = cue_bus(0.46)
    n = frames_for(0.42, R)
    sine, square = wavetable("sine"), wavetable("square", 7)
    env = env_shape(n, R, attack=0.004, tau=0.16, release=0.05)
    for frequency, gain in ((300.0, 0.9), (450.0, 0.35)):
        idx = phase_indices(n, R, frequency, glide=(3.0, 0.11), vibrato=(13.0, 0.03))
        bus.add(times([0.7 * sine[j] + 0.3 * square[j] for j in idx], env), 0.0, gain)
    bus.add(v_hat(R, 11, 0.06, 0.02, 2500.0, 7000.0), 0.0, 0.15)
    return bus.ch[0]


def cue_pop():
    # Bubble "bloop": a quick upward sine sweep with a tiny low thump.
    bus = cue_bus(0.20)
    n = frames_for(0.17, R)
    idx = phase_indices(n, R, 1050.0, glide=(0.3, 0.018))
    bus.add(times(lookup(wavetable("sine"), idx), env_shape(n, R, attack=0.002, tau=0.045, release=0.03)), 0.0, 1.0)
    bus.add(v_tom(R, 220.0, 0.08, 0.03), 0.0, 0.3)
    return bus.ch[0]


def cue_gate_open():
    bus = cue_bus(1.30)
    for i, pitch in enumerate([72, 76, 79, 84, 88, 91]):
        bus.add(v_bell(R, midi(pitch), 0.70, 0.32, 0.6), i * 0.055, 0.55 - i * 0.04)
    for j, pitch in enumerate([72, 76, 79, 83]):
        bus.add(v_pad(R, midi(pitch), 1.05, 0.25, 0.45, "saw", 0.8), 0.18 + j * 0.01, 0.10)
    bus.add(v_whoosh(R, 21, 0.70, 500.0, 3500.0), 0.0, 0.5)
    return bus.ch[0]


def cue_golden_spawn():
    bus = cue_bus(1.50)
    for i, pitch in enumerate([67, 69, 72, 74, 76, 79, 81, 84, 86, 88]):
        bus.add(v_bell(R, midi(pitch), 0.50, 0.25, 0.5), i * 0.036, 0.42 - i * 0.008)
    for pitch in [84, 86, 88, 91]:
        bus.add(v_bell(R, midi(pitch), 1.0, 0.6, 0.6), 0.40, 0.26)
    for pitch in [60, 67, 76]:
        bus.add(v_pad(R, midi(pitch), 0.95, 0.35, 0.45, "saw", 0.7), 0.35, 0.12)
    rng = random.Random(77)
    for _ in range(7):
        bus.add(v_bell(R, midi(rng.choice([96, 98, 100, 103])), 0.25, 0.12, 0.3), rng.uniform(0.5, 1.2), 0.12)
    return bus.ch[0]


def cue_golden_catch():
    bus = cue_bus(1.10)
    for pitch in [84, 88, 91]:
        bus.add(v_bell(R, midi(pitch), 0.90, 0.38, 0.7), 0.0, 0.42)
    for pitch in [72, 76, 79]:
        bus.add(v_epiano(R, midi(pitch), 0.80, 0.45), 0.0, 0.22)
    for i, pitch in enumerate([88, 91, 96]):
        bus.add(v_bell(R, midi(pitch), 0.60, 0.25, 0.5), 0.07 + i * 0.06, 0.30)
    bus.add(v_bass(R, midi(48), 0.45, 0.18, False), 0.0, 0.35)
    return bus.ch[0]


def cue_stampede_rumble():
    # Distant galloping herd: low filtered noise bed and soft triplet hoof thumps.
    seconds = 2.80
    bus = cue_bus(seconds)
    n = bus.length
    bed = onepole_lp(onepole_lp(noise(n, 4242), 160.0, R), 160.0, R)
    swell = [min(1.0, i / (0.7 * R)) * min(1.0, max(0.0, (n - i) / (0.9 * R))) for i in range(n)]
    bus.add([b * math.sin(s * math.pi / 2) ** 2 for b, s in zip(bed, swell)], 0.0, 5.0)
    rng = random.Random(99)
    t = 0.12
    while t < 2.35:
        shape = math.sin(math.pi * min(1.0, t / 2.45)) ** 0.8
        for dt, g in ((0.0, 0.55), (0.085, 0.70), (0.17, 1.0)):
            bus.add(v_kick(R, 0.22, 105.0, 52.0, 0.03, 0.07), t + dt + rng.uniform(-0.006, 0.006), 0.5 * g * shape)
        t += 0.36
    return bus.ch[0]


def cue_chain_tier():
    bus = cue_bus(0.55)
    for i, pitch in enumerate([79, 83, 86]):
        bus.add(v_bell(R, midi(pitch), 0.45 if i < 2 else 0.50, 0.20 if i < 2 else 0.28, 0.6), i * 0.055, 0.5)
    bus.add(v_bell(R, midi(91), 0.30, 0.12, 0.3), 0.165, 0.12)
    return bus.ch[0]


def cue_countdown():
    bus = cue_bus(0.22)
    n = frames_for(0.20, R)
    sine = wavetable("sine")
    tone = [sine[j] + 0.12 * sine[(2 * j) & TABLE_MASK] for j in phase_indices(n, R, 880.0)]
    bus.add(times(tone, env_shape(n, R, attack=0.008, tau=0.5, release=0.06)), 0.0, 1.0)
    return bus.ch[0]


def cue_start_whistle():
    # Friendly two-tone "tweet-tweeet" with gentle vibrato and a little breath.
    bus = cue_bus(0.80)
    sine = wavetable("sine")
    for start, seconds, frequency in ((0.0, 0.16, 1046.5), (0.21, 0.55, 1396.9)):
        n = frames_for(seconds, R)
        idx = phase_indices(n, R, frequency, glide=(0.93, 0.02), vibrato=(6.5, 0.012))
        tone = [sine[j] + 0.10 * sine[(2 * j) & TABLE_MASK] for j in idx]
        bus.add(times(tone, env_shape(n, R, attack=0.012, release=0.05)), start, 0.8)
        breath = onepole_lp(onepole_hp(noise(n, 5150 + n), 1000.0, R), 3000.0, R)
        bus.add(times(breath, env_shape(n, R, attack=0.01, release=0.04)), start, 0.12)
    return bus.ch[0]


def cue_buzzer():
    # Round-end horn: warm major chord "toot-tooot", soft attack, no rasp.
    bus = cue_bus(0.95)
    for start, seconds in ((0.0, 0.20), (0.27, 0.66)):
        for pitch in [53, 57, 60]:
            bus.add(v_brass(R, midi(pitch), seconds), start, 0.33)
    bus.add(v_bass(R, midi(41), 0.62, 0.5, False), 0.27, 0.25)
    return bus.ch[0]


def cue_rank_up():
    bus = cue_bus(1.60)
    for start in (0.0, 0.12, 0.24):
        bus.add(v_brass(R, midi(67), 0.10), start, 0.45)
    for pitch, gain in ((72, 0.45), (67, 0.25), (64, 0.25)):
        bus.add(v_brass(R, midi(pitch), 0.90), 0.36, gain)
    for i, pitch in enumerate([84, 88, 91, 96]):
        bus.add(v_bell(R, midi(pitch), 0.70, 0.30, 0.5), 0.36 + i * 0.05, 0.22)
    bus.add(v_tom(R, midi(48), 0.40, 0.15), 0.36, 0.4)
    return bus.ch[0]


def cue_ui_click():
    bus = cue_bus(0.07)
    n = frames_for(0.06, R)
    sine = wavetable("sine")
    hi = times(lookup(sine, phase_indices(n, R, 1500.0)), env_shape(n, R, attack=0.0006, tau=0.010, release=0.01))
    lo = times(lookup(sine, phase_indices(n, R, 750.0)), env_shape(n, R, attack=0.0006, tau=0.016, release=0.01))
    bus.add(hi, 0.0, 1.0)
    bus.add(lo, 0.0, 0.6)
    return bus.ch[0]


def cue_ui_claim():
    bus = cue_bus(0.60)
    bus.add(v_bell(R, midi(83), 0.30, 0.12, 0.5), 0.0, 0.45)
    bus.add(v_bell(R, midi(88), 0.50, 0.25, 0.5), 0.075, 0.50)
    bus.add(v_epiano(R, midi(76), 0.40, 0.3), 0.075, 0.20)
    bus.add(v_bell(R, midi(95), 0.30, 0.10, 0.3), 0.15, 0.10)
    return bus.ch[0]


def cue_signature():
    bus = cue_bus(0.90)
    for i, pitch in enumerate([100, 96, 93, 91, 88, 84]):
        bus.add(v_bell(R, midi(pitch), 0.40, 0.15, 0.4), i * 0.04, 0.32)
    for pitch in [81, 85, 88]:
        bus.add(v_bell(R, midi(pitch), 0.60, 0.40, 0.5), 0.22, 0.28)
    rng = random.Random(31)
    for _ in range(6):
        bus.add(v_bell(R, midi(rng.choice([96, 100, 103])), 0.20, 0.08, 0.3), rng.uniform(0.30, 0.68), 0.10)
    return bus.ch[0]


def cue_starstruck():
    bus = cue_bus(1.00)
    for i in range(11):
        bus.add(v_bell(R, midi(88 if i % 2 == 0 else 95), 0.25, 0.09, 0.4), i * 0.07, 0.42 * 0.82 ** i)
    for pitch in [76, 80, 83]:
        bus.add(v_pad(R, midi(pitch), 0.90, 0.10, 0.40, "saw", 0.6), 0.0, 0.08)
    return bus.ch[0]


# key, file, purpose, max seconds, target peak dBFS, builder, high-pass Hz
CUES = [
    ("zap", "zap.wav", "Hazard zap: friendly descending wobble", 2.0, -5.0, cue_zap, 30.0),
    ("pop", "pop.wav", "Bubble/target pop", 2.0, -4.5, cue_pop, 30.0),
    ("gate_open", "gate_open.wav", "Spark Gate opens: rising bell arpeggio + airy swell", 2.0, -5.0, cue_gate_open, 30.0),
    ("golden_spawn", "golden_spawn.wav", "Golden Spark appears: shimmering run + chord", 2.0, -5.0, cue_golden_spawn, 30.0),
    ("golden_catch", "golden_catch.wav", "Golden Spark caught: bright bell chord + flourish", 2.0, -3.5, cue_golden_catch, 30.0),
    ("stampede_rumble", "stampede_rumble.wav", "Stampede Run warning: soft galloping rumble", 3.0, -6.0,
     cue_stampede_rumble, 45.0),
    ("chain_tier", "chain_tier.wav", "Chain multiplier tier up: short rising chime", 2.0, -5.0, cue_chain_tier, 30.0),
    # Sustained tones sound louder than percussive cues at equal peak: peaks set lower.
    ("countdown", "countdown.wav", "Countdown tick: single soft beep", 2.0, -8.0, cue_countdown, 30.0),
    ("start_whistle", "start_whistle.wav", "Round start: friendly two-tone whistle", 2.0, -8.0, cue_start_whistle, 30.0),
    ("buzzer", "buzzer.wav", "Round end: warm friendly horn", 2.0, -5.0, cue_buzzer, 30.0),
    ("rank_up", "rank_up.wav", "Rank/level up: short fanfare", 2.0, -3.5, cue_rank_up, 30.0),
    ("ui_click", "ui_click.wav", "UI button click: soft tick", 2.0, -9.0, cue_ui_click, 30.0),
    ("ui_claim", "ui_claim.wav", "Reward/quest claim: two-note chime", 2.0, -5.0, cue_ui_claim, 30.0),
    ("signature", "signature.wav", "Signature move accent: sparkle cascade", 2.0, -5.0, cue_signature, 30.0),
    ("starstruck", "starstruck.wav", "Starstruck twinkle", 2.0, -6.0, cue_starstruck, 30.0),
]


# ---- arena music (22.05 kHz; base stereo + finale mono, same length) ---------
class Song:
    def __init__(self, bpm: int, bars: int):
        self.bpm, self.bars, self.rate = bpm, bars, LOOP_RATE
        self.beat = 60.0 / bpm
        exact = bars * 4 * 60 * LOOP_RATE / bpm
        if abs(exact - round(exact)) > 1e-9:
            raise ValueError("loop length must be an exact number of samples")
        self.length = round(exact)
        self.stems: dict = {}

    def stem(self, layer: str, name: str, rel_db: float, drive: float = 0.0) -> Bus:
        """drive > 0 gently saturates a percussion stem (tanh) to tame its transient
        crest factor so the master stage needs little limiting. Never used on
        melodic stems."""
        bus = Bus(self.length, self.rate, 2 if layer == "base" else 1, wrap=True)
        self.stems[(layer, name)] = (bus, rel_db, drive)
        return bus

    def at(self, bar: int, beat: float) -> float:
        return (bar * 4 + beat) * self.beat

    def layer(self, layer: str) -> list:
        """Sum stems after scaling each to its relative RMS target (measured, not guessed)."""
        channels = 2 if layer == "base" else 1
        out = [array("d", bytes(8 * self.length)) for _ in range(channels)]
        for (stem_layer, name), (bus, rel_db, drive) in self.stems.items():
            if stem_layer != layer:
                continue
            if drive > 0:
                top = max(max(abs(v) for v in ch) for ch in bus.ch)
                norm = math.tanh(drive)
                for ch in bus.ch:
                    ch[:] = array("d", [math.tanh(drive * v / top) / norm for v in ch])
            power = mean_square(bus.ch)
            if power <= 0:
                raise RuntimeError(f"silent stem {layer}/{name}")
            g = from_db(rel_db) / math.sqrt(power)
            for o, ch in zip(out, bus.ch):
                o[:] = array("d", [a + g * b for a, b in zip(o, ch)])
        stages = highpass2(30.0, self.rate) + lowpass4(LOOP_LOWPASS_HZ, self.rate)
        result = []
        for ch in out:
            x = filter_chain(list(ch), stages, circular=True)
            mean = sum(x) / len(x)
            result.append([v - mean for v in x])
        return result


def song_meadow() -> Song:
    """Pop Meadow: bright, bouncy D-major pop at 112 BPM."""
    s = Song(112, 8)
    b, r = s.beat, s.rate
    kick, clap = s.stem("base", "kick", -14, 2.5), s.stem("base", "clap", -19, 3.0)
    shaker = s.stem("base", "shaker", -27, 1.5)
    bass, pad, keys, lead = (s.stem("base", "bass", -11), s.stem("base", "pad", -17),
                             s.stem("base", "keys", -18), s.stem("base", "lead", -10.5))
    f_kick, f_arp = s.stem("finale", "kick", -14, 2.5), s.stem("finale", "arp", -13)
    f_hat = s.stem("finale", "hat", -21, 2.5)
    f_lead, f_bass = s.stem("finale", "lead", -14), s.stem("finale", "bass", -15)
    base_kicks, finale_kicks = [], []
    chords = [[62, 66, 69, 76], [59, 62, 66, 69], [59, 62, 67, 69], [61, 64, 69, 71],
              [62, 66, 69, 76], [61, 64, 66, 69], [59, 62, 67, 69], [62, 64, 69, 71]]
    roots = [38, 35, 43, 45, 38, 42, 43, 45]
    melody = [
        [(0, 78, 1), (1, 81, .5), (1.5, 83, .5), (2.5, 81, 1), (3.5, 78, .5)],
        [(0, 76, 1.5), (2, 74, .5), (2.5, 76, .5), (3, 78, 1)],
        [(0, 83, 1), (1, 81, .5), (1.5, 79, 1), (3, 76, 1)],
        [(0, 76, .5), (.5, 78, .5), (1, 81, 2), (3.5, 76, .5)],
        [(0, 78, 1), (1, 81, .5), (1.5, 86, 1), (2.5, 85, .5), (3, 83, 1)],
        [(0, 81, 1.5), (1.5, 78, .5), (2, 76, 1), (3, 73, 1)],
        [(0, 74, .5), (.5, 76, .5), (1, 79, 1), (2, 83, 1), (3, 81, 1)],
        [(0, 81, 1), (1, 76, .5), (1.5, 78, .5), (2, 76, 2)],
    ]
    for bar in range(8):
        chord, root = chords[bar], roots[bar]
        if bar == 7:  # Asus4 resolving to A on beat 3
            chord_late = [61, 64, 69, 71]
        for j, pitch in enumerate(chord):
            pad.add(voice("pad", r, midi(pitch), 4.4 * b, 0.35, 0.6, "saw", 0.8), s.at(bar, 0), 1.0, -0.6 + j * 0.4)
        for step, interval, g in ((0, 0, .9), (3, 0, .7), (4, 0, .85), (6, 12, .6), (7, 0, .7)):
            bass.add(voice("bass", r, midi(root + interval), 0.45 * b, 0.35, False), s.at(bar, step / 2), g)
        for beat in ((0, 2, 1.5) if bar % 2 else (0, 2)):
            kick.add(voice("kick", r, 0.32, 120.0, 50.0, 0.03, 0.12), s.at(bar, beat), 0.55 if beat == 1.5 else 1.0)
            base_kicks.append(s.at(bar, beat))
        for beat in (1, 3):
            clap.add(voice("snare", r, 300 + beat, 0.2, 190.0, True), s.at(bar, beat), 1.0)
        for step in range(8):
            shaker.add(voice("hat", r, 400 + step % 4, 0.09, 0.025, 2500.0, 7000.0), s.at(bar, step / 2),
                       1.0 if step % 2 else 0.6)
        for step in (1, 3, 5, 7):
            voicing = chord_late if bar == 7 and step >= 4 else chord
            for k, pitch in enumerate(voicing[1:]):
                keys.add(voice("epiano", r, midi(pitch), 0.3 * b, 0.25), s.at(bar, step / 2) + k * 0.004, 0.5,
                         -0.35 if step % 4 == 1 else 0.35)
        for beat, pitch, length in melody[bar]:
            lead.add(voice("bell", r, midi(pitch), length * b + 0.15, 0.45, 0.55), s.at(bar, beat), 1.0, 0.12)
            f_lead.add(voice("lead", r, midi(pitch), length * b * 0.95, 7), s.at(bar, beat), 1.0)
        # Finale layer: four-on-the-floor complement, 16th arps, tambourine 16ths, octave bass pump.
        for beat in (1, 3):
            f_kick.add(voice("kick", r, 0.30, 125.0, 52.0, 0.03, 0.11), s.at(bar, beat), 1.0)
            finale_kicks.append(s.at(bar, beat))
        tones = sorted(chord)
        for step, index in enumerate([0, 1, 2, 3, 2, 1, 2, 3] * 2):
            voicing = sorted(chord_late) if bar == 7 and step >= 8 else tones
            f_arp.add(voice("bell", r, midi(voicing[index] + 12), 0.30, 0.12, 0.4), s.at(bar, step / 4),
                      1.0 if step % 4 == 0 else 0.7)
        for step in range(16):
            f_hat.add(voice("hat", r, 500 + step % 4, 0.06, 0.02, 3500.0, 8000.0), s.at(bar, step / 4),
                      1.0 if step % 4 == 2 else 0.5)
        for step in range(8):
            f_bass.add(voice("bass", r, midi(root + 12), 0.22 * b, 0.12, False), s.at(bar, step / 2),
                       1.0 if step % 2 else 0.7)
    every_kick = base_kicks + finale_kicks
    duck(bass, every_kick, 0.6, 0.08)
    duck(pad, every_kick, 0.3, 0.15)
    duck(keys, base_kicks, 0.3, 0.10)
    duck(f_bass, every_kick, 0.6, 0.08)
    duck(f_arp, every_kick, 0.35, 0.08)
    pingpong(lead, 0.75 * b, 0.3, 3)
    return s


def song_canyon() -> Song:
    """Canyon: funky, syncopated A-dorian groove at 105 BPM with swung 16ths."""
    s = Song(105, 8)
    b, r = s.beat, s.rate
    sixteenth = b / 4

    def at16(bar, step, swing=0.14):
        return s.at(bar, step / 4) + (swing * sixteenth if step % 2 else 0.0)

    kick, snare = s.stem("base", "kick", -13, 2.5), s.stem("base", "snare", -16, 2.5)
    hats, bass = s.stem("base", "hats", -24, 2.0), s.stem("base", "bass", -11)
    guitar, keys = s.stem("base", "guitar", -20), s.stem("base", "keys", -16)
    organ, riff = s.stem("base", "organ", -16), s.stem("base", "riff", -19)
    f_brass, f_block = s.stem("finale", "brass", -14), s.stem("finale", "block", -20, 2.0)
    f_conga, f_open = s.stem("finale", "conga", -17, 1.5), s.stem("finale", "openhat", -22, 2.0)
    f_kick = s.stem("finale", "kick", -19, 2.5)
    kicks = []
    am, d9, fmaj, e7 = [57, 60, 64, 67], [54, 57, 60, 64], [53, 57, 60, 64], [56, 59, 62, 64]
    chords = [am, am, d9, d9, am, am, fmaj, e7]
    roots = [33, 33, 38, 38, 33, 33, 41, 40]
    bass_line = [(0, 0, 0.20, 1.0), (3, 12, 0.10, 0.7), (4, 0, 0.10, 0.6), (6, 3, 0.12, 0.75), (7, 5, 0.10, 0.6),
                 (10, 0, 0.16, 0.9), (11, 12, 0.08, 0.65), (13, 10, 0.10, 0.7), (14, 7, 0.12, 0.75)]
    riffs = {1: [(8, 76), (10, 79), (11, 81), (13, 79), (14, 76)],
             3: [(8, 76), (10, 79), (11, 81), (13, 83), (14, 81)],
             5: [(8, 76), (10, 79), (11, 81), (13, 79), (14, 76)],
             7: [(8, 76), (10, 79), (11, 80), (14, 83)]}
    for bar in range(8):
        chord, root = chords[bar], roots[bar]
        for step, interval, seconds, g in bass_line:
            slap = interval == 12
            bass.add(voice("bass", r, midi(root + interval), seconds, 0.12 if slap else 0.25, slap), at16(bar, step), g)
        for step in ([0, 6, 10] if bar % 2 == 0 else [0, 3, 6, 10, 15]):
            kick.add(voice("kick", r, 0.30, 130.0, 52.0, 0.028, 0.10), at16(bar, step), 0.5 if step == 15 else 1.0)
            kicks.append(at16(bar, step))
        for step in (4, 12):
            snare.add(voice("snare", r, 700 + step, 0.22, 200.0, False), at16(bar, step), 1.0)
        for step in (7, 9, 14):
            snare.add(voice("snare", r, 720 + step, 0.10, 200.0, False), at16(bar, step), 0.22)
        for step in range(16):
            g = 1.0 if step in (2, 6, 10, 14) else (0.6 if step % 2 == 0 else 0.35)
            hats.add(voice("hat", r, 800 + step % 4, 0.05, 0.015, 4000.0, 8000.0), at16(bar, step), g)
        for step in (2, 5, 9, 12, 15):  # interlocks with the bass line and riff (no shared 16ths)
            for k, pitch in enumerate(chord[1:]):
                guitar.add(voice("pluck", r, midi(pitch + 12), 0.12, 900 + k, 0.985), at16(bar, step) + k * 0.012,
                           0.6, 0.25)
        for step in (7, 13):
            guitar.add(voice("hat", r, 950 + step, 0.05, 0.012, 800.0, 2500.0), at16(bar, step), 0.5, 0.25)
        for step, beats in ((0, 1.2), (10, 0.45)):
            for k, pitch in enumerate(chord):
                keys.add(voice("epiano", r, midi(pitch), beats * b, 0.5), at16(bar, step) + k * 0.008, 0.5, -0.35)
        for j, pitch in enumerate(chord):
            organ.add(voice("pad", r, midi(pitch), 4.3 * b, 0.08, 0.3, "organ", 0.7), s.at(bar, 0), 1.0, -0.5 + j * 0.33)
        for step, pitch in riffs.get(bar, []):
            riff.add(voice("pluck", r, midi(pitch), 0.25, 1000 + pitch, 0.996), at16(bar, step), 1.0)
            riff.add(voice("bell", r, midi(pitch), 0.25, 0.12, 0.3), at16(bar, step), 0.35)
        # Finale: syncopated horn stabs, 3-3-2 woodblock, congas, open hats, extra kick.
        upcoming = chords[(bar + 1) % 8]
        for step, seconds, voicing in ((0, 0.18, chord), (6, 0.12, chord), (14, 0.22, upcoming)):
            for k, pitch in enumerate(voicing[1:]):
                f_brass.add(voice("brass", r, midi(pitch + 12), seconds), at16(bar, step) + k * 0.008, 1.0)
        for step in (0, 3, 6, 8, 11, 14):
            f_block.add(voice("block", r, 1000.0 if step in (0, 8) else 800.0, 0.08), at16(bar, step), 1.0)
        for step, frequency in ((2, 200.0), (7, 300.0), (10, 200.0), (15, 300.0)):
            f_conga.add(voice("tom", r, frequency, 0.18, 0.08), at16(bar, step), 1.0)
        for step in (2, 6, 10, 14):
            f_open.add(voice("hat", r, 1200 + step, 0.12, 0.06, 3500.0, 8000.0), at16(bar, step), 1.0)
        f_kick.add(voice("kick", r, 0.30, 130.0, 52.0, 0.028, 0.10), at16(bar, 8), 1.0)
        kicks.append(at16(bar, 8))
    duck(bass, kicks, 0.5, 0.07)
    duck(keys, kicks, 0.3, 0.10)
    duck(organ, kicks, 0.3, 0.15)
    return s


def song_aurora() -> Song:
    """Aurora Arcade: dreamy, spacious synth at 90 BPM with ping-pong celesta."""
    s = Song(90, 8)
    b, r = s.beat, s.rate
    kick, snare = s.stem("base", "kick", -14, 2.5), s.stem("base", "snare", -19, 2.5)
    shaker = s.stem("base", "shaker", -28, 1.5)
    bass, pad, bells, lead = (s.stem("base", "bass", -11), s.stem("base", "pad", -13),
                              s.stem("base", "bells", -14), s.stem("base", "lead", -13))
    f_kick, f_hat = s.stem("finale", "kick", -14, 2.5), s.stem("finale", "hat", -21, 2.0)
    f_arp, f_lead, f_pulse = s.stem("finale", "arp", -14), s.stem("finale", "lead", -13), s.stem("finale", "pulse", -16)
    base_kicks, finale_kicks = [], []
    chords = [[53, 57, 60, 64], [55, 59, 62, 64], [52, 55, 59, 62], [57, 60, 64, 71],
              [53, 57, 60, 64], [55, 60, 62, 64], [55, 59, 62, 64], [56, 59, 62, 64]]
    roots = [41, 41, 40, 45, 38, 43, 36, 40]
    melody = {4: [(0, 76, 2), (2, 74, 1), (3, 72, 1)], 5: [(0, 74, 2.5), (2.5, 76, 1.5)],
              6: [(0, 79, 1.5), (1.5, 76, 1), (2.5, 71, 1.5)], 7: [(0, 74, 2), (2, 71, 1), (3, 68, 1)]}
    counter = {0: [(0, 72, 2), (2, 76, 2)], 1: [(0, 74, 2), (2, 79, 2)],
               2: [(0, 79, 3), (3, 76, 1)], 3: [(0, 72, 2), (2, 71, 2)]}
    for bar in range(8):
        chord, root = chords[bar], roots[bar]
        for j, pitch in enumerate(chord):
            pad.add(voice("pad", r, midi(pitch), 4.6 * b, 0.6, 1.0, "saw", 0.7), s.at(bar, 0), 1.0, -0.7 + j * 0.45)
        bass.add(voice("bass", r, midi(root), 3.6 * b, 2.5, False), s.at(bar, 0), 1.0)
        bass.add(voice("bass", r, midi(root), 0.4 * b, 0.3, False), s.at(bar, 3.5), 0.5)
        for beat in (0, 2.5):
            kick.add(voice("kick", r, 0.36, 100.0, 46.0, 0.035, 0.14), s.at(bar, beat), 1.0)
            base_kicks.append(s.at(bar, beat))
        for beat in (1, 3):
            snare.add(voice("snare", r, 1300 + beat, 0.30, 180.0, False), s.at(bar, beat), 1.0)
        for step in range(8):
            shaker.add(voice("hat", r, 1400 + step % 4, 0.10, 0.03, 2500.0, 6500.0), s.at(bar, step / 2),
                       1.0 if step % 2 else 0.5)
        tones = sorted(chord)
        for step, index in enumerate([0, 1, 2, 3, 2, 3, 1, 2]):
            bells.add(voice("bell", r, midi(tones[index] + 12), 0.9, 0.5, 0.5), s.at(bar, step / 2), 1.0,
                      -0.5 if step % 2 == 0 else 0.5)
        for beat, pitch, length in melody.get(bar, []):
            lead.add(voice("lead", r, midi(pitch), length * b, 5), s.at(bar, beat), 1.0, -0.1)
        # Finale: steady soft four-on-the-floor, offbeat hats, 16th sparkle, counter-melody, pulses.
        for beat in range(4):
            f_kick.add(voice("kick", r, 0.30, 110.0, 48.0, 0.03, 0.11), s.at(bar, beat), 1.0)
            finale_kicks.append(s.at(bar, beat))
        for step in range(16):
            f_hat.add(voice("hat", r, 1500 + step % 4, 0.07, 0.035 if step % 4 == 2 else 0.015, 3500.0, 8000.0),
                      s.at(bar, step / 4), 1.0 if step % 4 == 2 else 0.4)
        for step, index in enumerate([0, 1, 2, 3, 1, 2, 3, 2] * 2):
            f_arp.add(voice("bell", r, midi(tones[index] + 24), 0.25, 0.10, 0.3), s.at(bar, step / 4),
                      1.0 if step % 2 == 0 else 0.6)
        for beat, pitch, length in counter.get(bar, []):
            f_lead.add(voice("lead", r, midi(pitch), length * b, 5), s.at(bar, beat), 1.0)
        for step in range(8):
            for pitch in tones[1:]:
                f_pulse.add(voice("epiano", r, midi(pitch + 12), 0.2 * b, 0.15), s.at(bar, step / 2), 1.0)
    every_kick = base_kicks + finale_kicks
    duck(bass, every_kick, 0.5, 0.08)
    duck(pad, every_kick, 0.3, 0.18)
    duck(f_pulse, every_kick, 0.5, 0.08)
    duck(f_arp, every_kick, 0.3, 0.08)
    pingpong(bells, 0.75 * b, 0.42, 5)
    return s


# key, finale key, purpose, builder
MUSIC = [
    ("music_meadow", "music_meadow_finale", "Pop Meadow arena loop (bright pop)", song_meadow),
    ("music_canyon", "music_canyon_finale", "Canyon arena loop (funky, syncopated)", song_canyon),
    ("music_aurora", "music_aurora_finale", "Aurora Arcade arena loop (dreamy synth)", song_aurora),
]
MUSIC_INFO = {"music_meadow": (112, 8, 2), "music_canyon": (105, 8, 2), "music_aurora": (90, 8, 2)}

LEGACY = [
    ("bank", "bank.wav", "legacy_cue", "Bank sparks: rising arpeggio"),
    ("catch", "catch.wav", "legacy_cue", "Catch: three-note sparkle"),
    ("dash", "dash.wav", "legacy_cue", "Dash: airy filtered sweep"),
    ("music", "pop_meadow_loop.wav", "legacy_music", "Original 16 s Pop Meadow groove (kept for provenance)"),
    ("round_reward", "round_reward.wav", "legacy_cue", "Round reward celebration"),
    ("upgrade", "upgrade.wav", "legacy_cue", "Upgrade purchased"),
]


def reference_cue_peak_dbfs() -> float:
    return statistics.median(peak for _, _, _, _, peak, _, _ in CUES)


def master_layers(base: list, finale: list, rate: int, base_db: float, combined_db: float) -> tuple:
    """Joint level/limit stage for a base loop and its finale layer.

    One smooth, circular, look-ahead gain curve is computed from the worst of
    |base|, |finale| and |base+finale| and applied to BOTH files, so each file
    alone and the two played together stay below the ceiling, and the loops stay
    periodic. Iterates until base RMS and combined RMS meet their targets.
    """
    ceiling = from_db(MUSIC_CEILING_DBFS)
    tb, tc = from_db(base_db), from_db(combined_db)
    fin = finale[0]
    count = len(fin)
    half = 2 * round(0.004 * rate)  # look-ahead/hold half-window (~8 ms)
    gb = gf = 1.0
    stats = {}
    for iteration in range(20):
        B = [[gb * v for v in ch] for ch in base]
        F = [gf * v for v in fin]
        peak = [abs(v) for v in F]
        for ch in B:
            peak = [max(p, abs(a), abs(a + f)) for p, a, f in zip(peak, ch, F)]
        worst = max(peak)
        if worst > ceiling:
            need = [ceiling / p if p > ceiling else 1.0 for p in peak]
            gain = box_circular(box_circular(window_min_circular(need, half), half // 2), half // 2)
            B = [[a * g for a, g in zip(ch, gain)] for ch in B]
            F = [a * g for a, g in zip(F, gain)]
            reduction = to_db(min(gain))
            deepest = gain.index(min(gain)) / rate
            active = [g for g in gain if g < 0.999]
            limited = len(active) / count
            typical = to_db(sum(active) / len(active)) if active else 0.0
        else:
            reduction, limited, typical, deepest = 0.0, 0.0, 0.0, 0.0
        pbb = sum(sum(v * v for v in ch) for ch in B) / (count * len(B))
        pbf = sum(sum(a * f for a, f in zip(ch, F)) for ch in B) / (count * len(B))
        pff = sum(v * v for v in F) / count
        mb, mc = math.sqrt(pbb), math.sqrt(pbb + 2 * pbf + pff)
        stats = {"iterations": iteration + 1, "max_gain_reduction_db": round(reduction, 2),
                 "mean_reduction_when_active_db": round(typical, 2), "limited_fraction": round(limited, 4),
                 "deepest_at_seconds": round(deepest, 3)}
        if abs(to_db(mb) - base_db) < 0.01 and abs(to_db(mc) - combined_db) < 0.01:
            return B, [F], stats
        sb = tb / mb
        disc = (sb * pbf) ** 2 - pff * (sb * sb * pbb - tc * tc)
        sf = (-sb * pbf + math.sqrt(disc)) / pff
        gb, gf = gb * sb, gf * sf
    raise RuntimeError(f"music level targets did not converge: {stats}")


def window_min_circular(values: list[float], half: int) -> list[float]:
    count = len(values)
    ext = values[count - half:] + values + values[:half]
    out = [0.0] * count
    window = deque()
    width = 2 * half + 1
    for i, v in enumerate(ext):
        while window and ext[window[-1]] >= v:
            window.pop()
        window.append(i)
        if window[0] <= i - width:
            window.popleft()
        if i >= width - 1:
            out[i - width + 1] = ext[window[0]]
    return out


def box_circular(values: list[float], half: int) -> list[float]:
    count = len(values)
    ext = values[count - half:] + values + values[:half]
    prefix = list(accumulate(ext, initial=0.0))
    width = 2 * half + 1
    return [(prefix[j + width] - prefix[j]) / width for j in range(count)]


# ---- generation -----------------------------------------------------------
def generate(out_dir: Path) -> None:
    global OUTPUT
    previous, OUTPUT = OUTPUT, out_dir
    try:
        log("legacy: rendering six original 2026-10-25 files (unchanged code)")
        make_sfx()
        make_music()
    finally:
        OUTPUT = previous
    for key, filename, _, _, peak, builder, highpass in CUES:
        write_pcm(out_dir / filename, [finish_cue(builder(), peak, highpass)], CUE_RATE)
        log(f"cue: {filename}")
    reference = reference_cue_peak_dbfs()
    for key, finale_key, _, builder in MUSIC:
        _voice_cache.clear()
        song = builder()
        base, finale = song.layer("base"), song.layer("finale")
        base, finale, stats = master_layers(base, finale, song.rate, reference - BASE_GAP_DB,
                                            reference - COMBINED_GAP_DB)
        write_pcm(out_dir / f"{key}.wav", base, song.rate)
        write_pcm(out_dir / f"{finale_key}.wav", finale, song.rate)
        log(f"music: {key}.wav + {finale_key}.wav; limiter {stats}")
    _voice_cache.clear()


# ---- verification ---------------------------------------------------------
class Checks:
    def __init__(self):
        self.failures: list[str] = []
        self.count = 0

    def expect(self, condition: bool, message: str) -> bool:
        self.count += 1
        if not condition:
            self.failures.append(message)
        return condition


def read_pcm(path: Path) -> tuple:
    with wave.open(str(path), "rb") as wav:
        params = wav.getparams()
        payload = wav.readframes(params.nframes)
    data = array("h")
    data.frombytes(payload)
    if sys.byteorder == "big":
        data.byteswap()
    return params, data, [data[c::params.nchannels] for c in range(params.nchannels)]


def hf_ratio_db(channels, rate: int) -> float:
    """Energy above ~10 kHz relative to full-band energy (4th-order Butterworth
    high-pass; includes transition-band leakage, so it is a conservative bound)."""
    stages = [biquad_coeffs("hp", HF_SPLIT_HZ, rate, q) for q in BUTTER4_Q]
    total = high = 0.0
    for ch in channels:
        x = [v / 32767 for v in ch]
        total += sum(v * v for v in x)
        high += sum(v * v for v in filter_chain(x, stages, circular=False))
    return 10 * math.log10(max(high, 1e-30) / total) if total else -200.0


def seam_metrics(channels) -> tuple[float, float]:
    """Step across the wrap point, and its ratio to the largest neighbouring step
    (32 samples either side). A click shows up as a ratio well above 1."""
    step, ratio = 0.0, 0.0
    for ch in channels:
        count = len(ch)
        seam = abs(ch[0] - ch[count - 1]) / 32767
        nearby = [abs(ch[k + 1] - ch[k]) for k in range(count - 33, count - 1)]
        nearby += [abs(ch[k + 1] - ch[k]) for k in range(0, 32)]
        local = max(max(nearby) / 32767, 1 / 32767)
        step, ratio = max(step, seam), max(ratio, seam / local)
    return step, ratio


def analyze(path: Path, checks: Checks, dc_limit: float = DC_LIMIT) -> tuple[dict, list]:
    name = path.name
    size = path.stat().st_size
    params, data, channels = read_pcm(path)
    frames, rate, nch = params.nframes, params.framerate, params.nchannels
    checks.expect(params.sampwidth == 2 and params.comptype == "NONE", f"{name}: expected 16-bit PCM")
    checks.expect(size == 44 + frames * nch * 2, f"{name}: unexpected WAV layout/extra chunks ({size} bytes)")
    checks.expect(frames > 0, f"{name}: empty")
    peak_int = max(max(data), -min(data))
    peak = peak_int / 32767
    checks.expect(peak_int < 32767, f"{name}: clipping (full-scale samples)")
    checks.expect(peak <= from_db(PEAK_LIMIT_DBFS) + 1e-9, f"{name}: peak {to_db(peak):.2f} dBFS above -1 dBFS")
    rms = math.sqrt(sum(map(operator.mul, data, data)) / len(data)) / 32767
    dc = sum(data) / len(data) / 32767
    checks.expect(abs(dc) < dc_limit, f"{name}: DC offset {dc:.5f}")
    seam_step, seam_ratio = seam_metrics(channels)
    record = {
        "file": name, "duration_seconds": round(frames / rate, 4), "frames": frames, "sample_rate": rate,
        "channels": nch, "bits_per_sample": 16, "bytes": size,
        "peak_linear": round(peak, 6), "peak_dbfs": round(to_db(peak), 2), "rms_dbfs": round(to_db(rms), 2),
        "dc_offset": round(dc, 6), "hf_above_10khz_db": round(hf_ratio_db(channels, rate), 1),
        "seam_step_linear": round(seam_step, 6), "seam_ratio": round(seam_ratio, 3),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }
    return record, channels


def verify_folder(folder: Path) -> tuple[dict, Checks]:
    checks = Checks()
    files, layers = [], []
    reference_measured = None

    def entry(key, role, purpose, provenance, record):
        item = {"key": key, "role": role, "purpose": purpose}
        item.update(record)
        item["provenance"] = provenance
        files.append(item)
        return item

    for key, filename, role, purpose in LEGACY:
        record, _ = analyze(folder / filename, checks, LEGACY_DC_LIMIT)
        # Original 2026-10-25 bounds kept verbatim for the legacy set.
        checks.expect(0.01 < record["peak_linear"] <= 0.60, f"{filename}: legacy peak bound")
        if role == "legacy_music":
            checks.expect(record["frames"] == record["sample_rate"] * 16 and record["seam_step_linear"] < 0.01,
                          f"{filename}: legacy loop duration/seam")
        else:
            _, _, channels = read_pcm(folder / filename)
            ch = channels[0]
            checks.expect(max(abs(ch[0]), abs(ch[-1])) < 50, f"{filename}: boundary click")
        entry(key, role, purpose, LEGACY_PROVENANCE, record)

    cue_peaks = []
    for key, filename, purpose, max_seconds, _, _, _ in CUES:
        record, channels = analyze(folder / filename, checks)
        ch = channels[0]
        checks.expect(record["sample_rate"] == CUE_RATE and record["channels"] == 1, f"{filename}: expected 44.1 kHz mono")
        checks.expect(0.03 <= record["duration_seconds"] <= max_seconds,
                      f"{filename}: duration {record['duration_seconds']} s outside 0.03-{max_seconds} s")
        checks.expect(record["peak_dbfs"] >= -20, f"{filename}: too quiet")
        checks.expect(max(abs(ch[0]), abs(ch[-1])) < 50, f"{filename}: boundary click")
        checks.expect(record["hf_above_10khz_db"] <= HF_LIMIT_DB,
                      f"{filename}: {record['hf_above_10khz_db']} dB energy above 10 kHz (limit {HF_LIMIT_DB})")
        cue_peaks.append(record["peak_dbfs"])
        entry(key, "cue", purpose, PROVENANCE, record)
    reference_measured = round(statistics.median(cue_peaks), 2)
    low, high = GAP_WINDOW_DB

    for key, finale_key, purpose, _ in MUSIC:
        bpm, bars, base_channels = MUSIC_INFO[key]
        expected_frames = bars * 4 * 60 * LOOP_RATE // bpm
        pair = []
        for k, role, label in ((key, "music", purpose), (finale_key, "music_finale", purpose + " - FINALE layer")):
            filename = f"{k}.wav"
            record, channels = analyze(folder / filename, checks)
            want_channels = base_channels if role == "music" else 1
            checks.expect(record["sample_rate"] == LOOP_RATE and record["channels"] == want_channels,
                          f"{filename}: expected {LOOP_RATE} Hz, {want_channels} channel(s)")
            checks.expect(record["frames"] == expected_frames,
                          f"{filename}: {record['frames']} frames, expected {expected_frames} ({bars} bars at {bpm} BPM)")
            checks.expect(LOOP_SECONDS[0] <= record["duration_seconds"] <= LOOP_SECONDS[1],
                          f"{filename}: loop length outside 16-24 s")
            checks.expect(record["seam_step_linear"] < 0.05 and record["seam_ratio"] <= 1.5,
                          f"{filename}: loop seam discontinuity (step {record['seam_step_linear']}, ratio {record['seam_ratio']})")
            checks.expect(record["hf_above_10khz_db"] <= HF_LIMIT_DB,
                          f"{filename}: {record['hf_above_10khz_db']} dB energy above 10 kHz")
            item = entry(k, role, label, PROVENANCE, record)
            item["bpm"], item["bars"] = bpm, bars
            pair.append((record, channels))
        (base_rec, base_ch), (fin_rec, fin_ch) = pair
        fin = fin_ch[0]
        combined_peak = max(max(abs(a + f) for a, f in zip(ch, fin)) for ch in base_ch) / 32767
        combined_ms = sum(sum((a + f) * (a + f) for a, f in zip(ch, fin)) for ch in base_ch) / (len(fin) * len(base_ch))
        combined_rms = math.sqrt(combined_ms) / 32767
        base_gap = round(reference_measured - base_rec["rms_dbfs"], 2)
        combined_gap = round(reference_measured - to_db(combined_rms), 2)
        checks.expect(combined_peak <= from_db(PEAK_LIMIT_DBFS),
                      f"{key}: base+finale peak {to_db(combined_peak):.2f} dBFS above -1 dBFS")
        checks.expect(low <= base_gap <= high, f"{key}: base RMS {base_gap} dB below cue peaks (want {low}-{high})")
        checks.expect(low <= combined_gap <= high,
                      f"{key}: base+finale RMS {combined_gap} dB below cue peaks (want {low}-{high})")
        layers.append({"base": key, "finale": finale_key, "bpm": bpm, "bars": bars,
                       "loop_seconds": base_rec["duration_seconds"],
                       "combined_peak_dbfs": round(to_db(combined_peak), 2),
                       "combined_rms_dbfs": round(to_db(combined_rms), 2),
                       "base_gap_below_cue_peak_db": base_gap, "combined_gap_below_cue_peak_db": combined_gap})

    total = sum(item["bytes"] for item in files)
    checks.expect(total < BUDGET_BYTES, f"audio budget exceeded: {total} bytes")
    report = {
        "generator": "tools/generate_audio.py",
        "provenance": PROVENANCE,
        "provenance_detail": ("All audio is synthesized from code in tools/generate_audio.py using the Python "
                              "standard library (math, seeded random, wave). No samples, sound fonts, MIDI, "
                              "loops, purchased or downloaded audio, or third-party compositions."),
        "loudness_method": ("Unweighted whole-file RMS and sample peak of decoded 16-bit PCM (not LUFS). Music "
                            "targets are relative to the median new-cue peak; base+finale is measured as the "
                            "per-channel sum with the mono finale on both channels."),
        "limits": {"peak_dbfs_max": PEAK_LIMIT_DBFS, "music_ceiling_dbfs": MUSIC_CEILING_DBFS,
                   "dc_abs_max": DC_LIMIT, "legacy_dc_abs_max": LEGACY_DC_LIMIT,
                   "hf_above_10khz_db_max": HF_LIMIT_DB,
                   "music_gap_window_db": list(GAP_WINDOW_DB), "loop_seconds": list(LOOP_SECONDS),
                   "budget_bytes": BUDGET_BYTES},
        "reference_cue_peak_dbfs": reference_measured,
        "files": files,
        "layers": layers,
        "total_bytes": total,
    }
    return report, checks


def check_catalog(report: dict, checks: Checks) -> None:
    """Cross-check AudioCatalog.luau against the manifest (keys, files, durations, finale links)."""
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        import set_audio_ids
    finally:
        sys.path.pop(0)
    catalog_path = ROOT / "game" / "ReplicatedStorage" / "Spark" / "AudioCatalog.luau"
    try:
        entries = set_audio_ids.parse_catalog(catalog_path.read_text(encoding="utf-8"))
    except set_audio_ids.CatalogError as error:
        checks.expect(False, f"AudioCatalog: {error}")
        return
    by_file = {item["file"]: item for item in report["files"]}
    for item in report["files"]:
        fields = entries.get(item["key"], {}).get("fields")
        if not checks.expect(fields is not None, f"AudioCatalog: missing key {item['key']}"):
            continue
        checks.expect(fields.get("file") == item["file"], f"AudioCatalog: {item['key']}.file should be {item['file']}")
        duration = fields.get("duration")
        checks.expect(isinstance(duration, (int, float)) and abs(duration - item["duration_seconds"]) <= 0.006,
                      f"AudioCatalog: {item['key']}.duration {duration} != {item['duration_seconds']}")
        if item["role"] in ("music", "music_finale", "legacy_music"):
            checks.expect(fields.get("looped") is True, f"AudioCatalog: {item['key']} must be looped=true")
    for key, entry in entries.items():
        filename = entry["fields"].get("file", "")
        checks.expect(filename == "" or filename in by_file, f"AudioCatalog: {key}.file {filename} not in manifest")
    for layer in report["layers"]:
        base = entries.get(layer["base"], {}).get("fields", {})
        finale = entries.get(layer["finale"], {}).get("fields", {})
        checks.expect(base.get("finale") == layer["finale"], f"AudioCatalog: {layer['base']}.finale link")
        checks.expect(finale.get("layerOf") == layer["base"], f"AudioCatalog: {layer['finale']}.layerOf link")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--verify", action="store_true", help="Verify the committed WAV files and manifest without modifying them")
    mode.add_argument("--reproduce", action="store_true",
                      help="Render everything into a temporary folder and require byte-identical files")
    args = parser.parse_args()
    manifest = OUTPUT / "manifest.json"

    if args.reproduce:
        with tempfile.TemporaryDirectory(prefix="spark-audio-") as directory:
            generate(Path(directory))
            report, _ = verify_folder(OUTPUT)
            mismatched = [item["file"] for item in report["files"]
                          if hashlib.sha256((Path(directory) / item["file"]).read_bytes()).hexdigest() != item["sha256"]]
        if mismatched:
            print("FAIL: regenerated bytes differ for: " + ", ".join(mismatched), file=sys.stderr)
            return 1
        print(f"PASS: all {len(report['files'])} WAVs regenerate byte-for-byte on this platform")
        return 0

    if not args.verify:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        generate(OUTPUT)
    report, checks = verify_folder(OUTPUT)
    check_catalog(report, checks)
    serialized = json.dumps(report, indent=2) + "\n"
    if args.verify:
        try:
            committed = json.loads(manifest.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            committed = {"error": str(error)}
        checks.expect(committed == report, "manifest mismatch (hashes/metrics); regenerate intentionally")
    if checks.failures:
        for failure in checks.failures:
            print("FAIL: " + failure, file=sys.stderr)
        print(f"{len(checks.failures)} of {checks.count} audio checks failed", file=sys.stderr)
        return 1
    if not args.verify:
        manifest.write_text(serialized, encoding="utf-8")
    print(serialized)
    print(f"PASS: {len(report['files'])} WAVs, {checks.count} checks; peaks <= -1 dBFS, no clipping, DC bounded, "
          f"<= {HF_LIMIT_DB:.0f} dB above 10 kHz (new files), cue lengths, loop length/seam, base+finale headroom "
          f"and level gap, catalog links, {report['total_bytes']} bytes < {BUDGET_BYTES}, manifest hashes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
