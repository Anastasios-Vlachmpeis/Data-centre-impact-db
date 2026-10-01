USE data_centre_impact;

-- CRUD example
-- week 5: we had to change this file. it used id 99, but after loading the
-- real data id 99 is already a real company, and Utrecht already exists,
-- so it gave duplicate key errors. now we use LAST_INSERT_ID() instead.
-- the old version also did SELECT * FROM data_centre_impact, which is the
-- database name and not a table, so that line never worked.

-- CREATE
INSERT INTO company (company_name) VALUES ('Demo Cloud BV');
SET @demo_company = LAST_INSERT_ID();

INSERT IGNORE INTO location (city, country) VALUES ('Utrecht', 'NL');
SET @utrecht = (SELECT location_id FROM location WHERE city = 'Utrecht' AND country = 'NL');

INSERT INTO data_center (dc_name, capacity_mw, status, company_id, location_id)
VALUES ('UTR-DEMO1', 55.00, 'planned', @demo_company, @utrecht);
SET @demo_dc = LAST_INSERT_ID();

-- READ
SELECT * FROM v_data_center_overview WHERE dc_id = @demo_dc;

-- UPDATE
UPDATE data_center SET status = 'operational' WHERE dc_id = @demo_dc;
SELECT dc_name, status FROM data_center WHERE dc_id = @demo_dc;

-- DELETE (we keep Utrecht because real data centres are in Utrecht)
DELETE FROM data_center WHERE dc_id = @demo_dc;
DELETE FROM company WHERE company_id = @demo_company;
