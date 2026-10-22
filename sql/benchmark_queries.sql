-- =====================================================================
-- benchmark_queries.sql
--
-- As três queries do benchmark da Tarefa 4.
--
-- Todas leem a fato pela view "fato". O src/benchmark.py cria essa
-- view três vezes, cada vez apontando para um formato (CSV, Parquet,
-- Parquet particionado), e roda as mesmas queries em cada um. Assim o
-- texto das queries é idêntico e só o formato muda.
-- As dimensões (dim_date, dim_product) são lidas do banco DuckDB.
--
-- Receita = soma de price dos itens cujo pedido não está 'canceled'
-- nem 'unavailable' (decisão de modelagem no README).
--
-- Executar com:
--     python src/benchmark.py
-- =====================================================================


-- ---------------------------------------------------------------------
-- Query 1: receita por mês em todo o período
--
-- Parte do calendário (dim_date) para que os meses sem venda, como
-- 2016-11, também apareçam, com receita 0.
-- A condição do status fica no ON, e não no WHERE: no WHERE, ela
-- eliminaria os meses sem venda (que não têm nenhum item da fato).
-- coalesce(..., 0) troca a soma nula desses meses por 0.
-- ---------------------------------------------------------------------

SELECT
    d.year_month,
    round(coalesce(sum(f.price), 0), 2) AS receita
FROM dim_date AS d
LEFT JOIN fato AS f
       ON f.date_key = d.date_key
      AND f.order_status NOT IN ('canceled', 'unavailable')
GROUP BY d.year_month
ORDER BY d.year_month;


-- ---------------------------------------------------------------------
-- Query 2: receita e quantidade de itens de um único mês (2017-11)
--
-- 2017-11 é o mês com mais vendas (Black Friday) e está completo.
-- O filtro usa year_month, a coluna de partição: no formato
-- particionado, o DuckDB lê só a pasta year_month=2017-11.
-- ---------------------------------------------------------------------

SELECT
    round(sum(price), 2) AS receita,
    count(*)             AS itens
FROM fato
WHERE year_month = '2017-11'
  AND order_status NOT IN ('canceled', 'unavailable');


-- ---------------------------------------------------------------------
-- Query 3: as cinco categorias de produto com maior receita
-- ---------------------------------------------------------------------

SELECT
    p.category_name_english AS categoria,
    round(sum(f.price), 2)  AS receita
FROM fato AS f
JOIN dim_product AS p ON p.product_key = f.product_key
WHERE f.order_status NOT IN ('canceled', 'unavailable')
GROUP BY p.category_name_english
ORDER BY receita DESC
LIMIT 5;
