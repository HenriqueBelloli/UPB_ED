"""
benchmark.py

Compara três formatos da fact_sales (Tarefa 4 do PA1):
    csv                    data/curated/fact_sales.csv
    parquet                data/curated/fact_sales.parquet
    parquet_particionado   data/curated/fact_sales_partitioned/

Mede o tamanho em disco de cada formato e o tempo das três queries de
sql/benchmark_queries.sql em cada um.

Método: para cada formato e cada query, 1 execução de aquecimento (não
medida) e depois REPETICOES execuções medidas. O resultado principal é
a mediana dos tempos, que não é puxada por uma execução fora da curva.

Pré-requisito: ter rodado o build_model.sql e o export_parquet.sql.
Uso (a partir da raiz do repositório):
    python src/benchmark.py > evidence/benchmark_output.txt
"""

import csv
import os
import platform
import statistics
import sys
import time

import duckdb

DB_PATH = "data/northmart.duckdb"
QUERIES_FILE = "sql/benchmark_queries.sql"
RESULTS_FILE = "evidence/benchmark_results.csv"
REPETICOES = 10

# Para cada formato: como o DuckDB lê a fato e onde ela está no disco
FORMATOS = {
    "csv": {
        "leitura": "read_csv('data/curated/fact_sales.csv')",
        "caminho": "data/curated/fact_sales.csv",
    },
    "parquet": {
        "leitura": "read_parquet('data/curated/fact_sales.parquet')",
        "caminho": "data/curated/fact_sales.parquet",
    },
    "parquet_particionado": {
        "leitura": "read_parquet('data/curated/fact_sales_partitioned/*/*.parquet', hive_partitioning = true)",
        "caminho": "data/curated/fact_sales_partitioned",
    },
}


def tamanho_mb(caminho):
    """Tamanho em MB de um arquivo ou, se for pasta, de tudo dentro dela."""
    if os.path.isfile(caminho):
        return os.path.getsize(caminho) / (1024 * 1024)

    total = 0
    for pasta, _, arquivos in os.walk(caminho):
        for nome in arquivos:
            total += os.path.getsize(os.path.join(pasta, nome))
    return total / (1024 * 1024)


# Força a saída em UTF-8 (mesmo motivo do run_sql.py)
sys.stdout.reconfigure(encoding="utf-8")

# 1. Abre o banco só para leitura: o benchmark não altera nada
con = duckdb.connect(DB_PATH, read_only=True)

# 2. Mostra o ambiente em que o teste rodou (faz parte do método)
print("Ambiente")
print(f"  Sistema:     {platform.platform()}")
print(f"  Processador: {platform.processor()} ({os.cpu_count()} núcleos lógicos)")
print(f"  Python:      {platform.python_version()}")
print(f"  DuckDB:      {duckdb.__version__}")
print(f"  Repetições:  1 aquecimento + {REPETICOES} medidas por query e formato")

# 3. Lê as três queries do arquivo .sql
with open(QUERIES_FILE, encoding="utf-8") as f:
    queries = con.extract_statements(f.read())

# 4. Roda as queries em cada formato
linhas_resultado = []   # uma linha por (formato, query), vai para o CSV
respostas = {}          # resposta de cada query em cada formato

for formato, info in FORMATOS.items():

    # 4.1 A view "fato" passa a ler a fato deste formato
    con.execute(f"CREATE OR REPLACE TEMP VIEW fato AS SELECT * FROM {info['leitura']}")
    tamanho = tamanho_mb(info["caminho"])

    for numero, query in enumerate(queries, start=1):

        # 4.2 Aquecimento: a primeira execução não é medida
        con.execute(query).fetchall()

        # 4.3 Execuções medidas, em milissegundos
        tempos = []
        for _ in range(REPETICOES):
            inicio = time.perf_counter()
            resposta = con.execute(query).fetchall()
            tempos.append((time.perf_counter() - inicio) * 1000)

        respostas[(formato, numero)] = resposta
        linhas_resultado.append({
            "formato": formato,
            "tamanho_mb": round(tamanho, 2),
            "query": numero,
            "mediana_ms": round(statistics.median(tempos), 1),
            "min_ms": round(min(tempos), 1),
            "max_ms": round(max(tempos), 1),
        })

# 5. Confere se os três formatos deram exatamente a mesma resposta
print("\nMesma resposta nos três formatos?")
for numero in range(1, len(queries) + 1):
    iguais = (respostas[("csv", numero)] == respostas[("parquet", numero)]
              == respostas[("parquet_particionado", numero)])
    print(f"  Query {numero}: {'sim' if iguais else 'NÃO'}")

# 6. Mostra a resposta de cada query (do formato parquet)
for numero in range(1, len(queries) + 1):
    print(f"\nResposta da query {numero}:")
    for linha in respostas[("parquet", numero)]:
        print("  ", linha)

# 7. Tabela de resultados: tamanho e mediana de cada query por formato
print("\nResultados (mediana de", REPETICOES, "execuções, em ms)")
print(f"{'formato':<22}{'tamanho_mb':>12}{'query 1':>10}{'query 2':>10}{'query 3':>10}")
for formato in FORMATOS:
    linhas = [l for l in linhas_resultado if l["formato"] == formato]
    medianas = "".join(f"{l['mediana_ms']:>10}" for l in linhas)
    print(f"{formato:<22}{linhas[0]['tamanho_mb']:>12}{medianas}")

# 8. Grava todos os números (com mínimo e máximo) em CSV
with open(RESULTS_FILE, "w", newline="", encoding="utf-8") as f:
    escritor = csv.DictWriter(f, fieldnames=linhas_resultado[0].keys())
    escritor.writeheader()
    escritor.writerows(linhas_resultado)
print(f"\nDetalhes (mediana, mínimo e máximo) gravados em {RESULTS_FILE}")

con.close()
