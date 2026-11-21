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

-- Analysis view: clean sessions + site + local (Eastern) time.
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
    d.site_name,
    d.site_type
FROM dbo.ev_sessions r
JOIN dbo.dim_site d ON d.address_1 = r.address_1
WHERE r.energy_kwh > 0
  AND CAST(LEFT(r.charging_time_hh_mm_ss, CHARINDEX(':', r.charging_time_hh_mm_ss) - 1) AS int) * 60.0
      + CAST(SUBSTRING(r.charging_time_hh_mm_ss, CHARINDEX(':', r.charging_time_hh_mm_ss) + 1, 2) AS int)
      + CAST(RIGHT(r.charging_time_hh_mm_ss, 2) AS int) / 60.0 > 0;
GO
