import io
import re
import uuid
import warnings
from datetime import datetime, timezone
from urllib.parse import urljoin

import pymysql
import requests
from pypdf import PdfReader
import wmill

INDEX = ("https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/inspecao-do-trabalho/"
         "seguranca-e-saude-no-trabalho/ctpp-nrs/normas-regulamentadoras-nrs")
UA = {"User-Agent": "Mozilla/5.0 (observatorio-sst; academic)"}

SEP = "\x01"
ROW = "\x02"


def get(url):
    try:
        r = requests.get(url, headers=UA, timeout=120)
    except requests.exceptions.SSLError:
        # sit.trabalho.gov.br serves an incomplete certificate chain
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            r = requests.get(url, headers=UA, timeout=120, verify=False)
    r.raise_for_status()
    return r


def find_norm_pages(html):
    pages = {}
    for m in re.finditer(r'href="(https://www\.gov\.br/[^"]*(?:norma-regulamentadora-no-(\d+)-nr-\2|/nr-(\d+))[^"]*)"', html):
        url = m.group(1)
        num = int(m.group(2) or m.group(3))
        pages[num] = url
    return pages


def find_pdf(html, num, page_url):
    # names vary wildly: nr-06.pdf, NR35atualizada2023.pdf, nr-06-atualizada-2025-ii.pdf
    pat = r'href="([^"]*/nr-?_?0?%d(?!\d)[^"/]*\.pdf)"' % num
    cands = re.findall(pat, html, re.I)
    # drop obvious non-norm documents (manuals, guides, portarias, atas)
    cands = [c for c in cands if not re.search(r"manual|guia|cartilha|portaria|ata_", c, re.I)]
    if not cands:
        return None
    atual = [c for c in cands if "atualizada" in c.lower()]
    return urljoin(page_url, (atual or cands)[-1])


def page_title(html):
    m = re.search(r"<h1[^>]*>(.*?)</h1>", html, re.S)
    if m:
        return re.sub(r"<[^>]+>|\s+", " ", m.group(1)).strip()
    return ""


ITEM_RE = re.compile(r"^(\d{1,2}(?:\.\d{1,3})+)\s")


def segment(text, nr):
    items = []
    current = ("preambulo", [])
    for line in text.splitlines():
        line = line.rstrip()
        if not line:
            continue
        m = ITEM_RE.match(line.lstrip())
        if m and m.group(1).split(".")[0] == str(nr):
            items.append(current)
            current = (m.group(1), [line.lstrip()])
        else:
            current[1].append(line)
    items.append(current)
    return [(k, "\n".join(v)) for k, v in items if v]


def main(apenas_nrs: list = None):
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    pages = find_norm_pages(get(INDEX).text)
    if len(pages) < 30:
        raise Exception(f"only {len(pages)} NR pages found, expected ~37")
    if apenas_nrs:
        pages = {n: u for n, u in pages.items() if n in set(int(x) for x in apenas_nrs)}

    norma_lines = []
    texto_lines = []
    report = {}
    failures = {}
    for num in sorted(pages):
        try:
            html = get(pages[num]).text
            pdf_url = find_pdf(html, num, pages[num])
            titulo = page_title(html)
            if not pdf_url:
                failures[num] = "no pdf link found"
                continue
            pdf = get(pdf_url).content
            reader = PdfReader(io.BytesIO(pdf))
            text = "\n".join((p.extract_text() or "") for p in reader.pages)
            if len(text) < 500:
                failures[num] = f"extracted only {len(text)} chars"
                continue
        except Exception as e:
            failures[num] = f"{type(e).__name__}: {str(e)[:120]}"
            continue
        parts = segment(text, num)
        norma_lines.append(SEP.join([str(num), titulo, pages[num], pdf_url,
                                     pdf_url.split("/")[-1], agora]))
        ordem = 0
        for item, txt in parts:
            texto_lines.append(SEP.join([str(num), item, txt, str(ordem), agora]))
            ordem += 1
        texto_lines.append(SEP.join([str(num), "__integra__", text, str(ordem), agora]))
        report[num] = {"itens": len(parts), "chars": len(text)}

    if not norma_lines:
        raise Exception(f"no NR extracted; failures={failures}")

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            if apenas_nrs:
                nums = ",".join(str(int(x)) for x in apenas_nrs)
                cur.execute(f"DELETE FROM bronze.nr_norma WHERE nr_numero IN ({nums})")
                cur.execute(f"DELETE FROM bronze.nr_texto WHERE nr_numero IN ({nums})")
            else:
                cur.execute("TRUNCATE TABLE bronze.nr_norma")
                cur.execute("TRUNCATE TABLE bronze.nr_texto")
        conn.commit()
    finally:
        conn.close()

    run = uuid.uuid4().hex[:8]
    for table, cols, lines in [
        ("nr_norma", ["nr_numero", "titulo", "url_pagina", "url_pdf",
                      "arquivo_pdf", "extraido_em"], norma_lines),
        ("nr_texto", ["nr_numero", "item", "texto", "ordem", "extraido_em"],
         texto_lines),
    ]:
        headers = {
            "label": f"sst_{table}_{run}",
            "column_separator": SEP,
            "row_delimiter": ROW,
            "columns": ",".join(cols),
            "max_filter_ratio": "0.001",
            "timeout": "600",
            "Expect": "100-continue",
        }
        payload = ROW.join(lines).encode("utf-8")
        r = requests.put(f"http://{sr['host']}:8030/api/bronze/{table}/_stream_load",
                         data=payload, headers=headers,
                         auth=(sr["user"], sr["password"]),
                         allow_redirects=False, timeout=650)
        if r.status_code in (301, 302, 307, 308):
            r = requests.put(r.headers["Location"], data=payload, headers=headers,
                             auth=(sr["user"], sr["password"]), timeout=650)
        res = r.json()
        if res.get("Status") not in ("Success", "Publish Timeout"):
            raise Exception(f"stream load {table} failed: {res}")

    return {"nrs": report, "falhas": failures}
