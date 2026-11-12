"""
task_durations.py

Duração das tarefas da DAG northmart_daily, lida do banco interno do
Airflow (SQLite em $AIRFLOW_HOME/airflow.db). Serve para a Tarefa 6 da
PA2: descobrir qual tarefa é a mais lenta.

Para cada tarefa, mostra a média, o mínimo e o máximo da duração (em
segundos) nas execuções que terminaram com sucesso, e grava os números
em evidence/task_durations.csv.

Uso (a partir da raiz do repositório, com source pa2_env.sh):
    python src/task_durations.py
"""

import csv
import os
import sqlite3
from pathlib import Path

AIRFLOW_DB = Path(os.environ.get("AIRFLOW_HOME", Path.home() / "airflow")) / "airflow.db"
RESULTS_FILE = "evidence/task_durations.csv"

# 1. Abre o banco do Airflow só para leitura
con = sqlite3.connect(f"file:{AIRFLOW_DB}?mode=ro", uri=True)

# 2. Duração por tarefa, só das execuções com sucesso (as que falharam
#    ou não rodaram não dizem quanto a tarefa demora)
linhas = con.execute("""
    SELECT task_id,
           count(*)                AS execucoes,
           round(avg(duration), 2) AS media_s,
           round(min(duration), 2) AS min_s,
           round(max(duration), 2) AS max_s
    FROM task_instance
    WHERE dag_id = 'northmart_daily'
      AND state = 'success'
    GROUP BY task_id
    ORDER BY media_s DESC
""").fetchall()
con.close()

# 3. Mostra a tabela, da tarefa mais lenta para a mais rápida
print(f"{'tarefa':<14}{'execuções':>11}{'média (s)':>11}{'mín (s)':>9}{'máx (s)':>9}")
for task_id, execucoes, media, minimo, maximo in linhas:
    print(f"{task_id:<14}{execucoes:>11}{media:>11}{minimo:>9}{maximo:>9}")

# 4. Grava em CSV
with open(RESULTS_FILE, "w", newline="", encoding="utf-8") as f:
    escritor = csv.writer(f)
    escritor.writerow(["tarefa", "execucoes", "media_s", "min_s", "max_s"])
    escritor.writerows(linhas)
print(f"\nGravado em {RESULTS_FILE}")
