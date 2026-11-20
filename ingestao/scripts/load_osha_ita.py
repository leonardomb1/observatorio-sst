import csv
import io
import uuid
import zipfile
from datetime import datetime, timezone

import pymysql
import requests
import wmill

COLUMNS = ["ano", "establishment_name", "company_name", "state", "zip_code",
           "naics_code", "industry_description", "size", "establishment_type",
           "annual_average_employees", "total_hours_worked",
           "no_injuries_illnesses", "total_deaths", "total_dafw_cases",
           "total_djtr_cases", "total_other_cases", "total_dafw_days",
           "total_djtr_days", "total_injuries", "total_poisonings",
           "total_respiratory_conditions", "total_skin_disorders",
           "total_hearing_loss", "total_other_illnesses",
           "arquivo_origem", "carregado_em"]
DATA_COLS = COLUMNS[1:-2]

SEP = "\x01"
UA = {"User-Agent": "Mozilla/5.0 (observatorio-sst; academic)"}

INT_COLS = {"annual_average_employees", "total_hours_worked", "total_deaths",
            "total_dafw_cases", "total_djtr_cases", "total_other_cases",
            "total_dafw_days", "total_djtr_days", "total_injuries",
            "total_poisonings", "total_respiratory_conditions",
            "total_skin_disorders", "total_hearing_loss",
            "total_other_illnesses"}


def main(ano: str, url: str):
    sr = wmill.get_resource("f/infra/starrocks")
    arquivo = url.split("/")[-1]
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    data = requests.get(url, headers=UA, timeout=1800).content
    if arquivo.lower().endswith(".zip"):
        zf = zipfile.ZipFile(io.BytesIO(data))
        members = [m for m in zf.namelist() if m.lower().endswith(".csv")]
        if not members:
            raise Exception(f"no csv in {zf.namelist()}")
        data = b"".join(zf.read(m) for m in members[:1])

    text = data.decode("utf-8-sig", errors="replace")
    del data
    reader = csv.DictReader(io.StringIO(text))

    lines = []
    total = 0
    for row in reader:
        total += 1
        out = [ano]
        for col in DATA_COLS:
            v = (row.get(col) or "").strip().replace(SEP, " ").replace("\n", " ").replace("\r", " ")
            if col in INT_COLS:
                v = v.split(".")[0]
                if v and not v.lstrip("-").isdigit():
                    v = ""
            out.append(v)
        out.append(arquivo)
        out.append(agora)
        lines.append(SEP.join(out))

    if total == 0:
        raise Exception(f"no rows parsed from {arquivo}")

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.osha_ita WHERE ano = %s", (ano,))
        conn.commit()
    finally:
        conn.close()

    label = f"sst_ita_{ano}_{uuid.uuid4().hex[:8]}"
    payload = ("\n".join(lines)).encode("utf-8")
    headers = {
        "label": label,
        "column_separator": SEP,
        "columns": ",".join(COLUMNS),
        "max_filter_ratio": "0.01",
        "timeout": "1800",
        "Expect": "100-continue",
    }
    r = requests.put(f"http://{sr['host']}:8030/api/bronze/osha_ita/_stream_load",
                     data=payload, headers=headers,
                     auth=(sr["user"], sr["password"]),
                     allow_redirects=False, timeout=1900)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers,
                         auth=(sr["user"], sr["password"]), timeout=1900)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {label} failed: {res}")

    return {"ano": ano, "arquivo": arquivo, "linhas_arquivo": total,
            "linhas_carregadas": res.get("NumberLoadedRows", 0),
            "linhas_filtradas": res.get("NumberFilteredRows", 0)}
