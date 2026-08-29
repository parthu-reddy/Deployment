BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('5190ac13-2b04-4699-9f3e-95a403b533d9', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('ffeb73c0-9a76-4567-9e2b-372445d4e89c', '5190ac13-2b04-4699-9f3e-95a403b533d9', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('94ef5803-3495-43b9-8893-5a7776709787', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('29b555bc-08e7-4104-82a4-06ddac027f47', '94ef5803-3495-43b9-8893-5a7776709787', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('79178792-d7e2-408b-8eff-bb34ffe1523a', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c1623187-0e5f-4b45-8a6f-afdbc8da99cf', '79178792-d7e2-408b-8eff-bb34ffe1523a', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('2b4a4de5-bab2-4d78-ab52-bfefbe06c0a1', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('46ffd2d7-d4a3-4929-ac87-e4982f9589a0', '2b4a4de5-bab2-4d78-ab52-bfefbe06c0a1', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('25eba45f-8ab6-4d05-86e4-fc5b9fa22ca2', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('6b6ba44c-15f4-4c33-8413-a6c0304e2fc2', '25eba45f-8ab6-4d05-86e4-fc5b9fa22ca2', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('e8eaeac5-6b83-42ff-8bb4-f8f90974ca38', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('518b0288-b5e8-4c56-ba95-91dd3bb12d76', 'e8eaeac5-6b83-42ff-8bb4-f8f90974ca38', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('afcd7f93-e464-40ac-aee4-3e7806ea36fe', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('f334427e-d70c-4734-a463-3f59f5428080', 'afcd7f93-e464-40ac-aee4-3e7806ea36fe', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('032a1733-5bfc-44a6-bc2a-879f94308dee', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('948c4732-e1a3-4883-b56d-d215b511b563', '032a1733-5bfc-44a6-bc2a-879f94308dee', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('66dba4b3-f686-465d-9447-8b49660566de', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('a44af5c3-e127-433b-b7ec-8b1ed05c47db', '66dba4b3-f686-465d-9447-8b49660566de', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('026dd6d5-4206-4caa-8679-391a284be332', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c51dd88a-2e49-446c-896e-e8c16579b53a', '026dd6d5-4206-4caa-8679-391a284be332', 'restaurant-service', 'RESTAURANT');

COMMIT;
