-- Build the clean analysis table: C and A records awarded 2022-01-01 to 2026-10-24
DROP TABLE IF EXISTS contracts_clean;

CREATE TABLE contracts_clean AS
SELECT
    reference_number,
    procurement_id,
    TRIM(vendor_name)                                AS vendor_name,
    UPPER(TRIM(vendor_name))                         AS vendor_key,
    owner_org,
    owner_org_title,
    contract_date,
    CAST(strftime('%Y', contract_date) AS INTEGER)
      - (CAST(strftime('%m', contract_date) AS INTEGER) < 4) AS fiscal_year_start,
    instrument_type,
    solicitation_procedure,
    limited_tendering_reason,
    article_6_exceptions,
    CAST(NULLIF(number_of_bids, '') AS INTEGER)      AS number_of_bids,
    commodity_type,
    economic_object_code,
    description_en,
    CAST(contract_value AS REAL)                     AS contract_value,
    CAST(NULLIF(original_value, '') AS REAL)         AS original_value,
    CAST(NULLIF(amendment_value, '') AS REAL)        AS amendment_value,
    contract_period_start,
    delivery_date,
    standing_offer_number,
    contracting_entity,
    former_public_servant,
    country_of_vendor,
    reporting_period
FROM contracts_raw
WHERE contract_date >= '2022-01-01'
  AND contract_date <= '2026-10-24'
  AND instrument_type IN ('C', 'A');
  
  -- Indexes to speed up the audit tests
CREATE INDEX IF NOT EXISTS idx_clean_org_vendor_date
    ON contracts_clean (owner_org, vendor_key, contract_date);

CREATE INDEX IF NOT EXISTS idx_clean_procurement
    ON contracts_clean (procurement_id);