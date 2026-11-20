#extra_requirements:
#datasus-dbc
#dbfread

import base64
import ftplib
import json
import os
import re
import socket
import tempfile
import uuid
from datetime import date, datetime, timezone
from typing import List, Optional
from urllib.parse import urlparse

import pymysql
import requests
import wmill
from datasus_dbc import decompress
from dbfread import DBF

HOST = "ftp.datasus.gov.br"
PASTAS = [("FINAIS", "/dissemin/publicos/SINAN/DADOS/FINAIS"),
          ("PRELIM", "/dissemin/publicos/SINAN/DADOS/PRELIM")]
AGRAVOS = ["ACGR", "ACBI", "LERD", "MENT", "PAIR", "PNEU", "DERM", "CANC", "IEXO"]
ANO_INICIAL = 2018
COLUMNS = ["agravo", "ano", "situacao_dados", "registro", "arquivo_origem", "carregado_em"]
SEP = "\x01"


def tunel(proxy, host, porta, timeout=120):
    """Abre um socket TCP ate host:porta atraves de um proxy HTTP CONNECT."""
    p = urlparse(proxy)
    s = socket.create_connection((p.hostname, p.port), timeout=timeout)
    pedido = f"CONNECT {host}:{porta} HTTP/1.1\r\nHost: {host}:{porta}\r\n"
    if p.username:
        cred = base64.b64encode(f"{p.username}:{p.password}".encode()).decode()
        pedido += f"Proxy-Authorization: Basic {cred}\r\n"
    s.sendall((pedido + "\r\n").encode())
    resposta = b""
    while b"\r\n\r\n" not in resposta:
        bloco = s.recv(4096)
        if not bloco:
            break
        resposta += bloco
    status = resposta.split(b"\r\n", 1)[0].decode(errors="replace")
    if " 200 " not in status + " ":
        s.close()
        raise ConnectionError(f"proxy recusou CONNECT {host}:{porta}: {status}")
    return s


class FTPPeloProxy(ftplib.FTP):
    """FTP passivo em que o controle e cada conexao de dados passam pelo
    tunel CONNECT do proxy; o endereco anunciado no PASV e ignorado, como o
    ftplib ja faz por padrao, e o host do controle e reutilizado."""

    def __init__(self, proxy):
        super().__init__()
        self.proxy = proxy

    def connect(self, host="", port=0, timeout=-999, source_address=None):
        self.host, self.port = host, port or 21
        self.sock = tunel(self.proxy, self.host, self.port)
        self.af = socket.AF_INET
        self.file = self.sock.makefile("r", encoding=self.encoding)
        self.welcome = self.getresp()
        return self.welcome

    def ntransfercmd(self, cmd, rest=None):
        _, porta = self.makepasv()
        conn = tunel(self.proxy, self.host, porta)
        if rest is not None:
            self.sendcmd(f"REST {rest}")
        resp = self.sendcmd(cmd)
        if resp[0] == "2":
            resp = self.getresp()
        if resp[0] != "1":
            conn.close()
            raise ftplib.error_reply(resp)
        return conn, None


def conecta(proxy):
    ftp = FTPPeloProxy(proxy)
    ftp.connect(HOST)
    ftp.login()
    return ftp


def arquivos(ftp, agravos, anos, ultimos_anos):
    padrao = re.compile(r"^(%s)BR(\d{2})\.DBC$" % "|".join(agravos), re.I)
    escolhidos = {}
    for situacao, pasta in PASTAS:
        for nome in ftp.nlst(pasta):
            base = nome.rsplit("/", 1)[-1]
            m = padrao.match(base)
            if not m:
                continue
            agravo, ano = m.group(1).upper(), 2000 + int(m.group(2))
            if ano < ANO_INICIAL or (anos and ano not in anos):
                continue
            escolhidos.setdefault((agravo, ano), (situacao, f"{pasta}/{base}"))
    if ultimos_anos and escolhidos:
        corte = max(ano for _, ano in escolhidos) - ultimos_anos
        escolhidos = {k: v for k, v in escolhidos.items() if k[1] > corte}
    return escolhidos


def valor_json(v):
    if isinstance(v, (date, datetime)):
        return v.isoformat()
    if isinstance(v, bytes):
        return v.decode("latin-1", errors="replace")
    return v


def stream_load(sr, linhas, label):
    payload = "\n".join(linhas).encode("utf-8")
    headers = {"label": label, "column_separator": SEP, "columns": ",".join(COLUMNS),
               "max_filter_ratio": "0", "timeout": "1800", "Expect": "100-continue"}
    auth = (sr["user"], sr["password"])
    r = requests.put(f"http://{sr['host']}:8030/api/bronze/sinan_trabalho/_stream_load",
                     data=payload, headers=headers, auth=auth, allow_redirects=False,
                     timeout=1900)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=payload, headers=headers, auth=auth,
                         timeout=1900)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {label} failed: {res}")
    return res.get("NumberLoadedRows", 0)


def carrega(sr, proxy, agravo, ano, situacao, caminho, agora):
    base = caminho.rsplit("/", 1)[-1]
    with tempfile.TemporaryDirectory() as tmp:
        dbc, dbf = os.path.join(tmp, base), os.path.join(tmp, base[:-4] + ".dbf")
        ftp = conecta(proxy)
        try:
            with open(dbc, "wb") as f:
                ftp.retrbinary(f"RETR {caminho}", f.write)
        finally:
            ftp.close()
        decompress(dbc, dbf)
        linhas = []
        for reg in DBF(dbf, encoding="latin-1", char_decode_errors="replace",
                       raw=False, ignore_missing_memofile=True):
            registro = json.dumps({k: valor_json(v) for k, v in reg.items()},
                                  ensure_ascii=False).replace(SEP, " ")
            linhas.append(SEP.join([agravo, str(ano), situacao, registro, base, agora]))
    if not linhas:
        raise Exception(f"{base}: nenhuma notificacao lida")
    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM bronze.sinan_trabalho WHERE agravo = %s AND ano = %s",
                        (agravo, ano))
        conn.commit()
    finally:
        conn.close()
    carregadas = stream_load(sr, linhas, f"sst_sinan_{agravo}_{ano}_{uuid.uuid4().hex[:8]}")
    return {"agravo": agravo, "ano": ano, "situacao": situacao, "notificacoes": len(linhas),
            "linhas_carregadas": carregadas}


def main(agravos: Optional[List[str]] = None, anos: Optional[List[int]] = None,
         ultimos_anos: int = 0, listar: bool = False):
    """ultimos_anos > 0 limita a carga aos anos mais recentes publicados, os
    que ainda recebem notificacoes ou passam de PRELIM para FINAIS; e o modo
    do agendamento mensal. Sem ele, carrega todo o historico desde 2018."""
    proxy = wmill.get_variable("f/sst/inss_proxy")
    agravos = [a.upper() for a in (agravos or AGRAVOS)]
    ftp = conecta(proxy)
    try:
        escolhidos = arquivos(ftp, agravos, anos, ultimos_anos)
    finally:
        ftp.close()
    if not escolhidos:
        raise Exception(f"nenhum arquivo de {agravos} encontrado no DATASUS")
    if listar:
        return {f"{a}{ano}": sit for (a, ano), (sit, _) in sorted(escolhidos.items())}
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    return [carrega(sr, proxy, a, ano, sit, caminho, agora)
            for (a, ano), (sit, caminho) in sorted(escolhidos.items())]
