BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('e3ed75a2-b6dd-4bd3-a156-09494462cff5', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d4f2098f-4c2b-4ff6-8b09-8c6bda29f45f', 'e3ed75a2-b6dd-4bd3-a156-09494462cff5', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('52e01185-f802-4c0d-bdd9-3278c53a4c7e', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c94833a3-3a77-4815-a790-4b14181c85f5', '52e01185-f802-4c0d-bdd9-3278c53a4c7e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('77e7d88c-9723-4cf8-975f-4f48d21b70fc', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('bdbfb758-1a3c-4739-a140-7e128cf21676', '77e7d88c-9723-4cf8-975f-4f48d21b70fc', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('b8675549-6c20-47bd-8c4b-af000a8993db', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('dfd515e3-a030-4c82-8504-ef9dae88f3c5', 'b8675549-6c20-47bd-8c4b-af000a8993db', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('e286e77b-2f83-4d9f-9dc5-1490c35c87cc', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('5f521e55-70eb-47df-973b-216588c91726', 'e286e77b-2f83-4d9f-9dc5-1490c35c87cc', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('a66b3d2a-4638-47a9-a96b-44cff3fa7019', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('715a7139-95a9-4f6f-a866-bea98eb71030', 'a66b3d2a-4638-47a9-a96b-44cff3fa7019', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('f0e0d54a-1011-4180-a466-d23689845692', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('894db1d3-025b-46e2-b939-ecdaf1502c04', 'f0e0d54a-1011-4180-a466-d23689845692', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('ac757283-6f87-4436-ab39-267393f6e497', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('34390664-d146-4439-8d42-472ae9571fbf', 'ac757283-6f87-4436-ab39-267393f6e497', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('230af5ae-9314-4e25-9fbc-00399285c217', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('203fff50-cebb-4c79-8961-dfa102d9735f', '230af5ae-9314-4e25-9fbc-00399285c217', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('54a428e6-b8d1-4b8f-85e2-261d7cee0725', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('251b87e6-5ab4-42c4-a8f6-8462869bca5a', '54a428e6-b8d1-4b8f-85e2-261d7cee0725', 'restaurant-service', 'RESTAURANT');

COMMIT;
