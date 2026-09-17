# Data Centre Impact DB

A MySQL database for tracking data centres, their operators, and their local impact.

The schema links companies and locations to data centres, yearly environmental metrics (energy, water, CO2), and how nearby stakeholders are affected.

A reviewer with MySQL installed can recreate the full database from the SQL files in this repo. No database dump is required.

## Repository layout

- `schema.sql` : database, tables, keys, and constraints
- `seed.sql` : realistic mock data
- `crud.sql` : insert, update, and delete examples
- `queries.sql` : queries

## How to run

1. Install MySQL and create a local user
2. Create the schema, then load the data

From a terminal, with MySQL on your PATH:

```bash
mysql -u root -p < schema.sql
mysql -u root -p data_centre_impact < seed.sql
mysql -u root -p data_centre_impact < crud.sql
mysql -u root -p data_centre_impact < queries.sql
```

In MySQL Workbench: open each file with **File → Open SQL Script** and execute it in this order: `schema.sql`, `seed.sql`, `crud.sql`, `queries.sql`.

## Schema

| Table | Role |
|---|---|
| `company` | Operator of one or more data centres |
| `location` | City and country |
| `data_center` | Site owned by one company, in one location |
| `environmental_impact` | Yearly energy, water, and CO2 for a site |
| `stakeholder` | Person or organisation in a location |
| `stakeholder_impact` | How a data centre affects a stakeholder |

## Queries

`queries.sql` has 3 queries:

1. Energy, water, and CO2 totals by city for the latest year
2. Operational sites with high CO2 and high-severity stakeholder impacts
3. Year-over-year energy change per data centre

## Contributors

Anastasios Vlachmpeis Nikita Kirillov
