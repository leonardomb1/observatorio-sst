import uuid
from datetime import datetime, timezone

import pymysql
import requests
import wmill

MUNICIPIOS = "https://servicodados.ibge.gov.br/api/v1/localidades/municipios"
CNAE_CLASSES = "https://servicodados.ibge.gov.br/api/v2/cnae/classes"
SEP = "\x01"


def stream_load(sr, tabela, colunas, payload, label):
    headers = {
        "label": label,
        "column_separator": SEP,
        "columns": ",".join(colunas),
        "max_filter_ratio": "0.001",
        "timeout": "600",
        "Expect": "100-continue",
    }
    auth = (sr["user"], sr["password"])
    url = f"http://{sr['host']}:8030/api/bronze/{tabela}/_stream_load"
    r = requests.put(url, data=payload, headers=headers, auth=auth,
                     allow_redirects=False, timeout=650)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers,
                         auth=auth, timeout=650)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {tabela} falhou: {res}")
    return res.get("NumberLoadedRows", 0)


def uf_do_municipio(m):
    # municipios criados recentemente vem com microrregiao nula
    micro = m.get("microrregiao") or {}
    meso = micro.get("mesorregiao") or {}
    uf = meso.get("UF")
    if uf:
        return uf
    imediata = m.get("regiao-imediata") or {}
    intermediaria = imediata.get("regiao-intermediaria") or {}
    uf = intermediaria.get("UF")
    if uf:
        return uf
    raise Exception(f"nao consegui resolver a UF de {m.get('nome')} ({m.get('id')})")


def main():
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    municipios = requests.get(MUNICIPIOS, timeout=180).json()
    if len(municipios) < 5000:
        raise Exception(f"apenas {len(municipios)} municipios retornados")
    linhas_mun = []
    for m in municipios:
        completo = str(m["id"])
        uf = uf_do_municipio(m)
        regiao = (uf.get("regiao") or {}).get("nome", "")
        linhas_mun.append(SEP.join([completo[:6], completo, m["nome"],
                                    uf["sigla"], uf["nome"], regiao, agora]))

    classes = requests.get(CNAE_CLASSES, timeout=180).json()
    if len(classes) < 600:
        raise Exception(f"apenas {len(classes)} classes retornadas")
    linhas_cnae = []
    for c in classes:
        codigo = str(c["id"])[:4]
        grupo = c.get("grupo") or {}
        divisao = grupo.get("divisao") or {}
        secao = divisao.get("secao") or {}
        linhas_cnae.append(SEP.join([
            codigo, c["descricao"], grupo.get("descricao", ""),
            divisao.get("descricao", ""), secao.get("descricao", ""), agora]))

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE bronze.ibge_municipios")
            cur.execute("TRUNCATE TABLE bronze.cnae_classes")
    finally:
        conn.close()

    run = uuid.uuid4().hex[:8]
    n1 = stream_load(sr, "ibge_municipios",
                     ["codigo", "codigo_completo", "nome", "uf_sigla", "uf_nome",
                      "regiao", "carregado_em"],
                     ("\n".join(linhas_mun)).encode("utf-8"), f"sst_ibge_mun_{run}")
    n2 = stream_load(sr, "cnae_classes",
                     ["codigo", "descricao", "grupo", "divisao", "secao", "carregado_em"],
                     ("\n".join(linhas_cnae)).encode("utf-8"), f"sst_cnae_cls_{run}")
    return {"municipios": n1, "cnae_classes": n2}
