# Week 5 – Testing our design against real-world data

Until week 4, our database only held mock data (4 companies, 4 cities, 10 data centres). This week we loaded two open, real datasets into it, fixed what broke, and checked whether our queries still answer the stakeholder questions.

Everything in this report can be reproduced with:

```bash
python etl/clean_data.py                                   # raw CSV -> clean CSV + real_data.sql
mysql -u root -p < schema.sql
mysql -u root -p data_centre_impact < seed.sql            # week 3 mock data
mysql -u root -p data_centre_impact < real_data.sql       # week 5 real data
mysql -u root -p data_centre_impact < queries.sql
mysql -u root -p data_centre_impact < checks.sql          # data-quality / normalisation checks
```

---

## 1. The two datasets

| | Dataset A – data centre locations | Dataset B – national electricity grid |
|---|---|---|
| Name | ATLAS / Global Data Center Map | Our World in Data – Energy dataset |
| Publisher | Ringmast4r (GitHub) | Our World in Data (OWID); electricity figures from Ember |
| URL | https://github.com/Ringmast4r/Global-Data-Center-Map | https://github.com/owid/energy-data |
| Version we used | commit `7c1c6f3`, published 16-09-2026 | commit `7e387a1`, published 27-04-2026 (Ember electricity update) |
| Licence | Attribution licence: free to use, copy, publish and build on, credit required (see note below) | Creative Commons BY 4.0 |
| Access | Public download, no registration or payment | Public download, no registration or payment |
| File used | `datacenters.csv` | `owid-energy-data.csv` (+ codebook) |
| Raw rows we took | 448 (country = Netherlands / Netherlands Antilles) | 7,636 (all countries and regions, year ≥ 2000) |
| Clean rows loaded | **397 data centres**, 181 companies, 102 cities | **1,030 country-year rows**, 40 European countries, 2000–2025 |
| Fills our tables | `company`, `location`, `data_center` | `country`, `grid_electricity` (new) |

Raw extracts are in `data/raw/`, the cleaned files in `data/clean/`.

**Attribution.** Data centres © Ringmast4r – Global-Data-Center-Map, https://github.com/Ringmast4r/Global-Data-Center-Map. Electricity data: Our World in Data, based on Ember – Yearly Electricity Data (2026), CC BY 4.0.

**Note on the licence of A.** The ATLAS licence is not a Creative Commons licence but a custom one. It lets anyone use, copy, publish and build on the data for free, as long as the source is credited and nobody claims they made it. In practice this is the same as CC BY, so we treat it as open data and credit it above. The author says the data was put together from other open sources and that it is not checked ground truth.

**Why these two are complementary (A ⊈ B, B ⊈ A).**
Dataset A describes *facilities*: who runs which data centre, and where. Dataset B describes *national electricity grids*: how much electricity a country uses and how clean it is each year. They overlap only on the Netherlands (the country of every row in A is one of the 40 countries in B). Neither is a subset of the other: A has no energy figures, and B has no facilities. Together they answer a question neither can answer alone: *how much CO2 would the electricity used by Dutch data centres cause on the Dutch grid?* (Q5).

A also overlaps with our mock data: all 4 mock companies (Google, Microsoft, Equinix, Digital Realty) and all 4 mock cities (Amsterdam, Rotterdam, Groningen, Eindhoven) appear in the real data. They were matched to the existing rows instead of being stored twice (see §4.4).

---

## 2. How the data is integrated

```
data/raw/*.csv ──> etl/clean_data.py ──> data/clean/*.csv
                                     └─> real_data.sql ──> MySQL
```

1. `etl/clean_data.py` (Python, standard library only) does all the cleaning and writes a log of how many rows each step touched (`data/clean/cleaning_log.md`).
2. It then generates `real_data.sql`, which:
   - runs inside **one transaction** (`START TRANSACTION … COMMIT`), so if one insert fails, nothing is loaded;
   - loads the cleaned but still flat data centre rows into a temporary **staging table**;
   - puts them into normalised form with `INSERT … SELECT DISTINCT`: each company and each city is stored once, and `data_center` only holds foreign keys to them;
   - loads the grid data into `country` and `grid_electricity`.

Because foreign keys are looked up by name (`JOIN company c ON c.company_name = s.company_name`) and not written as hard-coded ids, the real data links up with the mock data automatically.

---

## 3. Schema and constraint violations, and what we changed

We first tried to load the cleaned data into the **unchanged week 3 schema**. Results:

| Error in week 3 schema | Rows | Cause | Change in `schema.sql` |
|---|---|---|---|
| `Column 'capacity_mw' cannot be null` | 396 of 397 | Neither dataset reports capacity (MW) or status | `capacity_mw` and `status` may now be `NULL`. `CHECK (capacity_mw > 0)` still applies when a value is given |
| `Duplicate entry … for key 'data_center.dc_name'` | 64 | Real names are not unique: 'Amsterdam' is used as a site name by many operators | Dropped `UNIQUE(dc_name)`. A site is now identified by `UNIQUE(company_id, location_id, dc_name, street_address)` |
| `Data too long for column 'dc_name'` | 1 | Longest real name is 52 characters (limit was 50) | `VARCHAR(50)` → `VARCHAR(150)` |
| `Data too long for column 'country'` | 199 (test: all 2024 rows) | OWID uses 3-letter ISO codes (`NLD`), our column is `CHAR(2)` | Codes converted to 2 letters in the ETL. New `country` table; `location.country` is now a foreign key |
| No table for dataset B | – | Grid data belongs to a (country, year), not to a data centre | New table `grid_electricity`, PK `(country_code, year)` |

Other changes:

- **`street_address`** (nullable) added to `data_center`. Without it we could not tell two sites of the same operator in the same city apart, or find duplicates.
- **`source`** (`'mock'` / `'atlas'`) added so every row shows where it came from. This matters because our environmental and stakeholder figures are still mock data.
- **Indexes** on `environmental_impact(year)` and `grid_electricity(year)`, and a **view** `v_data_center_overview`. Both were listed as future work in our week 4 video (§7).
- **`crud.sql` fixed.** It used hard-coded ids (99) that are now taken by real rows. It also inserted 'Utrecht', which now already exists, and selected from a table that never existed (`data_centre_impact`). It now uses `LAST_INSERT_ID()`.
- `DROP DATABASE IF EXISTS` at the top of `schema.sql`, so the build can be re-run.

All constraints that still exist were kept and pass. Every `CHECK` passes for the 1,030 grid rows (e.g. `renewables_share_pct BETWEEN 0 AND 100`), and `checks.sql` finds 0 orphan rows.

---

## 4. Data cleaning and transformation

The counts come from `data/clean/cleaning_log.md`.

### 4.1 How is missing data reported?

| Dataset | How the source shows "missing" | What we did |
|---|---|---|
| A | Empty strings in `city` (150 of 448 rows) and `state`; one row with an empty address; the placeholder `tbc` ("to be confirmed") in 11 addresses; capacity, status and opening year are **not in the dataset at all** | Recovered the city from the address where possible (see 4.4). `tbc` and empty values become SQL `NULL`. Capacity and status stay `NULL`. We do **not** put in a fake value like 0 or 'unknown', so queries can tell "unknown" apart from a real value. 1 row had no recoverable city and was dropped (a location is required). |
| B | Empty cells (e.g. 1,608 of 7,636 raw rows have no `electricity_demand`, often in early years or small countries) | Empty → `NULL`. 2 rows with *every* metric empty were dropped. After filtering to Europe 2000–2025 no other values were missing. Coverage is still uneven: for 2025 only 37 of 40 countries have data (Albania, Iceland and Ukraine are missing), and Montenegro starts in 2005. |

### 4.2 How are dates formatted?

- **A has no dates at all.** No opening year, no "last updated" per row. We cannot tell whether a site is planned, running or closed, which is why `status` stays `NULL`. The only date is the repository version (16-09-2026), recorded in §1.
- **B uses a plain 4-digit `year`** (integer). That matches our `SMALLINT year` columns, so no conversion was needed. Our week 2 ERD listed `year` as `DATE` while the schema used `SMALLINT`. The updated ERD now says `SMALLINT` (see the week 2 report).
- OWID values are *annual* totals/averages, so they can only be joined to our yearly `environmental_impact` rows on `year`.

### 4.3 Are there duplicate records?

| Type of duplicate | Rows | How we handled it |
|---|---|---|
| A: fully identical rows | 1 | Removed |
| A: same company + name + street + city (after cleaning) | 4 | Removed |
| A: **same building under two naming conventions**, e.g. `Equinix AM1` and `AM1 Amsterdam IBX Data Center` (both Luttenbergweg 4), `Dataplace Utrecht` and `Utrecht` | 37 | Merged. Two rows at the same company + street + city count as one site if their site codes match (AM1 = AM1), or if one name adds nothing new. Different codes (AM1 vs AM2, DC1 vs DC2) are kept as separate buildings. We kept the most descriptive name. |
| B: duplicate (country, year) | 0 | Checked. `PRIMARY KEY (country_code, year)` would reject them anyway |

**Duplicates we could not remove.** `checks.sql` (C4) still lists 12 addresses with more than one site of the same operator. Most are real separate buildings on one campus (Equinix AM1/AM2, BIT-2A…2D). A few are probably duplicates we cannot prove: for example, Google Eemshaven appears under three addresses. We kept these and list them as a limitation.

### 4.4 Are there inconsistent naming conventions?

| Problem | Example (raw) | Clean |
|---|---|---|
| Legal suffixes and spelling of company names | `Bytesnet BV` / `Bytesnet`, `Global-e Datacenter bv` / `…BV` | Suffixes (BV, B.V., N.V., GmbH, Ltd, Inc) removed → `Bytesnet` |
| Same company, different names | `Digital Realty` / `Digital Realty Trust`, `NorthC` / `NorthC Datacenters`, `Microsoft` / `Microsoft Azure`, 3 × `Serverius …` | Alias table in the ETL, 89 rows renamed. `Microsoft Azure` → `Microsoft` and `Digital Realty Trust` → `Digital Realty` also link them to our mock companies |
| Rebrands | `CenturyLink` → `Lumen` (2020) | Mapped to the current name |
| Two address formats | `Lakenblekerstraat 13 1431 GE Aalsmeer Netherlands` vs `Kloosterweg 1, 6412 CN Heerlen, The Netherlands` | Parser finds the Dutch postcode (`1234 AB`) and splits street / city. It also works without the postcode letters (`1165 Haarlemmerliede`) |
| Country written in two languages | `Netherlands`, `The Netherlands`, `Nederland` (`Ede Nederland`) | Removed from the city. The country is stored once as `NL` |
| Wrong values in `city` | postcode letters (`BV`, `NR`, `TA`), a phone number (`877.843.7627`), half of a name (`Haag`, `Rijn`, `Meer`), `Gemert)` | 187 rows: city taken from the address instead of the `city` column |
| Typos and two names for one city | `Amerfoort`, `Den Bosch` vs `'s-Hertogenbosch`, `AmsterdamAmsterdam-Zuidoost` | Fix table → `Amersfoort`, `'s-Hertogenbosch`, `Amsterdam` |
| Country codes | OWID `NLD` (ISO alpha-3) vs our `NL` (alpha-2); Kosovo has **no** ISO code in OWID | Converted to alpha-2. Kosovo mapped by name to `XK` |

### 4.5 Other problems

- **Rows outside the scope.** 8 rows labelled "Netherlands" are in Curaçao or Sint Maarten (separate countries in the Caribbean). They were removed, because our project is about Dutch communities in Europe.
- **Wrong geocoding.** 25 Dutch rows had a US or Canadian state (`Nebraska`, `Alberta`). The Netherlands has no states, so the column was dropped.
- **Invisible characters.** A non-breaking space in `Equinix AM1` would have made it a different string from `Equinix AM1`. All text is Unicode-normalised.
- **E-mail and phone numbers inside addresses** (`… info@nxtvn.com`). Removed before parsing.
- **Aggregates mixed with countries in B.** 2,061 rows are regions such as `World`, `Europe`, `EU (Ember)` or `High-income countries`. They have no `iso_code` and were removed. One catch: Kosovo *also* has no `iso_code`, so the naive filter dropped a real country. We noticed this because we expected 40 countries and got 39.

---

## 5. Is the database still in 3NF?

### 5.1 Normal-form violations in the raw data

Neither raw file is normalised. This is what we found (also added to our week 2 report, see `docs/week2/normalisation_report.md`, Version 5):

| Raw file | Violation | Example | Fixed by |
|---|---|---|---|
| A | **1NF**: `address` is not atomic. Street, postcode, city and country are in one cell | `Kloosterweg 1, 6412 CN Heerlen, The Netherlands` | Split into `street_address` + `location` |
| A | **3NF**: `company` repeated on every row (Alticom 24×, Equinix 23×). A company's name depends on the company, not on the site | renaming a company means changing 24 rows | Stored once in `company`. `data_center.company_id` is an FK |
| A | **3NF**: `site → city → country`, a transitive dependency | `country` repeated on all 448 rows | `location` and `country` tables |
| B | **2NF**: key is `(iso_code, year)`, but `country` (the name) depends only on `iso_code` | `Netherlands` stored 26 times | `country` table; `grid_electricity` only keeps `country_code` |
| B | Different kinds of things in one table: countries and regions share rows and columns | `World`, `Europe (EI)` next to `Netherlands` | Regions removed |

### 5.2 Checking the final schema

- `country(country_code → country_name)`: one key, one attribute. ✔
- `location(location_id → city, country)`, with `(city, country)` unique. `country` is an FK, and the country name lives only in `country`. ✔
- `data_center(dc_id → dc_name, street_address, capacity_mw, status, source, company_id, location_id)`: none of these determines another non-key column. **Postcode deliberately not stored.** In the Netherlands a postcode determines the city, so storing it next to `location_id` would bring back a transitive dependency (`dc_id → postcode → city`). ✔
- `grid_electricity((country_code, year) → demand, generation, carbon_intensity, renewables_share)`: every column depends on the whole key. No country name is stored here (the 2NF problem above). ✔
- **Derived values are not stored.** The grid-based CO2 estimate (energy × carbon intensity) is computed in Q5, not saved in a column, so it can never go out of sync with the numbers it comes from.
- `checks.sql` confirms there are no companies or cities stored twice under different spelling or case (C1, C2 → 0 rows), no orphan locations (C3), and no grid rows without a country (C6).

**Conclusion.** The database with real data is in 3NF. The real data was inserted in normalised form: the staging table is flat, but only the normalised tables are kept.

---

## 6. Re-running the week 3 queries

### Q1 – Which cities carry the biggest data-centre burden?

Running the **week 3 version unchanged** on the new database gave exactly the same result as with mock data only:

| city | data_centers | energy_mwh |
|---|---|---|
| Amsterdam | **4** | 1,185,000 |
| Rotterdam | 2 | 600,000 |
| Eindhoven | 1 | 210,000 |
| Groningen | 1 | 151,000 |

That is **not what we expected**. The query `INNER JOIN`s on `environmental_impact`, and none of the 397 real sites has yearly metrics, so they were silently left out. Amsterdam really has 95 sites, not 4.

**Adapted** (`LEFT JOIN`, count every site, show how many report metrics):

| city | data_centers | sites_with_metrics | energy_mwh | co2_tons |
|---|---|---|---|---|
| Amsterdam | 95 | 4 | 1,185,000 | 95,200 |
| Schiphol-Rijk | 27 | 0 | NULL | NULL |
| Rotterdam | 20 | 2 | 600,000 | 50,700 |
| Groningen | 15 | 1 | 151,000 | 12,200 |
| Eindhoven | 14 | 1 | 210,000 | 16,800 |
| Almere | 13 | 0 | NULL | NULL |
| … | | | | |

The answer changes. Schiphol-Rijk (in Haarlemmermeer) is the 2nd biggest data-centre location in the Netherlands, and it was not even in our mock data. The query is now honest about coverage: only 8 of 407 sites have energy figures.

### Q2 – Operational sites with a big footprint and high local pushback

Week 3 version: the year was hard-coded to `2024`. **Adapted** to use the latest year like Q1. Result: the same 4 mock sites (AMS-DC1 42,000 t, RTD-DC1 36,500 t, AMS-DC2 26,500 t, EIN-EQX1 16,800 t).

This query **cannot use the real data yet.** Real sites have `status = NULL` (unknown) and no stakeholder records. We did not change the filter to `status IS NULL OR …`, because that would label sites as "operational" without evidence.

### Q3 – Year-over-year energy change

Unchanged, same results (e.g. AMS-DC1 +4.2 %, +4.0 %, +2.9 %). Real sites have no yearly energy data, so they do not appear. That is correct, not a bug.

### New queries using the real data

**Q4 – Which operators dominate?** (dataset A)

| company | sites | cities | % of NL sites |
|---|---|---|---|
| Alticom | 24 | 24 | 6.0 |
| Digital Realty | 18 | 7 | 4.5 |
| Cellnext | 16 | 15 | 4.0 |
| NorthC | 14 | 9 | 3.5 |
| Equinix | 11 | 3 | 2.8 |

No single operator dominates by number of sites. Some are spread out (Alticom: 24 small sites in 24 places), others are concentrated (Equinix: 11 sites in 3 cities). For a municipality this is the difference between many small neighbours and a few very large ones. We cannot rank by *size* because capacity is missing (§7).

**Q5 – Reported CO2 vs. the Dutch grid** (mock metrics + dataset B)

| site | energy 2025 (MWh) | reported CO2 (t) | grid g/kWh | CO2 on the grid (t) | reported as % of grid |
|---|---|---|---|---|---|
| AMS-DC1 | 535,000 | 42,000 | 253.6 | 135,655 | 31 % |
| RTD-DC1 | 428,000 | 36,500 | 253.6 | 108,524 | 34 % |
| … | | | | | ~31–34 % for every site |

If these sites used average Dutch grid electricity, they would emit about **3 times** what our (mock) data reports. A real operator can only report that low a number if it buys around two-thirds of its power as renewable contracts. This gives stakeholders a concrete question to ask an operator. It also shows that the co2 numbers we invented in week 3 were never checked against anything real.

**Q6 – How clean is the Dutch grid compared with Europe?** (dataset B)

| year | g CO2/kWh | renewables % | rank (1 = cleanest) |
|---|---|---|---|
| 2015 | 551 | 12.6 | 29 of 40 |
| 2020 | 343 | 26.8 | 25 of 40 |
| 2025 | 254 | 51.2 | 20 of 37 |

The carbon intensity of Dutch electricity has more than halved in 10 years, but the Netherlands is still only in the middle of Europe. The drop to 37 countries in 2025 is caused by missing data, not by countries leaving (§4.1).

---

## 7. Our week 4 limitations and future work, checked against the real data

| What we said in the video | Status after week 5 |
|---|---|
| "Data is simulated" | **Partly solved.** Sites, operators and places are now real (397 sites). Energy, water, CO2 and stakeholder data are still mock: no open dataset reports them per site. The `source` column makes this visible in every query. |
| "Only 4 cities and 10 data centres" | **Solved.** 102 places, 181 operators, 407 sites. |
| "Stakeholder impact has no scale (petition counts, legal outcomes)" | Still open. The real data has no stakeholder information at all. |
| "No health / air-quality data" | Still open. |
| "Stakeholder list narrower than reality (grid operators, utilities…)" | Partly: we now have national grid data, but no stakeholder records for grid operators. |
| Future work: **indexing** | **Done:** indexes on `year` in `environmental_impact` and `grid_electricity` (FK columns are indexed by InnoDB automatically). |
| Future work: **transactions** | **Done:** `real_data.sql` loads everything in one transaction. |
| Future work: **views** | **Done:** `v_data_center_overview`. |
| Future work: **partitioning** | Not needed yet: `environmental_impact` has 26 rows. MySQL also does not allow partitioning on tables with foreign keys, so this would need a design change. |
| Future work: **stored procedures** | Not done. The ETL script handles inserts for now. |

**New limitations we only found with real data:**

1. **Capacity and status are missing for every real site.** Q2 and any "biggest data centre" question cannot use the real data. This is the most important gap.
2. **"City" is sometimes a village or business park, not a municipality** (Schiphol-Rijk, Oude Meer and Hoofddorp are all in Haarlemmermeer). Stakeholders like a municipal council think in municipalities, so our city totals can split one municipality's burden into several rows.
3. **Some duplicates may remain** (§4.3), so the site counts may be a little too high.
4. **Grid carbon intensity is a national average and lifecycle-based** (it includes building power plants). It is an estimate, not a site's real emissions.
5. **ATLAS is compiled by one person and not checked.** It is useful for an overview, but not good enough to use as evidence against a specific operator.

## 8. Do the queries give meaningful results? What needs updating?

| Query | Meaningful now? | Needed update |
|---|---|---|
| Q1 | Yes, after the fix. The week 3 version was **misleading** (it showed 8 of 407 sites) | Done: `LEFT JOIN` + coverage column |
| Q2 | Only for mock sites | Needs real status + stakeholder data. Hard-coded year removed |
| Q3 | Only for mock sites | Needs real yearly energy per site |
| Q4 (new) | Yes, fully real data | – |
| Q5 (new) | Yes as a check; the reported values are still mock | Real per-site energy (e.g. from operators' sustainability reports) |
| Q6 (new) | Yes, fully real data | – |

**Next steps we would take:**

1. Add a municipality level to `location` (city → municipality, using CBS open data) so results match how councils are organised.
2. Add capacity and status for the largest sites from public permit and planning documents.
3. Replace the mock yearly metrics wherever operators publish per-site figures. For example, Google's environmental report gives water use per data-centre campus, including Eemshaven.
