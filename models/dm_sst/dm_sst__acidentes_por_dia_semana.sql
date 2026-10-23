SELECT
    ano,
    dia_semana,
    ordem,
    acidentes,
    obitos,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_dia_semana') }}
