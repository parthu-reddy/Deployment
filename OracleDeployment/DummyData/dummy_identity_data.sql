BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('1ac631ea-9774-47b7-b46e-06a09780e9a5', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('65659a0e-1cfb-44f0-b060-c30a40ddda87', '1ac631ea-9774-47b7-b46e-06a09780e9a5', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('3e2dd0a2-0609-455b-b792-70398e81413a', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('8756c90c-6106-455e-882d-bcec6c22942b', '3e2dd0a2-0609-455b-b792-70398e81413a', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('8d110ee2-4d52-41ef-9004-741fdb838229', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('a7960001-24f7-4a6c-bfa3-0e44d2322411', '8d110ee2-4d52-41ef-9004-741fdb838229', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('5872bd8e-c7d2-42c3-901c-9fa622b33be8', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d4170845-b03e-4b2a-ac15-4f539d951b6d', '5872bd8e-c7d2-42c3-901c-9fa622b33be8', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1b24e90d-83d1-47a2-b51e-ae09b9dc90df', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('4f170360-ed22-42c4-9320-3d4108303f01', '1b24e90d-83d1-47a2-b51e-ae09b9dc90df', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('791711ae-4f42-40ea-b6c8-f599a85019a4', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('2897f596-068d-4562-91ac-beba4edf82dd', '791711ae-4f42-40ea-b6c8-f599a85019a4', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c1308880-949a-4bbe-a4fb-fe08bf43d816', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('177c3faf-8aca-4c37-831a-6fa9df18d158', 'c1308880-949a-4bbe-a4fb-fe08bf43d816', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('bd27479e-3d37-4bb7-8a0e-3bc1f0283d01', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('af7e3d55-1560-4d06-8572-daa9882ee98f', 'bd27479e-3d37-4bb7-8a0e-3bc1f0283d01', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('7a055c9c-89a5-49a8-aaaf-116d8cb6748c', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('2fc5d5dd-f658-4dc7-a696-609d206b6e4c', '7a055c9c-89a5-49a8-aaaf-116d8cb6748c', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('eb9b8be7-a367-4651-a2c2-599478555c58', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1c18c9cb-5e9c-49b9-a109-384f285171bb', 'eb9b8be7-a367-4651-a2c2-599478555c58', 'restaurant-service', 'RESTAURANT');

COMMIT;
