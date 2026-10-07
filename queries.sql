USE data_centre_impact;

-- ===== week 3 queries, changed a bit in week 5 for the real data =====

-- Q1. which cities have the most data centres and the biggest footprint?
-- week 5: the old version used a normal JOIN with environmental_impact, so
-- all the real sites (they have no yearly numbers) were left out and
-- Amsterdam only had 4 data centres. with LEFT JOIN every site is counted,
-- and sites_with_metrics shows how many of them actually have numbers.
SELECT l.city,
       COUNT(*)                   AS data_centers,
       COUNT(e.dc_id)             AS sites_with_metrics,
       SUM(e.energy_mwh)          AS energy_mwh,
       SUM(e.water_m3)            AS water_m3,
       SUM(e.co2_tons)            AS co2_tons
FROM location l
JOIN data_center dc ON dc.location_id = l.location_id
LEFT JOIN environmental_impact e
       ON e.dc_id = dc.dc_id
      AND e.year = (SELECT MAX(year) FROM environmental_impact)
GROUP BY l.city
ORDER BY data_centers DESC, energy_mwh DESC
LIMIT 10;

-- Q2. operational sites with a lot of CO2 and high impact on stakeholders
-- week 5: year was fixed to 2024, now it takes the latest year like Q1.
-- the real sites have no status and no stakeholder data, so this still only
-- shows mock sites (see limitations in the report)
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
WHERE e.year = (SELECT MAX(year) FROM environmental_impact)
  AND dc.status = 'operational'
GROUP BY dc.dc_id, dc.dc_name, c.company_name, l.city, e.co2_tons
HAVING SUM(si.severity = 'high') >= 1
ORDER BY e.co2_tons DESC;

-- Q3 (Created by Nikita Kirillov)
-- Question: how much does energy use change every year for each data centre?
-- Why: it shows which sites are using more or less electricity over time. the real sites have no yearly energy numbers, so this still only uses the mock data. the query itself was not changed in week 5.
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

-- ===== new queries in week 5 that use the real data =====

-- Q4 (Created by Nikita Kirillov)
-- Question: which companies have the most data centres in the Netherlands, and in how many cities?
-- Why: dataset A is the real list of Dutch sites. this shows who owns the most of them, and whether those sites are spread over many cities or concentrated in a few.
SELECT c.company_name,
       COUNT(*)                    AS sites,
       COUNT(DISTINCT dc.location_id) AS cities,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM data_center WHERE source = 'atlas'), 1)
                                   AS pct_of_nl_sites
FROM data_center dc
JOIN company c ON c.company_id = dc.company_id
WHERE dc.source = 'atlas'
GROUP BY c.company_name
ORDER BY sites DESC
LIMIT 10;

-- Q5 (Created by MindaProgrammar)
-- Question: how much CO2 do the data centres report, compared to what the same amount of electricity would give on the dutch grid?
-- Why: companies report low CO2 because they say they use green energy. this shows how big the difference is, so people can question those numbers.
-- tonnes = MWh * g/kWh / 1000
SELECT dc.dc_name,
       e.year,
       e.energy_mwh,
       e.co2_tons                                              AS reported_co2_t,
       g.carbon_intensity_g_per_kwh                            AS grid_g_per_kwh,
       ROUND(e.energy_mwh * g.carbon_intensity_g_per_kwh / 1000, 0) AS grid_based_co2_t,
       -- NULLIF here because a 0 carbon_intensity or 0 energy_mwh would
       -- otherwise make this a division by zero
       ROUND(100.0 * e.co2_tons
             / NULLIF(e.energy_mwh * g.carbon_intensity_g_per_kwh / 1000, 0), 1) AS reported_pct_of_grid
FROM environmental_impact e
JOIN data_center dc ON dc.dc_id = e.dc_id
JOIN location l ON l.location_id = dc.location_id
LEFT JOIN grid_electricity g ON g.country_code = l.country AND g.year = e.year
WHERE e.year = (SELECT MAX(year) FROM environmental_impact)
ORDER BY grid_based_co2_t DESC;

-- Q6 (Created by MinDaProgrammar)
-- Question: how clean is dutch electricity compared to other countries in europe?
-- Why: more data centres means more electricity use. if the dutch grid is dirtier than most of europe, building more of them here causes more CO2.
-- rank 1 = cleanest country
SELECT year, carbon_intensity_g_per_kwh, renewables_share_pct, rank_in_europe, countries_ranked
FROM (
    SELECT country_code,
           year,
           carbon_intensity_g_per_kwh,
           renewables_share_pct,
           RANK()  OVER (PARTITION BY year ORDER BY carbon_intensity_g_per_kwh) AS rank_in_europe,
           COUNT(*) OVER (PARTITION BY year)                                   AS countries_ranked
    FROM grid_electricity
    WHERE carbon_intensity_g_per_kwh IS NOT NULL
) ranked
WHERE country_code = 'NL' AND year >= 2015
ORDER BY year;

-- Q7 (Created by Anastasios Vlachmpeis)
-- Question: is dutch electricity demand growing, and does generation keep up?
-- Why: data centres use a lot of electricity, so if demand grows faster than it's generation, 
-- homes and other users get less of the remaining electricity.

SELECT year,
       electricity_demand_twh,
       electricity_generation_twh,
       ROUND(electricity_demand_twh - electricity_generation_twh, 3) AS demand_gap_twh,
       LAG(electricity_demand_twh) OVER (ORDER BY year) AS prev_demand_twh,
       ROUND( 100.0 * ( electricity_demand_twh - LAG(electricity_demand_twh) OVER (ORDER BY year)) / NULLIF(LAG(electricity_demand_twh) OVER (ORDER BY year), 0), 1)
       AS demand_pct_change,
       carbon_intensity_g_per_kwh,
       renewables_share_pct
FROM grid_electricity
WHERE country_code = 'NL'
  AND year >= 2015
  AND electricity_demand_twh IS NOT NULL
ORDER BY year;


-- Q8 (Created by Anastasios Vlachmpeis)
-- Question: for companies with several dutch sites, how many of those sites are in the same city?
-- Why: If a company puts most of its sites in one city, that city takes more of the extra electricity use.

SELECT c.company_name,
       SUM(city_counts.sites_in_city) AS sites,
       COUNT(*) AS cities,
       MAX(city_counts.sites_in_city) AS sites_in_biggest_city,
       ROUND(100.0 * MAX(city_counts.sites_in_city) / SUM(city_counts.sites_in_city), 1) AS pct_in_biggest_city
FROM (
    SELECT company_id, location_id, COUNT(*) AS sites_in_city
    FROM data_center
    WHERE source = 'atlas'
    GROUP BY company_id, location_id
) city_counts
JOIN company c ON c.company_id = city_counts.company_id
GROUP BY c.company_name
HAVING SUM(city_counts.sites_in_city) >= 3
ORDER BY pct_in_biggest_city DESC, sites DESC
LIMIT 10;

-- Q9 (Created by Matvei Kandalintsev)
-- Question: which cities had the strongest pushback from stakeholders (protests or legal challenges)?
-- Why: this is the local-cost side of our problem, not just co2/energy numbers. a city with few
-- data centres but a lot of protests says more about local impact than the environmental totals do.
SELECT l.city,
       COUNT(*) AS impact_records,
       SUM(si.response = 'protest') AS protests,
       SUM(si.response = 'legal_challenge') AS legal_challenges,
       SUM(si.severity = 'high') AS high_severity_cases
FROM stakeholder_impact si
JOIN data_center dc ON dc.dc_id = si.dc_id
JOIN location l ON l.location_id = dc.location_id
GROUP BY l.city
HAVING SUM(si.response IN ('protest', 'legal_challenge')) >= 1
ORDER BY legal_challenges DESC, protests DESC;

-- Q10 (Created by Matvei Kandalintsev)
-- Question: which companies use the most water per MWh at their operational sites?
-- Why: water use is one of the local complaints in our societal problem, and energy alone doesn't
-- show that, two companies can use the same electricity but very different amounts of water.
SELECT c.company_name,
       COUNT(DISTINCT dc.dc_id) AS sites_with_data,
       SUM(e.water_m3) AS total_water_m3,
       SUM(e.energy_mwh) AS total_energy_mwh,
       ROUND(SUM(e.water_m3) / SUM(e.energy_mwh), 2) AS water_m3_per_mwh
FROM data_center dc
JOIN company c ON c.company_id = dc.company_id
JOIN environmental_impact e ON e.dc_id = dc.dc_id
WHERE dc.status = 'operational'
  AND e.year = (SELECT MAX(year) FROM environmental_impact)
GROUP BY c.company_name
HAVING SUM(e.energy_mwh) > 0
ORDER BY water_m3_per_mwh DESC;