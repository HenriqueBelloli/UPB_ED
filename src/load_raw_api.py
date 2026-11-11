"""
load_raw_api.py

Carga dos pedidos extraídos da API no DuckDB (passo "load" da PA2).

Lê as respostas gravadas pelo extract_orders.py em data/raw/<data>/ e
grava os itens na tabela raw_api_orders, uma linha por item.

Regras da camada raw:
  * todas as colunas dos itens ficam como texto (VARCHAR), exatamente
    como vieram no JSON. Assim, um valor malformado (ex.: preço "59,9")
    não derruba a carga: quem acusa o problema são os testes do dbt,
    no staging;
  * cada linha leva a data do lote (_run_date), o arquivo de origem
    (_source_file) e o momento da carga (_loaded_at);
  * rodar a mesma data de novo substitui as linhas daquela data em vez
    de duplicar (idempotência).

Uso (a partir da raiz do repositório, depois do extract):
    python src/load_raw_api.py 2018-05-03
Na DAG do Airflow, a tarefa load chama a função load(data).
"""

import os
import sys
from datetime import date
from pathlib import Path

import duckdb

# Pastas e banco, a partir da raiz do repositório (o Airflow não roda
# as tarefas a partir da raiz, então o caminho sai deste arquivo)
REPO = Path(__file__).resolve().parent.parent
RAW_DIR = REPO / "data" / "raw"

# Banco da PA2: o da variável NORTHMART_DB (definida no pa2_env.sh) ou,
# se ela não existir, data/northmart_pa2.duckdb
DB_PATH = os.environ.get("NORTHMART_DB", str(REPO / "data" / "northmart_pa2.duckdb"))

# Tabela da camada raw. Os nomes das colunas são os campos de cada item
# da API; as três últimas são de controle da carga.
CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS raw_api_orders (
    order_id                 VARCHAR,
    order_item_id            VARCHAR,
    customer_id              VARCHAR,
    product_id               VARCHAR,
    seller_id                VARCHAR,
    order_status             VARCHAR,
    order_purchase_timestamp VARCHAR,
    price                    VARCHAR,
    freight_value            VARCHAR,
    _run_date                DATE,
    _source_file             VARCHAR,
    _loaded_at               TIMESTAMP
)
"""

# Lê todos os page_*.json da data e transforma a lista "items" em
# linhas:
#   * read_json lê cada arquivo como uma linha; "items" fica como JSON;
#   * CAST(items AS JSON[]) vira uma lista e unnest() abre uma linha
#     por item;
#   * item ->> 'campo' pega o valor do campo como texto (NULL se o
#     campo não existir).
INSERT_ITEMS = """
INSERT INTO raw_api_orders
SELECT
    item ->> 'order_id',
    item ->> 'order_item_id',
    item ->> 'customer_id',
    item ->> 'product_id',
    item ->> 'seller_id',
    item ->> 'order_status',
    item ->> 'order_purchase_timestamp',
    item ->> 'price',
    item ->> 'freight_value',
    CAST(? AS DATE)          AS _run_date,
    parse_filename(filename) AS _source_file,
    current_timestamp        AS _loaded_at
FROM (
    SELECT filename, unnest(CAST(items AS JSON[])) AS item
    FROM read_json(?,
                   columns = {date: 'VARCHAR', page: 'BIGINT',
                              total_pages: 'BIGINT', items: 'JSON'},
                   filename = true)
)
"""


def load(data):
    """Carrega os itens de uma data na raw_api_orders."""

    # 1. Valida a data e confere se o extract já gravou essa data
    data = date.fromisoformat(str(data)).isoformat()
    pasta = RAW_DIR / data
    arquivos = sorted(pasta.glob("page_*.json"))
    if not arquivos:
        raise FileNotFoundError(
            f"Nenhuma página em {pasta}. Rode o extract dessa data antes."
        )
    print(f"Carregando {len(arquivos)} página(s) de {pasta} em {DB_PATH}")

    con = duckdb.connect(DB_PATH)
    try:
        # 2. Cria a tabela na primeira vez
        con.execute(CREATE_TABLE)

        # 3. Apaga a data e insere de novo, numa transação: ou as duas
        #    coisas acontecem, ou nenhuma (um erro no meio desfaz tudo)
        con.execute("BEGIN TRANSACTION")
        try:
            con.execute("DELETE FROM raw_api_orders WHERE _run_date = ?", [data])
            con.execute(INSERT_ITEMS, [data, str(pasta / "page_*.json")])
            con.execute("COMMIT")
        except Exception:
            con.execute("ROLLBACK")
            raise

        # 4. Conferência: linhas da data na tabela
        linhas = con.execute(
            "SELECT count(*) FROM raw_api_orders WHERE _run_date = ?", [data]
        ).fetchone()[0]
    finally:
        # 5. Fecha o banco sempre, para liberar a trava do arquivo
        con.close()

    resumo = {"data": data, "paginas": len(arquivos), "linhas": linhas}
    print(f"Concluído: {resumo}")
    return resumo


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python src/load_raw_api.py AAAA-MM-DD")
        sys.exit(1)
    load(sys.argv[1])
