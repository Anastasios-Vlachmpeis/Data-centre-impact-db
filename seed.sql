USE data_centre_impact;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE stakeholder_impact;
TRUNCATE TABLE environmental_impact;
TRUNCATE TABLE stakeholder;
TRUNCATE TABLE data_center;
TRUNCATE TABLE location;
TRUNCATE TABLE company;
SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO company (company_id, company_name) VALUES
    (1, 'Google'),
    (2, 'Microsoft'),
    (3, 'Equinix'),
    (4, 'Digital Realty');

INSERT INTO location (location_id, city, country) VALUES
    (1, 'Amsterdam', 'NL'),
    (2, 'Rotterdam', 'NL'),
    (3, 'Groningen', 'NL'),
    (4, 'Eindhoven', 'NL');

INSERT INTO data_center (dc_id, dc_name, capacity_mw, status, company_id, location_id) VALUES
    (1,  'AMS-DC1',  200.00, 'operational', 1, 1),
    (2,  'AMS-DC2',  150.00, 'operational', 2, 1),
    (3,  'AMS-EQX1', 120.00, 'operational', 3, 1),
    (4,  'RTD-DC1',  180.00, 'operational', 1, 2),
    (5,  'RTD-MS1',   90.00, 'operational', 2, 2),
    (6,  'GRO-DC1',   80.00, 'operational', 4, 3),
    (7,  'EIN-EQX1', 110.00, 'operational', 3, 4),
    (8,  'EIN-DC1',  250.00, 'planned',     1, 4),
    (9,  'AMS-DLR1',  70.00, 'operational', 4, 1),
    (10, 'GRO-MS1',   60.00, 'planned',     2, 3);

INSERT INTO environmental_impact (dc_id, year, energy_mwh, water_m3, co2_tons) VALUES
    (1, 2022, 480000, 115000, 47000),
    (1, 2023, 500000, 120000, 45000),
    (1, 2024, 520000, 125000, 43000),
    (1, 2025, 535000, 128000, 42000),
    (2, 2022, 290000,  76000, 30000),
    (2, 2023, 300000,  80000, 28000),
    (2, 2024, 310000,  82000, 27000),
    (2, 2025, 318000,  84000, 26500),
    (3, 2023, 210000,  52000, 19000),
    (3, 2024, 225000,  55000, 18500),
    (3, 2025, 230000,  56000, 18000),
    (4, 2022, 390000,  98000, 40000),
    (4, 2023, 400000, 100000, 38000),
    (4, 2024, 420000, 105000, 37000),
    (4, 2025, 428000, 107000, 36500),
    (5, 2023, 160000,  40000, 15000),
    (5, 2024, 168000,  42000, 14500),
    (5, 2025, 172000,  43000, 14200),
    (6, 2023, 140000,  35000, 13000),
    (6, 2024, 148000,  37000, 12500),
    (6, 2025, 151000,  38000, 12200),
    (7, 2023, 195000,  48000, 17500),
    (7, 2024, 205000,  50000, 17000),
    (7, 2025, 210000,  51000, 16800),
    (9, 2024,  95000,  24000,  9000),
    (9, 2025, 102000,  25500,  8700);

INSERT INTO stakeholder (stakeholder_id, stakeholder_name, stakeholder_type, location_id) VALUES
    (1,  'Minseok',                   'local_resident',    1),
    (2,  'Nikita',                    'local_resident',    1),
    (3,  'Tasos',                     'local_resident',    1),
    (4,  'Matvei',                    'local_resident',    2),
    (5,  'Municipality Amsterdam',    'municipality',      1),
    (6,  'Municipality Rotterdam',    'municipality',      2),
    (7,  'Green NGO Rotterdam',       'environmental_ngo', 2),
    (8,  'Utility Rotterdam',         'utility',           2),
    (9,  'Groningen Residents Group', 'local_resident',    3),
    (10, 'Eindhoven Water Board',     'utility',           4),
    (11, 'Brabant Environment NGO',   'environmental_ngo', 4),
    (12, 'Amsterdam Business Park',   'business',          1);

INSERT INTO stakeholder_impact (dc_id, stakeholder_id, impact_type, severity, response) VALUES
    (1,  1,  'financial',     'high',   'protest'),
    (1,  1,  'noise',         'medium', 'complaint'),
    (1,  5,  'regulatory',    'medium', 'legal_challenge'),
    (2,  3,  'noise',         'high',   'complaint'),
    (2, 12,  'financial',     'low',    'none'),
    (3,  2,  'noise',         'low',    'none'),
    (4,  7,  'environmental', 'high',   'legal_challenge'),
    (4,  8,  'financial',     'medium', 'complaint'),
    (5,  4,  'noise',         'medium', 'complaint'),
    (5,  6,  'regulatory',    'low',    'none'),
    (6,  9,  'environmental', 'medium', 'complaint'),
    (7, 10,  'financial',     'high',   'complaint'),
    (7, 11,  'environmental', 'high',   'legal_challenge'),
    (8, 11,  'regulatory',    'medium', 'protest'),
    (9,  5,  'regulatory',    'low',    'none');
