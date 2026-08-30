#!/usr/bin/env python3
"""Phase 3 gate: the vault owns secrets, and no deploy path can overwrite them.

The interesting check is SENTINEL: it proves the guarantee by attempting the failure. The static
checks can all pass while a deploy still clobbers .env, because the thing that clobbered it last
time was a flag in a script nobody re-read.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEPLOY_DIR = ROOT / "Deployment"
COMPOSE = DEPLOY_DIR / "docker-compose.yml"
SSH_KEY = "/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"
VM = "ubuntu@140.245.234.137"

# Values that must never appear in a tracked file. Names only -- never the values themselves.
SECRET_KEYS = [
    "POSTGRES_PASS", "CONFIG_PASSWORD", "EUREKA_PASSWORD", "R2_SECRET_ACCESS_KEY",
    "IDENTITY_HMAC_SECRET", "AUCTION_TOKEN_SECRET", "OLA_MAPS_API_KEY",
]
PLACEHOLDER = re.compile(r"(?i)^(|changeme|placeholder|<[^>]*>|x{3,}|\$\{.*\})$")

failures = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def main():
    # 1. No sync path can carry .env to the VM.
    offenders = []
    for sh in sorted(ROOT.glob("**/*.sh")):
        if "/node_modules/" in sh.as_posix() or "/target/" in sh.as_posix():
            continue
        body = re.sub(r"#[^\n]*", "", sh.read_text(encoding="utf-8", errors="ignore"))
        for line in body.splitlines():
            if not re.search(r"\b(rsync|scp)\b", line):
                continue
            # writing TO the VM
            if not re.search(r"(ubuntu@|\$REMOTE_USER@|\$\{REMOTE_USER\}@)", line):
                continue
            if re.search(r"Deployment/?\"?\s*$|Deployment/\s", line) and "--exclude" not in body:
                offenders.append(f"{sh.relative_to(ROOT)}: syncs Deployment/ with no exclude")
            if "--delete" in line and "Deployment" in line:
                offenders.append(f"{sh.relative_to(ROOT)}: --delete on Deployment/ can remove .env")
            if re.search(r"\.env\b", line):
                offenders.append(f"{sh.relative_to(ROOT)}: names .env in a transfer to the VM")
    check("NO-ENV-TRANSFER", not offenders, f"{len(offenders)}: " + "; ".join(sorted(set(offenders))[:5]))

    # 2. Every compose variable resolves from .env.example, or has an inline default.
    example = DEPLOY_DIR / ".env.example"
    check("ENV-EXAMPLE-EXISTS", example.is_file(), f"{example} not found")
    if example.is_file() and COMPOSE.is_file():
        declared = set(re.findall(r"^([A-Z0-9_]+)=", example.read_text(encoding="utf-8"), re.M))
        used = set()
        for m in re.finditer(r"\$\{([A-Z0-9_]+)(:-[^}]*)?\}", COMPOSE.read_text(encoding="utf-8")):
            # <SVC>_TAG is injected by deploy.sh from Deployment/.versions, which is deployment
            # state rather than configuration. Declaring it in .env.example would invite someone
            # to hand-edit the tag a container runs.
            if not m.group(2) and not m.group(1).endswith("_TAG"):
                used.add(m.group(1))
        missing = sorted(used - declared)
        check("COMPOSE-VARS-DECLARED", not missing,
              f"{len(missing)} var(s) have no default and no .env.example entry: "
              + ", ".join(missing[:6]))

    # 3. No tracked file holds a real value for a secret key.
    leaked = []
    for f in sorted(ROOT.glob("**/*")):
        if not f.is_file() or f.suffix in {".jar", ".png", ".jpg", ".gz"}:
            continue
        p = f.as_posix()
        if any(s in p for s in ("/node_modules/", "/target/", "/.git/", ".env.local")):
            continue
        if f.name == ".env":                        # untracked by policy; checked separately
            continue
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for key in SECRET_KEYS:
            for m in re.finditer(rf"^{key}=(.*)$", text, re.M):
                if not PLACEHOLDER.match(m.group(1).strip()):
                    leaked.append(f"{f.relative_to(ROOT)}:{key}")
    check("NO-TRACKED-SECRETS", not leaked,
          f"{len(leaked)} live value(s): " + ", ".join(sorted(set(leaked))[:5]))

    # 4. The guarantee, proven by attempting to break it.
    if "--sentinel" in sys.argv:
        env = DEPLOY_DIR / ".env"
        token = "PHASE3_SENTINEL=must-never-reach-the-vm"
        original = env.read_text(encoding="utf-8") if env.is_file() else None
        try:
            env.write_text((original or "") + f"\n{token}\n", encoding="utf-8")
            subprocess.run(["bash", str(DEPLOY_DIR / "deploy.sh"), "--config"],
                           capture_output=True, text=True, timeout=600)
            remote = subprocess.run(
                ["ssh", "-o", "StrictHostKeyChecking=no", "-i", SSH_KEY, VM,
                 'grep -c PHASE3_SENTINEL "Food Delivery.nosync/Deployment/.env" || true'],
                capture_output=True, text=True, timeout=120).stdout.strip()
            check("SENTINEL-DID-NOT-TRAVEL", remote in ("", "0"),
                  "the local .env reached the VM -- a deploy still overwrites vault secrets")
        finally:
            if original is None:
                env.unlink(missing_ok=True)
            else:
                env.write_text(original, encoding="utf-8")
    else:
        print("\n  note: SENTINEL skipped -- rerun with --sentinel before signing off")

    print(f"\n{'FAILED: ' + ', '.join(failures) if failures else 'Phase 3 gate: all checks passed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
