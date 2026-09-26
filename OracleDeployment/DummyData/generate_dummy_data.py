import random
import uuid
import math
import datetime

# Base coordinates
base_lat = 12.990300
base_lng = 77.670900
radius_km = 1.0
customer_radius_km = 1.0

IMAGE_URLS = [
    "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1499028344343-cd173ffc68a9?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80",
    "https://images.unsplash.com/photo-1565958011703-44f9829ba187?auto=format&fit=crop&w=800&q=80"
]

def get_image_sql_val():
    url = random.choice(IMAGE_URLS)
    return f"'{url}'" if url else "NULL"

radius_km = 1.0
customer_radius_km = 1.0

def generate_random_point(lat, lng, radius_km):
    # 1 degree of lat is ~ 111 km
    # 1 degree of lng is ~ 111 km * cos(lat)
    u = random.random()
    v = random.random()
    w = radius_km / 111.0
    t = 2 * math.pi * v
    x = w * math.sqrt(u) * math.cos(t)
    y = w * math.sqrt(u) * math.sin(t)
    
    new_lng = x / math.cos(math.radians(lat))
    return lat + y, lng + new_lng

brands = []
outlets = []
categories = []
menu_items = []
category_timings_data = []
brand_cat_timings = []
outlet_cat_timings = []
outlet_timings_data = []
customers = []
customer_addresses = []
delivery_riders = []

brand_names = [f"Brand {i}" for i in range(1, 11)]
cuisine_types = ["Italian", "Indian", "Chinese", "Mexican", "Continental", "American", "Thai", "Japanese", "Lebanese", "Mediterranean"]

for i, brand_name in enumerate(brand_names):
    brand_id = str(uuid.uuid4())
    owner_id = str(uuid.uuid4())
    brands.append({
        'id': brand_id,
        'owner_id': owner_id,
        'name': brand_name,
        'created_at': '2026-01-01 00:00:00+00',
        'updated_at': '2026-01-01 00:00:00+00'
    })
    
    # 10 categories per brand
    brand_categories = []
    for j in range(1, 11):
        cat_id = str(uuid.uuid4())
        brand_categories.append(cat_id)
        categories.append({
            'id': cat_id,
            'brand_id': brand_id,
            'name': "Food" if j == 1 else f"{brand_name} Category {j}",
            'description': "General Food Items" if j == 1 else f"Delicious items for {brand_name} Category {j}"
        })
        
        category_timings_data.append({
            'id': str(uuid.uuid4()),
            'category_id': cat_id,
            'opening_time': '00:00:00',
            'closing_time': '23:59:59'
        })
        
        # 5 menu items per category
        for k in range(1, 6):
            item_id = str(uuid.uuid4())
            menu_items.append({
                'id': item_id,
                'brand_id': brand_id,
                'category_id': cat_id,
                'name': f"{brand_name} Item {j}-{k}",
                'description': f"Yummy {brand_name} item {k} in category {j}",
                'base_price': round(random.uniform(5.0, 50.0), 2),
                'default_prep_time_minutes': random.randint(10, 30)
            })
            
        # Randomly override category timings at brand level
        if random.random() > 0.5:
            # Add brand_category_timing
            start_hour = random.randint(6, 11)
            end_hour = random.randint(18, 23)
            brand_cat_timings.append({
                'id': str(uuid.uuid4()),
                'brand_id': brand_id,
                'category_id': cat_id,
                'opening_time': f"{start_hour:02d}:00:00",
                'closing_time': f"{end_hour:02d}:00:00"
            })
            
    # 10 outlets per brand
    for j in range(1, 11):
        outlet_id = str(uuid.uuid4())
        lat, lng = generate_random_point(base_lat, base_lng, radius_km)
        outlets.append({
            'id': outlet_id,
            'brand_id': brand_id,
            'name': f"{brand_name} Outlet {j}",
            'lat': lat,
            'lng': lng,
            'cuisine': cuisine_types[i],
            'rating': round(random.uniform(3.5, 5.0), 1),
            'reviews_count': random.randint(10, 500)
        })
        
        outlet_timings_data.append({
            'id': str(uuid.uuid4()),
            'outlet_id': outlet_id,
            'opening_time': '00:00:00',
            'closing_time': '23:59:59'
        })
        
        # Randomly override category timings at outlet level
        for cat_id in brand_categories:
            if random.random() > 0.7:
                start_hour = random.randint(7, 10)
                end_hour = random.randint(20, 23)
                outlet_cat_timings.append({
                    'id': str(uuid.uuid4()),
                    'outlet_id': outlet_id,
                    'category_id': cat_id,
                    'opening_time': f"{start_hour:02d}:00:00",
                    'closing_time': f"{end_hour:02d}:00:00"
                })



# Write SQL for Restaurant DB
with open("dummy_data.sql", "w") as f:
    f.write("BEGIN;\n\n")
    
    for b in brands:
        f.write(f"INSERT INTO brands (id, owner_id, name, created_at, updated_at, logo_url) VALUES ('{b['id']}', '{b['owner_id']}', '{b['name']}', '{b['created_at']}', '{b['updated_at']}', {get_image_sql_val()});\n")
        
    for o in outlets:
        # Use ST_SetSRID(ST_Point(lng, lat), 4326)
        # Every outlet names its IANA time zone (NOT NULL since TimezoneCorrectness_2026-09-25); the
        # generated outlets are all around Bengaluru.
        f.write(f"INSERT INTO outlets (id, brand_id, name, location, cuisine, rating, reviews_count, banner_url, time_zone) VALUES ('{o['id']}', '{o['brand_id']}', '{o['name']}', ST_SetSRID(ST_Point({o['lng']}, {o['lat']}), 4326), '{o['cuisine']}', {o['rating']}, {o['reviews_count']}, {get_image_sql_val()}, 'Asia/Kolkata');\n")
        
    for c in categories:
        f.write(f"INSERT INTO categories (id, brand_id, name, description, active) VALUES ('{c['id']}', '{c['brand_id']}', '{c['name']}', '{c['description']}', true);\n")
        
    for m in menu_items:
        f.write(f"INSERT INTO master_menu_items (id, brand_id, category_id, name, description, base_price, default_prep_time_minutes, image_url) VALUES ('{m['id']}', '{m['brand_id']}', '{m['category_id']}', '{m['name']}', '{m['description']}', {m['base_price']}, {m['default_prep_time_minutes']}, {get_image_sql_val()});\n")
        
    for ct in category_timings_data:
        f.write(f"INSERT INTO category_timings (id, category_id, opening_time, closing_time) VALUES ('{ct['id']}', '{ct['category_id']}', '{ct['opening_time']}', '{ct['closing_time']}');\n")

    for bct in brand_cat_timings:
        f.write(f"INSERT INTO brand_category_timings (id, brand_id, category_id, opening_time, closing_time) VALUES ('{bct['id']}', '{bct['brand_id']}', '{bct['category_id']}', '{bct['opening_time']}', '{bct['closing_time']}');\n")
        
    for oct in outlet_cat_timings:
        f.write(f"INSERT INTO outlet_category_timings (id, outlet_id, category_id, opening_time, closing_time) VALUES ('{oct['id']}', '{oct['outlet_id']}', '{oct['category_id']}', '{oct['opening_time']}', '{oct['closing_time']}');\n")

    for ot in outlet_timings_data:
        f.write(f"INSERT INTO outlet_timings (id, outlet_id, opening_time, closing_time) VALUES ('{ot['id']}', '{ot['outlet_id']}', '{ot['opening_time']}', '{ot['closing_time']}');\n")

    f.write("\nCOMMIT;\n")

# Write SQL for Identity DB
with open("dummy_identity_data.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for idx, b in enumerate(brands, start=1):
        # We give each owner a name and email to bypass the profile completion check
        owner_name = f"Owner of {b['name']}"
        owner_email = f"owner{idx}@example.com"
        # Unique phone number per owner for login (9000000001 etc)
        phone = f"900000{str(idx).zfill(4)}" 
        
        f.write(f"INSERT INTO users (id, phone_number, name, email) VALUES ('{b['owner_id']}', '{phone}', '{owner_name}', '{owner_email}');\n")
        f.write(f"INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('{str(uuid.uuid4())}', '{b['owner_id']}', 'restaurant-service', 'RESTAURANT');\n")



    f.write("\nCOMMIT;\n")

# Write SQL for Customer DB
with open("dummy_customer_data.sql", "w") as f:
    f.write("BEGIN;\n\n")

    
    f.write("\nCOMMIT;\n")

# Write SQL for Delivery DB
VEHICLE_TYPES_B2 = ['MCWG', 'EV_TWO_WHEELER', 'LMV', 'BICYCLE']
with open("dummy_delivery_data.sql", "w") as f:
    f.write("BEGIN;\n\n")

    
    f.write("\nCOMMIT;\n")

# Generate Brand verification status
with open("dummy_government_id_brands.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for b in brands:
        f.write(f"INSERT INTO brand_documents (id, brand_id, doc_type, document_number, api_verification_status, verified_at) VALUES ('{str(uuid.uuid4())}', '{b['id']}', 'GSTIN', 'GSTIN{str(random.randint(100000000, 999999999))}', 'VERIFIED', CURRENT_TIMESTAMP);\n")
        f.write(f"INSERT INTO brand_documents (id, brand_id, doc_type, document_number, api_verification_status, verified_at) VALUES ('{str(uuid.uuid4())}', '{b['id']}', 'PAN', 'PAN{str(random.randint(10000, 99999))}', 'VERIFIED', CURRENT_TIMESTAMP);\n")
        f.write(f"INSERT INTO brand_documents (id, brand_id, doc_type, document_number, api_verification_status, verified_at) VALUES ('{str(uuid.uuid4())}', '{b['id']}', 'FSSAI', 'FSSAI{str(random.randint(100000, 999999))}', 'VERIFIED', CURRENT_TIMESTAMP);\n")
    f.write("\nCOMMIT;\n")

print("Files generated successfully.")
