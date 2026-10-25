-- =====================================================================
-- 03_test1_contract_splitting.sql
-- Test 1: Contract splitting below the s.6(b) non-competitive limits
-- =====================================================================

-- Step 1. How are non-competitive contracts recorded?
SELECT
    solicitation_procedure,
    article_6_exceptions,
    typeof(article_6_exceptions)          AS stored_as,
    COUNT(*)                              AS n_contracts,
    ROUND(SUM(original_value) / 1e6, 1)   AS value_millions
FROM contracts_clean
WHERE instrument_type = 'C'
GROUP BY solicitation_procedure, article_6_exceptions
ORDER BY n_contracts DESC;

-- Step 2. Non-competitive contracts at or below the s.6(b) limit
DROP TABLE IF EXISTS t1_below_limit;

CREATE TABLE t1_below_limit AS
SELECT
    reference_number,
    procurement_id,
    owner_org,
    owner_org_title,
    vendor_name,
    vendor_key,
    contract_date,
    commodity_type,
    description_en,
    original_value,
    CASE WHEN commodity_type = 'G' THEN 25000 ELSE 40000 END AS limit_value
FROM contracts_clean
WHERE instrument_type = 'C'
  AND solicitation_procedure = 'TN'
  AND original_value > 0
  AND original_value <= CASE WHEN commodity_type = 'G' THEN 25000 ELSE 40000 END;

CREATE INDEX idx_t1_org_vendor_date
    ON t1_below_limit (owner_org, vendor_key, contract_date);

-- Check
SELECT
    commodity_type,
    limit_value,
    COUNT(*)                             AS n_contracts,
    ROUND(SUM(original_value) / 1e6, 1)  AS value_millions
FROM t1_below_limit
GROUP BY commodity_type, limit_value;

-- Step 3. 30-day windows where below-limit contracts add up to more than the limit
DROP TABLE IF EXISTS t1_windows;

CREATE TABLE t1_windows AS
SELECT
    a.reference_number        AS anchor_ref,
    a.owner_org,
    a.owner_org_title,
    a.vendor_name,
    a.vendor_key,
    a.commodity_type,
    a.limit_value,
    a.contract_date           AS window_start,
    MAX(b.contract_date)      AS window_end,
    COUNT(*)                  AS n_contracts,
    SUM(b.original_value)     AS window_total
FROM t1_below_limit a
JOIN t1_below_limit b
  ON  b.owner_org      = a.owner_org
  AND b.vendor_key     = a.vendor_key
  AND b.commodity_type = a.commodity_type
  AND b.contract_date BETWEEN a.contract_date AND date(a.contract_date, '+30 days')
GROUP BY a.reference_number
HAVING COUNT(*) >= 2
   AND SUM(b.original_value) > a.limit_value;

-- Check
SELECT
    COUNT(*)                                      AS n_windows,
    COUNT(DISTINCT owner_org || '|' || vendor_key) AS n_org_vendor_pairs,
    COUNT(DISTINCT owner_org)                     AS n_departments,
    MAX(n_contracts)                              AS max_contracts_in_window,
    ROUND(AVG(n_contracts), 1)                    AS avg_contracts_in_window
FROM t1_windows;

-- Step 4. Same-day splits: 2+ below-limit contracts, same department, vendor and type, same day
DROP TABLE IF EXISTS t1_same_day;

CREATE TABLE t1_same_day AS
SELECT
    owner_org,
    owner_org_title,
    MIN(vendor_name)                   AS vendor_name,
    vendor_key,
    commodity_type,
    limit_value,
    contract_date,
    COUNT(*)                           AS n_contracts,
    SUM(original_value)                AS total_value,
    MAX(original_value)                AS largest_contract,
    GROUP_CONCAT(reference_number, '; ') AS contract_refs
FROM t1_below_limit
GROUP BY owner_org, vendor_key, commodity_type, contract_date
HAVING COUNT(*) >= 2
   AND SUM(original_value) > limit_value;

-- Check
SELECT
    COUNT(*)                             AS n_groups,
    SUM(n_contracts)                     AS n_contracts,
    ROUND(SUM(total_value) / 1e6, 1)     AS value_millions,
    COUNT(DISTINCT owner_org)            AS n_departments,
    COUNT(DISTINCT vendor_key)           AS n_vendors,
    MAX(n_contracts)                     AS max_contracts_same_day
FROM t1_same_day;

-- Step 5. Departments with the most same-day split groups
SELECT
    s.owner_org_title,
    COUNT(*)                                          AS n_groups,
    SUM(s.n_contracts)                                AS n_contracts_flagged,
    ROUND(SUM(s.total_value) / 1e6, 2)                AS value_millions,
    t.n_below_limit,
    ROUND(100.0 * SUM(s.n_contracts) / t.n_below_limit, 1) AS pct_flagged
FROM t1_same_day s
JOIN (
    SELECT owner_org, COUNT(*) AS n_below_limit
    FROM t1_below_limit
    GROUP BY owner_org
) t ON t.owner_org = s.owner_org
GROUP BY s.owner_org
ORDER BY n_groups DESC
LIMIT 15;

-- Step 6. Drill-down: Correctional Service of Canada, top vendors in same-day groups
SELECT
    s.vendor_name,
    s.commodity_type,
    COUNT(*)                              AS n_groups,
    SUM(s.n_contracts)                    AS n_contracts,
    ROUND(SUM(s.total_value) / 1e3, 0)    AS value_thousands,
    MAX(s.n_contracts)                    AS max_same_day,
    (SELECT b.description_en
       FROM t1_below_limit b
      WHERE b.owner_org  = s.owner_org
        AND b.vendor_key = s.vendor_key
      GROUP BY b.description_en
      ORDER BY COUNT(*) DESC
      LIMIT 1)                            AS main_description
FROM t1_same_day s
WHERE s.owner_org_title LIKE 'Correctional Service%'
GROUP BY s.vendor_key, s.commodity_type
ORDER BY n_groups DESC
LIMIT 15;

-- =====================================================================
-- Test 1 results (data downloaded 2026-10-24; contracts awarded 2022-01-01 to 2026-10-24)
-- =====================================================================
-- Non-competitive (TN) contracts at or below the s.6(b) limit: 77,272
--   Goods ($25,000 limit): 23,851 contracts, $409.4M
--   Services ($40,000 limit): 47,969 contracts, $1,074.6M
--   Construction ($40,000 limit): 5,452 contracts, $124.5M
-- 30-day windows above the limit: 16,581 windows, 9,451 department-vendor pairs, 87 departments
-- Same-day split groups: 1,487 groups, 3,798 contracts, $78.0M,
--   65 departments, 667 vendors, up to 14 contracts on one day
-- Highest concentration: Correctional Service of Canada
--   393 groups, 1,189 contracts, $19.42M; 37.7% of its below-limit TN contracts
--   (next highest: Public Health Agency of Canada at 13.7%)
-- Driver: McKesson Canada (pharmaceuticals) accounts for 348 of CSC's 393 groups
--   (88.5%), 1,051 contracts and $16.76M, with up to 11 contracts on one day
-- Limitations: flags indicate items for review, not confirmed non-compliance;
--   department-level data cannot separate orders from different CSC institutions;
--   English and French vendor names are not merged (e.g., Commissionaires);
--   the $100,000 limit for architectural and engineering services is not applied.