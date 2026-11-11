"""
extract_orders.py

Extração dos pedidos da API da NorthMart (Tarefa 1 da PA2).

Para uma data, pede à API todas as páginas de itens vendidos naquele dia
e grava cada resposta, exatamente como veio, na camada raw:
    data/raw/2018-05-03/page_001.json
    data/raw/2018-05-03/page_002.json
    ...

Erros tratados:
  * 503, outros erros 5xx, timeout e falha de conexão são temporários:
    tenta de novo (até MAX_TENTATIVAS vezes), esperando um pouco mais a
    cada tentativa;
  * 4xx (ex.: 400, data inválida) é erro do próprio pedido: tentar de
    novo não resolve, então falha na hora.

Uso (a partir da raiz do repositório, com a API no ar):
    python src/extract_orders.py 2018-05-03
Na DAG do Airflow, a tarefa extract chama a função extract(data).
"""

import shutil
import sys
import time
from datetime import date
from pathlib import Path

import requests

# Endereço da API (o mock_api.py, rodando com uvicorn na porta 8000)
API_URL = "http://localhost:8000/orders"

# Camada raw: data/raw/ dentro do repositório. O caminho é montado a
# partir deste arquivo, para funcionar de qualquer pasta (o Airflow não
# roda as tarefas a partir da raiz do repositório).
RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"

# Retry: até 5 tentativas por página, esperando 1 s, 2 s, 3 s e 4 s
# entre elas
MAX_TENTATIVAS = 5
ESPERA_SEGUNDOS = 1

# Tempo máximo de espera por uma resposta da API
TIMEOUT_SEGUNDOS = 10


def buscar_pagina(data, pagina):
    """Pede uma página à API e devolve (bytes da resposta, JSON lido)."""

    for tentativa in range(1, MAX_TENTATIVAS + 1):

        # 1. Faz o pedido. Timeout e falha de conexão contam como erro
        #    temporário.
        try:
            resposta = requests.get(
                API_URL,
                params={"date": data, "page": pagina},
                timeout=TIMEOUT_SEGUNDOS,
            )
        except (requests.ConnectionError, requests.Timeout) as erro:
            motivo = type(erro).__name__
        else:
            # 2. Deu certo: devolve a resposta
            if resposta.status_code == 200:
                return resposta.content, resposta.json()

            # 3. Erro 4xx: o pedido está errado, não adianta repetir
            if 400 <= resposta.status_code < 500:
                raise RuntimeError(
                    f"Página {pagina} de {data}: erro {resposta.status_code} "
                    f"({resposta.text}). Não adianta tentar de novo."
                )

            # 4. Qualquer outro código (503 etc.) é temporário
            motivo = f"HTTP {resposta.status_code}"

        # 5. Espera um pouco mais a cada tentativa e tenta de novo
        if tentativa < MAX_TENTATIVAS:
            espera = ESPERA_SEGUNDOS * tentativa
            print(f"  página {pagina}: {motivo} na tentativa {tentativa}, "
                  f"tentando de novo em {espera} s")
            time.sleep(espera)

    # 6. Esgotou as tentativas: falha (o Airflow marca a tarefa como erro)
    raise RuntimeError(
        f"Página {pagina} de {data}: {motivo} nas {MAX_TENTATIVAS} tentativas."
    )


def extract(data):
    """Extrai todas as páginas de uma data e grava na camada raw."""

    # 1. Valida a data (erro na hora se não for AAAA-MM-DD)
    data = date.fromisoformat(str(data)).isoformat()
    print(f"Extraindo os pedidos de {data} de {API_URL}")

    # 2. Grava primeiro numa pasta temporária (data/raw/<data>.tmp).
    #    Se algo falhar no meio, a pasta da data não fica pela metade.
    pasta_final = RAW_DIR / data
    pasta_tmp = RAW_DIR / f"{data}.tmp"
    if pasta_tmp.exists():
        shutil.rmtree(pasta_tmp)
    pasta_tmp.mkdir(parents=True)

    # 3. Percorre as páginas. O total só é conhecido depois da página 1,
    #    por isso começa em 1 e é atualizado na primeira resposta.
    #    Se qualquer página falhar, a pasta temporária é apagada e o erro
    #    segue adiante; a pasta antiga da data (se existir) fica intacta.
    pagina = 1
    total_paginas = 1
    total_itens = 0

    try:
        while pagina <= total_paginas:
            conteudo_bruto, resposta = buscar_pagina(data, pagina)

            # 3.1 Na página 1, guarda o total de páginas
            if pagina == 1:
                total_paginas = resposta["total_pages"]

            # 3.2 Confere se a API respondeu o que foi pedido
            if (resposta["date"] != data
                    or resposta["page"] != pagina
                    or resposta["total_pages"] != total_paginas):
                raise RuntimeError(
                    f"Resposta inesperada para a página {pagina} de {data}: "
                    f"date={resposta['date']}, page={resposta['page']}, "
                    f"total_pages={resposta['total_pages']}"
                )

            # 3.3 Grava os bytes exatamente como vieram (sem reformatar o
            #     JSON), num arquivo por página: page_001.json, page_002.json...
            arquivo = pasta_tmp / f"page_{pagina:03d}.json"
            arquivo.write_bytes(conteudo_bruto)

            itens_da_pagina = len(resposta["items"])
            total_itens += itens_da_pagina
            print(f"  página {pagina}/{total_paginas}: {itens_da_pagina} itens")
            pagina += 1
    except Exception:
        shutil.rmtree(pasta_tmp)
        raise

    # 4. Tudo certo: troca a pasta antiga da data pela nova. Rodar a mesma
    #    data de novo substitui os arquivos em vez de acumular
    #    (idempotência).
    if pasta_final.exists():
        shutil.rmtree(pasta_final)
    pasta_tmp.rename(pasta_final)

    # 5. Resumo (aparece no log do Airflow)
    resumo = {
        "data": data,
        "paginas": total_paginas,
        "itens": total_itens,
        "pasta": str(pasta_final),
    }
    print(f"Concluído: {resumo}")
    return resumo


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python src/extract_orders.py AAAA-MM-DD")
        sys.exit(1)
    extract(sys.argv[1])
