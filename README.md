# Data Centre Impact DB

This is a MySQL database project we built for a database design course. The idea is to model data centres, the companies that run them, and the effect they have on the places and people around them (energy use, water use, emissions, and local pushback from residents or councils).

We picked this topic because most example databases online are the same old library or shop schema, and we wanted something with a bit more real-world mess to it.

## What it does

The database keeps track of:

- which company owns which data centre, and where it's located
- yearly environmental numbers per site (energy in MWh, water in cubic metres, CO2 in tons)
- stakeholders near a site (residents, municipalities, NGOs, utilities, businesses) and how each data centre affects them, including how serious the issue was and what the response looked like (complaint, protest, legal challenge, etc.)

The seed data uses real company names (Google, Microsoft, Equinix, Digital Realty) and real Dutch cities (Amsterdam, Rotterdam, Groningen, Eindhoven) just because it made the numbers easier to reason about, but the actual sites, capacities, and impact records are all made up. Also fair warning, a few of the "local resident" stakeholders in `seed.sql` are just our first names, we got lazy filling in test data.

## Files

- `schema.sql` - creates the database and all the tables, with primary keys, foreign keys, and check constraints
- `seed.sql` - fake data so there's something to query
- `crud.sql` - a few insert/update/delete statements we used to sanity check the schema
- `queries.sql` - the actual analysis queries for the assignment

## Setting it up

You need MySQL installed locally. There's no dump file, you just run the scripts in order.

Command line:

```bash
mysql -u root -p < schema.sql
mysql -u root -p data_centre_impact < seed.sql
mysql -u root -p data_centre_impact < crud.sql
mysql -u root -p data_centre_impact < queries.sql
```

Or if you're using MySQL Workbench, open each file and run it with the lightning bolt icon, same order: schema, then seed, then crud, then queries.

## Tables

| Table | What it's for |
|---|---|
| `company` | the operator of one or more data centres |
| `location` | a city/country pair |
| `data_center` | one physical site, tied to a company and a location |
| `environmental_impact` | yearly energy/water/CO2 numbers for a site |
| `stakeholder` | a person or group near a location who might be affected |
| `stakeholder_impact` | links a data centre to a stakeholder and describes the impact |

## Queries

Three queries in `queries.sql`:

1. Total energy, water, and CO2 per city for the most recent year in the data
2. Operational data centres with a big footprint that also have high severity complaints from stakeholders
3. Year over year change in energy use per data centre, using a window function

If you're running MySQL 5.7 or something older without window function support, query 3 won't work, you'd need MySQL 8+.

## Requirements

`requirements.txt` only matters if you're connecting to the DB from Python (mysql-connector-python and python-dotenv). You don't need it just to run the SQL files.

## Contributors

Anastasios Vlachmpeis, Nikita Kirillov, Minseok Choi, Matvei Kandalintsev
