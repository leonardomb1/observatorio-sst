import hashlib
import re
import unicodedata
import uuid
from datetime import datetime, timezone

import pymysql
import requests
import wmill

BASE = "https://www.gov.br/trabalho-e-emprego/pt-br/noticias-e-conteudo"
UA = {"User-Agent": "Mozilla/5.0 (observatorio-sst; academic)"}

SEP = "\x01"
ROW = "\x02"

RELEVANTE = re.compile(
    r"fiscaliza|inspec[aã]o do trabalho|embargo|interdi[cç]|autua[cç]|resgat|"
    r"escravid|an[aá]logo|acidente|seguran[cç]a e sa[uú]de|\bsst\b|\bnr[- ]?\d|"
    r"trabalho infantil|auditor(es)?[- ]fiscal", re.I)

TIPOS = [
    ("resgate_escravidao", re.compile(r"resgat|escravid|an[aá]logo", re.I)),
    ("embargo_interdicao", re.compile(r"embargo|interdi[cç]", re.I)),
    ("autuacao", re.compile(r"autua[cç]|multa", re.I)),
    ("acidente", re.compile(r"acidente|morte|[oó]bito", re.I)),
    ("fiscalizacao", re.compile(r"fiscaliza|inspe[cç]|opera[cç][aã]o|auditor", re.I)),
    ("sst_geral", re.compile(r".", re.S)),
]

UFS = {"AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS",
       "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC",
       "SP", "SE", "TO"}
ESTADOS = {
    "acre": "AC", "alagoas": "AL", "amapa": "AP", "amazonas": "AM",
    "bahia": "BA", "ceara": "CE", "distrito federal": "DF",
    "espirito santo": "ES", "goias": "GO", "maranhao": "MA",
    "mato grosso do sul": "MS", "mato grosso": "MT", "minas gerais": "MG",
    "para": "PA", "paraiba": "PB", "parana": "PR", "pernambuco": "PE",
    "piaui": "PI", "rio de janeiro": "RJ", "rio grande do norte": "RN",
    "rio grande do sul": "RS", "rondonia": "RO", "roraima": "RR",
    "santa catarina": "SC", "sao paulo": "SP", "sergipe": "SE",
    "tocantins": "TO",
}

MESES = {"janeiro": 1, "fevereiro": 2, "marco": 3, "março": 3, "abril": 4,
         "maio": 5, "junho": 6, "julho": 7, "agosto": 8, "setembro": 9,
         "outubro": 10, "novembro": 11, "dezembro": 12}
MESES_URL = ["janeiro", "fevereiro", "marco", "abril", "maio", "junho",
             "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]


def _ascii(s):
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()


def strip_html(html):
    html = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    html = re.sub(r"<[^>]+>", " ", html)
    html = html.replace("&nbsp;", " ").replace("&amp;", "&").replace("&quot;", '"')
    html = re.sub(r"&#\d+;|&[a-z]+;", " ", html)
    return re.sub(r"[ \t]+", " ", html).strip()


def article_body(html):
    m = re.search(r'<div id="content"[^>]*>(.*?)<footer', html, re.S)
    if not m:
        m = re.search(r"<article[^>]*>(.*?)</article>", html, re.S)
    return strip_html(m.group(1)) if m else strip_html(html)[:8000]


def pub_date(html, url):
    m = re.search(r'"datePublished"\s*:\s*"(\d{4}-\d{2}-\d{2})', html)
    if m:
        return m.group(1)
    m = re.search(r"Publicado em (\d{2})/(\d{2})/(\d{4})", html)
    if m:
        return f"{m.group(3)}-{m.group(2)}-{m.group(1)}"
    m = re.search(r"/noticias-e-conteudo/(\d{4})/([a-z]+)/", _ascii(url))
    if m and m.group(2) in MESES:
        return f"{m.group(1)}-{MESES[m.group(2)]:02d}-01"
    return None


ARTIGO_RE = re.compile(
    r'href="(https://www\.gov\.br/trabalho-e-emprego/pt-br/noticias-e-conteudo/20\d\d/[a-z]+/[^"#?]+)"')


def collect_urls(listing_url, paginas):
    urls = []
    for p in range(paginas):
        try:
            page = requests.get(f"{listing_url}?b_start:int={p*30}", headers=UA,
                                timeout=60).text
        except Exception:
            break
        found = ARTIGO_RE.findall(page)
        if not found:
            break
        urls.extend(found)
    return urls


def main(paginas: int = 3, anos: list = None):
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    urls = collect_urls(BASE, paginas)
    for ano in (anos or []):
        for mes in MESES_URL:
            urls.extend(collect_urls(f"{BASE}/{ano}/{mes}", paginas))
    urls = list(dict.fromkeys(urls))

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT url_hash FROM bronze.mte_noticias")
            seen = {r[0] for r in cur.fetchall()}
    finally:
        conn.close()

    lines = []
    stats = {"listadas": len(urls), "novas": 0, "relevantes": 0}
    for url in urls:
        h = hashlib.md5(url.encode()).hexdigest()
        if h in seen:
            continue
        stats["novas"] += 1
        try:
            html = requests.get(url, headers=UA, timeout=60).text
        except Exception:
            continue
        title_m = re.search(r"<h1[^>]*>(.*?)</h1>", html, re.S)
        titulo = strip_html(title_m.group(1)) if title_m else ""
        corpo = article_body(html)
        blob = f"{titulo}\n{corpo}"
        if not RELEVANTE.search(blob):
            continue
        stats["relevantes"] += 1
        tipo = next(t for t, rx in TIPOS if rx.search(blob))
        low = _ascii(blob)
        ufs = {sig for nome, sig in ESTADOS.items() if nome in low}
        ufs |= {s for s in UFS if re.search(r"\(%s\)" % s, blob)}
        obito = bool(re.search(r"morte|[oó]bito|morreu|faleceu", blob, re.I))
        data = pub_date(html, url) or "\\N"
        texto = corpo[:60000].replace(SEP, " ").replace(ROW, " ")
        lines.append(SEP.join([h, url, data, titulo, tipo,
                               ",".join(sorted(ufs)), "1" if obito else "0",
                               texto, agora]))

    if lines:
        cols = ["url_hash", "url", "data_publicacao", "titulo", "tipo_acao",
                "ufs", "cita_obito", "texto", "extraido_em"]
        headers = {
            "label": f"sst_mte_{uuid.uuid4().hex[:8]}",
            "column_separator": SEP,
            "row_delimiter": ROW,
            "columns": ",".join(cols),
            "max_filter_ratio": "0.01",
            "timeout": "600",
            "Expect": "100-continue",
        }
        payload = ROW.join(lines).encode("utf-8")
        r = requests.put(f"http://{sr['host']}:8030/api/bronze/mte_noticias/_stream_load",
                         data=payload, headers=headers,
                         auth=(sr["user"], sr["password"]),
                         allow_redirects=False, timeout=650)
        if r.status_code in (301, 302, 307, 308):
            r = requests.put(r.headers["Location"], data=payload, headers=headers,
                             auth=(sr["user"], sr["password"]), timeout=650)
        res = r.json()
        if res.get("Status") not in ("Success", "Publish Timeout"):
            raise Exception(f"stream load failed: {res}")
        stats["carregadas"] = res.get("NumberLoadedRows", 0)

    return stats
