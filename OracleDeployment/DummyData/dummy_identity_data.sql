BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('19de9a4f-2738-42c8-ab74-1231f4073f5b', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('cc836449-4642-4f20-aca8-e45d6406443f', '19de9a4f-2738-42c8-ab74-1231f4073f5b', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('f3ee925a-b128-4c49-ac8e-3ccdd1c6ae7c', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c236992b-1152-4f99-9171-2abd346aba7a', 'f3ee925a-b128-4c49-ac8e-3ccdd1c6ae7c', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('42f977f1-0f09-48d3-8be0-bf66b64e1768', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('7c4eddf0-8b93-4e92-b3a8-398c42f6b043', '42f977f1-0f09-48d3-8be0-bf66b64e1768', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('fff78be6-fb55-4bb3-b3d0-eb01fa8029e6', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('58ccf87d-4c73-4019-b788-e7ea5a095169', 'fff78be6-fb55-4bb3-b3d0-eb01fa8029e6', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('78541dc2-c3e1-4c53-b99a-ecf69badfe5b', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('3342c584-7412-460c-bd93-dd09d31e9c52', '78541dc2-c3e1-4c53-b99a-ecf69badfe5b', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('a8be83bd-e13d-4f52-a2f0-fca265c0caad', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d1588df0-8d5f-4904-90ff-73fdfeee7554', 'a8be83bd-e13d-4f52-a2f0-fca265c0caad', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('645cd842-99d7-4c4a-ac01-26d36da895ad', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('24afe191-766e-4c83-a9c6-80c0b9587448', '645cd842-99d7-4c4a-ac01-26d36da895ad', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('b8efca7f-132b-48a4-a367-3a03b6f8c0b7', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('58686934-1a26-4188-b654-dc527a0293c1', 'b8efca7f-132b-48a4-a367-3a03b6f8c0b7', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('7af19320-2887-43d2-b82f-69df2beb86e0', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('98d3eeae-b0c8-4eec-8ac0-3b449b2bcf1d', '7af19320-2887-43d2-b82f-69df2beb86e0', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('4202cb3c-84f2-4cb8-8681-da77633e501e', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d1bc4555-28e2-48c9-ac7e-2ef27d48330d', '4202cb3c-84f2-4cb8-8681-da77633e501e', 'restaurant-service', 'RESTAURANT');

COMMIT;
