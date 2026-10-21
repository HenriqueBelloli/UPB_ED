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

_Próximos passos (profiling, build do modelo, export e benchmark) a preencher._

### Tarefa 1 — Achados do profiling

_A preencher._

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
