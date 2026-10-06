# Data Centre Impact DB

Repository: https://github.com/Anastasios-Vlachmpeis/Data-centre-impact-db

A MySQL database for tracking data centres, their operators, and their local impact. We built this for a database design course, modelling data centres, the companies that run them, and the effect they have on the places and people around them (energy use, water use, emissions, and local pushback from residents or councils).

We picked this topic because most example databases online are the same old library or shop schema, and we wanted something with a bit more real-world mess to it.

## What it does

The database keeps track of:

- which company owns which data centre, and where it's located
- yearly environmental numbers per site (energy in MWh, water in cubic metres, CO2 in tons)
- stakeholders near a site (residents, municipalities, NGOs, utilities, businesses) and how each data centre affects them, including how serious the issue was and what the response looked like (complaint, protest, legal challenge, etc.)

The seed data uses real company names (Google, Microsoft, Equinix, Digital Realty) and real Dutch cities (Amsterdam, Rotterdam, Groningen, Eindhoven) just because it made the numbers easier to reason about, but the actual sites, capacities, and impact records are all made up. Also fair warning, a few of the "local resident" stakeholders in `seed.sql` are just our first names, we got lazy filling in test data --> Now changed into student1, student2, student3, student4 before publishing.

## Contributors

Anastasios Vlachmpeis, Nikita Kirillov, Minseok Choi, Matvei Kandalintsev

---

## Week 1: Societal problem

Our topic is the local cost of the AI data centre boom, based on the MIT Technology Review article "Data centers are amazing. Everyone hates them." (Mat Honan, 14-01-2026). Data centres bring benefits that are global (AI, cloud, economic growth), but the costs are local: electricity and water use, noise, and grid problems, while residents have little say.

- File: [Week 1 – Societal problem (PDF)](docs/week1/week1_societal_problem.pdf)

## Week 2: ERD and normalization

- ERD:
- <img width="911" height="510" alt="image" src="https://github.com/user-attachments/assets/9bfba3ab-42ac-4ec0-94e8-84eccb5f973e" />

- Normalization report: [Week 2 – ERD and normalization (PDF)](docs/week2/week2_erd_normalization.pdf)


### Week 5 update: normal form violations in the real data

When we loaded the real data in week 5, the raw files had the same problems we fixed in week 2:
- 1NF: in dataset A the address was one cell with street, postcode, city and country together. We split it into `street_address` and `location`.
- 2NF: in dataset B the key is (country code, year), but the country name only depends on the country code, so it was repeated every year. We made a separate `country` table.
- 3NF: in dataset A the company and city were repeated on every row, and city -> country is a transitive dependency. Same fix as in week 2: `company`, `location` and now also `country` tables.
- We did not store the postcode, because postcode -> city would break 3NF again.

After loading, our database is still in 3NF. The ERD above is from week 2; in week 5 we added the `country` and `grid_electricity` tables.

## Week 3: Schema definition and constraints

### Repository layout

- `schema.sql` : database, tables, keys, and constraints
- `seed.sql` : realistic mock data
- `crud.sql` : insert, update, and delete examples
- `queries.sql` : queries
- `real_data.sql` : real-world data (week 5, made by `clean_data.py`)
- `checks.sql` : data checks after loading the real data (week 5)

### How to run

You need MySQL installed locally. There's no dump file, you just run the scripts in order.

Command line:

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

| Table | What it's for |
|---|---|
| `company` | Operator of one or more data centres |
| `location` | City and country |
| `data_center` | Site owned by one company, in one location |
| `environmental_impact` | Yearly energy, water, and CO2 for a site |
| `stakeholder` | Person or organisation in a location |
| `stakeholder_impact` | How a data centre affects a stakeholder |
| `country` | Country code and name (new in week 5) |
| `grid_electricity` | Electricity use, CO2 per kWh, and renewables share per country per year (new in week 5) |

### Queries

`queries.sql` has 6 queries. Q1 to Q3 are from week 3 (changed a bit in week 5), Q4 to Q6 are new and use the real data.

1. Number of data centres per city, and energy, water, and CO2 totals for the latest year
2. Operational sites with high CO2 and high-severity stakeholder impacts
3. Year-over-year energy change per data centre
4. Which companies have the most data centres in the Netherlands, and in how many cities (real data)
5. Reported CO2 compared to how much CO2 the same electricity would give on the Dutch grid (mock data + grid data)
6. How clean Dutch electricity is compared to the rest of Europe, per year (real data)

If you're running MySQL 5.7 or something older without window function support, query 3 won't work, you'd need MySQL 8+.

What we changed in week 5:
- Q1 used a normal JOIN with `environmental_impact`, so all real sites (which have no yearly numbers) were left out and Amsterdam only showed 4 data centres. With a LEFT JOIN it now shows 95, plus a column with how many of them actually have numbers.
- Q2 had the year fixed to 2024, now it takes the latest year like Q1.
- Q3 did not change.

`checks.sql` has extra checks we run after loading the real data (duplicate names, missing values, rows without a country).

## Week 4: Stakeholder video
- Video:

https://github.com/user-attachments/assets/c3191756-f645-4f16-970d-a3bfdec4b48f



## Week 5: Real-world data

This week we loaded two real, open datasets into our database to see if our design still works.

### Datasets

| | Dataset A | Dataset B |
|---|---|---|
| What | List of data centres (name, company, address) | Electricity use and how clean the grid is, per country per year |
| Source | [ATLAS / Global Data Center Map](https://github.com/Ringmast4r/Global-Data-Center-Map) by Ringmast4r | [Our World in Data energy dataset](https://github.com/owid/energy-data) (data from Ember) |
| Published | 16-09-2026 (version we used) | 27-04-2026 (version we used) |
| License | Free to use with credit (attribution license) | CC BY 4.0 |
| What we used | Dutch rows only: 448 raw -> 397 data centres | Europe 2000-2025: 1,030 rows, 40 countries |
| Goes into | `company`, `location`, `data_center` | `country`, `grid_electricity` |

The two datasets only overlap on the Netherlands, so neither one is a subset of the other. A tells us where the data centres are, B tells us how much CO2 the electricity they use causes.

### How we loaded it

- `clean_data.py` cleans the raw files in `data/raw/` and writes the clean files to `data/clean/` and the SQL to `real_data.sql`
- `real_data.sql` runs in one transaction and puts the data into the normalized tables (every company and city only once)

### Data cleaning

- **Missing data:** empty cells and "tbc" in the source. Capacity and status are not in dataset A at all. We store all of these as NULL instead of making up a value.
- **Dates:** dataset A has no dates at all. Dataset B uses a normal 4-digit year, which matches our `year` column.
- **Duplicates:** 1 exact duplicate, 4 duplicates after cleaning, and 37 sites that were in the data twice under different names (like "Equinix AM1" and "AM1 Amsterdam IBX Data Center").
- **Naming:** the same company written in different ways ("Digital Realty" / "Digital Realty Trust"), two address formats, typos in city names ("Amerfoort"), and 3-letter country codes (NLD) while we use 2 letters (NL).

### Schema and constraint changes

Loading the real data into the week 3 schema gave errors, so we changed:
- `capacity_mw` and `status` can be NULL now (396 rows failed on NOT NULL)
- `dc_name` is not unique anymore, because many companies call their site "Amsterdam" (64 rows failed)
- `dc_name` is longer (50 -> 150 characters)
- new columns `street_address` and `source` (mock or real) in `data_center`
- new tables `country` and `grid_electricity`
- `crud.sql` fixed, because it used ids that are now taken by real data

### Normalization

The raw files were not normalized. Addresses were not atomic (1NF), country names were repeated per year (2NF), and company and city were repeated on every row (3NF). After loading, our database is still in 3NF.

### Limitations and future work (from the week 4 video)

- "Only 4 cities and 10 data centres": fixed, we now have 102 places and 407 data centres
- "Data is simulated": partly fixed. Locations and companies are real now, but energy, water, CO2 and stakeholder data are still mock.
- Indexes, a transaction and a view are now added (these were future work in the video)
- New problem: the real data has no capacity or status, so Q2 and Q3 can still only use the mock data

### Publication
Link to our published sql dump on Zendo: https://zenodo.org/records/23189532
