"""
Look inside the warehouse.

  make tables                                   -> list all tables
  make sql Q="SELECT * FROM dw.fact_sales LIMIT 5"
"""
import os
import sys
from pathlib import Path

import duckdb

LAB_HOME = Path(os.environ.get("LAB_HOME", Path(__file__).resolve().parents[1]))
DB_PATH = os.environ.get("DUCKDB_PATH", str(LAB_HOME / "warehouse" / "retail.duckdb"))

sql = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1].strip() else """
    SELECT table_schema, table_name, table_type
    FROM information_schema.tables
    ORDER BY 1, 2
"""
# read_only=True: we only look, so we never lock the file for Airflow
con = duckdb.connect(DB_PATH, read_only=True)
con.sql(sql).show(max_rows=50)
con.close()
