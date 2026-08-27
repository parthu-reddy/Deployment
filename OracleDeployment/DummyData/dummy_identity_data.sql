BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('bf6e19a1-b8a2-4a73-baf4-93976f7fbdc9', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('fa03fccb-242c-4e84-8adb-8f0c2516313f', 'bf6e19a1-b8a2-4a73-baf4-93976f7fbdc9', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('af202f12-c39f-42ba-8518-70bb757a47ac', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('686d4f8e-320e-415f-9429-cc4add635a0a', 'af202f12-c39f-42ba-8518-70bb757a47ac', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('ca17db7c-a655-4a0c-b301-08e7dfd752eb', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('9c1b5f89-57fa-4763-abec-1897cc7c0aa5', 'ca17db7c-a655-4a0c-b301-08e7dfd752eb', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('2b171bb6-b454-486d-a0bd-042e5c88b248', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0b621693-d023-4f45-939c-4bbab06d4813', '2b171bb6-b454-486d-a0bd-042e5c88b248', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('b2c8a89e-3276-4abd-9c72-4715df29d90d', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('69f57536-c71e-4037-9d37-2b0d804b53b2', 'b2c8a89e-3276-4abd-9c72-4715df29d90d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('3b612282-abd3-4a73-9470-461db82d32fc', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d43f8f9e-2d7c-4afa-b16e-3577a8f8eff5', '3b612282-abd3-4a73-9470-461db82d32fc', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('11e84a1d-1b09-48a5-ba4d-9c7660eef395', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('8eef5c84-058d-4fc1-999d-0787fbe863bb', '11e84a1d-1b09-48a5-ba4d-9c7660eef395', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('0e9f9c4a-c4f9-485b-9234-6f21bf3119b2', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('3a4c9ac8-8184-4ffe-8925-4ba9e49be469', '0e9f9c4a-c4f9-485b-9234-6f21bf3119b2', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('294e902f-ed56-4897-a62c-38e9cb20cc8d', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0c83a959-d08e-4774-842a-f22df76566eb', '294e902f-ed56-4897-a62c-38e9cb20cc8d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('69caf172-f1d8-4a2c-8763-cc0ee2fc1dea', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('862976a6-d766-46f1-98e3-facdabeaaf35', '69caf172-f1d8-4a2c-8763-cc0ee2fc1dea', 'restaurant-service', 'RESTAURANT');

COMMIT;
