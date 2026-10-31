"""The updater's manifest for a release's .pck (EQ-14, scripts/core/updater.gd): the
version, the Godot version the pack needs (an update can't change the engine), the
pack's file name, size and SHA-256. tools/export.sh writes it beside the pack.
    python3 tools/update_manifest.py 0.2.0 4.7.2 build/release/SundownRun-0.2.0.pck
"""
import hashlib
import json
import re
import sys
from pathlib import Path


def engine(version_text: str) -> str:
    """MAJOR.MINOR.PATCH from `godot --version` ("4.7.2.stable.official.abc" or "4.7.stable")."""
    m = re.match(r"(\d+)\.(\d+)(?:\.(\d+))?", version_text.strip())
    if not m:
        raise SystemExit(f"not a Godot version: {version_text!r}")
    return f"{m.group(1)}.{m.group(2)}.{m.group(3) or 0}"


def manifest(version: str, godot_version: str, pck: Path) -> dict:
    data = pck.read_bytes()
    return {"version": version, "engine": engine(godot_version), "pck": pck.name,
            "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}


if __name__ == "__main__":
    print(json.dumps(manifest(sys.argv[1], sys.argv[2], Path(sys.argv[3])), indent=1))
