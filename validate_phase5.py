#!/usr/bin/env python3
"""Phase 5 gate: rollback is possible and bounded, and running state matches declared state.

The reconciliation check queries the VM. A local-only run cannot tell you whether orphans exist,
which is the entire point of the check.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEPLOY_DIR = ROOT / "Deployment"
COMPOSE = DEPLOY_DIR / "docker-compose.yml"
VERSIONS = DEPLOY_DIR / ".versions"
LOG = DEPLOY_DIR / "DEPLOY_LOG.md"
SSH_KEY = "/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"
VM = "ubuntu@140.245.234.137"
REMOTE_DIR = "Food Delivery.nosync/Deployment"

failures = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def git(*args, cwd):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True).stdout


def main():
    remote = "--remote" in sys.argv
    body = ""
    p = DEPLOY_DIR / "deploy.sh"
    if p.is_file():
        body = re.sub(r"#[^\n]*", "", p.read_text(encoding="utf-8"))

    # 1. Rollback exists and is bounded.
    check("ROLLBACK-EXISTS", "--rollback" in body, "deploy.sh has no --rollback")
    check("ROLLBACK-READS-HISTORY",
          re.search(r"git\s+log.*\.versions", body) is not None,
          "rollback does not resolve the previous tag from .versions history")
    check("ROLLBACK-RESPECTS-SCHEMA-BOUNDARY",
          re.search(r"destructive", body) is not None,
          "rollback does not consult the destructive-migration flag; it can start an old image "
          "against a schema whose columns it no longer finds")
    check("DEPLOY-REMOVES-ORPHANS",
          "--remove-orphans" in body,
          "deploy.sh can leave undeclared containers running")

    # 2. History exists and is actually usable for rollback.
    check("VERSIONS-COMMITTED", VERSIONS.is_file(), f"{VERSIONS} missing")
    if VERSIONS.is_file():
        dirty = git("status", "--porcelain", "--", ".versions", cwd=DEPLOY_DIR).strip()
        check("VERSIONS-NOT-DIRTY", not dirty,
              ".versions has uncommitted changes -- rollback history has a hole")
        revs = [l for l in git("log", "--format=%H", "--", ".versions", cwd=DEPLOY_DIR).splitlines() if l]
        check("VERSIONS-HAS-HISTORY", len(revs) >= 2,
              f"only {len(revs)} revision(s); rollback needs a previous tag to resolve")

    check("DEPLOY-LOG-EXISTS", LOG.is_file(), f"{LOG} missing")
    if LOG.is_file():
        entries = [l for l in LOG.read_text(encoding="utf-8").splitlines()
                   if re.search(r"\bdestructive=(true|false)\b", l)]
        check("DEPLOY-LOG-RECORDS-SCHEMA", bool(entries),
              "no entry records destructive=; the rollback boundary rule has nothing to read")

    # 3. Declared == running. This is the check that found the two orphans.
    if remote:
        declared = set(re.findall(r"^  ([a-z0-9_-]+):$", COMPOSE.read_text(encoding="utf-8"), re.M))
        try:
            out = subprocess.run(
                ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=20",
                 "-i", SSH_KEY, VM, f'cd "{REMOTE_DIR}" && docker compose ps -a --format json'],
                capture_output=True, text=True, timeout=180).stdout
            running = {json.loads(l)["Service"] for l in out.splitlines()
                       if l.strip().startswith("{") and json.loads(l).get("Service")}
        except Exception as e:
            check("RECONCILE-PROBE", False, f"{type(e).__name__}: {e}")
            running = set()

        if running:
            undeclared = sorted(running - declared)
            missing = sorted(declared - running)
            check("NO-UNDECLARED-CONTAINERS", not undeclared,
                  f"{len(undeclared)} running but not in compose: " + ", ".join(undeclared))
            check("NO-MISSING-CONTAINERS", not missing,
                  f"{len(missing)} declared but not running: " + ", ".join(missing[:6]))
    else:
        print("\n  note: reconciliation SKIPPED -- rerun with --remote; a local run cannot see orphans")

    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 5 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
