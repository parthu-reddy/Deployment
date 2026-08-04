BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('93a7b5f3-b6bb-404e-a63e-d1bb717e3786', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('07c0ffad-0205-4391-bac9-c2c0e5e5b73d', '93a7b5f3-b6bb-404e-a63e-d1bb717e3786', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('95f217af-057d-4d10-a5c2-5aa6582cb4c7', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('9d455d4b-0cf4-4b39-91ed-5f93a736892c', '95f217af-057d-4d10-a5c2-5aa6582cb4c7', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('23c1e520-db94-42a9-8ada-476f76467559', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('779206fd-a9f6-4722-9180-0da455967c11', '23c1e520-db94-42a9-8ada-476f76467559', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('0e2056b8-421d-49fd-b665-7f6fec81422d', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0825b8e3-395d-420d-8d43-70d8364c2625', '0e2056b8-421d-49fd-b665-7f6fec81422d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('a40eb54a-77c4-4aa8-bb74-be2188ce1421', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('2dc6c226-db67-4968-bf2c-eccc57a39788', 'a40eb54a-77c4-4aa8-bb74-be2188ce1421', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('94b88dfd-60c2-4713-9f61-e859e7c20781', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1c1ba5d3-c159-4ef9-b1f9-a7c36f152a2a', '94b88dfd-60c2-4713-9f61-e859e7c20781', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('ca6f9c58-8559-4650-9479-e45e3710607a', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('76fd9cf4-ea1c-4c30-a6ff-d68876a87daa', 'ca6f9c58-8559-4650-9479-e45e3710607a', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('0848f76b-a150-475f-ab90-9e19d7c70528', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('a7a797b8-e672-4608-86d2-dfff9308f2af', '0848f76b-a150-475f-ab90-9e19d7c70528', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('2b66ea89-334b-4f32-a0f8-4d26ae6e3570', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('99c80d82-4d67-4606-917b-9821f955720d', '2b66ea89-334b-4f32-a0f8-4d26ae6e3570', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('af930767-8d45-4c6e-a357-cc9457d43a57', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('2156edeb-2fce-43af-9135-470b04652008', 'af930767-8d45-4c6e-a357-cc9457d43a57', 'restaurant-service', 'RESTAURANT');

COMMIT;
