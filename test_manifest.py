import sys
from pathlib import Path
sys.path.append(str(Path.cwd()))
from retention import get_docker_credentials, get_bearer_token, fetch_tags
import urllib.request
import json

repo = "api-gateway"
user, pw = get_docker_credentials()
token = get_bearer_token(repo, user, pw)
url = f"https://hyd.ocir.io/v2/axekmbadoczl/food-delivery/{repo}/manifests/ac03125-e26e53f"
req = urllib.request.Request(url, method="GET")
req.add_header('Authorization', f'Bearer {token}')
accept = 'application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
req.add_header('Accept', accept)
with urllib.request.urlopen(req) as resp:
    print(resp.read().decode())
