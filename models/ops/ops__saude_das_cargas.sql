SELECT
    carga,
    agendamento,
    erro,
    mensagem,
    registrado_em
FROM {{ ref('gold__saude_das_cargas') }}
