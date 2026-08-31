#!/usr/bin/env python3
"""
OCIR Tag Retention Script (Phase 4)

This script manages the OCIR registry size by deleting old tags.
It keeps:
- The currently deployed tag (read from Deployment/.versions).
- The 4 most recent tags based on git commit time.
All other tags and their image digests are deleted, UNLESS they share an image
digest with one of the protected tags.
"""
import urllib.request
import urllib.parse
import json
import base64
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRY_RUN = "--dry-run" in sys.argv
DEPLOYMENT = ROOT / "Deployment"
VERSIONS_FILE = DEPLOYMENT / ".versions"
MAP_FILE = DEPLOYMENT / "service-map.tsv"
REGISTRY_DOMAIN = "hyd.ocir.io"
REGISTRY_REPO_PREFIX = "axekmbadoczl/food-delivery"

def run_cmd(cmd, cwd=ROOT):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return r.stdout.strip(), r.returncode

def get_docker_credentials():
    print(f"Fetching docker credentials for {REGISTRY_DOMAIN}...")
    r = subprocess.run(["docker-credential-desktop", "get"], input=REGISTRY_DOMAIN, text=True, capture_output=True)
    if r.returncode != 0:
        print(f"Failed to get credentials: {r.stderr}", file=sys.stderr)
        sys.exit(1)
    data = json.loads(r.stdout)
    return data["Username"], data["Secret"]

def get_bearer_token(repo, username, password, scope="pull,push"):
    # OCIR rejects a scope containing 'delete' with HTTP 400, but the token obtained with
    # 'pull,push' is still accepted for DELETE requests (tested 2026-08-31, status 202).
    # OCIR's Docker V2 implementation does not enforce action-level scopes on the token.
    auth_str = f"{username}:{password}"
    b64_auth = base64.b64encode(auth_str.encode()).decode()
    url = f"https://{REGISTRY_DOMAIN}/v2/{REGISTRY_REPO_PREFIX}/{repo}/tags/list"
    req = urllib.request.Request(url, method='HEAD')
    try:
        urllib.request.urlopen(req)
        return None
    except urllib.error.HTTPError as e:
        if e.code == 401:
            auth_header = e.headers.get('Www-Authenticate')
            parts = {}
            for p in auth_header.replace('Bearer ', '').split(','):
                if '=' in p:
                    k, v = p.split('=', 1)
                    parts[k] = v.strip('"')
            scope_str = urllib.parse.quote(f"repository:{REGISTRY_REPO_PREFIX}/{repo}:{scope}")
            token_url = f"{parts['realm']}?service={parts.get('service', REGISTRY_DOMAIN)}&scope={scope_str}"
            req2 = urllib.request.Request(token_url)
            req2.add_header('Authorization', f'Basic {b64_auth}')
            try:
                with urllib.request.urlopen(req2) as resp:
                    return json.loads(resp.read())['token']
            except urllib.error.HTTPError as err:
                print(f"Error fetching token for {repo}: {err.code} {err.read().decode()}", file=sys.stderr)
                return None
        return None

def fetch_tags(repo, token):
    url = f"https://{REGISTRY_DOMAIN}/v2/{REGISTRY_REPO_PREFIX}/{repo}/tags/list"
    req = urllib.request.Request(url)
    req.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
            return data.get("tags") or []
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return []
        print(f"Error fetching tags for {repo}: {e.code}", file=sys.stderr)
        return []

def get_digest(repo, tag, token):
    url = f"https://{REGISTRY_DOMAIN}/v2/{REGISTRY_REPO_PREFIX}/{repo}/manifests/{tag}"
    req = urllib.request.Request(url, method='HEAD')
    req.add_header('Authorization', f'Bearer {token}')
    # Must accept index types to get the digest for multi-arch/buildx pushes
    accept = 'application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
    req.add_header('Accept', accept)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.headers.get('Docker-Content-Digest')
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"Error fetching digest for {repo}:{tag} - {e.code}", file=sys.stderr)
        return None

def delete_digest(repo, digest, token):
    url = f"https://{REGISTRY_DOMAIN}/v2/{REGISTRY_REPO_PREFIX}/{repo}/manifests/{digest}"
    req = urllib.request.Request(url, method='DELETE')
    req.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status in (200, 202)
    except urllib.error.HTTPError as e:
        print(f"Failed to delete {repo}@{digest}: {e.code}", file=sys.stderr)
        return False

def get_tag_timestamp(module_dir, tag):
    sha = tag.replace("-dirty", "")
    out, rc = run_cmd(["git", "log", "-1", "--format=%ct", sha], cwd=ROOT / module_dir)
    if rc == 0 and out.isdigit():
        return int(out)
    return 0

def process_repo(repo, module_dir, deployed_tag, username, password):
    print(f"Processing {repo}...")
    token = get_bearer_token(repo, username, password)
    if not token:
        return repo, 0, 0
    
    tags = fetch_tags(repo, token)
    if not tags:
        print(f"  No tags found for {repo}")
        return repo, 0, 0

    print(f"  Found {len(tags)} tags. Fetching digests and timestamps...")
    
    tag_info = []
    # Fetch digests sequentially, usually fast enough per repo.
    for tag in tags:
        digest = get_digest(repo, tag, token)
        if digest:
            ts = get_tag_timestamp(module_dir, tag)
            tag_info.append({"tag": tag, "digest": digest, "ts": ts})

    tag_info.sort(key=lambda x: x["ts"], reverse=True)

    protected_tags = set()
    if deployed_tag in tags:
        protected_tags.add(deployed_tag)
    
    # Keep top 4 most recent
    for info in tag_info[:4]:
        protected_tags.add(info["tag"])

    protected_digests = {info["digest"] for info in tag_info if info["tag"] in protected_tags}
    
    to_delete_digests = {info["digest"] for info in tag_info if info["digest"] not in protected_digests}
    
    kept_count = len(tag_info) - len([info for info in tag_info if info["digest"] in to_delete_digests])
    deleted_count = len(to_delete_digests)
    
    print(f"  {repo}: Keeping {kept_count} tags (protected), deleting {deleted_count} digests.")
    for digest in to_delete_digests:
        if DRY_RUN:
            print(f"  [DRY-RUN] would delete {digest[:20]}... in {repo}")
        else:
            success = delete_digest(repo, digest, token)
            if not success:
                print(f"  Warning: failed to delete {digest} in {repo}")
            
    return repo, kept_count, deleted_count

def main():
    if not MAP_FILE.exists() or not VERSIONS_FILE.exists():
        print("Required files missing.", file=sys.stderr)
        return 1

    services = {}
    with open(MAP_FILE) as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.strip().split('\t')
            if len(parts) >= 2:
                services[parts[1]] = parts[0] # compose_service -> module_dir

    deployed_tags = {}
    with open(VERSIONS_FILE) as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                k_norm = k.replace("_TAG", "").lower().replace("_", "-")
                deployed_tags[k_norm] = v
                
    username, password = get_docker_credentials()
    
    total_kept = 0
    total_deleted = 0
    
    for svc, module in services.items():
        deployed_tag = deployed_tags.get(svc, "")
        repo, kept, deleted = process_repo(svc, module, deployed_tag, username, password)
        total_kept += kept
        total_deleted += deleted

    action = "would delete" if DRY_RUN else "deleted"
    print(f"\nRetention complete. Kept {total_kept} tags, {action} {total_deleted} digests.")
    if DRY_RUN:
        print("(dry-run mode: nothing was actually deleted)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
