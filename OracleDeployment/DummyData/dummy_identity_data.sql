BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('1df00aaf-4b47-42ef-976c-45e763cdf5c9', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('4b97feca-de45-427e-bd81-74ebbf2b6629', '1df00aaf-4b47-42ef-976c-45e763cdf5c9', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('284bd57b-8de8-48bc-bb08-c36606e87946', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('9f323032-6bea-4a50-9fd4-67a9596ff61c', '284bd57b-8de8-48bc-bb08-c36606e87946', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('84075d15-069e-4fa5-a28e-1802cd85fe77', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0f5227f5-03d0-44b0-8fbb-072d764311c1', '84075d15-069e-4fa5-a28e-1802cd85fe77', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('425a11de-e18e-4e6c-9c69-b88973d39391', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ce3bcbd1-591f-498a-a5cd-e2faad41b2cb', '425a11de-e18e-4e6c-9c69-b88973d39391', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c8f74fbc-68e4-43a4-a8ed-a8349fac09d2', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('cc42d94b-19ba-4746-9e04-568251cfe358', 'c8f74fbc-68e4-43a4-a8ed-a8349fac09d2', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('9499238b-6924-485e-84ce-9f9902ae75e0', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('27698e4b-aa44-4ad1-97e1-9fa13707bb8a', '9499238b-6924-485e-84ce-9f9902ae75e0', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('0ae21042-0cc5-4eee-82c8-a72b0fc7a81f', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c6cbf5a0-830e-4234-8c1e-b147edb3109e', '0ae21042-0cc5-4eee-82c8-a72b0fc7a81f', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('06972db6-8198-46ea-a6e5-f810d5135279', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('5ed1267a-a65b-4cb0-b265-c46ac7c8b2a1', '06972db6-8198-46ea-a6e5-f810d5135279', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c78865c5-e34c-482f-a5e2-41e2ce41733c', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('a617914f-6cdc-499a-b584-199c885a5cf3', 'c78865c5-e34c-482f-a5e2-41e2ce41733c', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('6824a6fd-8da5-48e8-9c4b-4c1e32069845', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('62ceee55-9ca1-499e-afb5-203580606c0e', '6824a6fd-8da5-48e8-9c4b-4c1e32069845', 'restaurant-service', 'RESTAURANT');

COMMIT;
