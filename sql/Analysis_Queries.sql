-- ============================================================
-- PROJECT  : Life Insurance Customer Persistency & 
--            Agent Performance Analysis
-- Author   : Mujahid Khan
-- Dataset  : insurance_data_FINAL.xlsx (SQLite)
-- Tool     : SQLite via VS Code Database Client
-- Purpose  : Identify root cause of 22% profit decline
--            and quantify revenue lost to lapsation
-- ============================================================
-- TABLES USED:
--   Policies   - 200 rows - core policy data
--   Customers  - 200 rows - customer demographics
--   Agents     - 20 rows  - agent details
--   Premiums   - 500 rows - payment history
--   Claims     - 50 rows  - claims data
-- ============================================================


-- ------------------------------------------------------------
-- QUERY 1: Lapse Rate by Distribution Channel
-- ------------------------------------------------------------
-- Business Question:
--   Which distribution channel has the highest lapse rate
--   and how many policies are affected in each channel?
--
-- Business Context:
--   Kotak Life sells through 3 channels - Agent, Banca,
--   and Digital. Understanding which channel drives the
--   most lapsation helps prioritise retention intervention.
--
-- Expected Insight:
--   Agent channel expected to have highest lapse rate
--   Digital expected to be most stable
-- ------------------------------------------------------------

SELECT 
    Channel,
    COUNT(*) AS Total_Policies,
    COUNT(CASE WHEN PolicyStatus = 'Lapsed' THEN 1 END) 
        AS Lapsed_Policies,
    ROUND(
        COUNT(CASE WHEN PolicyStatus = 'Lapsed' THEN 1 END) 
        * 100.0 / COUNT(*), 
    1) AS Lapse_Rate_Percent
FROM Policies
GROUP BY Channel
ORDER BY Lapse_Rate_Percent DESC;


-- ------------------------------------------------------------
-- QUERY 2: Churning Agent Detection
-- ------------------------------------------------------------
-- Business Question:
--   Which agents have a high volume of new business
--   combined with a high lapse rate - indicating they
--   are churning customers to earn repeat Year 1 commission?
--
-- Business Context:
--   A churning agent deliberately allows policies to lapse
--   after Year 1 and re-sells a new policy to the same
--   customer. This artificially inflates new business numbers
--   while destroying renewal revenue and increasing
--   acquisition cost simultaneously.
--
-- Risk Labels:
--   High Risk  = Lapse Rate above 65%
--   Watch List = Lapse Rate between 45% and 65%
--   Normal     = Lapse Rate below 45%
--
-- Expected Insight:
--   Agents A003 and A004 flagged as High Risk churning agents
-- ------------------------------------------------------------

SELECT 
    a.AgentID,
    a.AgentName,
    p.Channel,
    COUNT(*) AS Total_Policies,
    COUNT(CASE WHEN p.PolicyStatus = 'Lapsed' THEN 1 END) 
        AS Lapsed_Policies,
    ROUND(
        COUNT(CASE WHEN p.PolicyStatus = 'Lapsed' THEN 1 END) 
        * 100.0 / COUNT(*), 
    1) AS Lapse_Rate_Percent,
    CASE 
        WHEN ROUND(COUNT(CASE WHEN p.PolicyStatus = 'Lapsed' 
             THEN 1 END) * 100.0 / COUNT(*), 1) > 65 
             THEN 'High Risk'
        WHEN ROUND(COUNT(CASE WHEN p.PolicyStatus = 'Lapsed' 
             THEN 1 END) * 100.0 / COUNT(*), 1) BETWEEN 45 AND 65 
             THEN 'Watch List'
        ELSE 'Normal'
    END AS Risk_Label
FROM Policies p
JOIN Agents a ON p.AgentID = a.AgentID
GROUP BY a.AgentID, a.AgentName, p.Channel
ORDER BY Lapse_Rate_Percent DESC;


-- ------------------------------------------------------------
-- QUERY 3: 13th Month Persistency Rate by Product Type
-- ------------------------------------------------------------
-- Business Question:
--   What percentage of policies are still active at the
--   13th month - broken down by product type?
--
-- Business Context:
--   IRDAI tracks 13th month persistency as the primary
--   health metric for every life insurer. A policy surviving
--   to month 13 means the customer has paid at least 2 annual
--   premiums - the insurer has recovered acquisition cost.
--   Below 13 months = pure loss on that policy.
--
-- Filter Logic:
--   Only policies issued at least 13 months ago are eligible
--   for this measurement. Recent policies are excluded.
--
-- Expected Insight:
--   Term insurance highest persistency (pure protection)
--   ULIP lowest persistency (investment confusion/mis-selling)
-- ------------------------------------------------------------

SELECT 
    ProductType,
    COUNT(*) AS Total_Eligible_Policies,
    COUNT(CASE WHEN PolicyStatus = 'Active' THEN 1 END) 
        AS Survived_13_Months,
    ROUND(
        COUNT(CASE WHEN PolicyStatus = 'Active' THEN 1 END) 
        * 100.0 / COUNT(*), 
    1) AS Persistency_Rate_Percent
FROM Policies
WHERE IssueDate <= DATE('now', '-13 months')
GROUP BY ProductType
ORDER BY Persistency_Rate_Percent ASC;


-- ------------------------------------------------------------
-- QUERY 4: Lapse Rate by Geographic Region
-- ------------------------------------------------------------
-- Business Question:
--   Which geographic region has the highest lapse rate
--   and what is the average customer age in each region?
--
-- Business Context:
--   Regional lapse patterns can reveal agent quality issues,
--   economic stress in specific geographies, or poor
--   product-market fit for certain customer demographics.
--   Average age helps identify if younger customers in
--   certain regions are more likely to lapse.
--
-- Tables Joined:
--   Policies + Customers (on CustomerID)
--   Region data lives in Customers table
--
-- Expected Insight:
--   West region highest lapse rate with youngest avg age
--   suggesting affordability issues among younger customers
-- ------------------------------------------------------------

SELECT 
    c.Region,
    COUNT(*) AS Total_Policies,
    COUNT(CASE WHEN p.PolicyStatus = 'Lapsed' THEN 1 END) 
        AS Lapsed_Policies,
    ROUND(
        COUNT(CASE WHEN p.PolicyStatus = 'Lapsed' THEN 1 END) 
        * 100.0 / COUNT(*), 
    1) AS Lapse_Rate_Percent,
    ROUND(AVG(c.Age), 1) AS Avg_Customer_Age
FROM Policies p
JOIN Customers c ON p.CustomerID = c.CustomerID
GROUP BY c.Region
ORDER BY Lapse_Rate_Percent DESC;


-- ------------------------------------------------------------
-- QUERY 5: Revenue Lost to Lapsation by Channel
-- ------------------------------------------------------------
-- Business Question:
--   How much renewal premium revenue has been lost due to
--   policy lapsation - broken down by channel?
--
-- Business Context:
--   Every lapsed policy represents future premium payments
--   that will never be collected. This query quantifies the
--   exact revenue impact of the persistency problem.
--   Assuming average 3 years of remaining premiums lost
--   per lapsed policy (conservative estimate).
--
-- Formula:
--   Revenue Lost = SUM(PremiumAmount * 3) 
--   for all Lapsed policies
--
-- Key Output:
--   This number is the PROJECT HEADLINE KPI
--   Goes on dashboard as primary metric
--   Goes on resume as quantified achievement
--
-- Expected Insight:
--   Total revenue lost approximately ₹57 Lakhs
--   Agent channel contributing highest loss
-- ------------------------------------------------------------

SELECT 
    Channel,
    COUNT(CASE WHEN PolicyStatus = 'Lapsed' THEN 1 END) 
        AS Lapsed_Policies,
    ROUND(AVG(PremiumAmount), 0) 
        AS Avg_Premium_Amount,
    ROUND(SUM(CASE WHEN PolicyStatus = 'Lapsed' 
        THEN PremiumAmount * 3 ELSE 0 END), 0) 
        AS Revenue_Lost_INR

FROM Policies
GROUP BY Channel

UNION ALL

SELECT 
    'Grand Total' AS Channel,
    COUNT(CASE WHEN PolicyStatus = 'Lapsed' THEN 1 END),
    ROUND(AVG(PremiumAmount), 0),
    ROUND(SUM(CASE WHEN PolicyStatus = 'Lapsed' 
        THEN PremiumAmount * 3 ELSE 0 END), 0)
FROM Policies;


-- ------------------------------------------------------------
-- QUERY 6: Renewal Performance by Customer Segment
-- ------------------------------------------------------------
-- Business Question:
--   Which customer segment has the best renewal rate and
--   what is their premium and income profile?
--
-- Business Context:
--   Understanding which segment retains best helps the
--   business decide where to focus acquisition and
--   retention investment. High income customers may have
--   lower lapse risk due to premium affordability.
--
-- Segments:
--   HNI (High Net Worth Individual) — top tier
--   Corporate — group/employer purchased
--   Retail — individual mass market
--
-- Tables Joined:
--   Policies + Customers (on CustomerID)
--   CustomerSegment and AnnualIncome in Customers table
--
-- Expected Insight:
--   HNI segment best persistency due to high income
--   Retail segment highest volume but highest lapse risk
-- ------------------------------------------------------------

SELECT 
    c.CustomerSegment,
    COUNT(*) AS Total_Policies,
    COUNT(CASE WHEN p.PolicyStatus = 'Active' THEN 1 END) 
        AS Active_Policies,
    ROUND(
        COUNT(CASE WHEN p.PolicyStatus = 'Lapsed' THEN 1 END) 
        * 100.0 / COUNT(*), 
    1) AS Lapse_Rate_Percent,
    ROUND(AVG(p.PremiumAmount), 1) AS Avg_Premium_Amount,
    ROUND(AVG(c.AnnualIncome), 1) AS Avg_Annual_Income
FROM Policies p
JOIN Customers c ON p.CustomerID = c.CustomerID
GROUP BY c.CustomerSegment
ORDER BY Lapse_Rate_Percent ASC;


-- ------------------------------------------------------------
-- QUERY 7: Average Premium by Channel and Product Type
-- ------------------------------------------------------------
-- Business Question:
--   What is the average and total premium broken down by
--   both channel AND product type — which combination
--   generates the highest revenue per policy?
--
-- Business Context:
--   Different products carry very different premium levels.
--   ULIPs are investment-linked and carry higher premiums.
--   Term insurance carries lower premiums but higher
--   sum assured. Understanding the channel-product mix
--   helps optimise sales strategy and revenue forecasting.
--
-- New Concept Used:
--   GROUP BY two columns simultaneously
--   Channel + ProductType combination analysis
--
-- Expected Insight:
--   ULIP generates highest avg premium across all channels
--   Agent channel sells most ULIPs — highest revenue
--   but also highest lapse risk (cross-reference Query 3)
-- ------------------------------------------------------------

SELECT 
    Channel,
    ProductType,
    COUNT(*) AS Total_Policies,
    ROUND(AVG(PremiumAmount), 1) AS Avg_Premium,
    SUM(PremiumAmount) AS Total_Premium_INR
FROM Policies
GROUP BY Channel, ProductType
ORDER BY Channel, Total_Premium_INR DESC;


-- ------------------------------------------------------------
-- QUERY 8: Claim to Premium Ratio by Product Type
-- ------------------------------------------------------------
-- Business Question:
--   Which product type has the highest claim-to-premium
--   ratio and what is the claim settlement rate?
--
-- Business Context:
--   Claim-to-premium ratio measures how much the insurer
--   pays out in claims relative to what it collects in
--   premiums. A very high ratio indicates a product that
--   is expensive to maintain from a risk perspective.
--   Settlement rate measures claims processing quality.
--
-- Formula:
--   Claim to Premium Ratio = 
--   (Total Claim Amount / Total Premium Collected) * 100
--
-- Important Note on Term Insurance Ratio:
--   Term insurance will always show an extremely high
--   claim-to-premium ratio because premiums are very low
--   (avg ₹13,783) but sum assured is very high (₹50L-1Cr).
--   This is by design — Term is pure risk protection, 
--   not a savings product. This is not a red flag.
--
-- Tables Joined:
--   Claims + Policies (on PolicyID)
--
-- Expected Insight:
--   Term highest claim ratio by design
--   ULIP moderate — has investment component buffering
--   Settlement rate 64-70% realistic for Indian market
-- ------------------------------------------------------------

SELECT 
    p.ProductType,
    COUNT(*) AS Total_Claims,
    COUNT(CASE WHEN cl.ClaimStatus = 'Settled' THEN 1 END) 
        AS Settled_Claims,
    ROUND(
        COUNT(CASE WHEN cl.ClaimStatus = 'Settled' THEN 1 END) 
        * 100.0 / COUNT(*), 
    1) AS Settlement_Rate_Percent,
    SUM(cl.ClaimAmount) AS Total_Claim_Amount_INR,
    ROUND(
        SUM(cl.ClaimAmount) * 100.0 / SUM(p.PremiumAmount), 
    1) AS Claim_Premium_Ratio_Percent
FROM Claims cl
JOIN Policies p ON cl.PolicyID = p.PolicyID
GROUP BY p.ProductType
ORDER BY Settlement_Rate_Percent DESC;


-- ============================================================
-- END OF ANALYSIS
-- ============================================================
-- SUMMARY OF KEY FINDINGS:
--
-- 1. HEADLINE: ₹57.4 Lakhs lost to lapsation annually
--
-- 2. ROOT CAUSE: Agent churning — A003 (78% lapse) and
--    A004 (71% lapse) are High Risk churning agents
--    operating in Banca channel
--
-- 3. PRODUCT RISK: ULIP has lowest 13th month persistency
--    at 45% despite highest avg premium of ₹37,000
--
-- 4. BEST SEGMENT: HNI customers — only 19% lapse rate
--    with avg income ₹37.5L — priority acquisition target
--
-- 5. REGIONAL RISK: West region — 37.7% lapse rate with
--    youngest customer base (avg 45 years) — possible
--    mis-selling to younger, lower-income customers
--
-- 6. CHANNEL HEALTH: Digital channel most stable at 25%
--    lapse rate — recommend scaling digital acquisition 
-- ============================================================