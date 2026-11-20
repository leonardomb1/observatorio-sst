import io
import re
import uuid
from datetime import datetime, timezone

import pymysql
import requests
import wmill
from pypdf import PdfReader

URL = ("https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/inspecao-do-trabalho/"
       "areas-de-atuacao/documentos-pdf/cadastro_de_empregadores.pdf")
LINHA = re.compile(r"^\s{0,6}(\d{1,4})\s+(?:(20\d{2})\s+)?(?:([A-Z]{2})\s+)?(.*)$")
DOCUMENTO = re.compile(r"\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}|\d{3}\.\d{3}\.\d{3}-\d{2}")
CNAE = re.compile(r"(\d+)\s+(\d{4}-\d/\d{2})")
DATA = re.compile(r"\d{2}/\d{2}/\d{4}")
ATUALIZADO = re.compile(r"[Cc]adastro atualizado em (\d{2}/\d{2}/\d{4})")
JUDICIAL = re.compile(r"\(\*\d\)")
UFS = {"AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG",
       "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO"}
COLUMNS = ["atualizado_em", "registro", "ano_acao_fiscal", "uf", "tipo_documento",
           "trabalhadores", "cnae", "data_decisao", "data_inclusao", "inclusao_judicial",
           "arquivo_origem", "carregado_em"]
SEP = "\x01"


def iso(data):
    return datetime.strptime(data, "%d/%m/%Y").strftime("%Y-%m-%d") if data else None


def registros(texto):
    """A linha que abre cada registro traz o numero de ordem e, na mesma
    linha, o documento, os trabalhadores, a CNAE e as duas datas, mesmo
    quando nome e endereco quebram em varias linhas. O numero de
    trabalhadores e o inteiro que antecede a CNAE; nos incluidos por sentenca
    a fonte omite CNAE e datas, e ele e o primeiro inteiro apos o documento."""
    saida, vistos = [], set()
    for linha in texto.splitlines():
        m = LINHA.match(linha)
        if not m:
            continue
        resto = m.group(4)
        doc = DOCUMENTO.search(resto)
        if not doc or int(m.group(1)) in vistos:
            continue
        vistos.add(int(m.group(1)))
        cnae = CNAE.search(resto)
        if cnae:
            trabalhadores = int(cnae.group(1))
        else:
            depois = re.findall(r"(?<!\S)(\d{1,4})(?!\S)", resto[doc.end():])
            trabalhadores = int(depois[0]) if depois else None
        datas = DATA.findall(resto)
        saida.append([
            int(m.group(1)),
            int(m.group(2)) if m.group(2) else None,
            m.group(3) if m.group(3) in UFS else None,
            "CNPJ" if "/" in doc.group(0) else "CPF",
            trabalhadores,
            cnae.group(2) if cnae else None,
            iso(datas[-2]) if len(datas) >= 2 else None,
            iso(datas[-1]) if datas else None,
            bool(JUDICIAL.search(resto)),
        ])
    return saida


def main():
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    r = requests.get(URL, timeout=300, headers={"User-Agent": "Mozilla/5.0"})
    r.raise_for_status()
    leitor = PdfReader(io.BytesIO(r.content))
    texto = "\n".join(p.extract_text(extraction_mode="layout") for p in leitor.pages)

    m = ATUALIZADO.search(texto)
    if not m:
        raise Exception("data de atualizacao do cadastro nao encontrada no PDF")
    atualizado_em = iso(m.group(1))
    regs = registros(texto)
    maior = max(r[0] for r in regs) if regs else 0
    faltando = sorted(set(range(1, maior + 1)) - {r[0] for r in regs})
    if not regs or faltando:
        raise Exception(f"leitura incompleta: {len(regs)} registros, faltando {faltando[:20]}")

    linhas = [SEP.join("\\N" if v is None else str(v).lower() if isinstance(v, bool) else str(v)
                       for v in [atualizado_em] + reg + ["cadastro_de_empregadores.pdf", agora])
              for reg in regs]
    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.mte_cadastro_empregadores WHERE atualizado_em = %s",
                        (atualizado_em,))
        conn.commit()
    finally:
        conn.close()

    payload = "\n".join(linhas).encode("utf-8")
    headers = {"label": f"sst_cadastro_{uuid.uuid4().hex[:8]}", "column_separator": SEP,
               "columns": ",".join(COLUMNS), "max_filter_ratio": "0", "timeout": "600",
               "Expect": "100-continue"}
    auth = (sr["user"], sr["password"])
    s = requests.put(f"http://{sr['host']}:8030/api/bronze/mte_cadastro_empregadores/_stream_load",
                     data=payload, headers=headers, auth=auth, allow_redirects=False, timeout=650)
    if s.status_code in (301, 302, 307, 308):
        s = requests.put(s.headers["Location"], data=payload, headers=headers, auth=auth,
                         timeout=650)
    res = s.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load falhou: {res}")
    return {"atualizado_em": atualizado_em, "registros": len(regs),
            "trabalhadores": sum(r[4] or 0 for r in regs),
            "sem_uf": sum(1 for r in regs if r[2] is None),
            "linhas_carregadas": res.get("NumberLoadedRows", 0)}
