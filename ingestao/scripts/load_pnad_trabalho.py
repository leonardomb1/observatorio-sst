import uuid
from datetime import datetime, timezone

import pymysql
import requests
import wmill

TABELA = 4093
VARIAVEIS = [4090, 4091, 4723, 4724, 12466, 12467]
SIDRA = ("https://apisidra.ibge.gov.br/values/t/{t}/n1/all/n3/all/v/{v}/p/all/c2/all")
COLUMNS = ["trimestre", "tabela", "nivel", "territorio_codigo", "territorio",
           "sexo", "variavel_codigo", "variavel", "unidade", "valor",
           "carregado_em"]
SEP = "\x01"


def valor(texto):
    """O SIDRA usa '..', '...', '-' e 'X' para nao disponivel, nao aplicavel,
    zero absoluto e sigilo; so o zero absoluto e numero."""
    t = (texto or "").strip()
    if t == "-":
        return "0"
    try:
        float(t)
        return t
    except ValueError:
        return "\\N"


def stream_load(sr, payload: bytes, label: str):
    url = f"http://{sr['host']}:8030/api/bronze/pnad_trabalho/_stream_load"
    headers = {
        "label": label,
        "column_separator": SEP,
        "columns": ",".join(COLUMNS),
        "max_filter_ratio": "0.001",
        "timeout": "600",
        "Expect": "100-continue",
    }
    auth = (sr["user"], sr["password"])
    r = requests.put(url, data=payload, headers=headers, auth=auth,
                     allow_redirects=False, timeout=650)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers,
                         auth=auth, timeout=650)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {label} failed: {res}")
    return res


def main():
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    r = requests.get(SIDRA.format(t=TABELA, v=",".join(map(str, VARIAVEIS))),
                     timeout=300)
    r.raise_for_status()
    dados = r.json()[1:]
    if not dados:
        raise Exception(f"SIDRA nao devolveu valores da tabela {TABELA}")

    lines = []
    for d in dados:
        lines.append(SEP.join([
            d["D3C"],
            str(TABELA),
            "pais" if d["NC"] == "1" else "uf",
            d["D1C"],
            d["D1N"],
            d["D4N"],
            d["D2C"],
            d["D2N"],
            d["MN"],
            valor(d["V"]),
            agora,
        ]))

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.pnad_trabalho WHERE tabela = %s", (TABELA,))
        conn.commit()
    finally:
        conn.close()

    res = stream_load(sr, "\n".join(lines).encode("utf-8"),
                      f"sst_pnad_{TABELA}_{uuid.uuid4().hex[:8]}")
    trimestres = sorted({d["D3C"] for d in dados})
    return {"tabela": TABELA, "valores": len(dados),
            "linhas_carregadas": res.get("NumberLoadedRows", 0),
            "primeiro": trimestres[0], "ultimo": trimestres[-1]}
