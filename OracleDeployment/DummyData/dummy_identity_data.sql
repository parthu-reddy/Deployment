BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('6978a067-ee93-405b-bb51-20c30f875911', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('06f520d2-f3ed-465d-a519-72d2cacd8d37', '6978a067-ee93-405b-bb51-20c30f875911', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('5aa47b29-ad92-43fc-8e6e-aed191ea3b23', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ac74cb3d-0e27-495e-ab3e-01791dc1878d', '5aa47b29-ad92-43fc-8e6e-aed191ea3b23', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('d0f244ca-dd93-4762-b718-ea2c174e0404', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('d4804a82-11d8-44cf-afcf-091c066a1969', 'd0f244ca-dd93-4762-b718-ea2c174e0404', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('aa95398d-3636-449e-8a2c-765aac0ec335', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('cc27bffa-24ee-4ed4-bba6-0d0822686af1', 'aa95398d-3636-449e-8a2c-765aac0ec335', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('4ad28e72-925e-44db-834c-dc23378932aa', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('110adc84-cacb-41ec-aa74-c4ecb38be9ed', '4ad28e72-925e-44db-834c-dc23378932aa', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('96f76f22-2326-4e16-bce3-3df7293cf0f9', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('3727122d-8de0-4e2a-8373-536bf6a941b2', '96f76f22-2326-4e16-bce3-3df7293cf0f9', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('69f5548c-9171-494d-aa48-5123850204c5', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('fbeacb7a-a510-4e28-b4fc-2306228101da', '69f5548c-9171-494d-aa48-5123850204c5', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('95e04e85-bc35-4f0a-be12-f176b2170a37', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('89afded3-c959-4a54-ac6e-28d305f2ec48', '95e04e85-bc35-4f0a-be12-f176b2170a37', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('23481a42-32cd-4b91-b656-33b3dc8fc865', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('58144f82-de72-4ef3-bf99-483937816b45', '23481a42-32cd-4b91-b656-33b3dc8fc865', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c9916f70-efe8-45f3-a838-9807b245e211', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('dff85ed7-e762-47b9-8d78-ac6bbbf9ff9f', 'c9916f70-efe8-45f3-a838-9807b245e211', 'restaurant-service', 'RESTAURANT');

COMMIT;
