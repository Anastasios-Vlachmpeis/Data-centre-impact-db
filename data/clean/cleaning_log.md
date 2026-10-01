# Cleaning log (made by etl/clean_data.py)

| Step | Rows |
|---|---|
| A: raw rows (country = Netherlands / Netherlands Antilles) | 448 |
| A: exact duplicate rows removed | 1 |
| A: rows outside European NL removed (Curaçao, Sint Maarten, Antilles) | 8 |
| A: names/addresses with non-breaking spaces normalised | 1 |
| A: rows with a US/Canadian `state` value (column dropped) | 25 |
| A: rows with empty address (street stored as NULL) | 1 |
| A: city taken from address because `city` column was empty/wrong | 187 |
| A: city spelling fixed (typo, split name, capitalisation) | 2 |
| A: rows dropped because no city could be recovered | 1 |
| A: company names mapped to a canonical name | 89 |
| A: logical duplicates removed (same company + name + street + city) | 4 |
| A: same site under two naming conventions merged (same company + street + city) | 37 |
| A: clean data centre rows | 397 |
| A: distinct companies | 181 |
| A: distinct cities | 102 |
| B: raw rows (all countries and regions, year >= 2000) | 7636 |
| B: aggregate rows without iso_code removed (World, Europe, EU, income groups...) | 2061 |
| B: rows kept although iso_code is empty (Kosovo) | 26 |
| B: rows for European countries, 2000-2025 | 1032 |
| B: rows where every metric was empty removed | 2 |
| B: duplicate (country, year) rows removed | 0 |
| B: clean grid rows | 1030 |
| B: distinct countries | 40 |
