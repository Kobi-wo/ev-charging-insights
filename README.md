# EV Charging Customer Insights — Town of Cary, NC

An analysis of 10 years of public EV charging sessions. The goal: understand how customers use the charging network, where demand is growing, and what the network operator should do next.

**Tools:** Microsoft SQL Server (T-SQL), Power BI, Git/GitHub
**Data:** 20,142 charging sessions, April 2012 – January 2023, Town of Cary Open Data (see [Data source](#data-source))

---

## Business questions

1. How fast is EV charging demand growing?
2. Which sites carry the load?
3. When do customers charge, and does that line up with peak grid demand?
4. How long do customers stay, and how much energy do they take?
5. What should the operator do next?

## Key findings

**1. Demand grew 20× in five years.**
Sessions rose from 297 in 2017 to 5,907 in 2022. Growth continued through 2020 (+86%), when many other public services dropped. A large part of the jump in 2019 matches the opening of the downtown parking deck chargers.

| Year | Sessions | Energy (kWh) | Growth |
|------|---------:|-------------:|-------:|
| 2018 | 1,080 | 6,553 | +264% |
| 2019 | 1,870 | 15,386 | +73% |
| 2020 | 3,486 | 33,312 | +86% |
| 2021 | 4,322 | 40,712 | +24% |
| 2022 | 5,907 | 58,040 | +37% |

**2. Two sites carry 84% of sessions.**
In 2022, the Downtown Parking Deck had 49% of sessions and Bond Park Boathouse had 35%. Town Hall customers stay longer (153 min on average) and take more energy per visit (13 kWh).

**3. Demand peaks from 4 to 6 PM.**
20% of all sessions start in the 4–6 PM window (local time). This is also when utility demand is highest on a typical day.

**4. Short visits are frequent, long visits use the energy.**

| Session length | % of sessions | % of energy |
|---|---:|---:|
| Under 1 hour | 41% | 14% |
| 1–3 hours | 43% | 40% |
| 3–8 hours | 14% | 37% |
| 8+ hours | 1% | 9% |

Sessions of 3 hours or more are 16% of visits but 46% of the energy.

**5. Each site has its own customer.**
Bond Park is a weekend site: 7.6 sessions per day on weekends vs 5.8 on weekdays. The downtown deck is steady all week (8.1 per day). On its busiest days (late August 2022) the deck reached 26–27 sessions per day.

**6. Floor level drives demand in the parking deck.**
Chargers on the lower floors are much busier. In 2022, when all floors were open, each charger on floors 2–3 had about 1.7–1.9 sessions per day. Floors 5–6 had less than 0.2 — about 10 times less. Customers on high floors stay longer and take more energy (16–24 kWh vs about 9 kWh), which suggests long-stay parkers, not quick visitors.

| Deck floor | Chargers | Sessions per charger per day | Avg kWh | Avg minutes |
|---|---:|---:|---:|---:|
| 2 | 2 | 1.93 | 9.8 | 116 |
| 3 | 2 | 1.66 | 8.7 | 102 |
| 4 | 1 | 0.44 | 11.1 | 128 |
| 5 | 1 | 0.16 | 15.8 | 165 |
| 6 | 1 | 0.18 | 23.7 | 238 |

## Recommendations

These follow from the findings. They are proposals to test, not proven results.

1. **Shift the 4–6 PM peak.** Test off-peak pricing or a managed-charging program to move flexible sessions to the evening or night.
2. **Expand downtown first — on the lower floors.** The deck carries half the network's demand and has the highest daily peaks. New chargers on floors 2–3 should get far more use than chargers on floors 5–6. Better signs to the upper-floor chargers are a low-cost test.
3. **Manage long sessions.** A time limit or an idle fee after charging ends can free ports for more customers. (This data records charging time only, not total plug-in time — a next step is to get plug-in data to measure idle time directly.)
4. **Plan Bond Park around weekends.** Schedule maintenance on weekdays.

## Data cleaning

| Issue | What I did |
|---|---|
| Text dates and durations | Converted to `datetime` and minutes in a view (`v_sessions`). |
| Invalid sessions | Removed 2,132 rows with zero energy or zero duration. 18,010 valid sessions remain. |
| Timestamps in UTC | Converted to US Eastern time, with daylight saving time, for hour-of-day analysis. |
| Station renames | The network renamed its stations around August 6, 2021. Old names stop and new names start within the same days at the same addresses. I grouped the 22 station names into 4 physical sites with a lookup table (`dim_site`). |
| Partial years | 2012 starts in April and 2023 has only 3 days. Year trends exclude 2023. |

## Repository structure

```
sql/
  01_load_and_clean.sql   create table, load CSV, clean view
  02_sites.sql            site lookup table + analysis view for Power BI
  03_analysis.sql         one query per business question
data/
  ev_charging_sessions.csv
images/                   dashboard screenshots
```

## How to run

1. Install SQL Server Express and SQL Server Management Studio (SSMS).
2. Run `sql/01_load_and_clean.sql`. Change the file path in the `BULK INSERT` line first.
3. Run `sql/02_sites.sql`.
4. Run `sql/03_analysis.sql`.
5. In Power BI Desktop, connect to `localhost\SQLEXPRESS`, database `EV_Project`, view `v_sessions_enriched`.

## Data source

Town of Cary, North Carolina — Open Data Portal, EV charging station sessions.
<!-- TODO: add the exact dataset URL and license -->
