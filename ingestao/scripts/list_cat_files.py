import re
import unicodedata

import pymysql
import requests
import wmill

CKAN = "https://dadosabertos.inss.gov.br/api/3/action/package_show?id="
# Package ids survive renames; names do not (the PDA dataset was renamed jun-2025 -> dez-2027 in Oct/2026).
DATASETS = [
    "60982ce4-0258-49be-bebc-c1ff5309ba4b",  # inss-comunicacao-de-acidente-de-trabalho-cat
    "e6219d53-5478-4143-bcb9-a922ee622eca",  # ...-cat-plano-de-dados-abertos-jun-2023-a-dez-2027
]

MESES = {
    "janeiro": 1, "fevereiro": 2, "marco": 3, "abril": 4, "maio": 5,
    "junho": 6, "julho": 7, "agosto": 8, "setembro": 9, "outubro": 10,
    "novembro": 11, "dezembro": 12,
}


def _ascii(s: str) -> str:
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()


def periodo_for(name: str, url: str):
    fname = url.split("/")[-1]
    m = re.search(r"(20\d{4})", fname)
    if m:
        return m.group(1)
    # fall back to the resource name: first Portuguese month + year
    n = _ascii(name)
    year = re.search(r"(20\d{2})", n)
    months = [v for k, v in MESES.items() if k in n]
    if year and months:
        return f"{year.group(1)}{min(months):02d}"
    return None


def _package(ds: str, proxy: str) -> dict:
    # The CKAN API blocks Hetzner addresses; it is reached through the Brazilian relay.
    r = requests.get(CKAN + ds, timeout=60, proxies={"https": proxy})
    if r.status_code != 200:
        raise Exception(f"CKAN HTTP {r.status_code} for dataset {ds}")
    body = r.json()
    if not body.get("success"):
        raise Exception(f"CKAN dataset {ds} unavailable: {body.get('error')}")
    return body["result"]


def _publicado(url: str) -> bool:
    r = requests.head(url, timeout=60, allow_redirects=True)
    if r.status_code == 405:
        r = requests.get(url, timeout=60, stream=True)
        r.close()
    return r.status_code < 400


def main(only_missing: bool = True):
    proxy = wmill.get_variable("f/sst/inss_proxy")
    files = {}
    colisoes = []
    for ds in DATASETS:
        for r in _package(ds, proxy)["resources"]:
            url = r["url"]
            if url.lower().endswith(".xlsx"):
                continue
            periodo = periodo_for(r["name"], url)
            if not periodo:
                raise Exception(f"could not resolve periodo for {r['name']} ({url})")
            # later datasets overwrite earlier ones for the same periodo
            if periodo in files and files[periodo]["url"] != url:
                colisoes.append(periodo)
            files[periodo] = {"periodo": periodo, "url": url, "nome": r["name"]}

    out = sorted(files.values(), key=lambda f: f["periodo"])

    if only_missing:
        sr = wmill.get_resource("f/infra/starrocks")
        conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                               user=sr["user"], password=sr["password"])
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT DISTINCT periodo FROM bronze.cat")
                loaded = {row[0] for row in cur.fetchall()}
        finally:
            conn.close()
        out = [f for f in out if f["periodo"] not in loaded]

    # Listed in CKAN but not served by S3 yet (403/404): skip instead of failing the whole flow.
    nao_publicado = [f["periodo"] for f in out if not _publicado(f["url"])]
    if nao_publicado:
        print(f"nao publicado ainda, ignorado: {nao_publicado}")
    if colisoes:
        print(f"periodos oferecidos pelos dois datasets (vale o mais novo): {sorted(set(colisoes))}")
    return [f for f in out if f["periodo"] not in nao_publicado]
