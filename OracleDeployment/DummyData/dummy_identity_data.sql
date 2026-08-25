BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('b80ffca1-9933-4bd2-87de-885147145ef3', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('452cc412-a76c-4f67-86f9-a8025aae74e9', 'b80ffca1-9933-4bd2-87de-885147145ef3', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('319c0dd0-06e6-44ba-8a87-121116162da5', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ca8ef85d-9655-4976-ad95-c78771d4b70e', '319c0dd0-06e6-44ba-8a87-121116162da5', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('54fa7344-2c39-44c7-86da-187e1ee9913d', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('477e0594-1e65-4be5-9f8d-7c64e3b6a922', '54fa7344-2c39-44c7-86da-187e1ee9913d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('30221899-f98b-480b-ab80-2cd3a8542f3d', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('cc8b2d76-fabf-465d-8cf1-ccde71fbe80a', '30221899-f98b-480b-ab80-2cd3a8542f3d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('d9a3fc25-b91e-42f2-ae87-826c606d79a3', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('cf8989e4-8953-4237-a681-e8206764812f', 'd9a3fc25-b91e-42f2-ae87-826c606d79a3', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('db5160cf-3197-49e0-8e39-86b714b89b1e', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('4f989fa6-28ac-44d2-9b4f-88bf2c5bda21', 'db5160cf-3197-49e0-8e39-86b714b89b1e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('cb993ecc-f76e-4606-b758-e66a74c2321e', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1f0ef23f-d82a-4bd7-adf5-ba4ad7a2dd7f', 'cb993ecc-f76e-4606-b758-e66a74c2321e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('8d787529-f85a-4f98-8b7a-17c99d9be6f2', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('6c120c69-beed-45b9-851d-47bbde6345c6', '8d787529-f85a-4f98-8b7a-17c99d9be6f2', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('6dcb99b2-ebcb-4cba-9fa3-f497abeb6a71', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('66c7219d-284d-479b-90e8-581b3793a7cb', '6dcb99b2-ebcb-4cba-9fa3-f497abeb6a71', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('488c962f-2d63-412c-ac0f-b10327707ba9', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('996aeaa4-b3b3-4e47-9793-44c1db5d457c', '488c962f-2d63-412c-ac0f-b10327707ba9', 'restaurant-service', 'RESTAURANT');

COMMIT;
