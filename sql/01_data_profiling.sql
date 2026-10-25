-- =====================================================================
-- 01_data_profiling.sql
-- Data quality checks on the raw federal contracts table (contracts_raw)
-- Source: Proactive Publication of Contracts over $10,000, open.canada.ca
-- Downloaded 2026-10-24 (1,313,552 rows, 43 columns)
-- =====================================================================


-- A. List the last columns of the raw table (department fields)
SELECT cid, name
FROM pragma_table_info('contracts_raw')
WHERE cid >= 33;
-- Result: owner_org and owner_org_title hold the department code and name.


-- B. Data quality profile
SELECT
    COUNT(*)                                                AS n_rows,
    SUM(contract_date < '2000-01-01')                       AS dates_before_2000,
    SUM(contract_date > date('now'))                        AS future_dates,
    SUM(contract_date IS NULL OR contract_date = '')        AS missing_dates,
    SUM(typeof(contract_value) NOT IN ('real', 'integer'))  AS non_numeric_values,
    SUM(instrument_type = 'C')                              AS n_contracts,
    SUM(instrument_type = 'A')                              AS n_amendments,
    SUM(instrument_type = 'SOSA')                           AS n_sosa,
    SUM(contract_date >= '2022-01-01')                      AS rows_since_2022
FROM contracts_raw;
-- Result: 1,313,552 rows; 28 dates before 2000; 1 future date; 0 missing dates;
-- 348 non-numeric values; C 684,266; A 204,708; SOSA 69,988; 381,165 rows since 2022.


-- C. Sample of records with implausible contract dates
SELECT reference_number, vendor_name, contract_date,
       contract_value, instrument_type, reporting_period
FROM contracts_raw
WHERE contract_date < '2000-01-01'
   OR contract_date > date('now')
ORDER BY contract_date
LIMIT 20;
-- Result: 1899-12-30 and 1900-02-24 are Excel date errors. Most other pre-2000
-- dates are amendments (A) to a 1999 MDA contract, which keep the original
-- award date. Several MDA amendments repeat the same value in the same quarter
-- (possible duplicates). Amendment rows carry the cumulative contract value.


-- D. Instrument type by era
SELECT
    CASE
        WHEN contract_date < '2019-01-01' THEN '1. before 2019'
        WHEN contract_date < '2022-01-01' THEN '2. 2019 to 2021'
        ELSE '3. 2022 onward'
    END AS era,
    COALESCE(NULLIF(instrument_type, ''), '(blank)') AS itype,
    COUNT(*) AS n_rows
FROM contracts_raw
GROUP BY era, itype
ORDER BY era, n_rows DESC;
-- Result: all 354,590 blank instrument types are before 2019.
-- 2022 onward: C 273,233; A 67,927; SOSA 40,005; no blanks.


-- E. What are the non-numeric contract values?
SELECT
    typeof(contract_value) AS value_type,
    COUNT(*)               AS n_rows,
    MIN(contract_date)     AS first_date,
    MAX(contract_date)     AS last_date,
    MIN(contract_value)    AS example_value
FROM contracts_raw
GROUP BY value_type;
-- Result: the 348 non-numeric values are NULL, all dated 2005 to 2018.
-- Some contract values are negative (minimum -8,164,033.46).


-- F. Verify the clean table (run after 02_build_clean_table.sql)
SELECT
    instrument_type,
    COUNT(*)                     AS n_rows,
    MIN(contract_date)           AS first_date,
    MAX(contract_date)           AS last_date,
    SUM(contract_value < 0)      AS negative_values,
    SUM(contract_value = 0)      AS zero_values,
    SUM(original_value IS NULL)  AS missing_original,
    COUNT(DISTINCT owner_org)    AS n_departments,
    COUNT(DISTINCT vendor_key)   AS n_vendors
FROM contracts_clean
GROUP BY instrument_type;
-- Result:
--   C: 273,232 rows (the 1 future-dated record was a C and is excluded),
--      2022-01-01 to 2026-09-29, 1 negative value, 115 zero values,
--      0 missing original values, 94 departments, 61,972 vendors.
--   A: 67,927 rows, 2022-01-01 to 2026-07-27, 132 negative values,
--      1,588 zero values, 0 missing original values, 87 departments, 17,297 vendors.
