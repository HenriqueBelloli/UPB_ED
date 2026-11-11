# =====================================================================
# pa2_env.sh
#
# Prepara o terminal do Ubuntu (WSL) para a PA2: ativa o ambiente
# Python 3.12 e define as variáveis usadas pelo Airflow, pelo dbt e
# pelos scripts de src/.
#
# Uso, a partir da raiz do repositório:
#     source pa2_env.sh
# ("source" é necessário: sem ele, as variáveis somem quando o script
# termina.)
# =====================================================================

# Pasta do repositório: a pasta onde este arquivo está
export NORTHMART_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Banco DuckDB da PA2 (não versionado). Todos os passos usam este.
export NORTHMART_DB="$NORTHMART_REPO/data/northmart_pa2.duckdb"

# Airflow: a configuração, o banco interno (SQLite) e os logs ficam no
# Linux (~/airflow), porque o SQLite não se dá bem com /mnt/c.
# As DAGs ficam no repositório, para irem para o git.
export AIRFLOW_HOME="$HOME/airflow"
export AIRFLOW__CORE__DAGS_FOLDER="$NORTHMART_REPO/airflow/dags"

# Esconde as DAGs de exemplo que vêm com o Airflow
export AIRFLOW__CORE__LOAD_EXAMPLES=False

# Procura DAGs novas a cada 30 segundos (o padrão é 5 minutos)
export AIRFLOW__DAG_PROCESSOR__REFRESH_INTERVAL=30

# Ativa o ambiente Python 3.12 criado com o uv e entra no repositório
source "$HOME/venvs/northmart/bin/activate"
cd "$NORTHMART_REPO"

echo "Ambiente da PA2 pronto: $(python --version), banco em $NORTHMART_DB"
