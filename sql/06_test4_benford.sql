-- =====================================================================
-- 06_test4_benford.sql
-- Test 4: First-digit distribution of contract values vs Benford's Law
-- =====================================================================

-- Step 1. Government-wide first-digit distribution
DROP TABLE IF EXISTS t4_benford;

CREATE TABLE t4_benford AS
WITH d AS (
    SELECT CAST(SUBSTR(CAST(CAST(original_value AS INTEGER) AS TEXT), 1, 1) AS INTEGER) AS digit
    FROM contracts_clean
    WHERE instrument_type = 'C'
      AND original_value >= 1
),
c AS (
    SELECT digit, COUNT(*) AS n
    FROM d
    WHERE digit BETWEEN 1 AND 9
    GROUP BY digit
)
SELECT
    digit,
    n                                        AS n_contracts,
    ROUND(100.0 * n / (SELECT SUM(n) FROM c), 1) AS actual_pct,
    CASE digit
        WHEN 1 THEN 30.1 WHEN 2 THEN 17.6 WHEN 3 THEN 12.5
        WHEN 4 THEN 9.7  WHEN 5 THEN 7.9  WHEN 6 THEN 6.7
        WHEN 7 THEN 5.8  WHEN 8 THEN 5.1  ELSE 4.6
    END                                      AS expected_pct
FROM c;

-- Check
SELECT
    digit,
    n_contracts,
    actual_pct,
    expected_pct,
    ROUND(actual_pct - expected_pct, 1) AS difference
FROM t4_benford
ORDER BY digit;

-- Step 2. Departments whose first-digit pattern differs most from the government-wide pattern
WITH d AS (
    SELECT
        owner_org,
        owner_org_title,
        CAST(SUBSTR(CAST(CAST(original_value AS INTEGER) AS TEXT), 1, 1) AS INTEGER) AS digit
    FROM contracts_clean
    WHERE instrument_type = 'C'
      AND original_value >= 1
),
dept AS (
    SELECT owner_org, MIN(owner_org_title) AS owner_org_title, digit, COUNT(*) AS n
    FROM d
    GROUP BY owner_org, digit
),
dept_total AS (
    SELECT owner_org, SUM(n) AS total
    FROM dept
    GROUP BY owner_org
    HAVING SUM(n) >= 1000
)
SELECT
    MIN(dept.owner_org_title)                                          AS owner_org_title,
    dept_total.total                                                   AS n_contracts,
    ROUND(AVG(ABS(100.0 * dept.n / dept_total.total - g.actual_pct)), 2) AS mad_vs_government,
    ROUND(MAX(CASE WHEN dept.digit = 1 THEN 100.0 * dept.n / dept_total.total END), 1) AS pct_digit_1,
    ROUND(MAX(CASE WHEN dept.digit = 2 THEN 100.0 * dept.n / dept_total.total END), 1) AS pct_digit_2,
    ROUND(MAX(CASE WHEN dept.digit = 3 THEN 100.0 * dept.n / dept_total.total END), 1) AS pct_digit_3
FROM dept
JOIN dept_total USING (owner_org)
JOIN t4_benford g USING (digit)
GROUP BY dept.owner_org
ORDER BY mad_vs_government DESC
LIMIT 10;

-- =====================================================================
-- Test 4 results (new contracts awarded 2022-01-01 to 2026-10-24)
-- =====================================================================
-- Government-wide first digits vs Benford's Law:
--   digit 1: 43.9% actual vs 30.1% expected (+13.8)
--   digit 2: 22.5% vs 17.6% (+4.9); digit 3: 12.7% vs 12.5% (+0.2)
--   digits 4 to 9 all below expectation (-2.1 to -4.0)
-- The excess of 1s reflects the $10,000 reporting floor: most contracts sit
--   between $10,000 and $19,999, so the full dataset does not meet Benford's
--   assumptions. Departments were therefore compared with the government-wide
--   pattern instead (mean absolute deviation, departments with 1,000+ contracts).
-- Largest deviation: Immigration and Refugee Board, MAD 5.78
--   (next: Crown-Indigenous