BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('b01b9320-f5e6-4c9b-9226-e2fd77af0a12', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('6b8fdcdc-e583-4c86-b719-99977c9ff015', 'b01b9320-f5e6-4c9b-9226-e2fd77af0a12', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('6ad96a3c-ea75-4c64-9bbc-f63ab1acddea', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c75b5fb7-8d26-4038-a1e4-495ca12bdddf', '6ad96a3c-ea75-4c64-9bbc-f63ab1acddea', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('527d3742-8c20-46d8-9481-1690be5616d2', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('dcc46e1b-5945-48c9-b650-b2a695ec6762', '527d3742-8c20-46d8-9481-1690be5616d2', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('2e9ee269-9822-418a-9888-eb4b6bb7b66e', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('e8b1eed6-1197-49a4-90f8-98c076d762fb', '2e9ee269-9822-418a-9888-eb4b6bb7b66e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('b022be69-e0e0-4fa1-aa05-73e80f6e9bab', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('db7e2e1b-faa6-410c-80c3-687c69699e8e', 'b022be69-e0e0-4fa1-aa05-73e80f6e9bab', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('0d2f44d9-b7a8-4b62-80f1-65200cf7582e', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('88c825d2-fd8f-4c61-a689-3d37f0ca3771', '0d2f44d9-b7a8-4b62-80f1-65200cf7582e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('5189b8f3-cfda-4629-ba6d-628ea4514b8b', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('2a58718c-871a-4752-b513-976fe6a5699c', '5189b8f3-cfda-4629-ba6d-628ea4514b8b', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1a4d7008-aebe-4e37-ba7b-b3f37435b406', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('24ec8657-d14f-4e72-a37a-450d44cd3bee', '1a4d7008-aebe-4e37-ba7b-b3f37435b406', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c790032c-ba6d-46c0-b1f7-2c349d513b01', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('819dccc7-1751-4ff1-b6b6-a95af1617789', 'c790032c-ba6d-46c0-b1f7-2c349d513b01', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c1e14d4f-e93a-461a-9a1a-4fd123e02943', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('8900b5f2-2a39-434a-80a5-6debffb166e1', 'c1e14d4f-e93a-461a-9a1a-4fd123e02943', 'restaurant-service', 'RESTAURANT');

COMMIT;
