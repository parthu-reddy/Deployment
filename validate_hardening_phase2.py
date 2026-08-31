#!/usr/bin/env python3
"""Phase 2 gate: an edited applied migration is caught by the routine local validator.

This gate deliberately tests the CHECK, not the migrations. It edits a real migration, runs the
validator, and requires it to fail -- then restores. A check that has never been seen to fail is
not protection.
"""
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "FoodDeliveryContracts/validate_core_services.py"
MAP = ROOT / "Deployment/service-map.tsv"
VERSIONS = ROOT / "Deployment/.versions"

failures = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def run_validator():
    r = subprocess.run([sys.executable, str(VALIDATOR)], cwd=ROOT, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def modules_with_migrations():
    out = []
    for line in MAP.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or "\t" not in line:
            continue
        mod = line.split("\t")[0]
        if (ROOT / mod / "src/main/resources/db/migration").is_dir():
            out.append(mod)
    return sorted(set(out))


def main():
    src = VALIDATOR.read_text(encoding="utf-8")
    check("CHECK-REGISTERED", "SCHEMA-IMMUTABLE" in src,
          "validate_core_services.py has no SCHEMA-IMMUTABLE check")

    rc, out = run_validator()
    check("VALIDATOR-GREEN-BASELINE", rc == 0,
          "the validator does not pass on an unmodified tree; fix that before trusting anything below")
    check("CHECK-RUNS", "SCHEMA-IMMUTABLE" in out,
          "the check is defined but never executed (guarded by a condition that is never true?)")

    mods = modules_with_migrations()
    check("MODULES-DISCOVERED", len(mods) > 0,
          "no module with db/migration found via service-map.tsv; the check has nothing to inspect")

    # The real test: break an applied migration and require the validator to notice.
    target = None
    for m in mods:
        d = ROOT / m / "src/main/resources/db/migration"
        files = sorted(d.glob("V*.sql"))
        if files:
            target = files[0]
            break

    if target is None:
        check("BREAK-TEST", False, "no V*.sql migration found to break-test with")
    else:
        backup = Path(tempfile.mkdtemp()) / target.name
        shutil.copy2(target, backup)
        try:
            target.write_text(target.read_text(encoding="utf-8") + "\n-- immutability probe\n",
                              encoding="utf-8")
            rc2, out2 = run_validator()
            fired = rc2 != 0 and re.search(r"FAIL.*SCHEMA-IMMUTABLE", out2) is not None
            check("BREAK-TEST-FIRES", fired,
                  f"editing an applied migration ({target.name}) did NOT fail SCHEMA-IMMUTABLE — "
                  "the check is not looking at what you think it is")
            check("BREAK-TEST-NAMES-FILE", (not fired) or (target.name in out2),
                  "the failure does not name the offending file, so the remedy is unclear")
        finally:
            shutil.copy2(backup, target)

        rc3, _ = run_validator()
        check("RESTORED", rc3 == 0, "the tree was not restored cleanly after the break-test")

    # A newly ADDED migration must not trip the check, or the rule blocks the intended workflow.
    if target is not None:
        probe = target.parent / "V29990101000000__hardening_probe.sql"
        try:
            probe.write_text("-- probe\nSELECT 1;\n", encoding="utf-8")
            rc4, out4 = run_validator()
            check("NEW-MIGRATION-ALLOWED", rc4 == 0,
                  "adding a new timestamped migration fails the validator; a rule that refuses "
                  "everything is indistinguishable from a broken rollback")
        finally:
            probe.unlink(missing_ok=True)

    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 2 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
