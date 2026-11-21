/* =====================================================================
   03 - Analysis queries
   Each query answers one business question. Results feed the README findings.
   ===================================================================== */
USE EV_Project;
GO

-- Q0. Data check: each raw station name, the clean charger it maps to, and when it was used.
-- Read it per charger: the old name's last_use should be just before the new name's first_use.
SELECT d.site_name, c.charger_name, r.station_name,
       MIN(CONVERT(date, LEFT(r.start_date, 10))) AS first_use,
       MAX(CONVERT(date, LEFT(r.start_date, 10))) AS last_use,
       COUNT(*) AS sessions
FROM dbo.ev_sessions r
JOIN dbo.dim_site d    ON d.address_1    = r.address_1
JOIN dbo.dim_charger c ON c.station_name = r.station_name
GROUP BY d.site_name, c.charger_name, r.station_name
ORDER BY d.site_name, c.charger_name, first_use;

-- Q1. How has demand grown? (2023 has only 3 days of data - exclude it from trends.)
SELECT YEAR(start_local)                  AS yr,
       COUNT(*)                           AS sessions,
       CAST(SUM(energy_kwh) AS int)       AS total_kwh,
       CAST(AVG(charge_minutes) AS int)   AS avg_minutes,
       COUNT(DISTINCT site_name)          AS active_sites,
       COUNT(DISTINCT charger_name)       AS active_chargers
       -- Not COUNT(DISTINCT station_name): stations were renamed in Aug 2021,
       -- so 2021 would count each charger twice (old name + new name).
FROM dbo.v_sessions_enriched
WHERE YEAR(start_local) < 2023
GROUP BY YEAR(start_local)
ORDER BY yr;

-- Q2. Year-over-year growth in sessions.
WITH y AS (
    SELECT YEAR(start_local) AS yr, COUNT(*) AS sessions
    FROM dbo.v_sessions_enriched
    WHERE YEAR(start_local) < 2023
    GROUP BY YEAR(start_local)
)
SELECT yr, sessions,
       LAG(sessions) OVER (ORDER BY yr) AS prior_year,
       CAST(100.0 * (sessions - LAG(sessions) OVER (ORDER BY yr))
            / NULLIF(LAG(sessions) OVER (ORDER BY yr), 0) AS decimal(6,1)) AS pct_growth
FROM y
ORDER BY yr;

-- Q3. Which sites carry the load? (2022 = last full year)
SELECT site_name,
       COUNT(*)                                              AS sessions,
       CAST(SUM(energy_kwh) AS int)                          AS total_kwh,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,1)) AS pct_of_sessions,
       CAST(AVG(energy_kwh) AS decimal(5,1))                 AS avg_kwh,
       CAST(AVG(charge_minutes) AS int)                      AS avg_minutes
FROM dbo.v_sessions_enriched
WHERE YEAR(start_local) = 2022
GROUP BY site_name
ORDER BY sessions DESC;

-- Q4. When do customers charge? Sessions by local hour of day.
SELECT DATEPART(hour, start_local) AS hour_local,
       COUNT(*)                    AS sessions,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(4,1)) AS pct
FROM dbo.v_sessions_enriched
GROUP BY DATEPART(hour, start_local)
ORDER BY hour_local;

-- Q5. Weekday vs weekend, by site.
SELECT site_name,
       CASE WHEN DATENAME(weekday, start_local) IN ('Saturday','Sunday') THEN 'Weekend' ELSE 'Weekday' END AS day_type,
       COUNT(*) AS sessions,
       CAST(1.0 * COUNT(*) / COUNT(DISTINCT CAST(start_local AS date)) AS decimal(4,1)) AS sessions_per_active_day
FROM dbo.v_sessions_enriched
WHERE YEAR(start_local) = 2022
GROUP BY site_name,
         CASE WHEN DATENAME(weekday, start_local) IN ('Saturday','Sunday') THEN 'Weekend' ELSE 'Weekday' END
ORDER BY site_name, day_type;

-- Q6. Session length segments: how long do customers charge, and how much energy do they take?
SELECT CASE WHEN charge_minutes < 60  THEN '1. Under 1 hour'
            WHEN charge_minutes < 180 THEN '2. 1-3 hours'
            WHEN charge_minutes < 480 THEN '3. 3-8 hours'
            ELSE                           '4. 8+ hours' END       AS segment,
       COUNT(*)                                                     AS sessions,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(4,1)) AS pct_sessions,
       CAST(SUM(energy_kwh) AS int)                                 AS total_kwh,
       CAST(100.0 * SUM(energy_kwh) / SUM(SUM(energy_kwh)) OVER () AS decimal(4,1)) AS pct_kwh
FROM dbo.v_sessions_enriched
GROUP BY CASE WHEN charge_minutes < 60  THEN '1. Under 1 hour'
              WHEN charge_minutes < 180 THEN '2. 1-3 hours'
              WHEN charge_minutes < 480 THEN '3. 3-8 hours'
              ELSE                           '4. 8+ hours' END
ORDER BY segment;

-- Q7. Busiest days: how close do sites get to capacity? Top 10 days by sessions, per site.
WITH d AS (
    SELECT site_name, CAST(start_local AS date) AS day_, COUNT(*) AS sessions,
           ROW_NUMBER() OVER (PARTITION BY site_name ORDER BY COUNT(*) DESC) AS rn
    FROM dbo.v_sessions_enriched
    GROUP BY site_name, CAST(start_local AS date)
)
SELECT site_name, day_, sessions FROM d WHERE rn <= 3 ORDER BY site_name, sessions DESC;

-- Q8. What makes a charger popular? Floor level in the downtown deck (2022 = all floors open).
-- Charger names look like 'Deck P3 West', so character 7 is the floor number.
-- Note: P3 East opened mid-2022 and P2-1 stopped in Aug 2022, so dividing by 365
-- makes floors 2-3 look slightly LESS busy than they were. The real gap is even bigger.
WITH deck AS (
    SELECT CAST(SUBSTRING(charger_name, 7, 1) AS int) AS floor_level,
           charger_name, start_local, energy_kwh, charge_minutes
    FROM dbo.v_sessions_enriched
    WHERE site_name = 'Downtown Parking Deck'
)
SELECT floor_level,
       COUNT(DISTINCT charger_name)                                        AS chargers,
       COUNT(*)                                                            AS sessions,
       CAST(1.0 * COUNT(*) / COUNT(DISTINCT charger_name) / 365 AS decimal(4,2)) AS sessions_per_charger_day,
       CAST(AVG(energy_kwh) AS decimal(4,1))                               AS avg_kwh,
       CAST(AVG(charge_minutes) AS int)                                    AS avg_minutes
FROM deck
WHERE YEAR(start_local) = 2022
GROUP BY floor_level
ORDER BY floor_level;

-- Q8b. Floor check with outages removed: sessions per LIKELY WORKING day.
-- Uses the same outage rule as Q9 (gap of 30+ days AND 10x the charger's median gap).
-- Result: the floor effect is still real, but smaller (about 6x, not 10x).
WITH days_used AS (
    SELECT charger_name, CAST(start_local AS date) AS d, COUNT(*) AS n
    FROM dbo.v_sessions_enriched
    WHERE site_name = 'Downtown Parking Deck'
    GROUP BY charger_name, CAST(start_local AS date)
),
g AS (
    SELECT charger_name, d, n,
           DATEDIFF(day, LAG(d) OVER (PARTITION BY charger_name ORDER BY d), d) AS gap
    FROM days_used
),
m AS (
    SELECT DISTINCT charger_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap) OVER (PARTITION BY charger_name) AS median_gap
    FROM g WHERE gap IS NOT NULL
),
c AS (
    SELECT g.charger_name, SUM(n) AS sessions,
           DATEDIFF(day, MIN(d), MAX(d)) AS window_days,
           ISNULL(SUM(CASE WHEN gap >= 30 AND gap >= 10 * median_gap THEN gap END), 0) AS outage_days
    FROM g JOIN m ON m.charger_name = g.charger_name
    GROUP BY g.charger_name
)
SELECT CAST(SUBSTRING(charger_name, 7, 1) AS int) AS floor_level, charger_name, sessions,
       window_days, outage_days,
       CAST(100.0 * outage_days / window_days AS decimal(4,1))               AS pct_likely_down,
       CAST(1.0 * sessions / window_days AS decimal(4,2))                    AS per_day_all,
       CAST(1.0 * sessions / NULLIF(window_days - outage_days, 0) AS decimal(4,2)) AS per_working_day
FROM c
ORDER BY floor_level, charger_name;

-- Q9. Likely outages: unusually long gaps with no sessions, for every charger.
-- ASSUMPTION: the data has no status records, so it cannot confirm an outage.
-- A gap counts as a "likely outage" only if BOTH are true:
--   1. it lasts 30+ days, and
--   2. it is at least 10x the charger's normal gap between days of use.
-- Why rule 2: a busy charger is used almost every day, so 30 days of silence is unusual.
-- A rarely used charger (Deck P5/P6, ~1 use every 10 days) can go 30 days with no
-- customers just from low demand. Both thresholds are judgment calls, not standards.
-- Note: gaps in March-May 2020 also match the COVID lockdown, not only outages.
WITH days_used AS (
    SELECT charger_name, CAST(start_local AS date) AS day_used
    FROM dbo.v_sessions_enriched
    GROUP BY charger_name, CAST(start_local AS date)
),
gaps AS (
    SELECT charger_name,
           LAG(day_used) OVER (PARTITION BY charger_name ORDER BY day_used) AS last_use_before_gap,
           day_used AS first_use_after_gap,
           DATEDIFF(day, LAG(day_used) OVER (PARTITION BY charger_name ORDER BY day_used), day_used) AS gap_days
    FROM days_used
),
normal AS (   -- median gap = the charger's typical wait between days of use
    SELECT DISTINCT charger_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days) OVER (PARTITION BY charger_name) AS median_gap
    FROM gaps
    WHERE gap_days IS NOT NULL
)
SELECT g.charger_name, g.last_use_before_gap, g.first_use_after_gap, g.gap_days,
       n.median_gap AS normal_gap_days
FROM gaps g
JOIN normal n ON n.charger_name = g.charger_name
WHERE g.gap_days >= 30
  AND g.gap_days >= 10 * n.median_gap
ORDER BY g.charger_name, g.last_use_before_gap;

-- Q10. Ops Center decline: who used it, and how did that change?
SELECT YEAR(start_local) AS yr, charger_name,
       COUNT(*)                                                     AS sessions,
       CAST(AVG(energy_kwh) AS decimal(4,1))                        AS avg_kwh,
       CAST(100.0 * SUM(CASE WHEN DATENAME(weekday, start_local) IN ('Saturday','Sunday') THEN 1 ELSE 0 END)
            / COUNT(*) AS int)                                      AS pct_weekend
FROM dbo.v_sessions_enriched
WHERE site_name = 'Operations Center'
GROUP BY YEAR(start_local), charger_name
ORDER BY yr, charger_name;
