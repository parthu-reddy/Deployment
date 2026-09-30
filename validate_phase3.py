#!/usr/bin/env python3
"""Phase 3 gate: the vault owns secrets, and no deploy path can overwrite them.

The interesting check is SENTINEL: it proves the guarantee by attempting the failure. The static
checks can all pass while a deploy still clobbers .env, because the thing that clobbered it last
time was a flag in a script nobody re-read.
"""
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
DEPLOY_DIR = ROOT / "Deployment"
COMPOSE = DEPLOY_DIR / "docker-compose.yml"
E2E_COMPOSE = DEPLOY_DIR / "docker-compose.e2e.yml"
DEFAULTS = DEPLOY_DIR / ".env.defaults"
SSH_KEY = "/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key"
VM = "ubuntu@140.245.234.137"

# Values that must never appear in a tracked file. Names only -- never the values themselves.
SECRET_KEYS = [
    "POSTGRES_PASS", "CONFIG_PASSWORD", "EUREKA_PASSWORD", "R2_SECRET_ACCESS_KEY",
    "IDENTITY_HMAC_SECRET", "AUCTION_TOKEN_SECRET", "OLA_MAPS_API_KEY", "E2E_RUNNER_SECRET",
]
PLACEHOLDER = re.compile(r"(?i)^(|changeme|placeholder|<[^>]*>|x{3,}|\$\{.*\})$")

failures = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f"\n         └─ {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def env_values(path):
    """Read non-comment KEY=value settings without importing a deployment environment."""
    values = {}
    if not path.is_file():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        if not raw_line or raw_line.startswith("#") or "=" not in raw_line:
            continue
        key, value = raw_line.split("=", 1)
        values[key] = value
    return values


def is_one_exact_https_origin(value):
    """CORS origin syntax: one HTTPS origin, no path, list, or wildcard."""
    if not value or "," in value or "*" in value:
        return False
    parsed = urlparse(value)
    return (
        parsed.scheme == "https"
        and bool(parsed.netloc)
        and not parsed.path
        and not parsed.params
        and not parsed.query
        and not parsed.fragment
    )


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
        compose_text = COMPOSE.read_text(encoding="utf-8")
        compose_for_vars = re.sub(r"#[^\n]*", "", compose_text)
        declared = set(re.findall(r"^([A-Z0-9_]+)=", example.read_text(encoding="utf-8"), re.M))
        defaults = env_values(DEFAULTS)
        example_values = env_values(example)
        used = set()
        for m in re.finditer(r"\$\{([A-Z0-9_]+)(:-[^}]*)?\}", compose_for_vars):
            # <SVC>_TAG is injected by deploy.sh from Deployment/.versions, which is deployment
            # state rather than configuration. Declaring it in .env.example would invite someone
            # to hand-edit the tag a container runs.
            if not m.group(2) and not m.group(1).endswith("_TAG"):
                used.add(m.group(1))
        missing = sorted(used - declared)
        check("COMPOSE-VARS-DECLARED", not missing,
              f"{len(missing)} var(s) have no default and no .env.example entry: "
              + ", ".join(missing[:6]))

        # A public quick-tunnel domain is not an identity boundary: anyone can create a hostname
        # beneath it. The Dev browser policy therefore permits exactly one selected origin and
        # removes the pattern hook from both the compose environment and Gateway configuration.
        allowed_origin = defaults.get("ALLOWED_ORIGINS", "")
        gateway_file = DEPLOY_DIR / "api-gateway.yml"
        gateway_config = gateway_file.read_text(encoding="utf-8") if gateway_file.is_file() else ""
        check("DEV-CORS-ONE-EXACT-HTTPS-ORIGIN", is_one_exact_https_origin(allowed_origin),
              "Deployment/.env.defaults must contain one canonical HTTPS origin without a path, list, or wildcard")
        check("DEV-CORS-EXAMPLE-MATCHES-DEFAULTS",
              example_values.get("ALLOWED_ORIGINS") == allowed_origin,
              ".env.example must name the same exact Dev browser origin as .env.defaults")
        check("DEV-CORS-PATTERN-PATH-REMOVED",
              "ALLOWED_ORIGIN_PATTERNS" not in compose_text
              and "allowedOriginPatterns" not in gateway_config
              and "ALLOWED_ORIGIN_PATTERNS" not in defaults,
              "the gateway must not retain an arbitrary-origin CORS pattern path")

        reviews = re.search(r"^  reviews-service:\n(?P<body>(?:^(?!  [a-z0-9_-]+:).*$\n?)*)",
                            compose_text, re.M)
        check("REVIEWS-IDENTITY-SECRET-WIRED",
              reviews is not None and
              "IDENTITY_HMAC_SECRET=${IDENTITY_HMAC_SECRET}" in reviews.group("body"),
              "reviews-service does not receive the gateway identity HMAC secret")

        # The browser-test runner credential has a narrower boundary than the mesh HMAC. A base
        # deployment must never inject it, even if a stale E2E-specific host file still exists.
        e2e_text = E2E_COMPOSE.read_text(encoding="utf-8") if E2E_COMPOSE.is_file() else ""
        e2e_services = set(re.findall(r"^  ([a-z0-9_-]+):\s*$", e2e_text, re.M))
        e2e_env_file_references = len(re.findall(r"^\s*-\s+\.env\.e2e\s*$", e2e_text, re.M))
        e2e_required = {"api-gateway", "identity-service"}
        check("E2E-RUNNER-SECRET-ABSENT-FROM-BASE-COMPOSE",
              "E2E_RUNNER_SECRET" not in compose_text,
              "the base compose file would expose the E2E runner credential to ordinary containers")
        check("E2E-OVERLAY-IS-SCOPED",
              e2e_services == e2e_required
              and e2e_env_file_references == 2
              and e2e_text.count("SPRING_PROFILES_ACTIVE: dev,e2e") == 2,
              "docker-compose.e2e.yml must target only gateway and IdentityService with dev,e2e")

    clean_deploy = DEPLOY_DIR / "OracleDeployment/03_clean_deploy.sh"
    clean_body = clean_deploy.read_text(encoding="utf-8") if clean_deploy.is_file() else ""
    check("FULL-DEPLOY-SYNCS-COMPOSE",
          'deploy.sh" --sync-compose' in clean_body,
          "the full deployment can start containers from a stale remote docker-compose.yml")

    # 3. No tracked file holds a real value for a secret key.
    leaked = []
    # Prune generated trees before descending. Path.glob("**/*") still walks every file inside
    # a node_modules or target directory before the later filter can reject it, which made this
    # pre-deploy gate slow enough to look hung in a populated workspace.
    ignored_dirs = {"node_modules", "target", ".git"}
    for directory, names, filenames in os.walk(ROOT):
        names[:] = [name for name in names if name not in ignored_dirs]
        for filename in sorted(filenames):
            f = Path(directory, filename)
            if f.suffix in {".jar", ".png", ".jpg", ".gz"} or ".env.local" in f.as_posix():
                continue
            if f.name == ".env":                    # untracked by policy; checked separately
                continue
            try:
                text = f.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                continue
            for key in SECRET_KEYS:
                for m in re.finditer(rf"^{key}=(.*)$", text, re.M):
                    value = m.group(1).strip().strip("'\"")
                    if not PLACEHOLDER.match(value):
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
