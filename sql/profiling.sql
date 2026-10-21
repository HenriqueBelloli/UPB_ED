-- =====================================================================
-- profiling.sql
--
-- Profiling da camada raw (Tarefa 1 do PA1).
-- Mede em cada tabela: quantidade de linhas, unicidade das chaves,
-- duplicados, porcentagem de nulos, registros órfãos entre tabelas e
-- regras de negócio (datas fora de ordem, valores impossíveis, textos
-- sem padrão).
--
-- Pré-requisito: ter rodado o load_raw.sql.
-- Executar a partir da raiz do repositório:
--     python src/run_sql.py sql/profiling.sql
-- Para guardar a saída como evidência:
--     python src/run_sql.py sql/profiling.sql > evidence/profiling_output.txt
--
-- Padrões usados nas queries:
--   * cada linha do resultado é uma verificação ("verificacao") com a
--     quantidade de registros encontrados ("qtd");
--   * count(*) FILTER (WHERE ...) conta só as linhas que atendem à
--     condição;
--   * NOT IN (SELECT ...) encontra valores que não existem na outra
--     tabela, ou seja, registros órfãos.
-- =====================================================================


-- =====================================================================
-- 1. LINHAS, CHAVES E DUPLICADOS
--
-- Para cada tabela: total de linhas, quantos valores distintos a chave
-- tem e quantas linhas sobram (duplicados = linhas - chaves distintas).
-- Se a chave é única, "duplicados" tem que ser 0.
-- (a, b) dentro do count(DISTINCT ...) conta as combinações distintas
-- das duas colunas juntas (chave composta).
-- =====================================================================

SELECT 'raw_orders' AS tabela, 'order_id' AS chave,
       count(*) AS linhas,
       count(DISTINCT order_id) AS chaves_distintas,
       count(*) - count(DISTINCT order_id) AS duplicados
FROM raw_orders
UNION ALL
SELECT 'raw_order_items', 'order_id + order_item_id',
       count(*),
       count(DISTINCT (order_id, order_item_id)),
       count(*) - count(DISTINCT (order_id, order_item_id))
FROM raw_order_items
UNION ALL
SELECT 'raw_customers', 'customer_id',
       count(*),
       count(DISTINCT customer_id),
       count(*) - count(DISTINCT customer_id)
FROM raw_customers
UNION ALL
SELECT 'raw_customers', 'customer_unique_id (pessoa)',
       count(*),
       count(DISTINCT customer_unique_id),
       count(*) - count(DISTINCT customer_unique_id)
FROM raw_customers
UNION ALL
SELECT 'raw_products', 'product_id',
       count(*),
       count(DISTINCT product_id),
       count(*) - count(DISTINCT product_id)
FROM raw_products
UNION ALL
SELECT 'raw_sellers', 'seller_id',
       count(*),
       count(DISTINCT seller_id),
       count(*) - count(DISTINCT seller_id)
FROM raw_sellers
UNION ALL
SELECT 'raw_payments', 'order_id + payment_sequential',
       count(*),
       count(DISTINCT (order_id, payment_sequential)),
       count(*) - count(DISTINCT (order_id, payment_sequential))
FROM raw_payments
UNION ALL
SELECT 'raw_reviews', 'review_id',
       count(*),
       count(DISTINCT review_id),
       count(*) - count(DISTINCT review_id)
FROM raw_reviews
UNION ALL
SELECT 'raw_category_translation', 'product_category_name',
       count(*),
       count(DISTINCT product_category_name),
       count(*) - count(DISTINCT product_category_name)
FROM raw_category_translation
UNION ALL
SELECT 'raw_geolocation', 'geolocation_zip_code_prefix',
       count(*),
       count(DISTINCT geolocation_zip_code_prefix),
       count(*) - count(DISTINCT geolocation_zip_code_prefix)
FROM raw_geolocation
UNION ALL
SELECT 'raw_seller_profiles', 'seller_id',
       count(*),
       count(DISTINCT seller_id),
       count(*) - count(DISTINCT seller_id)
FROM raw_seller_profiles;


-- =====================================================================
-- 2. PORCENTAGEM DE NULOS
--
-- SUMMARIZE calcula estatísticas de todas as colunas de uma tabela.
-- Aqui usamos só a coluna null_percentage e mostramos apenas as
-- colunas que têm algum nulo.
-- =====================================================================

SELECT 'raw_orders' AS tabela, column_name AS coluna, null_percentage AS pct_nulos
FROM (SUMMARIZE raw_orders) WHERE null_percentage > 0
UNION ALL
SELECT 'raw_order_items', column_name, null_percentage
FROM (SUMMARIZE raw_order_items) WHERE null_percentage > 0
UNION ALL
SELECT 'raw_customers', column_name, null_percentage
FROM (SUMMARIZE raw_customers) WHERE null_percentage > 0
UNION ALL
SELECT 'raw_products', column_name, null_percentage
FROM (SUMMARIZE raw_products) WHERE null_percentage > 0
UNION ALL
SELECT 'raw_sellers', column_name, null_percentage
FROM (SUMMARIZE raw_sellers) WHERE null_percentage > 0
UNION ALL
SELECT 'raw_payments', column_name, null_percentage
FROM (SUMMARIZE raw_payments) WHERE null_percentage > 0
UNION ALL
SELECT 'raw_reviews', column_name, null_percentage
FROM (SUMMARIZE raw_reviews) WHERE null_percentage > 0
UNION ALL
SELECT 'raw_geolocation', column_name, null_percentage
FROM (SUMMARIZE raw_geolocation) WHERE null_percentage > 0;

-- Nulos dentro dos campos aninhados do JSON.
-- profile.tier lê o campo "tier" de dentro do STRUCT "profile".
SELECT 'perfis sem bloco shipping'      AS verificacao, count(*) FILTER (WHERE shipping IS NULL)               AS qtd FROM raw_seller_profiles
UNION ALL
SELECT 'perfis sem handling_days',       count(*) FILTER (WHERE shipping.handling_days IS NULL)  FROM raw_seller_profiles
UNION ALL
SELECT 'perfis sem tier',                count(*) FILTER (WHERE profile.tier IS NULL)            FROM raw_seller_profiles
UNION ALL
SELECT 'perfis sem joined_on',           count(*) FILTER (WHERE profile.joined_on IS NULL)       FROM raw_seller_profiles
UNION ALL
SELECT 'perfis sem email',               count(*) FILTER (WHERE contact.email IS NULL)           FROM raw_seller_profiles
UNION ALL
SELECT 'perfis sem updated_at',          count(*) FILTER (WHERE updated_at IS NULL)              FROM raw_seller_profiles;


-- =====================================================================
-- 3. INTEGRIDADE REFERENCIAL (REGISTROS ÓRFÃOS)
--
-- Procura chaves que apontam para registros que não existem na
-- tabela relacionada. O ideal é 0 em todas as linhas.
-- =====================================================================

SELECT 'itens sem pedido em raw_orders'          AS verificacao, count(*) AS qtd
FROM raw_order_items WHERE order_id NOT IN (SELECT order_id FROM raw_orders)
UNION ALL
SELECT 'itens sem produto em raw_products',       count(*)
FROM raw_order_items WHERE product_id NOT IN (SELECT product_id FROM raw_products)
UNION ALL
SELECT 'itens sem seller em raw_sellers',         count(*)
FROM raw_order_items WHERE seller_id NOT IN (SELECT seller_id FROM raw_sellers)
UNION ALL
SELECT 'pedidos sem cliente em raw_customers',    count(*)
FROM raw_orders WHERE customer_id NOT IN (SELECT customer_id FROM raw_customers)
UNION ALL
SELECT 'pedidos sem nenhum item',                 count(*)
FROM raw_orders WHERE order_id NOT IN (SELECT order_id FROM raw_order_items)
UNION ALL
SELECT 'pedidos sem pagamento',                   count(*)
FROM raw_orders WHERE order_id NOT IN (SELECT order_id FROM raw_payments)
UNION ALL
SELECT 'pedidos sem avaliação',                   count(*)
FROM raw_orders WHERE order_id NOT IN (SELECT order_id FROM raw_reviews)
UNION ALL
SELECT 'sellers da Olist sem perfil no JSON',     count(*)
FROM raw_sellers WHERE seller_id NOT IN (SELECT seller_id FROM raw_seller_profiles)
UNION ALL
SELECT 'perfis do JSON sem seller na Olist',      count(DISTINCT seller_id)
FROM raw_seller_profiles WHERE seller_id NOT IN (SELECT seller_id FROM raw_sellers)
UNION ALL
SELECT 'clientes com CEP fora da geolocalização', count(*)
FROM raw_customers WHERE customer_zip_code_prefix NOT IN (SELECT geolocation_zip_code_prefix FROM raw_geolocation)
UNION ALL
SELECT 'sellers com CEP fora da geolocalização',  count(*)
FROM raw_sellers WHERE seller_zip_code_prefix NOT IN (SELECT geolocation_zip_code_prefix FROM raw_geolocation);


-- =====================================================================
-- 4. PEDIDOS: STATUS, DATAS E PERÍODO
-- =====================================================================

-- Quantidade de pedidos por status
SELECT order_status, count(*) AS pedidos
FROM raw_orders
GROUP BY order_status
ORDER BY pedidos DESC;

-- Datas fora de ordem ou que faltam para o status do pedido.
-- A ordem esperada é: compra -> aprovação -> transportadora -> cliente.
SELECT 'aprovado antes da compra' AS verificacao,
       count(*) FILTER (WHERE order_approved_at < order_purchase_timestamp) AS qtd
FROM raw_orders
UNION ALL
SELECT 'entregue à transportadora antes da compra',
       count(*) FILTER (WHERE order_delivered_carrier_date < order_purchase_timestamp)
FROM raw_orders
UNION ALL
SELECT 'entregue à transportadora antes da aprovação',
       count(*) FILTER (WHERE order_delivered_carrier_date < order_approved_at)
FROM raw_orders
UNION ALL
SELECT 'entregue ao cliente antes da transportadora',
       count(*) FILTER (WHERE order_delivered_customer_date < order_delivered_carrier_date)
FROM raw_orders
UNION ALL
SELECT 'status delivered sem data de entrega',
       count(*) FILTER (WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL)
FROM raw_orders
UNION ALL
SELECT 'status delivered sem data de aprovação',
       count(*) FILTER (WHERE order_status = 'delivered' AND order_approved_at IS NULL)
FROM raw_orders
UNION ALL
SELECT 'status canceled com data de entrega',
       count(*) FILTER (WHERE order_status = 'canceled' AND order_delivered_customer_date IS NOT NULL)
FROM raw_orders;

-- Período coberto e pedidos por mês.
-- Serve para ver meses vazios ou incompletos no começo e no fim.
SELECT min(order_purchase_timestamp) AS primeira_compra,
       max(order_purchase_timestamp) AS ultima_compra
FROM raw_orders;

SELECT strftime(order_purchase_timestamp, '%Y-%m') AS ano_mes,
       count(*) AS pedidos
FROM raw_orders
GROUP BY ano_mes
ORDER BY ano_mes;


-- =====================================================================
-- 5. ITENS: VALORES E GRÃO
-- =====================================================================

-- Faixa de valores de preço e frete
SELECT min(price)            AS preco_min,
       median(price)         AS preco_mediana,
       max(price)            AS preco_max,
       min(freight_value)    AS frete_min,
       median(freight_value) AS frete_mediana,
       max(freight_value)    AS frete_max
FROM raw_order_items;

-- Valores suspeitos e características do grão (1 linha = 1 unidade)
SELECT 'itens com preço <= 0' AS verificacao,
       count(*) FILTER (WHERE price <= 0) AS qtd
FROM raw_order_items
UNION ALL
SELECT 'itens com frete negativo',
       count(*) FILTER (WHERE freight_value < 0)
FROM raw_order_items
UNION ALL
SELECT 'itens com frete zero (frete grátis?)',
       count(*) FILTER (WHERE freight_value = 0)
FROM raw_order_items
UNION ALL
SELECT 'itens com frete maior que o preço',
       count(*) FILTER (WHERE freight_value > price)
FROM raw_order_items
UNION ALL
SELECT 'pedido + produto repetido em várias linhas (sem coluna de quantidade)',
       count(*)
FROM (SELECT order_id, product_id FROM raw_order_items GROUP BY order_id, product_id HAVING count(*) > 1)
UNION ALL
SELECT 'pedidos com mais de um seller',
       count(*)
FROM (SELECT order_id FROM raw_order_items GROUP BY order_id HAVING count(DISTINCT seller_id) > 1);

-- Prazo de envio (shipping_limit_date) muito distante da compra
SELECT 'itens com prazo de envio > 60 dias após a compra' AS verificacao,
       count(*) AS qtd,
       max(i.shipping_limit_date) AS maior_prazo
FROM raw_order_items AS i
JOIN raw_orders AS o ON o.order_id = i.order_id
WHERE date_diff('day', o.order_purchase_timestamp, i.shipping_limit_date) > 60;

-- Itens e receita por status do pedido (mostra quanto vem de cancelados)
SELECT o.order_status,
       count(*)                AS itens,
       round(sum(i.price), 2)  AS receita
FROM raw_order_items AS i
JOIN raw_orders AS o ON o.order_id = i.order_id
GROUP BY o.order_status
ORDER BY itens DESC;


-- =====================================================================
-- 6. CLIENTES
-- =====================================================================

-- customer_id muda a cada pedido; customer_unique_id é a pessoa
SELECT count(DISTINCT customer_id)        AS customer_ids,
       count(DISTINCT customer_unique_id) AS pessoas
FROM raw_customers;

-- Quantas pessoas fizeram 1, 2, 3... pedidos
SELECT pedidos_da_pessoa, count(*) AS pessoas
FROM (
    SELECT customer_unique_id, count(*) AS pedidos_da_pessoa
    FROM raw_customers
    GROUP BY customer_unique_id
)
GROUP BY pedidos_da_pessoa
ORDER BY pedidos_da_pessoa;

-- Endereço e grafia da cidade sem padrão
SELECT 'pessoas com mais de um CEP' AS verificacao, count(*) AS qtd
FROM (
    SELECT customer_unique_id
    FROM raw_customers
    GROUP BY customer_unique_id
    HAVING count(DISTINCT customer_zip_code_prefix) > 1
)
UNION ALL
SELECT 'CEPs com mais de um nome de cidade', count(*)
FROM (
    SELECT customer_zip_code_prefix
    FROM raw_customers
    GROUP BY customer_zip_code_prefix
    HAVING count(DISTINCT customer_city) > 1
);

-- Exemplos de CEP com mais de um nome de cidade
SELECT customer_zip_code_prefix,
       list(DISTINCT customer_city) AS cidades
FROM raw_customers
GROUP BY customer_zip_code_prefix
HAVING count(DISTINCT customer_city) > 1
LIMIT 10;


-- =====================================================================
-- 7. PRODUTOS E CATEGORIAS
-- =====================================================================

SELECT 'produtos sem categoria' AS verificacao,
       count(*) FILTER (WHERE product_category_name IS NULL) AS qtd
FROM raw_products
UNION ALL
SELECT 'produtos sem peso ou dimensões',
       count(*) FILTER (WHERE product_weight_g IS NULL OR product_length_cm IS NULL)
FROM raw_products
UNION ALL
SELECT 'produtos com peso zero',
       count(*) FILTER (WHERE product_weight_g = 0)
FROM raw_products;

-- Categorias que não existem na tabela de tradução
SELECT product_category_name, count(*) AS produtos
FROM raw_products
WHERE product_category_name IS NOT NULL
  AND product_category_name NOT IN (SELECT product_category_name FROM raw_category_translation)
GROUP BY product_category_name;

-- Impacto nas vendas: itens e receita sem categoria ou sem tradução
SELECT CASE
           WHEN p.product_category_name IS NULL THEN 'sem categoria'
           WHEN t.product_category_name IS NULL THEN 'categoria sem tradução'
           ELSE 'ok'
       END                    AS situacao,
       count(*)               AS itens,
       round(sum(i.price), 2) AS receita
FROM raw_order_items AS i
JOIN raw_products AS p ON p.product_id = i.product_id
LEFT JOIN raw_category_translation AS t ON t.product_category_name = p.product_category_name
GROUP BY situacao;

-- Categorias quase repetidas (mesmo nome com sufixo _2)
SELECT product_category_name
FROM raw_category_translation
WHERE product_category_name LIKE '%\_2' ESCAPE '\'
   OR product_category_name IN ('casa_conforto', 'eletrodomesticos');


-- =====================================================================
-- 8. SELLERS (CSV): CIDADES SEM PADRÃO
-- =====================================================================

-- Cidades com barra, hífen, vírgula, e-mail, números, acento ou
-- espaço duplo (o padrão do dataset é minúsculo e sem acento)
SELECT seller_city, seller_state, count(*) AS sellers
FROM raw_sellers
WHERE seller_city LIKE '%/%'
   OR seller_city LIKE '% - %'
   OR seller_city LIKE '%,%'
   OR seller_city LIKE '%@%'
   OR seller_city LIKE '%  %'
   OR regexp_matches(seller_city, '[0-9]')
   OR seller_city <> strip_accents(seller_city)
GROUP BY seller_city, seller_state
ORDER BY seller_city;

-- Exemplo: as várias grafias de "sao paulo"
SELECT seller_city, count(*) AS sellers
FROM raw_sellers
WHERE strip_accents(seller_city) LIKE '%sao%paulo%'
   OR seller_city = 'sp / sp'
GROUP BY seller_city
ORDER BY sellers DESC;


-- =====================================================================
-- 9. JSON DE PERFIS DOS SELLERS
-- =====================================================================

-- 9.1 seller_id repetido: quantas versões e se o tier muda entre elas
SELECT count(*) AS sellers_repetidos,
       sum(versoes) AS registros_envolvidos,
       count(*) FILTER (WHERE tiers_diferentes > 1) AS com_tier_diferente
FROM (
    SELECT seller_id,
           count(*) AS versoes,
           count(DISTINCT lower(trim(profile.tier))) AS tiers_diferentes
    FROM raw_seller_profiles
    GROUP BY seller_id
    HAVING count(*) > 1
);

-- Exemplo de seller repetido com o tier diferente entre as versões
SELECT seller_id, updated_at, profile.tier AS tier, profile.joined_on AS joined_on
FROM raw_seller_profiles
WHERE seller_id IN (
    SELECT seller_id
    FROM raw_seller_profiles
    GROUP BY seller_id
    HAVING count(DISTINCT lower(trim(profile.tier))) > 1
)
ORDER BY seller_id, updated_at
LIMIT 6;

-- 9.2 Valores de tier sem padrão.
-- As aspas em volta mostram espaços no fim do texto.
SELECT '"' || profile.tier || '"' AS tier_original, count(*) AS perfis
FROM raw_seller_profiles
GROUP BY tier_original
ORDER BY perfis DESC;

-- 9.3 Distribuição de handling_days (dias para despachar)
SELECT shipping.handling_days AS handling_days, count(*) AS perfis
FROM raw_seller_profiles
GROUP BY handling_days
ORDER BY handling_days;

-- 9.4 Datas incoerentes: perfil atualizado antes de o seller entrar
SELECT 'perfis com joined_on depois de updated_at' AS verificacao,
       count(*) FILTER (WHERE profile.joined_on > updated_at) AS qtd
FROM raw_seller_profiles;

-- 9.5 joined_on comparado com a primeira venda do seller.
-- Se o seller entrou depois de já ter vendido, a data está errada.
SELECT 'sellers que venderam antes do joined_on' AS verificacao,
       count(*) AS qtd
FROM raw_seller_profiles AS p
JOIN (
    SELECT i.seller_id, min(o.order_purchase_timestamp) AS primeira_venda
    FROM raw_order_items AS i
    JOIN raw_orders AS o ON o.order_id = i.order_id
    GROUP BY i.seller_id
) AS v ON v.seller_id = p.seller_id
WHERE p.profile.joined_on > v.primeira_venda;

-- 9.6 Perfis que não pertencem a nenhum seller da Olist:
-- todos têm e-mail "new_N" e o mesmo telefone (dados de teste)
SELECT seller_id, updated_at, contact.email AS email, contact.phone AS phone
FROM raw_seller_profiles
WHERE seller_id NOT IN (SELECT seller_id FROM raw_sellers)
ORDER BY email;

-- 9.7 Sellers da Olist sem perfil: quanto eles vendem
SELECT count(DISTINCT s.seller_id) AS sellers_sem_perfil,
       count(i.order_id)           AS itens_vendidos,
       round(sum(i.price), 2)      AS receita
FROM raw_sellers AS s
LEFT JOIN raw_order_items AS i ON i.seller_id = s.seller_id
WHERE s.seller_id NOT IN (SELECT seller_id FROM raw_seller_profiles);


-- =====================================================================
-- 10. FONTES QUE NÃO ENTRAM NA FATO: PAGAMENTOS, AVALIAÇÕES, GEOLOCALIZAÇÃO
-- =====================================================================

-- 10.1 Pagamentos: tipos e valores suspeitos
SELECT payment_type, count(*) AS pagamentos, round(sum(payment_value), 2) AS valor
FROM raw_payments
GROUP BY payment_type
ORDER BY pagamentos DESC;

SELECT 'pagamentos com valor zero' AS verificacao,
       count(*) FILTER (WHERE payment_value = 0) AS qtd
FROM raw_payments
UNION ALL
SELECT 'pagamentos com 0 parcelas',
       count(*) FILTER (WHERE payment_installments = 0)
FROM raw_payments;

-- 10.2 Total pago x total dos itens (preço + frete), por pedido.
-- WITH cria duas tabelas temporárias com o total de cada lado.
WITH pago AS (
    SELECT order_id, sum(payment_value) AS total_pago
    FROM raw_payments
    GROUP BY order_id
),
itens AS (
    SELECT order_id, sum(price + freight_value) AS total_itens
    FROM raw_order_items
    GROUP BY order_id
)
SELECT count(*) AS pedidos_comparados,
       count(*) FILTER (WHERE abs(total_pago - total_itens) > 0.01) AS pedidos_com_diferenca,
       count(*) FILTER (WHERE total_pago - total_itens > 1)         AS pago_a_mais_de_1_real,
       count(*) FILTER (WHERE total_itens - total_pago > 1)         AS pago_a_menos_de_1_real
FROM pago
JOIN itens ON itens.order_id = pago.order_id;

-- 10.3 Avaliações: ids repetidos e datas incoerentes
SELECT 'review_id usado em mais de um pedido' AS verificacao, count(*) AS qtd
FROM (SELECT review_id FROM raw_reviews GROUP BY review_id HAVING count(*) > 1)
UNION ALL
SELECT 'pedidos com mais de uma avaliação', count(*)
FROM (SELECT order_id FROM raw_reviews GROUP BY order_id HAVING count(*) > 1)
UNION ALL
SELECT 'avaliações criadas antes da compra', count(*)
FROM raw_reviews AS r
JOIN raw_orders AS o ON o.order_id = r.order_id
WHERE r.review_creation_date < CAST(o.order_purchase_timestamp AS DATE);

-- 10.4 Geolocalização: duplicados exatos, coordenadas e grafias
SELECT 'linhas duplicadas exatas' AS verificacao,
       count(*) - count(DISTINCT (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
                                  geolocation_city, geolocation_state)) AS qtd
FROM raw_geolocation
UNION ALL
SELECT 'coordenadas fora do Brasil',
       count(*) FILTER (WHERE geolocation_lat NOT BETWEEN -34 AND 5.5
                           OR geolocation_lng NOT BETWEEN -74 AND -34)
FROM raw_geolocation
UNION ALL
SELECT 'cidades escritas com acento',
       count(*) FILTER (WHERE geolocation_city <> strip_accents(geolocation_city))
FROM raw_geolocation
UNION ALL
SELECT 'CEPs em mais de um estado', count(*)
FROM (
    SELECT geolocation_zip_code_prefix
    FROM raw_geolocation
    GROUP BY geolocation_zip_code_prefix
    HAVING count(DISTINCT geolocation_state) > 1
)
UNION ALL
SELECT 'maior número de linhas para um mesmo CEP', max(linhas)
FROM (
    SELECT count(*) AS linhas
    FROM raw_geolocation
    GROUP BY geolocation_zip_code_prefix
);
