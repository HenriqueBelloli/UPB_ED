-- =====================================================================
-- build_model.sql
--
-- Constrói o star schema de vendas (Tarefa 3 do PA1) a partir das
-- tabelas raw:
--     stg_seller_profiles  perfis do JSON achatados, 1 por seller
--     dim_date             calendário
--     dim_customer         clientes
--     dim_product          produtos e categorias
--     dim_seller           sellers + tier, joined_on e handling_days
--     fact_sales           1 linha por item de pedido
-- No final, roda as checagens referenciais e de qualidade.
--
-- O desenho do modelo está em architecture/star_schema.md.
--
-- Executar a partir da raiz do repositório, junto com a carga raw
-- (assim tudo é construído a partir dos arquivos de origem):
--     python src/run_sql.py sql/load_raw.sql sql/build_model.sql
-- =====================================================================


-- =====================================================================
-- 1. PERFIS DOS SELLERS (JSON): ACHATAR E DEDUPLICAR
--
-- A tabela raw_seller_profiles tem campos aninhados (STRUCT) e 25
-- sellers com duas versões do perfil. Aqui:
--   * achatamos os campos: profile.tier vira a coluna tier, etc.;
--   * normalizamos o tier: lower() deixa minúsculo e trim() tira os
--     espaços ("Bronze " e "BRONZE" viram "bronze");
--   * ficamos só com a versão mais recente de cada seller.
--
-- row_number() OVER (PARTITION BY seller_id ORDER BY updated_at DESC)
-- numera as versões de cada seller, começando em 1 na mais recente.
-- O WHERE versao = 1 de fora mantém só essa.
--
-- E-mail e telefone (contact) não entram: são dados pessoais e não
-- são usados na análise de vendas.
-- =====================================================================

CREATE OR REPLACE TABLE stg_seller_profiles AS
SELECT
    seller_id,
    updated_at,
    tier,
    joined_on,
    handling_days
FROM (
    SELECT
        seller_id,
        updated_at,
        lower(trim(profile.tier)) AS tier,
        profile.joined_on         AS joined_on,
        shipping.handling_days    AS handling_days,
        row_number() OVER (PARTITION BY seller_id ORDER BY updated_at DESC) AS versao
    FROM raw_seller_profiles
)
WHERE versao = 1;


-- =====================================================================
-- 2. DIM_DATE: CALENDÁRIO
--
-- Um dia por linha, de 2016-09-01 a 2018-10-31: os meses completos do
-- período dos pedidos (primeira compra em 2016-09-04, última em
-- 2018-10-17). O calendário é contínuo, então dias e meses sem venda
-- (como 2016-11) também existem.
--
-- range() gera uma lista de datas de 1 em 1 dia; o fim (2018-11-01)
-- não entra.
-- date_key é a data no formato AAAAMMDD como número (ex.: 20171124).
-- =====================================================================

CREATE OR REPLACE TABLE dim_date AS
SELECT
    CAST(strftime(dia, '%Y%m%d') AS INTEGER) AS date_key,
    CAST(dia AS DATE)                        AS full_date,
    year(dia)                                AS year,
    quarter(dia)                             AS quarter,
    month(dia)                               AS month,
    monthname(dia)                           AS month_name,
    strftime(dia, '%Y-%m')                   AS year_month,
    day(dia)                                 AS day,
    isodow(dia)                              AS day_of_week,   -- 1 = segunda ... 7 = domingo
    dayname(dia)                             AS day_name,
    isodow(dia) IN (6, 7)                    AS is_weekend
FROM range(DATE '2016-09-01', DATE '2018-11-01', INTERVAL 1 DAY) AS calendario(dia);


-- =====================================================================
-- 3. DIM_CUSTOMER: UMA LINHA POR customer_id
--
-- customer_key é a surrogate key: um número sequencial gerado aqui.
-- row_number() OVER (ORDER BY customer_id) numera as linhas em ordem
-- de customer_id, então a mesma linha recebe a mesma chave sempre que
-- o script roda de novo.
-- customer_unique_id identifica a pessoa e é usado para contar
-- clientes (decisão de modelagem no README).
-- =====================================================================

CREATE OR REPLACE TABLE dim_customer AS
SELECT
    CAST(row_number() OVER (ORDER BY customer_id) AS INTEGER) AS customer_key,
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix AS zip_code_prefix,
    customer_city            AS city,
    customer_state           AS state
FROM raw_customers;


-- =====================================================================
-- 4. DIM_PRODUCT: UMA LINHA POR product_id
--
-- LEFT JOIN com a tradução: mantém todos os produtos, mesmo os que
-- não têm tradução.
-- coalesce(a, b, c) devolve o primeiro valor que não é nulo:
--   * produto sem categoria (610)      -> 'sem_categoria'
--   * categoria sem tradução (2)       -> usa o nome em português
-- As colunas com erro de grafia na fonte ("lenght") são renomeadas.
-- =====================================================================

CREATE OR REPLACE TABLE dim_product AS
SELECT
    CAST(row_number() OVER (ORDER BY p.product_id) AS INTEGER) AS product_key,
    p.product_id,
    coalesce(p.product_category_name, 'sem_categoria') AS category_name,
    coalesce(t.product_category_name_english,
             p.product_category_name,
             'sem_categoria')                         AS category_name_english,
    p.product_name_lenght        AS name_length,
    p.product_description_lenght AS description_length,
    p.product_photos_qty         AS photos_qty,
    p.product_weight_g           AS weight_g,
    p.product_length_cm          AS length_cm,
    p.product_height_cm          AS height_cm,
    p.product_width_cm           AS width_cm
FROM raw_products AS p
LEFT JOIN raw_category_translation AS t
       ON t.product_category_name = p.product_category_name;


-- =====================================================================
-- 5. DIM_SELLER: SELLERS DA OLIST + PERFIL DO JSON
--
-- A base é raw_sellers (3 095 sellers). O LEFT JOIN traz o perfil do
-- JSON quando existe:
--   * os 40 sellers sem perfil ficam com tier 'unknown' e com
--     joined_on e handling_days nulos;
--   * os 15 perfis de teste (sem seller na Olist) não entram, porque
--     não existem em raw_sellers.
-- A cidade fica como veio da fonte; análises geográficas usam o
-- estado (decisão de modelagem no README).
-- =====================================================================

CREATE OR REPLACE TABLE dim_seller AS
SELECT
    CAST(row_number() OVER (ORDER BY s.seller_id) AS INTEGER) AS seller_key,
    s.seller_id,
    s.seller_zip_code_prefix   AS zip_code_prefix,
    s.seller_city              AS city,
    s.seller_state             AS state,
    coalesce(p.tier, 'unknown') AS tier,
    p.joined_on,
    p.handling_days
FROM raw_sellers AS s
LEFT JOIN stg_seller_profiles AS p
       ON p.seller_id = s.seller_id;


-- =====================================================================
-- 6. FACT_SALES: UMA LINHA POR ITEM DE PEDIDO
--
-- Parte de raw_order_items (1 linha = 1 item) e busca:
--   * em raw_orders: a data da compra e o status do pedido;
--   * nas dimensões: a surrogate key de cada uma.
-- Todos os JOINs são LEFT JOIN: se faltar alguma correspondência, o
-- item não some; ele fica com a chave nula e as checagens da seção 7
-- acusam o problema.
-- total_value = price + freight_value, arredondado em 2 casas para
-- não ficar com resto de conta de ponto flutuante (ex.: 0.30000001).
-- =====================================================================

CREATE OR REPLACE TABLE fact_sales AS
SELECT
    i.order_id,
    i.order_item_id,
    CAST(strftime(o.order_purchase_timestamp, '%Y%m%d') AS INTEGER) AS date_key,
    c.customer_key,
    p.product_key,
    s.seller_key,
    o.order_status,
    i.price,
    i.freight_value,
    round(i.price + i.freight_value, 2) AS total_value
FROM raw_order_items AS i
LEFT JOIN raw_orders   AS o ON o.order_id    = i.order_id
LEFT JOIN dim_customer AS c ON c.customer_id = o.customer_id
LEFT JOIN dim_product  AS p ON p.product_id  = i.product_id
LEFT JOIN dim_seller   AS s ON s.seller_id   = i.seller_id;


-- =====================================================================
-- 7. CHECAGENS REFERENCIAIS E DE QUALIDADE
--
-- Cada linha compara o valor encontrado com o valor esperado.
-- A coluna "resultado" mostra OK quando os dois são iguais e FALHA
-- quando são diferentes. Todas as linhas devem dar OK.
--
-- Órfãos: o LEFT JOIN da fato com a dimensão deixa a coluna da
-- dimensão nula quando a chave não existe nela (ou quando a chave da
-- fato é nula). Contar essas linhas dá o número de órfãos.
-- =====================================================================

WITH checagens AS (

    -- 7.1 A fato tem um item para cada linha de raw_order_items
    SELECT 'fato: linhas iguais às de raw_order_items' AS verificacao,
           (SELECT count(*) FROM fact_sales)      AS encontrado,
           (SELECT count(*) FROM raw_order_items) AS esperado

    -- 7.2 Nenhum item duplicado pelos JOINs
    UNION ALL
    SELECT 'fato: order_id + order_item_id sem duplicados',
           (SELECT count(*) - count(DISTINCT (order_id, order_item_id)) FROM fact_sales),
           0

    -- 7.3 A soma dos preços não mudou (nada perdido nem duplicado).
    --     A soma é comparada em centavos (* 100) para ser um número
    --     inteiro, como as outras linhas da tabela.
    UNION ALL
    SELECT 'fato: soma de price (em centavos) igual à de raw_order_items',
           (SELECT CAST(round(sum(price) * 100) AS BIGINT) FROM fact_sales),
           (SELECT CAST(round(sum(price) * 100) AS BIGINT) FROM raw_order_items)

    -- 7.4 a 7.7 Integridade referencial: itens sem dimensão
    UNION ALL
    SELECT 'órfãos: fato sem dim_date',
           (SELECT count(*) FROM fact_sales AS f
            LEFT JOIN dim_date AS d ON d.date_key = f.date_key
            WHERE d.date_key IS NULL),
           0
    UNION ALL
    SELECT 'órfãos: fato sem dim_customer',
           (SELECT count(*) FROM fact_sales AS f
            LEFT JOIN dim_customer AS d ON d.customer_key = f.customer_key
            WHERE d.customer_key IS NULL),
           0
    UNION ALL
    SELECT 'órfãos: fato sem dim_product',
           (SELECT count(*) FROM fact_sales AS f
            LEFT JOIN dim_product AS d ON d.product_key = f.product_key
            WHERE d.product_key IS NULL),
           0
    UNION ALL
    SELECT 'órfãos: fato sem dim_seller',
           (SELECT count(*) FROM fact_sales AS f
            LEFT JOIN dim_seller AS d ON d.seller_key = f.seller_key
            WHERE d.seller_key IS NULL),
           0

    -- 7.8 a 7.11 Cada dimensão tem uma linha por chave
    UNION ALL
    SELECT 'dim_date: date_key sem duplicados',
           (SELECT count(*) - count(DISTINCT date_key) FROM dim_date),
           0
    UNION ALL
    SELECT 'dim_customer: uma linha por customer_id de raw_customers',
           (SELECT count(DISTINCT customer_key) FROM dim_customer),
           (SELECT count(DISTINCT customer_id) FROM raw_customers)
    UNION ALL
    SELECT 'dim_product: uma linha por product_id de raw_products',
           (SELECT count(DISTINCT product_key) FROM dim_product),
           (SELECT count(DISTINCT product_id) FROM raw_products)
    UNION ALL
    SELECT 'dim_seller: uma linha por seller_id de raw_sellers',
           (SELECT count(DISTINCT seller_key) FROM dim_seller),
           (SELECT count(DISTINCT seller_id) FROM raw_sellers)
    UNION ALL
    SELECT 'dim_seller: nenhum seller_id repetido',
           (SELECT count(*) - count(DISTINCT seller_id) FROM dim_seller),
           0

    -- 7.12 a 7.14 Perfis do JSON
    UNION ALL
    SELECT 'stg_seller_profiles: um perfil por seller',
           (SELECT count(*) - count(DISTINCT seller_id) FROM stg_seller_profiles),
           0
    UNION ALL
    SELECT 'dim_seller: tier fora de bronze/silver/gold/unknown',
           (SELECT count(*) FROM dim_seller
            WHERE tier NOT IN ('bronze', 'silver', 'gold', 'unknown')),
           0
    UNION ALL
    SELECT 'dim_seller: handling_days menor ou igual a zero',
           (SELECT count(*) FROM dim_seller WHERE handling_days <= 0),
           0
)
SELECT
    verificacao,
    encontrado,
    esperado,
    CASE WHEN encontrado = esperado THEN 'OK' ELSE 'FALHA' END AS resultado
FROM checagens;


-- =====================================================================
-- 8. RESUMO DO MODELO
-- =====================================================================

-- Linhas em cada tabela do modelo
SELECT 'fact_sales'   AS tabela, count(*) AS linhas FROM fact_sales
UNION ALL
SELECT 'dim_date'     AS tabela, count(*) AS linhas FROM dim_date
UNION ALL
SELECT 'dim_customer' AS tabela, count(*) AS linhas FROM dim_customer
UNION ALL
SELECT 'dim_product'  AS tabela, count(*) AS linhas FROM dim_product
UNION ALL
SELECT 'dim_seller'   AS tabela, count(*) AS linhas FROM dim_seller;

-- Sellers por tier, depois de normalizar e juntar com o JSON
SELECT tier,
       count(*)           AS sellers,
       avg(handling_days) AS media_handling_days
FROM dim_seller
GROUP BY tier
ORDER BY sellers DESC;
