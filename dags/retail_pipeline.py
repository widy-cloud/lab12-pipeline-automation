"""
Lab 12 - Data Pipeline Automation
=================================
The Practice 10 script, split into tasks and run by Airflow on a schedule.

    check_source_files >> extract_load >> dbt_run >> dbt_test >> report

  E + L : scripts/extract_load.py   (CSV  -> DuckDB raw.*)
  T     : dbt run                   (raw  -> staging.* -> dw.* star schema)
  QC    : dbt test                  (replaces the hand-written qc = {...} checks)
  Report: print the monthly revenue table into the task log
"""
from __future__ import annotations

import os
import sys
from datetime import timedelta
from pathlib import Path

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import dag, task

LAB_HOME = Path(os.environ.get("LAB_HOME", Path(__file__).resolve().parents[1]))
RAW_DIR = LAB_HOME / "data" / "raw"
DBT_DIR = LAB_HOME / "dbt"
DB_PATH = LAB_HOME / "warehouse" / "retail.duckdb"

sys.path.insert(0, str(LAB_HOME / "scripts"))  # so we can import extract_load.py

default_args = {
    "owner": "student",
    "retries": 1,                          # try once more if a task fails
    "retry_delay": timedelta(seconds=20),
}


@dag(
    dag_id="retail_pipeline",
    description="CSV -> DuckDB -> dbt star schema -> tests -> report",
    schedule="@daily",                     # cron: 0 0 * * *
    start_date=pendulum.datetime(2026, 1, 1, tz="Asia/Jakarta"),
    catchup=False,                         # don't run all the missed days since start_date
    default_args=default_args,
    tags=["lab12", "retail"],
)
def retail_pipeline():

    @task
    def check_source_files() -> list[str]:
        """Fail early if the source files are not there."""
        files = sorted(p.name for p in RAW_DIR.glob("*.csv"))
        print(f"Found in {RAW_DIR}: {files}")
        if "customers.csv" not in files or "products.csv" not in files:
            raise FileNotFoundError("customers.csv / products.csv not found")
        if not any(f.startswith("sales_") for f in files):
            raise FileNotFoundError("no sales_*.csv file found")
        return files                       # returned value is stored as an XCom

    @task
    def extract_load(files: list[str]) -> dict[str, int]:
        from extract_load import extract_load as run_extract_load

        print(f"Loading {len(files)} files")
        return run_extract_load(RAW_DIR, DB_PATH)   # row counts -> XCom

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command="dbt run --profiles-dir . --no-use-colors",
        cwd=str(DBT_DIR),
        env={"DUCKDB_PATH": str(DB_PATH)},
        append_env=True,
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command="dbt test --profiles-dir . --no-use-colors",
        cwd=str(DBT_DIR),
        env={"DUCKDB_PATH": str(DB_PATH)},
        append_env=True,
        retries=0,                         # a failed data test will not fix itself
    )

    @task
    def report() -> None:
        import duckdb

        con = duckdb.connect(str(DB_PATH), read_only=True)
        try:
            print(con.sql("""
                SELECT ym, category, SUM(revenue) AS revenue
                FROM dw.mart_monthly_revenue
                GROUP BY ym, category
                ORDER BY ym, revenue DESC
            """))
        finally:
            con.close()

    loaded = extract_load(check_source_files())
    loaded >> dbt_run >> dbt_test >> report()


retail_pipeline()
