-- Purpose: Reports row counts for important warehouse objects.
-- Pipeline role: Provides a quick sanity check after deployment or population to confirm data landed where expected.
-- Dependencies: Bronze raw tables, Silver dimensions/facts, and Gold views.

select 'Bronze.rawChaseCheckingTransaction' as objectName, count(*) as rowCount from Bronze.rawChaseCheckingTransaction
union all
select 'Bronze.rawChaseCreditTransaction' as objectName, count(*) as rowCount from Bronze.rawChaseCreditTransaction
union all
select 'Silver.dimSourceFile' as objectName, count(*) as rowCount from Silver.dimSourceFile
union all
select 'Silver.dimFinancialAccount' as objectName, count(*) as rowCount from Silver.dimFinancialAccount
union all
select 'Silver.dimSpendingCategory' as objectName, count(*) as rowCount from Silver.dimSpendingCategory
union all
select 'Silver.dimMerchant' as objectName, count(*) as rowCount from Silver.dimMerchant
union all
select 'Silver.dimCalendarDate' as objectName, count(*) as rowCount from Silver.dimCalendarDate
union all
select 'Silver.mapMerchantRule' as objectName, count(*) as rowCount from Silver.mapMerchantRule
union all
select 'Silver.mapCategoryRule' as objectName, count(*) as rowCount from Silver.mapCategoryRule
union all
select 'Silver.factTransaction' as objectName, count(*) as rowCount from Silver.factTransaction
order by objectName;
