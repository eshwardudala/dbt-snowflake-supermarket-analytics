# dbt-snowflake-supermarket-analytics

## 📌 Project Overview

This project is a **learning-focused data analytics pipeline** built using **dbt-core** and **Snowflake**, demonstrating a practical **data reconciliation and validation workflow** using advanced dbt patterns.

The core objective is to validate data migration integrity by comparing source and target datasets across multiple dimensions:
- **Data completeness:** Detect missing rows
- **Data accuracy:** Verify column-by-column matching
- **Data consistency:** Identify value mismatches through row hashing

This repository demonstrates:
- Advanced dbt features (macros, dynamic SQL, full outer joins)
- Custom reconciliation models with row hashing
- Layered data validation (sources → staging → validation models)
- Integration of **Snowflake with dbt**
- Git-based version control for analytics engineering workflows

---

## 🧠 Prerequisites & Background

Before starting this project, I had:
- Prior knowledge of **Snowflake**
- Experience using **Git & GitHub**
- Beginner-level understanding of **dbt**, which is expanded through this project

---

## 🛠️ Tech Stack

- **Data Warehouse:** Snowflake  
- **Transformation Tool:** dbt-core  
- **Version Control:** GitHub  
- **Reconciliation Domain:** Data migration validation  

---

## 📂 Data Description

The project uses two primary datasets for reconciliation purposes:

### Source Data (`landing.customers`)
Original customer dataset used as the source of truth for comparison.

### Target Data (`landing.migrated_customers`)
Migrated customer dataset that needs validation against the source.

Both datasets are loaded as **dbt sources** in Snowflake and serve as inputs for all downstream validation models.

---

## 🧱 Project Architecture

The project follows a **three-layer validation framework**:

### 📋 Layer 1: Staging Models
These models extract source and target data, computing row hashes for efficient comparison.

#### `stg_source`
- **Source:** `landing.customers`
- **Purpose:** Prepares source data with a computed row hash
- **Row Hash:** MD5 hash of all non-key columns (concatenated and cast to VARCHAR)
- **Tests:** 
  - NOT NULL on primary key (CUSTOMERID)
  - UNIQUE on primary key (CUSTOMERID)

#### `stg_target`
- **Source:** `landing.migrated_customers`
- **Purpose:** Prepares target (migrated) data with a computed row hash for comparison
- **Row Hash:** MD5 hash of all non-key columns (concatenated and cast to VARCHAR)
- **Tests:**
  - NOT NULL on primary key (CUSTOMERID)
  - UNIQUE on primary key (CUSTOMERID)

---

### 🔍 Layer 2: Validation Models
These models perform deep data reconciliation using joins and comparisons.

#### `column_accuracy`
- **Purpose:** Compares each non-key column between source and target
- **Output Columns:**
  - `column_name`: Name of the column being validated
  - `total_rows`: Total rows compared for this column
  - `matched_rows`: Count of rows where values match
  - `match_percentage`: Percentage of matching rows (0-100%)
- **Logic:** UNION ALL for each column, joining source and target on primary key
- **Use Case:** Identify which columns have data quality issues

#### `missing_rows`
- **Purpose:** Detects rows missing in either source or target dataset
- **Output Columns:**
  - Primary key identifier
  - `issue`: Either 'MISSING_IN_TARGET' or 'MISSING_IN_SOURCE'
- **Logic:** LEFT JOIN from source to target UNION with LEFT JOIN from target to source
- **Use Case:** Ensure data completeness during migration

#### `row_reconciliation`
- **Purpose:** Comprehensive row-level comparison using row hashes
- **Output Columns:**
  - Primary key identifier
  - `row_status`: One of:
    - `MATCHED`: Row exists in both datasets with identical data
    - `MISSING_IN_SOURCE`: Row only in target
    - `MISSING_IN_TARGET`: Row only in source
    - `VALUE_MISMATCH`: Row exists in both but data differs
- **Logic:** FULL OUTER JOIN between source and target, comparing row hashes
- **Use Case:** Executive-level reconciliation summary

---

### 🧪 Layer 3: Data Quality Tests
Automated tests that fail the dbt run if data quality thresholds are breached.

#### `row_count_match`
- **Purpose:** Validates that source and target have identical row counts
- **Logic:** Compares `count(*)` between stg_source and stg_target
- **Failure Condition:** Row counts differ
- **Importance:** Detects mass data loss or duplication during migration

#### `exact_match`
- **Purpose:** Validates that all rows with matching primary keys have identical row hashes
- **Logic:** LEFT JOIN stg_source to stg_target, checking for row_hash mismatches
- **Failure Condition:** Any row_hash mismatch detected
- **Importance:** Ensures data values are exactly preserved

#### `row_hash_match`
- **Purpose:** Alternative exact match validation (same logic as exact_match)
- **Logic:** Joins on primary key and compares row hashes
- **Failure Condition:** Any row_hash discrepancy
- **Note:** Duplicate of exact_match for redundant validation

---

## 🛠️ Custom Macros

The project uses **two custom macros** for dynamic, reusable SQL generation:

### `generate_row_hash(relation, primary_key)`
**File:** [macros/generate_row_hash.sql](macros/generate_row_hash.sql)

**Purpose:** Generates an MD5 hash of all non-key columns to efficiently detect row changes.

**Logic:**
1. Takes a table relation and primary key column(s)
2. Calls `get_non_key_columns()` to identify all columns except the primary key
3. Concatenates non-key columns with pipe delimiters (|)
4. Casts each value to VARCHAR to ensure consistent hashing
5. Returns MD5 hash of the concatenated string

**Usage:**
```sql
{{ generate_row_hash(source('landing', 'customers'), var('primary_key')) }} as row_hash
```

**Benefits:**
- Single hash comparison instead of column-by-column checks
- Efficient detection of ANY data change in a row
- Enables full outer join reconciliation

---

### `get_non_key_columns(relation, primary_key)`
**File:** [macros/get_non_key_columns.sql](macros/get_non_key_columns.sql)

**Purpose:** Dynamically extracts all columns from a table EXCEPT the primary key(s).

**Logic:**
1. Uses `adapter.get_columns_in_relation()` to fetch all columns from the Snowflake table
2. Converts primary key column names to lowercase for case-insensitive comparison
3. Iterates through all columns and filters out primary key columns
4. Returns a list of non-key column names

**Usage:**
```sql
{% for col in get_non_key_columns(ref('stg_source'), var('primary_key')) %}
    cast({{ col }} as varchar)
{% endfor %}
```

**Why It Matters:**
- Eliminates hardcoding of column lists (reduces maintenance)
- Automatically adapts to schema changes
- Works with composite primary keys
- Enables dynamic SQL generation across staging models

---

## ⚙️ Configuration

### Variables (`dbt_project.yml`)

```yaml
vars:
  primary_key: CUSTOMERID          # Primary key column for reconciliation
  source_schema: L1_LANDING        # Source schema in Snowflake
  source_table: customers          # Source table name
  target_schema: L1_LANDING        # Target schema in Snowflake
  target_table: migrated_customers # Target table name
```

These variables are referenced throughout models and macros, making it easy to switch between different source/target pairs.

---

## 📊 Data Flow & Lineage

```
landing.customers                landing.migrated_customers
    (Source)                             (Target)
       |                                   |
       └───────────┬───────────────────────┘
                   |
           ┌───────┴───────┐
           |               |
      stg_source      stg_target
   (with row_hash)  (with row_hash)
           |               |
           └───────┬───────┘
                   |
        ┌──────────┼──────────┐
        |          |          |
   column_    missing_   row_
  accuracy     rows   reconciliation
  (validation) (issues) (summary)
        |          |          |
        └──────────┼──────────┘
                   |
        ┌──────────┴──────────┐
        |          |          |
   row_count_  exact_   row_hash_
     match    match      match
    (tests)   (tests)    (tests)
```

---

## ▶️ How to Run

### Run All Models & Tests
```bash
dbt run
dbt test
```

### Run Specific Model
```bash
dbt run -s stg_source
dbt run -s row_reconciliation
```

### Run Tests Only
```bash
dbt test
```

### Generate Documentation
```bash
dbt docs generate
dbt docs serve
```

### Debug & Troubleshoot
```bash
dbt debug
dbt run --debug
```

---

## 🎯 Key Insights & Learnings

### 1. Advanced Macro Usage
- Dynamic column extraction using `adapter.get_columns_in_relation()`
- Macro composition (`generate_row_hash` calls `get_non_key_columns`)
- Handling composite primary keys

### 2. Reconciliation Patterns
- **Row Hashing:** Efficient way to detect any data change
- **Full Outer Join:** Comprehensive missing data detection
- **Union-Based Validation:** Column-level accuracy reporting

### 3. dbt Testing Strategy
- Generic tests (NOT NULL, UNIQUE) for data quality
- Singular tests (row_count_match, exact_match) for business logic
- Fail-fast approach to catch migration issues early

### 4. Dynamic SQL Generation
- Using Jinja2 loops to generate UNION ALL statements
- Template variables for schema/table flexibility
- Adapter-specific functions for Snowflake metadata

---

## 📚 File Structure

```
.
├── dbt_project.yml                    # Project configuration & variables
├── README.md                          # This file
├── schema.yml                         # Model & test definitions
├── models/
│   ├── source.yml                     # Source definitions
│   ├── staging/
│   │   ├── stg_source.sql             # Source staging model (with hash)
│   │   └── stg_target.sql             # Target staging model (with hash)
│   └── validation/
│       ├── column_accuracy.sql        # Column-by-column accuracy check
│       ├── missing_rows.sql           # Detect missing rows
│       └── row_reconciliation.sql     # Full row comparison (hash-based)
├── macros/
│   ├── generate_row_hash.sql          # MD5 hash generator macro
│   └── get_non_key_columns.sql        # Dynamic column extractor macro
├── tests/
│   ├── exact_match.sql                # Ensures no row value mismatches
│   ├── row_count_match.sql            # Ensures row count parity
│   └── row_hash_match.sql             # Alternative exact match test
├── seeds/
├── snapshots/
└── analyses/
```

---



---

## 📝 Notes

This project showcases practical dbt patterns for **data migration validation**, combining:
- **Staging models** for data preparation
- **Macros** for code reusability
- **Validation models** for analytical insights
- **Tests** for automated quality assurance

The reconciliation framework is generalizable and can be adapted for any source-to-target comparison scenario.

---

## ▶️ Quick Start

```bash
# Clone repository
git clone <repo-url>
cd dbt-snowflake-supermarket-analytics

# Install dependencies
pip install -r requirements.txt

# Configure Snowflake connection
dbt debug

# Run pipeline
dbt run && dbt test

# View results
dbt docs generate
dbt docs serve
```

---
