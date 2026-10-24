"""
run_sql.py

Executa um ou mais arquivos .sql no banco DuckDB do projeto
(data/northmart.duckdb) e mostra o resultado de cada SELECT e o plano
de execução de cada EXPLAIN.

Uso (a partir da raiz do repositório):
    python src/run_sql.py sql/load_raw.sql
    python src/run_sql.py sql/load_raw.sql sql/build_model.sql
"""

import sys

import duckdb

# Caminho do banco. Se o arquivo não existir, o DuckDB cria.
DB_PATH = "data/northmart.duckdb"

# Força a saída em UTF-8. Sem isso, no Windows, salvar a saída num
# arquivo (com ">") quebra ao encontrar alguns acentos dos dados.
sys.stdout.reconfigure(encoding="utf-8")


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

        # 2.3 Se o comando for um SELECT ou um EXPLAIN, mostra a query.
        #     As linhas de comentário (--) são tiradas da query mostrada,
        #     porque o DuckDB junta ao comando os comentários que vêm
        #     logo depois dele no arquivo.
        if statement.type in (duckdb.StatementType.SELECT, duckdb.StatementType.EXPLAIN):
            linhas = statement.query.strip().splitlines()
            linhas_sem_comentario = [l for l in linhas if not l.strip().startswith("--")]
            print("\n" + "\n".join(linhas_sem_comentario).strip())

        # 2.4 Mostra o resultado: a tabela, no SELECT, ou o plano de
        #     execução, no EXPLAIN. O plano vem como texto, na segunda
        #     coluna da única linha do resultado.
        if statement.type == duckdb.StatementType.SELECT:
            print(result.df().to_string(index=False))
        elif statement.type == duckdb.StatementType.EXPLAIN:
            print(result.fetchall()[0][1])

# 3. Fecha a conexão (grava tudo no arquivo do banco)
con.close()
print("\nConcluído.")
