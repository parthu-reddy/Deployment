BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('db04c847-5625-4ad2-b98f-40396e852c4d', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('f4db8ab0-6fa4-460f-a0ea-64f04ed292b2', 'db04c847-5625-4ad2-b98f-40396e852c4d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('a3db9494-e574-4926-a8fc-4b2794a9b6ab', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('f70ae53c-3ea9-4a0c-b094-03ab4b8ef3bd', 'a3db9494-e574-4926-a8fc-4b2794a9b6ab', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('5b2b2f86-6fa5-4a5c-bb79-fb89a141c9b6', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1b2d1947-d0a0-4a99-a7c7-95e1cc189518', '5b2b2f86-6fa5-4a5c-bb79-fb89a141c9b6', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('67653df0-1f9e-4612-96b0-5ef8c58adc03', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('b83a1756-9f52-45b3-9eff-d4168b1c37e0', '67653df0-1f9e-4612-96b0-5ef8c58adc03', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('be4f5cc2-23ef-47c7-91b8-889fd997405d', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('900ac0d7-70dd-4163-a87d-226e9307d03b', 'be4f5cc2-23ef-47c7-91b8-889fd997405d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1f6f14ba-3156-446a-b804-74ed4a2744d0', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('a6e451ed-eca7-4767-89bc-7f84829ab283', '1f6f14ba-3156-446a-b804-74ed4a2744d0', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('496d6386-755e-40fe-8ba9-bb3611a9a750', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('2f21f9a9-d52e-4d8f-af2c-a1fa1b2b8ef5', '496d6386-755e-40fe-8ba9-bb3611a9a750', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('be48d862-70c3-42c4-a760-8d42f988d7fe', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('749d6097-aaa1-483c-b87c-5656aecd335c', 'be48d862-70c3-42c4-a760-8d42f988d7fe', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('ffc83e99-96c7-4fcf-b0ed-29d6ce95464c', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('292df20b-b287-4992-b6d6-653037a32d57', 'ffc83e99-96c7-4fcf-b0ed-29d6ce95464c', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('bda65c93-8cc5-43fb-8f26-71269d1ef7ee', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('bcea6880-ef18-4fda-9905-7d8f0c2717d4', 'bda65c93-8cc5-43fb-8f26-71269d1ef7ee', 'restaurant-service', 'RESTAURANT');

COMMIT;
