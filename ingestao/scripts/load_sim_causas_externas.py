import csv
import io
import re
import uuid
import zipfile
from datetime import datetime, timezone
from typing import List, Optional

import pymysql
import requests
import wmill

PAGINA = "https://dadosabertos.saude.gov.br/dataset/sim"
ARQUIVO = re.compile(r"https://[^\"\\]*/SIM/csv/Mortalidade_Geral_(\d{4})_csv\.zip")
CAMPOS = ["dtobito", "idade", "sexo", "racacor", "esc2010", "ocup", "codmunres",
          "codmunocor", "lococor", "causabas", "circobito", "acidtrab", "fonte"]
COLUMNS = ["ano"] + CAMPOS + ["arquivo_origem", "carregado_em"]
SEP = "\x01"
ANO_INICIAL = 2018


def anos_publicados():
    html = requests.get(PAGINA, timeout=120, headers={"User-Agent": "Mozilla/5.0"}).text
    return {int(a): u for u, a in ((m.group(0), m.group(1)) for m in ARQUIVO.finditer(html))}


def stream_load(sr, payload: bytes, label: str):
    url = f"http://{sr['host']}:8030/api/bronze/sim_causas_externas/_stream_load"
    headers = {
        "label": label,
        "column_separator": SEP,
        "columns": ",".join(COLUMNS),
        "max_filter_ratio": "0.001",
        "timeout": "1200",
        "Expect": "100-continue",
    }
    auth = (sr["user"], sr["password"])
    r = requests.put(url, data=payload, headers=headers, auth=auth,
                     allow_redirects=False, timeout=1300)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers,
                         auth=auth, timeout=1300)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {label} failed: {res}")
    return res.get("NumberLoadedRows", 0)


def carrega_ano(sr, ano, url, agora):
    arquivo = url.rsplit("/", 1)[-1]
    pacote = requests.get(url, timeout=1800)
    pacote.raise_for_status()
    z = zipfile.ZipFile(io.BytesIO(pacote.content))
    membro = [n for n in z.namelist() if n.lower().endswith(".csv")]
    if len(membro) != 1:
        raise Exception(f"{arquivo}: esperado 1 csv, encontrado {z.namelist()}")
    leitor = csv.reader(io.TextIOWrapper(z.open(membro[0]), encoding="latin-1"),
                        delimiter=";")
    cabecalho = [c.strip().strip('"').lower() for c in next(leitor)]
    faltando = [c for c in CAMPOS if c not in cabecalho]
    if faltando:
        raise Exception(f"{arquivo}: colunas ausentes {faltando}")
    pos = [cabecalho.index(c) for c in CAMPOS]
    i_causa = cabecalho.index("causabas")

    linhas, total = [], 0
    for campos in leitor:
        total += 1
        causa = campos[i_causa].strip() if i_causa < len(campos) else ""
        if not causa or causa[0] not in "VWXY":
            continue
        valores = [campos[p].strip() if p < len(campos) else "" for p in pos]
        linhas.append(SEP.join([str(ano)] + valores + [arquivo, agora]))
    if total == 0:
        raise Exception(f"{arquivo}: nenhum obito lido")

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.sim_causas_externas WHERE ano = %s", (ano,))
        conn.commit()
    finally:
        conn.close()
    carregadas = stream_load(sr, "\n".join(linhas).encode("utf-8"),
                             f"sst_sim_{ano}_{uuid.uuid4().hex[:8]}")
    return {"ano": ano, "obitos": total, "causas_externas": len(linhas),
            "linhas_carregadas": carregadas}


def main(anos: Optional[List[int]] = None):
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    publicados = anos_publicados()
    if not publicados:
        raise Exception(f"nenhum arquivo do SIM encontrado em {PAGINA}")
    if not anos:
        anos = sorted(a for a in publicados if a >= ANO_INICIAL)[-2:]
    ausentes = [a for a in anos if a not in publicados]
    if ausentes:
        raise Exception(f"anos nao publicados: {ausentes}; disponiveis: {sorted(publicados)}")
    return [carrega_ano(sr, a, publicados[a], agora) for a in sorted(anos)]
