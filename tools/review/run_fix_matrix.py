"""Sequential final-pack UI, pet/preparation and shutdown regression matrix."""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--resume", type=Path, help="Reuse passing cases only when their exported pack hash still matches")
    parser.add_argument("--rerun", action="append", default=[], help="Rerun this named case while preserving its previous result")
    args = parser.parse_args()
    previous = {}
    if args.resume:
        base = args.resume.resolve()
        saved = json.loads((ROOT / "build/validation/world-art-02/runtime-matrix.json").read_text(encoding="utf-8"))
        if (ROOT / saved["directory"]).resolve() != base:
            parser.error("Resume directory must match the preserved partial matrix")
        previous = {row["name"]: row for row in saved["cases"]}
    else:
        base = ROOT / "build/review" / (datetime.now().strftime("%Y%m%d-%H%M%S") + "-fix-matrix")
        base.mkdir(parents=True)
    current_pack = hashlib.sha256((ROOT / "build/windows/ProjectSevenSeas.pck").read_bytes()).hexdigest()
    cases = [("controls", "controls", False, 180), ("fixes", "fixes_regression", False, 180),
        ("quit-dummy", "title_quit", False, 40), ("quit-wasapi", "title_quit", True, 40),
        ("close-dummy", "window_close", False, 40), ("close-wasapi", "window_close", True, 40),
        ("native-wasapi", "native-startup", True, 40)]
    results = []
    for label, scenario, audio, timeout in cases:
        old = previous.get(label)
        if old and old["passed"] and label not in args.rerun:
            inv = json.loads((ROOT / old["directory"] / "invocation.json").read_text(encoding="utf-8"))
            if inv["pck_sha256"] != current_pack:
                raise SystemExit("Cannot reuse a passing case from a different pack")
            results.append(old)
            print(json.dumps({"name": label, "reused_verified_case": old["directory"]}), flush=True)
            continue
        folder = base / label
        if folder.exists():
            folder = base / (label + "-retry-" + datetime.now().strftime("%H%M%S"))
        command = [sys.executable, str(ROOT / "tools/review/run_fullscreen.py"), "--scenario", scenario,
            "--timeout", str(timeout), "--out", str(folder)]
        if audio:
            command.append("--audio")
        if scenario == "fixes_regression":
            command += ["--resume-profile", str(args.profile.resolve())]
        with (base / (label + "-runner.log")).open("w", encoding="utf-8") as output:
            proc = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=timeout + 20)
        checks = []
        for filename in ("review-evidence.json", "quit-ui-evidence.json", "window-close-evidence.json"):
            if (folder / filename).exists():
                checks = json.loads((folder / filename).read_text(encoding="utf-8")).get("checks", [])
                break
        log = (folder / "runtime.log").read_text(encoding="utf-8", errors="replace")
        errors = [x for x in log.splitlines() if "SCRIPT ERROR" in x or x.startswith("ERROR:")]
        resource_warnings = [x for x in log.splitlines() if x.startswith("WARNING:") and ("leaked" in x or "resources" in x)]
        failures = [x["name"] for x in checks if not x["passed"]]
        passed = proc.returncode == 0 and not errors and not failures and not resource_warnings
        if scenario not in ("native-title", "native-startup") and not checks:
            passed = False
        row = {"name": label, "directory": folder.relative_to(ROOT).as_posix(), "scenario": scenario,
            "audio": "default requested" if audio else "Dummy", "checks": len(checks), "failed_checks": failures,
            "runner_exit": proc.returncode, "errors": errors, "passed": passed,
            "resource_warnings": resource_warnings,
            "wasapi_activated": "WASAPI: Activated output_device" in log,
            "mixer_unavailable_observed": "output mixer unavailable" in log}
        if old:
            row["previous_attempts"] = old.get("previous_attempts", []) + [{k: v for k, v in old.items() if k != "previous_attempts"}]
        results.append(row)
        result = {"revision": "world-art-02", "directory": base.relative_to(ROOT).as_posix(),
            "passed": all(x["passed"] for x in results) and len(results) == len(cases), "cases": results}
        (ROOT / "build/validation/world-art-02/runtime-matrix.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(row), flush=True)
        if not passed:
            print(log[-5000:])
            raise SystemExit(1)
    print("Final matrix passed:", base, flush=True)


if __name__ == "__main__":
    main()
