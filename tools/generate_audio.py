"""Reproduce Spark Stampede's original synthesized audio with Python's standard library.

No samples, MIDI files, sound fonts, libraries, or downloaded audio are used.
All melodies, voicings, rhythms and synthesis parameters are authored here.
Run: python tools/generate_audio.py
Verify existing files: python tools/generate_audio.py --verify
"""
from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio"
TAU = math.tau
SFX_RATE = 44100
MUSIC_RATE = 44100


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


def inspect(path: Path) -> dict:
    with wave.open(str(path), "rb") as wav:
        assert wav.getsampwidth() == 2, f"{path.name}: expected signed 16-bit PCM"
        channels, rate, frames = wav.getnchannels(), wav.getframerate(), wav.getnframes()
        payload = wav.readframes(frames)
    samples = [item[0] for item in struct.iter_unpack("<h", payload)]
    peak = max(abs(value) for value in samples) / 32767
    rms = math.sqrt(sum((value / 32767) ** 2 for value in samples) / len(samples))
    assert all(abs(value) < 32767 for value in samples), f"{path.name}: clipping"
    assert 0.01 < peak <= 0.60, f"{path.name}: peak out of project bounds"
    assert abs(sum(samples) / len(samples) / 32767) < 0.005, f"{path.name}: DC offset"
    seam = max(abs(samples[c] - samples[-channels + c]) for c in range(channels)) / 32767
    if "loop" in path.stem:
        # Not a perceptual listening test: detect an abrupt discontinuity at wrap.
        assert frames == rate * 16 and seam < 0.01, f"{path.name}: loop duration/seam"
    else:
        assert max(abs(value) for value in samples[:channels] + samples[-channels:]) < 50, f"{path.name}: boundary click"
    return {
        "file": path.name, "duration_seconds": round(frames / rate, 4), "sample_rate": rate,
        "channels": channels, "bits_per_sample": 16, "bytes": path.stat().st_size,
        "peak_linear": round(peak, 6), "peak_dbfs": round(20 * math.log10(peak), 2),
        "rms_dbfs": round(20 * math.log10(rms), 2), "seam_step_linear": round(seam, 6),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Verify the committed WAV files and manifest without modifying them")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if not args.verify:
        make_sfx()
        make_music()
    expected = ["bank.wav", "catch.wav", "dash.wav", "pop_meadow_loop.wav", "round_reward.wav", "upgrade.wav"]
    report = {"generator": "tools/generate_audio.py", "provenance": "Original synthesis; no external audio assets",
              "files": [inspect(OUTPUT / filename) for filename in expected]}
    report["total_bytes"] = sum(item["bytes"] for item in report["files"])
    assert report["total_bytes"] < 10_000_000, "Audio budget exceeded"
    serialized = json.dumps(report, indent=2) + "\n"
    manifest = OUTPUT / "manifest.json"
    if args.verify:
        assert json.loads(manifest.read_text(encoding="utf-8")) == report, "Manifest mismatch; regenerate intentionally"
    else:
        manifest.write_text(serialized, encoding="utf-8")
    print(serialized)
    print("PASS: six WAVs; bounded peaks, no clipping, DC bounds, edge/loop checks, <10 MB, manifest hashes")


if __name__ == "__main__":
    main()
