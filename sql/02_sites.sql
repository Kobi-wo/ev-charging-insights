/* =====================================================================
   02 - Site lookup table
   Problem: the charger network renamed its stations around 2021-08-06.
   The data has 22 station names, but they belong to only 4 physical sites.
   Evidence: old names stop and new names start within the same days,
   and the street addresses match (see 03_analysis.sql, query 0).
   ===================================================================== */
USE EV_Project;
GO

IF OBJECT_ID('dbo.dim_site') IS NULL
CREATE TABLE dbo.dim_site (
    address_1  nvarchar(100) PRIMARY KEY,
    site_name  nvarchar(50)  NOT NULL,
    site_type  nvarchar(30)  NOT NULL
);
GO

MERGE dbo.dim_site AS t
USING (VALUES
    (N'113 Walnut St',          N'Downtown Parking Deck', N'Parking deck'),
    (N'117 E Park St',          N'Downtown Parking Deck', N'Parking deck'),
    (N'119 E Park St',          N'Downtown Parking Deck', N'Parking deck'),
    (N'228 Ambassador Loop',    N'Town Hall',             N'Civic building'),
    (N'400 James Jackson Ave',  N'Operations Center',     N'Civic building'),
    (N'801 High House Road',    N'Bond Park Boathouse',   N'Park')
) AS s (address_1, site_name, site_type)
ON t.address_1 = s.address_1
WHEN MATCHED THEN UPDATE SET site_name = s.site_name, site_type = s.site_type
WHEN NOT MATCHED THEN INSERT VALUES (s.address_1, s.site_name, s.site_type);
GO

-- Charger lookup: one clear name per physical charger.
-- Each charger had an old name (before 2021-08-06) and a new name (after).
-- Match rule: same address, old name stops and new name starts within days.
-- match_note says how sure the match is.
IF OBJECT_ID('dbo.dim_charger') IS NULL
CREATE TABLE dbo.dim_charger (
    station_name  nvarchar(100) PRIMARY KEY,   -- name as it appears in the raw data
    charger_name  nvarchar(50)  NOT NULL,      -- clean name used in analysis
    match_note    nvarchar(200) NOT NULL
);
GO

MERGE dbo.dim_charger AS t
USING (VALUES
    -- Bond Park Boathouse
    (N'TOWN OF CARY / BOND PARK',        N'Bond Park',        N'Old name; new name starts same day (2021-08-06)'),
    (N'TOWN OF CARY / BOND PARK BH',     N'Bond Park',        N'New name'),
    -- Downtown Parking Deck (old "Pn_DTCARY..." names -> new "DT DECK Pn" names)
    (N'TOWN OF CARY / P2_DTCARYDECKE1',  N'Deck P2-1',        N'Old name; gap before new name (2021-05 to 2022-01) - likely, not certain'),
    (N'TOWN OF CARY / DT DECK P2 (1)',   N'Deck P2-1',        N'New name'),
    (N'TOWN OF CARY / P2_DTCARYDEKCE2',  N'Deck P2-2',        N'Old name; new name starts next day'),
    (N'TOWN OF CARY / DT DECK P2 (2)',   N'Deck P2-2',        N'New name'),
    (N'TOWN OF CARY / P3_DTCARYDECKE',   N'Deck P3 East',     N'Old name; matches floor and side'),
    (N'TOWN OF CARY / DT DECK P3 EAST',  N'Deck P3 East',     N'New name'),
    (N'TOWN OF CARY / P3_DTCARYDECKW',   N'Deck P3 West',     N'Old name; new name starts within weeks'),
    (N'TOWN OF CARY / DT DECK P3 WEST',  N'Deck P3 West',     N'New name'),
    (N'TOWN OF CARY / P4_DTCARDECKE',    N'Deck P4',          N'Old name; matches floor'),
    (N'TOWN OF CARY / DT DECK P4',       N'Deck P4',          N'New name'),
    (N'TOWN OF CARY / P5_DTCARYDECKE',   N'Deck P5',          N'Old name; matches floor'),
    (N'TOWN OF CARY / DT DECK P5',       N'Deck P5',          N'New name'),
    (N'TOWN OF CARY / P6_DTCARYDECKE',   N'Deck P6',          N'Old name; matches floor'),
    (N'TOWN OF CARY / DT DECK P6',       N'Deck P6',          N'New name'),
    -- Town Hall
    (N'TOWN OF CARY / TOWNHALLEAST',     N'Town Hall',        N'Old name; same address, new name starts 3 days later'),
    (N'TOWN OF CARY / TOWN HALL-PWH',    N'Town Hall',        N'New name'),
    -- Operations Center
    (N'TOWN OF CARY / CHARGER #1',       N'Ops Center',       N'Old name; new name starts 7 days later'),
    (N'TOWN OF CARY / OPS CENTER',       N'Ops Center',       N'New name'),
    (N'TOWN OF CARY / TOWNOFCARY1',      N'Ops Center Fast',  N'ASSUMPTION: separate DC fast charger (34 kWh in 45 min avg), added 2022'),
    (N'TOWN OF CARY / OFF NETWORK 1',    N'Ops Center Other', N'ASSUMPTION: 1 session only; unknown unit')
) AS s (station_name, charger_name, match_note)
ON t.station_name = s.station_name
WHEN MATCHED THEN UPDATE SET charger_name = s.charger_name, match_note = s.match_note
WHEN NOT MATCHED THEN INSERT VALUES (s.station_name, s.charger_name, s.match_note);
GO

-- Analysis view: clean sessions + site + charger + local (Eastern) time.
-- This is the view the Power BI dashboard connects to.
CREATE OR ALTER VIEW dbo.v_sessions_enriched AS
SELECT
    CAST(CAST(LEFT(r.start_date, 19) AS datetime)
         AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time' AS datetime) AS start_local,
    CAST(LEFT(r.charging_time_hh_mm_ss, CHARINDEX(':', r.charging_time_hh_mm_ss) - 1) AS int) * 60.0
      + CAST(SUBSTRING(r.charging_time_hh_mm_ss, CHARINDEX(':', r.charging_time_hh_mm_ss) + 1, 2) AS int)
      + CAST(RIGHT(r.charging_time_hh_mm_ss, 2) AS int) / 60.0 AS charge_minutes,
    r.energy_kwh,
    r.station_name,
    c.charger_name,
    d.site_name,
    d.site_type
FROM dbo.ev_sessions r
JOIN dbo.dim_site d    ON d.address_1    = r.address_1
JOIN dbo.dim_charger c ON c.station_name = r.station_name
WHERE r.energy_kwh > 0
  AND CAST(LEFT(r.charging_time_hh_mm_ss, CHARINDEX(':', r.charging_time_hh_mm_ss) - 1) AS int) * 60.0
      + CAST(SUBSTRING(r.charging_time_hh_mm_ss, CHARINDEX(':', r.charging_time_hh_mm_ss) + 1, 2) AS int)
      + CAST(RIGHT(r.charging_time_hh_mm_ss, 2) AS int) / 60.0 > 0;
GO
