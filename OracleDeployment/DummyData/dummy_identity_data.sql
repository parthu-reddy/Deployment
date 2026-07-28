BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('1e400d88-69b9-4594-b62b-0067c92b1614', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('7345d56e-dce2-4987-9ddd-6dd6343f401e', '1e400d88-69b9-4594-b62b-0067c92b1614', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('8f87d28c-0426-4564-a778-5817bb5128e2', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('492a7741-11ba-4bb3-99bc-ae5396b9204c', '8f87d28c-0426-4564-a778-5817bb5128e2', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('b1915bb7-9685-4fd3-ac7c-780e0aefb1ee', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('73af185d-2648-4dc2-a7b8-838daa1690b9', 'b1915bb7-9685-4fd3-ac7c-780e0aefb1ee', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('ce39995d-4685-4dac-a1e1-1d37ebf5ff5f', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('3a39812a-c35e-4913-8fdc-98e3962694b4', 'ce39995d-4685-4dac-a1e1-1d37ebf5ff5f', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('f498de29-324e-4007-afe0-17a6a5dd5eb6', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d854b82f-d30c-4b29-be25-222aa6b79684', 'f498de29-324e-4007-afe0-17a6a5dd5eb6', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('a2cc0307-7d3c-462f-b5d5-25c4b080df37', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c400ad34-d781-4468-ac31-38ce1a0cc105', 'a2cc0307-7d3c-462f-b5d5-25c4b080df37', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1e964c21-43e5-4776-b001-b1cacf8dd8af', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('34821c95-5689-4651-8e6c-b8ff3f0e4795', '1e964c21-43e5-4776-b001-b1cacf8dd8af', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('77c48e3b-95f0-41e7-85ee-9dc66738b803', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0cf1c2ab-8593-4960-98b2-6a2ccbef4deb', '77c48e3b-95f0-41e7-85ee-9dc66738b803', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('2ae33aab-746f-4869-adf9-c6aac0f339ab', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('20ba7565-8d25-4903-ae87-aec9f8ce44ca', '2ae33aab-746f-4869-adf9-c6aac0f339ab', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('5c859c8f-31c7-48db-bcb1-f256718e0717', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('f1f1054b-e497-471e-b2e4-dbf013909e0d', '5c859c8f-31c7-48db-bcb1-f256718e0717', 'restaurant-service', 'RESTAURANT');

COMMIT;
