import urllib.request
import json

# 1. Generate OTP
try:
    req0 = urllib.request.Request("http://localhost:8080/api/v1/internal/auth/generate-otp?phoneNumber=1234567899", method="POST")
    urllib.request.urlopen(req0)
except Exception as e:
    pass

# 2. Login
login_data = json.dumps({"phoneNumber": "1234567899", "otp": "123456"}).encode('utf-8')
req = urllib.request.Request("http://localhost:8080/api/v1/internal/auth/login", data=login_data, headers={'Content-Type': 'application/json', 'X-Calling-Service': 'delivery'})
try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode('utf-8'))
        token = res['data']['token']
        print("Got token length:", len(token))
except Exception as e:
    print("Login failed:", e)
    if hasattr(e, 'read'):
        print(e.read().decode('utf-8'))
    exit(1)

# 3. Call profile API
req2 = urllib.request.Request("http://localhost:8080/api/delivery/profile?phoneNumber=1234567899", headers={'Authorization': 'Bearer ' + token})
try:
    with urllib.request.urlopen(req2) as response:
        print("Profile status:", response.status)
        print("Profile response:", response.read().decode('utf-8'))
except Exception as e:
    print("Profile failed:", getattr(e, 'status', 'Unknown status'))
    if hasattr(e, 'read'):
        print(e.read().decode('utf-8'))

