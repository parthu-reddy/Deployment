"""Add deterministic fixtures without regenerating any existing baseline UUID."""
from pathlib import Path
import json
from uuid import UUID, uuid5

HERE = Path(__file__).resolve().parent
NAMESPACE = UUID('18af603a-0ffd-49a0-92ee-5d4ce231d1d8')
def uid(key): return str(uuid5(NAMESPACE, key))
def literal(value):
    if value is None: return 'NULL'
    if isinstance(value, bool): return 'TRUE' if value else 'FALSE'
    if isinstance(value, (int, float)): return str(value)
    return "'" + value.replace("'", "''") + "'"
def insert(table, values):
    return f"INSERT INTO {table} ({', '.join(values)}) VALUES ({', '.join(map(literal, values.values()))}) ON CONFLICT DO NOTHING;"
sql = {db: [] for db in ['identity', 'customer', 'delivery', 'restaurant', 'government_id']}
manifest = []
groups = {
    'CUSTOMER': [(8000000501, 'incomplete-profile'), (8000000502, 'no-address'), (8000000503, 'suspended'), (8000000504, 'second-city')],
    'DELIVERY': [(7000000031, 'pending-kyc'), (7000000032, 'rejected-kyc'), (7000000033, 'approved-offline'), (7000000034, 'inactive-rider')],
    'RESTAURANT': [(9000000011, 'no-brand'), (9000000012, 'pending-brand'), (9000000013, 'rejected-brand'), (9000000014, 'inactive-outlet-and-unavailable-dish')],
}
services = {'CUSTOMER':'CustomerApplication', 'DELIVERY':'DeliveryExecutiveApplication', 'RESTAURANT':'RestaurantApplication'}
for role, entries in groups.items():
    for phone, scenario in entries:
        phone = str(phone); user = uid(phone)
        manifest.append(dict(role=role, phone=phone, userId=user, scenario=scenario))
        # A phone collision must not silently attach a scenario's role to somebody else.
        sql['identity'].append(f"DO $$ BEGIN IF EXISTS (SELECT FROM users WHERE phone_number='{phone}' AND id<>'{user}') THEN RAISE EXCEPTION 'Scenario phone collision: {phone}'; END IF; END $$;")
        incomplete = scenario == 'incomplete-profile'
        sql['identity'].append(insert('users', dict(id=user, phone_number=phone, name=None if incomplete else 'E2E '+scenario,
                email=None if incomplete else f'scenario-{phone}@example.com', is_active=scenario != 'suspended')))
        sql['identity'].append(insert('user_roles', dict(id=uid(phone+'-role'), user_id=user, service_name=services[role], role_name=role)))
        if role == 'CUSTOMER':
            sql['customer'].append(insert('customers', dict(id=user, phone_number=phone)))
            if scenario != 'no-address':
                second = scenario == 'second-city'
                sql['customer'].append(insert('customer_addresses', dict(id=uid(phone+'-home'), customer_id=user, label='Home',
                    address_line1='E2E Scenario Home', city='Hyderabad' if second else 'Bangalore', state='Telangana' if second else 'Karnataka',
                    zip_code='500001' if second else '560001', latitude=17.385 if second else 12.990, longitude=78.4867 if second else 77.670,
                    is_default=True, city_id='HYD' if second else 'BLR')))
        elif role == 'DELIVERY':
            status = {'pending-kyc':'IN_REVIEW','rejected-kyc':'REJECTED','approved-offline':'APPROVED','inactive-rider':'SUSPENDED'}[scenario]
            reason = 'Seeded application requires corrected documents.' if status in ('REJECTED','SUSPENDED') else None
            checks = 'REJECTED' if status == 'REJECTED' else 'APPROVED'
            manifest[-1]['applicationStatus'] = status
            sql['delivery'].append(insert('delivery_executives', dict(id=user, phone_number=phone, full_name='E2E '+scenario,
                email=f'scenario-{phone}@example.com', vehicle_number='KA01E'+phone[-5:], status='OFFLINE', application_status=status,
                rejection_reason=reason, submitted_at='2026-10-03 00:00:00+00',
                vehicle_type='MCWG', is_active=scenario == 'approved-offline', city_id='BLR')))
            for doc in ['DRIVING_LICENSE','RC']:
                sql['government_id'].append(insert('executive_documents', dict(document_id=uid(phone+'-'+doc), executive_id=user,
                    doc_type=doc, document_number='E2E-'+phone+'-'+doc, api_verification_status=checks)))
            sql['government_id'].append(insert('executive_bank_details', dict(bank_id=uid(phone+'-bank'), executive_id=user,
                account_number=phone, ifsc_code='HDFC0000001', bank_registered_name='E2E '+scenario, penny_drop_status=checks)))
        elif role == 'RESTAURANT':
            organisation = uid(phone+'-organisation')
            sql['identity'].append(insert('organisations', dict(id=organisation, display_name='E2E '+scenario, status='ACTIVE',
                created_by=user, created_at='2026-10-03 00:00:00+00', updated_at='2026-10-03 00:00:00+00')))
            sql['identity'].append(insert('organisation_members', dict(id=uid(phone+'-member'), organisation_id=organisation,
                user_id=user, role='OWNER', status='ACTIVE', added_by=user,
                created_at='2026-10-03 00:00:00+00', updated_at='2026-10-03 00:00:00+00')))
            if scenario == 'no-brand': continue
            brand = uid(phone+'-brand'); category = uid(phone+'-category')
            status = 'IN_REVIEW' if scenario == 'pending-brand' else 'REJECTED' if scenario == 'rejected-brand' else 'APPROVED'
            reason = 'Seeded application requires corrected documents.' if status == 'REJECTED' else None
            checks = 'REJECTED' if status == 'REJECTED' else 'APPROVED'
            manifest[-1]['applicationStatus'] = status
            sql['restaurant'].append(insert('brands', dict(id=brand, organisation_id=organisation, name='E2E '+scenario,
                application_status=status, rejection_reason=reason, submitted_at='2026-10-03 00:00:00+00', kyc_status=checks,
                penny_drop_status=checks, is_gstin_verified=checks == 'APPROVED', is_bank_verified=checks == 'APPROVED')))
            sql['restaurant'].append(insert('categories', dict(id=category, brand_id=brand, name='Scenario Food', active=True)))
            for doc in ['PAN','GSTIN']:
                sql['government_id'].append(insert('brand_documents', dict(id=uid(phone+'-'+doc), brand_id=brand,
                    doc_type=doc, document_number='E2E-'+phone+'-'+doc, api_verification_status=checks)))
            sql['government_id'].append(insert('brand_bank_details', dict(id=uid(phone+'-bank'), brand_id=brand, account_number=phone,
                ifsc_code='HDFC0000001', bank_registered_name='E2E '+scenario, penny_drop_status=checks)))
            outlet = uid(phone+'-outlet')
            # Location is a SQL expression, added explicitly after rendering the scalar values.
            row = insert('outlets', dict(id=outlet, brand_id=brand,
                name='E2E Inactive Outlet' if scenario == 'inactive-outlet-and-unavailable-dish' else 'E2E '+scenario+' Outlet',
                is_active=scenario != 'inactive-outlet-and-unavailable-dish',
                cuisine='Indian', time_zone='Asia/Kolkata', city_id='BLR', fssai_license_number='1234'+phone))
            sql['restaurant'].append(row)
            if scenario != 'inactive-outlet-and-unavailable-dish':
                sql['restaurant'].append(f"UPDATE outlets SET location=ST_SetSRID(ST_Point(77.670,12.990),4326) WHERE id='{outlet}' AND location IS NULL;")
                sql['restaurant'].append(insert('outlet_timings',dict(id=uid(phone+'-hours'),outlet_id=outlet,opening_time='00:00:00',closing_time='23:59:59')))
                sql['restaurant'].append(insert('category_timings',dict(id=uid(phone+'-category-hours'),category_id=category,opening_time='00:00:00',closing_time='23:59:59')))
            menu = uid(phone+'-menu')
            sql['restaurant'].append(insert('master_menu_items', dict(id=menu, brand_id=brand, category_id=category,
                name='E2E Vegetarian Dish', base_price=100, is_veg=True)))
            if scenario == 'inactive-outlet-and-unavailable-dish':
                hyd = uid(phone+'-hyd-outlet')
                sql['restaurant'].append(insert('outlets', dict(id=hyd, brand_id=brand, name='E2E Hyderabad Outlet', is_active=True,
                    cuisine='Indian', time_zone='Asia/Kolkata', city_id='HYD', fssai_license_number='1235'+phone)))
                sql['restaurant'].append(f"UPDATE outlets SET location=ST_SetSRID(ST_Point(78.4867,17.385),4326) WHERE id='{hyd}' AND location IS NULL;")
                sql['restaurant'].append(insert('outlet_menu_overrides', dict(id=uid(phone+'-unavailable'), outlet_id=hyd,
                    master_menu_item_id=menu, is_available=False)))
                sql['restaurant'].append(insert('master_menu_items', dict(id=uid(phone+'-nonveg-menu'), brand_id=brand,
                    category_id=category, name='E2E Nonvegetarian Dish', base_price=120, is_veg=False)))
                for key, table, column, entity in [('hours','outlet_timings','outlet_id',hyd), ('category-hours','category_timings','category_id',category)]:
                    sql['restaurant'].append(insert(table, dict(id=uid(phone+'-'+key), **{column:entity}, opening_time='00:00:00',closing_time='23:59:59')))

# Preserve the already approved admin's UUID. A conflicting non-admin account causes a failure.
for number in [1,2]:
    phone = '100000000'+str(number)
    sql['identity'].append(f"""DO $$ BEGIN
IF EXISTS (SELECT FROM users u WHERE u.phone_number='{phone}' AND NOT EXISTS
    (SELECT FROM user_roles r WHERE r.user_id=u.id AND r.role_name='ADMIN' AND lower(r.service_name) IN ('admin','adminapplication'))) THEN
    RAISE EXCEPTION 'Admin phone collision: {phone}';
END IF;
END $$;""")
    sql['identity'].append(insert('users', dict(id=uid(phone), phone_number=phone, name=f'E2E Admin {number}', email=f'e2e-admin-{number}@example.com', is_active=True)))
    sql['identity'].append(f"INSERT INTO user_roles (id,user_id,service_name,role_name) SELECT '{uid(phone+'-role')}',id,'ADMIN','ADMIN' FROM users WHERE phone_number='{phone}' ON CONFLICT DO NOTHING;")
    manifest.append(dict(role='ADMIN',phone=phone,scenario='provisioned-admin-'+str(number)))

for db, statements in sql.items():
    (HERE/f'scenario_{db}.sql').write_text('-- Generated by generate_scenario_data.py. Additive; preserves existing fixture state.\nBEGIN;\n'+ '\n'.join(statements)+'\nCOMMIT;\n')
(HERE/'scenario_accounts.json').write_text(json.dumps(manifest, indent=2)+'\n')
print('Generated 12 scenario accounts and 2 guarded administrators; baseline UUIDs unchanged')
