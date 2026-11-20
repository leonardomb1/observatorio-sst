import csv
import io
import uuid
import zipfile
from datetime import datetime, timezone

import pymysql
import requests
import wmill

CID_ZIP = "http://www2.datasus.gov.br/cid10/V2008/downloads/CID10CSV.zip"
CBO_OCUP = "https://raw.githubusercontent.com/lucassmacedo/cbo-brasil/master/csv/CBO2002%20-%20Ocupacao.csv"
CBO_FAM = "https://raw.githubusercontent.com/lucassmacedo/cbo-brasil/master/csv/CBO2002%20-%20Familia.csv"

SEP = "\x01"


def stream_load(sr, table, columns, payload: bytes, label: str):
    url = f"http://{sr['host']}:8030/api/bronze/{table}/_stream_load"
    headers = {
        "label": label,
        "column_separator": SEP,
        "columns": ",".join(columns),
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
        raise Exception(f"stream load {label} -> {table} failed: {res}")
    return res


def fix_double_encoding(text: str) -> str:
    # 'aeronÃ¡utica' -> 'aeronáutica' when the file is UTF-8-of-latin1-of-UTF-8
    if text.count("Ã") > 20:
        try:
            return text.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            return text
    return text


def parse_semicolon_csv(text: str):
    reader = csv.reader(io.StringIO(text), delimiter=";")
    header = next(reader)
    for row in reader:
        if row and any(f.strip() for f in row):
            yield dict(zip(header, row))


def load_cid10(sr, agora):
    z = zipfile.ZipFile(io.BytesIO(requests.get(CID_ZIP, timeout=120).content))
    read = lambda name: z.read(name).decode("latin-1")

    capitulos = []  # (catinic, catfim, num, desc)
    for r in parse_semicolon_csv(read("CID-10-CAPITULOS.CSV")):
        capitulos.append((r["CATINIC"], r["CATFIM"], r["NUMCAP"], r["DESCRICAO"]))
    grupos = []
    for r in parse_semicolon_csv(read("CID-10-GRUPOS.CSV")):
        grupos.append((r["CATINIC"], r["CATFIM"], r["DESCRICAO"]))

    def lookup(cat3, ranges):
        for item in ranges:
            if item[0] <= cat3 <= item[1]:
                return item
        return None

    rows = []
    for r in parse_semicolon_csv(read("CID-10-CATEGORIAS.CSV")):
        cod = r["CAT"].strip()
        cap = lookup(cod, capitulos)
        grp = lookup(cod, grupos)
        rows.append([cod, cod, "categoria", r["DESCRICAO"], r["DESCRABREV"],
                     grp[2] if grp else "", cap[2] if cap else "",
                     cap[3] if cap else "", agora])
    for r in parse_semicolon_csv(read("CID-10-SUBCATEGORIAS.CSV")):
        cod = r["SUBCAT"].strip()
        dotted = cod[:3] + "." + cod[3:] if len(cod) > 3 else cod
        cap = lookup(cod[:3], capitulos)
        grp = lookup(cod[:3], grupos)
        rows.append([cod, dotted, "subcategoria", r["DESCRICAO"], r["DESCRABREV"],
                     grp[2] if grp else "", cap[2] if cap else "",
                     cap[3] if cap else "", agora])

    cols = ["codigo", "codigo_pontuado", "nivel", "descricao", "descricao_abrev",
            "grupo_descricao", "capitulo_num", "capitulo_descricao", "carregado_em"]
    payload = "\n".join(SEP.join(r) for r in rows).encode("utf-8")
    return rows, cols, payload


def load_cbo(sr, agora):
    fam_text = fix_double_encoding(requests.get(CBO_FAM, timeout=60).text)
    ocup_text = fix_double_encoding(requests.get(CBO_OCUP, timeout=60).text)

    familias = {}
    for r in parse_semicolon_csv(fam_text):
        familias[r["code"].strip()] = r["name"].strip()

    rows = []
    for cod, nome in familias.items():
        rows.append([cod, "familia", nome, cod, nome, agora])
    for r in parse_semicolon_csv(ocup_text):
        cod = r["code"].strip()
        fam = cod[:4]
        rows.append([cod, "ocupacao", r["name"].strip(), fam,
                     familias.get(fam, ""), agora])

    cols = ["codigo", "nivel", "titulo", "familia_codigo", "familia_titulo",
            "carregado_em"]
    payload = "\n".join(SEP.join(r) for r in rows).encode("utf-8")
    return rows, cols, payload


def main():
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    cid_rows, cid_cols, cid_payload = load_cid10(sr, agora)
    cbo_rows, cbo_cols, cbo_payload = load_cbo(sr, agora)
    if len(cid_rows) < 12000 or len(cbo_rows) < 2500:
        raise Exception(f"suspiciously small: cid10={len(cid_rows)} cbo={len(cbo_rows)}")

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE bronze.cid10")
            cur.execute("TRUNCATE TABLE bronze.cbo")
    finally:
        conn.close()

    run = uuid.uuid4().hex[:8]
    r1 = stream_load(sr, "cid10", cid_cols, cid_payload, f"sst_cid10_{run}")
    r2 = stream_load(sr, "cbo", cbo_cols, cbo_payload, f"sst_cbo_{run}")

    return {"cid10": r1.get("NumberLoadedRows", 0),
            "cbo": r2.get("NumberLoadedRows", 0)}
