# NorthRoute Logistics — Data Grillen Demo
### Complete Setup Guide (Terraform + Windows)

---

> **A note before you start**
>
> This guide is one way to build this demo — not the only way. If you'd rather use
> a different tool, skip a step, or take a completely different approach, go for it.
> The goal is that you understand the concepts, not that you follow these instructions
> to the letter.
>
> If you get stuck or want to talk through anything, feel free to reach out:
> [LinkedIn](https://www.linkedin.com/in/tom-huntley-43b448131/) or tpwhuntley@proton.me

---

## What this builds

A complete ELT pipeline demo. One fictional haulage company, real-looking messy
data, three Azure resources, and a pipeline that transforms raw rubbish into a
clean star schema — live, in front of an audience.

```
Your Laptop                          Azure (provisioned by Terraform)
─────────────────────────────────    ──────────────────────────────────────────
PostgreSQL (Docker)                  Azure Data Factory
  └─ erp.delivery_orders    ──────►    └─ pl_northroute_elt pipeline
  └─ erp.warehouses         ──────►         │  Copy → brz.*  (Bronze)
  └─ erp.customers          ──────►         │  SP   → slv.*  (Silver)
                                            │  SP   → gld.*  (Gold)
                                            ▼
                                    Azure SQL Database
                                      └─ brz.*  Raw copy
                                      └─ slv.*  Cleaned + DQ flagged
                                      └─ gld.*  Star schema, query-ready
```

**Reset time:** ~3 minutes (one PowerShell command)
**Azure cost:** ~£3–5/day while resources exist. `terraform destroy` = £0.

---

## File structure

```
demo_v2/
├── terraform/                ← Provisions all Azure infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example   ← Copy + fill in, rename to .tfvars
│   └── .gitignore
│
├── sql/
│   ├── source/
│   │   ├── docker-compose.yml         ← Spins up local Postgres
│   │   └── 01_postgres_setup.sql      ← Creates source DB + 73 rows of data
│   ├── sink/
│   │   ├── 02_azuresql_setup.sql      ← Creates brz/slv/gld schemas + tables
│   │   ├── 03_sp_brz_to_slv.sql       ← Stored proc: Bronze → Silver
│   │   ├── 04_sp_slv_to_gld.sql       ← Stored proc: Silver → Gold
│   │   └── 05_demo_reveal_queries.sql ← Live demo queries, in order
│   └── teardown/
│       └── 06_teardown_azuresql.sql   ← Wipes Azure SQL clean
│
├── pipeline/
│   └── pl_northroute_elt.json    ← ADF pipeline definition
│
├── scripts/
│   └── reset-demo.ps1            ← ONE command to reset everything
│
└── README.md                     ← This file
```

---

## Prerequisites

You need these installed. Tick them off before starting:

| Tool | Check if installed | Install if not |
|------|-------------------|----------------|
| Azure CLI | `az --version` in PowerShell | https://aka.ms/installazurecliwindows |
| Terraform | `terraform --version` | https://developer.hashicorp.com/terraform/install |
| Docker Desktop | Open Docker Desktop app | https://www.docker.com/products/docker-desktop |
| Azure Data Studio | Search Start menu | https://aka.ms/azuredatastudio |
| sqlcmd | `sqlcmd -?` in PowerShell | Installed with Azure Data Studio — or https://aka.ms/sqlcmdinstall |

---

## PART 1 — First-time setup (~30 minutes)

Do this once. After this, resets take 3 minutes.

---

### Step 1 — Log in to Azure

Open **PowerShell** (not Command Prompt) and run:

```powershell
az login
```

A browser window opens. Sign in with your Azure account.

Back in PowerShell you'll see a list of subscriptions. If you have more than one,
set the right one:

```powershell
az account list --output table
# Look for your subscription in the list, then:
az account set --subscription "YOUR SUBSCRIPTION NAME OR ID"
```

Verify you're on the right one:
```powershell
az account show --output table
```

---

### Step 2 — Find your public IP address

You need this so the SQL firewall lets your laptop connect.

Go to: **https://whatismyip.com**

Note the IP address — something like `82.45.123.67`. You'll paste it shortly.

---

### Step 3 — Configure Terraform variables

In File Explorer, go to the `terraform/` folder.

Find the file called `terraform.tfvars.example`.
**Copy it** and rename the copy to `terraform.tfvars` (remove `.example`).

Open `terraform.tfvars` in any text editor (Notepad is fine) and fill it in:

```hcl
location           = "uksouth"
sql_admin_username = "northroute_admin"
sql_admin_password = "PickAStrongPassword123!"   # 8+ chars, upper, lower, number, symbol
my_ip_address      = "82.45.123.67"              # your IP from Step 2
```

Save and close. **Don't rename or move this file.**

---

### Step 4 — Run Terraform

In PowerShell, navigate to the `terraform/` folder:

```powershell
cd C:\path\to\demo_v2\terraform
```

Initialise Terraform (downloads the Azure provider — takes ~30 seconds):

```powershell
terraform init
```

You should see:
```
Terraform has been successfully initialized!
```

Preview what it's going to create (nothing is built yet):

```powershell
terraform plan
```

Read through the output. You'll see it plans to create ~10 resources:
a resource group, SQL server, SQL database, ADF, Key Vault, storage account, etc.
Everything prefixed with `+` is being created. Nothing is being changed or deleted.

Now actually create everything:

```powershell
terraform apply
```

Terraform will show the plan again and ask:
```
Do you want to perform these actions?
  Enter a value:
```

Type `yes` and press Enter.

**This takes 3–6 minutes.** Azure is provisioning the resources.

When it finishes you'll see a block of outputs like:

```
adf_name        = "adf-northroute-abc123"
adf_studio_url  = "https://adf.azure.com/en/authoring/..."
sql_server_name = "sql-northroute-abc123.database.windows.net"
sql_database_name = "northroute-demo"
sql_admin_username = "northroute_admin"
next_steps      = ...
```

**Copy these values somewhere** — you'll need the server name and ADF name in the next steps.

---

### Step 5 — Connect Azure Data Studio to your new SQL database

Open **Azure Data Studio**.

Click the **New Connection** button (plug icon, top left).

Fill in the connection details:
- **Server:** paste your `sql_server_name` from the Terraform output
  - e.g. `sql-northroute-abc123.database.windows.net`
- **Authentication type:** SQL Login
- **User name:** `northroute_admin` (or whatever you set)
- **Password:** your password from `terraform.tfvars`
- **Database:** `northroute-demo`
- **Encrypt:** Mandatory
- **Trust server certificate:** True (tick the box)

Click **Connect**.

You should see the server appear in the left panel with `northroute-demo` underneath it.

---

### Step 6 — Run the SQL setup scripts

In Azure Data Studio, with your connection active:

Click **File → Open File** and open `sql/sink/02_azuresql_setup.sql`

Press **Ctrl+Shift+E** to run it (or click the Run button ▶).

You should see output ending with:
```
Schema setup complete.
Tables created: brz(3), slv(3), gld(4), dbo.pipeline_log
```

Repeat for the next two scripts **in order**:
- `sql/sink/03_sp_brz_to_slv.sql` → should end with `usp_brz_to_slv created successfully.`
- `sql/sink/04_sp_slv_to_gld.sql` → should end with `usp_slv_to_gld created successfully.`

Verify everything was created — run this query in Azure Data Studio:

```sql
-- Should show 10 tables across brz, slv, gld schemas
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- Should show 2 stored procedures
SELECT ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE';
```

---

### Step 7 — Start the local Postgres source database

Open a **new** PowerShell window. Navigate to the source folder:

```powershell
cd C:\path\to\demo_v2\sql\source
```

Start the Docker container:

```powershell
docker-compose up -d
```

First time this runs, Docker downloads the Postgres image (~150MB). Subsequent
runs are instant.

When it says `Container northroute_postgres  Started`, verify the data loaded:

```powershell
docker exec northroute_postgres psql -U demo_user -d northroute_erp -c "SELECT COUNT(*) FROM erp.delivery_orders;"
```

Expected output: `73` (the number of rows including intentional duplicates etc.)

---

### Step 8 — Set up the Self-Hosted Integration Runtime (SHIR)

This is the bridge between your laptop (where Postgres is running) and ADF in Azure.
Without it, ADF can't reach your local database.

**8a. Create the SHIR in ADF:**

Open the `adf_studio_url` from your Terraform output in a browser.

In ADF Studio, click the **toolbox icon** on the far left (it says "Manage" on hover).

Click **Integration runtimes** in the left menu.

Click **+ New**.

Choose **Self-Hosted**. Click Continue.

Give it the name: `shir-demo-laptop`. Click Create.

You'll see a screen with two options. Choose **Option 2: Manual setup**.

Click **Download and install** — this downloads the SHIR installer.

**8b. Install the SHIR on your laptop:**

Run the downloaded installer. Accept defaults. Click through to finish.

After installation, a window pops up asking for an **Authentication key**.
Copy Key 1 from the ADF screen and paste it in. Click Register.

Wait ~30 seconds. The SHIR window should show **Connected** with a green icon.

Back in ADF Studio, the integration runtime should show **Running** (green dot).

> ⚠️ The SHIR must be running whenever you use the pipeline.
> If you restart your laptop, open "Microsoft Integration Runtime Configuration Manager"
> from the Start menu before running the demo.

---

### Step 9 — Create ADF Linked Services

Linked Services are ADF's way of storing connection details to external systems.
You need two: one for Postgres (source), one for Azure SQL (sink).

Still in ADF Studio → **Manage** → **Linked services** → **+ New**

#### Linked Service 1: PostgreSQL

Search for "PostgreSQL" and select **PostgreSQL** (the one that says "V2").

Fill in:
- **Name:** `ls_postgres_northroute`
- **Connect via integration runtime:** `shir-demo-laptop`
- **Server:** Your laptop's **local network IP address**
  - In PowerShell: `(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi").IPAddress`
  - It'll be something like `192.168.1.45` — NOT `localhost` or `127.0.0.1`
    (ADF runs in Azure so "localhost" would mean the Azure server, not your laptop)
- **Port:** `5432`
- **Database:** `northroute_erp`
- **Authentication type:** Basic
- **Username:** `demo_user`
- **Password:** `Demo1234!`
- **SSL mode:** Disable

Click **Test connection**. It should say ✓ Connection successful.

Click **Create**.

#### Linked Service 2: Azure SQL Database

Click **+ New** again. Search for "Azure SQL Database".

Fill in:
- **Name:** `ls_azuresql_northroute`
- **Connect via integration runtime:** AutoResolveIntegrationRuntime
- **Account selection method:** Enter manually
- **Fully qualified domain name:** your `sql_server_name` from Terraform output
- **Database name:** `northroute-demo`
- **Authentication type:** SQL authentication
- **Username:** `northroute_admin`
- **Password:** your SQL password

Click **Test connection**. Should say ✓ Connection successful.

Click **Create**.

---

### Step 10 — Create ADF Datasets

Datasets tell ADF which specific table in a linked service to read from or write to.
You need 6 of them (3 source, 3 sink).

In ADF Studio → **Author** (pencil icon) → **Datasets** → **+** → **New dataset**

#### Source datasets (PostgreSQL):

Create these 3 — the process is the same each time:

Select **PostgreSQL** as the type.

| Dataset name | Linked service | Schema | Table |
|---|---|---|---|
| `ds_postgres_warehouses` | ls_postgres_northroute | erp | warehouses |
| `ds_postgres_customers` | ls_postgres_northroute | erp | customers |
| `ds_postgres_delivery_orders` | ls_postgres_northroute | erp | delivery_orders |

For each one:
1. Name it as shown
2. Linked service: `ls_postgres_northroute`
3. Table name: click the dropdown, select the schema and table
4. Click **OK**

#### Sink datasets (Azure SQL):

Select **Azure SQL Database** as the type.

| Dataset name | Linked service | Schema | Table |
|---|---|---|---|
| `ds_azuresql_brz_warehouses` | ls_azuresql_northroute | brz | warehouses |
| `ds_azuresql_brz_customers` | ls_azuresql_northroute | brz | customers |
| `ds_azuresql_brz_delivery_orders` | ls_azuresql_northroute | brz | delivery_orders |

Click **Publish all** (top of screen) when all 6 are created.

---

### Step 11 — Create the Pipeline

You have two options here:

---

#### Option A — Import from JSON (~2 minutes)

The file `pipeline/pl_northroute_elt.json` contains the complete pipeline definition.

In ADF Studio → **Author** → **Pipelines** → **+** → **New pipeline**

Name it: `pl_northroute_elt`

Click the **`{}`** (Code) button in the top-right corner of the canvas.

Replace the entire contents of the editor with the contents of `pipeline/pl_northroute_elt.json`,
then click **OK**.

Click **Publish all**. ✓

You're done — skip to [Step 12](#step-12--test-run).

---

#### Option B — Build it yourself (~20 minutes)

Good if you want to understand how each activity fits together. The pipeline has 5 activities:
3 parallel Copy jobs loading raw data into Bronze, then two Stored Procedure activities
chaining Bronze→Silver and Silver→Gold.

In ADF Studio → **Author** → **Pipelines** → **+** → **New pipeline**

Name it: `pl_northroute_elt`

**Build the pipeline canvas:**

You're going to drag activities from the left panel onto the canvas.

**Activity 1, 2, 3 — Copy Data (run in parallel):**

From the Activities panel on the left, expand **Move & transform** and drag
**Copy data** onto the canvas. Do this 3 times.

Name them (click each one, edit the Name field in the General tab below):
- `Copy_Warehouses_to_Bronze`
- `Copy_Customers_to_Bronze`
- `Copy_DeliveryOrders_to_Bronze`

For **each** Copy activity, click it and configure the **Source** and **Sink** tabs:

| Activity | Source dataset | Sink dataset | Pre-copy script (in Sink tab) |
|---|---|---|---|
| Copy_Warehouses_to_Bronze | ds_postgres_warehouses | ds_azuresql_brz_warehouses | `TRUNCATE TABLE brz.warehouses` |
| Copy_Customers_to_Bronze | ds_postgres_customers | ds_azuresql_brz_customers | `TRUNCATE TABLE brz.customers` |
| Copy_DeliveryOrders_to_Bronze | ds_postgres_delivery_orders | ds_azuresql_brz_delivery_orders | `TRUNCATE TABLE brz.delivery_orders` |

The Pre-copy script is in the **Sink** tab → scroll down to find it.
This ensures Bronze is wiped clean before each load.

**Activity 4 — Stored Procedure: Bronze → Silver:**

Drag a **Stored procedure** activity onto the canvas (under General in the activity list).

Name it: `SP_Bronze_to_Silver`

Connect it to all three Copy activities: hover over each Copy activity box until
you see a small green arrow → drag it to `SP_Bronze_to_Silver`.
Do this for all three. You should see three arrows all pointing to the SP.

This means the SP only runs after ALL three Copy activities succeed.

Click `SP_Bronze_to_Silver` and configure:
- **Linked service:** `ls_azuresql_northroute`
- **Stored procedure name:** `[dbo].[usp_brz_to_slv]`
- **Stored procedure parameters:** click Import
  - Add parameter: Name = `pipeline_run_id`, Type = `String`
  - Value: click the text box → click **Add dynamic content** → select `Pipeline().RunId`

**Activity 5 — Stored Procedure: Silver → Gold:**

Drag another **Stored procedure** activity.

Name it: `SP_Silver_to_Gold`

Draw an arrow from `SP_Bronze_to_Silver` → `SP_Silver_to_Gold`.

Configure:
- **Linked service:** `ls_azuresql_northroute`
- **Stored procedure name:** `[dbo].[usp_slv_to_gld]`
- **Parameters:** same as above — `pipeline_run_id` = `@pipeline().RunId`

Your canvas should now look like:

```
[Copy Warehouses]  ──┐
[Copy Customers]   ──┼──► [SP: Brz→Slv] ──► [SP: Slv→Gld]
[Copy Deliveries]  ──┘
```

Click **Publish all**. ✓

---

### Step 12 — Test run

Click **Add trigger** (top of pipeline canvas) → **Trigger now** → **OK**.

Click the **monitor icon** (speedometer) on the left sidebar to watch it run.

You'll see the pipeline appear under Pipeline runs. Click it to see the individual
activity status. Each box turns green as it completes.

Total runtime for this data volume: ~45–90 seconds.

When complete, go to Azure Data Studio and run:

```sql
SELECT stage, status, rows_processed, message
FROM dbo.pipeline_log
ORDER BY log_id;
```

You should see:
```
SILVER | SUCCESS | 66 | Bronze rows in: 73 | Dupes removed: 3 ...
GOLD   | SUCCESS | 62 | Gold fact rows: 62 ...
```

**If you see this, your setup is complete.** 🎉

---

## PART 2 — Resetting for each demo run

### Option A: PowerShell script (recommended)

Open `scripts/reset-demo.ps1` in a text editor first.
Fill in your SQL server name and password at the top (the variables section).

Then run it:
```powershell
cd C:\path\to\demo_v2
.\scripts\reset-demo.ps1
```

It wipes everything and rebuilds in ~3 minutes. Run it before every practice session
and before the live demo.

### Option B: Manual reset

```powershell
# 1. Reset Postgres
cd sql\source
docker-compose down -v
docker-compose up -d

# 2. Reset Azure SQL — in Azure Data Studio, run these in order:
#    sql\teardown\06_teardown_azuresql.sql
#    sql\sink\02_azuresql_setup.sql
#    sql\sink\03_sp_brz_to_slv.sql
#    sql\sink\04_sp_slv_to_gld.sql
```

---

## PART 3 — Complete teardown (after the conference)

To delete **all** Azure resources and stop all charges:

```powershell
cd C:\path\to\demo_v2\terraform
terraform destroy
```

Type `yes` when prompted. Everything is gone in ~2 minutes.

To also stop Docker:
```powershell
cd ..\sql\source
docker-compose down -v
```

---

## Troubleshooting

### "Test connection failed" on the PostgreSQL linked service

The most common cause is the wrong IP address. ADF runs in Azure — when it tries
to connect to "your local Postgres", it needs to reach your laptop over the network.

1. Make sure Docker is running: open Docker Desktop, check the container is there
2. Find your actual local network IP in PowerShell:
   ```powershell
   ipconfig
   ```
   Look for **IPv4 Address** under your active network adapter (Wi-Fi or Ethernet).
   It should be something like `192.168.x.x` or `10.x.x.x`.
3. Update the linked service with this IP

If you're on a corporate network or VPN, this may be blocked. Use a personal
hotspot or home Wi-Fi for the demo if possible.

### ADF Copy activity fails: "Login failed for user"

The Azure SQL firewall is blocking ADF.

In Azure Portal → your SQL Server → **Networking**:
- Make sure "Allow Azure services and resources to access this server" is **On**
- This should already be set by Terraform, but double-check

### Stored procedure activity fails: "Could not find stored procedure"

The stored procedures weren't created. In Azure Data Studio, run:
```sql
SELECT ROUTINE_NAME FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE';
```
If it returns nothing, re-run `03_sp_brz_to_slv.sql` and `04_sp_slv_to_gld.sql`.

### Docker container exits immediately

```powershell
docker logs northroute_postgres
```
Look at the error. Usually it's a port conflict (something else using port 5432).

### Terraform apply fails: "Name already exists"

The random suffix should prevent this, but if it happens:
```powershell
terraform destroy
terraform apply
```
A new suffix is generated each time.

### SHIR shows "Disconnected" or "Limited" in ADF

Open **Microsoft Integration Runtime Configuration Manager** from your Start menu
and check the status. If it's disconnected, re-register it with the key from ADF.
The SHIR must be running before you trigger the pipeline.

---

## Demo day checklist

Run through this before you go on stage:

- [ ] Laptop plugged in (SHIR will disconnect if laptop sleeps)
- [ ] Docker Desktop open and running
- [ ] `.\scripts\reset-demo.ps1` — run it one final time
- [ ] Azure Data Studio open, connected to `northroute-demo`
- [ ] `05_demo_reveal_queries.sql` open in Azure Data Studio
- [ ] ADF Studio open in browser, pipeline canvas visible
- [ ] SHIR showing "Running" (green) in ADF → Manage → Integration runtimes
- [ ] Run `SELECT COUNT(*) FROM brz.delivery_orders;` — should return **0** (empty, ready)
- [ ] Run `SELECT COUNT(*) FROM erp.delivery_orders;` in Postgres — should return **73**

You're ready.
