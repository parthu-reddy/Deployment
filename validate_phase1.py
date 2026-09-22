#!/usr/bin/env python3
"""Phase 1 gate: every deployable image has identity and comes from a registry.

Checks the FILE and the RUNNING SYSTEM. A compose file that looks right while the VM runs a
locally-built image is the exact failure this phase exists to remove, so --remote is not optional
for sign-off.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ROOT / "Deployment/docker-compose.yml"
VERSIONS_DIR = ROOT / "Deployment/env_deployments/dev"
SSH_KEY = "/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"
VM = "ubuntu@140.245.234.137"
REMOTE_DIR = "Food Delivery.nosync/Deployment"

# Pulled images, not ours to tag. api-docs is plain nginx:alpine serving a mounted directory --
# it has no build: block despite looking like one of our services.
THIRD_PARTY = {"zookeeper", "kafka", "postgres", "redis", "clickhouse", "api-docs", "jaeger"}
EXPECTED_BUILT = 20      # 20 services from 19 modules; EurekaServer yields two

failures = []
notes = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def compose_services(text):
    """Service key -> its raw YAML block."""
    blocks, current, buf = {}, None, []
    for line in text.splitlines():
        m = re.match(r"^  ([a-z0-9_-]+):$", line)
        if m:
            if current:
                blocks[current] = "\n".join(buf)
            current, buf = m.group(1), []
        elif current is not None:
            if re.match(r"^[a-z]", line):      # left the services: mapping
                blocks[current] = "\n".join(buf)
                current, buf = None, []
            else:
                buf.append(line)
    if current:
        blocks[current] = "\n".join(buf)
    return blocks


def main():
    remote = "--remote" in sys.argv
    text = COMPOSE.read_text(encoding="utf-8")
    services = compose_services(text)
    ours = {k: v for k, v in services.items() if k not in THIRD_PARTY}
    notes.append(f"{len(services)} compose services, {len(ours)} ours")

    # 1. No service builds from source any more.
    building = [k for k, v in services.items() if re.search(r"^\s+build:", v, re.M)]
    check("NO-BUILD-BLOCKS", not building,
          f"{len(building)} service(s) still build on the host: {', '.join(sorted(building))}")

    # A commented-out build block re-forks the two paths the moment someone uncomments it.
    commented = [k for k, v in services.items() if re.search(r"^\s+#\s*build:", v, re.M)]
    check("NO-COMMENTED-BUILD", not commented,
          f"commented build: block in {', '.join(sorted(commented))} -- delete, do not comment")

    # 2. Every one of our services resolves to a registry image with a variable tag.
    unpinned = []
    for k, v in ours.items():
        m = re.search(r"^\s+image:\s*(\S+)", v, re.M)
        if not m:
            unpinned.append(f"{k} (no image:)")
        elif not re.search(r":\$\{[A-Z0-9_]+\}\s*$", m.group(1)):
            unpinned.append(f"{k} -> {m.group(1)}")
    check("IMAGE-PINNED", not unpinned,
          f"{len(unpinned)}: " + "; ".join(unpinned[:5]))

    # 3. `latest` is never used -- a moving tag restores the ambiguity this phase removes.
    latest = [k for k, v in ours.items() if re.search(r"image:.*:latest\b", v)]
    check("NO-LATEST-TAG", not latest, f"{', '.join(sorted(latest))}")

    # 4. env_deployments/dev covers every service and every tag looks like a git sha.
    if not VERSIONS_DIR.is_dir():
        check("VERSIONS-DIR", False, f"{VERSIONS_DIR} does not exist")
        tags = {}
    else:
        tags = {}
        for f in VERSIONS_DIR.glob("*.env"):
            for line in f.read_text(encoding="utf-8").splitlines():
                m = re.match(r"^([A-Z0-9_]+)_TAG=(\S+)$", line)
                if m:
                    tags[m.group(1)] = m.group(2)
        check("VERSIONS-DIR", True)
        expected = {k.upper().replace("-", "_") for k in ours}
        missing = sorted(expected - set(tags))
        check("VERSIONS-COMPLETE", not missing,
              f"{len(missing)} service(s) have no tag recorded: {', '.join(missing[:5])}")
        bad = sorted(k for k, t in tags.items() if not re.fullmatch(r"[0-9a-f]{7,40}(-dirty)?(-[0-9a-f]{7,40})?", t))
        check("VERSIONS-SHA-SHAPED", not bad,
              f"not a valid tag: {', '.join(f'{k}={tags[k]}' for k in bad[:5])}")

    # 5. What is actually running -- the check that catches a correct-looking file.
    if remote:
        try:
            out = subprocess.run(
                ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=20",
                 "-i", SSH_KEY, VM,
                 f'cd "{REMOTE_DIR}" && docker compose ps --format json'],
                capture_output=True, text=True, timeout=180).stdout
            running = []
            for line in out.splitlines():
                line = line.strip()
                if line.startswith("{"):
                    running.append(json.loads(line))
        except Exception as e:  # a broken probe must not look like a pass
            check("REMOTE-PROBE", False, f"{type(e).__name__}: {e}")
            running = []

        if running:
            local_built = [
                r.get("Service") for r in running
                if r.get("Service") not in THIRD_PARTY
                and "ocir.io/" not in (r.get("Image") or "")
            ]
            check("VM-RUNS-REGISTRY-IMAGES", not local_built,
                  f"{len(local_built)} container(s) run a non-registry image: "
                  f"{', '.join(sorted(x for x in local_built if x))}")

            mismatch = []
            for r in running:
                svc, image = r.get("Service"), r.get("Image") or ""
                if svc in THIRD_PARTY or not svc:
                    continue
                want = tags.get(svc.upper().replace("-", "_"))
                if want and not image.endswith(f":{want}"):
                    mismatch.append(f"{svc} runs {image.rsplit(':', 1)[-1]}, .versions says {want}")
            check("VM-MATCHES-VERSIONS", not mismatch,
                  f"{len(mismatch)}: " + "; ".join(mismatch[:5]))
    else:
        notes.append("remote checks SKIPPED -- rerun with --remote before signing off")

    print()
    for n in notes:
        print(f"  note: {n}")
    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 1 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
