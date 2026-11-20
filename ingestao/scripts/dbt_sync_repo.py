import io
import os
import tarfile

import requests

REPO = "leonardomb1/observatorio-sst"
ALVO = "f/sst/dbt_observatorio"
AGENDA = "f/sst/dbt_mensal"
PREFIXOS = ("models/", "macros/", "tests/", "profiles/", "seeds/")
ARQUIVOS = ("dbt_project.yml",)


def main(ref: str = "main"):
    base = os.environ.get("BASE_INTERNAL_URL") or os.environ["WM_BASE_URL"]
    ws = os.environ["WM_WORKSPACE"]
    h = {"Authorization": "Bearer " + os.environ["WM_TOKEN"]}

    url = f"https://codeload.github.com/{REPO}/tar.gz/refs/heads/{ref}"
    pacote = requests.get(url, timeout=180)
    pacote.raise_for_status()

    novos = {}
    with tarfile.open(fileobj=io.BytesIO(pacote.content)) as t:
        for m in t.getmembers():
            if not m.isfile() or "/" not in m.name:
                continue
            rel = m.name.split("/", 1)[1]
            if rel.startswith(PREFIXOS) or rel in ARQUIVOS:
                novos[rel] = t.extractfile(m).read().decode("utf-8")
    if "dbt_project.yml" not in novos:
        raise Exception(f"tarball sem dbt_project.yml: {sorted(novos)[:5]}")

    atual = requests.get(f"{base}/api/w/{ws}/scripts/get/p/{ALVO}", headers=h)
    atual.raise_for_status()
    s = atual.json()
    antigos = s.get("modules") or {}

    # A forma esperada de cada modulo vem dos que ja existem: em algumas versoes
    # e um objeto com linguagem, em outras o texto puro.
    #
    # Com o alvo VAZIO nao ha de quem inferir, e e justamente quando este script
    # mais importa: alvo vazio significa projeto perdido. Antes de 20/08/2026 o
    # caso ausente caia no texto puro e a API respondia 422, ou seja, a rota de
    # recuperacao falhava exatamente na situacao que deveria consertar. Sem
    # modulos, assume-se o objeto com linguagem, que e a forma aceita.
    molde = next(iter(antigos.values()), None)
    if isinstance(molde, str):
        modules = novos
    else:
        lingua = molde.get("language", "dbt") if isinstance(molde, dict) else "dbt"
        modules = {k: {"content": v, "language": lingua} for k, v in novos.items()}

    if modules == antigos:
        return {"hash": s["hash"], "modulos": len(modules),
                "adicionados": [], "removidos": [], "agendamento": "inalterado"}

    r = requests.post(
        f"{base}/api/w/{ws}/scripts/create", headers=h,
        json={"path": s["path"], "summary": s["summary"],
              "description": s["description"], "content": s["content"],
              "language": s["language"], "kind": s["kind"],
              "parent_hash": s["hash"], "modules": modules,
              "deployment_message": f"sincroniza projeto dbt de {REPO}@{ref}"},
    )
    r.raise_for_status()

    # o job ja na fila esta preso ao hash anterior: desligar e religar o
    # agendamento faz o Windmill descartar aquele job e enfileirar a versao nova
    agendamento = "reenfileirado"
    try:
        for estado in (False, True):
            requests.post(f"{base}/api/w/{ws}/schedules/setenabled/{AGENDA}",
                          headers=h, json={"enabled": estado}).raise_for_status()
    except Exception as e:
        agendamento = f"falhou: {str(e)[:120]}"

    return {"hash": r.text, "modulos": len(modules),
            "adicionados": sorted(set(novos) - set(antigos)),
            "removidos": sorted(set(antigos) - set(novos)),
            "agendamento": agendamento}
