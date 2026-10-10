# NorthRoute Demo – Rehearsal Script

Rehearsal notes for the demo section of *Accidental Data Engineer*. Last updated 2026-10-10. The editable copy is the Claude Doc; this file mirrors it.

## Running order

The demo runs 22–25 minutes in seven acts, picking up straight after the "It's demo time!" slide and handing back to Key Takeaways. Each act lists what you **do** on screen, what you might **say** (the gist, not lines to learn), and where to **ask** the audience something.

| Act | Minutes | Screen | The point it lands |
| --- | --- | --- | --- |
| 1. Meet NorthRoute + the source | 5–6 | pgAdmin | The data is messy, and plugging Power BI straight in would report £27k too much revenue |
| 2. The warehouse + control table | 2–3 | SSMS | Empty Bronze/Silver/Gold, plus a table that tells the pipeline what to move |
| 3. ADF building blocks | 3–4 | ADF Studio – Manage, Author | Slide 15 made real: IR, linked services, datasets |
| 4. Pipeline 1 – Lookup | 2–3 | ADF – pipeline 1 | The pipeline reads its instructions from a table |
| 5. Pipeline 2 – ForEach + Copy | 3–4 | ADF – pipeline 2, then SSMS | One Copy activity loads all three tables; Bronze = the mess, faithfully |
| 6. Pipeline Final – Silver + Gold | 4–5 | ADF – Final, then SSMS | Pure T-SQL turns the mess into trusted numbers |
| 7. Scaling out + wrap | 1–2 | ADF / SSMS control table | More tables = one row; more sources = the same pattern |

Rehearse with a timer. If you run long, cut 1e (tonnage) in Act 1 and 4e (product mix) in Act 6 first.

## Pre-flight checklist

Run through this 30–60 minutes before you go on. Most demo failures are one of these.

**Infrastructure**

- [ ] WorkSpace is on and logged in. The self-hosted IR runs on it, so ADF can't reach Postgres without it.
- [ ] Postgres service `postgresql-x64-15` is Running (`Get-Service postgresql*`).
- [ ] ADF → Manage → Integration runtimes: `AWSWorkspace` shows **Running**, with this machine's node online.
- [ ] Azure SQL `northroute-demo` is online. An automation has been pausing and resuming it, so check it isn't scheduled to pause during your slot.
- [ ] SSMS connects. The WorkSpace can change public IP; a new IP needs a SQL firewall rule.

**Clean state**

- [ ] Run `.\scripts\reset-demo.ps1` so Bronze, Silver and Gold are empty and `pipeline_log` is empty.
- [ ] `dbo.pipeline_control` still has 3 rows, all `is_active = 1`. The reset doesn't touch it, but check if you edited it while rehearsing.

**Screens and tabs (in order of use)**

- [ ] pgAdmin: NorthRoute ERP connected, Query Tool open on `northroute_erp` with `DataExploreScripts\Source.sql` loaded.
- [ ] SSMS: connected and **set to `northroute-demo`, not `master`**. Tabs: `Bronze.sql`, `Silver.sql`, `Gold.sql`, plus a scratch tab with the control table and pipeline log queries.
- [ ] Browser: ADF Studio on **`adf-northroute-47xop2-live`**, logged in, Author hub open. A second tab on the Monitor hub.
- [ ] Font sizes up in pgAdmin, SSMS (Ctrl + scroll) and browser zoom (125–150%). Check from the back of a room if you can.
- [ ] Notifications off (Teams, Outlook, Windows).

## Act 1 – Meet NorthRoute and the source system (5–6 min)

The goal: by the end of this act, the audience agrees that pointing Power BI straight at this database would be a mistake.

**Set the scene (slides → pgAdmin)**

- **Say:** "I can't show you the real client, so meet NorthRoute Logistics: a made-up UK haulage firm. Five depots: Manchester, Leeds, Birmingham, Bristol, Edinburgh. Eight business customers. They move aggregates, timber, steel, chemicals and food-grade goods."
- **Say:** "The real client runs SAP. Here, a PostgreSQL database plays the part of their on-premises ERP. Three months of data, January to March 2024."
- **Do:** in pgAdmin, expand `northroute_erp → Schemas → erp → Tables`. Point at the three tables: `warehouses` (5 rows), `customers` (8), `delivery_orders` (73). "Two reference tables, and one table where everything actually happens."

**Walk through Source.sql (highlight each block, F5)**

| Query | What appears | Ask / say |
| --- | --- | --- |
| 1a. All orders | 73 rows, tidy-looking | **Ask:** "Looks fine, right? Anyone want to build a report on this?" |
| 1b. Status counts | 5 values: DELIVERED 66, CANCELLED 3, Delivered 2, IN TRANSIT 1, delivered 1 | **Ask:** "How many statuses should there be?" Three spellings of delivered. Nobody decided this; it just happened. |
| 1c. Duplicate doc_entry | DOC-1003, DOC-1034, DOC-1057, each twice | "Three documents submitted twice. A system glitch." |
| 1d. DOC-1003 side by side | order_id 3 and 11, identical except the note "DUPLICATE – re-submitted in error" | **Ask:** "Spot the difference." Same date, same 31 tonnes, same driver. |
| 1e. Tonnage problems | DOC-1021 and DOC-1042 NULL; DOC-1028 −4 t; DOC-1055 −2.5 t | **Ask:** "What do we do with minus four tonnes? Delete it? Guess? Keep it and flag it?" Hold the answer for Silver. |
| 1f. DQ scorecard | 73 rows, 70 unique docs, 3 duplicates, 3 cancelled, 2 negative, 2 NULL, 3 mixed-case | "That's the job the pipeline has to do." |

One accuracy note for 1e: the notes say DOC-1028 was a return journey logged by the weigh bridge, and DOC-1055 was a data entry error. The comment in `Source.sql` calls both weigh-bridge errors.

**Why not just plug Power BI in? (the three reasons)**

1. **The numbers would be wrong.** Summing this table as it stands gives £200,834 revenue and 1,565 tonnes. The trusted figure (what Gold produces) is **£173,778 and 1,362 tonnes: £27k (16%) too much**. Duplicates alone add £15,975 and 112.5 t; cancelled orders add 81 t.
    - **The gotcha (good interactive moment):** **Ask:** "OK, so filter on status = DELIVERED. Problem solved?" It returns **66 rows, exactly the number Gold will give us later**. But it's the wrong 66: three are duplicates, and the three lower-case "Delivered" rows are missing. "The count matches, and it's still wrong."
    - **Say:** "You could fix all this in Power Query. Then the next report fixes it slightly differently, and Finance's number stops matching Operations' again." (Callback to slide 5.) The business rules belong in one place: Silver.
2. **The context lives elsewhere.** This ERP knows about deliveries. It knows nothing about costs, invoices, or what Finance tracks. "The real questions, like whether a depot is actually profitable, need data from more than one system, and you can't join across systems inside the ERP. A warehouse is where they meet." (Today we bring in one source; Act 7 shows how the pattern grows.)
3. **It's a transactional system.** "This database is built for lots of small writes: drivers and planners booking deliveries all day. Reporting does the opposite: scans and aggregates whole tables. Point Power BI at it at 9am and your reports compete with the people taking orders." For a DBA audience: "You wouldn't point a reporting workload at your busiest OLTP server in business hours." In the real client's case it's also an on-premises SAP system behind a firewall, and handing report builders production ERP credentials is its own conversation.

**Transition:** "So we need somewhere else for the data to live. Let's look at where it's going."

## Act 2 – The warehouse and the control table (2–3 min)

The goal: show an empty, ready-made destination and introduce the control table as "the brain" from slide 16.

**The empty warehouse (SSMS, `northroute-demo`)**

- **Do:** in Object Explorer, expand Tables. Point out the three schemas in order: `brz` (3 tables), `slv` (3), `gld` (4: `dim_date`, `dim_warehouse`, `dim_customer`, `fact_delivery`).
- **Say:** "Bronze, Silver, Gold, the layers from earlier, are just schemas in one Azure SQL database. Nothing exotic. If you can create a schema, you can build a medallion architecture."
- **Do:** optionally run `CountAll.sql`: every count is 0. "Empty. Nothing's been loaded yet."
- **Do:** expand Programmability → Stored Procedures: `usp_brz_to_slv`, `usp_slv_to_gld`. "Hold that thought. These do the transformation later."

**The control table**

- **Do:** `SELECT * FROM dbo.pipeline_control;`

| source_schema | source_table | sink_schema | sink_table | is_active | load_order |
| --- | --- | --- | --- | --- | --- |
| erp | warehouses | brz | warehouses | 1 | 1 |
| erp | customers | brz | customers | 1 | 2 |
| erp | delivery_orders | brz | delivery_orders | 1 | 3 |

- **Say:** "This is the brain of the pipeline. Each row is one table to move: where it comes from, where it lands. The pipeline doesn't know any table names. It reads them from here."
- **Ask:** "If I wanted to stop loading customers tonight, what would I change?" Answer: set `is_active = 0`. No pipeline change, no redeploy.
- **Say:** "There's also `pipeline_log`. Every transformation step writes a row there, so there's an audit trail. We'll come back to it at the end."

**Transition:** "So we have a source and a destination. Now, what moves the data between them?"

## Act 3 – ADF building blocks (3–4 min)

The goal: make slide 15 real. Go bottom-up, infrastructure first, because the pipelines only make sense once people know what they plug into. Keep the DBA analogies from the slide.

**Say (opening):** "Two factories here. The `-live` one is what we'll use. The other is a complete backup copy I never touch on demo day."

**1. Integration runtime – Manage → Integration runtimes**

- Two entries: `AutoResolveIntegrationRuntime` (Azure-hosted, always there) and `AWSWorkspace` (self-hosted).
- **Say:** "Azure can't see inside a company network. The self-hosted integration runtime is a small agent installed on a machine *inside* that network, next to the database. It connects outbound to Azure, so you don't open firewall holes inbound. At the client, that machine sits next to SAP. Here, it's on the same box as Postgres."
- Analogy: the server your SSIS packages run on.

**2. Linked services – Manage → Linked services**

| Linked service | Type | Worth pointing out |
| --- | --- | --- |
| `ls_keyvault_northroute` | Azure Key Vault | Holds the passwords. No password is typed into ADF. |
| `ls_azuresql_northroute` | Azure SQL Database | SQL login; the password comes from Key Vault secret `sqlserver-admin-password` |
| `PostgreSql1` | PostgreSQL (V2) | Host is `localhost`: localhost *from the integration runtime's point of view*. Runs via `AWSWorkspace`. Password from Key Vault. |

- **Say:** "A linked service is just a connection: server, database, credentials. Think of the connection dialog in SSMS, or a linked server."
- Optional: click **Test connection** on `PostgreSql1` for a green tick. It proves the whole chain works before you run anything.

**3. Datasets – Author → Datasets**

- `ds_postgres_source` and `ds_azuresql_sink`. Open one: **Parameters** tab shows `schema_name` and `table_name`; **Connection** tab shows the table as `@dataset().schema_name` / `@dataset().table_name`.
- **Say:** "A dataset points at a table. But notice there's no table name here, just parameters. So it's two datasets for three tables, and still two datasets for three hundred."
- Analogy: a table or view in a query.

**4. Pipelines, activities, triggers – Author**

- Pipelines `1`, `2` and `Final`. Open the activity toolbox on the left: Copy data, Lookup, ForEach, Stored procedure, and many more. "A pipeline is the container; activities are the steps. Think SSIS package."
- **Say (triggers):** "There are no triggers set up, because today I'm the trigger. In production, a schedule trigger runs this overnight, so the numbers are there before anyone starts work. That's your SQL Agent job schedule."

**Transition:** "Right, let's build this up one pipeline at a time."

## Act 4 – Pipeline 1: the Lookup (2–3 min)

The goal: show that the pipeline starts by asking the control table what to do.

**Walk through it**

- **Do:** open pipeline `1`. One activity: `Lookup_ControlTable`. Click it, then the **Settings** tab.
- Point out three things:
    - Dataset: `ds_azuresql_sink`, with `schema_name = dbo` and `table_name = pipeline_control`. "Same parameterised dataset, pointed at the control table."
    - The query: `SELECT source_schema, source_table, sink_schema, sink_table FROM dbo.pipeline_control WHERE is_active = 1 ORDER BY load_order`. "Plain SQL. Only active rows."
    - **First row only** is unticked. "We want every row back, not just the first."

**Run it**

- **Do:** click **Debug**. The Output pane under the canvas shows the run; it takes a few seconds.
- **Do:** hover the activity row and click the **Input** icon: the dataset and the query. Then the **Output** icon.
- What you'll see: `"count": 3` and a `value` array of three objects, e.g. `{ "source_schema": "erp", "source_table": "warehouses", "sink_schema": "brz", "sink_table": "warehouses" }`.
- **Say:** "That's the control table, as JSON. This is the to-do list the rest of the pipeline will work through."
- Worth a mention if it shows in the output: `effectiveIntegrationRuntime` should be the Azure (AutoResolve) runtime, because this step only talks to Azure SQL. Check this in rehearsal before saying it.

**Optional interactive beat (+1 min)**

- **Ask:** "Watch what happens if I switch customers off." Run `UPDATE dbo.pipeline_control SET is_active = 0 WHERE source_table = 'customers';` in SSMS, Debug again: `"count": 2`.
- **Then set it back** (`SET is_active = 1`) before moving on, or pipeline 2 will skip customers and the Silver/Gold numbers change.

**Transition:** "A to-do list is great. Now let's actually do something with it."

## Act 5 – Pipeline 2: ForEach + Copy into Bronze (3–4 min)

The goal: one Copy activity, driven by the to-do list, loads all three tables. Bronze shows the mess arrived intact.

**Walk through it**

- **Do:** open pipeline `2`. Same Lookup, now with a green **on success** arrow into `ForEach1`. "Pipeline 1, plus one step."
- **Do:** click `ForEach1` → **Settings**. Items = `@activity('Lookup_ControlTable').output.value`. "Loop over whatever the Lookup returned."
- **Do:** open the ForEach (pencil icon). Inside is one activity, `Copy data1`.
    - **Source** tab: dataset `ds_postgres_source`, parameters `@item().source_schema` and `@item().source_table`.
    - **Sink** tab: dataset `ds_azuresql_sink`, parameters `@item().sink_schema` and `@item().sink_table`.
    - **Say:** "`@item()` is the current row of the control table. First time round it's warehouses, then customers, then delivery orders. One Copy activity, three tables."
    - **Sink → Pre-copy script:** `TRUNCATE TABLE [@{item().sink_schema}].[@{item().sink_table}]`. "Empty the Bronze table first, then load. Run it twice and you don't get double the rows."

**Run it**

- **Do:** back on the main canvas, **Debug**. The Output pane shows the Lookup, then three `Copy data1` runs.
- **Say while it runs:** "The Lookup runs in Azure. The copies run on the self-hosted runtime next to Postgres, which reads the rows and pushes them up to Azure SQL."
- **Do:** click the **Details** (glasses) icon on a copy run: rows read and written. Expect **warehouses 5, customers 8, delivery_orders 73**. The Output JSON shows `rowsRead` / `rowsCopied` and the integration runtime used (should be `AWSWorkspace`; check in rehearsal).
- Note: the three copies start at the same time because the ForEach isn't set to **Sequential**. Fine for Bronze, which has no dependencies between tables.

**Show Bronze (SSMS, `Bronze.sql`)**

| Query | Result | Say |
| --- | --- | --- |
| 2a. Row count | 73 | "73 in Postgres, 73 in Bronze. Exact match." |
| 2b. DOC-1003 | Still two rows, with a `_loaded_at` timestamp | "The duplicate is still here. Good. Bronze doesn't fix anything." |
| 2c. Negative tonnage | DOC-1028 −4.000, DOC-1055 −2.500 | "Still wrong. On purpose." |

- **Say:** "Bronze is the truth as it arrived. If my cleaning logic has a bug next month, I fix it and reprocess from here, without going back to the source system."

**Transition:** "So we've moved the data. Now let's make it trustworthy."

## Act 6 – Pipeline Final: Silver and Gold (4–5 min)

The goal: the payoff. Two stored procedures, pure T-SQL, turn 73 messy rows into a trusted star schema, and every Act 1 problem gets its answer.

**Walk through it**

- **Do:** open `Final`. Lookup → ForEach (copy activity now named `Copy source to bronze`) → `Stored procedure1` → `Stored procedure2`, joined by green on-success arrows.
- **Do:** click `Stored procedure1` → **Settings**: linked service `ls_azuresql_northroute`, procedure `[dbo].[usp_brz_to_slv]`. `Stored procedure2` runs `[dbo].[usp_slv_to_gld]`.
- **Say:** "ADF isn't doing the transformation. It just tells Azure SQL to run a stored procedure. The logic is T-SQL my team already knows how to write, test and tune. That was the decision on slide 12."
- **Optional (+1 min):** in SSMS, script out `usp_brz_to_slv` and scroll: `ROW_NUMBER() OVER (PARTITION BY doc_entry ORDER BY order_id)` for duplicates, delete `CANCELLED`, `UPPER(status)`, `CASE` to floor NULL and negative tonnage, revenue = tonnes × price, DQ flags, then a row in `pipeline_log`. "No Spark. No Python. A CTE and some CASE statements."

**Run it:** **Debug**. Talk over it while the copies and both procs go green.

**Silver (SSMS, `Silver.sql`): the truth, made trustworthy**

| Query | Result | Say |
| --- | --- | --- |
| 3a. Bronze vs Silver | 73 in, 67 out: 3 duplicates and 3 cancellations removed | "Six rows gone, and we can say exactly why." |
| 3b. DOC-1003 | One row, 31 t, £4,402, `dq_was_duplicate = 1` | "Removed, but remembered. If someone asks next year whether January had duplicates: yes, three." |
| 3c. Tonnage flags | DOC-1021, DOC-1042 (were NULL), DOC-1028, DOC-1055 (were negative): all 0 t, £0, flagged | Answer the Act 1 question: "We didn't delete them and we didn't guess. Zero, and a flag saying why." |
| 3d. Status | DELIVERED 66, IN TRANSIT 1 | "Three spellings became one." (Not "one status value": the in-transit order is still here.) |
| 3e. Top revenue | DOC-1034 £6,390, DOC-1067 £6,106, DOC-1017 £5,964, DOC-1050 £5,680, DOC-1022 £5,467 | "Revenue didn't exist in the source. It's our first business metric, and it came from a multiplication." |

**Gold (SSMS, `Gold.sql`): the truth, ready to consume**

- **Say first:** "Silver had 67 rows; Gold has 66. The difference is DOC-1016, still in transit, so not a delivery yet. Remember the 66 from the naive filter in Act 1? Same count, but this time it's the right 66."

| Query | Result | Say |
| --- | --- | --- |
| 4a. DOC-1003 end to end | Friday 5 Jan 2024, Birmingham Hub (Midlands), Clearwater Retail PLC, Steel, 31 t, £4,402, duplicate flag still set | "Date, depot, customer, all joined. One clean row." |
| 4b. Monthly revenue | Jan £55,405 (23 deliveries), Feb £59,020 (22), Mar £59,354 (21) | "The director's view. Automated. Not a pivot table." Total £173,778: **"Remember £200,834? That's the £27k we didn't overstate."** |
| 4c. Revenue by depot | Birmingham Hub £67,417 = 38.8%, then Leeds 17.6%, Edinburgh 17.4%, Manchester 15.7%, Bristol 10.5% | "SUM() OVER(): one window function. That insight was buried in 73 messy rows 20 minutes ago." |
| 4d. Top customers | Clearwater Retail £45,350, Easton Food Group £30,275, Hartley Waste £23,681 | **Ask:** "If you ran NorthRoute, who would you be worried about losing?" Clearwater is 26% of revenue. |
| 4e. Product mix by month | Category × month | Cut this first if you're short of time. "This is what you'd drag into a Power BI chart." |

**The audit trail (scratch tab):** `SELECT stage, status, rows_processed, message FROM dbo.pipeline_log ORDER BY log_id;`

- SILVER: "Bronze rows in: 73 | Dupes removed: 3 | Cancelled removed: 3 | NULL tonnage floored: 2 | Negative tonnage floored: 2 | Silver rows out: 67"
- GOLD: "fact_delivery rows: 66 | dim_date: 366 | dim_warehouse: 5 | dim_customer: 8"
- **Say:** "Every run writes down what it did. When someone asks why the number changed, you have an answer."

## Act 7 – Scaling out, and the wrap (1–2 min)

The goal: show that the demo used one source, but nothing about the pattern stops there. Keep it honest about what's free and what still takes work.

**Another table from the same ERP: one row**

- **Do:** back in SSMS on the control table. **Say:** "Say NorthRoute want their vehicles table too. I create a Bronze table for it, add one row here, and the pipeline picks it up tonight. I don't open ADF."
- Be precise if asked: the Bronze table has to exist first, because the Copy's pre-copy `TRUNCATE` needs it. Any Silver/Gold logic for the new table is still SQL you write, and that's deliberate: it's version-controlled and tested.

**Another source system: same pattern, new connection**

- **Say:** "Now Finance want their numbers in: costs, invoices, from a different system. That's a new linked service and one parameterised dataset for that kind of source. Then either a second Lookup and ForEach, or a `source_system` column in the control table and a Switch activity to route it. Everything after that is the same Bronze, Silver, Gold."
- Close the loop with Act 1, reason 2: "And that's where it gets interesting. Delivery revenue from the ERP plus costs from Finance, joined in Gold, gives you profit per depot. Nobody could answer that before, because the data lived in two places."

**Optional interactive beat: what's still wrong?**

- **Ask:** "Anyone spot something the pipeline *didn't* catch?" The answer: Greystone Properties is marked **INACTIVE**, with no contact name, and still has 3 delivered orders (£3,509 in Gold).
- **Say:** "Is that a data problem, or a business process problem? You don't know until you ask the business. That's the bit no tool does for you." (Sets up takeaway 2: the tech isn't the whole picture.)

**Bridge to Key Takeaways**

- **Say:** "So: a messy source, a control table, two parameterised datasets, one Copy activity and two stored procedures. Nothing on screen today needed a skill a DBA doesn't already have." → Key Takeaways slide.

## If it goes wrong, likely questions, and things to fix first

**Fallbacks**

| Symptom | Fix on stage |
| --- | --- |
| Copy fails, can't reach Postgres | Check Manage → Integration runtimes. The **backup factory shares the same runtime**, so it is not a fallback for this. Switch to backup screenshots (see the last row). |
| SQL says "database not currently available" | It was paused. Wait about a minute and retry; it resumes on connect. |
| SSMS: "Client with IP address … is not allowed" | The WorkSpace changed IP. Portal → SQL server → Networking → Add your client IP. |
| Permission errors on brz tables | You're in `master`. Switch the database dropdown to `northroute-demo`. |
| A run is slow | Talk over it: explain the self-hosted runtime. Time each Debug run in rehearsal so you know what normal looks like. |
| Anything else | In your final rehearsal, screenshot each Debug output and query result into hidden backup slides. |

**Likely audience questions**

- **"Is Bronze really append-only?"** Not in this build. Each run truncates and reloads, so Bronze is a full snapshot of the source. The next step is incremental loading with a watermark (the source has a `created_at` column) and appending.
- **"How does ADF log into Azure SQL?"** A SQL login whose password lives in Key Vault. ADF reads Key Vault using the factory's managed identity.
- **"What happens when a step fails?"** Both procedures use TRY/CATCH: they write a FAILED row to `pipeline_log` with the error, then re-throw so ADF marks the activity red. Later steps don't run, because the arrows are on-success only. Retries are currently 0.
- **"Does load_order matter?"** It sorts the Lookup results. The ForEach runs the copies in parallel unless you tick Sequential.
- **"Why not Fabric or Databricks?"** Slides 9 and 12: a team already skilled in T-SQL, small-to-medium data, deep Azure integration. "Tools, not rules."

**Slides and build that don't match: decide before rehearsing**

| Where | Says | Reality | Suggested fix |
| --- | --- | --- | --- |
| Slide 11 | Bronze is "append-only" | Pre-copy `TRUNCATE` and full reload | Reword to "exact copy of source", or be ready for the question |
| Slide 14 | "Managed identity to Azure SQL" | SQL login, password from Key Vault | "Key Vault for secrets" (managed identity is used to read Key Vault) |
| `Silver.sql` 3d comment | "One status value. DELIVERED" | DELIVERED 66 + IN TRANSIT 1 | Fix the comment |
| `Source.sql` 1e comment | Both negatives are weigh-bridge errors | DOC-1055 is a data entry error | Fix the comment |
| ADF live | Postgres linked service called `PostgreSql1` | Default name on screen | Rename (the dataset reference updates too), or leave it |
| `pipeline_log` | Has a `run_id` column | Always NULL: the pipeline doesn't pass `@pipeline().RunId` to the procs | Add the parameter to both stored procedure activities |
