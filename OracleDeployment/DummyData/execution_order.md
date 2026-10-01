# Dummy Data — Execution Order

Run the loader from any directory on the Mac. It waits for healthy owning services,
successful Flyway history and schema markers, then inserts fixtures in dependency order:

```bash
bash Deployment/OracleDeployment/DummyData/run_remote_dummy_data.sh
```

Inserts now preserve existing rows and can recover a partial load. Conflicting phone/UUID
mappings fail instead of overwriting accounts. The loader stops on SQL errors and verifies
expected fixture IDs afterward. This does not restore intentionally changed fixture state.

To add only scenario accounts to an already loaded baseline:

```bash
bash Deployment/OracleDeployment/DummyData/run_remote_dummy_data.sh --scenarios-only
```

A schema reset is a separate destructive operation, needed only when deliberately starting
from an empty schema. `reset_remote_db.sh --all` retains its explicit confirmation prompt.

Neither needs a password. `psql` runs inside the postgres container and reads the credential from
that container's own environment, so it never appears on this machine, in an ssh command line, or in
the VM's process list.

This file previously embedded a third copy of that logic as a `init_dummy_data.sh` snippet. It
inserted into a database named `food_delivery`, **which does not exist** — the customer database is
`customer_db` — so anything pasted from it failed. Use the maintained loader and readiness scripts above.

## What the reset actually does

Schemas are rebuilt by **Flyway**, not Hibernate. Every service runs `ddl-auto: validate`, so
Hibernate creates nothing and refuses to start if the tables are not what it expects. Dropping the
public schema also drops `flyway_schema_history`, so each service re-applies every migration from
V1 on restart. Migrations must therefore stay runnable from an empty database — see
`Deployment/SCHEMA_POLICY.md`.

Two consequences that are easy to miss:

- **Extensions are dropped with the schema.** `postgis` is required by `restaurant_db`,
  `customer_db` and `delivery_db`; `pgcrypto` by `payment_db`. The reset recreates all four. It
  used to recreate only `restaurant_db`'s, and the other three services then failed their
  migrations on boot.
- **Every database's owner must be restarted**, or its schema is never rebuilt. `wallet_db`,
  `campaign_db` and `budget_db` were missing from the old list, so wallet balances and campaigns
  survived a wipe while the users they referenced did not.

`reviews_db` and `ondc_db` are deliberately excluded — `reviews-service` and
`ondc-integration-service` are parked and not running, so nothing would re-migrate them.

## Insertion order

The order is forced by cross-service foreign keys: identities exist before anything references them.

| # | Database | Files |
|---|---|---|
| 1 | `identity_db` | `dummy_riders_customers_identity.sql`, `dummy_identity_data.sql` |
| 2 | `customer_db` | `dummy_customers.sql`, `dummy_customer_data.sql` |
| 3 | `delivery_db` | `dummy_riders.sql`, `dummy_delivery_data.sql` |
| 4 | `restaurant_db` | `dummy_data.sql` |
| 5 | `government_id_db` | `dummy_government_id_brands.sql`, `dummy_government_id_executives.sql` |

To regenerate the SQL before inserting:

```bash
python3 generate_users_dummy_data.py    # identities first
python3 generate_dummy_data.py          # restaurants, orders, addresses
```


## Scenario expansion and verification

`generate_scenario_data.py` writes deterministic additive fixtures without regenerating baseline
UUIDs. It adds four customers, four riders, four restaurant owners and two guarded test admins;
the existing first administrator's UUID is preserved. `scenario_accounts.json` maps their states.

Expected seed coverage: 504 customers, 1,003 addresses, 34 riders, 13 brands, 104 outlets,
504 menu items and two active test administrators. Extra live records are allowed.
The Hyderabad fixtures exercise city separation; their presence does not enable HYD in fleet
configuration or prove Hyderabad dispatch/serviceability.

```bash
python3 Deployment/OracleDeployment/DummyData/validate_seed_data.py
python3 Deployment/OracleDeployment/DummyData/validate_seed_data.py --remote
bash Deployment/OracleDeployment/DummyData/test_schema_readiness.sh
```

The baseline generators still generate new UUIDs. Do not rerun them over shared live fixtures;
regenerating the baseline requires a deliberate coordinated reset of dependent data.
