-- =====================================================================
-- 08_dept_scorecard.sql
-- One row per department combining the results of all five tests
-- =====================================================================

DROP TABLE IF EXISTS dept_scorecard;

CREATE TABLE dept_scorecard AS
WITH split AS (
    SELECT owner_org, COUNT(*) AS split_groups, SUM(n_contracts) AS split_contracts
    FROM t1_same_day
    GROUP BY owner_org
),
below AS (
    SELECT owner_org, COUNT(*) AS n_below_limit
    FROM t1_below_limit
    GROUP BY owner_org
),
crossed AS (
    SELECT owner_org, COUNT(*) AS crossed_limit
    FROM t2_crossed_limit
    GROUP BY owner_org
),
dup AS (
    SELECT owner_org, SUM(n_records - 1) AS duplicate_records
    FROM t5_duplicates
    WHERE n_procurement_ids = 1
    GROUP BY owner_org
),
digits AS (
    SELECT owner_org,
           CAST(SUBSTR(CAST(CAST(original_value AS INTEGER) AS TEXT), 1, 1) AS INTEGER) AS digit
    FROM contracts_clean
    WHERE instrument_type = 'C'
      AND original_value >= 1
),
dd AS (
    SELECT owner_org, digit, COUNT(*) AS n
    FROM digits
    GROUP BY owner_org, digit
),
dt AS (
    SELECT owner_org, SUM(n) AS total
    FROM dd
    GROUP BY owner_org
),
mad AS (
    SELECT dd.owner_org,
           ROUND(AVG(ABS(100.0 * dd.n / dt.total - g.actual_pct)), 2) AS benford_mad
    FROM dd
    JOIN dt USING (owner_org)
    JOIN t4_benford g USING (digit)
    GROUP BY dd.owner_org
)
SELECT
    d.owner_org,
    CASE WHEN INSTR(d.owner_org_title, ' | ') > 0
         THEN SUBSTR(d.owner_org_title, 1, INSTR(d.owner_org_title, ' | ') - 1)
         ELSE d.owner_org_title
    END                                         AS department,
    d.n_contracts,
    d.total_millions,
    d.pct_value                                 AS pct_noncompetitive_value,
    d.pct_count                                 AS pct_noncompetitive_count,
    COALESCE(b.n_below_limit, 0)                AS n_below_limit,
    COALESCE(s.split_groups, 0)                 AS split_groups,
    COALESCE(s.split_contracts, 0)              AS split_contracts,
    ROUND(100.0 * COALESCE(s.split_contracts, 0) / NULLIF(b.n_below_limit, 0), 1)
                                                AS pct_below_limit_split,
    COALESCE(c.crossed_limit, 0)                AS crossed_limit,
    COALESCE(u.duplicate_records, 0)            AS duplicate_records,
    m.benford_mad
FROM t3_department d
LEFT JOIN below   b ON b.owner_org = d.owner_org
LEFT JOIN split   s ON s.owner_org = d.owner_org
LEFT JOIN crossed c ON c.owner_org = d.owner_org
LEFT JOIN dup     u ON u.owner_org = d.owner_org
LEFT JOIN mad     m ON m.owner_org = d.owner_org;

-- Check: totals should match the individual tests
SELECT
    COUNT(*)                AS n_departments,
    SUM(n_contracts)        AS n_contracts,
    SUM(split_groups)       AS split_groups,
    SUM(crossed_limit)      AS crossed_limit,
    SUM(duplicate_records)  AS duplicate_records
FROM dept_scorecard;

-- Vendors ranked by non-competitive contract value (for the dashboard)
DROP TABLE IF EXISTS t3_vendors;

CREATE TABLE t3_vendors AS
SELECT
    vendor_key,
    MIN(vendor_name)              AS vendor_name,
    COUNT(*)                      AS n_contracts,
    COUNT(DISTINCT owner_org)     AS n_departments,
    ROUND(SUM(original_value) / 1e6, 1) AS value_millions
FROM contracts_clean
WHERE instrument_type = 'C'
  AND solicitation_procedure = 'TN'
  AND original_value > 0
GROUP BY vendor_key
ORDER BY SUM(original_value) DESC;

-- =====================================================================
-- Scorecard check results
-- =====================================================================
-- 94 departments, 272,848 new contracts with a positive value
-- Totals match the individual tests: 1,487 same-day split groups,
--   1,126 contracts amended above the limit, 340 same-ID duplicate records