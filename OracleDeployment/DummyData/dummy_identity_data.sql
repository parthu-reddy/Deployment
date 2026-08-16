BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('7241e8ca-840c-4995-afff-b42cc5f4b36e', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('4f392446-a9e9-407b-8253-1e336bb90a99', '7241e8ca-840c-4995-afff-b42cc5f4b36e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('25ad04f5-8de2-486b-ac77-924ee142f3da', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ca936e6d-d1cc-4db5-a213-3d6b02116b69', '25ad04f5-8de2-486b-ac77-924ee142f3da', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('129de3ba-c49e-40e4-b060-f5e4a1fe0459', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('4e37faef-4a89-4387-9f72-9c63d250402c', '129de3ba-c49e-40e4-b060-f5e4a1fe0459', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('a3b25dd6-02ed-4a6c-bf30-ba1fe0fec248', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c7986685-9054-4882-9415-33a8b1dd83c3', 'a3b25dd6-02ed-4a6c-bf30-ba1fe0fec248', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('5ae4c176-bc92-4a61-8897-1f982a4bf7e7', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('5a6ead1b-eb6b-4ec9-829f-73787c365547', '5ae4c176-bc92-4a61-8897-1f982a4bf7e7', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('999f235d-7676-4f49-b6a9-cd13cba58d15', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('909043b5-7e39-437c-ba51-8d6ed941b2cc', '999f235d-7676-4f49-b6a9-cd13cba58d15', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('41e6e2d2-871e-4681-ac11-2fc46564faf3', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('91a69e97-11dd-41ec-ad70-8d5c6627f623', '41e6e2d2-871e-4681-ac11-2fc46564faf3', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('4dfac5bf-36d0-4189-858a-855661a99d4e', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0bfd3549-97ae-4315-8fbd-fe90af36c7b7', '4dfac5bf-36d0-4189-858a-855661a99d4e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('036249fd-03ff-4af6-9a60-10b8e3eaa6b4', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('72f31acf-bb7d-41f2-a0ce-032986a778a8', '036249fd-03ff-4af6-9a60-10b8e3eaa6b4', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('ccfded48-91c6-4992-85d2-d841c49be961', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('f55c324a-ab3d-4950-ac3d-d64e7f190d82', 'ccfded48-91c6-4992-85d2-d841c49be961', 'restaurant-service', 'RESTAURANT');

COMMIT;
