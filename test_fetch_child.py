import sys
from pathlib import Path
sys.path.append(str(Path.cwd()))
from retention import get_docker_credentials, get_bearer_token
import urllib.request

repo = "bidding-engine"
user, pw = get_docker_credentials()
token = get_bearer_token(repo, user, pw)
url = f"https://hyd.ocir.io/v2/axekmbadoczl/food-delivery/{repo}/manifests/sha256:1cd80ef60cf512908f1f4eb10f3bda7327ade43c942f50fdb112dde79ae17013"
req = urllib.request.Request(url, method="HEAD")
req.add_header('Authorization', f'Bearer {token}')
req.add_header('Accept', 'application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json')
try:
    urllib.request.urlopen(req)
    print("Child manifest exists!")
except urllib.error.HTTPError as e:
    print(f"Error fetching child manifest: {e.code}")
