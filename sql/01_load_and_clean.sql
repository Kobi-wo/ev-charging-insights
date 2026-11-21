/* =====================================================================
   01 - Load and clean
   Source: Town of Cary, NC open data - EV charging sessions (2012-2023)
   Engine: Microsoft SQL Server 2025 Express
   ===================================================================== */

IF DB_ID('EV_Project') IS NULL CREATE DATABASE EV_Project;
GO
USE EV_Project;
GO

-- Raw table: one row per charging session, loaded as-is from the CSV.
IF OBJECT_ID('dbo.ev_sessions') IS NULL
CREATE TABLE dbo.ev_sessions (
    start_date              nvarchar(50),   -- ISO 8601 text in UTC, e.g. 2023-01-03T17:58:04+00:00
    station_name            nvarchar(100),
    charging_time_hh_mm_ss  nvarchar(20),   -- duration as text, e.g. 01:22:28
    energy_kwh              float,
    address_1               nvarchar(100),
    address_2               nvarchar(100),
    city                    nvarchar(50),
    state_province          nvarchar(50),
    zip_postal_code         nvarchar(10)
);
GO

-- Load the CSV (change the path to where you cloned the repo).
-- BULK INSERT dbo.ev_sessions
-- FROM 'C:\path\to\ev-charging-insights\data\ev_charging_sessions.csv'
-- WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001');
GO

-- Clean view: convert text to real types and drop invalid sessions.
-- Why a view: every query and the dashboard get the same clean data. Filter once, reuse.
-- Result: 18,010 valid sessions out of 20,142 rows (2,132 removed for zero energy or zero duration).
CREATE OR ALTER VIEW dbo.v_sessions AS
SELECT
    CAST(LEFT(start_date, 19) AS datetime) AS start_datetime,   -- UTC
    CAST(LEFT(charging_time_hh_mm_ss, CHARINDEX(':', charging_time_hh_mm_ss) - 1) AS int) * 60.0
      + CAST(SUBSTRING(charging_time_hh_mm_ss, CHARINDEX(':', charging_time_hh_mm_ss) + 1, 2) AS int)
      + CAST(RIGHT(charging_time_hh_mm_ss, 2) AS int) / 60.0
      AS charge_minutes,
    energy_kwh,
    station_name,
    city,
    state_province,
    zip_postal_code
FROM dbo.ev_sessions
WHERE energy_kwh > 0                                  -- real power delivered
  AND CAST(LEFT(charging_time_hh_mm_ss, CHARINDEX(':', charging_time_hh_mm_ss) - 1) AS int) * 60.0
      + CAST(SUBSTRING(charging_time_hh_mm_ss, CHARINDEX(':', charging_time_hh_mm_ss) + 1, 2) AS int)
      + CAST(RIGHT(charging_time_hh_mm_ss, 2) AS int) / 60.0 > 0;   -- real duration
GO
