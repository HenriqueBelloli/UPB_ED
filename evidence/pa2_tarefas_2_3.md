# PA2 Tarefas 2 e 3

## Ambiente

- Sistema: Windows 11
- Python: 3.12.10
- dbt Core: 1.12.6
- dbt DuckDB: 1.11.1
- DuckDB: 2.0.0
- Base de dados: `data/northmart_pa2.duckdb`

## Tarefa 2 Projeto dbt

Foram criados os seguintes ficheiros:

- `dbt/dbt_project.yml`
- `dbt/profiles.yml`
- `dbt/models/sources.yml`
- `dbt/models/staging/stg_api_orders.sql`
- `dbt/models/staging/schema.yml`
- `dbt/models/marts/fact_sales.sql`

O staging processa apenas o lote indicado pela variável `run_date`, converte os tipos com `try_cast`, limpa os identificadores e normaliza `order_status`.

A `fact_sales` é incremental, usa `delete+insert`, tem chave única composta por `order_id` e `order_item_id`, e utiliza `LEFT JOIN` para obter as chaves das dimensões.

## Tarefa 3 Testes

Foram implementados:

- unicidade de `order_item_key`;
- testes `not_null` nos identificadores, data e medidas;
- integridade referencial para cliente, produto e seller;
- valores aceites para `order_status`;
- faixa válida para `price` e `freight_value`;
- data da compra igual à data do lote;
- regra de negócio que impede um seller de vender antes de `joined_on`.

## Comandos de validação

Executados a partir da pasta `dbt`:

```powershell
dbt debug --profiles-dir .
dbt parse --profiles-dir .
dbt run --select staging --vars "{run_date: 2018-05-03}" --profiles-dir .
dbt test --select staging --vars "{run_date: 2018-05-03}" --profiles-dir .
dbt run --select marts --vars "{run_date: 2018-05-03}" --profiles-dir .
```

Todos os comandos terminaram com sucesso. No lote de `2018-05-03`, os 19 testes passaram e a `fact_sales` recebeu 357 linhas.

O mesmo lote foi executado novamente. A fato permaneceu com 357 linhas, confirmando a idempotência.

## Execução dos 14 dias

- Linhas carregadas em `raw_api_orders`: 4 471.
- Dias aprovados: 13.
- Dia rejeitado: `2018-05-09`.
- Linhas finais em `fact_sales`: 4 059.

No dia corrompido falharam:

- `accepted_range` de `price`: 15 valores inválidos;
- `not_null` de `customer_id`: 10 valores nulos;
- `unique` de `order_item_key`: 20 duplicados.

O dia rejeitado não foi carregado na `fact_sales`.

As saídas completas estão em:

- `evidence/dbt_test_clean.txt`
- `evidence/dbt_test_corrupted.txt`
