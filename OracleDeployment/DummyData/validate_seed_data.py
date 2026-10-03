#!/usr/bin/env python3
"""Validate committed seed counts, UUID relationships and required fleet-city fields.

With --remote, also verify every expected non-admin primary key exists in the Dev databases.
Extra live records are allowed. Existing fixture state is never overwritten.
"""
import argparse
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
    print('Static seed validation passed: 14 organisations with one ACTIVE OWNER each, 554 identities, 504 customers, 1003 addresses, 34 riders, 13 brands, 104 outlets, 504 dishes')
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
                expected_orgs=','.join("('"+b['id']+"'::uuid,'"+b['organisation_id']+"'::uuid)" for b in tables['restaurant.brands'])
                checks.append("DO $$ BEGIN IF EXISTS (SELECT FROM (VALUES "+expected_orgs+") AS expected(id,org) LEFT JOIN brands b USING(id) WHERE b.organisation_id IS DISTINCT FROM expected.org) THEN RAISE EXCEPTION 'Seed brand organisation mismatch'; END IF; END $$;")
            if db=='identity':
                org_ids=','.join("'"+o['id']+"'" for o in tables['identity.organisations'])
                checks.append("DO $$ BEGIN IF EXISTS (SELECT FROM organisations o LEFT JOIN organisation_members m ON m.organisation_id=o.id AND m.role='OWNER' AND m.status='ACTIVE' WHERE o.id IN ("+org_ids+") GROUP BY o.id HAVING count(m.id)<>1) THEN RAISE EXCEPTION 'Seed organisations require exactly one ACTIVE OWNER'; END IF; END $$;")
                checks.append("DO $$ BEGIN IF (SELECT COUNT(DISTINCT u.id) FROM users u JOIN user_roles r ON r.user_id=u.id WHERE u.phone_number IN ('1000000001','1000000002') AND u.is_active AND r.role_name='ADMIN' AND lower(r.service_name) IN ('admin','adminapplication'))<>2 THEN RAISE EXCEPTION 'Expected two provisioned test administrators'; END IF; END $$;")
            sql='BEGIN READ ONLY;\n'+'\n'.join(checks)+'\nCOMMIT;'
            cmd='cd '+shlex.quote('Food Delivery.nosync/Deployment')+f' && docker compose exec -T -u postgres postgres psql -X -qAt -v ON_ERROR_STOP=1 -d {db}_db'
            result=subprocess.run(ssh+[cmd],input=sql,text=True,capture_output=True,timeout=90)
            if result.returncode:raise RuntimeError(result.stderr.strip())
            print(result.stdout.strip())
        print('Live seed primary-key and admin-role verification passed')

if __name__=='__main__':main()
