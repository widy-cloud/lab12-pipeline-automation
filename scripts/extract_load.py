"""
Step 1 of the pipeline: EXTRACT + LOAD (the "E" and "L" in ELT).

Reads every CSV in data/raw/ and copies it *as-is* (all columns as text)
into the `raw` schema of the DuckDB warehouse. No cleaning happens here:
cleaning is the job of dbt (the "T").

Run it by hand:      python scripts/extract_load.py
Airflow calls the same function from dags/retail_pipeline.py
"""
from __future__ import annotations

import glob
import os
from datetime import datetime
from pathlib import Path

import duckdb

LAB_HOME = Path(os.environ.get("LAB_HOME", Path(__file__).resolve().parents[1]))
RAW_DIR = LAB_HOME / "data" / "raw"
DB_PATH = Path(os.environ.get("DUCKDB_PATH", LAB_HOME / "warehouse" / "retail.duckdb"))


def log(msg: str) -> None:
    print(f"[{datetime.now().isoformat(timespec='seconds')}] {msg}", flush=True)


def extract_load(raw_dir: Path = RAW_DIR, db_path: Path = DB_PATH) -> dict[str, int]:
    """Load customers.csv, products.csv and all sales_*.csv into raw.* tables.
    Returns the number of rows loaded per table."""
    required = ["customers.csv", "products.csv"]
    missing = [f for f in required if not (raw_dir / f).exists()]
    sales_files = sorted(glob.glob(str(raw_dir / "sales_*.csv")))
    if missing or not sales_files:
        raise FileNotFoundError(f"Missing source files in {raw_dir}: {missing or 'sales_*.csv'}")

    db_path.parent.mkdir(parents=True, exist_ok=True)
    log(f"Load: writing raw tables into {db_path}")
    con = duckdb.connect(str(db_path))
    try:
        con.execute("CREATE SCHEMA IF NOT EXISTS raw")
        sources = {
            "customers": str(raw_dir / "customers.csv"),
            "products": str(raw_dir / "products.csv"),
            "sales": str(raw_dir / "sales_*.csv"),  # glob: every daily/monthly file
        }
        counts = {}
        for table, path in sources.items():
            # all_varchar=true -> keep the data exactly as the source sent it
            con.execute(f"""
                CREATE OR REPLACE TABLE raw.{table} AS
                SELECT *,
                       filename          AS _source_file,
                       current_timestamp AS _loaded_at
                FROM read_csv('{path}', header = true, all_varchar = true, filename = true)
            """)
            counts[table] = con.execute(f"SELECT count(*) FROM raw.{table}").fetchone()[0]
            log(f"  raw.{table:<9} {counts[table]:>5} rows")
        return counts
    finally:
        con.close()


if __name__ == "__main__":
    extract_load()
    log("Done.")
