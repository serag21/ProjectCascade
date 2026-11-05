"""Self-test for tools/set_audio_ids.py against a temporary copy of the real AudioCatalog.

Proves the tool rewrites only id fields (byte-for-byte elsewhere), propagates one
upload to entries that share a WAV, keeps the catalog compilable, supports
--dry-run/--replace, and refuses bad input without writing anything.

Usage: python tests/test_set_audio_ids.py
"""
from pathlib import Path
import json
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "set_audio_ids.py"
CATALOG = ROOT / "game" / "ReplicatedStorage" / "Spark" / "AudioCatalog.luau"
COMPILER = ROOT / ".tools" / "luau" / ("luau-compile.exe" if platform.system() == "Windows" else "luau-compile")
EXPECTED_KEYS = {
    # pre-existing keys (must be kept)
    "catch", "bank", "dash", "upgrade", "round_reward", "zap", "pop", "ui", "music",
    # 2026-11 cue set
    "gate_open", "golden_spawn", "golden_catch", "stampede_rumble", "chain_tier", "countdown", "start_whistle",
    "buzzer", "rank_up", "ui_click", "ui_claim", "signature", "starstruck",
    # arena loops + finale layers
    "music_meadow", "music_meadow_finale", "music_canyon", "music_canyon_finale", "music_aurora",
    "music_aurora_finale",
}
ID_FIELD = re.compile(r'\bid="[^"]*"')

sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "tools"))
import set_audio_ids  # noqa: E402


class SetAudioIdsTest(unittest.TestCase):
    def setUp(self):
        self.directory = Path(tempfile.mkdtemp(prefix="spark-audio-ids-"))
        self.catalog = self.directory / "AudioCatalog.luau"
        shutil.copyfile(CATALOG, self.catalog)
        self.original = self.catalog.read_bytes()

    def tearDown(self):
        shutil.rmtree(self.directory, ignore_errors=True)

    def run_tool(self, mapping, *flags, raw=None):
        ids = self.directory / "ids.json"
        ids.write_text(raw if raw is not None else json.dumps(mapping), encoding="utf-8")
        return subprocess.run([sys.executable, str(TOOL), str(ids), "--catalog", str(self.catalog), *flags],
                              capture_output=True, text=True, timeout=60)

    def ids(self):
        entries = set_audio_ids.parse_catalog(self.catalog.read_text(encoding="utf-8"))
        return {key: entry["fields"]["id"] for key, entry in entries.items()}

    def assert_untouched(self, result):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("No changes written", result.stderr)
        self.assertEqual(self.catalog.read_bytes(), self.original)

    def test_catalog_has_exactly_the_contracted_keys(self):
        self.assertEqual(set(self.ids()), EXPECTED_KEYS)
        self.assertTrue(all(value == "" for value in self.ids().values()), "repo catalog must ship with empty ids")

    def test_rewrites_only_id_fields_and_shares_uploads(self):
        result = self.run_tool({"catch": 1234567, "ui_click": "2345678", "music_meadow": "rbxassetid://3456789"})
        self.assertEqual(result.returncode, 0, result.stderr)
        ids = self.ids()
        self.assertEqual(ids["catch"], "rbxassetid://1234567")
        self.assertEqual(ids["ui_click"], "rbxassetid://2345678")
        self.assertEqual(ids["ui"], "rbxassetid://2345678")  # same WAV -> same upload
        self.assertEqual(ids["music_meadow"], "rbxassetid://3456789")
        self.assertEqual(ids["music_meadow_finale"], "")  # different WAV, not filled
        self.assertEqual(sum(1 for value in ids.values() if value), 4)
        self.assertIn("same file as ui_click", result.stdout)
        # Every byte other than the id values is identical (comments, order, spacing, newlines).
        rewritten = self.catalog.read_bytes().decode("utf-8")
        self.assertEqual(ID_FIELD.sub('id=""', rewritten), self.original.decode("utf-8"))

    @unittest.skipUnless(COMPILER.exists(), "luau-compile not installed in .tools/luau")
    def test_rewritten_catalog_compiles(self):
        mapping = {key: 1000 + i for i, key in enumerate(sorted(EXPECTED_KEYS - {"ui"}))}
        result = self.run_tool(mapping)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(self.ids().values()), "every entry should now carry an id")
        compiled = subprocess.run([str(COMPILER), "--null", str(self.catalog)], capture_output=True, text=True)
        self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_dry_run_writes_nothing(self):
        result = self.run_tool({"zap": 42}, "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('+\tzap={id="rbxassetid://42"', result.stdout)
        self.assertIn("nothing written", result.stdout)
        self.assertEqual(self.catalog.read_bytes(), self.original)

    def test_unknown_key_refused(self):
        result = self.run_tool({"catch": 1, "not_a_cue": 2})
        self.assert_untouched(result)
        self.assertIn("not_a_cue", result.stderr)

    def test_bad_ids_refused(self):
        for bad in (0, -5, 1.5, 7.0, "abc", "12a", "", " ", "rbxassetid://", "-3", "0012", True, None, [1],
                    {"id": 1}, 2 ** 53):
            with self.subTest(bad=bad):
                self.assert_untouched(self.run_tool({"catch": bad}))

    def test_malformed_files_refused(self):
        self.assert_untouched(self.run_tool(None, raw='{"catch": 1, "catch": 2}'))  # duplicate key
        self.assert_untouched(self.run_tool(None, raw="[1, 2]"))  # not an object
        self.assert_untouched(self.run_tool(None, raw="{not json"))

    def test_same_id_for_different_files_refused(self):
        result = self.run_tool({"catch": 555, "bank": 555})
        self.assert_untouched(result)
        self.assertIn("different WAV files", result.stderr)
        self.assert_untouched(self.run_tool({"ui": 1, "ui_click": 2}))  # same WAV, conflicting ids

    def test_existing_ids_need_replace_and_reruns_are_idempotent(self):
        self.assertEqual(self.run_tool({"catch": 111}).returncode, 0)
        after_first = self.catalog.read_bytes()
        result = self.run_tool({"catch": 999})
        self.assertEqual(result.returncode, 1)
        self.assertIn("--replace", result.stderr)
        self.assertEqual(self.catalog.read_bytes(), after_first)
        again = self.run_tool({"catch": 111})
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertIn("Updated 0 id field(s)", again.stdout)
        self.assertEqual(self.catalog.read_bytes(), after_first)
        replaced = self.run_tool({"catch": 999}, "--replace")
        self.assertEqual(replaced.returncode, 0, replaced.stderr)
        self.assertEqual(self.ids()["catch"], "rbxassetid://999")

    def test_unsupported_catalog_structure_refused(self):
        text = self.original.decode("utf-8").replace("return {", "local helper = function() end\nreturn {", 1)
        self.catalog.write_text(text, encoding="utf-8")
        self.original = self.catalog.read_bytes()
        self.assert_untouched(self.run_tool({"catch": 1}))
        with self.assertRaises(set_audio_ids.CatalogError):
            set_audio_ids.parse_catalog('return {\n\tcatch={id="",volume=math.huge},\n}\n')
        with self.assertRaises(set_audio_ids.CatalogError):
            set_audio_ids.parse_catalog('return {\n\tcatch={id=""},\n\tcatch={id=""},\n}\n')

    def test_parser_reads_values(self):
        entries = set_audio_ids.parse_catalog(
            'return {\n\ta={id="x",volume=.5,n=-2,big=1e3,flag=true,s="q\\"}",}, -- note {brace}\n}\n')
        self.assertEqual(entries["a"]["fields"], {"id": "x", "volume": 0.5, "n": -2, "big": 1000.0, "flag": True,
                                                  "s": 'q"}'})


if __name__ == "__main__":
    unittest.main(verbosity=2)
