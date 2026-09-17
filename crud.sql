USE data_centre_impact;

INSERT INTO company (company_id, company_name) VALUES (99, 'Demo Cloud BV');
INSERT INTO location (location_id, city, country) VALUES (99, 'Utrecht', 'NL');
INSERT INTO data_center (dc_id, dc_name, capacity_mw, status, company_id, location_id)
VALUES (99, 'UTR-DEMO1', 55.00, 'planned', 99, 99);

UPDATE data_center SET status = 'operational' WHERE dc_id = 99;

DELETE FROM data_center WHERE dc_id = 99;
DELETE FROM company WHERE company_id = 99;
DELETE FROM location WHERE location_id = 99;