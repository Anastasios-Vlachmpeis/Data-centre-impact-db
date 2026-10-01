# Data Centre Impact DB

Repository: https://github.com/Anastasios-Vlachmpeis/Data-centre-impact-db

A MySQL database for tracking data centres, their operators, and their local impact.

The schema links companies and locations to data centres, yearly environmental metrics (energy, water, CO2), and how nearby stakeholders are affected.

A reviewer with MySQL installed can recreate the full database from the SQL files in this repo. No database dump is required.

## Contributors

Anastasios Vlachmpeis Nikita Kirillov Minseok Choi Matvei Kandalintsev

---

## Week 1: Societal problem

> **TODO:** short description of the problem + link to the week 1 file

- File: 

## Week 2: ERD and normalization

> **TODO:** add the ERD picture and the normalization report (Version 1 to 4). Also add the normal form violations we found in the real data in week 5.

- ERD: 
- Normalization report: 

## Week 3: Schema definition and constraints

### Repository layout

- `schema.sql` : database, tables, keys, and constraints
- `seed.sql` : realistic mock data
- `crud.sql` : insert, update, and delete examples
- `queries.sql` : queries
- `real_data.sql` : real-world data (week 5, made by `etl/clean_data.py`)
- `checks.sql` : data checks after loading the real data (week 5)

### How to run

1. Install MySQL and create a local user
2. Create the schema, then load the data

From a terminal, with MySQL on your PATH:

```bash
mysql -u root -p < schema.sql
mysql -u root -p data_centre_impact < seed.sql
mysql -u root -p data_centre_impact < real_data.sql
mysql -u root -p data_centre_impact < crud.sql
mysql -u root -p data_centre_impact < queries.sql
mysql -u root -p data_centre_impact < checks.sql
```

In MySQL Workbench: open each file with **File → Open SQL Script** and execute it in this order: `schema.sql`, `seed.sql`, `real_data.sql`, `crud.sql`, `queries.sql`, `checks.sql`.

### Schema

| Table | Role |
|---|---|
| `company` | Operator of one or more data centres |
| `location` | City and country |
| `data_center` | Site owned by one company, in one location |
| `environmental_impact` | Yearly energy, water, and CO2 for a site |
| `stakeholder` | Person or organisation in a location |
| `stakeholder_impact` | How a data centre affects a stakeholder |
| `country` | **TODO:** describe (new in week 5) |
| `grid_electricity` | **TODO:** describe (new in week 5) |

### Queries

`queries.sql` has 3 queries:

1. Energy, water, and CO2 totals by city for the latest year
2. Operational sites with high CO2 and high-severity stakeholder impacts
3. Year-over-year energy change per data centre

> **TODO:** add the new queries from week 5 (Q4 to Q6)

## Week 4: Stakeholder video

> **TODO:** add the video here (drag the .mp4 into the README editor on github.com, or add a YouTube link)

- Video: 

## Week 5: Real-world data

> **TODO:** short summary + link to the week 5 report

- Report: 
- Dataset A (source, publication date, license): 
- Dataset B (source, publication date, license): 
- Data cleaning (missing data, dates, duplicates, naming): 
- Schema / constraint changes: 
- Queries re-run (results + changes): 
- Normalization check (still 3NF?): 
- Limitations and future work from the video, checked again: 
