-- Data Centre Impact DB schema
-- updated in week 5 for the real data, changes are marked with "week 5:"

-- week 5: drop first so we can run the whole thing again without errors
DROP DATABASE IF EXISTS data_centre_impact;
CREATE DATABASE data_centre_impact;
USE data_centre_impact;

-- week 5: new table. before, country was just a CHAR(2) in location, but the
-- grid data (dataset B) is per country so we needed a real country table
CREATE TABLE country (
    country_code CHAR(2) PRIMARY KEY,            -- 2 letter code like NL (XK = Kosovo)
    country_name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE company (
    company_id INT AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE location (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    country CHAR(2) NOT NULL,
    UNIQUE (city, country),
    -- week 5: country is now a foreign key
    CONSTRAINT fk_location_country FOREIGN KEY (country) REFERENCES country(country_code)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE data_center (
    dc_id INT AUTO_INCREMENT PRIMARY KEY,
    -- week 5: was VARCHAR(50) UNIQUE. one real name was too long and a lot of
    -- companies just call their site 'Amsterdam', so it can't be unique anymore
    dc_name VARCHAR(150) NOT NULL,
    -- week 5: new. street + house number, can be empty
    -- (we don't store the postcode because postcode -> city would break 3NF)
    street_address VARCHAR(255) NULL,
    street_address_key VARCHAR(255) GENERATED ALWAYS AS (IFNULL(street_address, '')) STORED,
    -- week 5: can be NULL now, the real data doesn't have capacity or status
    capacity_mw NUMERIC(8,2) NULL CHECK (capacity_mw > 0),
    status VARCHAR(20) NULL CHECK (status IN ('planned', 'operational', 'decommissioned')),
    -- week 5: new. 'mock' = our own test data, 'atlas' = real data
    source VARCHAR(10) NOT NULL DEFAULT 'mock' CHECK (source IN ('mock', 'atlas')),
    company_id INT NOT NULL,
    location_id INT NOT NULL,
    -- week 5: instead of unique dc_name, a site is unique by company + place + name + street
    CONSTRAINT uq_dc_site UNIQUE (company_id, location_id, dc_name, street_address_key),
    CONSTRAINT fk_dc_company FOREIGN KEY (company_id) REFERENCES company(company_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_dc_location FOREIGN KEY (location_id) REFERENCES location(location_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE environmental_impact (
    record_id INT AUTO_INCREMENT PRIMARY KEY,
    dc_id INTEGER NOT NULL,
    year SMALLINT NOT NULL CHECK (year BETWEEN 2000 AND 2100),
    energy_mwh NUMERIC(12,2) NOT NULL CHECK (energy_mwh >= 0),
    water_m3 NUMERIC(12,2) NOT NULL CHECK (water_m3 >= 0),
    co2_tons NUMERIC(12,2) NOT NULL CHECK (co2_tons >= 0),
    UNIQUE (dc_id, year),
    INDEX idx_env_year (year),                   -- week 5: our queries filter on year a lot
    CONSTRAINT fk_env_dc
    FOREIGN KEY (dc_id) REFERENCES data_center(dc_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- week 5: new table for dataset B, one row per country per year
CREATE TABLE grid_electricity (
    country_code CHAR(2) NOT NULL,
    -- same range as environmental_impact.year, our grid data doesn't go back further than 2000 anyway
    year SMALLINT NOT NULL CHECK (year BETWEEN 2000 AND 2100),
    electricity_demand_twh NUMERIC(10,3) NULL CHECK (electricity_demand_twh >= 0),
    electricity_generation_twh NUMERIC(10,3) NULL CHECK (electricity_generation_twh >= 0),
    carbon_intensity_g_per_kwh NUMERIC(8,3) NULL CHECK (carbon_intensity_g_per_kwh >= 0),
    renewables_share_pct NUMERIC(6,3) NULL CHECK (renewables_share_pct BETWEEN 0 AND 100),
    PRIMARY KEY (country_code, year),
    INDEX idx_grid_year (year),
    CONSTRAINT fk_grid_country FOREIGN KEY (country_code) REFERENCES country(country_code)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE stakeholder (
    stakeholder_id INT AUTO_INCREMENT PRIMARY KEY,
    stakeholder_name VARCHAR(150) NOT NULL,
    stakeholder_type VARCHAR(30) NOT NULL CHECK (stakeholder_type IN ('local_resident', 'municipality', 'environmental_ngo', 'utility', 'business')),
    location_id INTEGER NOT NULL,
    CONSTRAINT fk_stakeholder_location
    FOREIGN KEY (location_id) REFERENCES location(location_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE stakeholder_impact (
    dc_id INTEGER NOT NULL,
    stakeholder_id INTEGER NOT NULL,
    impact_type VARCHAR(30) NOT NULL CHECK (impact_type IN ('financial', 'noise', 'environmental', 'regulatory', 'health')),
    severity VARCHAR(10) NOT NULL CHECK (severity IN ('low', 'medium', 'high')),
    response VARCHAR(30) NOT NULL CHECK (response IN ('none', 'complaint', 'protest', 'legal_challenge')),
    PRIMARY KEY (dc_id, stakeholder_id, impact_type),
    CONSTRAINT fk_si_dc FOREIGN KEY (dc_id) REFERENCES data_center(dc_id) ON DELETE CASCADE,
    CONSTRAINT fk_si_stakeholder
    FOREIGN KEY (stakeholder_id) REFERENCES stakeholder(stakeholder_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- week 5: view so we don't have to write the same joins every time
-- (we said views were future work in the week 4 video)
CREATE VIEW v_data_center_overview AS
SELECT dc.dc_id,
       dc.dc_name,
       c.company_name,
       dc.street_address,
       l.city,
       co.country_name,
       dc.capacity_mw,
       dc.status,
       dc.source
FROM data_center dc
JOIN company c   ON c.company_id = dc.company_id
JOIN location l  ON l.location_id = dc.location_id
JOIN country co  ON co.country_code = l.country;
