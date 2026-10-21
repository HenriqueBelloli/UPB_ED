"""
run_sql.py

Executa um ou mais arquivos .sql no banco DuckDB do projeto
(data/northmart.duckdb) e mostra o resultado de cada SELECT.

Uso (a partir da raiz do repositório):
    python src/run_sql.py sql/load_raw.sql
    python src/run_sql.py sql/load_raw.sql sql/build_model.sql
"""

import sys

import duckdb

# Caminho do banco. Se o arquivo não existir, o DuckDB cria.
DB_PATH = "data/northmart.duckdb"


# 1. Abre a conexão com o banco
con = duckdb.connect(DB_PATH)

# 2. Percorre os arquivos .sql passados na linha de comando, na ordem
for sql_file in sys.argv[1:]:
    print(f"\n========== {sql_file} ==========")

    # 2.1 Lê o conteúdo do arquivo
    with open(sql_file, encoding="utf-8") as f:
        sql_text = f.read()

    # 2.2 Separa o script em comandos (um por ";") e executa um de cada vez
    for statement in con.extract_statements(sql_text):
        result = con.execute(statement)

        # 2.3 Se o comando for um SELECT, mostra a query e o resultado
        if statement.type == duckdb.StatementType.SELECT:
            print("\n" + statement.query.strip())
            print(result.df().to_string(index=False))

# 3. Fecha a conexão (grava tudo no arquivo do banco)
con.close()
print("\nConcluído.")
