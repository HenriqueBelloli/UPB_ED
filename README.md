# NorthMart — Data Engineering 2026/27

Plataforma de dados da NorthMart construída em três etapas (PA1, PA2, PA3) para a unidade curricular de Data Engineering do IPB.

## Setup

Requisitos: Python 3.12+ (testado com 3.14).

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# Linux / macOS / WSL
source .venv/bin/activate

pip install -r requirements.txt
```

### Dados de origem

Os arquivos de origem não são versionados. Antes de rodar qualquer script, coloque em `data/source/`:

1. Os 9 CSVs do [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle), com os nomes originais.
2. O arquivo `northmart_seller_profiles.json` (página da disciplina no virtual.ipb.pt).

Contagem esperada de linhas:

| Arquivo | Linhas |
|---|---:|
| olist_customers_dataset.csv | 99 441 |
| olist_geolocation_dataset.csv | 1 000 163 |
| olist_order_items_dataset.csv | 112 650 |
| olist_order_payments_dataset.csv | 103 886 |
| olist_order_reviews_dataset.csv | 99 224 |
| olist_orders_dataset.csv | 99 441 |
| olist_products_dataset.csv | 32 951 |
| olist_sellers_dataset.csv | 3 095 |
| product_category_name_translation.csv | 71 |
| northmart_seller_profiles.json | 3 095 registros |

## Estrutura do repositório

```
├── README.md
├── requirements.txt
├── architecture/   # diagramas: star schema (PA1), pipeline (PA2)
├── data/
│   ├── source/     # CSVs da Olist e JSON de sellers (não versionado)
│   ├── raw/        # respostas da API por data (PA2, não versionado)
│   ├── staging/    # arquivos intermediários
│   └── curated/    # exports em Parquet e saídas finais
├── sql/            # profiling.sql, build_model.sql, queries de benchmark
├── src/            # código Python
├── tests/          # verificações fora do dbt
└── evidence/       # tabela de benchmark, screenshots, contagens
```

---

## PA1 — Dos arquivos brutos ao star schema

### Como reproduzir

Todos os comandos são executados a partir da raiz do repositório, com o ambiente virtual ativo. O banco DuckDB é criado em `data/northmart.duckdb` (não versionado).

**1. Carregar a camada raw**

```bash
python src/run_sql.py sql/load_raw.sql
```

Cria uma tabela `raw_*` para cada arquivo de `data/source/`, sem nenhuma transformação, e no final mostra a contagem de linhas de cada tabela (deve bater com a tabela da seção "Dados de origem").

| Tabela | Origem |
|---|---|
| raw_orders | olist_orders_dataset.csv |
| raw_order_items | olist_order_items_dataset.csv |
| raw_customers | olist_customers_dataset.csv |
| raw_products | olist_products_dataset.csv |
| raw_sellers | olist_sellers_dataset.csv |
| raw_payments | olist_order_payments_dataset.csv |
| raw_reviews | olist_order_reviews_dataset.csv |
| raw_geolocation | olist_geolocation_dataset.csv |
| raw_category_translation | product_category_name_translation.csv |
| raw_seller_profiles | northmart_seller_profiles.json (campos aninhados mantidos como STRUCT) |

**2. Profiling da camada raw**

```bash
python src/run_sql.py sql/profiling.sql > evidence/profiling_output.txt
```

Roda todas as verificações de qualidade sobre as tabelas raw e guarda a saída (queries e resultados) em `evidence/profiling_output.txt`. Os achados estão na seção "Tarefa 1".

_Próximos passos (build do modelo, export e benchmark) a preencher._

### Tarefa 1 — Achados do profiling

Script: [`sql/profiling.sql`](sql/profiling.sql) · Saída completa: [`evidence/profiling_output.txt`](evidence/profiling_output.txt)

O profiling mediu, em todas as 10 tabelas raw: quantidade de linhas, unicidade das chaves, duplicados, porcentagem de nulos, registros órfãos entre tabelas e regras de negócio (ordem das datas, valores impossíveis, textos sem padrão).

#### Principais achados

| # | Fonte | Achado | Impacto e tratamento no modelo |
|---|---|---|---|
| 1 | JSON | **25 `seller_id` repetidos**: 3 095 registros para 3 070 sellers. Cada um tem duas versões; a mais antiga é sempre de 2017-06-15 09:00, e em 7 casos o `tier` muda entre as versões (ex.: bronze → silver). | Juntar direto com a fato duplicaria as vendas desses sellers. Fica só a versão com o `updated_at` mais recente. |
| 2 | JSON | **`tier` escrito de 9 formas**: além de `bronze`, `silver` e `gold`, aparecem `Bronze ` (com espaço, 21), `BRONZE` (19), `SILVER` (7), `Silver ` (6), `Gold ` (5) e `GOLD` (2). **30 perfis não têm o bloco `shipping`**, logo não têm `handling_days`. | Agrupar por tier daria 9 grupos em vez de 3. O tier passa por `lower(trim(...))`. O `handling_days` ausente fica nulo (desconhecido), não 0. |
| 3 | JSON | **Cobertura incompleta nos dois sentidos**: 15 perfis não pertencem a nenhum seller da Olist e são dados de teste (e-mail `new_N@example.com`, mesmo telefone `+55 11 90000-0000`, mesmo `updated_at`). E 40 sellers da Olist não têm perfil; eles vendem 769 itens, R$ 78 585,05. | Os 15 perfis de teste são descartados (a `dim_seller` parte de `raw_sellers`). Os 40 sellers sem perfil continuam no modelo com tier "desconhecido", para não perder as vendas deles. |
| 4 | JSON | **141 perfis com `joined_on` depois do `updated_at`**: o perfil teria sido atualizado antes de o seller existir. Já o `joined_on` é coerente com as vendas: nenhum seller vendeu antes da data de entrada. | O `joined_on` é usado como data de entrada. O `updated_at` serve só para escolher a versão mais recente do perfil. |
| 5 | customers | **`customer_id` não identifica a pessoa**: são 99 441 `customer_id` para 96 096 pessoas (`customer_unique_id`). O `customer_id` muda a cada pedido, e 3 345 registros são da mesma pessoa voltando a comprar. | Contar clientes por `customer_id` infla o número em 3,5%. A `dim_customer` guarda o `customer_unique_id` como atributo e a contagem de clientes usa ele. |
| 6 | products | **610 produtos sem categoria** (1,85%), que também não têm nome, descrição nem fotos. Eles somam 1 603 itens vendidos e R$ 179 535,28. Além disso, 2 categorias não têm tradução (`pc_gamer` e `portateis_cozinha_e_preparadores_de_alimentos`), com 24 itens. | Um JOIN simples descartaria R$ 185 mil de vendas no top 5 de categorias. Produto sem categoria recebe "sem_categoria" e categoria sem tradução usa o nome em português. |
| 7 | orders | **775 pedidos sem nenhum item** (603 `unavailable`, 164 `canceled`, entre outros). O mês 2016-11 não tem nenhum pedido, e as pontas do período estão quase vazias: 2016-09 (4), 2016-12 (1), 2018-09 (16) e 2018-10 (4). | Pedidos sem itens não entram numa fato com grão de item. A `dim_date` é um calendário contínuo, para o mês vazio aparecer como zero e não sumir. O benchmark usa um mês completo (2017-11). |
| 8 | payments | **Pagamento não bate com os itens em 380 pedidos**: em 232 deles se pagou mais de R$ 1 acima do preço + frete (juros do parcelamento). Há também 1 pedido sem pagamento e 3 pagamentos `not_defined` com valor 0. | Pagamento é registrado por pedido, não por item. Por isso fica fora da fato, e a receita é medida pelo `price` dos itens. |
| 9 | geolocation | **26% das linhas são duplicadas exatas** (261 831 de 1 000 163), com até 1 146 linhas para o mesmo CEP. Há 42 coordenadas fora do Brasil, 8 CEPs em dois estados e a mesma cidade com e sem acento (`são paulo` 24 918 vezes, `sao paulo` 135 800). | A tabela não é usada no star schema: cidade e estado já vêm de customers e sellers. |

#### Catálogo completo de inconsistências

Todos os números abaixo vêm de `evidence/profiling_output.txt`.

| Fonte | Verificação | Resultado | Tratamento |
|---|---|---|---|
| orders | `order_id` único | 0 duplicados | — |
| orders | Pedidos sem cliente | 0 | — |
| orders | Nulos em `order_approved_at` / `order_delivered_carrier_date` / `order_delivered_customer_date` | 0,16% / 1,79% / 2,98% | Datas não viram medida no PA1; a fato usa só a data da compra (0% nulo). |
| orders | Entregue à transportadora antes da compra | 166 | Valores mantidos como vieram; não usados no modelo. |
| orders | Entregue à transportadora antes da aprovação | 1 359 | Idem. |
| orders | Entregue ao cliente antes da transportadora | 23 | Idem. |
| orders | Status `delivered` sem data de entrega / sem aprovação | 8 / 14 | Idem. |
| orders | Status `canceled` com data de entrega | 6 | Idem. |
| orders | Itens de pedidos `canceled` e `unavailable` | 542 itens (R$ 95 235,27) e 7 itens (R$ 2 007,69) | Ficam na fato com o `order_status`; as queries de receita excluem esses dois status. |
| orders | Dias sem nenhum pedido entre a primeira e a última compra | 140 | `dim_date` contínua. |
| order_items | Chave `order_id + order_item_id` | 0 duplicados | — |
| order_items | Itens órfãos (sem pedido, produto ou seller) | 0 | Checagem repetida no build do modelo. |
| order_items | Preço ≤ 0 / frete negativo | 0 / 0 | — |
| order_items | Frete zero / frete maior que o preço | 383 / 4 124 | Valores plausíveis (frete grátis, produtos baratos); mantidos. |
| order_items | Mesmo produto em várias linhas do mesmo pedido | 7 088 combinações | Não existe coluna de quantidade: cada linha é uma unidade, e "itens vendidos" = número de linhas. |
| order_items | Pedidos com mais de um seller | 1 278 | O seller pertence ao item, não ao pedido; reforça o grão de item. |
| order_items | Prazo de envio > 60 dias após a compra | 12 (até 2020-04-09) | `shipping_limit_date` não entra no modelo. |
| customers | Pessoas com mais de um CEP | 250 | O endereço fica ligado ao `customer_id` (endereço daquele pedido). |
| customers | CEPs com mais de um nome de cidade | 39 (ex.: `embu` / `embu das artes`, `paraty` / `parati`) | Análises geográficas por estado (27 UFs válidas, 0 nulos). |
| customers | CEP fora da geolocalização | 278 | Geolocalização não usada. |
| products | Sem peso ou dimensões / peso zero | 2 / 4 | Atributos não usados nas análises do PA1. |
| products | Colunas com erro de grafia (`product_name_lenght`, `product_description_lenght`) | 2 colunas | Renomeadas para `length` no modelo. |
| products | Categorias quase repetidas (`casa_conforto` e `casa_conforto_2`, `eletrodomesticos` e `eletrodomesticos_2`) | 2 pares | Mantidas como vieram (não há como saber se são a mesma). |
| sellers | Cidade fora do padrão (barra, hífen, vírgula, espaço duplo, acento, número, e-mail) | 27 sellers, ex.: `sao paulo - sp`, `sp / sp`, `sbc/sp`, `04482255`, `vendas@creditparts.com.br` | Análises geográficas por estado (0 nulos). |
| sellers | "sao paulo" escrito de formas diferentes | 7 variações além da correta (`sao paulop`, `sao  paulo`, `são paulo`...) | Idem. |
| sellers | CEP fora da geolocalização | 7 | Geolocalização não usada. |
| reviews | `review_id` usado em mais de um pedido | 789 ids (814 linhas extras) | Avaliações ficam fora da fato. |
| reviews | Pedidos com mais de uma avaliação / sem avaliação | 547 / 768 | Idem. |
| reviews | Avaliação criada antes da compra | 64 | Idem. |
| reviews | Título / comentário nulos | 88,34% / 58,70% | Texto livre não é carregado no modelo. |
| payments | Valor zero / 0 parcelas | 9 / 2 | Pagamentos fora da fato. |
| JSON | E-mail e telefone dos sellers | dados pessoais em 100% dos perfis | Não entram no modelo (não são necessários para análise de vendas). |

#### Prevenção: verificações automáticas no build

Para que esses problemas não voltem sem ninguém perceber, o `build_model.sql` termina com verificações que precisam dar o resultado esperado:

- A fato tem 112 650 linhas e a mesma soma de `price` da `raw_order_items` (nenhum item perdido ou duplicado nos JOINs).
- Nenhuma linha da fato sem dimensão correspondente (0 órfãos em cada chave).
- A `dim_seller` tem exatamente uma linha por `seller_id` (3 095).
- O `tier` só tem os valores `bronze`, `silver`, `gold` ou `desconhecido`.
- O `handling_days` é nulo ou maior que zero.
- As surrogate keys de cada dimensão são únicas.

No PA2, essas mesmas regras viram testes do dbt.

### Tarefa 2 — Star schema

_A preencher: diagrama, grão, medidas e decisão de modelagem._

### Tarefa 4 — Benchmark

_A preencher: método e tabela de resultados._

### Tarefa 5 — Data warehouse, data lake ou lakehouse?

_A preencher (máx. 150 palavras)._

---

## PA2 — Pipeline ELT orquestrado e testado

_A preencher._

---

## PA3 — Proteção de dados e exploração de ferramenta

_A preencher._
