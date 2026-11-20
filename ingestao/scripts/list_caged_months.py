import re
import urllib.request

import pymysql
import wmill

BASE = "ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/"


def listing(url):
    return urllib.request.urlopen(url, timeout=60).read().decode("latin-1")


def main(only_missing: bool = True):
    years = sorted(set(re.findall(r"(20\d\d)\s*$", listing(BASE), re.M)))
    months = []
    for y in years:
        for m in sorted(set(re.findall(r"(\d{6})\s*$", listing(f"{BASE}{y}/"), re.M))):
            months.append({"competencia": m,
                           "url": f"{BASE}{y}/{m}/CAGEDMOV{m}.7z"})

    if only_missing:
        sr = wmill.get_resource("f/infra/starrocks")
        conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                               user=sr["user"], password=sr["password"])
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT DISTINCT competencia FROM bronze.caged_saldo")
                loaded = {row[0] for row in cur.fetchall()}
        finally:
            conn.close()
        months = [m for m in months if m["competencia"] not in loaded]

    return months
