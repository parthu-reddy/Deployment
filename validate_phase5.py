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
          re.search(r"git\b[^\n]*\blog\b[^\n]*\.versions", body) is not None,
          "rollback does not resolve the previous tag from .versions history")
    check("ROLLBACK-RESPECTS-SCHEMA-BOUNDARY",
          re.search(r"destructive", body) is not None,
          "rollback does not consult the destructive-migration flag; it can start an old image "
          "against a schema whose columns it no longer finds")
    rec = DEPLOY_DIR / "reconcile.sh"
    rbody = re.sub(r"#[^\n]*", "", rec.read_text(encoding="utf-8")) if rec.is_file() else ""
    check("RECONCILE-EXISTS", rec.is_file(), "Deployment/reconcile.sh missing")
    check("RECONCILE-REPORTS-BEFORE-REMOVING",
          "--apply" in rbody,
          "reconcile.sh removes without an explicit --apply; 'undeclared' can mean 'leftover' or "
          "'someone forgot to declare it', and the script cannot tell which")
    check("RECONCILE-CHECKS-IMAGE-DRIFT",
          "Config.Image" in rbody,
          "reconcile.sh checks only whether containers exist, not whether they run the declared image")

    check("ROLLBACK-CHECKS-REGISTRY",
          "manifest inspect" in body,
          "rollback does not confirm the target image exists before stopping anything; a rollback "
          "to a missing tag turns a bad deploy into an outage")

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
        lines = LOG.read_text(encoding="utf-8").splitlines()
        header = [l for l in lines if l.startswith("|") and "destructive" in l]
        rows = [l for l in lines if re.match(r"^\|[^|]*\|[^|]*\|[^|]*\|[^|]*\|\s*(true|false)\s*\|", l)]
        check("DEPLOY-LOG-RECORDS-SCHEMA", bool(header),
              "DEPLOY_LOG.md has no `destructive` column; the rollback boundary rule cannot read it")
        check("DEPLOY-LOG-ROW-PER-SERVICE", bool(rows),
              "no per-service row carries a true/false destructive flag; --rollback greps a single "
              "service's row and cannot read one that lumps every service together")

    # 3. Declared == running. This is the check that found the two orphans.
    if remote:
        # Commented-out blocks must not count as declared -- reviews-service and
        # ondc-integration-service are parked as `#  name:` lines and would otherwise read as
        # declared-but-not-running forever.
        uncommented = "\n".join(l for l in COMPOSE.read_text(encoding="utf-8").splitlines()
                                if not l.lstrip().startswith("#"))
        declared = set(re.findall(r"^  ([a-z0-9_-]+):$", uncommented, re.M))
        # TWO sources, deliberately. `docker compose ps` lists only containers belonging to the
        # compose project, so a container started with a bare `docker run` is invisible to it --
        # this gate passed with a stray `docker run -d --name stray alpine` running on the VM.
        # Bare `docker ps -a` catches those; compose ps catches service-level drift.
        def ssh(cmd):
            return subprocess.run(
                ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=20",
                 "-i", SSH_KEY, VM, cmd],
                capture_output=True, text=True, timeout=180).stdout

        try:
            out = ssh(f'cd "{REMOTE_DIR}" && docker compose ps -a --format json')
            recs = [json.loads(l) for l in out.splitlines() if l.strip().startswith("{")]
            running = {r["Service"] for r in recs if r.get("Service")}
            project_names = {r["Name"] for r in recs if r.get("Name")}
            all_names = {n for n in ssh("docker ps -a --format '{{.Names}}'").split() if n}
        except Exception as e:
            check("RECONCILE-PROBE", False, f"{type(e).__name__}: {e}")
            running, project_names, all_names = set(), set(), set()

        if running:
            undeclared = sorted(running - declared)
            missing = sorted(declared - running)
            strays = sorted(all_names - project_names)
            check("NO-UNDECLARED-CONTAINERS", not undeclared and not strays,
                  f"{len(undeclared)} compose service(s) not declared: {', '.join(undeclared)}; "
                  f"{len(strays)} container(s) outside the compose project: {', '.join(strays)}")
            check("NO-MISSING-CONTAINERS", not missing,
                  f"{len(missing)} declared but not running: " + ", ".join(missing[:6]))
    else:
        print("\n  note: reconciliation SKIPPED -- rerun with --remote; a local run cannot see orphans")

    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 5 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
