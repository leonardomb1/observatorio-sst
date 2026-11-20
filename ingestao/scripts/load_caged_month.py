import os
import tempfile
import urllib.request
import uuid
from datetime import datetime, timezone

import py7zr
import pymysql
import requests
import wmill

COLUMNS = ["competencia", "uf", "municipio_codigo", "cnae_secao",
           "cnae_subclasse", "admissoes", "desligamentos", "saldo",
           "arquivo_origem", "carregado_em"]
SEP = "\x01"


def main(competencia: str, url: str):
    sr = wmill.get_resource("f/infra/starrocks")
    arquivo = url.split("/")[-1]
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    agg = {}
    with tempfile.TemporaryDirectory() as td:
        seven = os.path.join(td, arquivo)
        with urllib.request.urlopen(url, timeout=1800) as r, open(seven, "wb") as f:
            while True:
                block = r.read(8 * 1024 * 1024)
                if not block:
                    break
                f.write(block)
        with py7zr.SevenZipFile(seven) as z:
            names = [n for n in z.getnames() if n.lower().endswith(".txt")]
            if len(names) != 1:
                raise Exception(f"expected 1 txt in 7z, found {z.getnames()}")
            z.extractall(td)
        txt = os.path.join(td, names[0])

        with open(txt, "r", encoding="utf-8", errors="replace") as f:
            header = f.readline().rstrip("\n").split(";")
            idx = {h.strip().lower(): i for i, h in enumerate(header)}
            try:
                i_comp = idx["competênciamov"]
                i_uf = idx["uf"]
                i_mun = idx["município"]
                i_sec = idx["seção"]
                i_sub = idx["subclasse"]
                i_saldo = idx["saldomovimentação"]
            except KeyError as e:
                raise Exception(f"unexpected CAGED layout, missing {e}: {header}")
            ncols = len(header)
            for line in f:
                p = line.rstrip("\n").split(";")
                if len(p) != ncols:
                    continue
                key = (p[i_comp], p[i_uf], p[i_mun], p[i_sec], p[i_sub])
                a = agg.get(key)
                if a is None:
                    a = agg[key] = [0, 0, 0]
                try:
                    s = int(p[i_saldo])
                except ValueError:
                    continue
                if s > 0:
                    a[0] += s
                else:
                    a[1] += -s
                a[2] += s

    if not agg:
        raise Exception(f"no rows aggregated from {arquivo}")

    lines = []
    for (comp, uf, mun, sec, sub), (adm, desl, saldo) in agg.items():
        lines.append(SEP.join([comp, uf, mun, sec, sub, str(adm), str(desl),
                               str(saldo), arquivo, agora]))

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.caged_saldo WHERE competencia = %s",
                        (competencia,))
        conn.commit()
    finally:
        conn.close()

    label = f"sst_caged_{competencia}_{uuid.uuid4().hex[:8]}"
    payload = ("\n".join(lines)).encode("utf-8")
    headers = {
        "label": label,
        "column_separator": SEP,
        "columns": ",".join(COLUMNS),
        "max_filter_ratio": "0.001",
        "timeout": "1800",
        "Expect": "100-continue",
    }
    r = requests.put(f"http://{sr['host']}:8030/api/bronze/caged_saldo/_stream_load",
                     data=payload, headers=headers,
                     auth=(sr["user"], sr["password"]),
                     allow_redirects=False, timeout=1900)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers,
                         auth=(sr["user"], sr["password"]), timeout=1900)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {label} failed: {res}")

    return {"competencia": competencia, "arquivo": arquivo,
            "grupos": len(lines),
            "linhas_carregadas": res.get("NumberLoadedRows", 0)}
