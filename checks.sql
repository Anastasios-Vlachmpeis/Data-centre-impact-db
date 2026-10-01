USE data_centre_impact;

-- week 5: checks we run after loading the real data
-- most of these should give 0 rows (or 0), otherwise something went wrong

-- C1. same company name written differently (capitals / spaces), should be 0 rows
SELECT LOWER(REPLACE(company_name, ' ', '')) AS normalised_name, COUNT(*) AS variants
FROM company
GROUP BY normalised_name
HAVING COUNT(*) > 1;

-- C2. same city stored twice, should be 0 rows
SELECT LOWER(city) AS city, country, COUNT(*) AS variants
FROM location
GROUP BY LOWER(city), country
HAVING COUNT(*) > 1;

-- C3. locations that nothing uses (just to check)
SELECT COUNT(*) AS unused_locations
FROM location l
WHERE NOT EXISTS (SELECT 1 FROM data_center d WHERE d.location_id = l.location_id)
  AND NOT EXISTS (SELECT 1 FROM stakeholder s WHERE s.location_id = l.location_id);

-- C4. same company on the same street with different site names. could still be
--     duplicates, but a lot are real (Equinix AM1 and AM2 are on the same street)
SELECT c.company_name, dc.street_address, l.city, COUNT(*) AS sites,
       GROUP_CONCAT(dc.dc_name SEPARATOR ' | ') AS names
FROM data_center dc
JOIN company c ON c.company_id = dc.company_id
JOIN location l ON l.location_id = dc.location_id
WHERE dc.street_address IS NOT NULL
GROUP BY c.company_name, dc.street_address, l.city
HAVING COUNT(*) > 1
ORDER BY sites DESC;

-- C5. how many values are missing, for mock and real data
SELECT source,
       COUNT(*)                         AS sites,
       SUM(capacity_mw IS NULL)         AS missing_capacity,
       SUM(status IS NULL)              AS missing_status,
       SUM(street_address IS NULL)      AS missing_street,
       SUM(NOT EXISTS (SELECT 1 FROM environmental_impact e WHERE e.dc_id = data_center.dc_id))
                                        AS no_yearly_metrics
FROM data_center
GROUP BY source;

SELECT COUNT(*)                               AS grid_rows,
       SUM(electricity_demand_twh IS NULL)     AS missing_demand,
       SUM(carbon_intensity_g_per_kwh IS NULL) AS missing_carbon_intensity,
       SUM(renewables_share_pct IS NULL)       AS missing_renewables_share
FROM grid_electricity;

-- C6. every grid row should point to a country that exists (should be 0).
--     the country name is only in the country table and not repeated in
--     grid_electricity, that was the 2NF problem in the raw OWID file
SELECT COUNT(*) AS grid_rows_without_country
FROM grid_electricity g
LEFT JOIN country c ON c.country_code = g.country_code
WHERE c.country_code IS NULL;
