BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('8764df53-387f-455b-93aa-f381e4d25085', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('58eacd5e-5c6e-4203-ab10-ba61dc6e2913', '8764df53-387f-455b-93aa-f381e4d25085', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('0d1fe542-fa39-4eb1-a938-90f0049af577', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('849ecdd9-4bce-4a8e-a9ff-a6b4eb86bdf2', '0d1fe542-fa39-4eb1-a938-90f0049af577', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c9313057-d683-4628-a977-5d61bbbeada5', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('43bfe7fe-a62b-45e3-a309-d3f50a63a975', 'c9313057-d683-4628-a977-5d61bbbeada5', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('5de6c26e-f6f8-43a2-8bae-c2bc0baaf15c', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('3fb6f83d-e709-49ad-902c-16960c4877b7', '5de6c26e-f6f8-43a2-8bae-c2bc0baaf15c', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('63658a21-e197-4558-9a67-38fa5858455b', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('991f94dc-53ac-46cf-b99b-75032ab8fe94', '63658a21-e197-4558-9a67-38fa5858455b', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('6f57609e-ea6e-47b3-b81e-ed4ac562c89d', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('a000c0fe-06f8-4aad-961e-2f328f625292', '6f57609e-ea6e-47b3-b81e-ed4ac562c89d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('a8666b82-527e-4a78-aef3-f7d8ee187dbc', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('45712185-a618-4f24-af82-ec726ab5a2a4', 'a8666b82-527e-4a78-aef3-f7d8ee187dbc', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('dd8c9b70-3b05-4355-bc04-5d07328a375b', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('f903d0b0-ca0b-41cb-a1f7-855ae3e1bedd', 'dd8c9b70-3b05-4355-bc04-5d07328a375b', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('04257997-e6dd-4976-8e3f-79f085b9f9fc', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('bc8b6473-3210-45a2-b08c-5f0d1f00b483', '04257997-e6dd-4976-8e3f-79f085b9f9fc', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('7b7a8c0c-5c50-42ff-9237-da64911c4dba', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('74355357-7363-4bfb-b641-bf8c507879d7', '7b7a8c0c-5c50-42ff-9237-da64911c4dba', 'restaurant-service', 'RESTAURANT');

COMMIT;
