/*
Purpose:
    Returns selectable spending categories for the manual category-rule workflow.
Dependencies:
    Silver.dimSpendingCategory.
*/
select
    spendingCategoryKey,
    spendingCategoryName,
    parentSpendingCategoryName
from Silver.dimSpendingCategory
where isActive = true
  and spendingCategoryName not in ('Unknown', 'Uncategorized')
order by parentSpendingCategoryName, spendingCategoryName
