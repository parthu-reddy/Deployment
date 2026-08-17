BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('bbe51b68-1935-4f68-9be6-2920ea1f23f5', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('e81ff7ad-025a-4980-be16-344c48ecb56a', 'bbe51b68-1935-4f68-9be6-2920ea1f23f5', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1497f021-7047-4913-ad2b-c2caeae6a1b9', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('11ef12a0-3718-44b5-bdd1-6fed705f5b34', '1497f021-7047-4913-ad2b-c2caeae6a1b9', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('d5616439-4ac4-4aaa-bbdc-2a74054000ba', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ea1d56e6-e825-472e-9f46-6b42b1febc20', 'd5616439-4ac4-4aaa-bbdc-2a74054000ba', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('dfe271ca-a7fc-4fb6-85a4-2b9b568b273f', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('6e432fae-8a52-4f3a-94be-ea3b4eeedfb9', 'dfe271ca-a7fc-4fb6-85a4-2b9b568b273f', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('a37b4657-9d9d-499b-8cdb-86162fdb566c', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('42751397-679c-45f0-8946-e46a0ff68e41', 'a37b4657-9d9d-499b-8cdb-86162fdb566c', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('faf94c7c-5c54-4064-b33c-cc66f9fec4fb', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('af8fdca2-859a-4e53-a6c0-c4bd084509a1', 'faf94c7c-5c54-4064-b33c-cc66f9fec4fb', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('ae46571e-be04-4949-a9ab-444f0b3daeac', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('06e4a7be-f196-4d55-bf01-79aaf4186e75', 'ae46571e-be04-4949-a9ab-444f0b3daeac', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('6888580d-df43-44a3-b8f8-b2be3cb5ba1d', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('9f64f523-86ed-435f-b526-f7126e99fc85', '6888580d-df43-44a3-b8f8-b2be3cb5ba1d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('d6d5427f-b0f2-4b15-b625-71093570cd44', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('3b8c9f82-7fe6-417b-b6b7-a6bb8a03794c', 'd6d5427f-b0f2-4b15-b625-71093570cd44', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('9689aee0-fb94-4f5e-bcf0-7e920fb0d514', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d0021dde-eba6-4e64-ba6f-44e6e85a1be8', '9689aee0-fb94-4f5e-bcf0-7e920fb0d514', 'restaurant-service', 'RESTAURANT');

COMMIT;
