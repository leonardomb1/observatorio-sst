import csv
import html
import io
import re
import uuid
import zipfile
from datetime import datetime, timezone
from typing import List, Optional

import pymysql
import requests
import wmill

PAGINA = "https://www.gov.br/prf/pt-br/acesso-a-informacao/dados-abertos/dados-abertos-da-prf"
DRIVE = "https://drive.usercontent.google.com/download?id={id}&export=download&confirm=t"
ROTULO = re.compile(r"Documento CSV de Acidentes (\d{4}) \(Agrupados por pessoa\)\s*$")
CAMPOS = ["id", "pesid", "data_inversa", "dia_semana", "horario", "uf", "br", "km",
          "municipio", "causa_acidente", "tipo_acidente", "classificacao_acidente",
          "fase_dia", "condicao_metereologica", "tipo_pista", "id_veiculo",
          "tipo_veiculo", "ano_fabricacao_veiculo", "tipo_envolvido",
          "estado_fisico", "idade", "sexo", "mortos", "feridos_graves",
          "latitude", "longitude"]
COLUMNS = ["ano", "acidente_id", "pessoa_id", "data_inversa", "dia_semana", "horario",
           "uf", "br", "km", "municipio", "causa_acidente", "tipo_acidente",
           "classificacao_acidente", "fase_dia", "condicao_metereologica", "tipo_pista",
           "veiculo_id", "tipo_veiculo", "ano_fabricacao_veiculo", "tipo_envolvido",
           "estado_fisico", "idade", "sexo", "mortos", "feridos_graves", "latitude",
           "longitude", "arquivo_origem", "carregado_em"]
SEP = "\x01"
ANO_INICIAL = 2018


def arquivos_publicados():
    """Cada link 'Baixar planilha' vem logo depois do rotulo do seu arquivo;
    o rotulo por pessoa sem o sufixo 'Todas as causas' e o que interessa."""
    pagina = requests.get(PAGINA, timeout=120, headers={"User-Agent": "Mozilla/5.0"}).text
    anos, fim_anterior = {}, 0
    for m in re.finditer(r'<a[^>]+href="https://drive\.google\.com/file/d/([^/"]+)[^"]*"[^>]*>(.*?)</a>',
                         pagina, re.S):
        texto = re.sub(r"<[^>]+>", "", m.group(2))
        if "Baixar" not in texto:
            continue
        antes = html.unescape(re.sub(r"<[^>]+>", " ", pagina[fim_anterior:m.start()]))
        antes = " ".join(antes.split())
        r = ROTULO.search(antes)
        if r:
            anos.setdefault(int(r.group(1)), m.group(1))
        fim_anterior = m.end()
    return anos


def stream_load(sr, payload: bytes, label: str):
    url = f"http://{sr['host']}:8030/api/bronze/prf_envolvidos/_stream_load"
    headers = {
        "label": label,
        "column_separator": SEP,
        "columns": ",".join(COLUMNS),
        "max_filter_ratio": "0.001",
        "timeout": "1200",
        "Expect": "100-continue",
    }
    auth = (sr["user"], sr["password"])
    r = requests.put(url, data=payload, headers=headers, auth=auth,
                     allow_redirects=False, timeout=1300)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers,
                         auth=auth, timeout=1300)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {label} failed: {res}")
    return res.get("NumberLoadedRows", 0)


def carrega_ano(sr, ano, drive_id, agora):
    pacote = requests.get(DRIVE.format(id=drive_id), timeout=1800)
    pacote.raise_for_status()
    z = zipfile.ZipFile(io.BytesIO(pacote.content))
    membro = [n for n in z.namelist() if n.lower().endswith(".csv")]
    if len(membro) != 1:
        raise Exception(f"{ano}: esperado 1 csv, encontrado {z.namelist()}")
    bruto = z.read(membro[0])
    try:
        texto = bruto.decode("utf-8")
    except UnicodeDecodeError:
        texto = bruto.decode("latin-1")
    leitor = csv.reader(io.StringIO(texto), delimiter=";")
    cabecalho = [c.strip().lower() for c in next(leitor)]
    faltando = [c for c in CAMPOS if c not in cabecalho]
    if faltando:
        raise Exception(f"{ano}: colunas ausentes {faltando}")
    pos = [cabecalho.index(c) for c in CAMPOS]

    linhas = []
    for campos in leitor:
        if not campos:
            continue
        valores = [campos[p].strip().replace(SEP, " ") if p < len(campos) else "" for p in pos]
        linhas.append(SEP.join([str(ano)] + valores + [membro[0], agora]))
    if not linhas:
        raise Exception(f"{ano}: nenhuma linha lida")

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.prf_envolvidos WHERE ano = %s", (ano,))
        conn.commit()
    finally:
        conn.close()
    carregadas = stream_load(sr, "\n".join(linhas).encode("utf-8"),
                             f"sst_prf_{ano}_{uuid.uuid4().hex[:8]}")
    return {"ano": ano, "linhas": len(linhas), "linhas_carregadas": carregadas}


def main(anos: Optional[List[int]] = None):
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    publicados = arquivos_publicados()
    if not publicados:
        raise Exception(f"nenhum arquivo por pessoa encontrado em {PAGINA}")
    if not anos:
        anos = sorted(a for a in publicados if a >= ANO_INICIAL)[-2:]
    ausentes = [a for a in anos if a not in publicados]
    if ausentes:
        raise Exception(f"anos nao publicados: {ausentes}; disponiveis: {sorted(publicados)}")
    return [carrega_ano(sr, a, publicados[a], agora) for a in sorted(anos)]
