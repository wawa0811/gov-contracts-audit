-- =====================================================================
-- 07_test5_duplicates.sql
-- Test 5: Possible duplicate contract records
-- =====================================================================

-- Step 1. Same department, vendor, date and value reported more than once
DROP TABLE IF EXISTS t5_duplicates;

CREATE TABLE t5_duplicates AS
SELECT
    owner_org,
    MIN(owner_org_title)            AS owner_org_title,
    vendor_key,
    MIN(vendor_name)                AS vendor_name,
    contract_date,
    original_value,
    COUNT(*)                        AS n_records,
    COUNT(DISTINCT procurement_id)  AS n_procurement_ids,
    GROUP_CONCAT(reference_number, '; ') AS contract_refs
FROM contracts_clean
WHERE instrument_type = 'C'
GROUP BY owner_org, vendor_key, contract_date, original_value
HAVING COUNT(*) > 1;

-- Check
SELECT
    COUNT(*)                                            AS n_groups,
    SUM(n_records - 1)                                  AS extra_records,
    ROUND(SUM((n_records - 1) * original_value) / 1e6, 1) AS extra_value_millions,
    SUM(n_procurement_ids = 1)                          AS groups_same_id,
    SUM(n_procurement_ids > 1)                          AS groups_different_ids,
    COUNT(DISTINCT owner_org)                           AS n_departments
FROM t5_duplicates;

-- Step 2. Same-ID duplicates (most likely double reporting), by department
SELECT
    owner_org_title,
    COUNT(*)                                             AS n_groups,
    SUM(n_records - 1)                                   AS extra_records,
    ROUND(SUM((n_records - 1) * original_value) / 1e6, 2) AS extra_value_millions,
    MAX(n_records)                                       AS max_copies
FROM t5_duplicates
WHERE n_procurement_ids = 1
GROUP BY owner_org
ORDER BY extra_value_millions DESC
LIMIT 10;

-- =====================================================================
-- Test 5 results (new contracts awarded 2022-01-01 to 2026-10-24)
-- =====================================================================
-- Records with the same department, vendor, date and original value: 3,172 groups,
--   4,791 extra records, $559.9M in extra value, 68 departments
--   Same procurement ID (likely double reporting): 287 groups
--   Different procurement IDs (may be separate orders): 2,885 groups
-- Same-ID duplicates by extra value:
--   Canadian Space Agency: 12 groups, $51.87M
--   Public Prosecution Service of Canada: 61 groups, 106 extra records, $14.11M,
--     up to 4 copies of one contract
--   Global Affairs Canada: 2 groups, $8.41M
--   Canada Revenue Agency: 28 groups, $5.43M
-- Limitations: identical records may be legitimate repeat orders;
--   duplicates are flagged for review, not confirmed.