"""
check_idempotency.py

Mostra as contagens da fact_sales, para provar que rodar o mesmo dia de
novo não duplica linhas (Tarefa 4 da PA2).

Como usar:
  1. rodar este script (contagem "antes");
  2. mandar o Airflow rodar de novo um dia que já foi carregado, ex.:
        airflow tasks clear northmart_daily -s 2018-05-03 -e 2018-05-03 -y
  3. esperar a execução terminar e rodar o script de novo ("depois").
As contagens têm de ser iguais e os duplicados, zero.

Uso (a partir da raiz do repositório, com source pa2_env.sh):
    python tests/check_idempotency.py antes
"""

import os
import sys
from datetime import datetime

import duckdb

DB_PATH = os.environ.get("NORTHMART_DB", "data/northmart_pa2.duckdb")
momento = sys.argv[1] if len(sys.argv) > 1 else ""

con = duckdb.connect(DB_PATH, read_only=True)

# 1. Total de linhas e itens repetidos (mesmo order_id + order_item_id)
total, duplicados = con.execute("""
    SELECT count(*),
           count(*) - count(DISTINCT (order_id, order_item_id))
    FROM fact_sales
""").fetchone()

print(f"=== Contagem da fact_sales {momento} ({datetime.now():%Y-%m-%d %H:%M:%S})")
print(f"Linhas na fato: {total}")
print(f"Itens duplicados: {duplicados}")

# 2. Linhas por dia da compra
print("Linhas por dia:")
for date_key, linhas in con.execute("""
    SELECT date_key, count(*)
    FROM fact_sales
    GROUP BY date_key
    ORDER BY date_key
""").fetchall():
    print(f"  {date_key}: {linhas}")

con.close()
