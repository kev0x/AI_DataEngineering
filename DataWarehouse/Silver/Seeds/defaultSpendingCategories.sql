insert or ignore into Silver.dimSpendingCategory (
    spendingCategoryKey,
    spendingCategoryName,
    parentSpendingCategoryName,
    spendingCategoryDescription
) values
    (-1, 'Unknown', 'Unknown', 'Missing or invalid category key'),
    (100, 'Dining', 'Food', 'Restaurants, cafes, and prepared food'),
    (200, 'Groceries', 'Food', 'Grocery and supermarket purchases'),
    (300, 'BillsAndUtilities', 'Household', 'Recurring bills and utility expenses'),
    (400, 'Transportation', 'Transportation', 'Transit, parking, rideshare, and vehicle expenses'),
    (500, 'Gas', 'Transportation', 'Fuel purchases'),
    (600, 'Travel', 'Lifestyle', 'Travel expenses'),
    (700, 'Shopping', 'Lifestyle', 'Retail purchases'),
    (800, 'Entertainment', 'Lifestyle', 'Entertainment expenses'),
    (900, 'Health', 'Lifestyle', 'Health and wellness expenses'),
    (1000, 'Education', 'Lifestyle', 'Education expenses'),
    (1100, 'Home', 'Household', 'Home-related expenses'),
    (1200, 'Personal', 'Lifestyle', 'Personal expenses'),
    (1300, 'ProfessionalServices', 'Lifestyle', 'Professional services'),
    (1400, 'Income', 'Income', 'Income transactions'),
    (1500, 'OtherIncome', 'Income', 'Income that is not otherwise categorized'),
    (1600, 'DebtPayment', 'Financial', 'Debt and loan payments'),
    (1700, 'Transfer', 'Financial', 'Transfers and account movements'),
    (1800, 'Fee', 'Financial', 'Fees'),
    (1900, 'Refund', 'Adjustment', 'Refunds and returns'),
    (2000, 'Uncategorized', 'Uncategorized', 'Needs category review');

