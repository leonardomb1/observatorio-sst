import io
import re
import unicodedata
import uuid
import zipfile
from datetime import datetime, timezone

import openpyxl
import pymysql
import requests
import wmill

COLUMNS = [
    "periodo", "competencia", "especie_codigo", "especie", "cid_codigo",
    "cid_descricao", "despacho_codigo", "despacho", "dt_nascimento", "sexo",
    "clientela", "municipio_residencia", "vinculo_dependentes",
    "forma_filiacao", "uf", "qt_sm_rmi", "ramo_atividade", "dt_dcb",
    "dt_ddb", "dt_dib", "cnae_codigo", "cnae_descricao", "grau_instrucao",
    "qt_anos_contribuicao", "arquivo_origem", "carregado_em",
]
DATA_COLS = COLUMNS[1:-2]

COLUMNS_INCAP = [
    "periodo", "competencia", "especie_codigo", "especie", "cid_codigo", "uf",
    "sexo", "cnae_codigo", "concessoes", "soma_qt_sm_rmi", "arquivo_origem",
    "carregado_em",
]
CHAVE_INCAP = ["competencia", "especie_codigo", "especie", "cid_codigo", "uf",
               "sexo", "cnae_codigo"]
ESPECIES_INCAPACIDADE = ("incapac", "doenca", "invalidez", "acident")

SEP = "\x01"

HEADER_MAP = {
    "competencia concessao": ("competencia", None),
    "especie": ("especie", "especie"),
    "cid": ("cid_codigo", "cid_descricao"),
    "despacho": ("despacho", "despacho"),
    "dt nascimento": ("dt_nascimento", None),
    "sexo": ("sexo", None),
    "clientela": ("clientela", None),
    "mun resid": ("municipio_residencia", None),
    "vinculo dependentes": ("vinculo_dependentes", None),
    "forma filiacao": ("forma_filiacao", None),
    "uf": ("uf", None),
    "qt sm rmi": ("qt_sm_rmi", None),
    "ramo atividade": ("ramo_atividade", None),
    "dt dcb": ("dt_dcb", None),
    "dt ddb": ("dt_ddb", None),
    "dt dib": ("dt_dib", None),
    "cnae 20": ("cnae_codigo", "cnae_descricao"),
    "grau instrucao": ("grau_instrucao", None),
    "qt anos contribuicao": ("qt_anos_contribuicao", None),
    "especie codigo": ("especie_codigo", None),
    "especie nome": ("especie", None),
    "cid 10 codigo": ("cid_codigo", None),
    "cid 10 nome": ("cid_descricao", None),
    "despacho codigo": ("despacho_codigo", None),
    "despacho nome": ("despacho", None),
    "data nascimento titular": ("dt_nascimento", None),
    "sexo titular nome": ("sexo", None),
    "clientela nome": ("clientela", None),
    "municipio resid titular codigo e nome": ("municipio_residencia", None),
    "vinculo dependente recebedor nome": ("vinculo_dependentes", None),
    "forma filiacao nome": ("forma_filiacao", None),
    "uf nome": ("uf", None),
    "quantidade salarios minimos rmi": ("qt_sm_rmi", None),
    "ramo atividade nome": ("ramo_atividade", None),
    "dcb data cessacao beneficio": ("dt_dcb", None),
    "ddb data despacho beneficio": ("dt_ddb", None),
    "dib data inicio beneficio": ("dt_dib", None),
    "grau instrucao nome": ("grau_instrucao", None),
}


def norm(s) -> str:
    # strip dedup suffixes some files add to repeated headers (CID_1, Sexo._1)
    s = re.sub(r"_\d+$", "", str(s or "").strip())
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", "", s.lower())).strip()


def build_mapping(header):
    normed = [norm(h) for h in header]
    counts = {}
    for h in normed:
        counts[h] = counts.get(h, 0) + 1
    mapping = {}
    seen = {}
    desconhecidas = []
    for i, h in enumerate(normed):
        if not h:
            continue
        if h not in HEADER_MAP:
            # the file layout gains and loses columns across years; keep what we
            # know and record the rest instead of failing the whole period
            desconhecidas.append((i, header[i]))
            continue
        occ = seen.get(h, 0)
        seen[h] = occ + 1
        first, second = HEADER_MAP[h]
        if counts[h] == 1:
            canon = first if h not in ("especie", "despacho") else \
                ("especie" if h == "especie" else "despacho")
        else:
            if h in ("especie", "despacho"):
                canon = (h + "_codigo") if occ == 0 else h
            else:
                canon = first if occ == 0 else second
        if canon:
            mapping[canon] = i
    # source corruption: 2020-02 replaces the competencia header with junk text
    if "competencia" not in mapping and len(desconhecidas) == 1:
        mapping["competencia"] = desconhecidas[0][0]
        desconhecidas = []
    if "especie" not in mapping or "competencia" not in mapping:
        raise Exception(f"missing key columns in header: {header}")
    return mapping, [nome for _, nome in desconhecidas]


def fmt(v):
    if v is None:
        return ""
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d")
    return str(v).strip()


def rmi(texto):
    """A renda mensal inicial vem com virgula decimal nos CSV e como numero
    nas planilhas; o que nao for numero fica fora da soma, nao vira zero."""
    try:
        return float(texto.replace(",", "."))
    except ValueError:
        return None


def rows_from_csv_text(text):
    lines = text.splitlines()
    header = None
    start = 0
    for i, line in enumerate(lines[:5]):
        n = norm(line)
        if "compet" in n or ("especie" in n and "cid" in n):
            header = line.split(";")
            start = i + 1
            break
    if header is None:
        raise Exception(f"no header row found: {lines[:2]}")
    for line in lines[start:]:
        if line:
            yield header, line.split(";")


def rows_from_xlsx(data):
    wb = openpyxl.load_workbook(io.BytesIO(data), read_only=True)
    ws = wb[wb.sheetnames[0]]
    header = None
    for row in ws.iter_rows(values_only=True):
        vals = [fmt(c) for c in row]
        if header is None:
            joined = norm(" ".join(vals))
            if "compet" in joined or ("especie" in joined and "cid" in joined):
                header = vals
            continue
        yield header, vals


def stream_load(sr, tabela, colunas, linhas, label):
    payload = ("\n".join(linhas)).encode("utf-8")
    headers = {
        "label": label,
        "column_separator": SEP,
        "columns": ",".join(colunas),
        "max_filter_ratio": "0.001",
        "timeout": "1800",
        "Expect": "100-continue",
    }
    r = requests.put(f"http://{sr['host']}:8030/api/bronze/{tabela}/_stream_load",
                     data=payload, headers=headers,
                     auth=(sr["user"], sr["password"]),
                     allow_redirects=False, timeout=1900)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers,
                         auth=(sr["user"], sr["password"]), timeout=1900)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {label} failed: {res}")
    return res.get("NumberLoadedRows", 0)


def main(periodo: str, url: str):
    sr = wmill.get_resource("f/infra/starrocks")
    arquivo = url.split("/")[-1]
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    data = requests.get(url, timeout=1800).content
    low = arquivo.lower()
    if low.endswith(".zip"):
        zf = zipfile.ZipFile(io.BytesIO(data))
        members = [m for m in zf.namelist() if m.lower().endswith((".csv", ".xlsx"))]
        if len(members) != 1:
            raise Exception(f"expected 1 member, found {zf.namelist()}")
        inner = members[0]
        data = zf.read(inner)
        low = inner.lower()

    if low.endswith(".xlsx"):
        row_iter = rows_from_xlsx(data)
    else:
        if data[:3] == b"\xef\xbb\xbf":
            text = data.decode("utf-8-sig", errors="replace")
        else:
            text = data.decode("latin-1")
        row_iter = rows_from_csv_text(text)
    del data

    mapping = None
    desconhecidas = []
    lines = []
    incap = {}
    total = 0
    kept = 0
    for header, fields in row_iter:
        if mapping is None:
            mapping, desconhecidas = build_mapping(header)
            esp_idx = mapping["especie"]
        total += 1
        if esp_idx >= len(fields):
            continue
        especie = norm(fields[esp_idx])
        if not any(k in especie for k in ESPECIES_INCAPACIDADE):
            continue
        valores = {}
        for col in DATA_COLS:
            idx = mapping.get(col)
            valores[col] = fmt(fields[idx]) if idx is not None and idx < len(fields) else ""

        chave = tuple(valores[c] for c in CHAVE_INCAP)
        acumulado = incap.setdefault(chave, [0, 0.0])
        acumulado[0] += 1
        v = rmi(valores["qt_sm_rmi"])
        if v is not None:
            acumulado[1] += v

        if "acident" not in especie:
            continue
        kept += 1
        lines.append(SEP.join([periodo] + [valores[c] for c in DATA_COLS]
                              + [arquivo, agora]))

    if total == 0 or mapping is None:
        raise Exception(f"no data rows parsed from {arquivo}")

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.inss_beneficios WHERE periodo = %s",
                        (periodo,))
            cur.execute("DELETE FROM bronze.inss_incapacidade WHERE periodo = %s",
                        (periodo,))
        conn.commit()
    finally:
        conn.close()

    sufixo = f"{periodo}_{uuid.uuid4().hex[:8]}"
    carregadas = stream_load(sr, "inss_beneficios", COLUMNS, lines, f"sst_ben_{sufixo}")
    linhas_incap = [SEP.join([periodo] + list(k) + [str(n), repr(s), arquivo, agora])
                    for k, (n, s) in incap.items()]
    carregadas_incap = stream_load(sr, "inss_incapacidade", COLUMNS_INCAP,
                                   linhas_incap, f"sst_incap_{sufixo}")

    return {"periodo": periodo, "arquivo": arquivo, "linhas_arquivo": total,
            "linhas_acidentarias": kept,
            "linhas_carregadas": carregadas,
            "concessoes_incapacidade": sum(n for n, _ in incap.values()),
            "grupos_incapacidade": carregadas_incap,
            "colunas_ignoradas": desconhecidas}
