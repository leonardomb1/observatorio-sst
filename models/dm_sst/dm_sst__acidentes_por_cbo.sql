SELECT
    ano,
    cbo_codigo,
    ocupacao,
    acidentes,
    obitos,
    acidentes_evento,
    obitos_evento,
    acidentes_covid,
    obitos_covid,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_cbo') }}
