BEGIN;

INSERT INTO users (id, phone_number, name, email) VALUES ('da19a2b2-7314-4808-8112-af8d13ec9763', '9000000001', 'Owner of Brand 1', 'owner1@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('20da2cc2-7e6f-42e6-8264-883710bb54f6', 'da19a2b2-7314-4808-8112-af8d13ec9763', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('c854f414-dc17-445d-887f-2c8dc23224ff', '9000000002', 'Owner of Brand 2', 'owner2@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('c77a0750-0025-4f1c-99bd-857764ce48c3', 'c854f414-dc17-445d-887f-2c8dc23224ff', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1b429c28-98a1-444e-8ce5-6c472ed471b9', '9000000003', 'Owner of Brand 3', 'owner3@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('0d295c93-2d25-4524-a170-97b49668f040', '1b429c28-98a1-444e-8ce5-6c472ed471b9', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('114ebff6-1364-4d7d-91aa-a1a8fb8d5f36', '9000000004', 'Owner of Brand 4', 'owner4@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('e3dcc61b-530f-4b40-83e8-1b579788ac8a', '114ebff6-1364-4d7d-91aa-a1a8fb8d5f36', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('1b7f65b2-2b9b-4556-bbfa-26c5833540bd', '9000000005', 'Owner of Brand 5', 'owner5@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('65afc847-8694-4b80-978a-b1fd51474803', '1b7f65b2-2b9b-4556-bbfa-26c5833540bd', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('3f76eea7-4323-479d-828f-74cb965c206c', '9000000006', 'Owner of Brand 6', 'owner6@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('621db61e-2ff6-4aca-8250-172049076141', '3f76eea7-4323-479d-828f-74cb965c206c', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('29f2d02c-1c46-4e69-9147-fedc48b04e9d', '9000000007', 'Owner of Brand 7', 'owner7@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('8ea75bb3-aa59-4848-ae46-ce31b1d9c9cc', '29f2d02c-1c46-4e69-9147-fedc48b04e9d', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('f4aab5cd-b0ec-468c-94d5-7cdfd1a648d0', '9000000008', 'Owner of Brand 8', 'owner8@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('1b219d53-6296-4fca-a425-f040d85ac0ab', 'f4aab5cd-b0ec-468c-94d5-7cdfd1a648d0', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('84974bdc-094f-4743-99a0-61c443296d3b', '9000000009', 'Owner of Brand 9', 'owner9@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('3f7b5c52-926c-4e87-a86c-248e28ed29b9', '84974bdc-094f-4743-99a0-61c443296d3b', 'restaurant-service', 'RESTAURANT');
INSERT INTO users (id, phone_number, name, email) VALUES ('f2e2eeb6-fd62-4454-88a2-58372af549b7', '9000000010', 'Owner of Brand 10', 'owner10@example.com');
INSERT INTO user_roles (id, user_id, service_name, role_name) VALUES ('5f5cd1c4-0f32-4d49-98ef-2b28bc7e3fd6', 'f2e2eeb6-fd62-4454-88a2-58372af549b7', 'restaurant-service', 'RESTAURANT');

COMMIT;
