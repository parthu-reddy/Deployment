import random
import uuid
import math
import datetime

# Base coordinates
base_lat = 12.990300
base_lng = 77.670900
radius_km = 3.0
customer_radius_km = 3.0

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
        'created_at': '2026-01-01 00:00:00',
        'updated_at': '2026-01-01 00:00:00'
    })
    
    # 10 categories per brand
    brand_categories = []
    for j in range(1, 11):
        cat_id = str(uuid.uuid4())
        brand_categories.append(cat_id)
        categories.append({
            'id': cat_id,
            'brand_id': brand_id,
            'name': f"{brand_name} Category {j}",
            'description': f"Delicious items for {brand_name} Category {j}"
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

# Generate 500 Customers
for i in range(1, 501):
    customer_id = str(uuid.uuid4())
    # Phone numbers 8000000001 ...
    phone = f"8000{str(i).zfill(6)}"
    customers.append({
        'id': customer_id,
        'phone_number': phone,
        'name': f"Customer {i}",
        'email': f"customer{i}@example.com"
    })
    
    # 2 addresses per customer
    for j in range(1, 3):
        addr_id = str(uuid.uuid4())
        lat, lng = generate_random_point(base_lat, base_lng, customer_radius_km)
        customer_addresses.append({
            'id': addr_id,
            'customer_id': customer_id,
            'label': 'Home' if j == 1 else 'Work',
            'address_line1': f"Address Line 1 - {j}",
            'address_line2': f"Address Line 2 - {j}",
            'city': "Bangalore",
            'state': "Karnataka",
            'zip_code': "560001",
            'latitude': lat,
            'longitude': lng,
            'is_default': 'TRUE' if j == 1 else 'FALSE'
        })

# Generate 30 Delivery Riders
for i in range(1, 31):
    rider_id = str(uuid.uuid4())
    # Phone numbers 7000000001 ...
    phone = f"7000{str(i).zfill(6)}"
    lat, lng = generate_random_point(base_lat, base_lng, radius_km)
    delivery_riders.append({
        'id': rider_id,
        'phone_number': phone,
        'vehicle_number': f"KA01 {str(random.randint(1000, 9999))}",
        'status': 'ONLINE',
        'lat': lat,
        'lng': lng,
        'email': f"rider{i}@example.com",
        'full_name': f"Rider {i}"
    })


# Write SQL for Restaurant DB
with open("dummy_data.sql", "w") as f:
    f.write("BEGIN;\n\n")
    
    for b in brands:
        f.write(f"INSERT INTO brands (id, owner_id, name, created_at, updated_at, logo_url) VALUES ('{b['id']}', '{b['owner_id']}', '{b['name']}', '{b['created_at']}', '{b['updated_at']}', 'https://example.com/logo.jpg');\n")
        
    for o in outlets:
        # Use ST_SetSRID(ST_Point(lng, lat), 4326)
        f.write(f"INSERT INTO outlets (id, brand_id, name, location, cuisine, rating, reviews_count, banner_url) VALUES ('{o['id']}', '{o['brand_id']}', '{o['name']}', ST_SetSRID(ST_Point({o['lng']}, {o['lat']}), 4326), '{o['cuisine']}', {o['rating']}, {o['reviews_count']}, 'https://example.com/banner.jpg');\n")
        
    for c in categories:
        f.write(f"INSERT INTO categories (id, brand_id, name, description) VALUES ('{c['id']}', '{c['brand_id']}', '{c['name']}', '{c['description']}');\n")
        
    for m in menu_items:
        f.write(f"INSERT INTO master_menu_items (id, brand_id, category_id, name, description, base_price, default_prep_time_minutes, image_url) VALUES ('{m['id']}', '{m['brand_id']}', '{m['category_id']}', '{m['name']}', '{m['description']}', {m['base_price']}, {m['default_prep_time_minutes']}, 'https://example.com/item.jpg');\n")
        
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

    for c in customers:
        f.write(f"INSERT INTO users (id, phone_number, name, email) VALUES ('{c['id']}', '{c['phone_number']}', '{c['name']}', '{c['email']}');\n")
        f.write(f"INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('{str(uuid.uuid4())}', '{c['id']}', 'customer-service', 'CUSTOMER');\n")

    for r in delivery_riders:
        f.write(f"INSERT INTO users (id, phone_number, name, email) VALUES ('{r['id']}', '{r['phone_number']}', '{r['full_name']}', '{r['email']}');\n")
        f.write(f"INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('{str(uuid.uuid4())}', '{r['id']}', 'delivery-service', 'DELIVERY');\n")

    f.write("\nCOMMIT;\n")

# Write SQL for Customer DB
with open("dummy_customer_data.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for c in customers:
        f.write(f"INSERT INTO customers (id, phone_number) VALUES ('{c['id']}', '{c['phone_number']}');\n")
    
    for a in customer_addresses:
        f.write(f"INSERT INTO customer_addresses (id, customer_id, label, address_line1, address_line2, city, state, zip_code, latitude, longitude, is_default) VALUES ('{a['id']}', '{a['customer_id']}', '{a['label']}', '{a['address_line1']}', '{a['address_line2']}', '{a['city']}', '{a['state']}', '{a['zip_code']}', {a['latitude']}, {a['longitude']}, {a['is_default']});\n")
    
    f.write("\nCOMMIT;\n")

# Write SQL for Delivery DB
with open("dummy_delivery_data.sql", "w") as f:
    f.write("BEGIN;\n\n")
    for r in delivery_riders:
        f.write(f"INSERT INTO delivery_executives (id, phone_number, vehicle_number, status, last_known_location, email, full_name, photo_url) VALUES ('{r['id']}', '{r['phone_number']}', '{r['vehicle_number']}', '{r['status']}', ST_SetSRID(ST_Point({r['lng']}, {r['lat']}), 4326), '{r['email']}', '{r['full_name']}', 'https://example.com/photo.jpg');\n")
    
    f.write("\nCOMMIT;\n")

