BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('a78b9631-e422-438d-8085-6597ef7eb7c1', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('e2c122e1-8e5a-481c-94a0-b3b0c185caeb', 'a78b9631-e422-438d-8085-6597ef7eb7c1', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('d824b87e-3309-47e8-852f-6d40387962ee', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('b9eb7828-de46-42b8-9274-5c9967ce7382', 'd824b87e-3309-47e8-852f-6d40387962ee', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('0ec24bd3-5fce-4c2f-98e4-6684371dd3d2', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ef37f22d-4b17-469e-95b9-81004d752b53', '0ec24bd3-5fce-4c2f-98e4-6684371dd3d2', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('f4abfa78-9a29-4fd1-a374-5dfd35a6de75', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0c5b35b0-483c-4a46-b256-9a4436281551', 'f4abfa78-9a29-4fd1-a374-5dfd35a6de75', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('8729f4b6-66e6-48bf-911c-8ea738bf444d', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('e62aab35-f49c-47e5-9996-32a4c25c9e0c', '8729f4b6-66e6-48bf-911c-8ea738bf444d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('6235fa11-91d6-4542-bd40-e4bb7112d2b0', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('7dfc6496-71e9-4dcf-922d-aff0e63b7f4c', '6235fa11-91d6-4542-bd40-e4bb7112d2b0', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('46bbb3e9-d12c-42a3-bf5f-c1f6865a2a7f', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('5d21cb42-b812-433a-b4f6-44245ac3bbbd', '46bbb3e9-d12c-42a3-bf5f-c1f6865a2a7f', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('d71427cf-78cb-418f-a779-051c12032e72', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('a5fe8d44-81da-4170-b6f1-6990f6678ce3', 'd71427cf-78cb-418f-a779-051c12032e72', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('bb0cc352-71a6-46e0-a17c-8cbd941af417', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('042fd820-5f76-4cbb-8440-47909ecfc162', 'bb0cc352-71a6-46e0-a17c-8cbd941af417', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('8f02a646-4b8a-431b-b6f0-396495f0ae9c', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('be69ac15-fa0e-4f08-a5bc-16f38841c02f', '8f02a646-4b8a-431b-b6f0-396495f0ae9c', 'restaurant-service', 'RESTAURANT');

COMMIT;
