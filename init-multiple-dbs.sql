-- Databases created when the shared_postgres volume is first initialised.
--
-- Keep this list in step with what services actually target. Every entry here must be the target of
-- some service's datasource URL; every database a service targets must appear here.
--
-- Removed 2026-08-21: advertisement_db -- created here but targeted by nothing.
-- Renamed 2026-08-21: food_delivery -> customer_db. It was CustomerApplication's database under
--   a name predating the service split, and only some config surfaces used it. Every service
--   database now follows <domain>_db.
-- Uncommented 2026-08-21: ondc_db, which ONDCIntegrationService targets but nothing created.
-- Never created here: tracking_db, bidding_db -- these exist only in long-lived local volumes,
--   created by hand at some point. Neither is referenced by any service, and neither will come
--   back on a fresh volume.
CREATE DATABASE customer_db;
CREATE DATABASE notification_db;
CREATE DATABASE payment_db;
CREATE DATABASE restaurant_db;
CREATE DATABASE delivery_db;
CREATE DATABASE identity_db;
CREATE DATABASE government_id_db;
CREATE DATABASE ledger_db;
CREATE DATABASE chat_db;
CREATE DATABASE ondc_db;
CREATE DATABASE wallet_db;
CREATE DATABASE campaign_db;
CREATE DATABASE budget_db;
CREATE DATABASE reviews_db;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
