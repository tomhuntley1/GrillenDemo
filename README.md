# GrillenDemo - NorthRoute Logistics Data Pipeline

A hands-on data engineering demo built around a fictional UK logistics company. It walks through the **Medallion Architecture** (Bronze > Silver > Gold) using Azure Data Factory, PostgreSQL as a source ERP system, and Azure SQL as the data warehouse.

The source data is intentionally messy - duplicates, cancelled orders, missing weights, inconsistent casing - and the pipeline cleans, transforms, and reshapes it into an analytics-ready star schema.

---

## What you will build

```
PostgreSQL (source ERP)
    erp.warehouses, erp.customers, erp.delivery_orders (73 rows, messy)

        Azure Data Factory - metadata-driven pipeline
        Lookup pipeline_control > ForEach > Copy to Bronze
        Stored proc: Bronze > Silver (clean + flag)
        Stored proc: Silver > Gold  (star schema)

Azure SQL (northroute-demo database)
    brz.*   Bronze  - exact copy of source
    slv.*   Silver  - deduplicated, cleaned, DQ flagged
    gld.*   Gold    - fact + dimension tables, ready for Power BI
```

---

## Prerequisites

- An **Azure subscription** (contributor access to create resources)
- **Terraform** v1.3+ - [install guide](https://developer.hashicorp.com/terraform/install)
- **Azure CLI** - [install guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- **PostgreSQL 15** - [download from postgresql.org](https://www.postgresql.org/download/)
- **pgAdmin** or **psql** (installed with PostgreSQL)
- **SSMS** (SQL Server Management Studio) - [download here](https://aka.ms/ssmsfullsetup)
- **sqlcmd** - included with SSMS, or install the [standalone tools](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility)

---

## Step 1 - Provision Azure infrastructure

This creates the Azure SQL database, two ADF instances, Key Vault, and Storage Account.

```bash
cd terraform

# Copy the example config and fill in your values
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `sql_admin_username` - your chosen SQL admin username
- `sql_admin_password` - must be 8+ chars with uppercase, lowercase, number, and symbol
- `my_ip_address` - your public IP (so you can connect to SQL from your machine - find it at whatismyip.com)
- `location` - Azure region, e.g. `uksouth`

Then run:

```bash
az login
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Note the outputs - you will need the **SQL Server FQDN** and **ADF instance names** in later steps.

---

## Step 2 - Set up PostgreSQL (source database)

### Install PostgreSQL

Download and install PostgreSQL 15 from [postgresql.org/download](https://www.postgresql.org/download/). The default port is `5432`. During installation, set a password for the `postgres` superuser.

For a full walkthrough of the installation and network configuration, see [sql/source/POSTGRES_SETUP_WORKSPACE.md](sql/source/POSTGRES_SETUP_WORKSPACE.md).

### Create the demo user

Open pgAdmin or psql and run:

```sql
CREATE USER demo_user WITH PASSWORD 'Demo1234!';
GRANT ALL PRIVILEGES ON DATABASE postgres TO demo_user;
```

### Create the database and seed the data

Run `sql/source/01_postgres_setup.sql` against your PostgreSQL instance. This creates:
- The `northroute_erp` database
- The `erp` schema with `warehouses`, `customers`, and `delivery_orders` tables
- All 73 rows of demo data (intentionally messy)

### Allow network access from Azure

ADF in the cloud needs to reach your PostgreSQL instance over the network. You will need to:

1. Edit `pg_hba.conf` to allow connections from external IPs (or `0.0.0.0/0` for testing)
2. Edit `postgresql.conf` and set `listen_addresses = '*'`
3. Open **port 5432** in your machine's firewall / router
4. Note your **public IP address** - you will need this when configuring the ADF linked service

Restart PostgreSQL after making these changes.

> **Note:** If your machine does not have a stable public IP, consider running PostgreSQL on a cloud VM (e.g. an Azure VM or AWS WorkSpace) to avoid firewall complexity.

---

## Step 3 - Set up Azure SQL (sink database)

Connect to your Azure SQL server using SSMS. The server address is in the Terraform output (`sql_server_fqdn`). Run the following scripts **in order**:

| Script | What it does |
|--------|-------------|
| `sql/sink/02_azuresql_setup.sql` | Creates Bronze, Silver, and Gold schemas and all tables |
| `sql/sink/03_sp_brz_to_slv.sql` | Creates the Bronze to Silver stored procedure |
| `sql/sink/04_sp_slv_to_gld.sql` | Creates the Silver to Gold stored procedure |
| `sql/sink/control_table.sql` | Creates and populates the `pipeline_control` metadata table |

---

## Step 4 - Configure Azure Data Factory

Open your ADF instance in the Azure portal. Terraform creates two ADF instances - use the **live** one (named `adf-northroute-...-live`) for setup. The other is a backup reference copy.

### 4a - Create linked services

Go to **Manage > Linked services > New** and create these two:

**Azure SQL linked service** (name it exactly `ls_azuresql_northroute`):
- Type: Azure SQL Database
- Server: your SQL Server FQDN from Terraform output
- Database: `northroute-demo`
- Authentication: SQL authentication
- Username / Password: the values you set in `terraform.tfvars`

**PostgreSQL linked service** (name it exactly `PostgreSql1`):
- Type: PostgreSQL (V2)
- Server: your PostgreSQL machine's public IP
- Port: `5432`
- Database: `northroute_erp`
- Username: `demo_user`
- Password: `Demo1234!`

Test both connections before moving on.

### 4b - Import datasets

Go to **Author > Datasets**. For each file in `adf/datasets/`, click **New dataset > ... > Import from JSON** and upload the file:

- `adf/datasets/ds_azuresql_sink.json`
- `adf/datasets/ds_postgres_source.json`

Publish after importing both.

### 4c - Import pipelines

Go to **Author > Pipelines**. For each file in `adf/pipelines/`, click the `{}` (Code) button on a new blank pipeline, paste the JSON, and save. Import all three:

- `adf/pipelines/1_lookup.json` - Lookup only (step 1 of the demo)
- `adf/pipelines/2_foreach_copy.json` - Lookup + ForEach + Copy (step 2)
- `adf/pipelines/Final_complete.json` - Full pipeline including stored procs (step 3)

Publish all pipelines.

---

## Step 5 - Reset and run the demo

### Reset to a clean state

Before running (or re-running) the demo, reset the Azure SQL data:

```powershell
# Edit scripts/reset-demo.ps1 first - update the server, database, and username
# to match your Terraform outputs, then run:
.\scripts\reset-demo.ps1
```

This truncates all data layers and re-applies the schemas and stored procedures, leaving you with a clean slate.

### Run the demo pipelines

In ADF, trigger the pipelines in order to walk through the demo narrative:

1. **Pipeline 1** - Run and show the Lookup output (the control table)
2. **Pipeline 2** - Run and show data landing in Bronze
3. **Pipeline Final** - Run the full pipeline (Bronze > Silver > Gold via stored procs)

### Explore the data

Use the scripts in `DataExploreScripts/` in SSMS to walk through each layer:

| Script | What it shows |
|--------|--------------|
| `DataExploreScripts/Source.sql` | The messy source data in PostgreSQL |
| `DataExploreScripts/Bronze.sql` | Exact copy - duplicates and errors still present |
| `DataExploreScripts/Silver.sql` | Cleaned, deduplicated, DQ flagged |
| `DataExploreScripts/Gold.sql` | Star schema - analytics queries |
| `DataExploreScripts/CountAll.sql` | Row counts across all layers |
| `DataExploreScripts/ViewAllTables.sql` | Full contents of every table |

---

## Repository structure

```
terraform/              Azure infrastructure (Resource Group, SQL, ADF, Key Vault)
sql/
    source/             PostgreSQL setup script and setup guide
    sink/               Azure SQL schemas, stored procedures, control table
    teardown/           Reset script (truncates data, keeps structure)
adf/
    pipelines/          ADF pipeline JSON definitions (import into ADF)
    datasets/           ADF dataset JSON definitions (import into ADF)
DataExploreScripts/     SQL query scripts for exploring each layer
scripts/                PowerShell reset automation
```
