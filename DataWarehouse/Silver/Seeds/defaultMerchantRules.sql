-- Purpose: Seeds starter merchant cleanup rules for common Chase description patterns.
-- Pipeline role: Improves merchant names for dashboard readability without changing transaction amount or category logic.
-- Dependencies: Silver.mapMerchantRule must exist before this seed runs; ProcessDimMerchant and ProcessFactTransaction consume the rules.

-- Merchant rules will be expanded after merchant profiling.
-- The unknown fallback rule is seeded in defaultUnknownMembers.sql because factTransaction
-- depends on a valid merchantRuleKey = -1.
