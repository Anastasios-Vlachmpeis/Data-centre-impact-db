# Week 5: cleaning script for our two real datasets
#
# Dataset A = ATLAS data centre list (only the Dutch rows)
#             -> goes into company, location, data_center
# Dataset B = Our World in Data energy data (Europe, 2000-2025)
#             -> goes into country, grid_electricity
#
# How to run (from the main folder of the repo):
#     python etl/clean_data.py
#
# It reads the raw csv files in data/raw/, writes the cleaned csv files to
# data/clean/ (plus cleaning_log.md with how many rows each step changed)
# and creates real_data.sql which we then run in MySQL.
# Only uses standard python, nothing to pip install.

import csv
import re
import unicodedata
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_ATLAS = ROOT / "data/raw/atlas_datacenters_nl_raw.csv"
RAW_OWID = ROOT / "data/raw/owid_energy_raw_subset.csv"
CLEAN_DIR = ROOT / "data/clean"
OUT_SQL = ROOT / "real_data.sql"

# we count every cleaning step here so we can put the numbers in the report
log = OrderedDict()


# ---------- small helper functions ----------

def clean_text(s):
    # some names had a non-breaking space in them, which looks the same
    # but is a different string, so we replace it and remove double spaces
    if s is None:
        return ""
    s = unicodedata.normalize("NFC", s).replace(" ", " ")
    return re.sub(r"\s+", " ", s).strip()


def sql_str(v):
    # turns a python value into something we can put in an INSERT
    # empty values become NULL
    if v is None or v == "":
        return "NULL"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("\\", "\\\\").replace("'", "''") + "'"


# ---------- dataset A: data centres ----------

# BV, B.V., GmbH etc. made the same company look like different ones
LEGAL_SUFFIX = re.compile(
    r"[\s,]+(b\.?\s?v\.?|n\.?\s?v\.?|c\.?\s?v\.?|gmbh|ltd\.?|inc\.?|lp|holding)$", re.I
)

# companies that appear under more than one name in the data.
# we went through the list of company names by hand and wrote these down
# (left = name in the data in lower case, right = name we use)
COMPANY_ALIASES = {
    "digital realty trust": "Digital Realty",
    "northc datacenters": "NorthC",
    "serverius it infrastructure": "Serverius",
    "serverius datacenters": "Serverius",
    "serverius datacenter dc1": "Serverius",
    "edgeconnex": "EdgeConneX",
    "softlayer technologies (ibm cloud)": "IBM Cloud",
    "microsoft azure": "Microsoft",
    "iron mountain data centers": "Iron Mountain",
    "iron mountain": "Iron Mountain",
    "keppel data centres germany": "Keppel Data Centres",
    "bt services (british telecom)": "BT Global Services",
    "colt technologies": "Colt",
    "computel standby": "Computel",
    "data facilities data centers": "Data Facilities",
    "datacenter groningen": "Datacenter Groningen",
    "databarn rivium": "Databarn",
    "bardeen datahotel": "Bardeen",
    "bit data center": "BIT",
    "eurofiber cloud infra": "Eurofiber",
    "nikhef housing": "NIKHEF",
    "smartdc": "SmartDC",
    "wide xs / ion-ip": "WideXS",
    "widexs / ion-ip": "WideXS",
    "maincubes": "Maincubes",
    "centurylink": "Lumen",           # CenturyLink changed its name to Lumen
    "tennet": "TenneT",
    "global-e datacenter": "Global-e Datacenter",
    "claranet": "Claranet",
    "bytesnet": "Bytesnet",
}

# some rows say "Netherlands" but are actually on Curacao / Sint Maarten etc.
# our project is about the Netherlands in Europe so we leave these out
CARIBBEAN = re.compile(r"antilles|cura[cç]ao|sint maarten|philipsburg|aruba|bonaire", re.I)

# dutch postcode, e.g. 1431 GE
DUTCH_POSTCODE = re.compile(r"\b(\d{4})\s?([A-Z]{2})\b")

# provinces / country names that ended up where the city should be
PROVINCES = {
    "gelderland", "limburg", "friesland", "zeeland", "drenthe", "overijssel",
    "nederland", "netherlands",
    "nh", "noord-holland", "zh", "zuid-holland", "ut", "utrecht province",
    "nb", "noord-brabant", "gr", "groningen province", "fl", "flevoland",
}

# typos and different names for the same place that we found
CITY_FIXES = {
    "amerfoort": "Amersfoort",           # typo in the data
    "haag": "Den Haag",                   # 'Den Haag' got cut in half
    "the hague": "Den Haag",
    "'s-gravenhage": "Den Haag",
    "s-gravenhage": "Den Haag",
    "luchthaven schiphol": "Schiphol",
    "amsterdam zuid-oost": "Amsterdam",
    "amsterdam-zuidoost": "Amsterdam",
    "amsterdam zuidoost": "Amsterdam",
    "zuid-oost": "Amsterdam",
    "rijn": "Alphen aan den Rijn",
    "ijssel": "Capelle aan den IJssel",
    "meer": "Haarlemmermeer",
    "son": "Son en Breugel",
    "eindhoven airport": "Eindhoven",
    "rotterdam airport": "Rotterdam",
    "den bosch": "'s-Hertogenbosch",     # same city, two names
    "amsterdamamsterdam-zuidoost": "Amsterdam",
    "schoorl aagtdorp": "Schoorl",
    "maastricht-airport": "Maastricht Airport",
}

# a city should only have letters, spaces, - . and '
VALID_CITY = re.compile(r"^[A-Za-zÀ-ÿ'][A-Za-zÀ-ÿ'\-\. ]{2,}$")


def canonical_company(raw):
    # returns (company name we use, True if we had to change it)
    name = clean_text(raw)
    stripped = LEGAL_SUFFIX.sub("", name).strip(" ,")
    key = stripped.lower()
    if key in COMPANY_ALIASES:
        return COMPANY_ALIASES[key], name != COMPANY_ALIASES[key]
    return stripped, stripped != name


def strip_country(addr):
    # addresses end with 'Netherlands', 'The Netherlands' or 'Nederland'
    return re.sub(r"[,\s]*((the\s+)?netherlands|nederland)\s*$", "", addr, flags=re.I).strip(" ,")


def parse_address(addr):
    # gets (street, city) out of the address.
    # the data uses two different formats:
    #   'Lakenblekerstraat 13 1431 GE Aalsmeer Netherlands'
    #   'Kloosterweg 1, 6412 CN Heerlen, The Netherlands'
    addr = clean_text(addr)
    addr = re.sub(r"\S+@\S+", "", addr)                         # some had an email in it
    addr = re.sub(r"\b\d{3}[.\-]\d{3}[.\-]\d{4}\b", "", addr)    # and one a phone number
    addr = strip_country(clean_text(addr))
    addr = re.sub(r"\s*\([^)]*\)?", "", addr)   # remove things like '(gemeente Gemert)'
    if not addr:
        return None, None
    parts = [p.strip() for p in addr.split(",") if p.strip()]
    parts = [p for p in parts if p.lower() not in PROVINCES]
    addr = ", ".join(parts)
    if not parts:
        return None, None

    # easiest case: there is a postcode, street is before it and city after it
    m = DUTCH_POSTCODE.search(addr)
    if m:
        before = addr[: m.start()].strip(" ,")
        after = addr[m.end():].strip(" ,")
        city = after.split(",")[0].strip()
        street = before.split(",")[-1].strip() if before else None
        return (street or None), (city or None)

    # postcode with only the 4 numbers, e.g. '1165 Haarlemmerliede'
    m = re.search(r"\b\d{4}\s+([A-Z][^,\d]+)$", addr)
    if m:
        return (addr[: m.start()].strip(" ,") or None), m.group(1)

    # only a place name
    if len(parts) == 1 and "," not in addr and len(addr.split()) == 1:
        return None, addr
    # 'street, city' without postcode
    if len(parts) >= 2:
        return parts[-2] if len(parts) > 2 else parts[0], parts[-1]
    # no commas and no postcode, e.g. 'tbc Almere': take the last word as city
    words = addr.split()
    return (" ".join(words[:-1]) or None), words[-1]


def fix_city(c):
    # returns a cleaned city name, or None if it is not a real city
    if not c:
        return None
    c = clean_text(c).strip(" ,.")
    c = re.sub(r"^\d{4}\s?[A-Z]{2}\s+", "", c)          # postcode left in front
    c = re.sub(r"\s+nederland$", "", c, flags=re.I)      # 'Ede Nederland' -> 'Ede'
    key = c.lower()
    if key in CITY_FIXES:
        return CITY_FIXES[key]
    # things like 'BV', 'NR' (postcode letters) or a phone number are not cities
    if not VALID_CITY.match(c) or key in PROVINCES or c.isupper() and len(c) <= 3:
        return None
    if c.islower() or c.isupper():      # 'AMSTERDAM' -> 'Amsterdam'
        c = c.title()
    return c


def normalise_street(s):
    # 'tbc' (to be confirmed) and similar are not real streets -> NULL
    if not s:
        return None
    s = clean_text(s)
    if s.lower() in {"tbc", "n/a", "na", "-", "unknown"}:
        return None
    return s


# words that don't help to tell two sites apart
GENERIC_WORDS = {
    "data", "center", "centre", "datacenter", "datacentre", "datacenters", "dc", "ibx",
    "facility", "the", "netherlands", "nederland", "bv", "b.v", "b.v.", "region", "-", "–",
}


def name_tokens(name, company, city):
    # splits a site name into codes with a number in them (AM1, DC2, ...)
    # and the other words, without the generic words, company and city name
    skip = GENERIC_WORDS | set(company.lower().split()) | set(city.lower().split())
    words = re.findall(r"[a-z0-9À-ÿ]+", name.lower())
    codes = {w for w in words if re.search(r"\d", w)}
    plain = {w for w in words if w not in codes and w not in skip}
    return codes, plain


def same_site(a, b):
    # are these two rows (same company + street + city) the same building?
    ca, pa = name_tokens(a["dc_name"], a["company_name"], a["city"])
    cb, pb = name_tokens(b["dc_name"], b["company_name"], b["city"])
    if ca and cb:
        return bool(ca & cb)              # AM1 and AM2 are different buildings
    return pa <= pb or pb <= pa           # 'Dataplace Utrecht' and 'Utrecht' are the same


def merge_naming_variants(rows):
    # the dataset seems to combine two lists, so the same building is often
    # in there twice with a different name, e.g. 'Equinix AM1' and
    # 'AM1 Amsterdam IBX Data Center'. we group rows by company + street + city
    # and merge the ones that are the same site.
    groups = OrderedDict()
    for r in rows:
        if not r["street_address"]:
            groups[id(r)] = [[r]]     # no street, can't compare, keep it
            continue
        key = (r["company_name"].lower(), r["street_address"].lower(), r["city"].lower())
        clusters = groups.setdefault(key, [])
        for cl in clusters:
            # it has to match all rows in the group, otherwise 'Amsterdam'
            # would merge 'Amsterdam East' and 'Amsterdam West' together
            if all(same_site(r, m) for m in cl):
                cl.append(r)
                break
        else:
            clusters.append([r])
    merged = []
    for clusters in groups.values():
        for cl in clusters:
            # keep the best name: one with a code like AM1, otherwise the longest
            best = max(cl, key=lambda m: (bool(re.search(r"\d", m["dc_name"])), len(m["dc_name"])))
            merged.append(best)
    return merged


def clean_atlas():
    rows = list(csv.DictReader(open(RAW_ATLAS, encoding="utf-8")))
    log["A: raw rows (country = Netherlands / Netherlands Antilles)"] = len(rows)

    # step 1: rows that are exactly the same
    seen, uniq = set(), []
    for r in rows:
        k = tuple(r.values())
        if k in seen:
            continue
        seen.add(k)
        uniq.append(r)
    log["A: exact duplicate rows removed"] = len(rows) - len(uniq)

    out, dropped_carib, dropped_nocity = [], 0, 0
    city_from_address = city_fixed = state_dropped = company_renamed = 0
    missing_address = nbsp_fixed = 0
    for r in uniq:
        if r["country"] == "Netherlands Antilles" or CARIBBEAN.search(
            " ".join([r["city"], r["address"], r["name"]])
        ):
            dropped_carib += 1
            continue
        if " " in r["name"] or " " in r["address"]:
            nbsp_fixed += 1
        if r["state"]:
            state_dropped += 1      # things like 'Nebraska', the NL has no states
        if not clean_text(r["address"]):
            missing_address += 1

        # we trust the address more than the city column, because the city
        # column often had postcode letters, a phone number or half a name
        street, city_addr = parse_address(r["address"])
        city_field = fix_city(r["city"])
        city_addr = fix_city(city_addr)
        city = city_addr or city_field
        if city_addr and city_addr != clean_text(r["city"]):
            city_from_address += 1
        elif city_field and city_field != clean_text(r["city"]):
            city_fixed += 1
        if not city:
            dropped_nocity += 1     # location_id is NOT NULL so we can't keep it
            continue

        if street and street.lower() == city.lower():
            street = None           # e.g. 'Eemshaven, 9909 TA Eemshaven' has no street
        company, renamed = canonical_company(r["company"])
        company_renamed += renamed
        out.append(
            {
                "dc_name": clean_text(r["name"]),
                "company_name": company,
                "street_address": normalise_street(street),
                "city": city,
                "country": "NL",
            }
        )

    log["A: rows outside European NL removed (Curaçao, Sint Maarten, Antilles)"] = dropped_carib
    log["A: names/addresses with non-breaking spaces normalised"] = nbsp_fixed
    log["A: rows with a US/Canadian `state` value (column dropped)"] = state_dropped
    log["A: rows with empty address (street stored as NULL)"] = missing_address
    log["A: city taken from address because `city` column was empty/wrong"] = city_from_address
    log["A: city spelling fixed (typo, split name, capitalisation)"] = city_fixed
    log["A: rows dropped because no city could be recovered"] = dropped_nocity
    log["A: company names mapped to a canonical name"] = company_renamed

    # step 2: duplicates after cleaning (same company, name, street and city)
    seen, dedup = set(), []
    for r in out:
        k = (r["company_name"].lower(), r["dc_name"].lower(),
             (r["street_address"] or "").lower(), r["city"].lower())
        if k in seen:
            continue
        seen.add(k)
        dedup.append(r)
    log["A: logical duplicates removed (same company + name + street + city)"] = len(out) - len(dedup)

    # step 3: same building with two different names
    before = len(dedup)
    dedup = merge_naming_variants(dedup)
    log["A: same site under two naming conventions merged (same company + street + city)"] = before - len(dedup)
    log["A: clean data centre rows"] = len(dedup)
    log["A: distinct companies"] = len({r["company_name"] for r in dedup})
    log["A: distinct cities"] = len({r["city"] for r in dedup})
    return dedup


# ---------- dataset B: electricity grid per country ----------

# OWID uses 3 letter country codes (NLD), our database uses 2 letters (NL).
# we only take the European countries
EUROPE_ISO3_TO_ISO2 = {
    "ALB": "AL", "AUT": "AT", "BEL": "BE", "BGR": "BG", "BIH": "BA", "BLR": "BY",
    "CHE": "CH", "CYP": "CY", "CZE": "CZ", "DEU": "DE", "DNK": "DK", "ESP": "ES",
    "EST": "EE", "FIN": "FI", "FRA": "FR", "GBR": "GB", "GRC": "GR", "HRV": "HR",
    "HUN": "HU", "IRL": "IE", "ISL": "IS", "ITA": "IT", "LTU": "LT", "LUX": "LU",
    "LVA": "LV", "MDA": "MD", "MKD": "MK", "MLT": "MT", "MNE": "ME", "NLD": "NL",
    "NOR": "NO", "POL": "PL", "PRT": "PT", "ROU": "RO", "SRB": "RS", "SVK": "SK",
    "SVN": "SI", "SWE": "SE", "UKR": "UA",
}
# Kosovo has no official ISO code so in OWID the iso_code is empty, just like
# for 'World' or 'Europe'. at first our filter removed Kosovo by accident
# (we got 39 countries instead of 40), so now we match it by name. XK is the
# code the EU uses for Kosovo.
COUNTRIES_WITHOUT_ISO = {"Kosovo": "XK"}

FIRST_YEAR, LAST_YEAR = 2000, 2025


def to_float(v):
    # empty cell -> None (NULL in the database)
    v = (v or "").strip()
    return round(float(v), 3) if v else None


def clean_owid():
    rows = list(csv.DictReader(open(RAW_OWID, encoding="utf-8")))
    log["B: raw rows (all countries and regions, year >= 2000)"] = len(rows)

    for r in rows:
        if not r["iso_code"].strip() and r["country"] in COUNTRIES_WITHOUT_ISO:
            r["iso2"] = COUNTRIES_WITHOUT_ISO[r["country"]]
        else:
            r["iso2"] = EUROPE_ISO3_TO_ISO2.get(r["iso_code"].strip())
    # rows without iso_code are regions like 'World', 'Europe', 'EU (Ember)'
    no_iso = [r for r in rows if not r["iso_code"].strip() and r["country"] not in COUNTRIES_WITHOUT_ISO]
    log["B: aggregate rows without iso_code removed (World, Europe, EU, income groups...)"] = len(no_iso)
    log["B: rows kept although iso_code is empty (Kosovo)"] = sum(
        1 for r in rows if r["country"] in COUNTRIES_WITHOUT_ISO)

    rows = [r for r in rows if r["iso2"]]
    rows = [r for r in rows if FIRST_YEAR <= int(r["year"]) <= LAST_YEAR]
    log[f"B: rows for European countries, {FIRST_YEAR}-{LAST_YEAR}"] = len(rows)

    out, all_missing, partial_missing = [], 0, Counter()
    countries = {}
    seen = set()
    dups = 0
    for r in rows:
        rec = {
            "country_code": r["iso2"],
            "year": int(r["year"]),
            "electricity_demand_twh": to_float(r["electricity_demand"]),
            "electricity_generation_twh": to_float(r["electricity_generation"]),
            "carbon_intensity_g_per_kwh": to_float(r["carbon_intensity_elec"]),
            "renewables_share_pct": to_float(r["renewables_share_elec"]),
        }
        metrics = [k for k in rec if k not in ("country_code", "year")]
        if all(rec[k] is None for k in metrics):
            all_missing += 1        # nothing useful in this row
            continue
        for k in metrics:
            if rec[k] is None:
                partial_missing[k] += 1
        key = (rec["country_code"], rec["year"])
        if key in seen:             # should not happen, but (country, year) is our PK
            dups += 1
            continue
        seen.add(key)
        countries[rec["country_code"]] = clean_text(r["country"])
        out.append(rec)

    log["B: rows where every metric was empty removed"] = all_missing
    for k, v in partial_missing.items():
        log[f"B: rows with empty `{k}` kept as NULL"] = v
    log["B: duplicate (country, year) rows removed"] = dups
    log["B: clean grid rows"] = len(out)
    log["B: distinct countries"] = len(countries)
    return out, countries


# ---------- writing the output files ----------

def write_csv(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)


def write_sql(dcs, grid, countries):
    L = []
    w = L.append
    w("-- made by etl/clean_data.py, if something needs to change, change the script")
    w("-- and run it again instead of editing this file")
    w("--")
    w("-- real data (week 5):")
    w("--   A: ATLAS / Global Data Center Map (c) Ringmast4r")
    w("--      https://github.com/Ringmast4r/Global-Data-Center-Map")
    w("--   B: Our World in Data energy dataset (CC BY 4.0)")
    w("--      https://github.com/owid/energy-data")
    w("-- run this after schema.sql and seed.sql")
    w("")
    w("USE data_centre_impact;")
    w("")
    w("-- everything in one transaction, so if one insert fails nothing gets loaded")
    w("START TRANSACTION;")
    w("")
    w("-- 1. first put the cleaned rows in a temporary flat table")
    w("DROP TEMPORARY TABLE IF EXISTS stg_datacenter;")
    w("CREATE TEMPORARY TABLE stg_datacenter (")
    w("    dc_name VARCHAR(150) NOT NULL,")
    w("    company_name VARCHAR(100) NOT NULL,")
    w("    street_address VARCHAR(255) NULL,")
    w("    city VARCHAR(100) NOT NULL,")
    w("    country CHAR(2) NOT NULL")
    w(");")
    w("")
    w("INSERT INTO stg_datacenter (dc_name, company_name, street_address, city, country) VALUES")
    vals = [
        f"    ({sql_str(r['dc_name'])}, {sql_str(r['company_name'])}, "
        f"{sql_str(r['street_address'])}, {sql_str(r['city'])}, {sql_str(r['country'])})"
        for r in dcs
    ]
    w(",\n".join(vals) + ";")
    w("")
    w("-- 2. countries from dataset B (NL is already added in seed.sql)")
    w("INSERT INTO country (country_code, country_name) VALUES")
    w(",\n".join(f"    ({sql_str(c)}, {sql_str(n)})" for c, n in sorted(countries.items())))
    w("ON DUPLICATE KEY UPDATE country_name = VALUES(country_name);")
    w("")
    w("-- 3. every company and city only once (IGNORE skips the ones from seed.sql)")
    w("INSERT IGNORE INTO company (company_name)")
    w("SELECT DISTINCT company_name FROM stg_datacenter;")
    w("")
    w("INSERT IGNORE INTO location (city, country)")
    w("SELECT DISTINCT city, country FROM stg_datacenter;")
    w("")
    w("-- 4. data centres, with the ids of their company and location")
    w("INSERT INTO data_center (dc_name, street_address, capacity_mw, status, source,")
    w("                         company_id, location_id)")
    w("SELECT s.dc_name, s.street_address, NULL, NULL, 'atlas', c.company_id, l.location_id")
    w("FROM stg_datacenter s")
    w("JOIN company c  ON c.company_name = s.company_name")
    w("JOIN location l ON l.city = s.city AND l.country = s.country;")
    w("")
    w("DROP TEMPORARY TABLE stg_datacenter;")
    w("")
    w("-- 5. electricity grid per country per year (dataset B)")
    w("INSERT INTO grid_electricity (country_code, year, electricity_demand_twh,")
    w("    electricity_generation_twh, carbon_intensity_g_per_kwh, renewables_share_pct) VALUES")
    vals = [
        f"    ({sql_str(r['country_code'])}, {r['year']}, {sql_str(r['electricity_demand_twh'])}, "
        f"{sql_str(r['electricity_generation_twh'])}, {sql_str(r['carbon_intensity_g_per_kwh'])}, "
        f"{sql_str(r['renewables_share_pct'])})"
        for r in grid
    ]
    w(",\n".join(vals) + ";")
    w("")
    w("COMMIT;")
    w("")
    OUT_SQL.write_text("\n".join(L), encoding="utf-8")


def write_log():
    lines = ["# Cleaning log (made by etl/clean_data.py)", "",
             "| Step | Rows |", "|---|---|"]
    lines += [f"| {k} | {v} |" for k, v in log.items()]
    (CLEAN_DIR / "cleaning_log.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    CLEAN_DIR.mkdir(parents=True, exist_ok=True)
    dcs = clean_atlas()
    grid, countries = clean_owid()
    write_csv(CLEAN_DIR / "datacenters_nl_clean.csv", dcs)
    write_csv(CLEAN_DIR / "grid_electricity_europe_clean.csv", grid)
    write_sql(dcs, grid, countries)
    write_log()
    for k, v in log.items():
        print(f"{v:>6}  {k}")


if __name__ == "__main__":
    main()
