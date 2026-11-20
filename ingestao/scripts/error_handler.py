import json
import uuid
from datetime import datetime, timezone

import requests
import wmill

SEP = "\x01"
ROW = "\x02"


def main(path: str = "", job_id: str = "", is_flow: bool = False,
         schedule_path: str = "", error: dict = None, error_started_at: str = "",
         **kwargs):
    sr = wmill.get_resource("f/infra/starrocks")
    agora = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    err = error or {}
    if not isinstance(err, dict):
        err = {"message": str(err)}
    mensagem = str(err.get("message") or json.dumps(err))[:4000]
    nome = str(err.get("name") or "Exception")

    linha = SEP.join([
        job_id or str(uuid.uuid4()),
        path or "",
        schedule_path or "",
        "flow" if is_flow else "script",
        nome,
        mensagem.replace(SEP, " ").replace(ROW, " "),
        error_started_at or agora,
        agora,
    ])

    cols = ["job_id", "script_path", "schedule_path", "tipo", "erro_nome",
            "erro_mensagem", "falhou_em", "registrado_em"]
    headers = {
        "label": f"sst_falha_{uuid.uuid4().hex[:8]}",
        "column_separator": SEP,
        "row_delimiter": ROW,
        "columns": ",".join(cols),
        "max_filter_ratio": "0.5",
        "timeout": "120",
        "Expect": "100-continue",
    }
    r = requests.put(f"http://{sr['host']}:8030/api/bronze/sst_falhas/_stream_load",
                     data=linha.encode("utf-8"), headers=headers,
                     auth=(sr["user"], sr["password"]),
                     allow_redirects=False, timeout=150)
    if r.status_code in (301, 302, 307, 308):
        r = requests.put(r.headers["Location"], data=linha.encode("utf-8"),
                         headers=headers, auth=(sr["user"], sr["password"]),
                         timeout=150)
    res = r.json()
    if res.get("Status") not in ("Success", "Publish Timeout"):
        raise Exception(f"nao consegui registrar a falha: {res}")

    return {"registrado": True, "script_path": path, "erro": mensagem[:200]}
