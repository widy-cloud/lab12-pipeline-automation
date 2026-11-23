#!/usr/bin/env bash
# Runs once when the codespace / dev container is created (about 3-5 minutes).
set -euo pipefail

AIRFLOW_VERSION="3.4.0"
PYTHON_VERSION="$(python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
CONSTRAINTS="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

echo ">>> 1/3  Airflow ${AIRFLOW_VERSION} (own virtual environment)"
python -m venv ~/.venvs/airflow
~/.venvs/airflow/bin/pip install -q --upgrade pip
~/.venvs/airflow/bin/pip install -q "apache-airflow==${AIRFLOW_VERSION}" duckdb --constraint "${CONSTRAINTS}"

echo ">>> 2/3  dbt + DuckDB adapter (own virtual environment)"
python -m venv ~/.venvs/dbt
~/.venvs/dbt/bin/pip install -q --upgrade pip
~/.venvs/dbt/bin/pip install -q -r requirements-dbt.txt

echo ">>> 3/3  Shortcuts and Airflow metadata database"
mkdir -p ~/.local/bin
ln -sf ~/.venvs/airflow/bin/airflow ~/.local/bin/airflow
ln -sf ~/.venvs/dbt/bin/dbt         ~/.local/bin/dbt
~/.local/bin/airflow db migrate > /dev/null

echo
echo "Setup complete. Open a NEW terminal and run:  make pipeline"
