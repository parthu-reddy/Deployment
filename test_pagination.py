import sys
from pathlib import Path
sys.path.append(str(Path.cwd()))
from retention import get_docker_credentials, get_bearer_token, fetch_tags
import urllib.request
import json

repo = "api-gateway"
user, pw = get_docker_credentials()
token = get_bearer_token(repo, user, pw)
url = f"https://hyd.ocir.io/v2/axekmbadoczl/food-delivery/{repo}/tags/list"
req = urllib.request.Request(url)
req.add_header('Authorization', f'Bearer {token}')
with urllib.request.urlopen(req) as resp:
    print("Headers:", resp.headers)
    print("Body:", resp.read().decode())
