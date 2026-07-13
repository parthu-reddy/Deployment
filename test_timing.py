import urllib.request
import json

base_url = "http://192.168.64.1:8081/api/v1"

def make_request(method, url, data=None):
    headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer test-token'}
    req = urllib.request.Request(url, headers=headers, method=method)
    if data:
        req.data = json.dumps(data).encode('utf-8')
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

# 1. Get an outlet
status, r = make_request('GET', f"{base_url}/outlets")
outlets = r.get("data", [])
if not outlets:
    print("No outlets found")
    exit(1)
outlet_id = outlets[0]["id"]
print(f"Outlet ID: {outlet_id}")

# 2. Get a category
status, r = make_request('GET', f"{base_url}/categories")
categories = r.get("data", [])
if not categories:
    print("No categories found")
    exit(1)
category_id = categories[0]["id"]
print(f"Category ID: {category_id}")

# 3. Set timing
payload = {
    "categoryId": category_id,
    "timings": [
        {"openingTime": "08:30:00", "closingTime": "21:45:00"}
    ]
}
print(f"Setting timing for outlet {outlet_id} and category {category_id}")
status, r = make_request('POST', f"{base_url}/outlets/{outlet_id}/categories/timings", data=payload)
print(f"Set Response: {status}")
print(r)

# 4. Get timing
status, r = make_request('GET', f"{base_url}/outlets/{outlet_id}/categories/{category_id}/timings")
print(f"Get Response: {status}")
print(r)

