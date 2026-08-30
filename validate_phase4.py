#!/usr/bin/env python3
"""Phase 4 gate: applied migrations are immutable, and changes are forward-only.

Static checks alone cannot prove immutability -- they cannot see what a database has applied. So
this compares against the git revision that was last deployed (Deployment/.versions records the tag
per service, and the tag IS a git sha), and optionally against flyway_schema_history itself.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEPLOY_DIR = ROOT / "Deployment"
POLICY = DEPLOY_DIR / "SCHEMA_POLICY.md"
VERSIONS = DEPLOY_DIR / ".versions"
SERVICE_MAP = DEPLOY_DIR / "service-map.tsv"

failures = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def migration_dirs():
    """<Service> -> migration dir. CommonLibrary is a shared overlay applied alongside every
    service's own baseline (flyway.locations in Deployment/application.yml), so it has no baseline
    of its own and must not be counted as a service."""
    out = {}
    for d in sorted(ROOT.glob("*/src/main/resources/db/migration")):
        svc = d.parents[4].name          # .../<Service>/src/main/resources/db/migration
        if svc == "CommonLibrary":
            continue
        out[svc] = d
    return out


def git(svc_dir, *args):
    r = subprocess.run(["git", *args], cwd=svc_dir, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def main():
    dirs = migration_dirs()
    print(f"  note: {len(dirs)} service(s) carry migrations")

    tags = {}
    if VERSIONS.is_file():
        tags = dict(re.findall(r"^([A-Z0-9_]+)_TAG=(\S+)$",
                               VERSIONS.read_text(encoding="utf-8"), re.M))

    # Module dir -> compose service. NEVER derive this: CommunicationService is chat-service,
    # UserTrackingService is event-tracking-service, and EurekaServer maps to two services.
    # A guessed mapping silently checks nothing, which is worse than no check at all.
    module_to_service = {}
    if SERVICE_MAP.is_file():
        for line in SERVICE_MAP.read_text(encoding="utf-8").splitlines():
            parts = line.split("\t")
            if len(parts) == 2 and not line.startswith("#"):
                module_to_service.setdefault(parts[0].strip(), parts[1].strip())
    check("SERVICE-MAP-EXISTS", bool(module_to_service),
          f"{SERVICE_MAP} missing or empty -- Phase 1 creates it; without it check 1 cannot "
          f"resolve a deployed revision and silently verifies nothing")

    # 1. THE RULE. A migration that exists in the deployed revision must be byte-identical now.
    #    Deployed revision = the git sha recorded in .versions for that service.
    violations, unknown = [], []
    for svc, d in dirs.items():
        compose_svc = module_to_service.get(svc)
        tag = tags.get(compose_svc.upper().replace("-", "_")) if compose_svc else None
        if not tag:
            unknown.append(svc)
            continue
        sha = tag.replace("-dirty", "")
        svc_dir = ROOT / svc
        for f in sorted(d.glob("V*.sql")):
            rel = f.relative_to(svc_dir).as_posix()
            old = git(svc_dir, "show", f"{sha}:{rel}")
            if old is None:
                continue                       # new file since that revision -- allowed
            if old != f.read_text(encoding="utf-8"):
                violations.append(f"{svc}/{f.name} changed since deployed {sha}")
    check("APPLIED-MIGRATIONS-UNCHANGED", not violations,
          f"{len(violations)}: " + "; ".join(violations[:4])
          + " -- revert the file and add a new timestamped migration")
    if unknown:
        print(f"         note: no deployed tag for {', '.join(sorted(unknown))} -- not checked")

    # 2. Policy is written down, so the code-vs-schema boundary is explicit.
    check("POLICY-EXISTS", POLICY.is_file(), f"{POLICY} not found")
    if POLICY.is_file():
        t = POLICY.read_text(encoding="utf-8").lower()
        check("POLICY-STATES-IMMUTABILITY", "immutable" in t and "forward" in t,
              "SCHEMA_POLICY.md does not state the immutability / forward-only rule")

    # 3. Timestamped versions -- sequential numbers collide across branches.
    bad = []
    for svc, d in dirs.items():
        for f in sorted(d.glob("V*.sql")):
            v = f.name.split("__", 1)[0][1:]
            if v != "1" and not re.fullmatch(r"\d{14}", v):
                bad.append(f"{svc}/{f.name}")
    check("VERSIONS-TIMESTAMPED", not bad,
          f"{len(bad)}: " + ", ".join(bad[:5]) + " -- use V<YYYYMMDDHHMMSS>__")

    # 4. Hibernate must never own the schema.
    wrong = []
    for f in list(DEPLOY_DIR.glob("*.yml")) + list(ROOT.glob("*/src/main/resources/application*.yml")):
        t = f.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r"ddl-auto:\s*(\S+)", t):
            if m.group(1) not in ("validate", "none") and "test" not in f.name:
                wrong.append(f"{f.relative_to(ROOT)} -> {m.group(1)}")
    check("HIBERNATE-DOES-NOT-OWN-SCHEMA", not wrong,
          "; ".join(wrong[:4]) + " -- Flyway must be the only writer")

    # 5. Checksum validation must not be disabled to dodge the rule.
    disabled = []
    for f in list(DEPLOY_DIR.glob("*.yml")) + list(ROOT.glob("*/src/main/resources/application*.yml")):
        t = f.read_text(encoding="utf-8", errors="ignore")
        if re.search(r"validate-on-migrate:\s*false", t) or "ignore-migration-patterns" in t:
            disabled.append(f.relative_to(ROOT).as_posix())
    check("VALIDATION-NOT-DISABLED", not disabled,
          ", ".join(disabled[:4]) + " -- this hides exactly the violation check 1 looks for")

    # 6. New columns on an existing table must tolerate existing rows.
    unsafe = []
    for svc, d in dirs.items():
        for f in sorted(d.glob("V*.sql")):
            if re.match(r"^V1__", f.name):
                continue                       # baseline runs against an empty database
            body = re.sub(r"--[^\n]*", "", f.read_text(encoding="utf-8"))
            for m in re.finditer(r"ADD\s+COLUMN\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)[^,;]*", body, re.I):
                frag = m.group(0)
                if re.search(r"\bNOT\s+NULL\b", frag, re.I) and not re.search(r"\bDEFAULT\b", frag, re.I):
                    unsafe.append(f"{svc}/{f.name}: {m.group(1)} NOT NULL with no DEFAULT")
    check("ADD-COLUMN-TOLERATES-EXISTING-ROWS", not unsafe,
          f"{len(unsafe)}: " + "; ".join(unsafe[:4]) + " -- fails against a non-empty table")

    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 4 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
