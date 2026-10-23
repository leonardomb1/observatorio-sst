SELECT
    ano,
    mes,
    tipo_acidente,
    acidentes,
    obitos,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_tipo_mensal') }}
