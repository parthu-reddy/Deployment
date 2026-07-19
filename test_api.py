import urllib.request
import json
import uuid

# We don't know the exact orderId and restaurantId, let's just make one up, we should get 404 or something, not 500
req = urllib.request.Request(
    f"http://localhost:8080/api/v1/restaurants/{uuid.uuid4()}/fulfillment/orders/{uuid.uuid4()}/accept",
    data=json.dumps({"additionalPrepTime": 15, "delayReason": "busy"}).encode("utf-8"),
    headers={"Content-Type": "application/json"}
)
try:
    with urllib.request.urlopen(req) as f:
        print("Response:", f.read().decode("utf-8"))
except urllib.error.HTTPError as e:
    print("HTTPError:", e.code, e.read().decode("utf-8"))
except Exception as e:
    print("Error:", e)
