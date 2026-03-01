# ⚡ Electric Vehicle Market Analysis
### Power BI | DAX | SQL | Excel

![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![SQL](https://img.shields.io/badge/SQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Excel](https://img.shields.io/badge/Excel-217346?style=for-the-badge&logo=microsoftexcel&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)

---

## 📌 Project Overview

A full-stack data analytics project analyzing **150,000+ electric vehicle transactions** across 15 US states from **2019–2024**. Built to surface high-growth markets, track adoption trends, and model revenue potential — delivered as an interactive Power BI dashboard backed by a robust SQL and DAX layer.

> **Resume Bullets:**
> - Built Power BI dashboard analyzing 150K+ EV transaction records to identify high-growth regions and BEV adoption trends using star schema modeling
> - Designed 19 complex DAX measures including YoY revenue growth, rolling averages, and a proprietary Revenue Potential Scoring model
> - Authored 15+ SQL queries (CTEs, window functions, RANK, LAG) for regional performance, cohort analysis, and incentive impact measurement

---

## 📊 Key Metrics at a Glance

| Metric | Value |
|--------|-------|
| 📁 Total Records | 150,000 transactions |
| 💰 Total Revenue | ~$8.9 Billion |
| 🗓️ Time Period | 2019 – 2024 |
| 🗺️ Geography | 15 US States |
| 🚗 Brands Covered | 12 major EV brands |
| 🔋 Vehicle Types | BEV, PHEV, HEV |
| 👤 Customer Segments | Individual, Fleet, Commercial, Government |
| ⚡ BEV Market Share | ~55% of transactions |
| 💚 Incentive Rate | ~58% of buyers used federal credits |

---

## 🗂️ Repository Structure

```
ev-market-analysis/
│
├── 📄 README.md                          # This file
│
├── 📊 EV_Market_Analysis_Dashboard.xlsx  # 7-tab Excel workbook
│   ├── Sheet 1: Executive Dashboard
│   ├── Sheet 2: Regional Analysis
│   ├── Sheet 3: Brand & Model Analysis
│   ├── Sheet 4: DAX Measures (Power BI)
│   ├── Sheet 5: SQL Queries Reference
│   ├── Sheet 6: Market Insights
│   └── Sheet 7: Data Sample (5K rows)
│
├── 📋 EV_Market_Data_150k.csv            # Full 150K-row dataset (19 fields)
│
├── 🗄️ EV_Market_SQL_Queries.sql          # 15 analytical SQL queries + schema
│
└── 📘 EV_Market_PowerBI_Guide.docx       # Power BI setup & DAX reference guide
```

---

## 🛠️ Tech Stack

| Tool | Usage |
|------|-------|
| **Power BI Desktop** | Interactive dashboard, star schema modeling, slicers |
| **DAX** | 19 measures: KPIs, time intelligence, market share, scoring |
| **SQL (MySQL / PostgreSQL)** | Schema design, 15 analytical queries, views |
| **Excel (openpyxl)** | 7-tab workbook with conditional formatting and charts |
| **Python (pandas, numpy)** | Dataset generation, data transformation |

---

## 📐 Data Model (Star Schema)

```
                    ┌─────────────┐
                    │  dim_date   │
                    │─────────────│
                    │ date_key PK │
                    │ year        │
                    │ quarter     │
                    │ month_name  │
                    │ season      │
                    └──────┬──────┘
                           │
┌─────────────┐    ┌───────▼────────┐    ┌──────────────┐
│ dim_region  │    │   ev_sales     │    │  (Brand Dim) │
│─────────────│    │   (FACT TABLE) │    │──────────────│
│ region_id PK│◄───│ transaction_id │    │  brand       │
│ region_name │    │ sale_date  FK  │    │  vehicle_type│
│ state_code  │    │ region     FK  │    │  model       │
│ census_reg  │    │ brand          │    └──────────────┘
│ timezone    │    │ sale_price_usd │
└─────────────┘    │ vehicle_type   │
                   │ satisfaction   │
                   │ incentive_flag │
                   │ dealer_revenue │
                   └────────────────┘
```

---

## 📈 DAX Measures Implemented

<details>
<summary><b>Core KPI Measures (click to expand)</b></summary>

```dax
-- Total Transactions
Total Transactions = COUNTROWS(EV_Sales)

-- Total Revenue
Total Revenue = SUM(EV_Sales[Sale_Price_USD])

-- Average Sale Price
Avg Sale Price = AVERAGE(EV_Sales[Sale_Price_USD])

-- Net Revenue After Incentives
Net Revenue = SUM(EV_Sales[Net_Price_USD])
```
</details>

<details>
<summary><b>Time Intelligence (click to expand)</b></summary>

```dax
-- Year-over-Year Revenue Growth
YoY Revenue Growth =
VAR CurrentYear = SUM(EV_Sales[Sale_Price_USD])
VAR PriorYear   = CALCULATE(
    SUM(EV_Sales[Sale_Price_USD]),
    DATEADD(DateTable[Date], -1, YEAR)
)
RETURN DIVIDE(CurrentYear - PriorYear, PriorYear, 0)

-- Rolling 3-Month Average
Rolling 3M Avg =
CALCULATE(
    AVERAGE(EV_Sales[Sale_Price_USD]),
    DATESINPERIOD(DateTable[Date], LASTDATE(DateTable[Date]), -3, MONTH)
)

-- Same Period Last Year
SPLY Revenue =
CALCULATE(SUM(EV_Sales[Sale_Price_USD]),
    SAMEPERIODLASTYEAR(DateTable[Date]))
```
</details>

<details>
<summary><b>Market Share & Scoring (click to expand)</b></summary>

```dax
-- Brand Market Share
Brand Market Share =
DIVIDE(COUNTROWS(EV_Sales),
    CALCULATE(COUNTROWS(EV_Sales), ALL(EV_Sales[Brand])))

-- BEV Penetration Rate
BEV Penetration =
DIVIDE(COUNTROWS(FILTER(EV_Sales, EV_Sales[Vehicle_Type] = "BEV")),
    COUNTROWS(EV_Sales))

-- Revenue Potential Score (Custom Model)
Revenue Potential Score =
VAR AvgPrice     = AVERAGE(EV_Sales[Sale_Price_USD])
VAR GrowthRate   = [YoY Revenue Growth]
VAR IncentiveRate = AVERAGE(EV_Sales[Incentive_Applied])
RETURN ROUND((AvgPrice / 10000) * (1 + GrowthRate) * (1 + IncentiveRate), 2)
```
</details>

---

## 🗄️ SQL Highlights

<details>
<summary><b>Regional Revenue Potential Scoring (click to expand)</b></summary>

```sql
WITH region_metrics AS (
    SELECT
        region,
        AVG(sale_price_usd)                                         AS avg_price,
        COUNT(*)                                                    AS volume,
        AVG(CAST(incentive_applied AS SIGNED))                      AS incentive_rate,
        AVG(satisfaction_score)                                     AS avg_satisfaction,
        SUM(CASE WHEN vehicle_type='BEV' THEN 1 ELSE 0 END) * 1.0
            / COUNT(*)                                              AS bev_rate
    FROM ev_sales
    GROUP BY region
),
scored AS (
    SELECT *,
        ROUND(
            (avg_price / 10000 * 0.30) +
            (volume    / 5000.0 * 0.25) +
            (incentive_rate * 10 * 0.20) +
            (avg_satisfaction / 5.0 * 10 * 0.15) +
            (bev_rate * 10 * 0.10), 2
        ) AS potential_score
    FROM region_metrics
)
SELECT *, RANK() OVER (ORDER BY potential_score DESC) AS priority_rank
FROM scored ORDER BY potential_score DESC;
```
</details>

<details>
<summary><b>YoY Growth with Window Functions (click to expand)</b></summary>

```sql
WITH yearly AS (
    SELECT year, COUNT(*) AS transactions, SUM(sale_price_usd) AS revenue
    FROM ev_sales GROUP BY year
)
SELECT
    year,
    transactions,
    ROUND(revenue / 1e6, 2)                                             AS revenue_millions,
    ROUND((transactions - LAG(transactions) OVER (ORDER BY year))
          * 100.0 / NULLIF(LAG(transactions) OVER (ORDER BY year), 0), 2) AS yoy_growth_pct,
    ROUND(SUM(revenue) OVER (ORDER BY year) / 1e6, 2)                  AS cumulative_revenue_m
FROM yearly ORDER BY year;
```
</details>

**Full query list (15 total):**

| # | Query | Technique Used |
|---|-------|----------------|
| Q01 | Executive KPI Summary | UNION ALL aggregations |
| Q02 | Regional Market Analysis | GROUP BY + window functions |
| Q03 | YoY Growth Analysis | LAG(), cumulative SUM() OVER |
| Q04 | Brand Competitive Analysis | RANK(), DENSE_RANK() |
| Q05 | Revenue Potential Scoring | CTE + weighted composite formula |
| Q06 | Vehicle Type Trends | PARTITION BY year, quarter |
| Q07 | Customer Segment Deep Dive | FILTER + segment share |
| Q08 | Rolling 3-Month Revenue | ROWS BETWEEN window frame |
| Q09 | Price Tier Segmentation | CASE WHEN classification |
| Q10 | Incentive Impact Analysis | Conditional aggregation |
| Q11 | Top Models by Region | RANK() PARTITION BY region |
| Q12 | Satisfaction Drivers | Multi-group correlation |
| Q13 | Dealer Performance | Effective margin calculation |
| Q14 | Market Share Trends | Share % OVER year partition |
| Q15 | Fleet vs Individual Buyers | Cohort YoY with LAG() |

---

## 📊 Dashboard Pages (Power BI)

| Page | Visuals | Key Insight |
|------|---------|-------------|
| **Executive Overview** | 7 KPI cards, line chart, donut | Revenue trends, BEV share |
| **Regional Analysis** | Map, bar chart, matrix | California leads; TX/FL growth opportunity |
| **Brand Competitiveness** | Scatter, bar, table | Tesla dominates; Rivian premium niche |
| **Adoption Trends** | Line, area, waterfall | BEV accelerating post-2021 |
| **Customer Segments** | Stacked bar, matrix | Fleet buyers = higher avg spend |
| **Incentive Analysis** | Gauge, comparison bars | 58% incentive rate; $7,500 avg credit |

---

## 🔑 Key Findings

1. **🏆 California dominates** with the highest revenue share among all regions (~22% of total)
2. **📈 BEV acceleration** — pure electric vehicles grew from 45% to 60%+ of sales by 2024
3. **💰 Incentive impact** — buyers using federal credits show higher satisfaction and larger vehicle purchases
4. **🎯 Texas & Florida** have high volume but lower BEV penetration — prime markets for infrastructure investment
5. **🚀 Tesla leads** with ~28% unit market share and highest brand revenue across all years
6. **👥 Fleet segment** averages 12–15% higher transaction values than individual buyers
7. **🔌 DC Fast Charging** adoption correlates with higher satisfaction scores in BEV segment

---

## 🚀 How to Use

### Option 1: Power BI Dashboard
1. Download `EV_Market_Data_150k.csv`
2. Open Power BI Desktop → **Get Data → Text/CSV**
3. Build star schema with `dim_date` and `dim_region`
4. Mark `dim_date` as a Date Table
5. Copy DAX measures from **Sheet 4** of the Excel workbook
6. Refer to `EV_Market_PowerBI_Guide.docx` for full setup instructions

### Option 2: SQL Analysis
```bash
# MySQL
mysql -u root -p < EV_Market_SQL_Queries.sql

# PostgreSQL
psql -U postgres -f EV_Market_SQL_Queries.sql

# Then import CSV
LOAD DATA INFILE 'EV_Market_Data_150k.csv'
INTO TABLE ev_sales FIELDS TERMINATED BY ',' IGNORE 1 ROWS;
```

### Option 3: Excel Workbook
Open `EV_Market_Analysis_Dashboard.xlsx` directly — all 7 tabs are pre-built with data, formulas, and conditional formatting.

---

## 📋 Dataset Fields

| Field | Type | Description |
|-------|------|-------------|
| `transaction_id` | VARCHAR | Unique record ID (EV0000001 format) |
| `sale_date` | DATE | Transaction date |
| `year / quarter / month` | INT | Time partitioning fields |
| `region` | VARCHAR | US state of sale |
| `brand` | VARCHAR | Vehicle manufacturer |
| `model` | VARCHAR | Specific model name |
| `vehicle_type` | VARCHAR | BEV / PHEV / HEV |
| `sale_price_usd` | DECIMAL | Gross sale price |
| `electric_range_miles` | INT | EPA-rated range |
| `charging_type` | VARCHAR | DC Fast / Level 2 / Both |
| `customer_segment` | VARCHAR | Individual / Fleet / Commercial / Gov |
| `incentive_applied` | BOOLEAN | Federal credit used flag |
| `federal_tax_credit` | DECIMAL | Credit amount ($0, $3,750, or $7,500) |
| `net_price_usd` | DECIMAL | Price after tax credit |
| `satisfaction_score` | DECIMAL | Customer rating (1.0–5.0) |
| `dealer_margin_pct` | DECIMAL | Dealer gross margin percentage |
| `dealer_revenue_usd` | DECIMAL | Dealer profit per transaction |

---

## 🏗️ Project Setup (Reproduce Dataset)

```bash
# Clone the repo
git clone https://github.com/yourusername/ev-market-analysis.git
cd ev-market-analysis

# Install Python dependencies
pip install pandas numpy openpyxl

# Regenerate the 150K dataset (if needed)
python generate_dataset.py

# Rebuild the Excel workbook
python create_excel.py
```

**Requirements:**
- Python 3.8+
- pandas, numpy, openpyxl
- Power BI Desktop (free) for dashboard
- MySQL 8+ or PostgreSQL 14+ for SQL queries

---

## 📁 Files for Google Drive Upload

Create a folder named **`EV_Market_Analysis_Project`** and upload all 4 files:

```
EV_Market_Analysis_Project/
├── EV_Market_Data_150k.csv              ← Import into Power BI / SQL
├── EV_Market_Analysis_Dashboard.xlsx   ← Open directly in Excel
├── EV_Market_SQL_Queries.sql            ← Run in any SQL client
└── EV_Market_PowerBI_Guide.docx        ← Follow for Power BI setup
```

---

## 👤 Author

Built as a portfolio data analytics project demonstrating end-to-end skills in:
- **Data Engineering** — schema design, dataset generation, SQL views
- **Business Intelligence** — Power BI modeling, DAX time intelligence
- **Analytics** — market segmentation, cohort analysis, scoring models
- **Visualization** — executive dashboards, conditional formatting, KPI design

---

## 📄 License

This project is for portfolio and educational purposes. Dataset is synthetically generated.
