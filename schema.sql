CREATE DATABASE data_centre_impact;
USE data_centre_impact;

CREATE TABLE company (
    company_id INT AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE location (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    country CHAR(2) NOT NULL,
    UNIQUE (city, country)
) ENGINE=InnoDB;

CREATE TABLE data_center (
    dc_id INT AUTO_INCREMENT PRIMARY KEY,
    dc_name VARCHAR(50) NOT NULL UNIQUE,
    capacity_mw NUMERIC(8,2) NOT NULL CHECK (capacity_mw > 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('planned', 'operational', 'decommissioned')),
    company_id INT NOT NULL, location_id INT NOT NULL,
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
    CONSTRAINT fk_env_dc
    FOREIGN KEY (dc_id) REFERENCES data_center(dc_id) ON DELETE CASCADE
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