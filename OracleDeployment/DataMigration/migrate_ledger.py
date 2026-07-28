#!/usr/bin/env python3
import psycopg2
import uuid
import os

# Connect to source and destination databases
# The script is intended to run inside the VM or have port forward
db_pass = os.getenv("DB_PASS", "password")
db_host = os.getenv("DB_HOST", "localhost")

source_conn = psycopg2.connect(
    dbname="food_delivery",
    user="postgres",
    password=db_pass,
    host=db_host
)

dest_conn = psycopg2.connect(
    dbname="ledger_db",
    user="postgres",
    password=db_pass,
    host=db_host
)

source_cur = source_conn.cursor()
dest_cur = dest_conn.cursor()

try:
    print("Migrating ledger_accounts...")
    source_cur.execute("SELECT id, owner_type, owner_id, balance, lock_version FROM ledger_accounts")
    accounts = source_cur.fetchall()
    
    for account in accounts:
        # Check if exists in dest
        dest_cur.execute("SELECT id FROM ledger_accounts WHERE id = %s", (account[0],))
        if dest_cur.fetchone() is None:
            dest_cur.execute(
                "INSERT INTO ledger_accounts (id, owner_type, owner_id, balance, lock_version) VALUES (%s, %s, %s, %s, %s)",
                (account[0], account[1], account[2], account[3], account[4])
            )
            print(f"Inserted account {account[0]}")
    
    print("Migrating ledger_entries...")
    source_cur.execute("SELECT id, transaction_id, account_id, direction, amount, created_at FROM ledger_entries")
    entries = source_cur.fetchall()
    
    for entry in entries:
        dest_cur.execute("SELECT id FROM ledger_entries WHERE id = %s", (entry[0],))
        if dest_cur.fetchone() is None:
            # Default category to 'UNKNOWN' or 'FOOD_COST'
            category = 'FOOD_COST'
            dest_cur.execute(
                "INSERT INTO ledger_entries (id, transaction_id, account_id, direction, category, amount, created_at) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (entry[0], entry[1], entry[2], entry[3], category, entry[4], entry[5])
            )
            print(f"Inserted entry {entry[0]}")
            
    dest_conn.commit()
    print("Migration completed successfully.")

except Exception as e:
    print(f"Error during migration: {e}")
    dest_conn.rollback()
finally:
    source_cur.close()
    dest_cur.close()
    source_conn.close()
    dest_conn.close()
