import csv
import os
import re
import tempfile
import threading
import time
import unicodedata
import uuid
from datetime import datetime, timezone
from ftplib import FTP

import py7zr
import pymysql
import requests
import wmill

HOST = "ftp.mtps.gov.br"
CAMINHO = "/pdet/microdados/RAIS/{ano}/RAIS_ESTAB_PUB.7z"

COLUMNS = ["ano", "uf", "municipio_codigo", "cnae_subclasse", "cnae_classe",
           "vinculos_ativos", "estabelecimentos", "arquivo_origem", "carregado_em"]
SEP = "\x01"

ALIASES = {
    "municipio": ["municipio", "codigo municipio", "cod municipio"],
    "uf": ["uf", "sigla uf", "unidade da federacao"],
    "cnae_subclasse": ["cnae 20 subclasse", "cnae 2 0 subclasse", "subclasse",
                       "cnae20 subclasse"],
    "cnae_classe": ["cnae 20 classe", "cnae 2 0 classe", "classe", "cnae20 classe",
                    "cnae 95 classe"],
    "vinculos": ["qtd vinculos ativos", "vinculos ativos", "qt vinculos ativos"],
}


def norm(s):
    s = unicodedata.normalize("NFKD", str(s or "")).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9 ]", " ", s.lower()).strip()


def find_col(header_norm, key, obrigatorio=True):
    for alias in ALIASES[key]:
        if alias in header_norm:
            return header_norm.index(alias)
    for i, h in enumerate(header_norm):
        for alias in ALIASES[key]:
            if h.startswith(alias):
                return i
    if obrigatorio:
        raise Exception(f"coluna {key} nao encontrada. header={header_norm}")
    return None


class FatiaCompleta(Exception):
    """sinaliza que o segmento recebeu todos os bytes que lhe cabiam"""


def conectar():
    ftp = FTP(HOST, timeout=180)
    ftp.login()
    ftp.set_pasv(True)
    ftp.voidcmd("TYPE I")
    return ftp


def tamanho_remoto(caminho_remoto):
    ftp = conectar()
    try:
        return ftp.size(caminho_remoto)
    finally:
        try:
            ftp.quit()
        except Exception:
            ftp.close()


def baixar_fatia(caminho_remoto, parte, inicio, fim, tentativas, estado, indice):
    alvo = fim - inicio
    for _ in range(tentativas):
        ja = os.path.getsize(parte) if os.path.exists(parte) else 0
        if ja >= alvo:
            estado[indice] = ja
            return
        escrito = ja
        try:
            ftp = conectar()
            with open(parte, "ab" if ja else "wb") as f:
                def escreve(bloco):
                    nonlocal escrito
                    faltam = alvo - escrito
                    if len(bloco) >= faltam:
                        f.write(bloco[:faltam])
                        escrito += faltam
                        raise FatiaCompleta
                    f.write(bloco)
                    escrito += len(bloco)
                try:
                    ftp.retrbinary(f"RETR {caminho_remoto}", escreve,
                                   blocksize=1 << 20, rest=inicio + ja)
                except FatiaCompleta:
                    pass
            try:
                ftp.close()
            except Exception:
                pass
        except Exception:
            time.sleep(4)
        estado[indice] = os.path.getsize(parte) if os.path.exists(parte) else 0
        if estado[indice] >= alvo:
            return
    raise Exception(f"fatia {indice} incompleta: {estado[indice]} de {alvo} bytes")


def baixar_segmentado(caminho_remoto, destino, segmentos=4, tentativas=6):
    total = tamanho_remoto(caminho_remoto)
    if not total:
        raise Exception("servidor nao informou o tamanho do arquivo")
    limites = [(i * total // segmentos, (i + 1) * total // segmentos)
               for i in range(segmentos)]
    partes = [f"{destino}.p{i}" for i in range(segmentos)]
    estado = [0] * segmentos
    erros = []

    def alvo(i):
        try:
            baixar_fatia(caminho_remoto, partes[i], limites[i][0], limites[i][1],
                         tentativas, estado, i)
        except Exception as e:
            erros.append(str(e))

    threads = [threading.Thread(target=alvo, args=(i,)) for i in range(segmentos)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    if erros:
        raise Exception("; ".join(erros[:3]))

    with open(destino, "wb") as saida:
        for parte in partes:
            with open(parte, "rb") as p:
                while True:
                    bloco = p.read(8 << 20)
                    if not bloco:
                        break
                    saida.write(bloco)
            os.remove(parte)
    baixado = os.path.getsize(destino)
    if baixado != total:
        raise Exception(f"tamanho final {baixado} difere do esperado {total}")
    return baixado


def baixar_unico(caminho_remoto, destino, tentativas=10):
    esperado = tamanho_remoto(caminho_remoto)
    for _ in range(tentativas):
        parcial = os.path.getsize(destino) if os.path.exists(destino) else 0
        if esperado and parcial >= esperado:
            return parcial
        try:
            ftp = conectar()
            with open(destino, "ab" if parcial else "wb") as f:
                ftp.retrbinary(f"RETR {caminho_remoto}", f.write,
                               blocksize=1 << 20, rest=parcial or None)
            try:
                ftp.quit()
            except Exception:
                ftp.close()
        except Exception:
            time.sleep(5)
    parcial = os.path.getsize(destino) if os.path.exists(destino) else 0
    if esperado and parcial >= esperado:
        return parcial
    raise Exception(f"download incompleto: {parcial} de {esperado} bytes")


def main(ano: str, segmentos: int = 4):
    sr = wmill.get_resource("f/infra/starrocks")
    remoto = CAMINHO.format(ano=ano)
    arquivo = f"RAIS_ESTAB_PUB_{ano}.7z"
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    agg = {}
    total_linhas = 0
    descartadas = 0
    with tempfile.TemporaryDirectory() as td:
        seven = os.path.join(td, "estab.7z")
        inicio = time.time()
        try:
            bytes_baixados = baixar_segmentado(remoto, seven, segmentos=segmentos)
            modo = f"segmentado x{segmentos}"
        except Exception as e:
            for resto in os.listdir(td):
                os.remove(os.path.join(td, resto))
            bytes_baixados = baixar_unico(remoto, seven)
            modo = f"unico (segmentado falhou: {str(e)[:120]})"
        segundos_download = round(time.time() - inicio, 1)

        with py7zr.SevenZipFile(seven) as z:
            # o membro nao tem extensao convencional (vem como .COMT), entao
            # pegamos o maior arquivo do pacote em vez de filtrar por nome
            infos = [i for i in z.list() if not i.is_directory]
            if not infos:
                raise Exception("pacote 7z vazio")
            membro = max(infos, key=lambda i: i.uncompressed or 0).filename
            z.extractall(td)
        os.remove(seven)
        caminho = os.path.join(td, membro)

        with open(caminho, "r", encoding="latin-1", errors="replace",
                  newline="") as f:
            primeira = f.readline().rstrip("\r\n")
            # a RAIS nao usa ponto e virgula como as demais fontes e traz os
            # campos entre aspas, entao detectamos o separador e lemos com csv
            try:
                delim = csv.Sniffer().sniff(primeira,
                                            delimiters=";,\t|").delimiter
            except Exception:
                delim = max([";", "\t", "|", ","],
                            key=lambda s: primeira.count(s))
            header = next(csv.reader([primeira], delimiter=delim,
                                     quotechar='"'))
            hn = [norm(h) for h in header]
            i_mun = find_col(hn, "municipio")
            i_uf = find_col(hn, "uf")
            i_sub = find_col(hn, "cnae_subclasse", obrigatorio=False)
            i_cls = find_col(hn, "cnae_classe", obrigatorio=False)
            i_vin = find_col(hn, "vinculos")
            if i_sub is None and i_cls is None:
                raise Exception(f"nenhuma coluna de CNAE. header={hn}")
            ncols = len(header)
            for p in csv.reader(f, delimiter=delim, quotechar='"'):
                if len(p) != ncols:
                    descartadas += 1
                    continue
                total_linhas += 1
                mun = p[i_mun].strip().strip('"')
                uf = p[i_uf].strip().strip('"')
                sub = p[i_sub].strip().strip('"') if i_sub is not None else ""
                cls = p[i_cls].strip().strip('"') if i_cls is not None else ""
                try:
                    v = int(float(p[i_vin].strip().strip('"').replace(",", ".")))
                except ValueError:
                    v = 0
                key = (uf, mun, sub, cls)
                a = agg.get(key)
                if a is None:
                    a = agg[key] = [0, 0]
                a[0] += v
                a[1] += 1

    if not agg:
        raise Exception(f"nada agregado de {arquivo}")

    lines = [SEP.join([str(ano), uf, mun, sub, cls, str(vin), str(est), arquivo, agora])
             for (uf, mun, sub, cls), (vin, est) in agg.items()]

    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.rais_estoque WHERE ano = %s", (int(ano),))
        conn.commit()
    finally:
        conn.close()

    payload = ("\n".join(lines)).encode("utf-8")
    headers = {
        "label": f"sst_rais_{ano}_{uuid.uuid4().hex[:8]}",
        "column_separator": SEP,
        "columns": ",".join(COLUMNS),
        "max_filter_ratio": "0.001",
        "timeout": "1800",
        "Expect": "100-continue",
    }
    r = requests.put(f"http://{sr['host']}:8030/api/bronze/rais_estoque/_stream_load",
                     data=payload, headers=headers,
                     auth=(sr["user"], sr["password"]),
                     allow_redirects=False, timeout=1900)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers,
                         auth=(sr["user"], sr["password"]), timeout=1900)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load falhou: {res}")

    return {"ano": ano, "modo_download": modo, "membro": membro,
            "mb": round(bytes_baixados / 1e6, 1),
            "segundos_download": segundos_download,
            "estabelecimentos_lidos": total_linhas,
            "linhas_descartadas": descartadas, "grupos": len(lines),
            "linhas_carregadas": res.get("NumberLoadedRows", 0)}
