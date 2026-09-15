BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('9e28ad75-3b50-4e22-bfef-2023c561c659', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1810efe5-e6d4-401b-9111-7001e1ed7ad6', '9e28ad75-3b50-4e22-bfef-2023c561c659', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('f45ce81a-8f0b-465e-8375-3074d34c5864', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('a1e31207-2e9c-4cea-8b8e-b3c153b351db', 'f45ce81a-8f0b-465e-8375-3074d34c5864', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('2ff44503-52a2-41cc-a0fa-185a26008300', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('26990c10-4ab9-4985-9da3-2291f8523161', '2ff44503-52a2-41cc-a0fa-185a26008300', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('067597a5-4237-42bf-975d-1409402f7002', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('614530f1-4353-475e-b83c-a87d58b93f57', '067597a5-4237-42bf-975d-1409402f7002', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('04450e97-e9b3-4d8e-97b6-e7b28e5eb320', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ae38ec8d-e5da-4f8e-8797-bf7ee74cbdcd', '04450e97-e9b3-4d8e-97b6-e7b28e5eb320', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('bbbe6349-87e8-4636-a204-30a13cbb4451', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('3f8a5443-101e-4e96-b643-406ecf9695f5', 'bbbe6349-87e8-4636-a204-30a13cbb4451', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('26f05078-d571-4a1f-b8cb-4c0c8c16db16', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0ca16c48-14dc-442c-9bef-68376c6b8430', '26f05078-d571-4a1f-b8cb-4c0c8c16db16', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('977a714a-edb8-4826-8325-ccb423ddf4e1', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d8bf9624-5ec8-4ca6-9010-187e2f3b88d2', '977a714a-edb8-4826-8325-ccb423ddf4e1', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('0108aa02-e28f-4864-b86f-ebe7f5864060', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('4f6db9c8-671a-468f-9b81-5d6d96e593ad', '0108aa02-e28f-4864-b86f-ebe7f5864060', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('581dcf50-38ae-4dce-8e76-be1b5df52f5b', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('72d8c220-6099-46aa-80c3-99b165dc9737', '581dcf50-38ae-4dce-8e76-be1b5df52f5b', 'restaurant-service', 'RESTAURANT');

COMMIT;
