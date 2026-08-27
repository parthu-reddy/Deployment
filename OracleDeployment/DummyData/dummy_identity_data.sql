BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('07fc1e46-21cf-4d6f-bc91-90ea8cb461ac', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('6860bfe9-07f6-4440-95d1-5074cd09a132', '07fc1e46-21cf-4d6f-bc91-90ea8cb461ac', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('80589289-8303-4c28-b235-0842721fe300', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ee793e33-51c4-4591-aaa3-430b2af1a54f', '80589289-8303-4c28-b235-0842721fe300', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('48f4704f-2a6b-4990-a38d-b19db7130db3', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('76404761-33ef-47e4-b996-534cb8b67cc7', '48f4704f-2a6b-4990-a38d-b19db7130db3', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('32e1f70f-da97-4be5-abcf-90c4d921676b', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d13aec39-fb4c-413b-b20c-e17a04ba7cf7', '32e1f70f-da97-4be5-abcf-90c4d921676b', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('fcd56237-a160-463a-b4f3-49fca76ff99e', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('8e078f15-ed65-4018-bf2c-7502117a3ff2', 'fcd56237-a160-463a-b4f3-49fca76ff99e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('cb0b3f0e-d73d-45e2-a0f5-a3c3491a2fc9', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('84aefafa-6d7f-40b2-a00a-a5ba4d3ea89b', 'cb0b3f0e-d73d-45e2-a0f5-a3c3491a2fc9', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('477f9c6f-7f65-4703-bc1b-4d52f0257292', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('048093ee-48e5-4e78-bb0e-b336b8d9f36e', '477f9c6f-7f65-4703-bc1b-4d52f0257292', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('b40988cf-2be0-4527-8011-01cedd20d1af', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('04cf97a2-f745-4bcb-bdef-b4e421387ad3', 'b40988cf-2be0-4527-8011-01cedd20d1af', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('2f6a0e36-0b9a-43a7-b525-800147115715', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('fcc385ed-bcac-4a62-a522-27f9723a914f', '2f6a0e36-0b9a-43a7-b525-800147115715', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('345d0688-c280-4d42-85bc-0dac03e9dcda', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('97fb0344-c829-48db-a31f-a485faebedc5', '345d0688-c280-4d42-85bc-0dac03e9dcda', 'restaurant-service', 'RESTAURANT');

COMMIT;
