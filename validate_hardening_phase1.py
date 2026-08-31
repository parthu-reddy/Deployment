#!/usr/bin/env python3
"""Phase 1 gate: config delivery is scripted, verified, and cannot silently no-op.

The point of this phase is that a config push which does not land must FAIL. Every check below
exists because the manual path could not tell success from silence.
"""
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEPLOY = ROOT / "Deployment"
SSH_KEY = "/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"
VM = "ubuntu@140.245.234.137"
REMOTE = "Food Delivery.nosync/Deployment"

failures = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def ssh(cmd):
    return subprocess.run(
        ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=20", "-i", SSH_KEY, VM, cmd],
        capture_output=True, text=True, timeout=180).stdout


def main():
    remote = "--remote" in sys.argv
    p = DEPLOY / "publish-config.sh"
    body = re.sub(r"#[^\n]*", "", p.read_text(encoding="utf-8")) if p.is_file() else ""
    dbody = re.sub(r"#[^\n]*", "", (DEPLOY / "deploy.sh").read_text(encoding="utf-8"))

    check("CONFIG-SCRIPT-EXISTS", p.is_file(), "Deployment/publish-config.sh missing")

    # The failure this phase exists to prevent: rsync exits 0 having written nothing.
    check("VERIFIES-CHECKSUMS",
          re.search(r"md5|sha256|cksum", body) is not None,
          "publish-config.sh does not checksum anything; rsync's exit code cannot detect a "
          "mis-quoted remote path, which is exactly how a config push silently no-opped")

    # macOS rsync 2.6.9 has no --protect-args, so the space must be escaped for the remote shell.
    uses_rsync = "rsync" in body
    escaped = re.search(r"Food\\\\ Delivery", body) or "--protect-args" in body or "-s " in body
    check("ESCAPES-REMOTE-PATH", (not uses_rsync) or bool(escaped),
          "the remote path contains a space and is not escaped for the remote shell; "
          r"use 'ubuntu@HOST:/home/ubuntu/Food\\ Delivery.nosync/...'")

    check("NEVER-DELETES", "--delete" not in body,
          "publish-config.sh uses --delete; removing remote files is reconcile.sh's job, explicitly")

    for key in (".env", "node_modules"):
        check(f"EXCLUDES-{key.strip('.').upper()}", key in body,
              f"{key} is not excluded; shipping it from a laptop overwrites what the vault flow writes")

    check("DEPLOY-HAS-CONFIG-FLAG", "--config" in dbody,
          "deploy.sh has no --config entry point")

    # Ordering: helpers must be defined before the branch that calls them. Two ordering bugs have
    # already shipped in deploy.sh.
    if "--config" in dbody:
        first_use = dbody.find("publish-config.sh")
        defn = dbody.find("config_deploy()")
        check("CONFIG-HELPER-ORDER", defn == -1 or first_use == -1 or defn < first_use,
              "the --config branch calls a helper defined later in the file")

    check("DRY-RUN", "--dry-run" in body, "no --dry-run; there is no way to see what would ship")

    if remote:
        # Local and VM must agree on every served config file. A mismatch means someone's change
        # did not land -- the exact silent failure this phase addresses.
        local = {f.name: hashlib.md5(f.read_bytes()).hexdigest()
                 for f in DEPLOY.glob("*.yml")}
        out = ssh(f"cd '{REMOTE}' && md5sum *.yml 2>/dev/null")
        vm = {}
        for line in out.splitlines():
            parts = line.split()
            if len(parts) == 2:
                vm[parts[1]] = parts[0]
        drift = sorted(n for n, h in local.items() if vm.get(n) and vm[n] != h)
        missing = sorted(n for n in local if n not in vm)
        check("CONFIG-IN-SYNC", not drift,
              f"{len(drift)} config file(s) differ between local and VM: {', '.join(drift[:6])}")
        check("NO-MISSING-CONFIG", not missing,
              f"{len(missing)} local config file(s) absent on the VM: {', '.join(missing[:6])}")
        # Nothing in this phase may touch .env.
        env_mode = ssh(f"cd '{REMOTE}' && stat -c '%a' .env 2>/dev/null").strip()
        check("ENV-STILL-600", env_mode == "600", f".env mode is '{env_mode}', expected 600")
    else:
        print("\n  note: sync checks SKIPPED — rerun with --remote")

    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 1 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
