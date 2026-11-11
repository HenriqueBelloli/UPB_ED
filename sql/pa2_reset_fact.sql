-- =====================================================================
-- pa2_reset_fact.sql
--
-- Prepara o banco da PA2 (enunciado: "run the PA1 build script against
-- it, then delete all rows of the fact table, so that the pipeline
-- fills it").
--
-- As dimensões ficam como o build_model.sql da PA1 construiu; só a
-- fact_sales é esvaziada. Quem a enche de novo, dia a dia, é o
-- pipeline (dbt, chamado pelo Airflow).
--
-- Executar junto com a carga e o build da PA1, no banco da PA2:
--     NORTHMART_DB=data/northmart_pa2.duckdb python src/run_sql.py \
--         sql/load_raw.sql sql/build_model.sql sql/pa2_reset_fact.sql
-- =====================================================================

DELETE FROM fact_sales;

-- Conferência: a fato vazia e as dimensões cheias
SELECT 'fact_sales'   AS tabela, count(*) AS linhas FROM fact_sales
UNION ALL
SELECT 'dim_date'     AS tabela, count(*) AS linhas FROM dim_date
UNION ALL
SELECT 'dim_customer' AS tabela, count(*) AS linhas FROM dim_customer
UNION ALL
SELECT 'dim_product'  AS tabela, count(*) AS linhas FROM dim_product
UNION ALL
SELECT 'dim_seller'   AS tabela, count(*) AS linhas FROM dim_seller;
