BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('3e86b680-5e33-490e-99f0-bcbbcd2488d2', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('4cd065e8-b52c-471f-ad13-db6436cd3dd0', '3e86b680-5e33-490e-99f0-bcbbcd2488d2', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('2426f4ae-ed6d-4c56-8c98-f31dc4267d94', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1d27414b-3c28-4c9d-ab68-13cc158b8d65', '2426f4ae-ed6d-4c56-8c98-f31dc4267d94', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('939a77d6-0e65-482c-a196-ea0b0d5bda83', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('916c9d80-2eb0-420b-95ee-15c4bff7d0a4', '939a77d6-0e65-482c-a196-ea0b0d5bda83', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1b472e77-5d28-45fc-ad73-4cd2c9ad2d2f', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('04ecb6cf-afff-4133-83d6-3992f35c154e', '1b472e77-5d28-45fc-ad73-4cd2c9ad2d2f', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('0814f0e4-e800-4f0c-ac65-45afb8c521d3', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('e08dae90-0b1c-4581-af5c-bcc191596d08', '0814f0e4-e800-4f0c-ac65-45afb8c521d3', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('55bfc33f-3b5b-4a53-a5e3-2aecce2bf8b6', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('405d3597-cd6d-4f27-a15f-ec361564a4c6', '55bfc33f-3b5b-4a53-a5e3-2aecce2bf8b6', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('3ea8f7b7-8d30-493f-8c03-5f0917e00dcd', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('03ecc0cb-fd3c-49b9-bcac-ed7ece18ca3d', '3ea8f7b7-8d30-493f-8c03-5f0917e00dcd', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('a7cc6889-ca73-414f-9850-e735b76b7b9e', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1ef61ca1-9563-4fc1-9aac-645619d9f157', 'a7cc6889-ca73-414f-9850-e735b76b7b9e', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('e24ba39d-1125-4f14-83e8-cd323798a97b', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('b3f245e7-2a27-4453-a5a8-c2bee3703bcc', 'e24ba39d-1125-4f14-83e8-cd323798a97b', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('ebbfb578-4652-4cbc-bb17-5494ca7506cc', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d67894c2-c438-4c6c-a0a3-7e616cfb6b89', 'ebbfb578-4652-4cbc-bb17-5494ca7506cc', 'restaurant-service', 'RESTAURANT');

COMMIT;
