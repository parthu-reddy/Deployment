#!/usr/bin/env python3
"""Phase 3 gate: the reset is targeted, and a targeted reset cannot touch its neighbours.

The destructive checks run against the live VM, so this gate is only meaningful with --remote.
It never wipes anything itself; it verifies the script's refusals and reads current state.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DD = ROOT / "Deployment/OracleDeployment/DummyData"
SCRIPT = DD / "reset_remote_db.sh"
TABLE = DD / "schema_sentinels.tsv"
SSH_KEY = "/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"
VM = "ubuntu@140.245.234.137"
REMOTE = "Food Delivery.nosync/Deployment"

failures = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def sh(cmd):
    return subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True, timeout=180)


def psql(db, sql):
    import base64
    b = base64.b64encode(sql.encode()).decode()
    cmd = (f"ssh -o StrictHostKeyChecking=no -i {SSH_KEY} {VM} "
           f"\"cd '{REMOTE}' && docker compose exec -T postgres sh -c "
           f"'echo {b} | base64 -d | PGPASSWORD=\\$POSTGRES_PASS psql -h 127.0.0.1 -U postgres -d {db} -tA -f -'\"")
    return sh(cmd).stdout.strip()


def main():
    remote = "--remote" in sys.argv
    body = SCRIPT.read_text(encoding="utf-8") if SCRIPT.is_file() else ""
    nocomment = re.sub(r"#[^\n]*", "", body)

    check("SCRIPT-EXISTS", SCRIPT.is_file(), f"{SCRIPT} missing")
    check("TABLE-WIDENED", TABLE.is_file() and any(
        len(l.split("\t")) >= 4 for l in TABLE.read_text(encoding="utf-8").splitlines()
        if l.strip() and not l.startswith("#")),
        "schema_sentinels.tsv does not carry database/service/sentinel/extensions")

    check("ALL-IS-EXPLICIT", "--all" in nocomment,
          "there is no --all flag, so the destructive scope is still implicit")
    check("KEEPS-CONFIRMATION", "WIPE" in body, "the WIPE prompt was removed")
    check("IN-CONTAINER-PASSWORD", "POSTGRES_PASS" in body and "PGPASSWORD" in body,
          "the password is not read inside the container")
    check("BASE64-SQL", "base64" in nocomment,
          "SQL is not base64-encoded; a literal single quote closes the sh -c quoting and truncates it")

    # Refusals must be observable, not merely present in the source.
    r = sh(f"bash '{SCRIPT}' </dev/null")
    check("NO-ARGS-REFUSED", r.returncode != 0 and re.search(r"usage", r.stdout + r.stderr, re.I) is not None,
          "running with no arguments did not print usage and exit non-zero — it may still default to all")
    r2 = sh(f"bash '{SCRIPT}' not_a_database </dev/null")
    check("UNKNOWN-DB-REFUSED", r2.returncode != 0,
          "an unknown database name was not rejected")

    # Redis is global; it must not be flushed by a targeted reset.
    m = re.search(r"FLUSHALL", nocomment)
    if m:
        window = nocomment[max(0, m.start() - 400):m.start()]
        check("REDIS-ONLY-ON-ALL", re.search(r"ALL|all", window) is not None,
              "FLUSHALL is not guarded by --all; a targeted reset would clear every service's cache")

    if remote and TABLE.is_file():
        rows = [l.split("\t") for l in TABLE.read_text(encoding="utf-8").splitlines()
                if l.strip() and not l.startswith("#")]
        # Every declared extension must actually exist right now.
        missing = []
        for row in rows:
            if len(row) < 4 or row[3].strip() in ("-", ""):
                continue
            for ext in row[3].split(","):
                ext = ext.strip()
                got = psql(row[0], f"SELECT count(*) FROM pg_extension WHERE extname='{ext}'")
                if got != "1":
                    missing.append(f"{row[0]}:{ext}")
        check("EXTENSIONS-PRESENT", not missing,
              f"declared extension(s) absent on the VM: {', '.join(missing)} — a wipe would "
              "drop them and the owning service would fail its migrations on boot")

        # Every declared sentinel must exist, or the wait can never succeed.
        absent = []
        for row in rows:
            if len(row) < 3:
                continue
            got = psql(row[0], "SELECT EXISTS (SELECT FROM information_schema.tables "
                               f"WHERE table_schema='public' AND table_name='{row[2].strip()}')")
            if "t" not in got:
                absent.append(f"{row[0]}.{row[2].strip()}")
        check("SENTINELS-PRESENT", not absent,
              f"sentinel table(s) missing: {', '.join(absent)}")
    else:
        print("\n  note: extension/sentinel checks SKIPPED — rerun with --remote")

    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 3 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
