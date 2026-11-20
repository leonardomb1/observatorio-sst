import csv
import io
import uuid
from datetime import datetime, timezone

import pymysql
import requests
import wmill

SDMX = "https://sdmx.ilo.org/rest/data/ILO,{flow}/all?format=csv&startPeriod=2000"
FLOWS = {
    "SDG_F881": "DF_SDG_F881_SEX_MIG_RT",
    "SDG_N881": "DF_SDG_N881_SEX_MIG_RT",
}

COLUMNS = ["indicador", "ref_area", "sexo", "mig", "ano", "valor",
           "obs_status", "fonte", "nota_fonte", "nota_indicador", "carregado_em"]

SEP = "\x01"


def stream_load(sr, payload: bytes, label: str):
    url = f"http://{sr['host']}:8030/api/bronze/ilo_sst_taxas/_stream_load"
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

    lines = []
    per_flow = {}
    for indicador, flow in FLOWS.items():
        r = requests.get(SDMX.format(flow=flow), timeout=300)
        r.raise_for_status()
        reader = csv.DictReader(io.StringIO(r.text))
        n = 0
        for row in reader:
            if not row.get("OBS_VALUE"):
                continue
            lines.append(SEP.join([
                indicador,
                row["REF_AREA"],
                row["SEX"],
                row["MIG"],
                row["TIME_PERIOD"],
                row["OBS_VALUE"],
                row.get("OBS_STATUS", ""),
                row.get("SOURCE", ""),
                row.get("NOTE_SOURCE", ""),
                row.get("NOTE_INDICATOR", ""),
                agora,
            ]))
            n += 1
        per_flow[indicador] = n
        if n == 0:
            raise Exception(f"ILO SDMX returned no rows for {flow}")

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE bronze.ilo_sst_taxas")
    finally:
        conn.close()

    label = f"sst_ilo_{uuid.uuid4().hex[:8]}"
    payload = ("\n".join(lines)).encode("utf-8")
    res = stream_load(sr, payload, label)

    return {"linhas_por_indicador": per_flow,
            "linhas_carregadas": res.get("NumberLoadedRows", 0)}
