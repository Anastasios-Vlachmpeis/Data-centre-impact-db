USE data_centre_impact;

-- Energy, water, and co2 by city for the last recorded year
SELECT l.city,
       COUNT(DISTINCT dc.dc_id) AS data_centers,
       SUM(e.energy_mwh) AS energy_mwh,
       SUM(e.water_m3) AS water_m3,
       SUM(e.co2_tons) AS co2_tons
FROM location l
JOIN data_center dc ON dc.location_id = l.location_id
JOIN environmental_impact e ON e.dc_id = dc.dc_id
WHERE e.year = (SELECT MAX(year) FROM environmental_impact)
GROUP BY l.city
HAVING SUM(e.energy_mwh) > 0
ORDER BY energy_mwh DESC;

-- Operational data centres with large footprint and high local pushback
SELECT dc.dc_name,
       c.company_name,
       l.city,
       e.co2_tons,
       SUM(si.severity = 'high') AS high_impacts,
       GROUP_CONCAT(DISTINCT si.impact_type ORDER BY si.impact_type SEPARATOR ', ') AS impact_types
FROM data_center dc
JOIN company c ON c.company_id = dc.company_id
JOIN location l ON l.location_id = dc.location_id
JOIN environmental_impact e ON e.dc_id = dc.dc_id
JOIN stakeholder_impact si ON si.dc_id = dc.dc_id
WHERE e.year = 2024
  AND dc.status = 'operational'
GROUP BY dc.dc_name, c.company_name, l.city, e.co2_tons
HAVING SUM(si.severity = 'high') >= 1
ORDER BY e.co2_tons DESC;

-- YOY energy change per data centre
SELECT dc.dc_name,
       e.year,
       e.energy_mwh,
       LAG(e.energy_mwh) OVER (PARTITION BY dc.dc_id ORDER BY e.year) AS prev_year_mwh,
       ROUND(
           100.0 * (
               e.energy_mwh - LAG(e.energy_mwh) OVER (PARTITION BY dc.dc_id ORDER BY e.year)
           ) / NULLIF(LAG(e.energy_mwh) OVER (PARTITION BY dc.dc_id ORDER BY e.year), 0), 1
       ) AS pct_change
FROM environmental_impact e
JOIN data_center dc ON dc.dc_id = e.dc_id
ORDER BY dc.dc_name, e.year;