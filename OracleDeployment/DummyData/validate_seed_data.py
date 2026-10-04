#!/usr/bin/env python3
"""Validate committed seed counts, UUID relationships and required fleet-city fields.

With --remote, also verify every expected non-admin primary key exists in the Dev databases.
Extra live records are allowed. Existing fixture state is never overwritten.
"""
import argparse
import json
from collections import defaultdict
import os
from pathlib import Path
import re
import shlex
import subprocess

HERE=Path(__file__).resolve().parent
FILES={
 'identity':['dummy_riders_customers_identity.sql','dummy_identity_data.sql','scenario_identity.sql'],
 'customer':['dummy_customers.sql','dummy_customer_data.sql','scenario_customer.sql'],
 'delivery':['dummy_riders.sql','dummy_delivery_data.sql','scenario_delivery.sql'],
 'restaurant':['dummy_data.sql','scenario_restaurant.sql'],
 'government_id':['dummy_government_id_brands.sql','dummy_government_id_executives.sql','scenario_government_id.sql'],
}
def values(text):
    parts=[]; start=0; quoted=False; depth=0; i=0
    while i<len(text):
        c=text[i]
        if c=="'":
            if quoted and i+1<len(text) and text[i+1]=="'": i+=2;continue
            quoted=not quoted
        elif not quoted:
            if c=='(':depth+=1
            elif c==')':depth-=1
            elif c==',' and depth==0:parts.append(text[start:i].strip());start=i+1
        i+=1
    parts.append(text[start:].strip())
    return [p[1:-1].replace("''", "'") if p.startswith("'") and p.endswith("'") else p for p in parts]

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--remote',action='store_true');args=parser.parse_args()
    tables=defaultdict(list); databases={}
    for db,names in FILES.items():
        for name in names:
            for line in (HERE/name).read_text().splitlines():
                m=re.fullmatch(r'INSERT INTO (\w+) \(([^)]+)\) VALUES \((.*)\)(?: ON CONFLICT(?: \([^)]*\))? DO NOTHING)?;',line)
                if m:
                    table,cols,data=m.groups();cols=[c.strip() for c in cols.split(',')];data=values(data)
                    assert len(cols)==len(data),(name,table,'invalid column/value count')
                    tables[db+'.'+table].append(dict(zip(cols,data)));databases[db+'.'+table]=db
    expected={'identity.organisations':14,'identity.organisation_members':14,'identity.users':554,'customer.customers':504,'customer.customer_addresses':1003,
              'delivery.delivery_executives':34,'restaurant.brands':13,'restaurant.outlets':104,
              'restaurant.categories':103,'restaurant.master_menu_items':504}
    for table,count in expected.items():assert len(tables[table])==count,(table,len(tables[table]),count)
    index={}
    for table,rows in tables.items():
        pk=next((key for key in ['id','document_id','bank_id','verification_id'] if key in rows[0]),None)
        if pk:
            ids=[row[pk] for row in rows];assert len(ids)==len(set(ids)),(table,'duplicate primary key')
            index[table]=set(ids)
    def references(table,column,parent):
        for row in tables[table]:
            if row.get(column,'NULL')!='NULL':assert row[column] in index[parent],(table,column,row[column])
    for table,column,parent in [
        ('identity.user_roles','user_id','identity.users'),
        ('customer.customers','id','identity.users'),('customer.customer_addresses','customer_id','customer.customers'),
        ('delivery.delivery_executives','id','identity.users'),('restaurant.brands','organisation_id','identity.organisations'),
        ('identity.organisations','created_by','identity.users'),('identity.organisation_members','user_id','identity.users'),
        ('identity.organisation_members','organisation_id','identity.organisations'),
        ('restaurant.outlets','brand_id','restaurant.brands'),('restaurant.categories','brand_id','restaurant.brands'),
        ('restaurant.master_menu_items','brand_id','restaurant.brands'),('restaurant.master_menu_items','category_id','restaurant.categories'),
        ('restaurant.outlet_menu_overrides','outlet_id','restaurant.outlets'),('restaurant.outlet_menu_overrides','master_menu_item_id','restaurant.master_menu_items'),
        ('government_id.executive_documents','executive_id','delivery.delivery_executives'),
        ('government_id.executive_bank_details','executive_id','delivery.delivery_executives'),
        ('government_id.brand_documents','brand_id','restaurant.brands'),('government_id.brand_bank_details','brand_id','restaurant.brands')]:
        references(table,column,parent)
    assert len({b['organisation_id'] for b in tables['restaurant.brands']}) == len(tables['restaurant.brands']), 'One brand per organisation'
    for organisation in tables['identity.organisations']:
        owners=[m for m in tables['identity.organisation_members'] if m['organisation_id']==organisation['id'] and m['role']=='OWNER' and m['status']=='ACTIVE']
        assert len(owners)==1, (organisation['id'],'Expected exactly one active owner')
        assert owners[0]['user_id']==organisation['created_by'], (organisation['id'],'Seed owner mismatch')
    for table in ['customer.customer_addresses','restaurant.outlets','delivery.delivery_executives']:
        for row in tables[table]:assert re.fullmatch('[A-Z][A-Z0-9_-]{0,63}',row.get('city_id','')),(table,'missing/invalid city_id')
    identities={row['id']:row['phone_number'] for row in tables['identity.users']}
    for table in ['customer.customers','delivery.delivery_executives']:
        for row in tables[table]:assert identities[row['id']]==row['phone_number'],(table,'phone/UUID mismatch')
    application_states={'DRAFT','SUBMITTED','IN_REVIEW','APPROVED','REJECTED','SUSPENDED'}
    fssai=[row['fssai_license_number'] for row in tables['restaurant.outlets'] if row.get('fssai_license_number') not in {None,'NULL'}]
    assert len(fssai)==len(set(fssai)), 'Outlet FSSAI numbers must be unique'
    vehicles=[row['vehicle_number'] for row in tables['delivery.delivery_executives'] if row.get('vehicle_number') not in {None,'NULL'}]
    assert len(vehicles)==len(set(vehicles)), 'Rider vehicle registrations must be unique'
    for table in ['restaurant.brands','delivery.delivery_executives']:
        for row in tables[table]:
            state=row.get('application_status');assert state in application_states,(table,row['id'],'missing/invalid application status')
            if state in {'REJECTED','SUSPENDED'}:assert 10<=len(row.get('rejection_reason','').strip())<=500,(table,row['id'],'missing rejection/suspension reason')
            if table=='delivery.delivery_executives':assert 'verification_status' not in row,(table,'retired executive status field')
            if table=='restaurant.brands' and state=='APPROVED':
                assert any(outlet['brand_id']==row['id'] and re.fullmatch(r'[0-9]{14}',outlet.get('fssai_license_number','')) for outlet in tables['restaurant.outlets']),(table,row['id'],'approved brand needs an outlet with FSSAI')
    for scenario in json.loads((HERE/'scenario_accounts.json').read_text()):
        if 'applicationStatus' not in scenario:continue
        table='delivery.delivery_executives' if scenario['role']=='DELIVERY' else 'restaurant.brands'
        rows=[row for row in tables[table] if (row['id']==scenario['userId'] if scenario['role']=='DELIVERY'
              else any(member['user_id']==scenario['userId'] and member['organisation_id']==row['organisation_id'] for member in tables['identity.organisation_members']))]
        assert len(rows)==1 and rows[0]['application_status']==scenario['applicationStatus'],(scenario['phone'],'scenario application status mismatch')
    canonical=next(row for row in tables['restaurant.outlets'] if row['name']=='Brand 1 Outlet 3')
    food=next(row for row in tables['restaurant.categories'] if row['brand_id']==canonical['brand_id'] and row['name']=='Food')
    assert any(row['outlet_id']==canonical['id'] and row['category_id']==food['id']
               and row['opening_time']=='00:00:00' and row['closing_time']=='23:59:59'
               for row in tables['restaurant.outlet_category_timings']), 'Canonical Dev Food category must be orderable overnight'
    print('Static seed validation passed: 14 organisations with one ACTIVE OWNER each, 554 identities, 504 customers, 1003 addresses, 34 riders, 13 brands, 104 outlets, 504 dishes; all application states/reasons, scenario mapping and APPROVED brand FSSAI valid')
    if args.remote:
        ssh=['ssh','-o','BatchMode=yes','-o','ConnectTimeout=20','-i',os.environ.get('SSH_KEY','/Users/parthureddy/Documents/OracleSSH/ssh-key-2026-08-16.key'),os.environ.get('VM','ubuntu@140.245.234.137')]
        for db in FILES:
            checks=[]
            for key,ids in index.items():
                if databases[key]!=db:continue
                rows=tables[key];pk=next(k for k in ['id','document_id','bank_id','verification_id'] if k in rows[0])
                # Existing administrators retain their pre-bootstrap UUIDs.
                if key=='identity.users':ids={r['id'] for r in rows if not r['phone_number'].startswith('100000000')}
                literals=','.join("'"+value+"'" for value in sorted(ids))
                checks.append(f"SELECT '{key}=' || COUNT(*) FROM {key.split('.')[1]} WHERE {pk} IN ({literals});")
                checks[-1]+=f"\nDO $$ BEGIN IF (SELECT COUNT(*) FROM {key.split('.')[1]} WHERE {pk} IN ({literals})) <> {len(ids)} THEN RAISE EXCEPTION 'Missing fixtures in {key}'; END IF; END $$;"
            if db=='restaurant':
                checks.append("DO $$ BEGIN IF EXISTS(SELECT FROM brands WHERE application_status NOT IN ('DRAFT','SUBMITTED','IN_REVIEW','APPROVED','REJECTED','SUSPENDED') OR application_status IS NULL OR (application_status IN ('REJECTED','SUSPENDED') AND (rejection_reason IS NULL OR length(btrim(rejection_reason)) NOT BETWEEN 10 AND 500))) OR EXISTS(SELECT FROM brands b WHERE b.application_status='APPROVED' AND NOT EXISTS(SELECT FROM outlets o WHERE o.brand_id=b.id AND o.fssai_license_number ~ '^[0-9]{14}$')) THEN RAISE EXCEPTION 'Invalid brand application seed/completeness'; END IF; END $$;")
                expected_orgs=','.join("('"+b['id']+"'::uuid,'"+b['organisation_id']+"'::uuid)" for b in tables['restaurant.brands'])
                checks.append("DO $$ BEGIN IF EXISTS (SELECT FROM (VALUES "+expected_orgs+") AS expected(id,org) LEFT JOIN brands b USING(id) WHERE b.organisation_id IS DISTINCT FROM expected.org) THEN RAISE EXCEPTION 'Seed brand organisation mismatch'; END IF; END $$;")
                checks.append("DO $$ BEGIN IF NOT EXISTS (SELECT FROM outlet_category_timings WHERE outlet_id='"+canonical['id']+"' AND category_id='"+food['id']+"' AND opening_time='00:00:00'::time AND closing_time='23:59:59'::time) THEN RAISE EXCEPTION 'Canonical Dev Food category must be orderable overnight'; END IF; END $$;")
            if db=='identity':
                org_ids=','.join("'"+o['id']+"'" for o in tables['identity.organisations'])
                checks.append("DO $$ BEGIN IF EXISTS (SELECT FROM organisations o LEFT JOIN organisation_members m ON m.organisation_id=o.id AND m.role='OWNER' AND m.status='ACTIVE' WHERE o.id IN ("+org_ids+") GROUP BY o.id HAVING count(m.id)<>1) THEN RAISE EXCEPTION 'Seed organisations require exactly one ACTIVE OWNER'; END IF; END $$;")
                checks.append("DO $$ BEGIN IF (SELECT COUNT(DISTINCT u.id) FROM users u JOIN user_roles r ON r.user_id=u.id WHERE u.phone_number IN ('1000000001','1000000002') AND u.is_active AND r.role_name='ADMIN' AND lower(r.service_name) IN ('admin','adminapplication'))<>2 THEN RAISE EXCEPTION 'Expected two provisioned test administrators'; END IF; END $$;")
            if db=='delivery':
                checks.append("DO $$ BEGIN IF EXISTS(SELECT FROM delivery_executives WHERE application_status NOT IN ('DRAFT','SUBMITTED','IN_REVIEW','APPROVED','REJECTED','SUSPENDED') OR application_status IS NULL OR (application_status IN ('REJECTED','SUSPENDED') AND (rejection_reason IS NULL OR length(btrim(rejection_reason)) NOT BETWEEN 10 AND 500))) THEN RAISE EXCEPTION 'Invalid rider application seed'; END IF; END $$;")
            sql='BEGIN READ ONLY;\n'+'\n'.join(checks)+'\nCOMMIT;'
            cmd='cd '+shlex.quote('Food Delivery.nosync/Deployment')+f' && docker compose exec -T -u postgres postgres psql -X -qAt -v ON_ERROR_STOP=1 -d {db}_db'
            result=subprocess.run(ssh+[cmd],input=sql,text=True,capture_output=True,timeout=90)
            if result.returncode:raise RuntimeError(result.stderr.strip())
            print(result.stdout.strip())
        print('Live seed primary-key and admin-role verification passed')

if __name__=='__main__':main()
