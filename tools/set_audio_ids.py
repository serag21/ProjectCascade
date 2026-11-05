"""Write owner-uploaded Roblox audio asset IDs into AudioCatalog.luau.

Workflow: upload the WAVs from assets/audio with Studio's Asset Manager, copy each
asset ID, and save a JSON object mapping AudioCatalog keys to IDs, for example
{"catch": 1234567, "music_meadow": 2345678}. Then, from the repository root:

    python tools/set_audio_ids.py ids.json --dry-run   # print the exact diff, write nothing
    python tools/set_audio_ids.py ids.json             # rewrite only the matching id="" fields

Rules (any violation exits with status 1 and writes nothing):
* keys must already exist in AudioCatalog.luau (unknown keys are refused);
* IDs must be positive integers: JSON numbers, or digit strings / "rbxassetid://<n>"
  pasted from Studio. Booleans, floats, zero, negatives and other text are refused;
* catalog entries that reference the same WAV share one upload: an ID given for one
  also fills the others (e.g. "ui_click" fills "ui") unless they are listed explicitly;
* one asset ID may not be assigned to two different WAV files (copy/paste guard);
* an entry that already holds a different ID is refused unless --replace is passed.

Only the text inside id="..." changes; comments, ordering and every other byte are
preserved. The catalog must keep one `key={...},` entry per line with plain values
(strings, numbers, booleans), which is how AudioCatalog.luau is written.
Self-test: python tests/test_set_audio_ids.py
"""
from __future__ import annotations

import argparse
import difflib
import json
import os
from pathlib import Path
import re
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "game" / "ReplicatedStorage" / "Spark" / "AudioCatalog.luau"
MAX_ASSET_ID = 2 ** 53 - 1  # exact in JSON/Lua doubles

NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
ENTRY_START = re.compile(r"^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{")
NUMBER = re.compile(r"-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?")
RETURN_OPEN = re.compile(r"^\s*return\s*\{\s*(--.*)?$")
TABLE_CLOSE = re.compile(r"^\s*\}\s*(--.*)?$")
IGNORABLE = re.compile(r"^\s*(--.*)?$")
TRAILER = re.compile(r"^\s*,?\s*(--.*)?$")
ESCAPES = {"n": "\n", "t": "\t", "\\": "\\", '"': '"', "'": "'"}


class CatalogError(ValueError):
    """The catalog or the ID mapping is not acceptable; nothing was written."""


def _parse_entry(line: str, number: int) -> tuple[str, dict, dict]:
    match = ENTRY_START.match(line)
    key, pos, n = match.group(2), match.end(), len(line)
    fields: dict = {}
    spans: dict = {}
    while True:
        while pos < n and line[pos] in " \t":
            pos += 1
        if pos < n and line[pos] == "}":
            pos += 1
            break
        name = NAME.match(line, pos)
        if not name:
            raise CatalogError(f"line {number}: expected name=value in entry '{key}'")
        pos = name.end()
        while pos < n and line[pos] in " \t":
            pos += 1
        if pos >= n or line[pos] != "=":
            raise CatalogError(f"line {number}: expected '=' after '{name.group()}' in entry '{key}'")
        pos += 1
        while pos < n and line[pos] in " \t":
            pos += 1
        start = pos
        if pos < n and line[pos] in "\"'":
            quote, pos, chars = line[pos], pos + 1, []
            while pos < n and line[pos] != quote:
                if line[pos] == "\\":
                    if pos + 1 >= n or line[pos + 1] not in ESCAPES:
                        raise CatalogError(f"line {number}: unsupported escape in entry '{key}'")
                    chars.append(ESCAPES[line[pos + 1]])
                    pos += 2
                else:
                    chars.append(line[pos])
                    pos += 1
            if pos >= n:
                raise CatalogError(f"line {number}: unterminated string in entry '{key}'")
            pos += 1
            value = "".join(chars)
        elif line.startswith("true", pos) or line.startswith("false", pos):
            value = line.startswith("true", pos)
            pos += 4 if value else 5
        else:
            token = NUMBER.match(line, pos)
            if not token:
                raise CatalogError(f"line {number}: entry '{key}' field '{name.group()}' must be a string, "
                                   "number or boolean (values only)")
            pos = token.end()
            text = token.group()
            value = int(text) if re.fullmatch(r"-?\d+", text) else float(text)
        if name.group() in fields:
            raise CatalogError(f"line {number}: duplicate field '{name.group()}' in entry '{key}'")
        fields[name.group()] = value
        spans[name.group()] = (start, pos)
        while pos < n and line[pos] in " \t":
            pos += 1
        if pos < n and line[pos] == ",":
            pos += 1
        elif pos < n and line[pos] == "}":
            continue
        else:
            raise CatalogError(f"line {number}: expected ',' or '}}' in entry '{key}'")
    if not TRAILER.match(line[pos:]):
        raise CatalogError(f"line {number}: unexpected text after entry '{key}'")
    return key, fields, spans


def parse_catalog(text: str) -> dict:
    """Return {key: {"line": index, "fields": {...}, "spans": {...}}} in catalog order."""
    lines = text.splitlines()
    opens = [i for i, line in enumerate(lines) if RETURN_OPEN.match(line)]
    if len(opens) != 1:
        raise CatalogError("expected exactly one 'return {' line")
    for i in range(opens[0]):
        if not IGNORABLE.match(lines[i]):
            raise CatalogError(f"line {i + 1}: only comments may precede 'return {{' (values-only module)")
    entries: dict = {}
    close = None
    for i in range(opens[0] + 1, len(lines)):
        line = lines[i]
        if TABLE_CLOSE.match(line):
            close = i
            break
        if IGNORABLE.match(line):
            continue
        if not ENTRY_START.match(line):
            raise CatalogError(f"line {i + 1}: expected one `key={{...}},` entry per line")
        key, fields, spans = _parse_entry(line, i + 1)
        if key in entries:
            raise CatalogError(f"line {i + 1}: duplicate key '{key}'")
        entries[key] = {"line": i, "fields": fields, "spans": spans}
    if close is None:
        raise CatalogError("missing closing '}' for the returned table")
    for i in range(close + 1, len(lines)):
        if not IGNORABLE.match(lines[i]):
            raise CatalogError(f"line {i + 1}: unexpected code after the returned table")
    return entries


def normalize_id(key: str, value) -> int:
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        raise CatalogError(f"'{key}': asset id must be a positive integer, got {json.dumps(value)}")
    if isinstance(value, str):
        match = re.fullmatch(r"(?:rbxassetid://)?([1-9][0-9]*)", value.strip())
        if not match:
            raise CatalogError(f"'{key}': asset id must be a positive integer, got {json.dumps(value)}")
        value = int(match.group(1))
    if not 0 < value <= MAX_ASSET_ID:
        raise CatalogError(f"'{key}': asset id must be a positive integer, got {value}")
    return value


def apply_ids(text: str, mapping: dict, replace: bool = False) -> tuple[str, list]:
    """Return (new_text, changes). changes: (key, old, new, reason) for rewritten entries."""
    if not isinstance(mapping, dict):
        raise CatalogError("the ID file must contain a JSON object of {catalog_key: asset_id}")
    entries = parse_catalog(text)
    unknown = sorted(k for k in mapping if k not in entries)
    if unknown:
        raise CatalogError("unknown AudioCatalog key(s): " + ", ".join(unknown)
                           + "; known keys: " + ", ".join(entries))
    ids = {key: normalize_id(key, value) for key, value in mapping.items()}
    for key in ids:
        if not isinstance(entries[key]["fields"].get("id"), str):
            raise CatalogError(f"'{key}' has no string id field to rewrite")

    def file_of(key):
        value = entries[key]["fields"].get("file", "")
        return value if isinstance(value, str) else ""

    targets = {key: (asset, "given") for key, asset in ids.items()}
    for key, asset in ids.items():
        filename = file_of(key)
        if not filename:
            continue
        for other in entries:
            if other == key or file_of(other) != filename:
                continue
            if other in ids:
                if ids[other] != asset:
                    raise CatalogError(f"'{key}' and '{other}' share {filename} but were given different ids")
            elif isinstance(entries[other]["fields"].get("id"), str):
                targets.setdefault(other, (asset, f"same file as {key}"))
    owners: dict = {}
    for key, (asset, _) in targets.items():
        owners.setdefault(asset, set()).add(file_of(key) or f"<{key}>")
    clashes = sorted(f"{asset} -> {', '.join(sorted(files))}" for asset, files in owners.items() if len(files) > 1)
    if clashes:
        raise CatalogError("the same asset id was given to different WAV files: " + "; ".join(clashes))

    lines = text.splitlines(keepends=True)
    changes, conflicts = [], []
    for key, entry in entries.items():
        if key not in targets:
            continue
        asset, reason = targets[key]
        old, new = entry["fields"]["id"], f"rbxassetid://{asset}"
        if old == new:
            continue
        if old and not replace:
            conflicts.append(f"{key} already has id \"{old}\"")
            continue
        start, end = entry["spans"]["id"]
        line = lines[entry["line"]]
        lines[entry["line"]] = line[:start] + json.dumps(new) + line[end:]
        changes.append((key, old, new, reason))
    if conflicts:
        raise CatalogError("refusing to overwrite existing ids (pass --replace to allow): " + "; ".join(conflicts))
    return "".join(lines), changes


def _load_mapping(source: str) -> dict:
    def no_duplicates(pairs):
        seen = {}
        for key, value in pairs:
            if key in seen:
                raise CatalogError(f"duplicate key '{key}' in the ID file")
            seen[key] = value
        return seen

    raw = sys.stdin.read() if source == "-" else Path(source).read_text(encoding="utf-8")
    try:
        return json.loads(raw, object_pairs_hook=no_duplicates)
    except json.JSONDecodeError as error:
        raise CatalogError(f"ID file is not valid JSON: {error}") from None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("ids", help="JSON file mapping AudioCatalog keys to Roblox asset ids ('-' for stdin)")
    parser.add_argument("--catalog", type=Path, default=CATALOG, help="catalog to rewrite (default: %(default)s)")
    parser.add_argument("--dry-run", action="store_true", help="print the diff and write nothing")
    parser.add_argument("--replace", action="store_true", help="allow overwriting ids that are already set")
    args = parser.parse_args(argv)
    try:
        text = args.catalog.read_text(encoding="utf-8")
        new_text, changes = apply_ids(text, _load_mapping(args.ids), args.replace)
    except (CatalogError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        print("No changes written.", file=sys.stderr)
        return 1
    for key, old, new, reason in changes:
        print(f"{key}: {json.dumps(old)} -> {json.dumps(new)} ({reason})")
    if args.dry_run:
        diff = difflib.unified_diff(text.splitlines(keepends=True), new_text.splitlines(keepends=True),
                                    str(args.catalog), str(args.catalog) + " (proposed)")
        sys.stdout.writelines(diff)
        print(f"Dry run: {len(changes)} id field(s) would change; nothing written.")
        return 0
    if changes:
        fd, temporary = tempfile.mkstemp(prefix=".audiocatalog-", dir=str(args.catalog.parent))
        try:
            with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
                handle.write(new_text)
            os.replace(temporary, args.catalog)
        except BaseException:
            if os.path.exists(temporary):
                os.unlink(temporary)
            raise
    missing = [key for key, entry in parse_catalog(new_text).items() if entry["fields"].get("id") == ""]
    print(f"Updated {len(changes)} id field(s) in {args.catalog}.")
    if missing:
        print(f"{len(missing)} entr{'y' if len(missing) == 1 else 'ies'} still without an uploaded id: " + ", ".join(missing))
    print("Next: compile the catalog (luau-compile --null) and listen in Studio before release.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
