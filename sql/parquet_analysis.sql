-- =====================================================================
-- parquet_analysis.sql
--
-- Olha por dentro dos arquivos Parquet gerados pelo export_parquet.sql,
-- para explicar os resultados do benchmark (Tarefa 4 do PA1):
--   1. quanto cada coluna ocupa no Parquet;
--   2. quantos row groups (blocos de linhas) o arquivo único tem;
--   3. quantas linhas e quantos KB tem cada partição;
--   4. quais arquivos e colunas a query 2 lê em cada layout.
--
-- Só lê metadados e planos de execução: não altera nada.
--
-- Pré-requisito: ter rodado o export_parquet.sql.
-- Executar a partir da raiz do repositório:
--     python src/run_sql.py sql/parquet_analysis.sql > evidence/parquet_analysis_output.txt
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Espaço de cada coluna no Parquet sem partição
--
-- parquet_metadata() lê só o rodapé do arquivo, onde o Parquet guarda
-- uma linha por coluna e por row group, com o tamanho comprimido em
-- bytes (total_compressed_size).
-- parquet_file_metadata() dá o tamanho do arquivo inteiro, usado para
-- calcular a porcentagem de cada coluna.
-- ---------------------------------------------------------------------

SELECT path_in_schema AS coluna,
       round(sum(total_compressed_size) / 1024 / 1024, 2) AS mb,
       round(100.0 * sum(total_compressed_size)
             / (SELECT file_size_bytes FROM parquet_file_metadata('data/curated/fact_sales.parquet')), 1) AS pct_do_arquivo
FROM parquet_metadata('data/curated/fact_sales.parquet')
GROUP BY coluna
ORDER BY mb DESC, coluna;


-- ---------------------------------------------------------------------
-- 2. Parquet sem partição: linhas, row groups e tamanho
--
-- Um row group é um bloco de linhas que o leitor pode pular quando o
-- filtro não bate com ele. Com um só row group, não há o que pular.
-- ---------------------------------------------------------------------

SELECT num_rows                                AS linhas,
       num_row_groups                          AS row_groups,
       round(file_size_bytes / 1024 / 1024, 2) AS mb
FROM parquet_file_metadata('data/curated/fact_sales.parquet');


-- ---------------------------------------------------------------------
-- 3. Parquet particionado: linhas e tamanho de cada partição
-- ---------------------------------------------------------------------

SELECT file_name                         AS arquivo,
       num_rows                          AS linhas,
       round(file_size_bytes / 1024, 1)  AS kb
FROM parquet_file_metadata('data/curated/fact_sales_partitioned/*/*.parquet')
ORDER BY arquivo;

-- Resumo: quantos arquivos, a menor e a maior partição, e quantas
-- partições têm menos de 2 KB
SELECT count(*)                                      AS arquivos,
       min(num_rows)                                 AS menor_particao_linhas,
       max(num_rows)                                 AS maior_particao_linhas,
       count(*) FILTER (WHERE file_size_bytes < 2048) AS particoes_menores_que_2kb,
       round(sum(file_size_bytes) / 1024 / 1024, 2)  AS mb_total
FROM parquet_file_metadata('data/curated/fact_sales_partitioned/*/*.parquet');


-- ---------------------------------------------------------------------
-- 4. Plano de execução da query 2 (receita e itens de 2017-11)
--
-- EXPLAIN mostra como o DuckDB vai rodar a query, sem rodá-la.
-- No bloco "Read Parquet":
--   * Projections: colunas devolvidas pela leitura;
--   * Filters: condições aplicadas às linhas (essas colunas também
--     são lidas do arquivo);
--   * File Filters: condição aplicada ao nome das pastas (partição);
--   * Scanning Files: quantos arquivos serão lidos, do total.
-- ---------------------------------------------------------------------

-- 4.1 Parquet sem partição: o filtro do mês é aplicado às linhas
EXPLAIN
SELECT round(sum(price), 2) AS receita,
       count(*)             AS itens
FROM read_parquet('data/curated/fact_sales.parquet')
WHERE year_month = '2017-11'
  AND order_status NOT IN ('canceled', 'unavailable');

-- 4.2 Parquet particionado: o filtro do mês escolhe a pasta, e só o
-- arquivo de 2017-11 é aberto
EXPLAIN
SELECT round(sum(price), 2) AS receita,
       count(*)             AS itens
FROM read_parquet('data/curated/fact_sales_partitioned/*/*.parquet', hive_partitioning = true)
WHERE year_month = '2017-11'
  AND order_status NOT IN ('canceled', 'unavailable');
