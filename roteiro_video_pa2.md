# Roteiro do vídeo da PA2 (até 5 min)

**O que o enunciado pede no vídeo:**
1. ligar a API simulada;
2. rodar a DAG para um dia limpo e para o dia corrompido;
3. mostrar a grid do Airflow e a saída do `dbt test` dos dois dias;
4. mostrar as contagens da fato antes e depois de rodar um dia de novo.

Os dois integrantes precisam falar. O roteiro dá o começo ao **Integrante A** (quem fez as Tarefas 1 e 4) e o fim ao **Integrante B** (quem fez as Tarefas 2 e 3).

**Estratégia:** não recomeçar do zero. O backfill já está feito: 13 dias verdes e o 09 vermelho. No vídeo, rodamos de novo o dia 03 (limpo) e o dia 09 (corrompido) com `airflow tasks clear`. Isso cobre "rodar a DAG" nos dois dias e a prova de idempotência, sem esperar os 14 dias.

**Em que máquina gravar:** na que já tem o backfill feito, ou seja, a grid com os 14 dias e a fato com 4 059 linhas. Se forem gravar noutra máquina, antes é preciso montar o ambiente e rodar o backfill, como manda a seção "Rodar o pipeline no Airflow" do README.

Este arquivo fica no repositório só para o grupo. O `.gitattributes` o tira do zip da entrega.

---

## Antes de gravar (fora do vídeo)

1. Abrir **3 terminais do Ubuntu**, todos na raiz do repositório e com `source pa2_env.sh`:
   - **T1:** vai ligar a API. Deixar vazio, porque isso é gravado.
   - **T2:** `airflow standalone`, já rodando. Esperar a interface abrir.
   - **T3:** para os comandos. Limpar com `clear`.
2. No navegador, abrir `http://localhost:8080`, fazer login e deixar na grid da `northmart_daily`:
   - colapsar o painel de detalhes;
   - conferir que as 14 colunas aparecem.
3. Aumentar a fonte dos terminais (Ctrl + roda do mouse) e fechar o que não vai aparecer na tela.
4. Ensaiar uma vez com o cronômetro. Cada `clear` leva de 30 s a 1 min até terminar: dá para cortar a espera na edição ou falar enquanto roda.

**Atenção:** não rodar o `check_idempotency.py` enquanto uma execução estiver ativa. O DuckDB aceita um escritor por vez e o script daria erro de lock.

---

## Cenas

### 1. Abertura — Integrante A (0:00–0:20)

**Tela:** o README no GitHub, na seção da PA2, ou o `architecture/pipeline.md`.

> "Na PA2, trocamos a carga manual da PA1 por um pipeline diário: extrai os pedidos de uma API, guarda as respostas numa camada raw, transforma com dbt e roda no Airflow. Os testes ficam entre o staging e a fato: se falharem, a fato não muda."

### 2. Ligar a API — Integrante A (0:20–0:50)

**T1:**
```bash
uvicorn mock_api:app --port 8000
```

**T3**, para mostrar que ela responde:
```bash
curl -s "localhost:8000/orders?date=2018-05-03&page=1" | head -c 300
```

> "A API entrega os itens de cada dia, 100 por página. Às vezes ela responde 503 de propósito. A nossa tarefa de extração pede todas as páginas e tenta de novo quando dá 503, e grava cada resposta sem alterar em `data/raw/<data>/`."

### 3. A DAG e o backfill — Integrante A (0:50–1:30)

**Tela:** a grid da `northmart_daily`. Clicar na aba **Graph** e depois voltar para a grid.

> "A DAG tem cinco tarefas: extract, load, dbt_staging, dbt_test e dbt_marts. Ela é diária, de 1 a 14 de maio, e roda um dia de cada vez, porque o DuckDB aceita um único escritor. Fizemos o backfill dos 14 dias: 13 terminaram verdes, e o dia 9 parou no dbt_test."

Passar o mouse na coluna do dia 09 para mostrar o `dbt_test` vermelho e o `dbt_marts` como `upstream_failed`.

### 4. Dia limpo e idempotência — Integrante A (1:30–2:30)

**T3**, a contagem antes:
```bash
python tests/check_idempotency.py antes
```

> "A fato tem 4 059 linhas, zero duplicados, e o dia 3 tem 357. Agora vamos rodar a DAG de novo para o dia 3."

**T3:**
```bash
airflow tasks clear northmart_daily -s 2018-05-03 -e 2018-05-03 -y
```

**Tela:** a grid, com o dia 03 rodando até ficar verde. Cortar a espera.

> "Enquanto roda: cada camada é idempotente. O extract troca a pasta da data, o load apaga e reinsere a data na raw, e a fato é incremental com delete+insert pela chave do item."

**T3**, a contagem depois:
```bash
python tests/check_idempotency.py depois
```

> "Continua com 4 059 linhas, 357 no dia 3 e zero duplicados. Rodar o mesmo dia duas vezes não duplica nada."

### 5. Saída do dbt test no dia limpo — Integrante B (2:30–3:10)

**Tela:** na grid, clicar no `dbt_test` do dia 03 e abrir o **log**. Rolar até o fim, onde aparece `PASS=19`.

> "Eu fiz a parte do dbt. O staging tipa e limpa só o lote do dia, sem apagar linhas, para os testes enxergarem os defeitos. São 19 testes: unicidade, not null, integridade com as dimensões da PA1, faixa de valores e uma regra de negócio nossa. A regra é que um seller não pode vender antes da data em que entrou na NorthMart. No dia 3, os 19 passaram, e o dbt_marts carregou a fato."

### 6. Dia corrompido — Integrante B (3:10–4:20)

**T3:**
```bash
airflow tasks clear northmart_daily -s 2018-05-09 -e 2018-05-09 -y
```

**Tela:** a grid, com o dia 09 rodando. O `dbt_test` fica vermelho e o `dbt_marts` fica `upstream_failed`. Abrir o **log** do `dbt_test` e mostrar as 3 falhas e o `ERROR=3` no fim.

> "O dia 9 é o corrompido. O extract, o load e o staging rodam, mas três testes falham: 15 preços negativos, 10 itens sem cliente e 20 itens duplicados. Com isso o dbt_marts nem roda: a DAG parou antes de atualizar a fato."

**T3:**
```bash
python tests/check_idempotency.py depois-dia-09
```

> "A fato continua com 4 059 linhas, e o dia 9 nem aparece na lista. O lote ruim não chegou aos relatórios."

### 7. Fecho — Integrante B (4:20–4:45)

**Tela:** o README, nas Tarefas 5 e 6.

> "Comparamos o dia 9 item a item com a PA1, e os testes pegaram todos os defeitos. O lote fica em quarentena, avisamos a fonte, e quando ela corrigir os dados rodamos só esse dia de novo. A tarefa mais lenta é o dbt_staging, e quase todo o tempo é a inicialização do dbt. A otimização é juntar as três tarefas do dbt num único dbt build. Obrigado."

---

## Gravar e entregar

- **Gravar:** com o OBS, ou com a Ferramenta de Captura do Windows no modo vídeo com o microfone ligado.
  - Se gravarem juntos, numa chamada, basta uma gravação.
  - Se gravarem separados, cada um grava as suas cenas e vocês juntam no Clipchamp.
- **Conferir antes de enviar:**
  - o vídeo tem no máximo 5:00;
  - os dois falam;
  - aparecem as contagens antes e depois;
  - aparece o log do `dbt test` dos dois dias.
- **Zip do repositório:**
  ```bash
  git archive --format=zip -o ../PA2_69607_69584.zip HEAD
  ```
  O zip vai para a pasta acima do repositório, para não ficar solto dentro dele. Ele tem só o que está commitado. Não entram `data/source/`, `data/raw/` nem os bancos `.duckdb`, como o `.gitignore` manda, e também não entra este roteiro. Por isso, façam o commit e o push de tudo antes de gerar o zip.
- **Enviar** o zip e o vídeo no virtual.ipb.pt até **sábado, 14/11, às 23:59**.
