import sys
from pathlib import Path
sys.path.append(str(Path.cwd()))
from retention import get_docker_credentials, get_bearer_token
import urllib.request
import json

repo = "bidding-engine"
user, pw = get_docker_credentials()
token = get_bearer_token(repo, user, pw)
url = f"https://hyd.ocir.io/v2/axekmbadoczl/food-delivery/{repo}/manifests/da74354-149b4eb"
req = urllib.request.Request(url, method="GET")
req.add_header('Authorization', f'Bearer {token}')
accept = 'application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
req.add_header('Accept', accept)
try:
    with urllib.request.urlopen(req) as resp:
        print(resp.read().decode())
except urllib.error.HTTPError as e:
    print(f"Error: {e.code}")
