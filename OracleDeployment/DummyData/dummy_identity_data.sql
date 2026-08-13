BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('c3365820-b182-4307-ba94-094a6cb25db7', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1edbfa89-6ddf-490a-9c64-11f1ac025913', 'c3365820-b182-4307-ba94-094a6cb25db7', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('806123cb-59ca-4f27-a218-3909ed98de46', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('9c79b2d1-0e4e-4647-a62b-8aeb84355f85', '806123cb-59ca-4f27-a218-3909ed98de46', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('5346e991-8e0e-4403-be60-03b4d8812841', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('b6d61c84-2490-4fa6-9000-254b5c012c06', '5346e991-8e0e-4403-be60-03b4d8812841', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('efc3c142-0f89-4c2a-9555-dea9d8ba2901', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('948709f2-5462-45e6-bc77-f25cb94e9121', 'efc3c142-0f89-4c2a-9555-dea9d8ba2901', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('5d8001ce-8d03-4241-bfd3-4f927dbbb868', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('e386e47e-a143-4686-8e4d-4be391d088fa', '5d8001ce-8d03-4241-bfd3-4f927dbbb868', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c863392d-982a-4e1a-a355-d525bd4c68f7', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c93c75fa-c260-4262-a4b1-5d97db6cd13e', 'c863392d-982a-4e1a-a355-d525bd4c68f7', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c2009d31-2dc8-482e-a82f-06fccf6da11c', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('4ab1092f-1014-426e-953b-969347b1ae60', 'c2009d31-2dc8-482e-a82f-06fccf6da11c', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('f8f87d27-1d82-4d85-b610-17922e229dec', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ccdfd8b2-7156-4041-9860-c9e1679604f4', 'f8f87d27-1d82-4d85-b610-17922e229dec', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('4bf76975-150c-4f0e-9dae-2acdf6ea9e7f', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('aa136a36-c42d-4646-84f9-a79fe741ea03', '4bf76975-150c-4f0e-9dae-2acdf6ea9e7f', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('f3be6830-a309-49eb-8aa4-2f8ce463465f', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('b77bf934-e9d5-41bb-9611-ad322398bb13', 'f3be6830-a309-49eb-8aa4-2f8ce463465f', 'restaurant-service', 'RESTAURANT');

COMMIT;
