import os
import re
import tempfile
import uuid
import zipfile
from datetime import datetime, timezone

import pymysql
import requests
import wmill

# canonical column order of bronze.cat (periodo first, metadata last)
COLUMNS = [
    "periodo", "agente_causador", "competencia", "cbo_codigo", "cbo_descricao",
    "cid10_codigo", "cid10_descricao", "cnae_codigo", "cnae_descricao",
    "emitente_cat", "especie_beneficio", "filiacao_segurado", "indica_obito",
    "municipio_empregador", "natureza_lesao", "origem_cadastramento",
    "parte_corpo", "sexo", "tipo_acidente", "uf_acidente", "uf_empregador",
    "data_afastamento", "data_despacho_beneficio", "data_acidente",
    "data_nascimento", "data_emissao_cat", "tipo_empregador",
    "cnpj_cei_empregador", "arquivo_origem", "carregado_em",
]

SEP = "\x01"

CANON = ["agente_causador", "competencia", "cbo_codigo", "cbo_descricao",
         "cid10_codigo", "cid10_descricao", "cnae_codigo", "cnae_descricao",
         "emitente_cat", "especie_beneficio", "filiacao_segurado",
         "indica_obito", "municipio_empregador", "natureza_lesao",
         "origem_cadastramento", "parte_corpo", "sexo", "tipo_acidente",
         "uf_acidente", "uf_empregador", "data_afastamento",
         "data_despacho_beneficio", "data_acidente", "data_nascimento",
         "data_emissao_cat", "tipo_empregador", "cnpj_cei_empregador"]

GEN_A = {  # 25 cols, 2018Q4-2020Q4: code/label split, no tipo_empregador/cnpj
    "agente_causador": 0, "competencia": 1, "cbo_codigo": 2, "cbo_descricao": 3,
    "cid10_codigo": 4, "cid10_descricao": 5, "cnae_codigo": 6, "cnae_descricao": 7,
    "emitente_cat": 8, "especie_beneficio": 9, "filiacao_segurado": 10,
    "indica_obito": 11, "municipio_empregador": 12, "natureza_lesao": 13,
    "origem_cadastramento": 14, "parte_corpo": 15, "sexo": 16,
    "tipo_acidente": 17, "uf_acidente": 18, "uf_empregador": 19,
    "data_afastamento": 20, "data_despacho_beneficio": 21, "data_acidente": 22,
    "data_nascimento": 23, "data_emissao_cat": 24,
}

GEN_B = {  # 24 cols, 2021-mai/2023: cbo and cid merged code+label, no afastamento/tipo_empregador
    "agente_causador": 0, "competencia": 1,
    "cnae_codigo": 4, "cnae_descricao": 5, "emitente_cat": 6,
    "especie_beneficio": 7, "filiacao_segurado": 8, "indica_obito": 9,
    "municipio_empregador": 10, "natureza_lesao": 11,
    "origem_cadastramento": 12, "parte_corpo": 13, "sexo": 14,
    "tipo_acidente": 15, "uf_acidente": 16, "uf_empregador": 17,
    "data_despacho_beneficio": 19, "data_acidente": 20, "data_nascimento": 21,
    "data_emissao_cat": 22, "cnpj_cei_empregador": 23,
}

GEN_C = {  # 27 cols, later PDA era: like GEN_A plus tipo_empregador and cnpj
    "agente_causador": 0, "competencia": 1, "cbo_codigo": 2, "cbo_descricao": 3,
    "cid10_codigo": 4, "cid10_descricao": 5, "cnae_codigo": 6, "cnae_descricao": 7,
    "emitente_cat": 8, "especie_beneficio": 9, "filiacao_segurado": 10,
    "indica_obito": 11, "municipio_empregador": 12, "natureza_lesao": 13,
    "origem_cadastramento": 14, "parte_corpo": 15, "sexo": 16,
    "tipo_acidente": 17, "uf_acidente": 18, "uf_empregador": 19,
    "data_afastamento": 20, "data_despacho_beneficio": 21, "data_acidente": 22,
    "data_nascimento": 23, "data_emissao_cat": 24, "tipo_empregador": 25,
    "cnpj_cei_empregador": 26,
}

GEN_D = {  # 24 cols, jun/2023+: split code/label, Data Afastamento, no despacho/cnpj;
    # last column's header says 'Data Acidente' but holds the CAT emission date
    "agente_causador": 0, "competencia": 1, "cbo_codigo": 2, "cbo_descricao": 3,
    "cid10_codigo": 4, "cid10_descricao": 5, "cnae_codigo": 6, "cnae_descricao": 7,
    "emitente_cat": 8, "especie_beneficio": 9, "filiacao_segurado": 10,
    "indica_obito": 11, "municipio_empregador": 12, "natureza_lesao": 13,
    "origem_cadastramento": 14, "parte_corpo": 15, "sexo": 16,
    "tipo_acidente": 17, "uf_acidente": 18, "uf_empregador": 19,
    "data_afastamento": 20, "data_acidente": 21, "data_nascimento": 22,
    "data_emissao_cat": 23,
}


def detect_generation(header_fields):
    n = len(header_fields)
    # some files dedupe repeated header names as 'CBO_1', 'CID-10_2': strip the suffix
    h = [re.sub(r"_\d+$", "", f.strip()) for f in header_fields]
    if n == 25 and h[2] == "CBO" and h[3] == "CBO":
        return "A", GEN_A
    if n == 24 and h[2] == "CBO" and h[3] == "CID-10":
        return "B", GEN_B
    if n == 24 and h[2] == "CBO" and h[3] == "CBO":
        return "D", GEN_D
    if n == 27 and h[2] == "CBO" and h[3] == "CBO":
        return "C", GEN_C
    raise Exception(f"unknown CAT layout: {n} columns, header={h[:6]}...")


def split_merged(value: str, sep: str):
    # '324115-Desc' -> ('324115', 'Desc'); 'S52.6 Desc' -> ('S52.6', 'Desc')
    v = value.strip()
    if sep == "-" and "-" in v:
        code, _, desc = v.partition("-")
        return code.strip(), desc.strip()
    if sep == " " and " " in v:
        code, _, desc = v.partition(" ")
        return code.strip(), desc.strip()
    return v, ""


def normalize_row(fields, gen, mapping, periodo, arquivo, agora):
    out = [periodo]
    if gen == "B":
        cbo_cod, cbo_desc = split_merged(fields[2], "-")
        cid_cod, cid_desc = split_merged(fields[3], " ")
        extra = {"cbo_codigo": cbo_cod, "cbo_descricao": cbo_desc,
                 "cid10_codigo": cid_cod, "cid10_descricao": cid_desc}
    else:
        extra = {}
    for col in CANON:
        if col in extra:
            out.append(extra[col])
        else:
            idx = mapping.get(col)
            out.append(fields[idx].strip() if idx is not None else "")
    out.append(arquivo)
    out.append(agora)
    return out


def stream_load(sr, payload: bytes, label: str):
    url = f"http://{sr['host']}:8030/api/bronze/cat/_stream_load"
    headers = {
        "label": label,
        "column_separator": SEP,
        "columns": ",".join(COLUMNS),
        "max_filter_ratio": "0.001",
        "timeout": "1800",
        "Expect": "100-continue",
    }
    auth = (sr["user"], sr["password"])
    r = requests.put(url, data=payload, headers=headers, auth=auth,
                     allow_redirects=False, timeout=1900)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers,
                         auth=auth, timeout=1900)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {label} failed: {res}")
    return res


def main(periodo: str, url: str):
    sr = wmill.get_resource("f/infra/starrocks")
    arquivo = url.split("/")[-1]
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    with tempfile.TemporaryDirectory() as tmpdir:
        fpath = os.path.join(tmpdir, "cat_download")
        with requests.get(url, stream=True, timeout=1800) as r:
            r.raise_for_status()
            with open(fpath, "wb") as f:
                for block in r.iter_content(8 * 1024 * 1024):
                    f.write(block)

        if arquivo.lower().endswith(".zip"):
            zf = zipfile.ZipFile(fpath)
            members = [m for m in zf.namelist() if m.lower().endswith(".csv")]
            if len(members) != 1:
                raise Exception(f"expected 1 csv in zip, found {members}")
            data = zf.read(members[0])
        else:
            with open(fpath, "rb") as f:
                data = f.read()

    # most files are latin-1; the 2020 quarterlies are UTF-8 with BOM
    if data[:3] == b"\xef\xbb\xbf":
        text = data.decode("utf-8-sig", errors="replace")
    else:
        text = data.decode("latin-1")
    del data

    rows = text.splitlines()
    header = rows[0].split(";")
    gen, mapping = detect_generation(header)
    ncols = len(header)

    lines = []
    bad = 0
    total = 0
    for line in rows[1:]:
        if not line:
            continue
        fields = line.split(";")
        total += 1
        if len(fields) != ncols:
            bad += 1
            continue
        lines.append(SEP.join(normalize_row(fields, gen, mapping,
                                            periodo, arquivo, agora)))

    if bad > total * 0.001:
        raise Exception(f"{bad}/{total} malformed rows in {arquivo}, aborting")

    payload = ("\n".join(lines)).encode("utf-8")

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.cat WHERE periodo = %s", (periodo,))
        conn.commit()
    finally:
        conn.close()

    label = f"sst_cat_{periodo}_{uuid.uuid4().hex[:8]}"
    res = stream_load(sr, payload, label)

    return {
        "periodo": periodo,
        "arquivo": arquivo,
        "geracao": gen,
        "linhas_arquivo": total,
        "linhas_invalidas": bad,
        "linhas_carregadas": res.get("NumberLoadedRows", 0),
    }
