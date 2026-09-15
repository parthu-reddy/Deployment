BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('8084874b-d369-4bb9-bc8f-d15a15c5e105', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('4dbf658a-f592-43b6-9e21-f5ee54c50d94', '8084874b-d369-4bb9-bc8f-d15a15c5e105', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('3ed1c76e-e597-48e6-8e10-5f2c18c42ead', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('8e751cbf-e6df-4e60-b23c-f639daebe368', '3ed1c76e-e597-48e6-8e10-5f2c18c42ead', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('49e4dd96-8697-4a8f-a790-3edfb205fdb1', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0d0db47e-b32f-4809-912c-232c57528f88', '49e4dd96-8697-4a8f-a790-3edfb205fdb1', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('88c080a7-37ce-4b57-8b86-0f0220a6a7c4', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('28e6e247-b73e-41c7-9c1d-22e1d4ed32b0', '88c080a7-37ce-4b57-8b86-0f0220a6a7c4', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('4ece458c-fd56-400a-89e7-7cbb7d53e5db', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('051102fa-9d43-4591-803b-9f0c5a0a792d', '4ece458c-fd56-400a-89e7-7cbb7d53e5db', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c6e44bdb-4b61-4901-ae6d-3b8c2645ced7', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1806d8ae-517e-4b32-85bf-9ab0cd18de37', 'c6e44bdb-4b61-4901-ae6d-3b8c2645ced7', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1db04403-b832-466c-a416-5b95a9850f25', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('803502ad-5c30-4bd8-bb65-e36c7e6a7235', '1db04403-b832-466c-a416-5b95a9850f25', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('12f3cb3a-6b02-440e-a9bc-9add6eef841d', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('e97dae5a-bc49-48fb-bca8-ea3b1341c5e6', '12f3cb3a-6b02-440e-a9bc-9add6eef841d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('e427e1bd-8f2d-4be9-999e-4eb6a8f2c934', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('7c114748-422b-4c10-beea-79ac10069cab', 'e427e1bd-8f2d-4be9-999e-4eb6a8f2c934', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('984739dc-9853-4e88-bc5e-6ef355c6aad7', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('b9731408-5452-435d-85b5-cc23d6495a50', '984739dc-9853-4e88-bc5e-6ef355c6aad7', 'restaurant-service', 'RESTAURANT');

COMMIT;
