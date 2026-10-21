-- =====================================================================
-- load_raw.sql
--
-- Carrega os arquivos de data/source/ em tabelas raw_* no DuckDB.
--
-- Regra da camada raw: os dados entram exatamente como vêm da fonte,
-- sem limpeza, sem remover duplicados e sem corrigir nada.
-- Tudo o que vem depois (profiling e star schema) parte destas tabelas.
--
-- Executar a partir da raiz do repositório:
--     python src/run_sql.py sql/load_raw.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. CSVs da Olist: um arquivo = uma tabela
--
-- read_csv detecta sozinho o separador, o cabeçalho e o tipo de cada
-- coluna (texto, número, data). Os valores em si não são alterados.
-- CREATE OR REPLACE permite rodar o script de novo sem dar erro.
-- ---------------------------------------------------------------------

-- Pedidos: um registro por pedido (status e datas)
CREATE OR REPLACE TABLE raw_orders AS
SELECT *
FROM read_csv('data/source/olist_orders_dataset.csv');

-- Itens dos pedidos: um registro por item (produto, seller, preço, frete)
CREATE OR REPLACE TABLE raw_order_items AS
SELECT *
FROM read_csv('data/source/olist_order_items_dataset.csv');

-- Clientes: um registro por customer_id (CEP, cidade, estado)
CREATE OR REPLACE TABLE raw_customers AS
SELECT *
FROM read_csv('data/source/olist_customers_dataset.csv');

-- Produtos: categoria (em português), peso e dimensões
CREATE OR REPLACE TABLE raw_products AS
SELECT *
FROM read_csv('data/source/olist_products_dataset.csv');

-- Sellers: CEP, cidade e estado de cada vendedor
CREATE OR REPLACE TABLE raw_sellers AS
SELECT *
FROM read_csv('data/source/olist_sellers_dataset.csv');

-- Pagamentos: um ou mais registros por pedido
CREATE OR REPLACE TABLE raw_payments AS
SELECT *
FROM read_csv('data/source/olist_order_payments_dataset.csv');

-- Avaliações: nota e comentário do cliente sobre o pedido
CREATE OR REPLACE TABLE raw_reviews AS
SELECT *
FROM read_csv('data/source/olist_order_reviews_dataset.csv');

-- Geolocalização: latitude e longitude por prefixo de CEP
CREATE OR REPLACE TABLE raw_geolocation AS
SELECT *
FROM read_csv('data/source/olist_geolocation_dataset.csv');

-- Tradução das categorias de produto (português -> inglês)
CREATE OR REPLACE TABLE raw_category_translation AS
SELECT *
FROM read_csv('data/source/product_category_name_translation.csv');


-- ---------------------------------------------------------------------
-- 2. JSON com os perfis dos sellers
--
-- read_json lê a lista de objetos e cria uma linha por seller.
-- Os campos aninhados (profile, contact, shipping) ficam como STRUCT,
-- ou seja, continuam aninhados, igual ao arquivo original.
-- O achatamento desses campos é feito depois, no build_model.sql.
-- ---------------------------------------------------------------------

CREATE OR REPLACE TABLE raw_seller_profiles AS
SELECT *
FROM read_json('data/source/northmart_seller_profiles.json');


-- ---------------------------------------------------------------------
-- 3. Conferência: quantidade de linhas carregadas em cada tabela
--
-- Os números devem ser iguais aos do README (seção "Dados de origem").
-- ---------------------------------------------------------------------

SELECT 'raw_orders'               AS tabela, count(*) AS linhas FROM raw_orders
UNION ALL
SELECT 'raw_order_items'          AS tabela, count(*) AS linhas FROM raw_order_items
UNION ALL
SELECT 'raw_customers'            AS tabela, count(*) AS linhas FROM raw_customers
UNION ALL
SELECT 'raw_products'             AS tabela, count(*) AS linhas FROM raw_products
UNION ALL
SELECT 'raw_sellers'              AS tabela, count(*) AS linhas FROM raw_sellers
UNION ALL
SELECT 'raw_payments'             AS tabela, count(*) AS linhas FROM raw_payments
UNION ALL
SELECT 'raw_reviews'              AS tabela, count(*) AS linhas FROM raw_reviews
UNION ALL
SELECT 'raw_geolocation'          AS tabela, count(*) AS linhas FROM raw_geolocation
UNION ALL
SELECT 'raw_category_translation' AS tabela, count(*) AS linhas FROM raw_category_translation
UNION ALL
SELECT 'raw_seller_profiles'      AS tabela, count(*) AS linhas FROM raw_seller_profiles;
