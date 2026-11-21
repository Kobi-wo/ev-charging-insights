# EV Charging Customer Insights — Town of Cary, NC

An analysis of 10 years of public EV charging sessions. The goal: understand how customers use the charging network, where demand is growing, and what the network operator should do next.

**Tools:** Microsoft SQL Server (T-SQL), Power BI, Git/GitHub
**Data:** 20,142 charging sessions, April 2012 – January 2023, Town of Cary Open Data (see [Data source](#data-source))

---

## Business questions

1. How fast is EV charging demand growing?
2. Which sites carry the load?
3. When do customers charge, and did that change as demand grew?
4. How long do customers stay, and how much energy do they take?
5. What should the operator do next?

## Key findings

**1. Demand grew 20× in five years.**
Sessions rose from 297 in 2017 to 5,907 in 2022. The growth came in two stages:

- **2018–2020: new sites.** 2018 was Bond Park's first full year (opened September 2017), and 2020 was the downtown deck's first full year (opened late 2019). Most early growth came from more places to charge.
- **2021–2022: more demand at the same sites.** No new sites opened, but use kept growing — the deck rose 62% and Town Hall 65% in 2022. This is true demand growth on about 10 chargers.

| Year | Sessions | Energy (kWh) | Growth |
|------|---------:|-------------:|-------:|
| 2018 | 1,080 | 6,553 | +264% |
| 2019 | 1,870 | 15,386 | +73% |
| 2020 | 3,486 | 33,312 | +86% |
| 2021 | 4,322 | 40,712 | +24% |
| 2022 | 5,907 | 58,040 | +37% |

**2. Two sites carry 84% of sessions.**
In 2022, the Downtown Parking Deck had 49% of sessions and Bond Park Boathouse had 35%. Town Hall customers stay longer (153 min on average) and take more energy per visit (13 kWh).

**3. The 4–6 PM peak faded as demand grew.**
Across all years, 20% of sessions start between 4 and 6 PM (local time). But that number comes mostly from the early years: in 2017, 48% of sessions started then. From 2019 on, only about 16% do, and demand spreads across the day.

| Year | 6–10 AM | 10 AM–4 PM | 4–6 PM | 6–10 PM |
|---|---:|---:|---:|---:|
| 2017 | 17% | 28% | 48% | 6% |
| 2019 | 24% | 49% | 16% | 10% |
| 2022 | 21% | 43% | 16% | 17% |

Evening charging (6–10 PM) doubled from about 10% to about 20% starting in 2020. Note: these numbers count session *starts*. A session that starts at 3 PM still draws power during the 4–6 PM grid peak.

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

**6. Floor level drives demand in the parking deck — and outages make it look bigger.**
In 2022, each charger on floors 2–3 had about 1.7–1.9 sessions per day, and floors 5–6 had less than 0.2. But the upper-floor chargers were also silent for long periods (see finding 7). Counting only the days a charger was likely working, floors 2–3 still get about **6 times** more use than floors 5–6 (about 1.8 vs 0.3 sessions per day). Customers on high floors also stay longer and take more energy (16–24 kWh vs about 9 kWh), which suggests long-stay parkers.

| Deck floor | Sessions per day (all days) | Sessions per day (likely working days) |
|---|---:|---:|
| 2 | 0.59–2.37 | 0.77–2.63 |
| 3 | 0.73–1.71 | 1.10–1.88 |
| 4 | 0.35 | 0.46 |
| 5 | 0.10 | 0.26 |
| 6 | 0.09 | 0.37 |

**7. Some chargers were likely out of service for months.**
The data has no status records, so outages cannot be confirmed. But a busy charger that goes silent for months is most likely down. I flagged a gap as a *likely outage* when it was 30+ days **and** at least 10 times the charger's normal gap between uses.

- **Deck P5 and P6** were silent 62–77% of their time in service. When they did work, customers used them every 2–4 days.
- **Deck P3 East** was silent for 388 days (May 2021 – June 2022), and **Deck P2-1** for 244 days.
- **Ops Center** was a steady weekday charger (about 200 sessions a year, 2012–2018). From mid-2019 it had five gaps of 68–133 days, and it stopped in December 2021. Its decline came mostly from downtime, not from a lack of drivers. (Some 2020 gaps also match the COVID lockdown.)

## Recommendations

These follow from the findings. They are proposals to test, not proven results.

1. **Watch the evening shift.** Evening charging doubled after 2020. Measure how much charging is *in progress* during the 4–6 PM grid peak before designing off-peak pricing or managed charging.
2. **Expand downtown first — on the lower floors.** The deck carries half the network's demand and has the highest daily peaks. New chargers on floors 2–3 should get far more use than chargers on floors 5–6. Better signs to the upper-floor chargers are a low-cost test.
3. **Manage long sessions.** A time limit or an idle fee after charging ends can free ports for more customers. (This data records charging time only, not total plug-in time — a next step is to get plug-in data to measure idle time directly.)
4. **Plan Bond Park around weekends.** Schedule maintenance on weekdays.
5. **Track charger uptime.** Measure the % of days each charger works, and alert when a normally busy charger has no sessions for 2+ weeks. Long outages lose customers, and the upper-floor chargers lose the most.

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
