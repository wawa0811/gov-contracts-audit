# Canadian Federal Contracts: Audit Analytics

**Data:** Proactive Publication of Contracts over $10,000, Open Government Portal (Open Government Licence - Canada), downloaded October 24, 2026
**Scope:** Contracts and amendments awarded January 1, 2022 to October 24, 2026
**Author:** Jiatong (Clover) Li, University of Waterloo, Financial Analysis and Risk Management
**Dashboard:** [Tableau Public](https://public.tableau.com/views/CanadianFederalContractsAuditAnalytics/AuditDashboard)

---

## Summary

I applied five standard audit analytics tests to 273,232 new federal contracts and 67,927 amendments reported by 94 departments. The tests flagged 1,487 groups of same-day contracts that together exceeded the non-competitive dollar limit, 1,126 contracts awarded without competition that were later amended above that limit, and 287 groups of records that appear to be reported twice. Non-competitive awards made up 20.9% of contract value government-wide and were heavily concentrated: three vendors received 37.7% of all non-competitive value. Every flag is an item for review, not a finding of non-compliance.

## Data and scope

The raw file contained 1,313,552 rows and 43 columns. Before testing, I profiled it for quality:

- **Mandatory fields changed over time.** All 354,590 rows with a blank instrument type were dated before 2019, and several fields needed for the tests (solicitation procedure, limited tendering reason) only became mandatory on January 1, 2022. I therefore limited the analysis to contracts awarded from 2022 onward.
- **Implausible dates.** 28 rows were dated before 2000. Two were clear entry errors (1899-12-30 is Excel's zero date). Most of the rest were amendments to a 1999 contract, which keep the original award date, so they were not errors. One contract was dated after the download date and was excluded.
- **Amendment values are cumulative.** On amendment rows, contract value is the total value after the amendment, not the change. Summing rows for the same contract would overstate spending.
- **Missing and invalid values.** 348 contract values were null, all from 2005 to 2018 and outside scope. Within scope, 1 new contract and 132 amendments had negative total values, and 115 new contracts and 1,588 amendments had a value of zero.

The clean table holds 341,159 records: 273,232 new contracts (C) and 67,927 amendments (A). Standing offer agreements (SOSA) were excluded because their value is a ceiling, not spending.

## Tests and findings

### 1. Contract splitting

Section 6(b) of the Government Contracts Regulations allows a contract to be awarded without bids if it does not exceed $25,000 for goods or $40,000 for most other contracts. Splitting one purchase into several smaller contracts can avoid that requirement.

- 77,272 non-competitive contracts were at or below the limit.
- 1,487 groups of two or more such contracts were signed by the same department with the same vendor, for the same commodity type, on the same day, and together exceeded the limit (3,798 contracts, $78.0M, 65 departments).
- Correctional Service of Canada accounted for 393 groups, covering 37.7% of its below-limit non-competitive contracts, against 13.7% for the next-highest department. McKesson Canada (pharmaceuticals) accounted for 348 of those 393 groups, with up to 11 contracts on one day.

The data is reported at department level, so separate orders from different institutions on the same day look identical. These groups are worth reviewing, not evidence of intent.

### 2. Amendment growth

Amendments were matched to their original contract by department and procurement ID. 48,671 of 67,927 amendments (71.7%) matched a contract awarded in scope; 860 procurement IDs used by more than one contract were excluded.

- Of 31,887 amended contracts, 10,149 (31.8%) at least doubled in value and 1,559 grew five times or more.
- 3,964 contracts were awarded without competition at or below the limit and later amended. 1,126 of them (28.4%) were amended above the limit, growing from $30.0M at award to $90.8M in total. The largest single increase was 151 times the original value, at National Defence.

### 3. Non-competitive concentration

- 20.9% of contract value government-wide was awarded without competition.
- Among departments with 500 or more contracts, the highest shares were the Privy Council Office (58.1%), Statistics Canada (53.0%) and Treasury Board Secretariat (51.2%).
- The top 3 vendors (CAE Military Aviation Training, Bell Textron Canada and Leonardo UK) received 37.7% of all non-competitive value with one or two contracts each. The top 15 received 57.5%, mostly defence and IT suppliers.

### 4. Benford's Law

First digits of contract values did not follow Benford's Law: 43.9% began with 1 against an expected 30.1%. This reflects the $10,000 reporting floor, since most contracts fall between $10,000 and $19,999, so the dataset does not meet Benford's assumptions. I compared each department with the government-wide pattern instead. The Immigration and Refugee Board deviated most (mean absolute deviation 5.78, next 3.86): 40.2% of its contracts begin with 2 and 21.0% with 3, against 22.5% and 12.7% government-wide, which points to clustering between $20,000 and $39,999.

### 5. Duplicate records

- 3,172 groups of new contracts shared the same department, vendor, date and value, adding 4,791 extra records and $559.9M.
- 287 of these groups also shared a procurement ID, which suggests double reporting (340 extra records). The Canadian Space Agency had the largest extra value ($51.87M across 12 groups); the Public Prosecution Service had the most repeats, with up to 4 copies of one contract.
- The other 2,885 groups had different procurement IDs and may be legitimate repeat orders.

## Limitations

- Flags identify items for review. Non-competitive awards can be fully justified, for example when only one supplier is capable.
- Vendor names are not standardized, so English and French names, or variants such as GD OTS C and General Dynamics, are counted separately.
- The $100,000 limit for architectural and engineering services was not applied, because those contracts cannot be reliably identified in the data.
- Amendments were matched on department and procurement ID only, and contract values are taken as reported, including values that appear to be entry errors.

## Files

- `sql/`: data profiling, clean table, five tests and the department scorecard
- `data/output/`: tables exported for the dashboard
- `tableau/`: dashboard screenshot
