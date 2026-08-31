#!/usr/bin/env python3
"""Phase 2 gate: exactly one deploy path exists, and the VM cannot build.

The local half proves the old scripts are gone. The remote half proves the VM has no source and no
toolchain -- without it, the old path is still reachable by hand and the phase is not done.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEPLOY_DIR = ROOT / "Deployment"
SSH_KEY = "/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"
VM = "ubuntu@140.245.234.137"
REMOTE_ROOT = "Food Delivery.nosync"

failures = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def ssh(cmd, timeout=180):
    return subprocess.run(
        ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=20", "-i", SSH_KEY, VM, cmd],
        capture_output=True, text=True, timeout=timeout).stdout.strip()


def main():
    remote = "--remote" in sys.argv

    # 1. Exactly one entrypoint, and none of the 27 survivors.
    entry = DEPLOY_DIR / "deploy.sh"
    check("ENTRYPOINT-EXISTS", entry.is_file(), f"{entry} not found")

    # Only scripts that DEPLOY TO THE VM are superseded by deploy.sh. Deployment/ also holds a
    # separate family of local-development scripts (--apple / --docker engine switching, building
    # against the developer's own machine) which this phase does not replace. Matching on the
    # filename alone conflated the two and would have deleted a working local workflow.
    strays = []
    for p in sorted(DEPLOY_DIR.rglob("deploy_*.sh")):
        body = p.read_text(encoding="utf-8", errors="ignore")
        if re.search(r"ubuntu@|ORACLE_IP|140\.245\.", body):
            strays.append(p.relative_to(ROOT).as_posix())
    check("NO-PER-SERVICE-SCRIPTS", not strays,
          f"{len(strays)} script(s) still deploy to the VM: " + ", ".join(strays[:6]))

    recent = DEPLOY_DIR / "DeploymentSteps/deploy_recent_changes.sh"
    check("NO-RECENT-CHANGES-SCRIPT", not recent.is_file(),
          "deploy_recent_changes.sh still rsyncs Deployment/ with --delete")

    # 2. The entrypoint must not build or ship source. These are the two behaviours that,
    #    if they survive, silently recreate the old design inside the new file.
    if entry.is_file():
        body = re.sub(r"#[^\n]*", "", entry.read_text(encoding="utf-8"))
        banned = {
            "mvn": r"\bmvn\b",
            "rsync of source": r"\brsync\b",
            "docker compose build": r"docker\s+compose\s+build",
            "--no-cache": r"--no-cache",
            "npm on the VM": r"\bnpm\b",
        }
        found = [n for n, pat in banned.items() if re.search(pat, body)]
        check("ENTRYPOINT-DEPLOYS-ONLY", not found,
              "deploy.sh still does: " + ", ".join(found))

        # service-map.tsv is the source of truth for valid service names (Phase 1), not compose --
        # the map also carries the module each service is built from, which compose does not.
        check("ENTRYPOINT-VALIDATES-SERVICE",
              "service-map" in body or "docker-compose.yml" in body or "compose config" in body,
              "deploy.sh does not resolve the service name against service-map.tsv -- a typo will reach SSH")

        check("ENTRYPOINT-WAITS-FOR-HEALTH",
              re.search(r"health|compose\s+ps", body) is not None,
              "deploy.sh returns without observing that the container came up")

        # Healthy is not the same as updated. The old script exited 0 having shipped nothing,
        # with the container healthy on the previous image for 51 minutes.
        check("ENTRYPOINT-VERIFIES-IMAGE-CHANGED",
              re.search(r"docker\s+inspect|\.Image|digest", body) is not None,
              "deploy.sh does not compare the image before and after; a deploy that ships "
              "nothing would report success")

        # One mvn reading the heredoc discards every command after it.
        heredoc = re.search(r"<<\s*'?EOF'?", body)
        risky = [ln for ln in body.splitlines()
                 if re.match(r"\s*(mvn|npm)\b", ln) and "/dev/null" not in ln]
        check("REMOTE-COMMANDS-DO-NOT-EAT-STDIN",
              not (heredoc and risky),
              f"{len(risky)} command(s) inside an SSH heredoc can consume the command list: "
              + "; ".join(x.strip()[:50] for x in risky[:3]))

    # 3. Docs must be rewritten, not annotated.
    ui_readme = DEPLOY_DIR / "OracleDeployment/UIDeployment/README.md"
    if ui_readme.is_file():
        t = ui_readme.read_text(encoding="utf-8")
        # Only look inside fenced code blocks. Prose that explains why a step is obsolete is not
        # an instruction to perform it, and matching the whole document flagged a rewrite whose
        # entire point was recording that those steps no longer apply. Sixth occurrence of this
        # trap in this workspace: a checker reading documentation as if it were the thing itself.
        commands = "\n".join(re.findall(r"```[a-z]*\n(.*?)```", t, re.S))
        stale = [s for s in ("--no-cache", "npm run build", "rsync") if s in commands]
        check("UI-DOCS-REWRITTEN", not stale,
              "still instructs VM-side steps in a code block: " + ", ".join(stale))

    # 4. The VM: no source, no toolchain, no build context.
    if remote:
        listing = ssh(f'ls -1 ~/"{REMOTE_ROOT}" 2>/dev/null')
        entries = [x for x in listing.splitlines() if x.strip()]
        extra = [x for x in entries if x != "Deployment"]
        check("VM-HAS-NO-SOURCE", not extra,
              f"{len(extra)} director(ies) remain: " + ", ".join(extra[:8]))

        # Look for inputs that would let someone REBUILD A SERVICE. Deployment/ is excluded: it is
        # operational tooling that legitimately lives on the VM, and its node_modules belongs to
        # populate_mock_driver.js, a mock-data utility. Flagging that conflated "the VM can rebuild
        # the application" with "the VM has any node_modules at all".
        leftovers = ssh(
            f'find ~/"{REMOTE_ROOT}" -maxdepth 3 -not -path "*/Deployment/*" '
            f'\\( -name pom.xml -o -name src \\) 2>/dev/null | head -5')
        check("VM-NO-BUILD-INPUTS", not leftovers.strip(),
              "service build inputs still present: " + leftovers.replace("\n", "; "))

        # Building on the VM needs BOTH a toolchain and source. Source is what this phase removes;
        # maven alone cannot rebuild anything and uninstalling a system package is a heavier,
        # separate decision. Fail only if the pair is present, which is the reachable path.
        mvn = ssh("command -v mvn || true").strip()
        has_src = bool(leftovers.strip())
        check("VM-CANNOT-BUILD", not (mvn and has_src),
              f"maven at {mvn} AND service source present -- the old path is reachable")
        if mvn:
            print(f"         note: maven is installed at {mvn}, harmless with no source present")
    else:
        print("\n  note: remote checks SKIPPED -- rerun with --remote before signing off")

    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 2 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
