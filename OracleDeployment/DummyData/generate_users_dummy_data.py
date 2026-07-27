import random
import uuid
import math

base_lat = 12.990300
base_lng = 77.670900
customer_radius_km = 3.0
rider_radius_km = 3.0

IMAGE_URLS = [
    "https://pub-331840c6b8de469a8750b945b9159673.r2.dev/SampleImages/1eace54b-6c8b-4de4-9247-3e028bfad925_dadf2264-a4fb-4ef2-a24a-71a7d5cd526a.jpg",
    "https://pub-331840c6b8de469a8750b945b9159673.r2.dev/SampleImages/740a92bd202ffd40813bc354b86005db.avif",
    "https://pub-331840c6b8de469a8750b945b9159673.r2.dev/SampleImages/991da0faa53554ef91bfac714da24c29.avif",
    "https://pub-331840c6b8de469a8750b945b9159673.r2.dev/SampleImages/Fried_Chicken_Bucket_spicy_202607250834.jpeg",
    "https://pub-331840c6b8de469a8750b945b9159673.r2.dev/SampleImages/Kurkure_Chaat_snacks_with_onions_202607250834.jpeg",
    "https://pub-331840c6b8de469a8750b945b9159673.r2.dev/SampleImages/Mutton_Kheema_Dosa_with_gravy_202607250833.jpeg",
    "https://pub-331840c6b8de469a8750b945b9159673.r2.dev/SampleImages/Triple_Schezwan_Veg_Rice_202607250834.jpeg",
    None, None, None, None
]

def get_image_sql_val():
    url = random.choice(IMAGE_URLS)
    return f"'{url}'" if url else "NULL"


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

VEHICLE_TYPES = ['MCWG', 'EV_TWO_WHEELER', 'LMV', 'BICYCLE']
IFSC_CODES = ['SBIN0001234', 'HDFC0001234', 'ICIC0001234', 'UTIB0001234', 'KKBK0001234']

with open("dummy_riders.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for i, r in enumerate(riders):
        vtype = VEHICLE_TYPES[i % len(VEHICLE_TYPES)]
        f.write(f"INSERT INTO delivery_executives (id, phone_number, vehicle_number, status, full_name, email, last_known_location, photo_url, verification_status, vehicle_type, is_active, last_biometric_verification_at) VALUES ('{r['id']}', '{r['phone']}', '{r['vehicle']}', 'ONLINE', '{r['name']}', '{r['email']}', ST_SetSRID(ST_MakePoint({r['lng']}, {r['lat']}), 4326), {get_image_sql_val()}, 'APPROVED', '{vtype}', TRUE, CURRENT_TIMESTAMP);\n")
    f.write("\nCOMMIT;\n")

with open("dummy_government_id_executives.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for i, r in enumerate(riders):
        vtype = VEHICLE_TYPES[i % len(VEHICLE_TYPES)]
        dl_class = 'MCWG' if vtype in ('MCWG', 'EV_TWO_WHEELER') else ('LMV' if vtype == 'LMV' else 'MCWG')
        # Aadhaar
        f.write(f"INSERT INTO executive_documents (document_id, executive_id, doc_type, document_number, document_url, api_verification_status, created_at) VALUES ('{str(uuid.uuid4())}', '{r['id']}', 'AADHAAR', '123456789012', {get_image_sql_val()}, 'APPROVED', CURRENT_TIMESTAMP);\n")
        # Driving License with correct vehicle class stored in api_raw_response
        f.write(f"INSERT INTO executive_documents (document_id, executive_id, doc_type, document_number, document_url, api_verification_status, api_raw_response, created_at) VALUES ('{str(uuid.uuid4())}', '{r['id']}', 'DRIVING_LICENSE', 'DL-{r['phone'][-4:]}', {get_image_sql_val()}, 'APPROVED', '{{\"vehicleClass\": \"{dl_class}\"}}', CURRENT_TIMESTAMP);\n")
        # Vehicle RC
        f.write(f"INSERT INTO executive_documents (document_id, executive_id, doc_type, document_number, document_url, api_verification_status, created_at) VALUES ('{str(uuid.uuid4())}', '{r['id']}', 'RC', '{r['vehicle']}', {get_image_sql_val()}, 'APPROVED', CURRENT_TIMESTAMP);\n")
        # Bank Details
        acct_num = f"1234567890{str(i+1).zfill(2)}"
        ifsc = IFSC_CODES[i % len(IFSC_CODES)]
        f.write(f"INSERT INTO executive_bank_details (bank_id, executive_id, account_number, ifsc_code, bank_registered_name, penny_drop_status, name_match_score, verified_at) VALUES ('{str(uuid.uuid4())}', '{r['id']}', '{acct_num}', '{ifsc}', '{r['name']}', 'APPROVED', 0.950, CURRENT_TIMESTAMP);\n")
        # Biometric verification record
        f.write(f"INSERT INTO biometric_verifications (verification_id, executive_id, selfie_url, confidence_score, is_live, verification_time) VALUES ('{str(uuid.uuid4())}', '{r['id']}', {get_image_sql_val()}, 0.950, TRUE, CURRENT_TIMESTAMP);\n")
    f.write("\nCOMMIT;\n")

with open("dummy_customers.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for c in customers:
        f.write(f"INSERT INTO customers (id, phone_number) VALUES ('{c['id']}', '{c['phone']}');\n")
        for a in c['addresses']:
            f.write(f"INSERT INTO customer_addresses (id, customer_id, label, address_line1, city, state, zip_code, latitude, longitude, is_default) VALUES ('{a['id']}', '{c['id']}', '{a['label']}', '{a['line1']}', '{a['city']}', '{a['state']}', '{a['zip']}', {a['lat']}, {a['lng']}, {a['is_default']});\n")
    f.write("\nCOMMIT;\n")

print("Files created successfully.")
