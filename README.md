# Lab 12 — Data Pipeline Automation

In **Practice 10** you wrote one Python script that did everything:
read the CSVs, clean them with pandas, build a star schema in DuckDB,
run quality checks and print a report. It worked, but **you** had to run it,
and when something went wrong you had to read the whole script to find out where.

In this lab you rebuild the *same* pipeline the way data teams do it in industry:

| Job | Practice 10 | Lab 12 | Tool |
|---|---|---|---|
| Extract + Load | `pd.read_csv` + `con.register` | `scripts/extract_load.py` → `raw.*` tables | Python + DuckDB |
| Transform (clean) | pandas `strip`, `title`, `to_numeric`, `drop_duplicates` | `dbt/models/staging/stg_*.sql` | **dbt** |
| Build star schema | SQL strings inside `con.execute(...)` | `dbt/models/marts/dim_*.sql`, `fact_sales.sql` | **dbt** |
| Quality checks | `qc = {...}` dictionary | `schema.yml` tests: `unique`, `not_null`, `relationships` | **dbt test** |
| Run it | you type `python etl.py` | runs every day by itself, retries, logs | **Airflow** |
| Same environment for everyone | "works on my laptop" | dev container built from a Dockerfile image | **Docker / Codespaces** |

```
 data/raw/*.csv
      │  ① check_source_files   (Airflow task)
      │  ② extract_load         (Python → DuckDB raw.*)
      ▼
 warehouse/retail.duckdb
   raw.*  ──③ dbt run──►  staging.* (views)  ──►  dw.* (star schema + mart)
      │  ④ dbt test             (data quality)
      │  ⑤ report               (monthly revenue in the log)
      ▼
 Airflow UI: schedule, status, logs, retries
```

---

## Part A — Start your environment (10 min)

**Option 1: GitHub Codespaces (recommended)**

1. Log in to GitHub with **your personal account**.
   Students: verify at <https://education.github.com> to get 180 free core-hours/month.
2. On this repository click **Use this template → Create a new repository** (in your own account).
3. In your new repository: **Code → Codespaces → Create codespace on main**.
4. Wait until the terminal prints `Setup complete` (first time: about 3–5 minutes).
5. Open a **new terminal** (`+` in the terminal panel) and type `make help`.

**Option 2: your own laptop** — install Docker Desktop and VS Code with the
*Dev Containers* extension, open this folder and choose **Reopen in Container**.
Everything else is the same. Needs about 8 GB RAM.

> ⚠️ When you finish, **stop** your codespace (Codespaces menu → *Stop Current Codespace*).
> A running codespace uses your free hours even when you are not typing.

---

## Part B — Run the pipeline by hand (20 min)

Run each step yourself first, so you know what Airflow will automate.

```bash
make el          # ① Extract + Load: CSV -> raw.customers, raw.products, raw.sales
make tables      # what is in the warehouse now?
make transform   # ② dbt run: raw -> staging -> dw
make tables      # look again: staging.* and dw.* appeared
make test        # ③ dbt test: 18 checks
```

Questions:

1. Open `dbt/models/staging/stg_sales.sql`. Find the SQL line that does the same
   job as each pandas line from Practice 10 (`to_datetime`, `fillna(0)`,
   `drop_duplicates`, negative quantity).
2. `raw.sales` has 244 rows but `dw.fact_sales` has 241. Where did 3 rows go?
   Use `make sql Q="SELECT ..."` to prove it, for example
   `make sql Q="SELECT count(*) FROM staging.stg_sales"`.
3. `make test` shows **1 warning**. Which test? Why is it a *warning* and not an *error*?
   (Look at `dbt/models/staging/schema.yml`.)
4. Open `dbt/models/marts/fact_sales.sql`. It never says *which* table to build first.
   How does dbt know that `stg_sales` must exist before `fact_sales`?

Optional: `make docs` and open port **8081** to see the lineage graph.

---

## Part C — Let Airflow run it (30 min)

```bash
make airflow     # starts Airflow. Keep this terminal open. Stop with Ctrl+C.
```

Open the **Ports** tab → port **8080** → click the 🌐 globe icon.
(No password is needed in this lab environment.)

1. Find the DAG **`retail_pipeline`**. It is **paused** — switch the toggle on.
2. Click ▶ **Trigger** to run it now. Open the **Graph** view and watch the 5 tasks
   turn green: `check_source_files → extract_load → dbt_run → dbt_test → report`.
3. Click the **report** task → **Logs**: the monthly revenue table is there.
4. Click **extract_load** → **XCom**: the row counts it returned.
5. Read `dags/retail_pipeline.py`. Find: the schedule, the retries, and the line that
   sets the order of the tasks (`>>`).

No browser? `make run-dag` runs the whole DAG once in the terminal.

---

## Part D — Automation in action (20 min)

**Scenario 1 — new data arrives.** In a *second* terminal:

```bash
make new-day     # sales_2024_07.csv lands in data/raw/
```

Trigger the DAG again. July 2024 now appears in the report.
You changed **no code** — the pipeline picked up the new file by itself.

**Scenario 2 — bad data arrives.**

```bash
make break       # a file with customer_id = 999 (does not exist)
```

Trigger the DAG. Which task turns red? Open its log and find the failing test.
Which task did **not** run, and why is that a good thing?

```bash
make fix         # remove the bad file, then trigger again -> all green
```

Discussion: when `dbt_test` failed, had `dbt_run` *already* written the bad row into
`dw.fact_sales`? How could you stop bad data **before** it reaches the warehouse?
(Hint: look up `dbt build`.)

---

## Part E — Exercises (homework)

Take the analytic queries from your Practice 10 assignment and make them part
of the automated pipeline:

1. **`dbt/models/marts/mart_sales_region_month.sql`** — sales per region per month
   (join `dim_customer`).
2. **`mart_top5_products_per_category.sql`** — use a window function
   (`ROW_NUMBER()` or `QUALIFY`).
3. **`mart_revenue_growth.sql`** — month-over-month growth with `LAG()`.
4. **`mart_top_customers.sql`** — customers with the highest total spending.
5. Add **one new test** to `dbt/models/marts/schema.yml`, for example
   `accepted_values` on `dim_product.category`.
6. Add **one new task** to the DAG, for example a task after `report` that writes
   `mart_monthly_revenue` to `data/export/monthly_revenue.csv`.

Run `make transform test`, then trigger the DAG. Submit the link to your repository.

---

## Folder map

```
.devcontainer/      environment recipe (image, tools, ports)  ← Docker
data/raw/           source files the pipeline reads
data/incoming/      a "tomorrow" file for Scenario 1
data/bad/           a broken file for Scenario 2
scripts/            extract_load.py (E+L), query.py (look inside the warehouse)
dbt/                models/staging, models/marts, tests  ← T + quality
dags/               retail_pipeline.py  ← Airflow
warehouse/          retail.duckdb (created when you run the pipeline)
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `airflow: command not found` | Setup still running, or open a **new** terminal |
| `Could not set lock on file ... retail.duckdb` | Another program has the database open for writing. Close it; use `make sql` (read-only) to look |
| DAG not in the UI | Wait 10 seconds; check for Python errors: `airflow dags list-import-errors` |
| Port 8080 shows nothing | Is `make airflow` still running? Look for errors in that terminal |
| Start again from zero | `make reset` |

Versions: Python 3.12 · Apache Airflow 3.4.0 · dbt Core 1.12 + dbt-duckdb · DuckDB 2.0
