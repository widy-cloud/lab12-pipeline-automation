# Shortcuts for Lab 12. Type `make help` to see them all.
export LAB_HOME      ?= $(CURDIR)
export DUCKDB_PATH   ?= $(CURDIR)/warehouse/retail.duckdb
export AIRFLOW_HOME  ?= $(CURDIR)/.airflow
export AIRFLOW__CORE__DAGS_FOLDER ?= $(CURDIR)/dags
export AIRFLOW__CORE__LOAD_EXAMPLES ?= False
export AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_ALL_ADMINS ?= True

# Python from the Airflow environment (it has duckdb installed)
PYTHON ?= $(shell test -x $(HOME)/.venvs/airflow/bin/python && echo $(HOME)/.venvs/airflow/bin/python || echo python3)
DBT = cd dbt && dbt

.PHONY: help el transform test pipeline tables sql airflow run-dag docs new-day break fix reset

help:          ## show this list
	@grep -E '^[a-z-]+:.*##' Makefile | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

# ---- Part B: run each step by hand -------------------------------------
el:            ## Extract + Load: CSV -> DuckDB raw.*
	$(PYTHON) scripts/extract_load.py

transform:     ## Transform: dbt run (raw -> staging -> dw)
	$(DBT) run --profiles-dir .

test:          ## Quality checks: dbt test
	$(DBT) test --profiles-dir .

pipeline: el transform test   ## the whole pipeline, by hand

tables:        ## list the tables in the warehouse
	$(PYTHON) scripts/query.py

sql:           ## run your own query:  make sql Q="SELECT * FROM dw.fact_sales LIMIT 5"
	$(PYTHON) scripts/query.py "$(Q)"

# ---- Part C: let Airflow do it -----------------------------------------
airflow:       ## start Airflow (UI on port 8080). Stop with Ctrl+C
	airflow standalone

run-dag:       ## run the DAG once from the terminal (no UI needed)
	airflow dags test retail_pipeline

docs:          ## dbt documentation + lineage graph (port 8081)
	$(DBT) docs generate --profiles-dir . && $(DBT) docs serve --profiles-dir . --port 8081 --host 0.0.0.0

# ---- Part D: scenarios ---------------------------------------------------
new-day:       ## a new sales file arrives (July 2024)
	cp data/incoming/sales_2024_07.csv data/raw/ && ls data/raw

break:         ## a bad file arrives (unknown customer_id 999)
	cp data/bad/sales_2024_08_orphan.csv data/raw/ && ls data/raw

fix:           ## remove the bad file
	rm -f data/raw/sales_2024_08_orphan.csv && ls data/raw

reset:         ## back to the starting point
	rm -f data/raw/sales_2024_07.csv data/raw/sales_2024_08_orphan.csv
	rm -rf warehouse dbt/target
