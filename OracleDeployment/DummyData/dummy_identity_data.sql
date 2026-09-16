BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('426f016b-c98e-43c1-b464-94e1a587f6d3', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('5d540f0a-2c6a-4b64-87dc-0d2ea6b69945', '426f016b-c98e-43c1-b464-94e1a587f6d3', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('aa923368-e7d6-49e2-88bf-52bff6ade67e', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('37bc7b62-7d5f-4dfa-a7d3-d73931872e20', 'aa923368-e7d6-49e2-88bf-52bff6ade67e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('4f0cce5b-8317-4189-8906-9f05369c4ee9', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ad569e68-da9e-45ab-a527-25eb713a7d82', '4f0cce5b-8317-4189-8906-9f05369c4ee9', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1111c5f9-c69b-4f44-81ee-0e27f4bad2e2', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('65a023cd-7991-4d80-996a-fe594721638f', '1111c5f9-c69b-4f44-81ee-0e27f4bad2e2', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('e01886c2-2819-4338-9b74-46fffeb71f26', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ac2fc132-24ae-4d3a-aa16-974f6cd21bd3', 'e01886c2-2819-4338-9b74-46fffeb71f26', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('35095146-05f5-4e30-8cc5-75b13ba4da7a', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('a714c2a9-6b4d-4aa8-979f-e939d6c055e4', '35095146-05f5-4e30-8cc5-75b13ba4da7a', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('d828a8c6-ea39-4689-8145-7249940a6645', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('63a1b121-d413-4135-a5cc-90dea38baa56', 'd828a8c6-ea39-4689-8145-7249940a6645', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('629a09b9-c38a-4ca0-80fc-af80f1314972', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('613614df-7293-4ec0-a228-0de6d38e985b', '629a09b9-c38a-4ca0-80fc-af80f1314972', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('24cce6fa-e8cb-423a-8740-4061489ab7bd', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('2a879c7b-07ec-41d6-82c2-db1bc4d10d11', '24cce6fa-e8cb-423a-8740-4061489ab7bd', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c6c75d95-2fb6-4e84-88e8-bb00573188b2', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ae6b5293-3ea4-431f-bea4-5494da56bd8a', 'c6c75d95-2fb6-4e84-88e8-bb00573188b2', 'restaurant-service', 'RESTAURANT');

COMMIT;
