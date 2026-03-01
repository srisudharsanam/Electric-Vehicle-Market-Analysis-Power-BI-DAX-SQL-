-- ============================================================
-- EV MARKET ANALYSIS — COMPLETE SQL SCRIPT
-- Compatible with: MySQL 8+, PostgreSQL 14+, SQL Server 2019+
-- Author: EV Analytics Project
-- Records: 150,000+ transactions | 2019-2024 | US Market
-- ============================================================

-- ============================================================
-- SECTION 1: DATABASE SCHEMA
-- ============================================================

CREATE DATABASE IF NOT EXISTS ev_market_db;
USE ev_market_db;

-- Main Sales Fact Table
CREATE TABLE IF NOT EXISTS ev_sales (
    transaction_id      VARCHAR(10)     PRIMARY KEY,
    sale_date           DATE            NOT NULL,
    year                INT             NOT NULL,
    quarter             CHAR(2)         NOT NULL,
    month               INT             NOT NULL,
    region              VARCHAR(50)     NOT NULL,
    brand               VARCHAR(50)     NOT NULL,
    model               VARCHAR(60)     NOT NULL,
    vehicle_type        VARCHAR(10)     NOT NULL,     -- BEV, PHEV, HEV
    sale_price_usd      DECIMAL(12,2)   NOT NULL,
    electric_range_miles INT            NOT NULL,
    charging_type       VARCHAR(30)     NOT NULL,
    customer_segment    VARCHAR(20)     NOT NULL,     -- Individual, Fleet, Commercial, Government
    incentive_applied   BOOLEAN         NOT NULL,
    federal_tax_credit  DECIMAL(10,2)   NOT NULL DEFAULT 0,
    net_price_usd       DECIMAL(12,2)   NOT NULL,
    satisfaction_score  DECIMAL(3,1)    CHECK (satisfaction_score BETWEEN 1 AND 5),
    dealer_margin_pct   DECIMAL(6,4)    NOT NULL,
    dealer_revenue_usd  DECIMAL(10,2)   NOT NULL,
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_region (region),
    INDEX idx_brand (brand),
    INDEX idx_vehicle_type (vehicle_type),
    INDEX idx_sale_date (sale_date),
    INDEX idx_year (year),
    INDEX idx_customer_segment (customer_segment)
);

-- Date Dimension Table
CREATE TABLE IF NOT EXISTS dim_date AS
SELECT DISTINCT
    sale_date                                               AS date_key,
    YEAR(sale_date)                                         AS year,
    QUARTER(sale_date)                                      AS quarter_num,
    CONCAT('Q', QUARTER(sale_date))                         AS quarter_label,
    MONTH(sale_date)                                        AS month_num,
    MONTHNAME(sale_date)                                    AS month_name,
    DAYOFMONTH(sale_date)                                   AS day_of_month,
    DAYOFWEEK(sale_date)                                    AS day_of_week,
    DAYNAME(sale_date)                                      AS day_name,
    WEEKOFYEAR(sale_date)                                   AS week_of_year,
    CASE 
        WHEN MONTH(sale_date) IN (12, 1, 2) THEN 'Winter'
        WHEN MONTH(sale_date) IN (3, 4, 5)  THEN 'Spring'
        WHEN MONTH(sale_date) IN (6, 7, 8)  THEN 'Summer'
        ELSE 'Fall'
    END                                                     AS season,
    CASE 
        WHEN MONTH(sale_date) <= 6 THEN 'H1'
        ELSE 'H2'
    END                                                     AS half_year
FROM ev_sales;

-- Region Reference Table
CREATE TABLE IF NOT EXISTS dim_region (
    region_id   INT PRIMARY KEY AUTO_INCREMENT,
    region_name VARCHAR(50) UNIQUE NOT NULL,
    state_code  CHAR(2),
    timezone    VARCHAR(30),
    census_region VARCHAR(30)
);

INSERT INTO dim_region (region_name, state_code, timezone, census_region) VALUES
    ('California',    'CA', 'Pacific/Los_Angeles',  'West'),
    ('Texas',         'TX', 'America/Chicago',       'South'),
    ('Florida',       'FL', 'America/New_York',      'South'),
    ('New York',      'NY', 'America/New_York',      'Northeast'),
    ('Washington',    'WA', 'America/Los_Angeles',   'West'),
    ('Colorado',      'CO', 'America/Denver',        'West'),
    ('Oregon',        'OR', 'America/Los_Angeles',   'West'),
    ('Nevada',        'NV', 'America/Los_Angeles',   'West'),
    ('Arizona',       'AZ', 'America/Phoenix',       'West'),
    ('Georgia',       'GA', 'America/New_York',      'South'),
    ('Illinois',      'IL', 'America/Chicago',       'Midwest'),
    ('Massachusetts', 'MA', 'America/New_York',      'Northeast'),
    ('Virginia',      'VA', 'America/New_York',      'South'),
    ('Michigan',      'MI', 'America/Detroit',       'Midwest'),
    ('Ohio',          'OH', 'America/New_York',      'Midwest');


-- ============================================================
-- SECTION 2: CORE ANALYTICAL QUERIES
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- Q01: Executive KPI Summary (Single-Query Dashboard)
-- ──────────────────────────────────────────────────────────
SELECT 
    'Total Transactions'    AS kpi, FORMAT(COUNT(*), 0)                             AS value, 'Records'       AS unit FROM ev_sales
UNION ALL SELECT 'Total Revenue ($B)',    FORMAT(ROUND(SUM(sale_price_usd)/1e9, 2), 2),     'Billion USD'   FROM ev_sales
UNION ALL SELECT 'Net Revenue ($B)',      FORMAT(ROUND(SUM(net_price_usd)/1e9, 2), 2),      'Billion USD'   FROM ev_sales
UNION ALL SELECT 'Avg Sale Price',        FORMAT(ROUND(AVG(sale_price_usd), 0), 0),          'USD'           FROM ev_sales
UNION ALL SELECT 'BEV Market Share',      CONCAT(FORMAT(AVG(vehicle_type='BEV')*100, 1),'%'), 'Percent'     FROM ev_sales
UNION ALL SELECT 'Incentive Rate',        CONCAT(FORMAT(AVG(incentive_applied)*100, 1),'%'),  'Percent'     FROM ev_sales
UNION ALL SELECT 'Tax Credits Issued',    FORMAT(ROUND(SUM(federal_tax_credit)/1e6, 1), 1),  'Million USD'  FROM ev_sales
UNION ALL SELECT 'Dealer Revenue ($M)',   FORMAT(ROUND(SUM(dealer_revenue_usd)/1e6, 1), 1),  'Million USD'  FROM ev_sales
UNION ALL SELECT 'Avg Satisfaction',      FORMAT(ROUND(AVG(satisfaction_score), 2), 2),       '/ 5.0'       FROM ev_sales;


-- ──────────────────────────────────────────────────────────
-- Q02: Regional Market Analysis (High-Growth Identification)
-- ──────────────────────────────────────────────────────────
SELECT 
    e.region,
    dr.census_region,
    COUNT(*)                                                        AS total_transactions,
    SUM(e.sale_price_usd)                                           AS total_revenue,
    ROUND(AVG(e.sale_price_usd), 2)                                 AS avg_sale_price,
    ROUND(SUM(e.sale_price_usd) / SUM(SUM(e.sale_price_usd)) OVER() * 100, 2) AS revenue_share_pct,
    ROUND(SUM(CASE WHEN e.vehicle_type = 'BEV' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS bev_penetration_pct,
    ROUND(AVG(CAST(e.incentive_applied AS SIGNED)) * 100, 2)        AS incentive_rate_pct,
    SUM(e.federal_tax_credit)                                       AS total_tax_credits,
    ROUND(AVG(e.satisfaction_score), 3)                             AS avg_satisfaction,
    RANK() OVER (ORDER BY SUM(e.sale_price_usd) DESC)               AS revenue_rank
FROM ev_sales e
LEFT JOIN dim_region dr ON e.region = dr.region_name
GROUP BY e.region, dr.census_region
ORDER BY total_revenue DESC;


-- ──────────────────────────────────────────────────────────
-- Q03: Year-over-Year Growth Analysis
-- ──────────────────────────────────────────────────────────
WITH yearly_stats AS (
    SELECT
        year,
        COUNT(*)                        AS transactions,
        SUM(sale_price_usd)             AS revenue,
        AVG(sale_price_usd)             AS avg_price,
        SUM(federal_tax_credit)         AS tax_credits,
        AVG(satisfaction_score)         AS avg_satisfaction
    FROM ev_sales
    GROUP BY year
)
SELECT
    year,
    transactions,
    ROUND(revenue / 1e6, 2)                                         AS revenue_millions,
    ROUND(avg_price, 2)                                             AS avg_price_usd,
    LAG(transactions) OVER (ORDER BY year)                          AS prev_year_transactions,
    ROUND((transactions - LAG(transactions) OVER (ORDER BY year)) * 100.0 / 
          NULLIF(LAG(transactions) OVER (ORDER BY year), 0), 2)     AS yoy_txn_growth_pct,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY year)) * 100.0 / 
          NULLIF(LAG(revenue) OVER (ORDER BY year), 0), 2)          AS yoy_rev_growth_pct,
    ROUND(SUM(revenue) OVER (ORDER BY year) / 1e6, 2)              AS cumulative_revenue_m,
    ROUND(tax_credits / 1e6, 2)                                     AS tax_credits_millions,
    ROUND(avg_satisfaction, 3)                                      AS avg_satisfaction
FROM yearly_stats
ORDER BY year;


-- ──────────────────────────────────────────────────────────
-- Q04: Brand Competitive Analysis
-- ──────────────────────────────────────────────────────────
SELECT 
    brand,
    COUNT(*)                                                        AS units_sold,
    ROUND(SUM(sale_price_usd) / 1e6, 2)                            AS revenue_millions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)              AS unit_market_share_pct,
    ROUND(SUM(sale_price_usd) * 100.0 / SUM(SUM(sale_price_usd)) OVER(), 2) AS rev_market_share_pct,
    ROUND(AVG(sale_price_usd), 2)                                   AS avg_price,
    ROUND(MIN(sale_price_usd), 2)                                   AS min_price,
    ROUND(MAX(sale_price_usd), 2)                                   AS max_price,
    ROUND(AVG(satisfaction_score), 3)                               AS avg_satisfaction,
    ROUND(AVG(CAST(incentive_applied AS SIGNED)) * 100, 2)          AS incentive_rate_pct,
    ROUND(SUM(dealer_revenue_usd) / 1e6, 2)                        AS dealer_revenue_millions,
    RANK() OVER (ORDER BY SUM(sale_price_usd) DESC)                 AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY AVG(satisfaction_score) DESC)       AS satisfaction_rank
FROM ev_sales
GROUP BY brand
ORDER BY revenue_millions DESC;


-- ──────────────────────────────────────────────────────────
-- Q05: Revenue Potential Scoring Model
-- ──────────────────────────────────────────────────────────
WITH region_metrics AS (
    SELECT 
        region,
        AVG(sale_price_usd)                                                         AS avg_price,
        COUNT(*)                                                                    AS volume,
        AVG(CAST(incentive_applied AS SIGNED))                                      AS incentive_rate,
        AVG(satisfaction_score)                                                     AS avg_satisfaction,
        SUM(CASE WHEN vehicle_type = 'BEV' THEN 1 ELSE 0 END) * 1.0 / COUNT(*)    AS bev_rate,
        ROUND((COUNT(*) - LAG(COUNT(*)) OVER(PARTITION BY region ORDER BY MAX(year))) * 100.0 /
              NULLIF(LAG(COUNT(*)) OVER(PARTITION BY region ORDER BY MAX(year)), 0), 2) AS growth_rate
    FROM ev_sales
    GROUP BY region
),
scored AS (
    SELECT *,
        ROUND(
            (avg_price / 10000 * 0.30) +          -- Price premium weight
            (volume / 5000.0 * 0.25) +             -- Market volume weight
            (incentive_rate * 10 * 0.20) +         -- Incentive adoption weight
            (avg_satisfaction / 5.0 * 10 * 0.15) + -- Customer satisfaction weight
            (bev_rate * 10 * 0.10),                -- BEV penetration weight
        2)                                          AS potential_score
    FROM region_metrics
)
SELECT 
    region,
    ROUND(avg_price, 0)         AS avg_price_usd,
    volume                      AS total_volume,
    CONCAT(ROUND(incentive_rate * 100, 1), '%') AS incentive_rate,
    ROUND(avg_satisfaction, 2)  AS satisfaction,
    CONCAT(ROUND(bev_rate * 100, 1), '%') AS bev_penetration,
    potential_score,
    RANK() OVER (ORDER BY potential_score DESC) AS market_priority_rank,
    CASE 
        WHEN RANK() OVER (ORDER BY potential_score DESC) <= 3 THEN '🔥 Tier 1 - Priority'
        WHEN RANK() OVER (ORDER BY potential_score DESC) <= 7 THEN '⭐ Tier 2 - Growth'
        ELSE '📌 Tier 3 - Develop'
    END AS market_tier
FROM scored
ORDER BY potential_score DESC;


-- ──────────────────────────────────────────────────────────
-- Q06: Vehicle Type Adoption Trends (Quarterly)
-- ──────────────────────────────────────────────────────────
SELECT
    year,
    quarter,
    vehicle_type,
    COUNT(*)                                                        AS transactions,
    ROUND(SUM(sale_price_usd) / 1e6, 2)                            AS revenue_millions,
    ROUND(AVG(sale_price_usd), 2)                                   AS avg_price,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY year, quarter), 2) AS type_share_pct,
    ROUND(AVG(electric_range_miles), 0)                             AS avg_range_miles,
    ROUND(AVG(satisfaction_score), 2)                               AS avg_satisfaction
FROM ev_sales
GROUP BY year, quarter, vehicle_type
ORDER BY year, quarter, vehicle_type;


-- ──────────────────────────────────────────────────────────
-- Q07: Customer Segment Deep Dive
-- ──────────────────────────────────────────────────────────
SELECT
    customer_segment,
    vehicle_type,
    COUNT(*)                                                        AS transactions,
    ROUND(SUM(sale_price_usd) / 1e6, 2)                            AS revenue_millions,
    ROUND(AVG(sale_price_usd), 0)                                   AS avg_price,
    ROUND(AVG(satisfaction_score), 2)                               AS avg_satisfaction,
    ROUND(AVG(CAST(incentive_applied AS SIGNED)) * 100, 1)          AS incentive_usage_pct,
    ROUND(SUM(federal_tax_credit) / 1e6, 2)                        AS total_credits_millions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)              AS overall_share_pct
FROM ev_sales
GROUP BY customer_segment, vehicle_type
ORDER BY revenue_millions DESC;


-- ──────────────────────────────────────────────────────────
-- Q08: Rolling 3-Month Revenue Moving Average
-- ──────────────────────────────────────────────────────────
WITH monthly AS (
    SELECT
        DATE_FORMAT(sale_date, '%Y-%m-01')              AS month_start,
        COUNT(*)                                        AS transactions,
        SUM(sale_price_usd)                             AS revenue
    FROM ev_sales
    GROUP BY DATE_FORMAT(sale_date, '%Y-%m-01')
)
SELECT
    month_start,
    transactions,
    ROUND(revenue / 1e6, 2)                             AS revenue_millions,
    ROUND(AVG(revenue) OVER (
        ORDER BY month_start
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) / 1e6, 2)                                         AS rolling_3m_avg_millions,
    ROUND(SUM(revenue) OVER (ORDER BY month_start) / 1e6, 2) AS cumulative_revenue_millions
FROM monthly
ORDER BY month_start;


-- ──────────────────────────────────────────────────────────
-- Q09: Price Tier Segmentation Analysis
-- ──────────────────────────────────────────────────────────
SELECT
    CASE 
        WHEN sale_price_usd < 35000  THEN '💚 Economy (<$35K)'
        WHEN sale_price_usd < 55000  THEN '💛 Mid-Range ($35K-$55K)'
        WHEN sale_price_usd < 80000  THEN '🟠 Premium ($55K-$80K)'
        WHEN sale_price_usd < 110000 THEN '🔴 Luxury ($80K-$110K)'
        ELSE '👑 Ultra-Luxury (>$110K)'
    END                                                         AS price_tier,
    vehicle_type,
    COUNT(*)                                                    AS transactions,
    ROUND(AVG(sale_price_usd), 0)                               AS avg_price,
    ROUND(SUM(sale_price_usd) / 1e6, 2)                        AS revenue_millions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)          AS market_share_pct,
    ROUND(AVG(satisfaction_score), 2)                           AS avg_satisfaction,
    ROUND(AVG(CAST(incentive_applied AS SIGNED)) * 100, 1)      AS incentive_rate_pct
FROM ev_sales
GROUP BY price_tier, vehicle_type
ORDER BY AVG(sale_price_usd), vehicle_type;


-- ──────────────────────────────────────────────────────────
-- Q10: Incentive Impact Analysis
-- ──────────────────────────────────────────────────────────
SELECT
    vehicle_type,
    incentive_applied,
    COUNT(*)                                                        AS transactions,
    ROUND(AVG(sale_price_usd), 0)                                   AS avg_gross_price,
    ROUND(AVG(net_price_usd), 0)                                    AS avg_net_price,
    ROUND(AVG(federal_tax_credit), 0)                               AS avg_credit_received,
    ROUND(AVG(satisfaction_score), 3)                               AS avg_satisfaction,
    ROUND(AVG(sale_price_usd) - 
        AVG(CASE WHEN NOT incentive_applied THEN sale_price_usd END) 
        OVER(PARTITION BY vehicle_type), 0)                         AS price_lift_from_incentive
FROM ev_sales
GROUP BY vehicle_type, incentive_applied
ORDER BY vehicle_type, incentive_applied DESC;


-- ──────────────────────────────────────────────────────────
-- Q11: Top Models by Region (Pivot-style)
-- ──────────────────────────────────────────────────────────
WITH model_region AS (
    SELECT
        model,
        brand,
        region,
        COUNT(*) AS units,
        ROUND(SUM(sale_price_usd) / 1e6, 2) AS revenue_m,
        RANK() OVER (PARTITION BY region ORDER BY COUNT(*) DESC) AS rank_in_region
    FROM ev_sales
    GROUP BY model, brand, region
)
SELECT *
FROM model_region
WHERE rank_in_region <= 3
ORDER BY region, rank_in_region;


-- ──────────────────────────────────────────────────────────
-- Q12: Satisfaction Drivers Correlation
-- ──────────────────────────────────────────────────────────
SELECT
    CASE 
        WHEN sale_price_usd < 40000 THEN 'Economy'
        WHEN sale_price_usd < 70000 THEN 'Mid-Range'
        WHEN sale_price_usd < 100000 THEN 'Premium'
        ELSE 'Luxury'
    END AS price_tier,
    vehicle_type,
    charging_type,
    customer_segment,
    ROUND(AVG(satisfaction_score), 3)   AS avg_satisfaction,
    COUNT(*)                            AS sample_size,
    ROUND(MIN(satisfaction_score), 1)   AS min_score,
    ROUND(MAX(satisfaction_score), 1)   AS max_score
FROM ev_sales
WHERE charging_type != 'N/A'
GROUP BY 1,2,3,4
HAVING COUNT(*) > 50
ORDER BY avg_satisfaction DESC
LIMIT 20;


-- ──────────────────────────────────────────────────────────
-- Q13: Dealer Performance Analysis
-- ──────────────────────────────────────────────────────────
SELECT
    region,
    brand,
    COUNT(*)                                            AS transactions,
    ROUND(AVG(dealer_margin_pct) * 100, 2)              AS avg_margin_pct,
    ROUND(SUM(dealer_revenue_usd) / 1e6, 3)             AS total_dealer_revenue_m,
    ROUND(AVG(dealer_revenue_usd), 0)                   AS avg_revenue_per_sale,
    ROUND(SUM(dealer_revenue_usd) / SUM(sale_price_usd) * 100, 2) AS effective_margin_pct
FROM ev_sales
GROUP BY region, brand
ORDER BY total_dealer_revenue_m DESC
LIMIT 30;


-- ──────────────────────────────────────────────────────────
-- Q14: Market Share Trend (for Power BI time-series)
-- ──────────────────────────────────────────────────────────
SELECT
    year,
    brand,
    COUNT(*) AS units,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY year), 2) AS brand_share_pct,
    ROUND(SUM(sale_price_usd) * 100.0 / SUM(SUM(sale_price_usd)) OVER(PARTITION BY year), 2) AS revenue_share_pct
FROM ev_sales
GROUP BY year, brand
ORDER BY year, units DESC;


-- ──────────────────────────────────────────────────────────
-- Q15: Fleet vs Individual Buyer Behavior
-- ──────────────────────────────────────────────────────────
WITH segment_stats AS (
    SELECT
        customer_segment,
        year,
        COUNT(*) AS purchases,
        AVG(sale_price_usd) AS avg_spend,
        AVG(satisfaction_score) AS avg_satisfaction,
        AVG(electric_range_miles) AS avg_range,
        AVG(CAST(incentive_applied AS SIGNED)) AS incentive_usage
    FROM ev_sales
    GROUP BY customer_segment, year
)
SELECT
    customer_segment,
    year,
    purchases,
    ROUND(avg_spend, 0) AS avg_spend_usd,
    ROUND(avg_satisfaction, 2) AS satisfaction,
    ROUND(avg_range, 0) AS avg_range_miles,
    CONCAT(ROUND(incentive_usage * 100, 1), '%') AS incentive_rate,
    ROUND(purchases - LAG(purchases) OVER(PARTITION BY customer_segment ORDER BY year), 0) AS yoy_change
FROM segment_stats
ORDER BY customer_segment, year;


-- ============================================================
-- SECTION 3: VIEWS FOR POWER BI INTEGRATION
-- ============================================================

CREATE OR REPLACE VIEW vw_regional_summary AS
SELECT 
    region,
    year,
    quarter,
    vehicle_type,
    customer_segment,
    COUNT(*) AS transactions,
    SUM(sale_price_usd) AS total_revenue,
    AVG(sale_price_usd) AS avg_price,
    AVG(satisfaction_score) AS avg_satisfaction,
    SUM(federal_tax_credit) AS total_incentives,
    SUM(dealer_revenue_usd) AS dealer_revenue
FROM ev_sales
GROUP BY region, year, quarter, vehicle_type, customer_segment;

CREATE OR REPLACE VIEW vw_brand_performance AS
SELECT
    brand,
    model,
    vehicle_type,
    year,
    region,
    COUNT(*) AS units_sold,
    SUM(sale_price_usd) AS revenue,
    AVG(sale_price_usd) AS avg_price,
    AVG(satisfaction_score) AS satisfaction,
    AVG(dealer_margin_pct) AS avg_margin
FROM ev_sales
GROUP BY brand, model, vehicle_type, year, region;

CREATE OR REPLACE VIEW vw_monthly_trends AS
SELECT
    DATE_FORMAT(sale_date, '%Y-%m-01') AS month,
    year,
    quarter,
    COUNT(*) AS transactions,
    SUM(sale_price_usd) AS revenue,
    AVG(sale_price_usd) AS avg_price,
    SUM(CASE WHEN vehicle_type='BEV' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS bev_rate,
    AVG(satisfaction_score) AS avg_satisfaction
FROM ev_sales
GROUP BY DATE_FORMAT(sale_date, '%Y-%m-01'), year, quarter;

-- ============================================================
-- END OF SCRIPT
-- ============================================================
