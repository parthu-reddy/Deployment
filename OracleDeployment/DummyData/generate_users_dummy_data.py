import random
import uuid
import math

base_lat = 12.990300
base_lng = 77.670900
customer_radius_km = 3.0
rider_radius_km = 3.0

def generate_random_point(lat, lng, radius_km):
    u = random.random()
    v = random.random()
    w = radius_km / 111.0
    t = 2 * math.pi * v
    x = w * math.sqrt(u) * math.cos(t)
    y = w * math.sqrt(u) * math.sin(t)
    new_lng = x / math.cos(math.radians(lat))
    return lat + y, lng + new_lng

customers = []
riders = []

# Generate 30 riders
for i in range(1, 31):
    rider_id = str(uuid.uuid4())
    # Phone number 5000000001 to 5000000030
    phone = f"500000{str(i).zfill(4)}"
    lat, lng = generate_random_point(base_lat, base_lng, rider_radius_km)
    
    riders.append({
        'id': rider_id,
        'phone': phone,
        'name': f"Rider {i}",
        'email': f"rider{i}@example.com",
        'vehicle': f"KA{str(random.randint(10,99))}AB{str(random.randint(1000,9999))}",
        'lat': lat,
        'lng': lng
    })

# Generate 500 customers
for i in range(1, 501):
    customer_id = str(uuid.uuid4())
    # Phone number 6000000001 to 6000000500
    phone = f"600000{str(i).zfill(4)}"
    
    addresses = []
    for j in range(2):
        lat, lng = generate_random_point(base_lat, base_lng, customer_radius_km)
        addresses.append({
            'id': str(uuid.uuid4()),
            'label': 'Home' if j == 0 else 'Work',
            'line1': f"{random.randint(1, 999)}, Random Street {random.randint(1, 50)}",
            'city': 'Bangalore',
            'state': 'Karnataka',
            'zip': '560001',
            'lat': lat,
            'lng': lng,
            'is_default': 'TRUE' if j == 0 else 'FALSE'
        })
        
    customers.append({
        'id': customer_id,
        'phone': phone,
        'name': f"Customer {i}",
        'email': f"customer{i}@example.com",
        'addresses': addresses
    })

# Write SQL
with open("dummy_riders_customers_identity.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for r in riders:
        f.write(f"INSERT INTO users (id, phone_number, name, email) VALUES ('{r['id']}', '{r['phone']}', '{r['name']}', '{r['email']}');\n")
        f.write(f"INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('{str(uuid.uuid4())}', '{r['id']}', 'delivery-service', 'DELIVERY');\n")
    for c in customers:
        f.write(f"INSERT INTO users (id, phone_number, name, email) VALUES ('{c['id']}', '{c['phone']}', '{c['name']}', '{c['email']}');\n")
        f.write(f"INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('{str(uuid.uuid4())}', '{c['id']}', 'customer-service', 'CUSTOMER');\n")
    f.write("\nCOMMIT;\n")

with open("dummy_riders.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for r in riders:
        f.write(f"INSERT INTO delivery_executives (id, phone_number, vehicle_number, status, full_name, email, last_known_location, photo_url) VALUES ('{r['id']}', '{r['phone']}', '{r['vehicle']}', 'ONLINE', '{r['name']}', '{r['email']}', ST_SetSRID(ST_MakePoint({r['lng']}, {r['lat']}), 4326), 'https://example.com/photo.jpg');\n")
    f.write("\nCOMMIT;\n")

with open("dummy_customers.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for c in customers:
        f.write(f"INSERT INTO customers (id, phone_number) VALUES ('{c['id']}', '{c['phone']}');\n")
        for a in c['addresses']:
            f.write(f"INSERT INTO customer_addresses (id, customer_id, label, address_line1, city, state, zip_code, latitude, longitude, is_default) VALUES ('{a['id']}', '{c['id']}', '{a['label']}', '{a['line1']}', '{a['city']}', '{a['state']}', '{a['zip']}', {a['lat']}, {a['lng']}, {a['is_default']});\n")
    f.write("\nCOMMIT;\n")

print("Files created successfully.")
