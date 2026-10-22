-- =====================================================================
-- export_parquet.sql
--
-- Exporta a fact_sales em três formatos, para o benchmark da Tarefa 4:
--     data/curated/fact_sales.csv                  CSV (texto)
--     data/curated/fact_sales.parquet              Parquet, um arquivo só
--     data/curated/fact_sales_partitioned/         Parquet particionado
--                                                  por year_month
--
-- Os três têm exatamente as mesmas linhas e colunas, para que a única
-- diferença no benchmark seja o formato de armazenamento.
--
-- Pré-requisito: ter rodado o build_model.sql.
-- Executar a partir da raiz do repositório:
--     python src/run_sql.py sql/export_parquet.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Fato com a coluna de partição
--
-- A partição escolhida é o mês da compra (year_month, ex.: '2017-11').
-- Motivo: as análises de vendas são quase sempre por período, e a
-- query 2 do benchmark filtra um único mês; com a partição, o DuckDB
-- lê só a pasta daquele mês.
--
-- A fato não tem year_month (só date_key), então ele vem da dim_date.
-- A mesma tabela, com year_month, é exportada nos três formatos.
-- ---------------------------------------------------------------------

CREATE OR REPLACE TABLE fact_sales_export AS
SELECT
    f.*,
    d.year_month
FROM fact_sales AS f
JOIN dim_date AS d ON d.date_key = f.date_key;


-- ---------------------------------------------------------------------
-- 2. CSV: um arquivo de texto, com cabeçalho
-- ---------------------------------------------------------------------

COPY fact_sales_export
TO 'data/curated/fact_sales.csv' (FORMAT csv, HEADER);


-- ---------------------------------------------------------------------
-- 3. Parquet sem partição: um arquivo só
--
-- Parquet guarda os dados por coluna e comprimidos (o DuckDB usa a
-- compressão snappy por padrão).
-- ---------------------------------------------------------------------

COPY fact_sales_export
TO 'data/curated/fact_sales.parquet' (FORMAT parquet);


-- ---------------------------------------------------------------------
-- 4. Parquet particionado por year_month
--
-- PARTITION_BY cria uma pasta por mês, no padrão "hive":
--     fact_sales_partitioned/year_month=2017-11/data_0.parquet
-- O valor de year_month fica no nome da pasta, não dentro do arquivo.
-- OVERWRITE_OR_IGNORE permite rodar o script de novo sobre as pastas
-- que já existem.
-- ---------------------------------------------------------------------

COPY fact_sales_export
TO 'data/curated/fact_sales_partitioned' (FORMAT parquet, PARTITION_BY (year_month), OVERWRITE_OR_IGNORE);


-- ---------------------------------------------------------------------
-- 5. Conferência: os três formatos têm as mesmas linhas
--
-- hive_partitioning = true faz o DuckDB recriar a coluna year_month a
-- partir do nome das pastas.
-- Todos devem ter 112 650 linhas e a mesma soma de price.
-- ---------------------------------------------------------------------

SELECT 'csv' AS formato,
       count(*) AS linhas,
       round(sum(price), 2) AS soma_price,
       count(DISTINCT year_month) AS meses
FROM read_csv('data/curated/fact_sales.csv')
UNION ALL
SELECT 'parquet',
       count(*),
       round(sum(price), 2),
       count(DISTINCT year_month)
FROM read_parquet('data/curated/fact_sales.parquet')
UNION ALL
SELECT 'parquet_particionado',
       count(*),
       round(sum(price), 2),
       count(DISTINCT year_month)
FROM read_parquet('data/curated/fact_sales_partitioned/*/*.parquet', hive_partitioning = true);


-- ---------------------------------------------------------------------
-- 6. Limpeza: a tabela auxiliar não faz parte do modelo
-- ---------------------------------------------------------------------

DROP TABLE fact_sales_export;
