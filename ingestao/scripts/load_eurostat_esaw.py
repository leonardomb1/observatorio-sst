import csv
import io
import uuid
from datetime import datetime, timezone

import pymysql
import requests
import wmill

BASE = "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/{ds}/{chave}?format=SDMX-CSV"
DATASETS = [
    ("hsw_n2_02", "fatal", "A..."),
    ("hsw_n2_01", "nao_fatal", "A...T."),
]
COLUMNS = ["ano", "dataset", "gravidade", "unidade", "nace_r2", "geo", "valor",
           "flag", "carregado_em"]
SEP = "\x01"


def stream_load(sr, payload: bytes, label: str):
    url = f"http://{sr['host']}:8030/api/bronze/eurostat_esaw/_stream_load"
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

    lines, por_dataset = [], {}
    for ds, gravidade, chave in DATASETS:
        r = requests.get(BASE.format(ds=ds, chave=chave), timeout=300)
        r.raise_for_status()
        n = 0
        for row in csv.DictReader(io.StringIO(r.text)):
            if not row.get("OBS_VALUE"):
                continue
            lines.append(SEP.join([
                row["TIME_PERIOD"], ds, gravidade, row["unit"], row["nace_r2"],
                row["geo"], row["OBS_VALUE"], row.get("OBS_FLAG", ""), agora,
            ]))
            n += 1
        if n == 0:
            raise Exception(f"Eurostat nao devolveu valores de {ds}")
        por_dataset[ds] = n

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE bronze.eurostat_esaw")
    finally:
        conn.close()

    res = stream_load(sr, "\n".join(lines).encode("utf-8"),
                      f"sst_esaw_{uuid.uuid4().hex[:8]}")
    return {"linhas_por_dataset": por_dataset,
            "linhas_carregadas": res.get("NumberLoadedRows", 0)}
