"""
northmart_daily.py

DAG da PA2 (Tarefa 4): o pipeline diário da NorthMart.

    extract → load → dbt_staging → dbt_test → dbt_marts

  * extract e load: tarefas Python que chamam src/extract_orders.py e
    src/load_raw_api.py para a data da execução ({{ ds }});
  * dbt_staging: tipa e limpa o lote do dia (modelo stg_api_orders);
  * dbt_test: os testes do dbt. É o "portão": se algum teste falhar, a
    tarefa falha, o dbt_marts não roda e a fact_sales fica como estava;
  * dbt_marts: carrega o lote na fact_sales (incremental, delete+insert,
    então rodar o mesmo dia de novo não duplica linhas).

Agendamento diário, de 2018-05-01 a 2018-05-14 (os dias que a API tem).
Os 14 dias são rodados com o backfill:
    airflow backfill create --dag-id northmart_daily \
        --from-date 2018-05-01 --to-date 2018-05-14
"""

import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import dag, task

# ---------------------------------------------------------------------
# Caminhos, montados a partir deste arquivo (airflow/dags/ no repositório)
# ---------------------------------------------------------------------

REPO = Path(__file__).resolve().parents[2]
SRC_DIR = REPO / "src"
DBT_DIR = REPO / "dbt"

# O dbt instalado no mesmo ambiente Python que roda o Airflow
DBT = Path(sys.executable).parent / "dbt"

# Banco da PA2: o da variável NORTHMART_DB (pa2_env.sh) ou o padrão
NORTHMART_DB = os.environ.get("NORTHMART_DB", str(REPO / "data" / "northmart_pa2.duckdb"))

# Opções comuns aos comandos do dbt. {{ ds }} é a data da execução
# (AAAA-MM-DD), preenchida pelo Airflow; o dbt a recebe como run_date.
DBT_OPCOES = "--vars '{run_date: {{ ds }}}' --profiles-dir ."


@dag(
    dag_id="northmart_daily",
    description="API -> raw -> dbt staging -> testes (portão) -> fact_sales",
    schedule="@daily",
    start_date=datetime(2018, 5, 1),
    end_date=datetime(2018, 5, 14),
    catchup=False,           # os dias passados entram pelo backfill
    max_active_runs=1,       # um dia de cada vez: o DuckDB aceita um escritor
    max_active_tasks=1,
    default_args={
        "owner": "northmart",
        "retries": 1,                         # uma nova tentativa em caso de erro
        "retry_delay": timedelta(seconds=10),
    },
    tags=["pa2", "northmart"],
)
def northmart_daily():

    # 1. Extração: API -> data/raw/<data>/page_NNN.json
    @task
    def extract(data):
        sys.path.insert(0, str(SRC_DIR))
        from extract_orders import extract as extrair
        return extrair(data)

    # 2. Carga: data/raw/<data>/ -> tabela raw_api_orders
    @task
    def load(data):
        sys.path.insert(0, str(SRC_DIR))
        from load_raw_api import load as carregar
        return carregar(data)

    # 3. Staging: tipa e limpa só o lote do dia
    dbt_staging = BashOperator(
        task_id="dbt_staging",
        bash_command=f"cd {DBT_DIR} && {DBT} run --select staging " + DBT_OPCOES,
        env={"NORTHMART_DB": NORTHMART_DB},
        append_env=True,
    )

    # 4. Testes (portão). Sem nova tentativa: rodar de novo os mesmos
    #    dados dá o mesmo resultado.
    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {DBT_DIR} && {DBT} test --select staging " + DBT_OPCOES,
        env={"NORTHMART_DB": NORTHMART_DB},
        append_env=True,
        retries=0,
    )

    # 5. Marts: carrega o lote aprovado na fact_sales
    dbt_marts = BashOperator(
        task_id="dbt_marts",
        bash_command=f"cd {DBT_DIR} && {DBT} run --select marts " + DBT_OPCOES,
        env={"NORTHMART_DB": NORTHMART_DB},
        append_env=True,
    )

    # Ordem das tarefas
    extract("{{ ds }}") >> load("{{ ds }}") >> dbt_staging >> dbt_test >> dbt_marts


northmart_daily()
