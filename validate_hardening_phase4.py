#!/usr/bin/env python3
"""Phase 4 gate: retention exists and cannot reach a tag the deployment history names.

The invariant is one sentence: no tag named anywhere in .versions git history may be deletable.
Everything else is housekeeping.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEPLOY = ROOT / "Deployment"
VERSIONS = DEPLOY / ".versions"
REGISTRY = "hyd.ocir.io/axekmbadoczl"

failures = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def git(*a):
    return subprocess.run(["git", "-C", str(DEPLOY), *a], capture_output=True, text=True).stdout


def protected_tags():
    """Every <service>:<tag> the deployment history has ever named."""
    tags = set()
    for sha in git("log", "--format=%H", "--", ".versions").split():
        for line in git("show", f"{sha}:.versions").splitlines():
            if "_TAG=" in line:
                k, v = line.split("=", 1)
                svc = k[:-4].lower().replace("_", "-")
                tags.add(f"{svc}:{v.strip()}")
    for line in VERSIONS.read_text(encoding="utf-8").splitlines():
        if "_TAG=" in line:
            k, v = line.split("=", 1)
            tags.add(f"{k[:-4].lower().replace('_','-')}:{v.strip()}")
    return tags


def main():
    prot = protected_tags()
    check("PROTECTED-SET-NONEMPTY", len(prot) >= 20,
          f"only {len(prot)} protected tags derived; expected at least the 20 currently deployed")

    # The two services that actually have rollback history must be represented twice.
    byservice = {}
    for t in prot:
        s, _, v = t.partition(":")
        byservice.setdefault(s, set()).add(v)
    multi = {s: v for s, v in byservice.items() if len(v) > 1}
    check("ROLLBACK-TARGETS-PROTECTED", len(multi) >= 1,
          "no service has two protected tags; if that is true, no rollback target exists to protect")

    # A retention mechanism must exist in some form.
    scripts = list(DEPLOY.glob("*retention*")) + list(DEPLOY.glob("*prune*"))
    policy_doc = (Path(__file__).resolve().parents[1]
                  / "RandomDocuments/DeploymentHardening_2026-08-31/Phase4_RegistryRetention/plan.md")
    doc = policy_doc.read_text(encoding="utf-8") if policy_doc.is_file() else ""
    has_numbers = re.search(r"\b(keep[- ]count|retain)\b.*\d", doc, re.I) is not None
    check("MECHANISM-EXISTS", bool(scripts) or "lifecycle policy applied" in doc.lower(),
          "no retention script and no record of an applied OCI lifecycle policy")
    check("KEEP-COUNT-JUSTIFIED", has_numbers,
          "plan.md records no measured keep-count; the number must follow from real tag counts "
          "and storage figures, not from a default")

    # If a script exists, it must consult the protected set and default to dry-run.
    for s in scripts:
        body = re.sub(r"#[^\n]*", "", s.read_text(encoding="utf-8", errors="ignore"))
        check(f"{s.name}-CONSULTS-VERSIONS", ".versions" in body,
              f"{s.name} does not read .versions, so it cannot know which tags are protected")
        check(f"{s.name}-DRY-RUN-DEFAULT",
              re.search(r"dry[-_]?run", body, re.I) is not None,
              f"{s.name} has no dry-run mode")
        check(f"{s.name}-NOT-ON-VM",
              not re.search(r"ssh .*ubuntu@", body),
              f"{s.name} appears to run against the VM over ssh; the VM credential is pull-only "
              "by design and must not be upgraded for housekeeping")

    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 4 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
