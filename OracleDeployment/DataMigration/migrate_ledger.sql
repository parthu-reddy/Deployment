-- Connect to food_delivery and export
\c food_delivery
\COPY (SELECT id, owner_type, owner_id, balance, lock_version FROM ledger_accounts) TO '/tmp/accounts.csv' CSV HEADER;
\COPY (SELECT id, transaction_id, account_id, direction, 'FOOD_COST' as category, amount, created_at FROM ledger_entries) TO '/tmp/entries.csv' CSV HEADER;

-- Connect to ledger_db and import
\c ledger_db

CREATE TEMP TABLE tmp_accounts (
    id UUID, owner_type VARCHAR(50), owner_id UUID, balance DECIMAL(15,2), lock_version INT
);
CREATE TEMP TABLE tmp_entries (
    id UUID, transaction_id UUID, account_id UUID, direction VARCHAR(10), category VARCHAR(50), amount DECIMAL(15,2), created_at TIMESTAMP WITH TIME ZONE
);

\COPY tmp_accounts FROM '/tmp/accounts.csv' CSV HEADER;
\COPY tmp_entries FROM '/tmp/entries.csv' CSV HEADER;

INSERT INTO ledger_accounts (id, owner_type, owner_id, balance, lock_version)
SELECT id, owner_type, owner_id, balance, lock_version FROM tmp_accounts
ON CONFLICT (id) DO NOTHING;

INSERT INTO ledger_entries (id, transaction_id, account_id, direction, category, amount, created_at)
SELECT id, transaction_id, account_id, direction, category, amount, created_at FROM tmp_entries
ON CONFLICT (id) DO NOTHING;

