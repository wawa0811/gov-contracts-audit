-- =====================================================================
-- 04_test2_amendment_growth.sql
-- Test 2: Contracts whose value grew far beyond the original award
-- =====================================================================

-- Step 1. Can amendments be matched to their original contract?
WITH c AS (
    SELECT owner_org, procurement_id, COUNT(*) AS n_c
    FROM contracts_clean
    WHERE instrument_type = 'C'
    GROUP BY owner_org, procurement_id
),
a AS (
    SELECT owner_org, procurement_id
    FROM contracts_clean
    WHERE instrument_type = 'A'
)
SELECT
    (SELECT COUNT(*) FROM a)                                    AS n_amendments,
    (SELECT COUNT(*) FROM a JOIN c USING (owner_org, procurement_id)) AS amendments_matched,
    (SELECT SUM(n_c) FROM c
      WHERE procurement_id IS NULL OR procurement_id IN ('', 'NA')) AS contracts_missing_id,
    (SELECT COUNT(*) FROM c WHERE n_c > 1)                      AS duplicate_contract_ids;
	
-- Step 2. Original value vs latest amended value, one row per amended contract
DROP TABLE IF EXISTS t2_growth;

CREATE TABLE t2_growth AS
WITH c AS (
    SELECT
        owner_org,
        procurement_id,
        MIN(owner_org_title)        AS owner_org_title,
        MIN(vendor_name)            AS vendor_name,
        MIN(contract_date)          AS contract_date,
        MIN(commodity_type)         AS commodity_type,
        MIN(solicitation_procedure) AS solicitation_procedure,
        MIN(description_en)         AS description_en,
        MIN(original_value)         AS original_value
    FROM contracts_clean
    WHERE instrument_type = 'C'
    GROUP BY owner_org, procurement_id
    HAVING COUNT(*) = 1
),
a AS (
    SELECT
        owner_org,
        procurement_id,
        contract_value,
        reporting_period,
        ROW_NUMBER() OVER (PARTITION BY owner_org, procurement_id
                           ORDER BY reporting_period DESC, reference_number DESC) AS rn,
        COUNT(*)     OVER (PARTITION BY owner_org, procurement_id)                AS n_amendments
    FROM contracts_clean
    WHERE instrument_type = 'A'
)
SELECT
    c.*,
    a.n_amendments,
    a.contract_value                          AS final_value,
    a.reporting_period                        AS last_amended,
    a.contract_value - c.original_value       AS increase,
    ROUND(a.contract_value / c.original_value, 2) AS growth_ratio
FROM c
JOIN a USING (owner_org, procurement_id)
WHERE a.rn = 1
  AND c.original_value > 0;

-- Check
SELECT
    COUNT(*)                                 AS n_contracts_amended,
    SUM(growth_ratio >= 2)                   AS doubled_or_more,
    SUM(growth_ratio >= 5)                   AS five_times_or_more,
    SUM(final_value < original_value)        AS decreased,
    SUM(final_value <= 0)                    AS final_zero_or_negative,
    ROUND(SUM(increase) / 1e6, 1)            AS net_increase_millions
FROM t2_growth;

-- Step 3. Non-competitive contracts awarded at or below the s.6(b) limit
--         and later amended above it
DROP TABLE IF EXISTS t2_crossed_limit;

CREATE TABLE t2_crossed_limit AS
SELECT
    g.*,
    CASE WHEN g.commodity_type = 'G' THEN 25000 ELSE 40000 END AS limit_value
FROM t2_growth g
WHERE g.solicitation_procedure = 'TN'
  AND g.original_value <= CASE WHEN g.commodity_type = 'G' THEN 25000 ELSE 40000 END
  AND g.final_value    >  CASE WHEN g.commodity_type = 'G' THEN 25000 ELSE 40000 END;

-- Check
SELECT
    (SELECT COUNT(*)
       FROM t2_growth
      WHERE solicitation_procedure = 'TN'
        AND original_value <= CASE WHEN commodity_type = 'G' THEN 25000 ELSE 40000 END)
                                               AS n_tn_below_limit_amended,
    COUNT(*)                                   AS n_crossed_limit,
    ROUND(SUM(original_value) / 1e6, 1)        AS original_millions,
    ROUND(SUM(final_value) / 1e6, 1)           AS final_millions,
    ROUND(AVG(growth_ratio), 1)                AS avg_growth_ratio,
    COUNT(DISTINCT owner_org)                  AS n_departments
FROM t2_crossed_limit;

-- Step 4. Departments with the most contracts amended above the limit
SELECT
    owner_org_title,
    COUNT(*)                              AS n_crossed_limit,
    ROUND(SUM(original_value) / 1e6, 2)   AS original_millions,
    ROUND(SUM(final_value) / 1e6, 2)      AS final_millions,
    ROUND(MAX(growth_ratio), 1)           AS max_growth_ratio
FROM t2_crossed_limit
GROUP BY owner_org
ORDER BY n_crossed_limit DESC
LIMIT 10;

-- =====================================================================
-- Test 2 results (contracts awarded 2022-01-01 to 2026-10-24)
-- =====================================================================
-- Amendments: 67,927; matched to a 2022+ contract: 48,671 (71.7%)
-- Procurement IDs used by more than one contract in a department: 860 (excluded)
-- Amended contracts analysed: 31,887
--   Doubled or more: 10,149 (31.8%); five times or more: 1,559
--   Decreased: 7,353; final value zero or negative: 1,078 (likely reporting errors)
--   Net increase from amendments: $16,354.4M
-- Non-competitive contracts awarded at or below the s.6(b) limit and later amended: 3,964
--   Amended above the limit: 1,126 (28.4%) across 65 departments
--   Value grew from $30.0M at award to $90.8M (average growth ratio 3.3x)
-- Most contracts amended above the limit: Global Affairs Canada (108),
--   National Research Council (93), Fisheries and Oceans (88),
--   Correctional Service of Canada (66), PSPC (64)
-- Largest single growth ratio: National Defence, 151x the original value
-- Limitations: amendments matched by