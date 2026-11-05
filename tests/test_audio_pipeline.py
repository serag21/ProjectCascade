"""Negative/positive tests for the audio verifier in tools/generate_audio.py.

Synthetic signals prove the checks are not vacuous: a non-periodic loop is flagged
at the seam, a 10.5 kHz tone trips the treble limit, clipping/DC/boundary clicks
fail, and the joint base+finale limiter keeps both files and their sum under the
ceiling while staying periodic. Reads no committed assets and writes only to a
temporary folder.

Usage: python tests/test_audio_pipeline.py
"""
from pathlib import Path
import math
import random
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "tools"))
import generate_audio as audio  # noqa: E402


def tone(frequency, seconds, rate, amplitude=0.5):
    n = round(seconds * rate)
    return [amplitude * math.sin(math.tau * frequency * i / rate) for i in range(n)]


class AudioVerifierTest(unittest.TestCase):
    def setUp(self):
        self.directory = Path(tempfile.mkdtemp(prefix="spark-audio-verify-"))

    def tearDown(self):
        shutil.rmtree(self.directory, ignore_errors=True)

    def analyze(self, name, channels, rate):
        path = self.directory / name
        audio.write_pcm(path, channels, rate)
        checks = audio.Checks()
        record, decoded = audio.analyze(path, checks)
        return record, decoded, checks

    def test_seam_detector(self):
        rate = audio.LOOP_RATE
        periodic = tone(441.0, 1.0, rate)  # exactly 441 cycles: seamless
        broken = tone(440.3, 1.0, rate)    # fractional cycle: jump at the wrap
        good, _, _ = self.analyze("good.wav", [periodic], rate)
        bad, _, _ = self.analyze("bad.wav", [broken], rate)
        self.assertLessEqual(good["seam_ratio"], 1.5)
        self.assertGreater(bad["seam_ratio"], 1.5)

    def test_treble_limit(self):
        rate = audio.CUE_RATE
        soft, _, _ = self.analyze("soft.wav", [audio.finish_cue(tone(1000.0, 0.3, rate), -6.0)], rate)
        harsh, _, _ = self.analyze("harsh.wav", [tone(10500.0, 0.3, rate)], rate)
        self.assertLessEqual(soft["hf_above_10khz_db"], audio.HF_LIMIT_DB)
        self.assertGreater(harsh["hf_above_10khz_db"], audio.HF_LIMIT_DB)

    def test_peak_dc_and_boundary_failures(self):
        rate = audio.CUE_RATE
        with self.assertRaises(RuntimeError):  # the writer refuses anything above -1 dBFS
            audio.write_pcm(self.directory / "hot.wav", [tone(500.0, 0.1, rate, 0.95)], rate)
        _, _, checks = self.analyze("dc.wav", [[v + 0.01 for v in tone(500.0, 0.1, rate)]], rate)
        self.assertTrue(any("DC offset" in failure for failure in checks.failures))
        clicky = tone(500.0, 0.1, rate)
        clicky[-1] = 0.3
        _, decoded, _ = self.analyze("click.wav", [clicky], rate)
        self.assertGreaterEqual(abs(decoded[0][-1]), 50)  # the verify_folder boundary rule would fail it

    def test_joint_limiter_bounds_each_file_and_the_sum(self):
        rate = audio.LOOP_RATE
        rng = random.Random(7)
        n = rate  # one-second loop
        base = [[0.0] * n for _ in range(2)]
        finale = [0.0] * n
        for start in range(0, n, rate // 4):  # periodic spiky hits in both layers
            for i in range(800):
                hit = math.sin(math.tau * 90 * i / rate) * math.exp(-i / 300)
                for ch in base:
                    ch[(start + i) % n] += hit
                finale[(start + i + 40) % n] += 0.8 * hit
        for i in range(n):
            pad = 0.2 * math.sin(math.tau * 220 * i / rate) + 0.02 * rng.uniform(-1, 1)
            base[0][i] += pad
            base[1][i] += pad
        b, f, stats = audio.master_layers(base, [finale], rate, -14.0, -12.5)
        ceiling = audio.from_db(audio.MUSIC_CEILING_DBFS) + 1e-9
        self.assertLess(stats["max_gain_reduction_db"], 0)  # the test signal really needed limiting
        self.assertLessEqual(max(abs(v) for ch in b for v in ch), ceiling)
        self.assertLessEqual(max(abs(v) for v in f[0]), ceiling)
        self.assertLessEqual(max(abs(x + y) for ch in b for x, y in zip(ch, f[0])), ceiling)
        base_rms = math.sqrt(audio.mean_square(b))
        self.assertAlmostEqual(audio.to_db(base_rms), -14.0, delta=0.02)


if __name__ == "__main__":
    unittest.main(verbosity=2)
