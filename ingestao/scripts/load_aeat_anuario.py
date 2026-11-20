import io
import re
import unicodedata
import uuid
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

import openpyxl
import pymysql
import requests
import wmill

PAGINA = ("https://www.gov.br/previdencia/pt-br/assuntos/previdencia-social/"
          "saude-e-seguranca-do-trabalhador/acidente_trabalho_incapacidade")
SEP = "\x01"
NS_XLSX = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"

COLS_IND = ["ano", "anuario", "escopo", "escopo_tipo", "cnae_codigo",
            "incidencia_por_mil", "incidencia_doencas_por_mil",
            "incidencia_tipicos_por_mil", "incidencia_incap_temp_por_mil",
            "mortalidade_por_100mil", "letalidade_por_mil_acidentes",
            "acidentalidade_16_34_pct", "arquivo_origem", "carregado_em"]
COLS_REG = ["ano", "anuario", "escopo", "escopo_tipo", "cnae_codigo", "total",
            "com_cat", "sem_cat", "tipico", "trajeto", "doenca",
            "arquivo_origem", "carregado_em"]
COLS_PERFIL = ["ano", "anuario", "escopo", "escopo_tipo", "situacao_registro",
               "dimensao", "categoria", "acidentes", "arquivo_origem",
               "carregado_em"]

INDICADORES = [
    ("incidencia_doencas_por_mil", "doencas ocupacionais"),
    ("incidencia_tipicos_por_mil", "acidentes tipicos"),
    ("incidencia_incap_temp_por_mil", "incapacidade temporaria"),
    ("mortalidade_por_100mil", "mortalidade"),
    ("letalidade_por_mil_acidentes", "letalidade"),
    ("acidentalidade_16_34_pct", "16 a 34"),
    ("incidencia_por_mil", "incidencia"),
]

REGIOES = {"norte": "Norte", "nordeste": "Nordeste", "sudeste": "Sudeste",
           "sul": "Sul", "centro-oeste": "Centro-Oeste"}


def norm(s):
    s = unicodedata.normalize("NFKD", str(s or "")).encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", s.lower()).strip()


def escopo_do_titulo(titulo):
    """O titulo termina em ', <escopo> - <ano>' e o escopo vem com preposicao.

    O nome sai como a fonte escreve, com acento e com a caixa correta: passar
    por title() produziria "Rio Grande Do Sul" e perder o acento produziria
    "Parana", nomes que ninguem reconhece num painel.
    """
    m = re.search(r",\s*([^,]+?)\s*-\s*\d{4}", titulo)
    bruto = (m.group(1) if m else "").strip()
    bruto = re.sub(r"^(?:nos?|nas?|em|dos estabelecimentos localizados\s+"
                   r"(?:nos?|nas?|em))\s+", "", bruto, flags=re.I).strip()
    bruto = re.sub(r"^estados?\s+d[oaei]s?\s+", "", bruto, flags=re.I).strip()
    chave = norm(bruto)
    if chave in ("brasil", ""):
        return "Brasil", "pais"
    if chave.startswith("regiao"):
        return bruto, "regiao"
    return bruto, "uf"


def escopo_da_linha(rotulo):
    """Nas tabelas por UF o escopo vem na primeira coluna: o pais e as
    regioes em caixa alta, as UFs com a grafia oficial."""
    chave = norm(rotulo)
    if chave == "brasil":
        return "Brasil", "pais"
    if chave in REGIOES:
        return REGIOES[chave], "regiao"
    if chave.startswith("ignorad"):
        return "Ignorada", "ignorado"
    return str(rotulo).strip(), "uf"


def numero(v):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return float(v)
    t = str(v).strip().replace(".", "").replace(",", ".") if "," in str(v) else str(v).strip()
    if t in ("", "-", "..", "...", "x"):
        return None
    try:
        return float(t)
    except ValueError:
        return None


def codigo(v):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return str(int(v)).zfill(4)
    return str(v).strip()


def indice_da_coluna(ref):
    n = 0
    for ch in re.match(r"[A-Z]+", ref).group(0):
        n = n * 26 + ord(ch) - 64
    return n - 1


def linhas_do_xml(conteudo):
    """Le a primeira planilha direto do XML, sem passar pelos estilos.

    As planilhas de raca/cor e de instrucao trazem estilos de data
    malformados que fazem o openpyxl falhar; os valores das celulas estao
    intactos e saem daqui como texto ou numero.
    """
    z = zipfile.ZipFile(io.BytesIO(conteudo))
    compartilhadas = []
    if "xl/sharedStrings.xml" in z.namelist():
        raiz = ET.fromstring(z.read("xl/sharedStrings.xml"))
        for si in raiz.iter(f"{NS_XLSX}si"):
            compartilhadas.append("".join(t.text or "" for t in si.iter(f"{NS_XLSX}t")))
    planilha = sorted(n for n in z.namelist()
                      if re.fullmatch(r"xl/worksheets/sheet\d+\.xml", n))[0]
    linhas = []
    for r in ET.fromstring(z.read(planilha)).iter(f"{NS_XLSX}row"):
        while len(linhas) < int(r.get("r")) - 1:
            linhas.append([])
        linha = []
        for c in r.iter(f"{NS_XLSX}c"):
            while len(linha) < indice_da_coluna(c.get("r")):
                linha.append(None)
            v = c.find(f"{NS_XLSX}v")
            if c.get("t") == "s" and v is not None:
                valor = compartilhadas[int(v.text)]
            elif c.get("t") == "inlineStr":
                valor = "".join(t.text or "" for t in c.iter(f"{NS_XLSX}t"))
            elif v is not None and v.text is not None:
                valor = numero(v.text) if c.get("t") != "str" else v.text
            else:
                valor = None
            linha.append(valor)
        linhas.append(linha)
    return linhas


def linhas_da_planilha(z, nome):
    conteudo = z.read(nome)
    try:
        wb = openpyxl.load_workbook(io.BytesIO(conteudo), read_only=True,
                                    data_only=True)
        ws = wb[wb.sheetnames[0]]
        dados = [list(r) for r in ws.iter_rows(values_only=True)]
        wb.close()
        return dados
    except TypeError:
        return linhas_do_xml(conteudo)


def preenche(linha):
    """propaga o rotulo de celula mesclada para a direita"""
    saida, ultimo = [], ""
    for c in linha:
        t = "" if c is None else str(c).replace("\n", " ").strip()
        if t:
            ultimo = t
        saida.append(ultimo)
    return saida


def fim_da_tabela(rotulo):
    r = norm(rotulo)
    return (not r) or r.startswith(("fonte", "nota", "(conclusao", "(continua",
                                    "obs", "elaboracao"))


def parse_indicadores(dados, titulo, anuario, arquivo, agora):
    ano = int(re.search(r"(\d{4})\s*$", titulo.strip()).group(1))
    escopo, tipo = escopo_do_titulo(titulo)
    i_cab = next(i for i, l in enumerate(dados)
                 if l and norm(l[0]) == "cnae")
    rotulos = [norm(c) for c in preenche(dados[i_cab + 1])]

    posicao = {}
    for j, rot in enumerate(rotulos):
        if j == 0 or not rot:
            continue
        for campo, chave in INDICADORES:
            if chave in rot and campo not in posicao:
                posicao[campo] = j
                break

    linhas = []
    for l in dados[i_cab + 2:]:
        if not l or fim_da_tabela(l[0]):
            break
        cod = codigo(l[0])
        if cod.upper() != "TOTAL" and not re.fullmatch(r"\d{4}", cod):
            continue
        valores = [numero(l[posicao[c]]) if c in posicao and posicao[c] < len(l)
                   else None for c in COLS_IND[5:12]]
        linhas.append([ano, anuario, escopo, tipo, cod.upper()]
                      + valores + [arquivo, agora])
    return linhas


def parse_registro(dados, titulo, anuario, arquivo, agora):
    escopo, tipo = escopo_do_titulo(titulo)
    i_cab = next(i for i, l in enumerate(dados) if l and norm(l[0]) == "cnae")
    i_ano = next(i for i in range(i_cab, min(i_cab + 6, len(dados)))
                 if sum(1 for c in dados[i][1:]
                        if re.fullmatch(r"\d{4}", str(c or "").strip())) >= 2)

    grupos = [preenche(dados[i]) for i in range(i_cab, i_ano)]
    campo_da_coluna = {}
    for j in range(1, len(dados[i_ano])):
        rot = norm(" ".join(g[j] if j < len(g) else "" for g in grupos))
        ano_col = str(dados[i_ano][j] or "").strip()
        if not re.fullmatch(r"\d{4}", ano_col):
            continue
        if "sem cat" in rot:
            campo = "sem_cat"
        elif "tipico" in rot:
            campo = "tipico"
        elif "trajeto" in rot:
            campo = "trajeto"
        elif "doenca" in rot:
            campo = "doenca"
        elif "com cat" in rot:
            campo = "com_cat"
        else:
            campo = "total"
        campo_da_coluna[j] = (int(ano_col), campo)

    anos = sorted({a for a, _ in campo_da_coluna.values()})
    linhas = []
    for l in dados[i_ano + 1:]:
        if not l or fim_da_tabela(l[0]):
            break
        cod = codigo(l[0])
        if cod.upper() != "TOTAL" and not re.fullmatch(r"\d{4}", cod):
            continue
        por_ano = {a: dict.fromkeys(COLS_REG[5:11]) for a in anos}
        for j, (a, campo) in campo_da_coluna.items():
            if j < len(l):
                v = numero(l[j])
                por_ano[a][campo] = None if v is None else int(v)
        for a in anos:
            linhas.append([a, anuario, escopo, tipo, cod.upper()]
                          + [por_ano[a][c] for c in COLS_REG[5:11]]
                          + [arquivo, agora])
    return linhas


def parse_perfil(dados, titulo, anuario, arquivo, agora):
    """Tabelas por raca/cor e por nivel de instrucao, segundo regioes e UFs.

    Cada escopo ocupa uma linha por ano, com o nome so na primeira; as
    categorias estao duas linhas abaixo do cabecalho, a partir da coluna que
    segue o total. Sai em formato longo, uma linha por categoria, incluindo
    o total, que serve de conferencia contra a soma das partes.
    """
    t = norm(titulo)
    dimensao = "raca_cor" if "raca/cor" in t else "instrucao"
    situacao = ("com_cat" if "com cat" in t
                else "sem_cat" if "sem cat" in t else "total")
    i_cab = next(i for i, l in enumerate(dados)
                 if l and norm(l[0]).startswith("grandes regioes"))
    j_total = next(j for j, c in enumerate(dados[i_cab + 1]) if norm(c) == "total")
    categorias = {j: re.sub(r"\s+", " ", str(c)).strip()
                  for j, c in enumerate(dados[i_cab + 2])
                  if j > j_total and c not in (None, "")}

    linhas, escopo, tipo = [], None, None
    for l in dados[i_cab + 3:]:
        if not l:
            continue
        if l[0] not in (None, "") and fim_da_tabela(l[0]):
            break
        if l[0] not in (None, ""):
            escopo, tipo = escopo_da_linha(l[0])
        ano_txt = str(l[1] if len(l) > 1 and l[1] is not None else "").strip()
        m = re.fullmatch(r"(\d{4})(?:\.0)?", ano_txt)
        if not m or escopo is None:
            continue
        ano = int(m.group(1))
        valores = [("Total", j_total)] + [(c, j) for j, c in categorias.items()]
        for categoria, j in valores:
            v = numero(l[j]) if j < len(l) else None
            linhas.append([ano, anuario, escopo, tipo, situacao, dimensao,
                           categoria, None if v is None else int(v),
                           arquivo, agora])
    return linhas


def carrega(sr, tabela, colunas, linhas, anuario):
    conn = pymysql.connect(host=sr["host"], port=int(sr["port"]),
                           user=sr["user"], password=sr["password"])
    try:
        with conn.cursor() as cur:
            cur.execute(f"DELETE FROM bronze.{tabela} WHERE anuario = %s", (anuario,))
        conn.commit()
    finally:
        conn.close()

    corpo = "\n".join(
        SEP.join("\\N" if v is None else str(v) for v in linha) for linha in linhas
    ).encode("utf-8")
    headers = {"label": f"sst_{tabela}_{anuario}_{uuid.uuid4().hex[:8]}",
               "column_separator": SEP, "columns": ",".join(colunas),
               "max_filter_ratio": "0.01", "timeout": "1200",
               "Expect": "100-continue"}
    r = requests.put(f"http://{sr['host']}:8030/api/bronze/{tabela}/_stream_load",
                     data=corpo, headers=headers,
                     auth=(sr["user"], sr["password"]),
                     allow_redirects=False, timeout=1300)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=corpo, headers=headers,
                         auth=(sr["user"], sr["password"]), timeout=1300)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"stream load {tabela} falhou: {res}")
    return res.get("NumberLoadedRows", 0)


def main(anuario: int = 0):
    """anuario 0 significa a edicao mais recente publicada na pagina.

    O padrao precisa ser dinamico: com um ano fixo, o agendamento continuaria
    recarregando a mesma edicao para sempre e a chegada de uma nova passaria
    despercebida.
    """
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    html = requests.get(PAGINA, timeout=180).text
    urls = set(re.findall(r"https?://[^\"']*aeat[^\"']*\.zip", html, re.I))
    anos = {}
    for u in urls:
        m = re.search(r"(20\d{2})", u.rsplit("/", 1)[-1])
        if m:
            anos.setdefault(int(m.group(1)), u)
    if not anos:
        raise Exception(f"nenhuma edicao encontrada em {PAGINA}")
    if not anuario:
        anuario = max(anos)
    if anuario not in anos:
        raise Exception(f"edicao {anuario} nao encontrada. disponiveis={sorted(anos)}")
    url = anos[anuario]
    arquivo = url.rsplit("/", 1)[-1]

    pacote = requests.get(url, timeout=600)
    pacote.raise_for_status()
    z = zipfile.ZipFile(io.BytesIO(pacote.content))

    ind, reg, perfil, ignorados, falhas = [], [], [], 0, []
    for nome in sorted(n for n in z.namelist() if n.endswith(".xlsx")):
        try:
            dados = linhas_da_planilha(z, nome)
            titulo = " ".join(str(c) for c in (dados[1] or []) if c) if len(dados) > 1 else ""
            t = norm(titulo)
            if ("raca/cor" in t or "nivel de instrucao" in t) and "unidades da federacao" in t:
                perfil += parse_perfil(dados, titulo, anuario, arquivo, agora)
            elif "Atividades Econ" not in titulo:
                ignorados += 1
            elif "Indicadores de acidentes do trabalho" in titulo:
                ind += parse_indicadores(dados, titulo, anuario, arquivo, agora)
            elif "situa" in titulo and "registro e motivo" in titulo:
                reg += parse_registro(dados, titulo, anuario, arquivo, agora)
            else:
                ignorados += 1
        except Exception as e:
            falhas.append(f"{nome.split('/')[-1]}: {type(e).__name__} {e}"[:160])

    if not ind and not reg and not perfil:
        raise Exception(f"nada extraido de {arquivo}. falhas={falhas[:3]}")

    carregadas = {}
    if ind:
        carregadas["aeat_indicadores"] = carrega(sr, "aeat_indicadores", COLS_IND,
                                                 ind, anuario)
    if reg:
        carregadas["aeat_registro"] = carrega(sr, "aeat_registro", COLS_REG,
                                              reg, anuario)
    if perfil:
        carregadas["aeat_perfil"] = carrega(sr, "aeat_perfil", COLS_PERFIL,
                                            perfil, anuario)

    return {"anuario": anuario, "arquivo": arquivo,
            "planilhas_ignoradas": ignorados, "linhas_carregadas": carregadas,
            "falhas": falhas[:5], "n_falhas": len(falhas)}
