-- =====================================================================
-- 05_test3_noncompetitive_concentration.sql
-- Test 3: Share of each department's contracts awarded without competition
-- =====================================================================

-- Step 1. Non-competitive share by department
DROP TABLE IF EXISTS t3_department;

CREATE TABLE t3_department AS
SELECT
    owner_org,
    owner_org_title,
    COUNT(*)                                                    AS n_contracts,
    SUM(solicitation_procedure = 'TN')                          AS n_noncompetitive,
    ROUND(100.0 * SUM(solicitation_procedure = 'TN') / COUNT(*), 1) AS pct_count,
    ROUND(SUM(original_value) / 1e6, 1)                         AS total_millions,
    ROUND(SUM(CASE WHEN solicitation_procedure = 'TN'
                   THEN original_value ELSE 0 END) / 1e6, 1)    AS noncompetitive_millions,
    ROUND(100.0 * SUM(CASE WHEN solicitation_procedure = 'TN'
                           THEN original_value ELSE 0 END)
                / SUM(original_value), 1)                       AS pct_value
FROM contracts_clean
WHERE instrument_type = 'C'
  AND original_value > 0
GROUP BY owner_org;

-- Check: departments with at least 500 contracts, highest non-competitive share of value
SELECT owner_org_title, n_contracts, pct_count, total_millions,
       noncompetitive_millions, pct_value
FROM t3_department
WHERE n_contracts >= 500
ORDER BY pct_value DESC
LIMIT 15;

-- Step 2. Vendors receiving the most non-competitive contract value
WITH tn AS (
    SELECT
        vendor_key,
        MIN(vendor_name)            AS vendor_name,
        COUNT(*)                    AS n_contracts,
        COUNT(DISTINCT owner_org)   AS n_departments,
        SUM(original_value)         AS value
    FROM contracts_clean
    WHERE instrument_type = 'C'
      AND solicitation_procedure = 'TN'
      AND original_value > 0
    GROUP BY vendor_key
),
totals AS (
    SELECT
        (SELECT SUM(value) FROM tn) AS tn_total,
        (SELECT SUM(original_value)
           FROM contracts_clean
          WHERE instrument_type = 'C' AND original_value > 0) AS all_total
)
SELECT
    vendor_name,
    n_contracts,
    n_departments,
    ROUND(value / 1e6, 1)                                      AS value_millions,
    ROUND(100.0 * value / tn_total, 1)                         AS pct_of_noncompetitive,
    ROUND(SUM(100.0 * value / tn_total) OVER (ORDER BY value DESC), 1) AS cumulative_pct,
    ROUND(100.0 * tn_total / all_total, 1)                     AS govt_wide_pct_noncompetitive
FROM tn, totals
ORDER BY value DESC
LIMIT 15;

-- =====================================================================
-- Test 3 results (new contracts awarded 2022-01-01 to 2026-10-24)
-- =====================================================================
-- Government-wide, 20.9% of contract value was awarded non-competitively (TN)
-- Highest non-competitive share of value (departments with 500+ contracts):
--   Privy Council Office 58.1%, Statistics Canada 53.0%,
--   Treasury Board Secretariat 51.2%, Justice 46.5%,
--   Canadian Food Inspection Agency 40.0%
-- Vendor concentration of non-competitive value:
--   Top 3 vendors (CAE Military Aviation Training, Bell Textron Canada,
--   Leonardo UK) hold 37.7% with 1 to 2 contracts each
--   Top 15 vendors hold 57.5%, mostly defence and IT suppliers
-- Limitations: vendor names are not standardized across spellings
--   (e.g., GD OTS C, General Dynamics, General Dynamics Ordnance and Tactical);
--   non-competitive awards can be justified (e.g., only one capable supplier),
--   so a high share is a prompt for review, not evidence of non-compliance.